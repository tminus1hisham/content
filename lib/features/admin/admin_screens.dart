import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../auth/fake_auth.dart';
import '../content/discover_screens.dart';
import 'admin_app.dart';
import 'fake_admin.dart';

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

String _when(BuildContext context, String iso) {
  final at = DateTime.parse(iso).toLocal();
  final l = MaterialLocalizations.of(context);
  return '${l.formatMediumDate(at)} ${l.formatTimeOfDay(TimeOfDay.fromDateTime(at))}';
}

final _listProvider = FutureProvider.autoDispose.family<List<Json>, String>(
  (ref, path) async =>
      ((await ref.read(dioProvider).get<List<dynamic>>(path)).data!)
          .cast<Json>(),
);

final _objectProvider = FutureProvider.autoDispose.family<Json, String>(
  (ref, path) async => (await ref.read(dioProvider).get<Json>(path)).data!,
);

/// Runs a staff action, reports errors, and refreshes [refresh].
Future<void> _act(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action, {
  required String done,
  List<String> refresh = const [],
}) async {
  try {
    await action();
    for (final path in refresh) {
      ref.invalidate(_listProvider(path));
      ref.invalidate(_objectProvider(path));
    }
    if (context.mounted) _snack(context, done);
  } catch (e) {
    if (context.mounted) _snack(context, apiErrorMessage(e));
  }
}

/// Asks for a written reason; null when cancelled.
Future<String?> _askReason(BuildContext context, String title) async {
  final reason = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        key: const ValueKey('admin-reason'),
        controller: reason,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Reason (sent to the user)',
        ),
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
  );
  return ok == true ? reason.text.trim() : null;
}

Widget _page(List<Widget> children) =>
    ListView(padding: const EdgeInsets.all(16), children: children);

/// IT.md ADM1.
class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _mfa = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_email, _password, _mfa]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(adminAuthProvider.notifier)
          .login(
            _email.text.trim().toLowerCase(),
            _password.text,
            _mfa.text.trim(),
          );
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Staff sign in',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              TextField(
                key: const ValueKey('admin-email'),
                controller: _email,
                decoration: const InputDecoration(labelText: 'Work email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('admin-password'),
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('admin-mfa'),
                controller: _mfa,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Authenticator code',
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              FilledButton(
                key: const ValueKey('admin-login'),
                onPressed: _busy ? null : _submit,
                child: const Text('Sign in'),
              ),
              if (usingFakeBackend)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Demo: admin@, mod@, finance@ or finance2@staff.ke, '
                    'password password123, code $fakeOtp',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// IT.md ADM2.
class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const path = '/admin/dashboard';
    final auth = ref.watch(adminAuthProvider);
    return asyncBody(
      ref.watch(_objectProvider(path)),
      () => ref.invalidate(_objectProvider(path)),
      (d) {
        Widget tile(
          String label,
          String key,
          String route,
          String? perm, {
          bool alert = false,
        }) {
          final count = d[key] as int;
          final scheme = Theme.of(context).colorScheme;
          return SizedBox(
            width: 220,
            child: Card(
              color: alert && count > 0 ? scheme.errorContainer : null,
              child: ListTile(
                title: Text(
                  '$count',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                subtitle: Text(label),
                onTap: perm == null || auth.can(perm)
                    ? () => context.go(route)
                    : null,
              ),
            ),
          );
        }

        return _page([
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              tile(
                'Urgent safety cases',
                'urgentReports',
                '/moderation',
                Perm.moderationRead,
                alert: true,
              ),
              tile(
                'Open reports',
                'openReports',
                '/moderation',
                Perm.moderationRead,
              ),
              tile(
                'Creators to review',
                'pendingCreators',
                '/creators',
                Perm.creatorReview,
              ),
              tile(
                'Payouts to review',
                'payoutsToReview',
                '/finance',
                Perm.payoutApprove,
              ),
              tile(
                'Reconciliation exceptions',
                'reconciliationExceptions',
                '/finance',
                Perm.payoutApprove,
              ),
            ],
          ),
        ]);
      },
    );
  }
}

