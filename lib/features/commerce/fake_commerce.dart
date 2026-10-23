import 'package:dio/dio.dart';

import '../../core/fake_backend.dart';
import '../auth/fake_auth.dart';
import '../content/fake_content.dart';
import '../live/fake_live.dart';
import '../messages/fake_messaging.dart';
import '../onboarding/fake_onboarding.dart';

/// In-memory orders, M-Pesa payments, entitlements, subscriptions, ledger and
/// payouts (IT.md §9.8–9.10, §10). Checkout phones ending in 000 fail and 999
/// are cancelled by the "customer"; any other number succeeds on the second
/// status check, as if the M-Pesa callback had arrived.
const commissionPercent = 20;
const payoutMinimumCents = 100000; // KSh 1,000
const payoutMaximumCents = 15000000; // KSh 150,000
const contractRef = 'v1.0';

class _Order {
  _Order(
    this.id,
    this.fanId,
    this.type,
    this.itemId,
    this.creatorId,
    this.description,
    this.amountCents,
    this.key,
  );
  final String id;
  final String fanId;
  final String type; // post | subscription
  final String itemId;
  final String creatorId;
  final String description;
  final int amountCents;
  final String key;
  String status = 'created'; // created | paid | refund_requested | refunded
  final createdAt = DateTime.now().toUtc();
}

class _Payment {
  _Payment(this.id, this.order, this.phone);
  final String id;
  final _Order order;
  final String phone;
  String status = 'processing';
  String? failureReason;
  int polls = 0;
}

class _Entry {
  _Entry(this.txId, this.account, this.amountCents);
  final String txId;
  final String account; // e.g. creator:u2:pending, platform:commission
  final int amountCents;
}

class _Tx {
  _Tx(
    this.id,
    this.creatorId,
    this.type,
    this.description,
    this.grossCents,
    this.commissionCents,
    this.status,
    this.createdAt,
  );
  final String id;
  final String creatorId;
  final String type; // sale | subscription | payout | refund
  final String description;
  final int grossCents;
  final int commissionCents;
  String status;
  final DateTime createdAt;
}

class _Subscription {
  _Subscription(
    this.id,
    this.fanId,
    this.creatorId,
    this.priceCents,
    this.endsAt,
  );
  final String id;
  final String fanId;
  final String creatorId;
  final int priceCents;
  String status = 'active'; // active | cancelled | expired
  DateTime endsAt;
}

class _Payout {
  _Payout(this.id, this.creatorId, this.amountCents, this.destination);
  final String id;
  final String creatorId;
  final int amountCents;
  final String destination;
  String status = 'requested'; // requested | approved | paid | rejected
  String? approvedBy;
  String? rejectReason;
  final createdAt = DateTime.now().toUtc();
}

/// Commission for new transactions; staff change it in the admin app. Past
/// transactions keep the rate they were posted with (FR-PRC-005).
var currentCommissionPercent = commissionPercent;

class FakeCommerceDb {
  final _orders = <String, _Order>{};
  final _payments = <String, _Payment>{};
  final _processedCallbacks = <String>{};
  final ledger = <_Entry>[];
  final _txs = <_Tx>[];
  final _subscriptions = <String, _Subscription>{};
  final _payouts = <_Payout>[];
  var _seq = 0;

  FakeCommerceDb() {
    reset();
  }

