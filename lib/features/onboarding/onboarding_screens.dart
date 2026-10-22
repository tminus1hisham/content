import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../auth/auth_controller.dart';
import '../auth/fake_auth.dart';
import 'onboarding_controller.dart';

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

Widget _page(List<Widget> children) => ListView(
  padding: const EdgeInsets.all(16),
  children: [
    Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  ],
);

/// Shows a spinner, an error with retry, or [builder] for an AsyncValue.
Widget _async<T>(
  WidgetRef ref,
  AsyncValue<T> value,
  ProviderOrFamily provider,
  Widget Function(T) builder,
) => value.when(
  data: builder,
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (e, _) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(apiErrorMessage(e)),
        TextButton(
          onPressed: () => ref.invalidate(provider),
          child: const Text('Try again'),
        ),
      ],
    ),
  ),
);

/// Creator Home tab until the M5 dashboard: setup progress for creators who
/// are not approved yet.
class CreatorHomeScreen extends ConsumerWidget {
  const CreatorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: _async(ref, onboarding, onboardingProvider, (status) {
        if (status.approved) {
          return const Center(child: Text('Your dashboard is coming soon'));
        }
        return _page([
          Card(
            child: ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Finish setting up to start earning'),
              subtitle: Text(statusLabels[status.status] ?? status.status),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/onboarding'),
            ),
          ),
        ]);
      }),
    );
  }
}

/// IT.md C1 (eligibility summary) and C6 (status checklist).
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Creator setup')),
      body: _async(ref, onboarding, onboardingProvider, (s) {
        final editable =
            s.status == 'incomplete' || s.status == 'action_required';
        Widget step(
          String title,
          bool done,
          String path, {
          String? detail,
          bool enabled = true,
        }) => ListTile(
          leading: Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? Theme.of(context).colorScheme.primary : null,
          ),
          title: Text(title),
          subtitle: detail == null ? null : Text(detail),
          trailing: editable && enabled
              ? const Icon(Icons.chevron_right)
              : null,
          onTap: editable && enabled ? () => context.push(path) : null,
        );
        final identityDetail = switch (s.identity) {
          'pending' => 'Waiting for the result',
          'failed' => 'Not verified. Try again with a clear photo of your ID.',
          'verified' => 'Verified',
          _ => null,
        };
        return _page([
          Card(
            child: ListTile(
              title: Text(statusLabels[s.status] ?? s.status),
              subtitle: Text(switch (s.status) {
                'under_review' =>
                  'We are reviewing your details. This usually takes 1-2 '
                      'working days.',
                'approved' => 'You can now sell content and go live.',
                'rejected' =>
                  'Your application was not approved. Contact support to '
                      'appeal.',
                'suspended' => 'Your account is suspended. Contact support.',
                _ => 'Complete each step, then submit for review.',
              }),
            ),
          ),
          if (s.status == 'incomplete') const _EligibilityCard(),
          step('Contact verified', true, ''),
          step(
            'Age and identity',
            s.identity == 'verified',
            '/onboarding/identity',
            detail: identityDetail,
            enabled: s.identity != 'verified',
          ),
          step('Creator profile', s.profile, '/onboarding/profile'),
          step(
            'Creator agreement',
            s.contract,
            '/onboarding/contract',
            enabled: !s.contract,
          ),
          step('Payout method', s.payout, '/onboarding/payout'),
          const SizedBox(height: 16),
          if (editable)
            FilledButton(
              onPressed: s.readyToSubmit
                  ? () async {
                      try {
                        await ref
                            .read(dioProvider)
                            .post<void>('/creators/me/submit-review');
                        ref.invalidate(onboardingProvider);
                      } catch (e) {
                        if (context.mounted) {
                          _snack(context, apiErrorMessage(e));
                        }
                      }
                    }
                  : null,
              child: const Text('Submit for review'),
            ),
        ]);
      }),
    );
  }
}

class _EligibilityCard extends StatelessWidget {
  const _EligibilityCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ExpansionTile(
        leading: Icon(Icons.info_outline),
        title: Text('What you need'),
        childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• You must be 18 or older and live in a supported country '
            '(currently Kenya).\n'
            '• A valid national ID or passport for identity checks.\n'
            '• An M-Pesa number registered in your name for payouts.\n'
            '• Everyone in your content must be an adult who has consented.\n'
            '• Our team reviews every application before you can earn.',
          ),
        ],
      ),
    );
  }
}

