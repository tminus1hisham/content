import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/birth_date_picker.dart';
import '../../app/motion.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../app/ui.dart';
import '../../core/api_client.dart';
import '../disguise/disguise_controller.dart';
import 'auth_controller.dart';
import 'fake_auth.dart';

const _maxWidth = BoxConstraints(maxWidth: 440);

/// Centered, scrollable, width-capped body used by every entry screen.
class _EntryBody extends StatelessWidget {
  const _EntryBody({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: _maxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// The form surface on entry screens: a hairline card on the layered tones.
class _FormCard extends StatelessWidget {
  const _FormCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// A lit icon in a soft ring of brand light, as in [StateView].
class _LitIcon extends StatelessWidget {
  const _LitIcon(this.icon, {this.size = 72, this.color});
  final IconData icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = Brand.of(context);
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              brand.glowA.withValues(alpha: 0.22),
              brand.glowB.withValues(alpha: 0.22),
            ],
          ),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Icon(icon, size: size * 0.44, color: color ?? scheme.primary),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error(this.message);
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: const BorderRadius.all(
              Radius.circular(controlRadius),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline,
                size: 20,
                color: scheme.onErrorContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// IT.md F1: explains the 18+ rule and asks for a date of birth before
/// anything else is shown.
class AgeGateScreen extends ConsumerStatefulWidget {
  const AgeGateScreen({super.key});

  @override
  ConsumerState<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends ConsumerState<AgeGateScreen> {
  bool _underage = false;

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showBirthDatePicker(context);
    if (picked == null) return;
    if (isAdult(picked, now)) {
      await ref.read(ageGateProvider.notifier).confirm();
    } else {
      setState(() => _underage = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackground()),
          _EntryBody(
            children: [
              Entrance(
                child: _LitIcon(
                  _underage
                      ? Icons.do_not_disturb_on_outlined
                      : Icons.eighteen_up_rating_outlined,
                  size: 88,
                  color: _underage ? scheme.error : null,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Adults only',
                style: text.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _underage
                    ? 'Sorry, you must be 18 or older to use this app.'
                    : 'This app contains content for people aged 18 and over. '
                          'Confirm your date of birth to continue.',
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              if (!_underage)
                Pressable(
                  child: FilledButton(
                    style: brandButtonStyle(context),
                    onPressed: _pickBirthDate,
                    child: const Text('Enter date of birth'),
                  ),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => SystemNavigator.pop(),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                ),
                child: const Text('Leave'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disguise = ref.watch(disguiseProvider);
    // Startup must preserve the identity chosen in the disguise settings.
    if (disguise != Disguise.none) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(disguise.icon, size: 64),
              const SizedBox(height: 20),
              Text(
                disguise.label,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
      );
    }

    const cream = Color(0xFFFFFCF5);
    const ink = Color(0xFF392B32);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: cream,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: cream,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(1.1, -0.8),
                  radius: 1.15,
                  colors: [Color(0x26FF9A43), Color(0x00FF9A43)],
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-1.1, 0.9),
                  radius: 1.1,
                  colors: [Color(0x24FF65A1), Color(0x00FF65A1)],
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 650),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - value)),
                        child: child,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(44),
                          child: Image.asset(
                            'assets/branding/raha.png',
                            width: 176,
                            height: 176,
                            excludeFromSemantics: true,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Raha',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 56,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -2.5,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Closer to what you love.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: Color(0xFF796972),
                          ),
                        ),
                        const SizedBox(height: 44),
                        SizedBox(
                          width: 64,
                          child: LinearProgressIndicator(
                            value: reduceMotion ? 0.6 : null,
                            minHeight: 3,
                            borderRadius: BorderRadius.circular(4),
                            color: const Color(0xFFEC6A72),
                            backgroundColor: const Color(0xFFF2E3DF),
                            semanticsLabel: 'Loading Raha',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// IT.md A1.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final brand = Brand.of(context);
    final hero = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The logo rises in once; under reduce-motion it is simply there.
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: motion(context, const Duration(milliseconds: 400)),
          curve: easeOut,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, 16 * (1 - t)),
              child: child,
            ),
          ),
          child: Center(
            child: Container(
              width: 168,
              height: 168,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    brand.glowB.withValues(alpha: 0.28),
                    brand.glowA.withValues(alpha: 0.10),
                    brand.glowA.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Image.asset(
                  'assets/branding/raha.png',
                  width: 104,
                  height: 104,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Entrance(
          index: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Raha',
                style: text.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Support creators you love. Pay only for what you want, in KES.',
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final actions = Entrance(
      index: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Pressable(
            child: FilledButton(
              style: brandButtonStyle(context),
              onPressed: () => context.go('/register'),
              child: const Text('Create account'),
            ),
          ),
          const SizedBox(height: 12),
          Pressable(
            child: OutlinedButton(
              onPressed: () => context.go('/login'),
              child: const Text('Sign in'),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '18+ only. Currently available in Kenya. We protect your privacy, '
            'but no online service can guarantee anonymity.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          const _PolicyLinks(),
        ],
      ),
    );
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // A centred 440 column on wide screens.
                final side = math.max(
                  24.0,
                  (constraints.maxWidth - _maxWidth.maxWidth) / 2,
                );
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(side, 24, side, 16),
                  child: ConstrainedBox(
                    // Hero in the middle, actions at the thumb; scrolls when
                    // the text is large.
                    constraints: BoxConstraints(
                      minHeight: math.max(0, constraints.maxHeight - 40),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox.shrink(),
                        hero,
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: actions,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyLinks extends StatelessWidget {
  const _PolicyLinks();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    void show(String title) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text('The full document will be published here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    final style = TextButton.styleFrom(
      foregroundColor: scheme.onSurfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      textStyle: Theme.of(context).textTheme.labelMedium,
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (i, title) in [
          'Terms',
          'Privacy',
          'Acceptable use',
        ].indexed) ...[
          if (i > 0)
            ExcludeSemantics(
              child: Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.outline,
                ),
              ),
            ),
          TextButton(
            style: style,
            onPressed: () => show(title),
            child: Text(title),
          ),
        ],
      ],
    );
  }
}

const _countries = {
  'KE': 'Kenya',
  'UG': 'Uganda',
  'TZ': 'Tanzania',
  'RW': 'Rwanda',
  'NG': 'Nigeria',
  'ZA': 'South Africa',
};

/// IT.md A2 / F2.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  String _country = 'KE';
  bool _accepted = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_accepted) {
      setState(() => _error = 'Accept the terms to continue');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final identifier = normalizeIdentifier(_identifier.text)!;
    try {
      final verificationId = await ref
          .read(authProvider.notifier)
          .register(
            identifier: identifier,
            password: _password.text,
            country: _country,
          );
      if (!mounted) return;
      context.go(
        '/verify',
        extra: VerifyArgs(verificationId, identifier, _password.text),
      );
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create account'),
        leading: BackButton(onPressed: () => context.go('/welcome')),
      ),
      body: Form(
        key: _form,
        child: _EntryBody(
          children: [
            _FormCard(
              children: [
                TextFormField(
                  key: const ValueKey('register-identifier'),
                  controller: _identifier,
                  decoration: const InputDecoration(
                    labelText: 'Email or phone',
                    hintText: 'you@example.com or 0712 345 678',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  validator: (v) => normalizeIdentifier(v ?? '') == null
                      ? 'Enter a valid email or phone number'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('register-password'),
                  controller: _password,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (v) =>
                      (v ?? '').length < 8 ? 'Use at least 8 characters' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _country,
                  decoration: const InputDecoration(
                    labelText: 'Country',
                    prefixIcon: Icon(Icons.public),
                  ),
                  borderRadius: const BorderRadius.all(
                    Radius.circular(controlRadius),
                  ),
                  items: [
                    for (final MapEntry(:key, :value) in _countries.entries)
                      DropdownMenuItem(value: key, child: Text(value)),
                  ],
                  onChanged: (v) => setState(() => _country = v!),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  key: const ValueKey('register-terms'),
                  value: _accepted,
                  onChanged: (v) => setState(() => _accepted = v!),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(controlRadius),
                    ),
                  ),
                  title: Text(
                    'I am 18+ and accept the Terms, Privacy Policy and '
                    'Acceptable Use Policy',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 12),
                _Error(_error),
                Pressable(
                  child: FilledButton(
                    key: const ValueKey('register-submit'),
                    style: brandButtonStyle(context),
                    onPressed: _busy ? null : _submit,
                    child: const Text('Create account'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('I already have an account'),
            ),
          ],
        ),
      ),
    );
  }
}

class VerifyArgs {
  const VerifyArgs(this.verificationId, this.identifier, this.password);
  final String verificationId;
  final String identifier;
  final String password;
}

/// IT.md A3. Signs in automatically once the code is accepted.
class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({super.key, required this.args});
  final VerifyArgs? args;

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  static const _resendAfter = 60;
  final _code = TextEditingController();
  Timer? _timer;
  int _wait = _resendAfter;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _wait = _resendAfter;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _wait--);
      if (_wait <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit(VerifyArgs args) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authProvider.notifier);
    try {
      await auth.verify(args.verificationId, _code.text.trim());
      await auth.login(args.identifier, args.password);
    } catch (e) {
      final message = switch (apiErrorCode(e)) {
        'INVALID_CODE' => 'That code is not right. Check it and try again.',
        'VERIFICATION_EXPIRED' => 'This code has expired. Send a new one.',
        'RATE_LIMITED' => 'Too many attempts. Wait a minute and try again.',
        _ => apiErrorMessage(e),
      };
      if (mounted) setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend(VerifyArgs args) async {
    try {
      await ref.read(authProvider.notifier).resend(args.verificationId);
      setState(_startTimer);
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify'),
        leading: BackButton(onPressed: () => context.go('/register')),
      ),
      body: args == null
          ? SafeArea(
              child: StateView(
                icon: Icons.link_off,
                title: 'This verification link has expired.',
                action: TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Sign in'),
                ),
              ),
            )
          : _EntryBody(
              children: [
                _FormCard(
                  children: [
                    const _LitIcon(Icons.mark_email_read_outlined, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Enter the 6-digit code we sent to ${args.identifier}.',
                      textAlign: TextAlign.center,
                      style: text.bodyLarge?.copyWith(height: 1.5),
                    ),
                    if (usingFakeBackend) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Demo code: $fakeOtp',
                        textAlign: TextAlign.center,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _CodeCells(
                      controller: _code,
                      hasError: _error != null,
                      field: (focusNode, style) => TextField(
                        key: const ValueKey('verify-code'),
                        controller: _code,
                        focusNode: focusNode,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(labelText: 'Code'),
                        style: style,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _Error(_error),
                    Pressable(
                      child: FilledButton(
                        key: const ValueKey('verify-submit'),
                        style: brandButtonStyle(context),
                        onPressed: _busy ? null : () => _submit(args),
                        child: const Text('Verify'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _wait > 0 ? null : () => _resend(args),
                      child: Text(
                        _wait > 0 ? 'Resend code in ${_wait}s' : 'Resend code',
                        style: const TextStyle(
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Text('Use a different email or phone'),
                ),
              ],
            ),
    );
  }
}

/// Six digit cells drawn over the real code [TextField], which stays on top
/// (invisible) so taps, paste, autofill and `enterText` all reach it.
class _CodeCells extends StatefulWidget {
  const _CodeCells({
    required this.controller,
    required this.hasError,
    required this.field,
  });
  final TextEditingController controller;
  final bool hasError;
  final Widget Function(FocusNode focusNode, TextStyle style) field;

  @override
  State<_CodeCells> createState() => _CodeCellsState();
}

class _CodeCellsState extends State<_CodeCells> {
  static const _length = 6;
  final _focus = FocusNode();

  void _changed() => setState(() {});

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focus.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final code = widget.controller.text;
    // The cell the next digit lands in; none once the code is complete.
    final active = _focus.hasFocus && code.length < _length ? code.length : -1;
    final digit = theme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget cell(int i) {
      final BorderSide side;
      if (widget.hasError) {
        side = BorderSide(color: scheme.error, width: 1.5);
      } else if (i == active) {
        side = BorderSide(color: scheme.primary, width: 1.5);
      } else {
        side = BorderSide(color: scheme.outlineVariant);
      }
      return Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.all(Radius.circular(controlRadius)),
          border: Border.fromBorderSide(side),
        ),
        child: Text(i < code.length ? code[i] : '', style: digit),
      );
    }

    const hidden = TextStyle(color: Colors.transparent, fontSize: 1);
    return Stack(
      children: [
        ExcludeSemantics(
          child: Row(
            children: [
              for (var i = 0; i < _length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: cell(i)),
              ],
            ],
          ),
        ),
        Positioned.fill(
          // Invisible but still read out as the "Code" field.
          child: Opacity(
            opacity: 0,
            alwaysIncludeSemantics: true,
            child: widget.field(_focus, hidden),
          ),
        ),
      ],
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final identifier = normalizeIdentifier(_identifier.text)!;
    try {
      await ref.read(authProvider.notifier).login(identifier, _password.text);
    } catch (e) {
      if (!mounted) return;
      if (apiErrorCode(e) == 'CONTACT_NOT_VERIFIED') {
        final data = (e as DioException).response!.data as Map;
        context.go(
          '/verify',
          extra: VerifyArgs(
            data['verificationId'] as String,
            identifier,
            _password.text,
          ),
        );
        return;
      }
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Sign in'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        // The theme's title style pins its own colour; over the photo it
        // must be white in both modes.
        titleTextStyle: Theme.of(
          context,
        ).appBarTheme.titleTextStyle?.copyWith(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: BackButton(onPressed: () => context.go('/welcome')),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.black,
          image: DecorationImage(
            image: AssetImage('assets/demo/login_bg.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        // Scrim: keeps the bar legible and lets the card read as a lit panel.
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.45),
                Colors.black.withValues(alpha: 0.15),
                Colors.black.withValues(alpha: 0.6),
              ],
              stops: const [0, 0.45, 1],
            ),
          ),
          child: Form(
            key: _form,
            child: _EntryBody(
              children: [
                const SizedBox(height: kToolbarHeight),
                Glass(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(cardRadius),
                  ),
                  color: scheme.surface.withValues(alpha: 0.78),
                  border: Border.all(color: scheme.outlineVariant),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _fields(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _fields(BuildContext context) => [
    Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(
          'assets/branding/raha.png',
          width: 52,
          height: 52,
          excludeFromSemantics: true,
        ),
      ),
    ),
    const SizedBox(height: 20),
    TextFormField(
      key: const ValueKey('login-identifier'),
      controller: _identifier,
      decoration: const InputDecoration(
        labelText: 'Email or phone',
        prefixIcon: Icon(Icons.alternate_email),
      ),
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.username],
      validator: (v) => normalizeIdentifier(v ?? '') == null
          ? 'Enter a valid email or phone number'
          : null,
    ),
    const SizedBox(height: 16),
    TextFormField(
      key: const ValueKey('login-password'),
      controller: _password,
      decoration: const InputDecoration(
        labelText: 'Password',
        prefixIcon: Icon(Icons.lock_outline),
      ),
      obscureText: true,
      autofillHints: const [AutofillHints.password],
      validator: (v) => (v ?? '').isEmpty ? 'Enter your password' : null,
      onFieldSubmitted: (_) => _submit(),
    ),
    const SizedBox(height: 20),
    _Error(_error),
    Pressable(
      child: FilledButton(
        key: const ValueKey('login-submit'),
        style: brandButtonStyle(context),
        onPressed: _busy ? null : _submit,
        child: const Text('Sign in'),
      ),
    ),
    const SizedBox(height: 4),
    TextButton(
      onPressed: () => context.go('/register'),
      child: const Text('Create an account'),
    ),
    if (usingFakeBackend) ...[
      const SizedBox(height: 4),
      Text(
        'Demo: fan@demo.ke, creator@demo.ke or new@demo.ke, '
        'password password123',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  ];
}

/// IT.md A4. Choosing creator only starts onboarding; it never skips checks.
class RoleScreen extends ConsumerStatefulWidget {
  const RoleScreen({super.key});

  @override
  ConsumerState<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends ConsumerState<RoleScreen> {
  bool _busy = false;
  String? _error;

  /// The card tapped last, lit while its choice is saved.
  String? _picked;

  Future<void> _choose(Set<String> roles, UserRole view) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(roleProvider.notifier).set(view);
      await ref.read(authProvider.notifier).setRoles(roles);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget option(
      String title,
      String subtitle,
      IconData icon,
      Set<String> roles,
      UserRole view,
    ) => _RoleOption(
      title: title,
      subtitle: subtitle,
      icon: icon,
      selected: _picked == title,
      enabled: !_busy,
      onTap: () {
        setState(() => _picked = title);
        _choose(roles, view);
      },
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('How will you use the app?'),
        automaticallyImplyLeading: false,
      ),
      body: _EntryBody(
        children: [
          option(
            'Fan',
            'Discover creators, subscribe and buy content',
            Icons.favorite_outline,
            {'fan'},
            UserRole.fan,
          ),
          const SizedBox(height: 12),
          option(
            'Creator',
            'Sell content and go live. Requires ID verification.',
            Icons.videocam_outlined,
            {'creator'},
            UserRole.creator,
          ),
          const SizedBox(height: 12),
          option(
            'Both',
            'Use the app as a fan and as a creator',
            Icons.swap_horiz,
            {'fan', 'creator'},
            UserRole.creator,
          ),
          const SizedBox(height: 16),
          _Error(_error),
        ],
      ),
    );
  }
}

/// A pressable role card; the chosen one is lit with the brand ring.
class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final brand = Brand.of(context);
    final duration = motion(context, shortDuration);
    const ring = 2.0;
    final card = Material(
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(cardRadius - ring),
        ),
        side: selected
            ? BorderSide.none
            : BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(controlRadius),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      brand.glowA.withValues(alpha: 0.22),
                      brand.glowB.withValues(alpha: 0.22),
                    ],
                  ),
                ),
                child: Icon(icon, color: scheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.check_circle : Icons.chevron_right,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      selected: selected,
      child: AnimatedOpacity(
        // While one choice is saving, the others step back.
        opacity: enabled || selected ? 1 : 0.5,
        duration: duration,
        curve: easeOut,
        child: Pressable(
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: duration,
                  curve: easeOut,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: brand.gradient,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(cardRadius),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(padding: const EdgeInsets.all(ring), child: card),
            ],
          ),
        ),
      ),
    );
  }
}