  void reset() {
    _orders.clear();
    _payments.clear();
    _processedCallbacks.clear();
    ledger.clear();
    _txs.clear();
    _subscriptions.clear();
    _payouts.clear();
    _seq = 0;
    // Amani's history: KSh 12,450 available, KSh 20,000 already paid out.
    _post(
      _Tx(
        't-seed-1',
        'u2',
        'sale',
        'Earlier sales',
        1556250,
        311250,
        'settled',
        DateTime.utc(2026, 9, 1),
      ),
      settled: true,
    );
    _post(
      _Tx(
        't-seed-2',
        'u2',
        'sale',
        'Earlier sales',
        2500000,
        500000,
        'settled',
        DateTime.utc(2026, 9, 15),
      ),
      settled: true,
    );
    _txs.add(
      _Tx(
        't-seed-3',
        'u2',
        'payout',
        'Payout to M-Pesa',
        2000000,
        0,
        'paid',
        DateTime.utc(2026, 9, 20),
      ),
    );
    ledger
      ..add(_Entry('t-seed-3', 'creator:u2:available', 2000000))
      ..add(_Entry('t-seed-3', 'provider:mpesa:clearing', -2000000));
    currentCommissionPercent = commissionPercent;
    // Amani has asked for KSh 5,000 (finance queue demo), funded by one more
    // settled sale so her available balance stays KSh 12,450.
    _post(
      _Tx(
        't-seed-4',
        'u2',
        'sale',
        'Earlier sales',
        625000,
        125000,
        'settled',
        DateTime.utc(2026, 10, 5),
      ),
      settled: true,
    );
    _payouts.add(_Payout('po-seed', 'u2', 500000, 'M-Pesa +254 ••• 111'));
    ledger
      ..add(_Entry('po-seed', 'creator:u2:available', 500000))
      ..add(_Entry('po-seed', 'creator:u2:reserved', -500000));
  }

  /// Balanced entries for a sale: asset = creator share + commission.
  void _post(_Tx tx, {bool settled = false}) {
    _txs.add(tx);
    final net = tx.grossCents - tx.commissionCents;
    ledger
      ..add(_Entry(tx.id, 'provider:mpesa:clearing', tx.grossCents))
      ..add(
        _Entry(
          tx.id,
          'creator:${tx.creatorId}:${settled ? 'available' : 'pending'}',
          -net,
        ),
      )
      ..add(_Entry(tx.id, 'platform:commission', -tx.commissionCents));
  }

  /// Balance of a creator liability bucket. Liabilities are credits, stored
  /// negative, so every transaction's entries sum to zero.
  int balance(String creatorId, String bucket) => -ledger
      .where((e) => e.account == 'creator:$creatorId:$bucket')
      .fold<int>(0, (s, e) => s + e.amountCents);

  int paidOut(String creatorId) => _txs
      .where(
        (t) =>
            t.creatorId == creatorId &&
            t.type == 'payout' &&
            t.status == 'paid',
      )
      .fold<int>(0, (s, t) => s + t.grossCents);

  static int commissionOf(int grossCents) =>
      (grossCents * currentCommissionPercent + 50) ~/ 100;

  List<Map<String, Object?>> payoutsFor(String? status) => [
    for (final p in _payouts.reversed.where(
      (p) => status == null || p.status == status,
    ))
      {
        ..._payoutJson(p),
        'creatorId': p.creatorId,
        'approvedBy': p.approvedBy,
        'rejectReason': p.rejectReason,
      },
  ];

  _Payout? _payout(String id) => _payouts.where((p) => p.id == id).firstOrNull;

  (int, Object?) approvePayout(String id, String staffId) {
    final p = _payout(id);
    if (p == null) return _notFound;
    if (p.status != 'requested') {
      return _error(
        409,
        'INVALID_STATE',
        'Only requested payouts can be approved',
      );
    }
    p
      ..status = 'approved'
      ..approvedBy = staffId;
    return (200, _payoutJson(p));
  }

