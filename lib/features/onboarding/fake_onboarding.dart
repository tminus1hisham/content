import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../core/fake_backend.dart';
import '../auth/fake_auth.dart';

/// In-memory creator onboarding, contracts and payout destinations
/// (IT.md §9.3–9.5, §9.10). The payout OTP is [fakeOtp].
const contractSections = [
  (
    'Commercial terms',
    'You set your own prices. The platform keeps the commission below on '
        'every sale and pays you the rest.',
  ),
  (
    'Platform commission',
    'The platform commission is 20% of each successful transaction, '
        'including subscriptions, single items, tips and live tickets.',
  ),
  (
    'Payment and payout terms',
    'Earnings become available after the settlement period. You can request '
        'a payout to your verified M-Pesa number once you reach the minimum.',
  ),
  (
    'Content ownership and licensing',
    'You keep ownership of your content. You give the platform a limited '
        'licence to store, process and show it to fans who are allowed to see it.',
  ),
  (
    'Content rules and consent',
    'Everyone who appears in your content must be an adult who has given '
        'documented consent. Prohibited content is removed and may be reported.',
  ),
  (
    'Refunds and chargebacks',
    'Refunds and chargebacks reverse the related earnings as shown in your '
        'statement.',
  ),
  (
    'Privacy and termination',
    'Either party may end this agreement with notice. Earned balances are '
        'paid out according to these terms.',
  ),
  (
    'Dispute resolution',
    'Disputes are first raised with support, then resolved under the laws '
        'of Kenya.',
  ),
];

const _offerId = 'offer-standard';
const _offerVersion = 'v1.0';
const takenHandles = {'amani'};

String _documentHash() => sha256
    .convert(
      utf8.encode(
        '$_offerVersion\n${contractSections.map((s) => '${s.$1}\n${s.$2}').join('\n')}',
      ),
    )
    .toString();

class _Creator {
  String identity = 'not_started'; // not_started | pending | verified | failed
  Map<String, Object?>? profile;
  Map<String, Object?>? contract;
  Map<String, Object?>? payout;
  String? reviewStatus; // null until submitted
}

class FakeOnboardingDb {
  final _creators = <String, _Creator>{};

  FakeOnboardingDb() {
    reset();
  }

  void reset() {
    _creators.clear();
    // creator@demo.ke is fully approved.
    _creators['u2'] = _Creator()
      ..identity = 'verified'
      ..profile = {
        'displayName': 'Amani',
        'handle': 'amani',
        'bio': 'Dancer and storyteller from Nairobi.',
        'categories': ['Dance', 'Lifestyle'],
        'language': 'en',
        'location': 'Nairobi',
        'discoverable': true,
      }
      ..contract = {
        'id': 'contract-u2',
        'version': _offerVersion,
        'documentHash': _documentHash(),
        'signedAt': '2026-10-01T09:00:00Z',
        'signatureName': 'Amani Wanjiru',
      }
      ..payout = {
        'id': 'pm-u2',
        'type': 'mpesa',
        'phone': '+254712000111',
        'accountName': 'Amani Wanjiru',
        'verified': true,
      }
      ..reviewStatus = 'approved';
  }

  /// Fake admin action (M9 adds the real admin screens).
  void approve(String userId) => _creators[userId]?.reviewStatus = 'approved';

  Iterable<String> get approvedIds => _creators.keys.where(isApproved);

  bool isApproved(String userId) =>
      _creators[userId]?.reviewStatus == 'approved';

  Map<String, Object?>? profileOf(String userId) => _creators[userId]?.profile;

  Map<String, Object?>? payoutOf(String userId) => _creators[userId]?.payout;

  (int, Object?) _withCreator(
    RequestOptions req,
    (int, Object?) Function(String userId, _Creator creator) handle,
  ) {
    final userId = fakeAuthDb.callerId(req);
    if (userId == null) return FakeAuthDb.unauthorized;
    return handle(userId, _creators.putIfAbsent(userId, _Creator.new));
  }

  static String _maskPhone(String phone) =>
      '${phone.substring(0, 4)} ••• ${phone.substring(phone.length - 3)}';

  Map<String, Object?> _onboarding(_Creator c) {
    final steps = {
      'contact': true,
      'identity': c.identity,
      'profile': c.profile != null,
      'contract': c.contract != null,
      'payout': c.payout?['verified'] == true,
    };
    final complete =
        c.identity == 'verified' &&
        c.profile != null &&
        c.contract != null &&
        c.payout?['verified'] == true;
    return {
      'status':
          c.reviewStatus ??
          (c.identity == 'failed' ? 'action_required' : 'incomplete'),
      'steps': steps,
      'readyToSubmit': complete && c.reviewStatus == null,
    };
  }

  Map<String, Object?> _payoutJson(Map<String, Object?> p) => {
    'id': p['id'],
    'type': p['type'],
    'phoneMasked': _maskPhone(p['phone'] as String),
    'accountName': p['accountName'],
    'verified': p['verified'],
  };