/// IT.md ADM3: verification outcomes only, never identity documents.
class CreatorReviewScreen extends ConsumerWidget {
  const CreatorReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const path = '/admin/creators';
    Future<void> decide(Json c, String decision, String label) async {
      String? reason = '';
      if (decision != 'approve') {
        reason = await _askReason(context, '$label @${c['handle']}');
        if (reason == null) return;
      }
      if (!context.mounted) return;
      await _act(
        context,
        ref,
        () => ref
            .read(dioProvider)
            .post<void>(
              '/admin/creators/${c['userId']}/review',
              data: {'decision': decision, 'reason': reason},
            ),
        done: 'Saved: $label',
        refresh: const [path, '/admin/dashboard'],
      );
    }

    return asyncBody(
      ref.watch(_listProvider(path)),
      () => ref.invalidate(_listProvider(path)),
      (creators) => creators.isEmpty
          ? const Center(child: Text('No creators waiting for review'))
          : _page([
              for (final c in creators)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c['displayName']} (@${c['handle']})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        _check(
                          'Age and identity: ${c['identity']}',
                          c['identity'] == 'verified',
                        ),
                        _check(
                          c['contract'] == null
                              ? 'Agreement not signed'
                              : 'Agreement ${(c['contract'] as Json)['version']} signed',
                          c['contract'] != null,
                        ),
                        _check(
                          'Payout destination verified',
                          c['payoutVerified'] == true,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            FilledButton(
                              key: ValueKey('approve-${c['userId']}'),
                              onPressed: () => decide(c, 'approve', 'Approved'),
                              child: const Text('Approve'),
                            ),
                            OutlinedButton(
                              onPressed: () => decide(
                                c,
                                'request_info',
                                'Requested more information',
                              ),
                              child: const Text('Request info'),
                            ),
                            OutlinedButton(
                              onPressed: () => decide(c, 'reject', 'Rejected'),
                              child: const Text('Reject'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  decide(c, 'suspend', 'Suspended'),
                              child: const Text('Suspend'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ]),
    );
  }

  Widget _check(String text, bool ok) => Row(
    children: [
      Icon(
        ok ? Icons.check_circle : Icons.cancel,
        size: 18,
        color: ok ? Colors.green : Colors.red,
      ),
      const SizedBox(width: 6),
      Expanded(child: Text(text)),
    ],
  );
}

const _reasonCodes = {
  'NO_VIOLATION': 'No violation found',
  'NON_CONSENSUAL': 'Non-consensual content',
  'MINOR_SAFETY': 'Possible minor',
  'HARASSMENT': 'Harassment',
  'SPAM_SCAM': 'Spam or scam',
  'IMPERSONATION': 'Impersonation',
};

/// IT.md ADM6.
class ModerationScreen extends ConsumerWidget {
  const ModerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const path = '/admin/moderation/cases';
    final canResolve = ref.watch(adminAuthProvider).can(Perm.moderationResolve);

    Future<void> resolve(Json c, String action) async {
      final code = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Reason code'),
          children: [
            for (final MapEntry(:key, :value) in _reasonCodes.entries)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, key),
                child: Text(value),
              ),
          ],
        ),
      );
      if (code == null || !context.mounted) return;
      await _act(
        context,
        ref,
        () => ref
            .read(dioProvider)
            .post<void>(
              '/admin/moderation/cases/${c['caseId']}/actions',
              data: {'action': action, 'reasonCode': code},
            ),
        done: 'Case ${c['caseId']} resolved',
        refresh: const [path, '/admin/dashboard'],
      );
    }

    return asyncBody(
      ref.watch(_listProvider(path)),
      () => ref.invalidate(_listProvider(path)),
      (cases) => cases.isEmpty
          ? const Center(child: Text('No reports'))
          : _page([
              for (final c in cases)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${c['caseId']}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(width: 8),
                            if (c['priority'] == 'urgent')
                              const Chip(
                                label: Text('Urgent'),
                                backgroundColor: Colors.redAccent,
                              ),
                            const Spacer(),
                            Text('${c['status']}'),
                          ],
                        ),
                        Text(
                          'Reported ${c['targetType']} ${c['targetId']} for '
                          '${c['reason']} · ${_when(context, c['createdAt'] as String)}',
                        ),
                        if ((c['details'] as String? ?? '').isNotEmpty)
                          Text('"${c['details']}"'),
                        if (c['decision'] != null)
                          Text(
                            'Decision: ${c['decision']} (${c['reasonCode']}) by '
                            '${c['resolvedBy']}',
                          ),
                        if (c['status'] == 'open' && canResolve) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (c['targetType'] == 'post')
                                FilledButton(
                                  key: ValueKey('restrict-${c['caseId']}'),
                                  onPressed: () =>
                                      resolve(c, 'restrict_content'),
                                  child: const Text('Restrict content'),
                                ),
                              if (c['targetType'] == 'user')
                                FilledButton(
                                  onPressed: () => resolve(c, 'suspend_user'),
                                  child: const Text('Suspend user'),
                                ),
                              OutlinedButton(
                                onPressed: () => resolve(c, 'dismiss'),
                                child: const Text('Dismiss'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ]),
    );
  }
}