  /// Sends the approved payout to M-Pesa. A different staff member must do
  /// this than the one who approved it (dual control, IT.md 7.3).
  (int, Object?) submitPayout(String id, String staffId) {
    final p = _payout(id);
    if (p == null) return _notFound;
    if (p.status != 'approved') {
      return _error(409, 'INVALID_STATE', 'Approve the payout first');
    }
    if (p.approvedBy == staffId) {
      return _error(
        409,
        'DUAL_CONTROL_REQUIRED',
        'A different finance user must send this payout',
      );
    }
    p.status = 'paid'; // the fake M-Pesa B2C confirms immediately
    ledger
      ..add(_Entry(p.id, 'creator:${p.creatorId}:reserved', p.amountCents))
      ..add(_Entry(p.id, 'provider:mpesa:clearing', -p.amountCents));
    _txs.add(
      _Tx(
        't-${p.id}',
        p.creatorId,
        'payout',
        'Payout to ${p.destination}',
        p.amountCents,
        0,
        'paid',
        DateTime.now().toUtc(),
      ),
    );
    return (200, _payoutJson(p));
  }

  (int, Object?) rejectPayout(String id, String reason) {
    final p = _payout(id);
    if (p == null) return _notFound;
    if (p.status != 'requested' && p.status != 'approved') {
      return _error(
        409,
        'INVALID_STATE',
        'This payout can no longer be rejected',
      );
    }
    p
      ..status = 'rejected'
      ..rejectReason = reason;
    // Reserved goes back to available.
    ledger
      ..add(_Entry(p.id, 'creator:${p.creatorId}:reserved', p.amountCents))
      ..add(_Entry(p.id, 'creator:${p.creatorId}:available', -p.amountCents));
    return (200, _payoutJson(p));
  }

  int _tierPrice(String creatorId) => creatorId == 'u2' ? 50000 : 30000;

  /// The verified M-Pesa callback. Applying it twice changes nothing
  /// (FR-PAY-004).
  void providerCallback(
    String paymentId, {
    required bool success,
    String? reason,
  }) {
    if (!_processedCallbacks.add(paymentId)) return;
    final payment = _payments[paymentId]!;
    if (!success) {
      payment
        ..status = reason == 'cancelled' ? 'cancelled' : 'failed'
        ..failureReason = reason;
      return;
    }
    payment.status = 'succeeded';
    final order = payment.order..status = 'paid';
    _post(
      _Tx(
        't-${order.id}',
        order.creatorId,
        switch (order.type) {
          'subscription' => 'subscription',
          'tip' => 'tip',
          _ => 'sale',
        },
        order.description,
        order.amountCents,
        commissionOf(order.amountCents),
        'pending',
        DateTime.now().toUtc(),
      ),
    );
    if (order.type == 'post') {
      fakeContentDb.grantPurchase(order.fanId, order.itemId);
    } else if (order.type == 'message') {
      fakeMessagingDb.unlock(order.fanId, order.itemId);
    } else if (order.type == 'ticket') {
      fakeLiveDb.grantTicket(order.fanId, order.itemId);
    } else if (order.type == 'tip') {
      fakeLiveDb.recordTip(order.itemId, order.amountCents);
    } else {
      final existing = _subscriptions.values.where(
        (s) => s.fanId == order.fanId && s.creatorId == order.creatorId,
      );
      final endsAt = DateTime.now().toUtc().add(const Duration(days: 30));
      if (existing.isEmpty) {
        final id = 's${++_seq}';
        _subscriptions[id] = _Subscription(
          id,
          order.fanId,
          order.creatorId,
          order.amountCents,
          endsAt,
        );
      } else {
        existing.first
          ..status = 'active'
          ..endsAt = endsAt;
      }
      fakeContentDb.grantSubscription(order.fanId, order.creatorId);
    }
  }

  (int, Object?) _signedIn(
    RequestOptions req,
    (int, Object?) Function(String userId) handle,
  ) {
    final userId = fakeAuthDb.callerId(req);
    return userId == null ? FakeAuthDb.unauthorized : handle(userId);
  }

  static (int, Object?) _error(int status, String code, String message) =>
      (status, {'code': code, 'message': message});

  static const _notFound = (404, {'code': 'NOT_FOUND', 'message': 'Not found'});

