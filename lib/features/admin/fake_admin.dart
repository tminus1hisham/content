import 'package:dio/dio.dart';

import '../../core/fake_backend.dart';
import '../auth/fake_auth.dart';
import '../commerce/fake_commerce.dart';
import '../content/fake_content.dart';
import '../messages/fake_messaging.dart';
import '../onboarding/fake_onboarding.dart';

/// In-memory staff API (IT.md §5.4, §7, §9.13). Staff sign in with password
/// plus an MFA code ([fakeOtp]); every route checks one granular permission.
abstract final class Perm {
  static const creatorReview = 'creator.verification.review';
  static const moderationRead = 'moderation.case.read';
  static const moderationResolve = 'moderation.case.resolve';
  static const payoutApprove = 'finance.payout.approve';
  static const payoutInitiate = 'finance.payout.initiate';
  static const contracts = 'contracts.template.manage';
  static const config = 'admin.config.manage';
  static const roles = 'admin.roles.manage';
  static const audit = 'audit.sensitive_access.read';
  static const all = [
    creatorReview,
    moderationRead,
    moderationResolve,
    payoutApprove,
    payoutInitiate,
    contracts,
    config,
    roles,
    audit,
  ];
}

class _Staff {
  const _Staff(this.id, this.email, this.name, this.role, this.permissions);
  final String id;
  final String email;
  final String name;
  final String role;
  final List<String> permissions;

  Map<String, Object?> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'role': role,
    'permissions': permissions,
    'mfaEnabled': true,
  };
}

const _finance = [Perm.payoutApprove, Perm.payoutInitiate];

class FakeAdminDb {
  static const _staff = [
    _Staff('s1', 'admin@staff.ke', 'Achieng Odhiambo', 'Super admin', Perm.all),
    _Staff('s2', 'mod@staff.ke', 'Otieno Barasa', 'Moderator', [
      Perm.moderationRead,
      Perm.moderationResolve,
    ]),
    _Staff('s3', 'finance@staff.ke', 'Wambui Njeri', 'Finance', _finance),
    _Staff('s4', 'finance2@staff.ke', 'Kamau Mwangi', 'Finance', _finance),
  ];
  static const _password = 'password123';

  final _tokens = <String, String>{}; // token -> staff id
  final audit = <Map<String, Object?>>[];
  var _seq = 0;

  FakeAdminDb() {
    reset();
  }

  void reset() {
    _tokens.clear();
    audit.clear();
    _seq = 0;
  }

  /// A signed-in staff token, for tests and demos.
  String tokenFor(String email) {
    final staff = _staff.firstWhere((s) => s.email == email);
    final token = 'fake-staff-${staff.id}-${++_seq}';
    _tokens[token] = staff.id;
    return token;
  }

  void _log(_Staff staff, String action, String target, [Object? detail]) =>
      audit.insert(0, {
        'at': DateTime.now().toUtc().toIso8601String(),
        'staff': staff.email,
        'action': action,
        'target': target,
        'detail': detail,
      });

  (int, Object?) _as(
    RequestOptions req,
    String? permission,
    (int, Object?) Function(_Staff staff) handle,
  ) {
    final header = req.headers['Authorization'] as String?;
    final id = _tokens[header?.replaceFirst('Bearer ', '')];
    final staff = _staff.where((s) => s.id == id).firstOrNull;
    if (staff == null) return FakeAuthDb.unauthorized;
    if (permission != null && !staff.permissions.contains(permission)) {
      return _error(403, 'FORBIDDEN', 'You do not have access to this');
    }
    return handle(staff);
  }

  static (int, Object?) _error(int status, String code, String message) =>
      (status, {'code': code, 'message': message});

  static const _decisions = {
    'approve': 'approved',
    'request_info': 'action_required',
    'reject': 'rejected',
    'suspend': 'suspended',
  };