/// IT.md ADM5: payout approval with dual control.
class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const path = '/admin/payouts';
    final me = ref.watch(adminAuthProvider).staff?['id'];
    Future<void> run(Json p, String action, String done) async {
      String? reason;
      if (action == 'reject') {
        reason = await _askReason(context, 'Reject payout');
        if (reason == null) return;
      }
      if (!context.mounted) return;
      await _act(
        context,
        ref,
        () => ref
            .read(dioProvider)
            .post<void>(
              '/admin/payouts/${p['id']}/$action',
              data: {'reason': ?reason},
            ),
        done: done,
        refresh: const [path, '/admin/dashboard'],
      );
    }

    return asyncBody(
      ref.watch(_listProvider(path)),
      () => ref.invalidate(_listProvider(path)),
      (payouts) => _page([
        for (final p in payouts)
          Card(
            child: ListTile(
              title: Text(
                '${formatKes(p['amountCents'] as int)} to ${p['destination']}',
              ),
              subtitle: Text(
                'Creator ${p['creatorId']} · ${p['status']}'
                '${p['approvedBy'] != null ? ' · approved by ${p['approvedBy']}' : ''}'
                '${p['rejectReason'] != null ? ' · ${p['rejectReason']}' : ''}',
              ),
              trailing: Wrap(
                spacing: 8,
                children: [
                  if (p['status'] == 'requested')
                    FilledButton(
                      key: ValueKey('approve-${p['id']}'),
                      onPressed: () => run(p, 'approve', 'Payout approved'),
                      child: const Text('Approve'),
                    ),
                  if (p['status'] == 'approved')
                    FilledButton(
                      key: ValueKey('submit-${p['id']}'),
                      onPressed: p['approvedBy'] == me
                          ? null
                          : () => run(p, 'submit', 'Sent to M-Pesa'),
                      child: Text(
                        p['approvedBy'] == me
                            ? 'Needs a second approver'
                            : 'Send to M-Pesa',
                      ),
                    ),
                  if (p['status'] == 'requested' || p['status'] == 'approved')
                    OutlinedButton(
                      onPressed: () => run(p, 'reject', 'Payout rejected'),
                      child: const Text('Reject'),
                    ),
                ],
              ),
            ),
          ),
      ]),
    );
  }
}