  Map<String, Object?> _orderJson(_Order o) => {
    'id': o.id,
    'type': o.type,
    'itemId': o.itemId,
    'creatorId': o.creatorId,
    'description': o.description,
    'currency': 'KES',
    'amountCents': o.amountCents,
    'feesCents': 0,
    'totalCents': o.amountCents,
    'recurring': o.type == 'subscription',
    'status': o.status,
    'createdAt': o.createdAt.toIso8601String(),
  };

  Map<String, Object?> _paymentJson(_Payment p) => {
    'id': p.id,
    'orderId': p.order.id,
    'status': p.status,
    'method': 'mpesa',
    'failureReason': p.failureReason,
  };

  Map<String, Object?> _txJson(_Tx t) => {
    'id': t.id,
    'type': t.type,
    'description': t.description,
    'currency': 'KES',
    'grossCents': t.grossCents,
    'commissionCents': t.commissionCents,
    'feesCents': 0,
    'netCents': t.type == 'payout'
        ? -t.grossCents
        : t.grossCents - t.commissionCents,
    'status': t.status,
    'contractRef': t.type == 'payout' ? null : contractRef,
    'createdAt': t.createdAt.toIso8601String(),
  };

  Map<String, Object?> _subscriptionJson(_Subscription s, String viewerId) => {
    'id': s.id,
    'creator': fakeContentDb.creatorJson(s.creatorId, viewerId),
    'priceCents': s.priceCents,
    'currency': 'KES',
    'status': s.status,
    'renewsAt': s.status == 'active' ? s.endsAt.toIso8601String() : null,
    'endsAt': s.endsAt.toIso8601String(),
    'benefits': const ['All subscriber posts', 'Priority messages'],
  };

