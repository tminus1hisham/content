import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../app/ui.dart';
import '../../core/api_client.dart';
import '../auth/auth_controller.dart';
import '../content/discover_screens.dart';
import '../content/studio_screens.dart';
import '../auth/fake_auth.dart';
import '../settings/settings_screen.dart';
import 'onboarding_controller.dart';

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

Widget _page(List<Widget> children, {double bottom = 32}) => ListView(
  padding: EdgeInsets.fromLTRB(16, 8, 16, bottom),
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

TextStyle? _muted(BuildContext context, TextStyle? style) =>
    style?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

/// Readable long-form text: muted, with a comfortable line height.
TextStyle? _prose(BuildContext context) => _muted(
  context,
  Theme.of(context).textTheme.bodyMedium,
)?.copyWith(height: 1.6);

/// A form section: a small heading over a grouped card.
class _Group extends StatelessWidget {
  const _Group({this.title, required this.children});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
            child: Semantics(
              header: true,
              child: Text(
                title!,
                style: _muted(
                  context,
                  Theme.of(context).textTheme.labelLarge,
                )?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4),
              ),
            ),
          )
        else
          const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

/// A step's main action, with press feedback.
Widget _cta(FilledButton button, {double top = 24}) => Padding(
  padding: EdgeInsets.only(top: top),
  child: Pressable(child: button),
);

/// Loading look for the sub-screen forms.
const _formSkeleton = SkeletonList(count: 4, itemHeight: 64);

/// Creator Home tab until the M5 dashboard: setup progress for creators who
/// are not approved yet.
class CreatorHomeScreen extends ConsumerWidget {
  const CreatorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingProvider);
    // No app bar: the dashboard's greeting card is the header, like the
    // other tabs' large titles.
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: asyncBody(onboarding, () => ref.invalidate(onboardingProvider), (
          status,
        ) {
          if (status.approved) return const CreatorDashboard();
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
      ),
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
      body: asyncBody(
        onboarding,
        () => ref.invalidate(onboardingProvider),
        loading: () => const SkeletonList(count: 6, itemHeight: 72),
        (s) {
          final editable =
              s.status == 'incomplete' || s.status == 'action_required';
          final identityDetail = switch (s.identity) {
            'pending' => 'Waiting for the result',
            'failed' =>
              'Not verified. Try again with a clear photo of your ID.',
            'verified' => 'Verified',
            _ => null,
          };
          final steps = [
            // Verified at sign-up: there is no screen to open.
            (
              title: 'Contact verified',
              done: true,
              path: '',
              detail: null,
              enabled: false,
            ),
            (
              title: 'Age and identity',
              done: s.identity == 'verified',
              path: '/onboarding/identity',
              detail: identityDetail,
              enabled: s.identity != 'verified',
            ),
            (
              title: 'Creator profile',
              done: s.profile,
              path: '/onboarding/profile',
              detail: null,
              enabled: true,
            ),
            (
              title: 'Creator agreement',
              done: s.contract,
              path: '/onboarding/contract',
              detail: null,
              enabled: !s.contract,
            ),
            (
              title: 'Payout method',
              done: s.payout,
              path: '/onboarding/payout',
              detail: null,
              enabled: true,
            ),
          ];
          return _page(
            // Room below the button, so a floating snackbar never covers it.
            bottom: 112,
            [
              Entrance(
                child: _StatusHeader(
                  label: statusLabels[s.status] ?? s.status,
                  message: switch (s.status) {
                    'under_review' =>
                      'We are reviewing your details. This usually takes 1-2 '
                          'working days.',
                    'approved' => 'You can now sell content and go live.',
                    'rejected' =>
                      'Your application was not approved. Contact support to '
                          'appeal.',
                    'suspended' =>
                      'Your account is suspended. Contact support.',
                    _ => 'Complete each step, then submit for review.',
                  },
                  done: steps.where((step) => step.done).length,
                  total: steps.length,
                ),
              ),
              if (s.status == 'incomplete') ...[
                const SizedBox(height: 12),
                const Entrance(index: 1, child: _EligibilityCard()),
              ],
              const SizedBox(height: 6),
              for (final (i, step) in steps.indexed)
                Entrance(
                  index: i + 2,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _StepRow(
                      number: i + 1,
                      title: step.title,
                      done: step.done,
                      detail: step.detail,
                      onTap: editable && step.enabled
                          ? () => context.push(step.path)
                          : null,
                    ),
                  ),
                ),
              if (editable)
                _cta(
                  FilledButton(
                    style: brandButtonStyle(context),
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
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Status over the brand glow, with a progress track lit by the gradient.
class _StatusHeader extends StatelessWidget {
  const _StatusHeader({
    required this.label,
    required this.message,
    required this.done,
    required this.total,
  });
  final String label;
  final String message;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(cardRadius)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: GlowBackground()),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: _muted(
                    context,
                    text.bodyMedium,
                  )?.copyWith(height: 1.45),
                ),
                const SizedBox(height: 20),
                ExcludeSemantics(child: _ProgressTrack(value: done / total)),
                const SizedBox(height: 8),
                Text(
                  '$done of $total steps done',
                  style: _muted(context, text.labelMedium),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(3));
    // A null begin starts at end: the fill animates on change, not on entry.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: motion(context, mediumDuration),
      curve: easeOut,
      builder: (context, v, _) => Container(
        height: 6,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: radius,
        ),
        child: FractionallySizedBox(
          widthFactor: v,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: Brand.of(context).gradient,
              borderRadius: radius,
            ),
          ),
        ),
      ),
    );
  }
}