/// IT.md ADM4 (read-only until template editing is specified).
class ContractsScreen extends ConsumerWidget {
  const ContractsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const path = '/admin/contracts/templates';
    return asyncBody(
      ref.watch(_listProvider(path)),
      () => ref.invalidate(_listProvider(path)),
      (templates) => _page([
        for (final t in templates)
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(title: Text(t['title'] as String)),
                for (final v in t['versions'] as List)
                  ListTile(
                    leading: const Icon(Icons.history_edu),
                    title: Text('Version ${v['version']} · ${v['status']}'),
                    subtitle: Text(
                      'Commission ${v['commissionPercent']}% · effective '
                      '${v['effectiveFrom']} · signed by ${v['signedCount']} '
                      'creators',
                    ),
                  ),
              ],
            ),
          ),
      ]),
    );
  }
}

/// IT.md ADM8.
class ConfigScreen extends ConsumerWidget {
  const ConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const path = '/admin/configuration';
    final canEdit = ref.watch(adminAuthProvider).can(Perm.config);
    Future<void> editCommission(int current) async {
      final value = TextEditingController(text: '$current');
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Platform commission'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('commission-value'),
                controller: value,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(suffixText: '%'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Applies to new transactions only. Past transactions keep '
                'their rate. This change is recorded in the audit log.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
      await _act(
        context,
        ref,
        () => ref
            .read(dioProvider)
            .patch<void>(
              '/admin/configuration/commissionPercent',
              data: {'value': int.tryParse(value.text)},
            ),
        done: 'Commission updated',
        refresh: const [path],
      );
    }

    return asyncBody(
      ref.watch(_objectProvider(path)),
      () => ref.invalidate(_objectProvider(path)),
      (c) => _page([
        ListTile(
          title: const Text('Platform commission (new transactions)'),
          subtitle: Text('${c['commissionPercent']}%'),
          trailing: canEdit
              ? TextButton(
                  key: const ValueKey('edit-commission'),
                  onPressed: () =>
                      editCommission(c['commissionPercent'] as int),
                  child: const Text('Change'),
                )
              : null,
        ),
        ListTile(
          title: const Text('Price limits'),
          subtitle: Text(
            '${formatKes(c['minPriceCents'] as int)} – '
            '${formatKes(c['maxPriceCents'] as int)}',
          ),
        ),
        ListTile(
          title: const Text('Payout minimum'),
          subtitle: Text(formatKes(c['payoutMinimumCents'] as int)),
        ),
        ListTile(
          title: const Text('Currencies · countries'),
          subtitle: Text(
            '${(c['currencies'] as List).join(', ')} · '
            '${(c['countries'] as List).join(', ')}',
          ),
        ),
      ]),
    );
  }
}

/// IT.md ADM7 (audit).
class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const path = '/admin/audit-events';
    return asyncBody(
      ref.watch(_listProvider(path)),
      () => ref.invalidate(_listProvider(path)),
      (events) => events.isEmpty
          ? const Center(child: Text('No events yet'))
          : ListView(
              children: [
                for (final e in events)
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: Text('${e['action']} · ${e['target']}'),
                    subtitle: Text(
                      '${e['staff']} · ${_when(context, e['at'] as String)}'
                      '${e['detail'] != null ? ' · ${e['detail']}' : ''}',
                    ),
                  ),
              ],
            ),
    );
  }
}

/// IT.md ADM7 (staff and roles).
class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const path = '/admin/staff';
    return asyncBody(
      ref.watch(_listProvider(path)),
      () => ref.invalidate(_listProvider(path)),
      (staff) => _page([
        for (final s in staff)
          Card(
            child: ListTile(
              title: Text('${s['name']} · ${s['role']}'),
              subtitle: Text(
                '${s['email']}\n${(s['permissions'] as List).join(', ')}',
              ),
              isThreeLine: true,
              trailing: Icon(
                s['mfaEnabled'] == true ? Icons.verified_user : Icons.gpp_bad,
                semanticLabel: s['mfaEnabled'] == true ? 'MFA on' : 'MFA off',
              ),
            ),
          ),
      ]),
    );
  }
}