  Map<String, FakeHandler> get routes => {
    'POST /admin/auth/login': (req, _) {
      final body = req.data as Map;
      final staff = _staff.where((s) => s.email == body['email']).firstOrNull;
      if (staff == null || body['password'] != _password) {
        return _error(401, 'INVALID_CREDENTIALS', 'Wrong email or password');
      }
      if (body['mfaCode'] == null || body['mfaCode'] == '') {
        return _error(401, 'MFA_REQUIRED', 'Enter your authenticator code');
      }
      if (body['mfaCode'] != fakeOtp) {
        return _error(401, 'MFA_INVALID', 'That code is not right');
      }
      final token = tokenFor(staff.email);
      _log(staff, 'staff.login', staff.email);
      return (
        200,
        {'accessToken': token, 'refreshToken': '', 'staff': staff.toJson()},
      );
    },
    'GET /admin/me': (req, _) => _as(req, null, (s) => (200, s.toJson())),
    'GET /admin/dashboard': (req, _) => _as(req, null, (_) {
      final open = fakeMessagingDb.reports.where((r) => r['status'] == 'open');
      return (
        200,
        {
          'pendingCreators': fakeOnboardingDb
              .idsWithStatus('under_review')
              .length,
          'openReports': open.length,
          'urgentReports': open.where((r) => r['priority'] == 'urgent').length,
          'payoutsToReview':
              fakeCommerceDb.payoutsFor('requested').length +
              fakeCommerceDb.payoutsFor('approved').length,
          'reconciliationExceptions': 0,
        },
      );
    }),
    'GET /admin/creators': (req, _) => _as(req, Perm.creatorReview, (_) {
      final status = req.queryParameters['status'] as String? ?? 'under_review';
      return (
        200,
        [
          for (final id in fakeOnboardingDb.idsWithStatus(status))
            fakeOnboardingDb.reviewSummary(id),
        ],
      );
    }),
    'POST /admin/creators/{id}/review': (req, params) =>
        _as(req, Perm.creatorReview, (staff) {
          final body = req.data as Map;
          final status = _decisions[body['decision']];
          final reason = (body['reason'] as String? ?? '').trim();
          if (status == null) {
            return _error(400, 'INVALID_DECISION', 'Choose a decision');
          }
          if (status != 'approved' && reason.isEmpty) {
            return _error(400, 'REASON_REQUIRED', 'Give the creator a reason');
          }
          if (fakeOnboardingDb.reviewSummary(params['id']!) == null) {
            return _error(404, 'NOT_FOUND', 'Not found');
          }
          fakeOnboardingDb.setReviewStatus(params['id']!, status);
          _log(staff, 'creator.review.$status', params['id']!, reason);
          return (200, fakeOnboardingDb.reviewSummary(params['id']!));
        }),
    'GET /admin/moderation/cases': (req, _) =>
        _as(req, Perm.moderationRead, (_) {
          final cases = [...fakeMessagingDb.reports]
            ..sort((a, b) {
              final urgent = (b['priority'] == 'urgent' ? 1 : 0).compareTo(
                a['priority'] == 'urgent' ? 1 : 0,
              );
              return urgent != 0
                  ? urgent
                  : '${a['createdAt']}'.compareTo('${b['createdAt']}');
            });
          // Staff see the case, not the reporter's identity details.
          return (
            200,
            [
              for (final c in cases) {...c, 'reporterId': null},
            ],
          );
        }),
    'POST /admin/moderation/cases/{id}/actions': (req, params) =>
        _as(req, Perm.moderationResolve, (staff) {
          final report = fakeMessagingDb.reports
              .where((r) => r['caseId'] == params['id'])
              .firstOrNull;
          if (report == null) return _error(404, 'NOT_FOUND', 'Not found');
          final body = req.data as Map;
          final action = body['action'];
          final reasonCode = body['reasonCode'] as String?;
          if (reasonCode == null || reasonCode.isEmpty) {
            return _error(400, 'REASON_REQUIRED', 'Choose a reason code');
          }
          switch (action) {
            case 'dismiss':
              break;
            case 'restrict_content' when report['targetType'] == 'post':
              fakeContentDb.restrictPost(report['targetId'] as String);
            case 'suspend_user' when report['targetType'] == 'user':
              fakeOnboardingDb.setReviewStatus(
                report['targetId'] as String,
                'suspended',
              );
            default:
              return _error(400, 'INVALID_ACTION', 'That action does not fit');
          }
          report
            ..['status'] = 'resolved'
            ..['decision'] = action
            ..['reasonCode'] = reasonCode
            ..['resolvedBy'] = staff.email;
          _log(staff, 'moderation.$action', params['id']!, reasonCode);
          return (200, report);
        }),
    'GET /admin/payouts': (req, _) => _as(
      req,
      Perm.payoutApprove,
      (_) => (
        200,
        fakeCommerceDb.payoutsFor(req.queryParameters['status'] as String?),
      ),
    ),
    'POST /admin/payouts/{id}/approve': (req, params) =>
        _as(req, Perm.payoutApprove, (staff) {
          final result = fakeCommerceDb.approvePayout(params['id']!, staff.id);
          if (result.$1 == 200) _log(staff, 'payout.approve', params['id']!);
          return result;
        }),
    'POST /admin/payouts/{id}/submit': (req, params) =>
        _as(req, Perm.payoutInitiate, (staff) {
          final result = fakeCommerceDb.submitPayout(params['id']!, staff.id);
          if (result.$1 == 200) _log(staff, 'payout.submit', params['id']!);
          return result;
        }),
    'POST /admin/payouts/{id}/reject': (req, params) => _as(
      req,
      Perm.payoutApprove,
      (staff) {
        final reason = ((req.data as Map?)?['reason'] as String? ?? '').trim();
        if (reason.isEmpty) {
          return _error(400, 'REASON_REQUIRED', 'Give the creator a reason');
        }
        final result = fakeCommerceDb.rejectPayout(params['id']!, reason);
        if (result.$1 == 200) {
          _log(staff, 'payout.reject', params['id']!, reason);
        }
        return result;
      },
    ),
    'GET /admin/contracts/templates': (req, _) => _as(
      req,
      Perm.contracts,
      (_) => (
        200,
        [
          {
            'id': 'standard',
            'title': 'Creator agreement',
            'versions': [
              {
                'version': 'v1.0',
                'status': 'published',
                'commissionPercent': commissionPercent,
                'effectiveFrom': '2026-09-01',
                'signedCount': fakeOnboardingDb.signedContracts,
              },
            ],
          },
        ],
      ),
    ),
    'GET /admin/configuration': (req, _) => _as(
      req,
      null,
      (_) => (
        200,
        {
          'commissionPercent': currentCommissionPercent,
          'minPriceCents': minPriceCents,
          'maxPriceCents': maxPriceCents,
          'payoutMinimumCents': payoutMinimumCents,
          'currencies': ['KES'],
          'countries': ['KE'],
        },
      ),
    ),
    'PATCH /admin/configuration/{key}': (req, params) => _as(req, Perm.config, (
      staff,
    ) {
      if (params['key'] != 'commissionPercent') {
        return _error(400, 'NOT_EDITABLE', 'This setting is read-only');
      }
      final value = (req.data as Map)['value'];
      if (value is! int || value < 0 || value > 50) {
        return _error(400, 'INVALID_VALUE', 'Use a whole number 0-50');
      }
      final before = currentCommissionPercent;
      currentCommissionPercent = value;
      _log(staff, 'config.commissionPercent', 'platform', '$before -> $value');
      return (200, {'commissionPercent': value});
    }),
    'GET /admin/audit-events': (req, _) =>
        _as(req, Perm.audit, (_) => (200, audit)),
    'GET /admin/staff': (req, _) => _as(
      req,
      Perm.roles,
      (_) => (200, [for (final s in _staff) s.toJson()]),
    ),
  };
}

final fakeAdminDb = FakeAdminDb();
