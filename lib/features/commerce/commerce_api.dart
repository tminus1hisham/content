import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

/// Read-only views of server records. Amounts are integer cents in KES and
/// are only ever displayed, never computed here (IT.md §9.10).
typedef Json = Map<String, dynamic>;

Future<List<Json>> _list(Ref ref, String path) async =>
    ((await ref.read(dioProvider).get<List<dynamic>>(path)).data!).cast<Json>();

Future<Json> _object(Ref ref, String path) async =>
    (await ref.read(dioProvider).get<Json>(path)).data!;

final tiersProvider = FutureProvider.autoDispose.family<List<Json>, String>(
  (ref, creatorId) => _list(ref, '/creators/$creatorId/subscription-tiers'),
);

final purchasesProvider = FutureProvider.autoDispose<List<Json>>(
  (ref) => _list(ref, '/fans/me/purchases'),
);

final subscriptionsProvider = FutureProvider.autoDispose<List<Json>>(
  (ref) => _list(ref, '/fans/me/subscriptions'),
);

final earningsProvider = FutureProvider.autoDispose<Json>(
  (ref) => _object(ref, '/creators/me/earnings'),
);

final transactionsProvider = FutureProvider.autoDispose<List<Json>>(
  (ref) => _list(ref, '/creators/me/transactions'),
);

final payoutRequestsProvider = FutureProvider.autoDispose<List<Json>>(
  (ref) => _list(ref, '/creators/me/payout-requests'),
);

final payoutMethodsProvider = FutureProvider.autoDispose<List<Json>>(
  (ref) => _list(ref, '/creators/me/payout-methods'),
);

/// One per user action, so retries of the same action are de-duplicated by
/// the server (FR-PAY-004).
String newIdempotencyKey() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// Payment states from IT.md §10.3 that end the wait.
const terminalPaymentStates = {
  'succeeded',
  'failed',
  'cancelled',
  'expired',
  'reversed',
  'under_review',
};

const orderStatusLabels = {
  'paid': 'Paid',
  'refund_requested': 'Refund requested',
  'refunded': 'Refunded',
  'created': 'Not paid',
};