  Map<String, FakeHandler> get routes => {
    'GET /creators/{id}/subscription-tiers': (req, params) {
      if (fakeContentDb.creatorProfile(params['id']!) == null) {
        return _notFound;
      }
      return (
        200,
        [
          {
            'id': 'tier-${params['id']}',
            'name': 'Monthly',
            'priceCents': _tierPrice(params['id']!),
            'currency': 'KES',
            'interval': 'month',
            'benefits': const ['All subscriber posts', 'Priority messages'],
          },
        ],
      );
    },
    'POST /orders': (req, _) => _signedIn(req, (userId) {
      final body = req.data as Map;
      final key = body['idempotencyKey'] as String? ?? '';
      final repeat = _orders.values.where(
        (o) => o.fanId == userId && o.key == key && key != '',
      );
      if (repeat.isNotEmpty) return (200, _orderJson(repeat.first));
      final type = body['type'];
      final itemId = body['itemId'] as String? ?? '';
      String creatorId;
      int amount;
      String description;
      if (type == 'post') {
        final post = fakeContentDb.paidPost(itemId);
        if (post == null) {
          return _error(400, 'NOT_PURCHASABLE', 'This item is not for sale');
        }
        creatorId = post.creatorId;
        amount = post.priceCents;
        final handle = fakeContentDb.creatorProfile(creatorId)?['handle'];
        description = 'Post by @$handle';
      } else if (type == 'ticket') {
        final ticket = fakeLiveDb.ticketFor(itemId);
        if (ticket == null) {
          return _error(400, 'NOT_PURCHASABLE', 'This stream has no tickets');
        }
        creatorId = ticket.creatorId;
        amount = ticket.priceCents;
        final handle = fakeContentDb.creatorProfile(creatorId)?['handle'];
        description = 'Live ticket for @$handle';
      } else if (type == 'tip') {
        final creator = fakeLiveDb.creatorOf(itemId);
        final tip = body['amountCents'] as int?;
        if (creator == null) {
          return _error(400, 'NOT_PURCHASABLE', 'This stream has ended');
        }
        if (tip == null || tip < minPriceCents || tip > maxPriceCents) {
          return _error(
            400,
            'PRICE_OUT_OF_RANGE',
            'Tips must be between KSh 10 and KSh 50,000',
          );
        }
        creatorId = creator;
        amount = tip;
        final handle = fakeContentDb.creatorProfile(creatorId)?['handle'];
        description = 'Live tip for @$handle';
      } else if (type == 'message') {
        final message = fakeMessagingDb.paidMessage(itemId, userId);
        if (message == null) {
          return _error(400, 'NOT_PURCHASABLE', 'This item is not for sale');
        }
        creatorId = message.creatorId;
        amount = message.priceCents;
        final handle = fakeContentDb.creatorProfile(creatorId)?['handle'];
        description = 'Message attachment from @$handle';
      } else if (type == 'subscription') {
        if (fakeContentDb.creatorProfile(itemId) == null) {
          return _error(400, 'NOT_PURCHASABLE', 'Creator not found');
        }
        creatorId = itemId;
        amount = _tierPrice(itemId);
        final handle = fakeContentDb.creatorProfile(itemId)?['handle'];
        description = 'Monthly subscription to @$handle';
      } else {
        return _error(400, 'NOT_PURCHASABLE', 'Unknown item type');
      }
      if (creatorId == userId) {
        return _error(400, 'NOT_PURCHASABLE', 'You own this');
      }
      final id = 'o${++_seq}';
      _orders[id] = _Order(
        id,
        userId,
        type as String,
        itemId,
        creatorId,
        description,
        amount,
        key,
      );
      return (201, _orderJson(_orders[id]!));
    }),
    'GET /orders/{id}': (req, params) => _signedIn(req, (userId) {
      final o = _orders[params['id']];
      return o == null || o.fanId != userId ? _notFound : (200, _orderJson(o));
    }),
    'POST /orders/{id}/checkout': (req, params) => _signedIn(req, (userId) {
      final o = _orders[params['id']];
      if (o == null || o.fanId != userId) return _notFound;
      if (o.status == 'paid') {
        return _error(409, 'ALREADY_PAID', 'This order is already paid');
      }
      final phone = (req.data as Map)['phone'] as String? ?? '';
      if (!RegExp(r'^\+254[17]\d{8}$').hasMatch(phone)) {
        return _error(400, 'INVALID_PHONE', 'Enter an M-Pesa number');
      }
      final id = 'pay${++_seq}';
      _payments[id] = _Payment(id, o, phone);
      return (201, _paymentJson(_payments[id]!));
    }),
    // Real system: the provider status is authoritative. The fake decides
    // from the phone number on the second check.
    'GET /payments/{id}': (req, params) => _signedIn(req, (userId) {
      final p = _payments[params['id']];
      if (p == null || p.order.fanId != userId) return _notFound;
      if (p.status == 'processing' && ++p.polls >= 2) {
        if (p.phone.endsWith('000')) {
          providerCallback(p.id, success: false, reason: 'insufficient_funds');
        } else if (p.phone.endsWith('999')) {
          providerCallback(p.id, success: false, reason: 'cancelled');
        } else {
          providerCallback(p.id, success: true);
        }
      }
      return (200, _paymentJson(p));
    }),
    'POST /payments/provider-webhooks/{provider}': (req, _) {
      final body = req.data as Map;
      final id = body['paymentId'] as String?;
      if (!_payments.containsKey(id)) return _notFound;
      providerCallback(id!, success: body['resultCode'] == 0);
      return (200, {'received': true});
    },
    'GET /fans/me/purchases': (req, _) => _signedIn(
      req,
      (userId) => (
        200,
        [
          for (final o in _orders.values.where(
            (o) => o.fanId == userId && o.status != 'created',
          ))
            _orderJson(o),
        ].reversed.toList(),
      ),
    ),
    'POST /orders/{id}/refund-requests': (req, params) => _signedIn(req, (
      userId,
    ) {
      final o = _orders[params['id']];
      if (o == null || o.fanId != userId) return _notFound;
      if (o.status != 'paid') {
        return _error(409, 'NOT_REFUNDABLE', 'This order cannot be refunded');
      }
      o.status = 'refund_requested';
      return (201, {'id': 'r${o.id}', 'status': 'requested'});
    }),
    'GET /fans/me/subscriptions': (req, _) => _signedIn(
      req,
      (userId) => (
        200,
        [
          for (final s in _subscriptions.values.where((s) => s.fanId == userId))
            _subscriptionJson(s, userId),
        ],
      ),
    ),
    'POST /subscriptions/{id}/cancel': (req, params) =>
        _signedIn(req, (userId) {
          final s = _subscriptions[params['id']];
          if (s == null || s.fanId != userId) return _notFound;
          // Renewal stops; access continues until endsAt.
          s.status = 'cancelled';
          return (200, _subscriptionJson(s, userId));
        }),
    'GET /creators/me/earnings': (req, _) => _signedIn(
      req,
      (userId) => (
        200,
        {
          'currency': 'KES',
          'pendingCents': balance(userId, 'pending'),
          'availableCents': balance(userId, 'available'),
          'reservedCents': balance(userId, 'reserved'),
          'paidOutCents': paidOut(userId),
          'adjustmentsCents': 0,
          'commissionPercent': currentCommissionPercent,
          'payoutMinimumCents': payoutMinimumCents,
          'payoutMaximumCents': payoutMaximumCents,
        },
      ),
    ),
    'GET /creators/me/transactions': (req, _) => _signedIn(req, (userId) {
      final txs = _txs.where((t) => t.creatorId == userId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return (200, [for (final t in txs) _txJson(t)]);
    }),
    'POST /creators/me/payout-requests': (req, _) => _signedIn(req, (userId) {
      final body = req.data as Map;
      final amount = body['amountCents'] as int? ?? 0;
      final key = body['idempotencyKey'] as String? ?? '';
      final repeat = _payouts.where((p) => p.id == 'po-$key');
      if (repeat.isNotEmpty) {
        return (200, _payoutJson(repeat.first));
      }
      if (!fakeOnboardingDb.isApproved(userId)) {
        return _error(
          403,
          'CREATOR_NOT_APPROVED',
          'Finish creator setup first',
        );
      }
      final methods = fakeOnboardingDb.payoutOf(userId);
      if (methods == null ||
          methods['id'] != body['payoutMethodId'] ||
          methods['verified'] != true) {
        return _error(
          400,
          'DESTINATION_NOT_VERIFIED',
          'Verify your M-Pesa number first',
        );
      }
      if (amount < payoutMinimumCents || amount > payoutMaximumCents) {
        return _error(
          400,
          'AMOUNT_OUT_OF_RANGE',
          'Amount must be between KSh 1,000 and KSh 150,000',
        );
      }
      if (amount > balance(userId, 'available')) {
        return _error(
          400,
          'INSUFFICIENT_BALANCE',
          'That is more than your available balance',
        );
      }
      final payout = _Payout(
        'po-$key',
        userId,
        amount,
        'M-Pesa ${(methods['phone'] as String).substring(0, 4)} ••• '
            '${(methods['phone'] as String).substring(10)}',
      );
      _payouts.add(payout);
      // Available -> reserved until finance approves and M-Pesa pays.
      ledger
        ..add(_Entry(payout.id, 'creator:$userId:available', amount))
        ..add(_Entry(payout.id, 'creator:$userId:reserved', -amount));
      return (201, _payoutJson(payout));
    }),
    'GET /creators/me/payout-requests': (req, _) => _signedIn(
      req,
      (userId) => (
        200,
        [
          for (final p in _payouts.reversed.where((p) => p.creatorId == userId))
            _payoutJson(p),
        ],
      ),
    ),
  };

  Map<String, Object?> _payoutJson(_Payout p) => {
    'id': p.id,
    'amountCents': p.amountCents,
    'currency': 'KES',
    'destination': p.destination,
    'status': p.status,
    'createdAt': p.createdAt.toIso8601String(),
  };
}

final fakeCommerceDb = FakeCommerceDb();