/// IT.md C2. The provider (still to be chosen) runs the actual check; we only
/// keep its outcome.
class IdentityScreen extends ConsumerStatefulWidget {
  const IdentityScreen({super.key});

  @override
  ConsumerState<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends ConsumerState<IdentityScreen> {
  bool _busy = false;
  bool _started = false;

  Future<void> _run(Future<void> Function(Dio dio) action) async {
    setState(() => _busy = true);
    try {
      await action(ref.read(dioProvider));
      ref.invalidate(onboardingProvider);
    } catch (e) {
      if (mounted) _snack(context, apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(onboardingProvider).valueOrNull?.identity;
    if (identity == 'verified') {
      return Scaffold(
        appBar: AppBar(title: const Text('Age and identity')),
        body: _page([
          const Icon(Icons.verified, size: 64),
          const SizedBox(height: 12),
          const Text('You are verified.', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.pop(),
            child: const Text('Back to setup'),
          ),
        ]),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Age and identity')),
      body: _page([
        const Text(
          'We use a specialist verification partner to confirm you are an '
          'adult and that you are who you say you are. You will take a photo '
          'of your ID and a short selfie video.',
        ),
        const SizedBox(height: 12),
        Text(
          'How we use your data: the partner checks your documents and tells '
          'us the result. Only specially authorised staff can see identity '
          'evidence, and it is never shown to fans.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (identity == 'failed') ...[
          const SizedBox(height: 12),
          const Text(
            'Your last check did not pass. Use a valid, unexpired ID, in good '
            'light, with all four corners visible.',
          ),
        ],
        const SizedBox(height: 24),
        if (!_started && identity != 'pending')
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run((dio) async {
                    await dio.post<void>('/verification/sessions');
                    setState(() => _started = true);
                  }),
            child: const Text('Start verification'),
          )
        else
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => _run((dio) => dio.get<void>('/verification/status')),
            child: const Text('Check my result'),
          ),
      ]),
    );
  }
}

const creatorCategories = [
  'Fitness',
  'Dance',
  'Music',
  'Comedy',
  'Lifestyle',
  'Fashion',
  'Art',
  'Cooking',
  'Gaming',
  'Education',
];

/// IT.md C3. Saved on the server, so a draft survives reinstalls
/// (FR-CRT-005). Avatar and banner arrive with uploads in M5.
class CreatorProfileScreen extends ConsumerStatefulWidget {
  const CreatorProfileScreen({super.key});

  @override
  ConsumerState<CreatorProfileScreen> createState() =>
      _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends ConsumerState<CreatorProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _handle = TextEditingController();
  final _bio = TextEditingController();
  final _location = TextEditingController();
  final _categories = <String>{};
  String _language = 'en';
  bool _discoverable = true;
  bool _loading = true;
  bool _busy = false;
  String? _handleError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p =
          (await ref
                  .read(dioProvider)
                  .get<Map<String, dynamic>>('/creators/me'))
              .data!;
      _name.text = p['displayName'] as String? ?? '';
      _handle.text = p['handle'] as String? ?? '';
      _bio.text = p['bio'] as String? ?? '';
      _location.text = p['location'] as String? ?? '';
      _categories.addAll((p['categories'] as List? ?? []).cast<String>());
      _language = p['language'] as String? ?? 'en';
      _discoverable = p['discoverable'] as bool? ?? true;
    } on DioException {
      // 404: no profile yet.
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [_name, _handle, _bio, _location]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _handleError = null;
    });
    try {
      await ref
          .read(dioProvider)
          .patch<void>(
            '/creators/me',
            data: {
              'displayName': _name.text.trim(),
              'handle': _handle.text.trim(),
              'bio': _bio.text.trim(),
              'categories': _categories.toList(),
              'language': _language,
              'location': _location.text.trim(),
              'discoverable': _discoverable,
            },
          );
      ref.invalidate(onboardingProvider);
      if (mounted) {
        _snack(context, 'Profile saved');
        context.pop();
      }
    } catch (e) {
      final code = apiErrorCode(e);
      if (code == 'HANDLE_TAKEN' || code == 'INVALID_HANDLE') {
        setState(() => _handleError = apiErrorMessage(e));
      } else if (mounted) {
        _snack(context, apiErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Creator profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: _page([
                TextFormField(
                  key: const ValueKey('profile-name'),
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Display name'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Enter a display name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('profile-handle'),
                  controller: _handle,
                  decoration: InputDecoration(
                    labelText: 'Handle',
                    prefixText: '@',
                    errorText: _handleError,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                  ],
                  validator: (v) => (v ?? '').trim().length < 3
                      ? 'At least 3 characters'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bio,
                  decoration: const InputDecoration(labelText: 'Bio'),
                  maxLines: 3,
                  maxLength: 280,
                ),
                const SizedBox(height: 8),
                Text(
                  'Categories',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in creatorCategories)
                      FilterChip(
                        label: Text(category),
                        selected: _categories.contains(category),
                        onSelected: (on) => setState(
                          () => on
                              ? _categories.add(category)
                              : _categories.remove(category),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _language,
                  decoration: const InputDecoration(labelText: 'Language'),
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'sw', child: Text('Kiswahili')),
                  ],
                  onChanged: (v) => setState(() => _language = v!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _location,
                  decoration: const InputDecoration(
                    labelText: 'Public location (optional)',
                    hintText: 'e.g. Nairobi',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show me in Discover'),
                  value: _discoverable,
                  onChanged: (v) => setState(() => _discoverable = v),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  key: const ValueKey('profile-save'),
                  onPressed: _busy ? null : _save,
                  child: const Text('Save'),
                ),
              ]),
            ),
    );
  }
}

/// IT.md C4. Signing sends the exact version and document hash that was read
/// (FR-CON-003); the button stays off until the whole agreement was scrolled.
class ContractScreen extends ConsumerStatefulWidget {
  const ContractScreen({super.key});

