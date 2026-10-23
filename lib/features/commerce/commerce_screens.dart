import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../core/money.dart';
import '../auth/auth_controller.dart';
import '../content/content_api.dart';
import '../content/discover_screens.dart';
import '../disguise/lock_gate.dart';
import '../disguise/pin_pad.dart';
import 'commerce_api.dart';

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

String _date(BuildContext context, String iso) => MaterialLocalizations.of(
  context,
).formatMediumDate(DateTime.parse(iso).toLocal());

const _tabular = [FontFeature.tabularFigures()];

/// Rounded-square tonal icon used as the leading element of money rows.
class _TonalIcon extends StatelessWidget {
  const _TonalIcon(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(controlRadius),
      ),
      child: Icon(icon, color: scheme.onSecondaryContainer),
    );
  }
}

/// IT.md F6 + F7. The server prices the order; access is granted only when
/// the server reports the payment `succeeded`, never from this screen.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.type,
    required this.itemId,
    this.amountCents,
  });

  /// post | subscription | message | ticket | tip
  final String type;
  final String itemId;

  /// Only for tips, where the fan chooses the amount.
  final int? amountCents;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  static const pollEvery = Duration(seconds: 2);
  static const giveUpAfter = 45; // polls, about 90 seconds

  final _orderKey = newIdempotencyKey();
  final _phone = TextEditingController();
  Json? _order;
  String? _error;
  String? _paymentId;
  String? _status;
  String? _failureReason;
  Timer? _timer;
  int _polls = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final identifier = ref.read(authProvider).user?.identifier ?? '';
    if (identifier.startsWith('+254')) {
      _phone.text = '0${identifier.substring(4)}';
    }
    _createOrder();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _createOrder() async {
    try {
      final response = await ref
          .read(dioProvider)
          .post<Json>(
            '/orders',
            data: {
              'type': widget.type,
              'itemId': widget.itemId,
              'amountCents': ?widget.amountCents,
              'idempotencyKey': _orderKey,
            },
          );
      setState(() => _order = response.data);
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    }
  }

  Future<void> _pay() async {
    final phone = normalizeIdentifier(_phone.text);
    if (phone == null || !RegExp(r'^\+254[17]\d{8}$').hasMatch(phone)) {
      return _snack(context, 'Enter your M-Pesa number');
    }
    setState(() => _busy = true);
    try {
      final payment =
          (await ref
                  .read(dioProvider)
                  .post<Json>(
                    '/orders/${_order!['id']}/checkout',
                    data: {
                      'method': 'mpesa',
                      'phone': phone,
                      'idempotencyKey': newIdempotencyKey(),
                    },
                  ))
              .data!;
      setState(() {
        _paymentId = payment['id'] as String;
        _status = payment['status'] as String;
        _polls = 0;
      });
      _timer = Timer.periodic(pollEvery, (_) => _poll());
    } catch (e) {
      if (mounted) _snack(context, apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _poll() async {
    if (++_polls > giveUpAfter) {
      _timer?.cancel();
      setState(() => _status = 'still_waiting');
      return;
    }
    try {
      final payment =
          (await ref.read(dioProvider).get<Json>('/payments/$_paymentId'))
              .data!;
      if (!mounted) return;
      final status = payment['status'] as String;
      setState(() {
        _status = status;
        _failureReason = payment['failureReason'] as String?;
      });
      if (terminalPaymentStates.contains(status)) {
        _timer?.cancel();
        if (status == 'succeeded') _refreshAccess();
      }
    } catch (_) {
      // Offline for a moment: keep polling; the server state is unchanged.
    }
  }

  void _refreshAccess() {
    if (widget.type == 'post') ref.invalidate(postProvider(widget.itemId));
    ref.invalidate(creatorPostsProvider);
    ref.invalidate(creatorProvider);
    ref.invalidate(purchasesProvider);
    ref.invalidate(subscriptionsProvider);
  }

  void _checkAgain() {
    _polls = 0;
    setState(() => _status = 'processing');
    _timer = Timer.periodic(pollEvery, (_) => _poll());
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: order == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(_error!),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _OrderSummary(order: order),
                const SizedBox(height: 16),
                if (_paymentId == null) ..._payForm() else _result(order),
              ],
            ),
    );
  }

  List<Widget> _payForm() => [
    Text('Pay with', style: Theme.of(context).textTheme.titleMedium),
    const Card(
      child: ListTile(
        leading: _TonalIcon(Icons.phone_android),
        title: Text('M-Pesa'),
        subtitle: Text('You will get a prompt on your phone'),
        trailing: Icon(Icons.check_circle),
      ),
    ),
    const SizedBox(height: 8),
    TextField(
      key: const ValueKey('checkout-phone'),
      controller: _phone,
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
      decoration: const InputDecoration(
        labelText: 'M-Pesa number',
        hintText: '0712 345 678',
      ),
    ),
    const SizedBox(height: 16),
    FilledButton(
      key: const ValueKey('checkout-pay'),
      onPressed: _busy ? null : _pay,
      child: Text('Pay ${formatKes(_order!['totalCents'] as int)}'),
    ),
  ];

  Widget _result(Json order) {
    final text = Theme.of(context).textTheme;
    Widget state(
      IconData icon,
      String title,
      String body,
      List<Widget> actions,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, size: 56),
        const SizedBox(height: 8),
        Text(title, style: text.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(body, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ...actions,
      ],
    );
    final done = FilledButton(
      onPressed: () => context.pop(_status == 'succeeded'),
      child: const Text('Done'),
    );
    final retry = OutlinedButton(
      onPressed: () => setState(() => _paymentId = null),
      child: const Text('Try again'),
    );
    return switch (_status) {
      'succeeded' => state(
        Icons.check_circle_outline,
        'Payment received',
        switch (order['type']) {
          'post' => 'The post is unlocked. Your receipt is in My library.',
          'subscription' =>
            'Your subscription is active. Your receipt is in My library.',
          'ticket' => 'You have a ticket. Enjoy the stream!',
          'tip' => 'Your tip was sent. Thank you!',
          _ => 'Unlocked. Your receipt is in My library.',
        },
        [done],
      ),
      'failed' => state(
        Icons.error_outline,
        'Payment failed',
        _failureReason == 'insufficient_funds'
            ? 'M-Pesa said there were not enough funds. You were not charged.'
            : 'M-Pesa did not complete the payment. You were not charged.',
        [retry],
      ),
      'cancelled' => state(
        Icons.cancel_outlined,
        'Payment cancelled',
        'The M-Pesa prompt was cancelled. You were not charged.',
        [retry],
      ),
      'expired' => state(
        Icons.timer_off_outlined,
        'Payment expired',
        'The M-Pesa prompt timed out. You were not charged.',
        [retry],
      ),
      'under_review' => state(
        Icons.hourglass_empty,
        'Payment under review',
        'We are checking this payment. Access unlocks once it is confirmed.',
        [done],
      ),
      'still_waiting' => state(
        Icons.hourglass_empty,
        'Still waiting for M-Pesa',
        'If you entered your PIN, the payment may still arrive. Nothing '
            'unlocks until M-Pesa confirms it.',
        [
          FilledButton(
            onPressed: _checkAgain,
            child: const Text('Check again'),
          ),
          done,
        ],
      ),
      _ => state(
        Icons.phone_android,
        'Check your phone',
        'Enter your M-Pesa PIN on the prompt to pay '
            '${formatKes(order['totalCents'] as int)}. Waiting for M-Pesa to '
            'confirm…',
        [const LinearProgressIndicator()],
      ),
    };
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.order});
  final Json order;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget row(String label, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: bold ? text.titleLarge : text.bodyLarge),
          ),
          Text(
            value,
            style: bold
                ? text.titleLarge?.copyWith(fontFeatures: _tabular)
                : text.bodyLarge?.copyWith(fontFeatures: _tabular),
          ),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order['description'] as String,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            row('Price', formatKes(order['amountCents'] as int)),
            row('Fees', formatKes(order['feesCents'] as int)),
            const Divider(height: 24),
            row('Total', formatKes(order['totalCents'] as int), bold: true),
            const SizedBox(height: 8),
            Text(
              order['recurring'] == true
                  ? 'Renews every month until you cancel. Cancel any time in '
                        'My library.'
                  : 'One-time payment. No renewal.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// IT.md F8, F9 and F11: purchases, receipts, refunds and subscriptions.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  Future<void> _refund(BuildContext context, WidgetRef ref, Json order) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request a refund'),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(labelText: 'What went wrong?'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send request'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(dioProvider)
          .post<void>(
            '/orders/${order['id']}/refund-requests',
            data: {'reason': reason.text.trim()},
          );
      ref.invalidate(purchasesProvider);
      if (context.mounted) _snack(context, 'Refund request sent');
    } catch (e) {
      if (context.mounted) _snack(context, apiErrorMessage(e));
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, Json sub) async {
    final ends = _date(context, sub['endsAt'] as String);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel subscription?'),
        content: Text('It will not renew. You keep access until $ends.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel subscription'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(dioProvider)
          .post<void>('/subscriptions/${sub['id']}/cancel');
      ref.invalidate(subscriptionsProvider);
    } catch (e) {
      if (context.mounted) _snack(context, apiErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My library'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Purchases'),
              Tab(text: 'Subscriptions'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            asyncBody(
              ref.watch(purchasesProvider),
              () => ref.invalidate(purchasesProvider),
              (orders) => orders.isEmpty
                  ? const Center(child: Text('Nothing bought yet'))
                  : ListView(
                      children: [
                        for (final o in orders)
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: _TonalIcon(
                              o['type'] == 'post'
                                  ? Icons.lock_open
                                  : Icons.autorenew,
                            ),
                            title: Text(o['description'] as String),
                            subtitle: Text(
                              '${formatKes(o['totalCents'] as int)} · '
                              '${orderStatusLabels[o['status']] ?? o['status']} · '
                              '${_date(context, o['createdAt'] as String)}',
                            ),
                            onTap: o['type'] == 'post'
                                ? () => context.push('/p/${o['itemId']}')
                                : null,
                            trailing: o['status'] == 'paid'
                                ? PopupMenuButton<String>(
                                    onSelected: (_) => _refund(context, ref, o),
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'refund',
                                        child: Text('Request refund'),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                      ],
                    ),
            ),
            asyncBody(
              ref.watch(subscriptionsProvider),
              () => ref.invalidate(subscriptionsProvider),
              (subs) => subs.isEmpty
                  ? const Center(child: Text('No subscriptions'))
                  : ListView(
                      children: [
                        for (final s in subs)
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: const _TonalIcon(Icons.star_outline),
                            title: Text('@${(s['creator'] as Json)['handle']}'),
                            subtitle: Text(
                              '${formatKes(s['priceCents'] as int)}/month · '
                              '${s['status'] == 'active' ? 'Renews ${_date(context, s['renewsAt'] as String)}' : 'Ends ${_date(context, s['endsAt'] as String)}'}',
                            ),
                            trailing: s['status'] == 'active'
                                ? TextButton(
                                    onPressed: () => _cancel(context, ref, s),
                                    child: const Text('Cancel'),
                                  )
                                : const Text('Cancelled'),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// IT.md C10. Every figure comes from the server's ledger.
class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: asyncBody(
        ref.watch(earningsProvider),
        () {
          ref.invalidate(earningsProvider);
        },
        (e) {
          Widget bucket(String label, String key) => Expanded(
            child: Column(
              children: [
                Text(
                  formatKes(e[key] as int),
                  style: text.titleMedium?.copyWith(fontFeatures: _tabular),
                ),
                Text(label, style: text.bodySmall),
              ],
            ),
          );
          final canPay =
              (e['availableCents'] as int) >= (e['payoutMinimumCents'] as int);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(transactionsProvider);
              ref.invalidate(payoutRequestsProvider);
              ref.invalidate(earningsProvider);
              await ref.read(earningsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text('Available', style: text.labelLarge),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatKes(e['availableCents'] as int),
                            key: const ValueKey('earnings-available'),
                            style: text.displaySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontFeatures: _tabular,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            bucket('Pending', 'pendingCents'),
                            bucket('Reserved', 'reservedCents'),
                            bucket('Paid out', 'paidOutCents'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: canPay
                              ? () => context.push('/earnings/payout')
                              : null,
                          child: const Text('Request payout'),
                        ),
                        if (!canPay)
                          Text(
                            'You can request a payout from '
                            '${formatKes(e['payoutMinimumCents'] as int)}.',
                            style: text.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Platform commission: ${e['commissionPercent']}% under your '
                  'agreement. New earnings stay pending until settlement.',
                  style: text.bodySmall,
                ),
                const SizedBox(height: 16),
                _PayoutHistory(),
                Text('Transactions', style: text.titleMedium),
                _Transactions(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PayoutHistory extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payouts = ref.watch(payoutRequestsProvider).valueOrNull ?? const [];
    if (payouts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payout requests', style: Theme.of(context).textTheme.titleMedium),
        for (final p in payouts)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const _TonalIcon(Icons.outbox),
            title: Text(
              formatKes(p['amountCents'] as int),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontFeatures: _tabular),
            ),
            subtitle: Text(
              '${p['destination']} · ${_date(context, p['createdAt'] as String)}',
            ),
            trailing: Chip(
              label: Text(_payoutLabels[p['status']] ?? '${p['status']}'),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

const _payoutLabels = {
  'requested': 'Requested',
  'under_review': 'In review',
  'approved': 'Approved',
  'processing': 'Processing',
  'paid': 'Paid',
  'failed': 'Failed',
  'cancelled': 'Cancelled',
};

class _Transactions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(transactionsProvider).valueOrNull ?? const [];
    return Column(
      children: [
        for (final t in txs)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            shape: const Border(),
            collapsedShape: const Border(),
            leading: _TonalIcon(
              (t['netCents'] as int) < 0
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
            ),
            title: Text(t['description'] as String),
            subtitle: Text(_date(context, t['createdAt'] as String)),
            trailing: Text(
              ((t['netCents'] as int) < 0 ? '' : '+') +
                  formatKes(t['netCents'] as int),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontFeatures: _tabular,
                color: (t['netCents'] as int) < 0
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            childrenPadding: const EdgeInsets.only(bottom: 12),
            children: [
              for (final (label, key) in [
                ('Gross', 'grossCents'),
                ('Commission', 'commissionCents'),
                ('Processing fees', 'feesCents'),
                ('Net', 'netCents'),
              ])
                Row(
                  children: [
                    Expanded(child: Text(label)),
                    Text(
                      formatKes(t[key] as int),
                      style: const TextStyle(fontFeatures: _tabular),
                    ),
                  ],
                ),
              Row(
                children: [
                  Expanded(child: Text('Status · ${t['status']}')),
                  if (t['contractRef'] != null)
                    Text('Agreement ${t['contractRef']}'),
                ],
              ),
            ],
          ),
      ],
    );
  }
}

/// IT.md C11.
class PayoutRequestScreen extends ConsumerStatefulWidget {
  const PayoutRequestScreen({super.key});

  @override
  ConsumerState<PayoutRequestScreen> createState() =>
      _PayoutRequestScreenState();
}

class _PayoutRequestScreenState extends ConsumerState<PayoutRequestScreen> {
  final _amount = TextEditingController();
  final _key = newIdempotencyKey();
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit(Json earnings, Json method) async {
    final kes = int.tryParse(_amount.text);
    final min = earnings['payoutMinimumCents'] as int;
    final max = earnings['payoutMaximumCents'] as int;
    final available = earnings['availableCents'] as int;
    if (kes == null || kes * 100 < min || kes * 100 > max) {
      return _snack(
        context,
        'Enter between ${formatKes(min)} and ${formatKes(max)}',
      );
    }
    if (kes * 100 > available) {
      return _snack(context, 'That is more than your available balance');
    }
    // Re-authenticate before money leaves (IT.md C11 step 4).
    final bool confirmed;
    if (ref.read(lockProvider).hasPin == true) {
      confirmed = await showPinSheet(context, ref);
    } else {
      confirmed =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Confirm payout'),
              content: Text(
                'Send ${formatKes(kes * 100)} to ${method['phoneMasked']}?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ) ==
          true;
    }
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(dioProvider)
          .post<void>(
            '/creators/me/payout-requests',
            data: {
              'amountCents': kes * 100,
              'payoutMethodId': method['id'],
              'idempotencyKey': _key,
            },
          );
      ref.invalidate(earningsProvider);
      ref.invalidate(payoutRequestsProvider);
      if (!mounted) return;
      _snack(context, 'Payout requested');
      context.pop();
    } catch (e) {
      if (mounted) _snack(context, apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final earnings = ref.watch(earningsProvider).valueOrNull;
    final methods = ref.watch(payoutMethodsProvider).valueOrNull;
    final method = methods?.where((m) => m['verified'] == true).firstOrNull;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Request payout')),
      body: earnings == null || methods == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Available', style: text.labelLarge),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatKes(earnings['availableCents'] as int),
                            style: text.displaySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontFeatures: _tabular,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Minimum ${formatKes(earnings['payoutMinimumCents'] as int)}'
                          ' · maximum ${formatKes(earnings['payoutMaximumCents'] as int)}',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (method == null)
                  ListTile(
                    leading: const Icon(Icons.warning_amber),
                    title: const Text('Add and verify an M-Pesa number first'),
                    onTap: () => context.push('/onboarding/payout'),
                  )
                else ...[
                  Card(
                    child: ListTile(
                      leading: const _TonalIcon(Icons.phone_android),
                      title: Text('M-Pesa ${method['phoneMasked']}'),
                      subtitle: Text('${method['accountName']}'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('payout-amount'),
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: 'KSh ',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No payout fee. Payouts are reviewed and usually reach '
                    'M-Pesa within 1–2 working days.',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const ValueKey('payout-submit'),
                    onPressed: _busy ? null : () => _submit(earnings, method),
                    child: const Text('Request payout'),
                  ),
                ],
              ],
            ),
    );
  }
}
