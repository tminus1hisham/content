import 'package:content/core/api_client.dart';
import 'package:content/core/fake_backend.dart';
import 'package:content/core/prefs.dart';
import 'package:content/features/admin/admin_app.dart';
import 'package:content/features/admin/fake_admin.dart';
import 'package:content/features/auth/fake_auth.dart';
import 'package:content/features/commerce/fake_commerce.dart';
import 'package:content/features/onboarding/fake_onboarding.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Dio signed in as [staffEmail] (staff) or [userEmail] (app user).
Future<Dio> _dio({String? staffEmail, String? userEmail}) async {
  fakeLatency = Duration.zero;
  final token = staffEmail != null
      ? fakeAdminDb.tokenFor(staffEmail)
      : userEmail != null
      ? fakeAuthDb.sessionFor(userEmail)['accessToken'] as String
      : null;
  FlutterSecureStorage.setMockInitialValues({accessTokenKey: ?token});
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container.read(dioProvider);
}

Future<String?> _code(Future<Object?> request) =>
    request.then<String?>((_) => null, onError: (Object e) => apiErrorCode(e));

int _ledgerTotal() =>
    fakeCommerceDb.ledger.fold<int>(0, (sum, e) => sum + e.amountCents);

Future<void> _pumpAdmin(WidgetTester tester) async {
  fakeLatency = Duration.zero;
  resetFakeBackend();
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const AdminApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _signIn(WidgetTester tester, String email) async {
  await tester.enterText(find.byKey(const ValueKey('admin-email')), email);
  await tester.enterText(
    find.byKey(const ValueKey('admin-password')),
    'password123',
  );
  await tester.enterText(find.byKey(const ValueKey('admin-mfa')), fakeOtp);
  await tester.tap(find.byKey(const ValueKey('admin-login')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(resetFakeBackend);

  group('staff API rules', () {
    test('sign-in needs the MFA code', () async {
      final dio = await _dio();
      Future<String?> login(String? code) => _code(
        dio.post<Object?>(
          '/admin/auth/login',
          data: {
            'email': 'admin@staff.ke',
            'password': 'password123',
            'mfaCode': code,
          },
        ),
      );
      expect(await login(null), 'MFA_REQUIRED');
      expect(await login('000000'), 'MFA_INVALID');
      expect(await login(fakeOtp), isNull);
    });

    test('each role only reaches its own tools', () async {
      final mod = await _dio(staffEmail: 'mod@staff.ke');
      expect(await _code(mod.get<Object?>('/admin/payouts')), 'FORBIDDEN');
      final finance = await _dio(staffEmail: 'finance@staff.ke');
      expect(
        await _code(finance.get<Object?>('/admin/moderation/cases')),
        'FORBIDDEN',
      );
      final user = await _dio(userEmail: 'creator@demo.ke');
      expect(
        await _code(user.get<Object?>('/admin/dashboard')),
        'UNAUTHORIZED',
      );
    });

    test('a payout needs two different finance users', () async {
      final paidBefore = fakeCommerceDb.paidOut('u2');
      final first = await _dio(staffEmail: 'finance@staff.ke');
      await first.post<void>('/admin/payouts/po-seed/approve');
      expect(
        await _code(first.post<Object?>('/admin/payouts/po-seed/submit')),
        'DUAL_CONTROL_REQUIRED',
      );
      final second = await _dio(staffEmail: 'finance2@staff.ke');
      expect(
        await _code(second.post<Object?>('/admin/payouts/po-seed/submit')),
        isNull,
      );
      expect(fakeCommerceDb.paidOut('u2'), paidBefore + 500000);
      expect(fakeCommerceDb.balance('u2', 'reserved'), 0);
      expect(_ledgerTotal(), 0);
    });

    test('a rejected payout goes back to available', () async {
      final available = fakeCommerceDb.balance('u2', 'available');
      final finance = await _dio(staffEmail: 'finance@staff.ke');
      expect(
        await _code(finance.post<Object?>('/admin/payouts/po-seed/reject')),
        'REASON_REQUIRED',
      );
      await finance.post<void>(
        '/admin/payouts/po-seed/reject',
        data: {'reason': 'Name does not match M-Pesa account'},
      );
      expect(fakeCommerceDb.balance('u2', 'available'), available + 500000);
      expect(fakeCommerceDb.balance('u2', 'reserved'), 0);
      expect(_ledgerTotal(), 0);
    });

    test(
      'creator review: reasons required, approval unlocks selling',
      () async {
        final admin = await _dio(staffEmail: 'admin@staff.ke');
        expect(
          await _code(
            admin.post<Object?>(
              '/admin/creators/u5/review',
              data: {'decision': 'reject'},
            ),
          ),
          'REASON_REQUIRED',
        );
        await admin.post<void>(
          '/admin/creators/u5/review',
          data: {'decision': 'approve'},
        );
        expect(fakeOnboardingDb.isApproved('u5'), isTrue);
        expect(fakeAdminDb.audit.first['action'], 'creator.review.approved');
      },
    );

    test('restricting reported content hides it from fans', () async {
      final mod = await _dio(staffEmail: 'mod@staff.ke');
      final cases = (await mod.get<List>('/admin/moderation/cases')).data!;
      expect((cases.first as Map)['priority'], 'urgent');
      expect((cases.first as Map)['reporterId'], isNull);
      await mod.post<void>(
        '/admin/moderation/cases/CASE-1000/actions',
        data: {'action': 'restrict_content', 'reasonCode': 'NON_CONSENSUAL'},
      );
      final fan = await _dio(userEmail: 'fan@demo.ke');
      expect(await _code(fan.get<Object?>('/posts/p4')), 'NOT_FOUND');
    });

    test('a commission change only applies to new sales', () async {
      final finance = await _dio(staffEmail: 'finance@staff.ke');
      expect(
        await _code(
          finance.patch<Object?>(
            '/admin/configuration/commissionPercent',
            data: {'value': 10},
          ),
        ),
        'FORBIDDEN',
      );
      final admin = await _dio(staffEmail: 'admin@staff.ke');
      await admin.patch<void>(
        '/admin/configuration/commissionPercent',
        data: {'value': 10},
      );
      expect(FakeCommerceDb.commissionOf(100000), 10000);

      final creator = await _dio(userEmail: 'creator@demo.ke');
      final old =
          (await creator.get<List>(
                '/creators/me/transactions',
              )).data!.firstWhere((t) => t['id'] == 't-seed-1')
              as Map;
      expect(old['commissionCents'], 311250); // still 20%
      expect(fakeAdminDb.audit.first['detail'], '20 -> 10');
    });
  });

  testWidgets('staff sign in with MFA; a moderator sees only moderation', (
    tester,
  ) async {
    await _pumpAdmin(tester);
    expect(find.text('Staff sign in'), findsOneWidget);
    await _signIn(tester, 'mod@staff.ke');

    expect(find.text('Urgent safety cases'), findsOneWidget);
    expect(find.text('Moderation'), findsOneWidget);
    expect(find.text('Payouts'), findsNothing);
    expect(find.text('Creators'), findsNothing);
  });

  testWidgets('admin approves a waiting creator', (tester) async {
    await _pumpAdmin(tester);
    await _signIn(tester, 'admin@staff.ke');
    await tester.tap(find.text('Creators'));
    await tester.pumpAndSettle();
    expect(find.text('Pendo Atieno (@pendo)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('approve-u5')));
    await tester.pumpAndSettle();
    expect(find.text('No creators waiting for review'), findsOneWidget);
  });

  testWidgets('the approver cannot also send the payout', (tester) async {
    await _pumpAdmin(tester);
    await _signIn(tester, 'finance@staff.ke');
    await tester.tap(find.text('Payouts'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('approve-po-seed')));
    await tester.pumpAndSettle();

    final send = tester.widget<FilledButton>(
      find.byKey(const ValueKey('submit-po-seed')),
    );
    expect(send.onPressed, isNull);
    expect(find.text('Needs a second approver'), findsOneWidget);
  });
}