  @override
  ConsumerState<ContractScreen> createState() => _ContractScreenState();
}

class _ContractScreenState extends ConsumerState<ContractScreen> {
  final _scroll = ScrollController();
  final _signature = TextEditingController();
  Map<String, dynamic>? _offer;
  String? _error;
  bool _readToEnd = false;
  bool _consent = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_checkEnd);
    _load();
  }

  void _checkEnd() {
    if (!_readToEnd &&
        _scroll.hasClients &&
        _scroll.position.extentAfter < 24) {
      setState(() => _readToEnd = true);
    }
  }

  Future<void> _load() async {
    try {
      final dio = ref.read(dioProvider);
      final offers = (await dio.get<List<dynamic>>('/contracts/offers')).data!;
      if (offers.isEmpty) {
        setState(() => _error = 'There is no agreement waiting for you.');
        return;
      }
      final id = (offers.first as Map)['id'];
      final offer = (await dio.get<Map<String, dynamic>>(
        '/contracts/offers/$id',
      )).data!;
      setState(() => _offer = offer);
      // Short agreements fit on screen without scrolling.
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkEnd());
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _signature.dispose();
    super.dispose();
  }

  Future<void> _sign() async {
    final offer = _offer!;
    setState(() => _busy = true);
    try {
      await ref
          .read(dioProvider)
          .post<void>(
            '/contracts/offers/${offer['id']}/sign',
            data: {
              'version': offer['version'],
              'documentHash': offer['documentHash'],
              'signatureName': _signature.text.trim(),
              'consentToElectronicSignature': true,
            },
          );
      ref.invalidate(onboardingProvider);
      if (mounted) {
        _snack(context, 'Agreement signed');
        context.pop();
      }
    } catch (e) {
      if (mounted) _snack(context, apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    await ref
        .read(dioProvider)
        .post<void>('/contracts/offers/${_offer!['id']}/decline');
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final offer = _offer;
    final text = Theme.of(context).textTheme;
    final canSign =
        _readToEnd && _consent && _signature.text.trim().length >= 3 && !_busy;
    return Scaffold(
      appBar: AppBar(title: const Text('Creator agreement')),
      body: offer == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(_error!),
            )
          : ListView(
              key: const ValueKey('contract-scroll'),
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.percent),
                    title: Text(
                      'Platform commission: ${offer['commissionPercent']}%',
                    ),
                    subtitle: Text(
                      'You keep ${100 - (offer['commissionPercent'] as int)}% '
                      'of every sale. Version ${offer['version']}.',
                    ),
                  ),
                ),
                for (final section in offer['sections'] as List) ...[
                  const SizedBox(height: 16),
                  Text(section['heading'] as String, style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(section['body'] as String),
                ],
                const Divider(height: 32),
                if (_readToEnd) ...[
                  TextField(
                    key: const ValueKey('contract-signature'),
                    controller: _signature,
                    decoration: const InputDecoration(
                      labelText: 'Type your full legal name to sign',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  CheckboxListTile(
                    key: const ValueKey('contract-consent'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _consent,
                    onChanged: (v) => setState(() => _consent = v!),
                    title: const Text(
                      'I have read this agreement and agree to sign it '
                      'electronically.',
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(onPressed: _decline, child: const Text('Decline')),
                TextButton(
                  onPressed: () => _snack(
                    context,
                    'Questions? Email support before signing.',
                  ),
                  child: const Text('Ask support'),
                ),
              ],
            ),
      // Always visible, so it is clear signing unlocks only after reading.
      bottomNavigationBar: offer == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  key: const ValueKey('contract-sign'),
                  onPressed: canSign ? _sign : null,
                  child: Text(
                    _readToEnd ? 'Accept and sign' : 'Read to the end to sign',
                  ),
                ),
              ),
            ),
    );
  }
}

