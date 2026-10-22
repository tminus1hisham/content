import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../auth/auth_controller.dart';

/// `GET /creators/me/onboarding` (IT.md C6, FR-CRT-002).
class OnboardingStatus {
  const OnboardingStatus({
    required this.status,
    required this.identity,
    required this.profile,
    required this.contract,
    required this.payout,
    required this.readyToSubmit,
  });

  factory OnboardingStatus.fromJson(Map<String, dynamic> json) {
    final steps = json['steps'] as Map<String, dynamic>;
    return OnboardingStatus(
      status: json['status'] as String,
      identity: steps['identity'] as String,
      profile: steps['profile'] as bool,
      contract: steps['contract'] as bool,
      payout: steps['payout'] as bool,
      readyToSubmit: json['readyToSubmit'] as bool,
    );
  }

  /// incomplete | submitted | under_review | action_required | approved |
  /// rejected | suspended
  final String status;

  /// not_started | pending | verified | failed
  final String identity;
  final bool profile;
  final bool contract;
  final bool payout;
  final bool readyToSubmit;

  bool get approved => status == 'approved';
}

/// Invalidate after any onboarding step to re-read the server's view.
final onboardingProvider = FutureProvider<OnboardingStatus>((ref) async {
  ref.watch(authProvider.select((s) => s.user?.id));
  final response = await ref
      .read(dioProvider)
      .get<Map<String, dynamic>>('/creators/me/onboarding');
  return OnboardingStatus.fromJson(response.data!);
});

/// Monetising (paid posts, live tickets, payouts) needs an approved creator
/// (FR-CRT-004). The server enforces this too.
final creatorApprovedProvider = Provider<bool>(
  (ref) => ref.watch(onboardingProvider).valueOrNull?.approved ?? false,
);

const statusLabels = {
  'incomplete': 'Incomplete',
  'submitted': 'Submitted',
  'under_review': 'Under review',
  'action_required': 'Action required',
  'approved': 'Approved',
  'rejected': 'Rejected',
  'suspended': 'Suspended',
};
