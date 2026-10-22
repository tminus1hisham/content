import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/api_client.dart';
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

class _Error extends StatelessWidget {
  const _Error(this.message);
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        message!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
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
    final picked = await showDatePicker(
      context: context,
      initialEntryMode: DatePickerEntryMode.input,
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked == null) return;
    if (isAdult(picked, now)) {
      await ref.read(ageGateProvider.notifier).confirm();
    } else {
      setState(() => _underage = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: _EntryBody(
        children: [
          const Icon(Icons.eighteen_up_rating_outlined, size: 64),
          const SizedBox(height: 16),
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
          ),
          const SizedBox(height: 24),
          if (!_underage)
            FilledButton(
              onPressed: _pickBirthDate,
              child: const Text('Enter date of birth'),
            ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => SystemNavigator.pop(),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// IT.md A1.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: _EntryBody(
        children: [
          Icon(Icons.auto_awesome, size: 64, color: scheme.primary),
          const SizedBox(height: 16),
          Text(
            'Content',
            style: text.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Support creators you love. Pay only for what you want, in KES.',
            textAlign: TextAlign.center,
            style: text.bodyLarge,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => context.go('/register'),
            child: const Text('Create account'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.go('/login'),
            child: const Text('Sign in'),
          ),
          const SizedBox(height: 24),
          Text(
            '18+ only. Currently available in Kenya. We protect your privacy, '
            'but no online service can guarantee anonymity.',
            textAlign: TextAlign.center,
            style: text.bodySmall,
          ),
          const _PolicyLinks(),
        ],
      ),
    );
  }
}

class _PolicyLinks extends StatelessWidget {
  const _PolicyLinks();

  @override
  Widget build(BuildContext context) {
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
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        for (final title in ['Terms', 'Privacy', 'Acceptable use'])
          TextButton(onPressed: () => show(title), child: Text(title)),
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
            TextFormField(
              key: const ValueKey('register-identifier'),
              controller: _identifier,
              decoration: const InputDecoration(
                labelText: 'Email or phone',
                hintText: 'you@example.com or 0712 345 678',
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
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: (v) =>
                  (v ?? '').length < 8 ? 'Use at least 8 characters' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _country,
              decoration: const InputDecoration(labelText: 'Country'),
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
              title: const Text(
                'I am 18+ and accept the Terms, Privacy Policy and '
                'Acceptable Use Policy',
              ),
            ),
            const SizedBox(height: 8),
            _Error(_error),
            FilledButton(
              key: const ValueKey('register-submit'),
              onPressed: _busy ? null : _submit,
              child: const Text('Create account'),
            ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify'),
        leading: BackButton(onPressed: () => context.go('/register')),
      ),
      body: args == null
          ? _EntryBody(
              children: [
                const Text('This verification link has expired.'),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Sign in'),
                ),
              ],
            )
          : _EntryBody(
              children: [
                Text('Enter the 6-digit code we sent to ${args.identifier}.'),
                if (usingFakeBackend)
                  Text(
                    'Demo code: $fakeOtp',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('verify-code'),
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Code'),
                ),
                _Error(_error),
                FilledButton(
                  key: const ValueKey('verify-submit'),
                  onPressed: _busy ? null : () => _submit(args),
                  child: const Text('Verify'),
                ),
                TextButton(
                  onPressed: _wait > 0 ? null : () => _resend(args),
                  child: Text(
                    _wait > 0 ? 'Resend code in ${_wait}s' : 'Resend code',
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Text('Use a different email or phone'),
                ),
              ],
            ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in'),
        leading: BackButton(onPressed: () => context.go('/welcome')),
      ),
      body: Form(
        key: _form,
        child: _EntryBody(
          children: [
            TextFormField(
              key: const ValueKey('login-identifier'),
              controller: _identifier,
              decoration: const InputDecoration(labelText: 'Email or phone'),
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
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              validator: (v) =>
                  (v ?? '').isEmpty ? 'Enter your password' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            _Error(_error),
            FilledButton(
              key: const ValueKey('login-submit'),
              onPressed: _busy ? null : _submit,
              child: const Text('Sign in'),
            ),
            TextButton(
              onPressed: () => context.go('/register'),
              child: const Text('Create an account'),
            ),
            if (usingFakeBackend)
              Text(
                'Demo: fan@demo.ke, creator@demo.ke or new@demo.ke, '
                'password password123',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
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
    ) => Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        enabled: !_busy,
        onTap: () => _choose(roles, view),
      ),
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
          option(
            'Creator',
            'Sell content and go live. Requires ID verification.',
            Icons.videocam_outlined,
            {'creator'},
            UserRole.creator,
          ),
          option(
            'Both',
            'Use the app as a fan and as a creator',
            Icons.swap_horiz,
            {'fan', 'creator'},
            UserRole.creator,
          ),
          const SizedBox(height: 8),
          _Error(_error),
        ],
      ),
    );
  }
}