/// One checklist step: numbered badge (a gradient check once done), title,
/// optional detail, and a chevron when it can be opened.
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.title,
    required this.done,
    this.detail,
    this.onTap,
  });
  final int number;
  final String title;
  final bool done;
  final String? detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final badge = Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: done ? Brand.of(context).gradient : null,
        border: done
            ? null
            : Border.all(color: scheme.outlineVariant, width: 1.5),
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 18, color: brandInk)
          : Text(
              '$number',
              // Inside a fixed circle; the title next to it carries meaning.
              textScaler: TextScaler.noScaling,
              style: _muted(
                context,
                text.labelLarge,
              )?.copyWith(fontWeight: FontWeight.w700),
            ),
    );
    final card = Material(
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(cardRadius)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          child: Row(
            children: [
              Semantics(
                label: done ? 'Done' : 'To do',
                child: ExcludeSemantics(child: badge),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 2),
                      Text(detail!, style: _muted(context, text.bodySmall)),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
    return onTap == null ? card : Pressable(child: card);
  }
}

class _EligibilityCard extends StatelessWidget {
  const _EligibilityCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const SettingsIcon(Icons.info_outline),
        title: Text(
          'What you need',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• You must be 18 or older and live in a supported country '
            '(currently Kenya).\n'
            '• A valid national ID or passport for identity checks.\n'
            '• An M-Pesa number registered in your name for payouts.\n'
            '• Everyone in your content must be an adult who has consented.\n'
            '• Our team reviews every application before you can earn.',
            style: _prose(context),
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
        body: StateView(
          icon: Icons.verified,
          title: 'You are verified.',
          action: Pressable(
            child: FilledButton(
              style: brandButtonStyle(context),
              onPressed: () => context.pop(),
              child: const Text('Back to setup'),
            ),
          ),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Age and identity')),
      body: _page([
        _Group(
          title: 'How it works',
          children: [
            Text(
              'We use a specialist verification partner to confirm you are an '
              'adult and that you are who you say you are. You will take a '
              'photo of your ID and a short selfie video.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ],
        ),
        _Group(
          title: 'Your privacy',
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SettingsIcon(Icons.lock_outline),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'How we use your data: the partner checks your documents '
                    'and tells us the result. Only specially authorised staff '
                    'can see identity evidence, and it is never shown to fans.',
                    style: _prose(context),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (identity == 'failed') ...[
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            color: scheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: scheme.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your last check did not pass. Use a valid, unexpired '
                      'ID, in good light, with all four corners visible.',
                      style: TextStyle(
                        color: scheme.onErrorContainer,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (!_started && identity != 'pending')
          _cta(
            FilledButton(
              style: brandButtonStyle(context),
              onPressed: _busy
                  ? null
                  : () => _run((dio) async {
                      await dio.post<void>('/verification/sessions');
                      setState(() => _started = true);
                    }),
              child: const Text('Start verification'),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run((dio) => dio.get<void>('/verification/status')),
              child: const Text('Check my result'),
            ),
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
          ? _formSkeleton
          : Form(
              key: _form,
              child: _page([
                _Group(
                  title: 'About you',
                  children: [
                    TextFormField(
                      key: const ValueKey('profile-name'),
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Enter a display name'
                          : null,
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
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9_]'),
                        ),
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
                  ],
                ),
                _Group(
                  title: 'Categories',
                  children: [
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
                  ],
                ),
                _Group(
                  title: 'Preferences',
                  children: [
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
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show me in Discover'),
                      value: _discoverable,
                      onChanged: (v) => setState(() => _discoverable = v),
                    ),
                  ],
                ),
                _cta(
                  FilledButton(
                    key: const ValueKey('profile-save'),
                    style: brandButtonStyle(context),
                    onPressed: _busy ? null : _save,
                    child: const Text('Save'),
                  ),
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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final canSign =
        _readToEnd && _consent && _signature.text.trim().length >= 3 && !_busy;
    return Scaffold(
      appBar: AppBar(title: const Text('Creator agreement')),
      body: offer == null
          ? _error == null
                ? _formSkeleton
                : StateView(icon: Icons.description_outlined, title: _error!)
          : ListView(
              key: const ValueKey('contract-scroll'),
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Material(
                          color: scheme.surfaceContainerLow,
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: const BorderRadius.all(
                              Radius.circular(cardRadius),
                            ),
                            side: BorderSide(color: scheme.outlineVariant),
                          ),
                          child: Stack(
                            children: [
                              const Positioned.fill(child: GlowBackground()),
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SettingsIcon(Icons.percent),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Platform commission: '
                                            '${offer['commissionPercent']}%',
                                            style: text.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'You keep '
                                            '${100 - (offer['commissionPercent'] as int)}% '
                                            'of every sale. Version '
                                            '${offer['version']}.',
                                            style: _muted(
                                              context,
                                              text.bodyMedium,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _Group(
                          title: 'Agreement',
                          children: [
                            for (final (i, section)
                                in (offer['sections'] as List).indexed) ...[
                              if (i > 0) const SizedBox(height: 20),
                              Semantics(
                                header: true,
                                child: Text(
                                  section['heading'] as String,
                                  style: text.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                section['body'] as String,
                                style: _prose(context),
                              ),
                            ],
                          ],
                        ),
                        if (_readToEnd)
                          _Group(
                            title: 'Sign',
                            children: [
                              TextField(
                                key: const ValueKey('contract-signature'),
                                controller: _signature,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Type your full legal name to sign',
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 4),
                              CheckboxListTile(
                                key: const ValueKey('contract-consent'),
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                value: _consent,
                                onChanged: (v) => setState(() => _consent = v!),
                                title: const Text(
                                  'I have read this agreement and agree to '
                                  'sign it electronically.',
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: _decline,
                              child: const Text('Decline'),
                            ),
                            TextButton(
                              onPressed: () => _snack(
                                context,
                                'Questions? Email support before signing.',
                              ),
                              child: const Text('Ask support'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      // Always visible, so it is clear signing unlocks only after reading.
      bottomNavigationBar: offer == null
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Center(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: SizedBox(
                        width: double.infinity,
                        child: Pressable(
                          child: FilledButton(
                            key: const ValueKey('contract-sign'),
                            style: brandButtonStyle(context),
                            onPressed: canSign ? _sign : null,
                            child: Text(
                              _readToEnd
                                  ? 'Accept and sign'
                                  : 'Read to the end to sign',
                            ),
                          ),
                        ),
                      ),
                    ),
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
    final text = Theme.of(context).textTheme;
    const saveKey = ValueKey('payout-save');
    final onSave = _busy ? null : _add;
    const saveLabel = Text('Save and send code');
    return Scaffold(
      appBar: AppBar(title: const Text('Payout method')),
      body: _page([
        if (method != null)
          _Group(
            children: [
              Row(
                children: [
                  SettingsIcon(
                    verified ? Icons.verified_outlined : Icons.phone_android,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'M-Pesa ${method['phoneMasked']}',
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${method['accountName']} · '
                          '${verified ? 'Verified' : 'Waiting for code'}',
                          style: _muted(context, text.bodySmall),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        if (method != null && !verified) ...[
          _Group(
            title: 'Confirm your number',
            children: [
              Text(
                'Enter the code we sent by SMS to ${method['phoneMasked']}.',
                style: _prose(context),
              ),
              if (usingFakeBackend)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Demo code: $fakeOtp',
                    style: _muted(context, text.bodySmall),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('payout-code'),
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Code'),
              ),
              _cta(
                top: 8,
                FilledButton(
                  key: const ValueKey('payout-verify'),
                  style: brandButtonStyle(context),
                  onPressed: _busy ? null : _verify,
                  child: const Text('Verify'),
                ),
              ),
            ],
          ),
        ],
        _Group(
          title: method == null
              ? 'Add your M-Pesa number'
              : 'Replace destination',
          children: [
            if (method != null) ...[
              Text(
                'For your security, a new number must be verified again and '
                'payouts may be held for a short time.',
                style: _muted(context, text.bodySmall)?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 16),
            ],
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    validator: (v) => (v ?? '').trim().length < 3
                        ? 'Enter the full name'
                        : null,
                  ),
                  // The main action until a number exists; secondary after.
                  if (method == null)
                    _cta(
                      top: 20,
                      FilledButton(
                        key: saveKey,
                        style: brandButtonStyle(context),
                        onPressed: onSave,
                        child: saveLabel,
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: FilledButton.tonal(
                        key: saveKey,
                        onPressed: onSave,
                        child: saveLabel,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ]),
    );
  }
}