  Map<String, FakeHandler> get routes => {
    'GET /creators/me/onboarding': (req, _) =>
        _withCreator(req, (_, c) => (200, _onboarding(c))),
    'POST /creators/me/submit-review': (req, _) => _withCreator(req, (_, c) {
      if (_onboarding(c)['readyToSubmit'] != true) {
        return (
          400,
          {
            'code': 'ONBOARDING_INCOMPLETE',
            'message': 'Finish every step first',
          },
        );
      }
      c.reviewStatus = 'under_review';
      return (200, _onboarding(c));
    }),
    // Real flow: the app opens the provider and the provider calls our
    // webhook. The fake verifies on the first status check.
    'POST /verification/sessions': (req, _) => _withCreator(req, (_, c) {
      c.identity = 'pending';
      return (201, {'sessionId': 'vs-1', 'status': 'pending'});
    }),
    'GET /verification/status': (req, _) => _withCreator(req, (_, c) {
      if (c.identity == 'pending') c.identity = 'verified';
      return (200, {'status': c.identity});
    }),
    'GET /creators/me': (req, _) => _withCreator(
      req,
      (_, c) => c.profile == null
          ? (404, {'code': 'NOT_FOUND', 'message': 'No profile yet'})
          : (200, c.profile),
    ),
    'PATCH /creators/me': (req, _) => _withCreator(req, (userId, c) {
      final body = Map<String, Object?>.from(req.data as Map);
      final handle = (body['handle'] as String? ?? '').toLowerCase();
      if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(handle)) {
        return (
          400,
          {
            'code': 'INVALID_HANDLE',
            'message': 'Use 3-20 letters, numbers or underscores',
          },
        );
      }
      final ownHandle = c.profile?['handle'];
      final takenByOther = _creators.entries.any(
        (e) => e.key != userId && e.value.profile?['handle'] == handle,
      );
      if (handle != ownHandle &&
          (takenByOther || takenHandles.contains(handle))) {
        return (
          409,
          {'code': 'HANDLE_TAKEN', 'message': 'That handle is taken'},
        );
      }
      c.profile = {...body, 'handle': handle};
      return (200, c.profile);
    }),
    'GET /contracts/offers': (req, _) => _withCreator(
      req,
      (_, c) => (
        200,
        c.contract != null
            ? <Object>[]
            : [
                {
                  'id': _offerId,
                  'title': 'Creator agreement',
                  'version': _offerVersion,
                  'commissionPercent': 20,
                },
              ],
      ),
    ),
    'GET /contracts/offers/{id}': (req, params) => params['id'] != _offerId
        ? (404, {'code': 'NOT_FOUND', 'message': 'No such offer'})
        : (
            200,
            {
              'id': _offerId,
              'title': 'Creator agreement',
              'version': _offerVersion,
              'commissionPercent': 20,
              'documentHash': _documentHash(),
              'sections': [
                for (final (heading, body) in contractSections)
                  {'heading': heading, 'body': body},
              ],
            },
          ),
    'POST /contracts/offers/{id}/sign': (req, params) =>
        _withCreator(req, (userId, c) {
          final body = req.data as Map;
          if (params['id'] != _offerId ||
              body['version'] != _offerVersion ||
              body['documentHash'] != _documentHash()) {
            return (
              409,
              {
                'code': 'VERSION_MISMATCH',
                'message': 'The agreement changed. Read the latest version.',
              },
            );
          }
          if (body['consentToElectronicSignature'] != true ||
              (body['signatureName'] as String? ?? '').trim().length < 3) {
            return (
              400,
              {
                'code': 'SIGNATURE_INVALID',
                'message': 'Type your full name and consent',
              },
            );
          }
          c.contract = {
            'id': 'contract-$userId',
            'version': _offerVersion,
            'documentHash': _documentHash(),
            'signedAt': DateTime.now().toUtc().toIso8601String(),
            'signatureName': (body['signatureName'] as String).trim(),
          };
          return (201, c.contract);
        }),
    'POST /contracts/offers/{id}/decline': (_, _) => (204, null),
    'GET /creators/me/contracts': (req, _) =>
        _withCreator(req, (_, c) => (200, [?c.contract])),
    'GET /creators/me/payout-methods': (req, _) => _withCreator(
      req,
      (_, c) => (200, [if (c.payout != null) _payoutJson(c.payout!)]),
    ),
    'POST /creators/me/payout-methods': (req, _) =>
        _withCreator(req, (userId, c) {
          final body = req.data as Map;
          final phone = body['phone'] as String? ?? '';
          if (!RegExp(r'^\+254[17]\d{8}$').hasMatch(phone)) {
            return (
              400,
              {
                'code': 'INVALID_DESTINATION',
                'message': 'Enter a Kenyan M-Pesa number',
              },
            );
          }
          // Replacing a destination needs verifying again (IT.md C5).
          c.payout = {
            'id': 'pm-$userId-${DateTime.now().microsecondsSinceEpoch}',
            'type': 'mpesa',
            'phone': phone,
            'accountName': body['accountName'],
            'verified': false,
          };
          return (201, _payoutJson(c.payout!));
        }),
    'POST /creators/me/payout-methods/{id}/verify': (req, params) =>
        _withCreator(req, (_, c) {
          if (c.payout?['id'] != params['id']) {
            return (404, {'code': 'NOT_FOUND', 'message': 'No such method'});
          }
          if ((req.data as Map)['code'] != fakeOtp) {
            return (400, {'code': 'INVALID_CODE', 'message': 'Wrong code'});
          }
          c.payout!['verified'] = true;
          return (200, _payoutJson(c.payout!));
        }),
  };
}

final fakeOnboardingDb = FakeOnboardingDb();