/// IT.md C5: M-Pesa payout destination, confirmed by an SMS code.
class PayoutSetupScreen extends ConsumerStatefulWidget {
  const PayoutSetupScreen({super.key});

  @override
  ConsumerState<PayoutSetupScreen> createState() => _PayoutSetupScreenState();
}

class _PayoutSetupScreenState extends ConsumerState<PayoutSetupScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _code = TextEditingController();
  Map<String, dynamic>? _method;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref
        .read(dioProvider)
        .get<List<dynamic>>('/creators/me/payout-methods')
        .then((r) {
          if (mounted && r.data!.isNotEmpty) {
            setState(() => _method = r.data!.first as Map<String, dynamic>);
          }
        }, onError: (_) {});
  }

  @override
  void dispose() {
    for (final c in [_phone, _name, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _busyRun(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) _snack(context, apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    if (!_form.currentState!.validate()) return;
    await _busyRun(() async {
      final response = await ref
          .read(dioProvider)
          .post<Map<String, dynamic>>(
            '/creators/me/payout-methods',
            data: {
              'type': 'mpesa',
              'phone': normalizeIdentifier(_phone.text),
              'accountName': _name.text.trim(),
            },
          );
      setState(() => _method = response.data);
      ref.invalidate(onboardingProvider);
    });
  }

  Future<void> _verify() => _busyRun(() async {
    final response = await ref
        .read(dioProvider)
        .post<Map<String, dynamic>>(
          '/creators/me/payout-methods/${_method!['id']}/verify',
          data: {'code': _code.text.trim()},
        );
    setState(() => _method = response.data);
    ref.invalidate(onboardingProvider);
  });

  @override
  Widget build(BuildContext context) {
    final method = _method;
    final verified = method?['verified'] == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Payout method')),
      body: _page([
        if (method != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone_android),
              title: Text('M-Pesa ${method['phoneMasked']}'),
              subtitle: Text(
                '${method['accountName']} · '
                '${verified ? 'Verified' : 'Waiting for code'}',
              ),
            ),
          ),
        if (method != null && !verified) ...[
          const SizedBox(height: 16),
          Text('Enter the code we sent by SMS to ${method['phoneMasked']}.'),
          if (usingFakeBackend)
            Text(
              'Demo code: $fakeOtp',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          TextField(
            key: const ValueKey('payout-code'),
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Code'),
          ),
          FilledButton(
            key: const ValueKey('payout-verify'),
            onPressed: _busy ? null : _verify,
            child: const Text('Verify'),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          method == null ? 'Add your M-Pesa number' : 'Replace destination',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (method != null)
          Text(
            'For your security, a new number must be verified again and '
            'payouts may be held for a short time.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 12),
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                key: const ValueKey('payout-phone'),
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'M-Pesa number',
                  hintText: '0712 345 678',
                ),
                validator: (v) {
                  final phone = normalizeIdentifier(v ?? '');
                  return phone != null &&
                          RegExp(r'^\+254[17]\d{8}$').hasMatch(phone)
                      ? null
                      : 'Enter a Kenyan M-Pesa number';
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('payout-name'),
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Name registered on M-Pesa',
                ),
                validator: (v) =>
                    (v ?? '').trim().length < 3 ? 'Enter the full name' : null,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  key: const ValueKey('payout-save'),
                  onPressed: _busy ? null : _add,
                  child: const Text('Save and send code'),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
