import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../app/ui.dart';
import '../../core/api_client.dart';
import '../../core/money.dart';
import '../auth/auth_controller.dart';
import '../content/content_api.dart';
import '../content/discover_screens.dart';
import '../content/media_view.dart';
import '../disguise/lock_gate.dart';
import '../disguise/pin_pad.dart';
import 'commerce_api.dart';

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

String _date(BuildContext context, String iso) => MaterialLocalizations.of(
  context,
).formatMediumDate(DateTime.parse(iso).toLocal());

const _tabular = [FontFeature.tabularFigures()];

/// List padding that centres a 600-wide column on wide screens.
EdgeInsets _pad(BuildContext context) => EdgeInsets.symmetric(
  horizontal: math.max(16, (MediaQuery.sizeOf(context).width - 600) / 2),
  vertical: 16,
);

/// Creators have no name on orders; the description carries the handle.
String _handleIn(String description) =>
    RegExp(r'@([\w.]+)').firstMatch(description)?.group(1) ?? description;

/// Hairline-bordered card from the theme, tappable with press feedback.
Widget _card({required Widget child, VoidCallback? onTap}) {
  final card = Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: onTap == null ? child : InkWell(onTap: onTap, child: child),
  );
  return onTap == null ? card : Pressable(child: card);
}

/// Heading above a group of rows.
Widget _section(BuildContext context, String title) => Padding(
  padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
  child: Text(title, style: Theme.of(context).textTheme.titleMedium),
);

/// Rounded-square tonal icon used as the leading element of money rows.
class _TonalIcon extends StatelessWidget {
  const _TonalIcon(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(controlRadius),
      ),
      child: Icon(icon, color: scheme.onSecondaryContainer),
    );
  }
}

/// IT.md F6 + F7. The server prices the order; access is granted only when
/// the server reports the payment `succeeded`, never from this screen.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.type,
    required this.itemId,
    this.amountCents,
  });

  /// post | subscription | message | ticket | tip
  final String type;
  final String itemId;

  /// Only for tips, where the fan chooses the amount.
  final int? amountCents;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

/// Statuses with their own view in [_CheckoutScreenState._result]; anything
/// else shows the waiting view.
const _outcomes = {
  'succeeded',
  'failed',
  'cancelled',
  'expired',
  'reversed',
  'under_review',
  'still_waiting',
};

/// Outcomes where the payment did not go through (shown as a failed step).
const _unsuccessful = {'failed', 'cancelled', 'expired', 'reversed'};

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  static const pollEvery = Duration(seconds: 2);
  static const giveUpAfter = 45; // polls, about 90 seconds

  final _orderKey = newIdempotencyKey();
  final _phone = TextEditingController();
  Json? _order;
  String? _error;
  String? _paymentId;
  String? _status;
  String? _failureReason;
  Timer? _timer;
  int _polls = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final identifier = ref.read(authProvider).user?.identifier ?? '';
    if (identifier.startsWith('+254')) {
      _phone.text = '0${identifier.substring(4)}';
    }
    _createOrder();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _createOrder() async {
    try {
      final response = await ref
          .read(dioProvider)
          .post<Json>(
            '/orders',
            data: {
              'type': widget.type,
              'itemId': widget.itemId,
              'amountCents': ?widget.amountCents,
              'idempotencyKey': _orderKey,
            },
          );
      setState(() => _order = response.data);
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    }
  }

  Future<void> _pay() async {
    final phone = normalizeIdentifier(_phone.text);
    if (phone == null || !RegExp(r'^\+254[17]\d{8}$').hasMatch(phone)) {
      return _snack(context, 'Enter your M-Pesa number');
    }
    setState(() => _busy = true);
    try {
      final payment =
          (await ref
                  .read(dioProvider)
                  .post<Json>(
                    '/orders/${_order!['id']}/checkout',
                    data: {
                      'method': 'mpesa',
                      'phone': phone,
                      'idempotencyKey': newIdempotencyKey(),
                    },
                  ))
              .data!;
      setState(() {
        _paymentId = payment['id'] as String;
        _status = payment['status'] as String;
        _polls = 0;
      });
      _timer = Timer.periodic(pollEvery, (_) => _poll());
    } catch (e) {
      if (mounted) _snack(context, apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _poll() async {
    if (++_polls > giveUpAfter) {
      _timer?.cancel();
      setState(() => _status = 'still_waiting');
      return;
    }
    try {
      final payment =
          (await ref.read(dioProvider).get<Json>('/payments/$_paymentId'))
              .data!;
      if (!mounted) return;
      final status = payment['status'] as String;
      setState(() {
        _status = status;
        _failureReason = payment['failureReason'] as String?;
      });
      if (terminalPaymentStates.contains(status)) {
        _timer?.cancel();
        // A reversal can withdraw access granted earlier, so refresh then too.
        if (status == 'succeeded' || status == 'reversed') _refreshAccess();
      }
    } catch (_) {
      // Offline for a moment: keep polling; the server state is unchanged.
    }
  }

  void _refreshAccess() {
    if (widget.type == 'post') ref.invalidate(postProvider(widget.itemId));
    ref.invalidate(creatorPostsProvider);
    ref.invalidate(creatorProvider);
    ref.invalidate(purchasesProvider);
    ref.invalidate(subscriptionsProvider);
  }

  void _checkAgain() {
    _polls = 0;
    setState(() => _status = 'processing');
    _timer = Timer.periodic(pollEvery, (_) => _poll());
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: _error == null
            ? const SkeletonList(count: 2, itemHeight: 120)
            : StateView(icon: Icons.error_outline, title: _error!),
      );
    }
    final text = Theme.of(context).textTheme;
    final copy = _copyFor(order);
    // Scaffold and panel share the surface colour, so the 24px the panel is
    // lifted over the hero leaves no visible gap at the bottom.
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        centerTitle: true,
        toolbarHeight: 68,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Checkout',
              style: text.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              copy.subtitle,
              style: text.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _paymentId == null ? _payBar(copy) : null,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _CheckoutHero(order: order, copy: copy),
          Transform.translate(
            offset: const Offset(0, -24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(sheetRadius),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      28,
                      20,
                      16 + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PriceRow(order: order),
                        const Divider(height: 40),
                        // Cross-fades form -> waiting -> outcome; no movement
                        // on a money screen.
                        AnimatedSwitcher(
                          duration: motion(context, shortDuration),
                          switchInCurve: easeOut,
                          switchOutCurve: easeOut,
                          // Top-aligned, so the outgoing view never shifts.
                          layoutBuilder: (current, previous) => Stack(
                            alignment: Alignment.topCenter,
                            children: [...previous, ?current],
                          ),
                          child: KeyedSubtree(
                            key: ValueKey(
                              _paymentId == null
                                  ? 'form'
                                  : _outcomes.contains(_status)
                                  ? _status
                                  : 'waiting',
                            ),
                            child: _paymentId == null
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: _payForm(copy),
                                  )
                                : _result(order),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _payForm(_CheckoutCopy copy) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          'Choose payment method',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      // The only method the server takes; shown selected, as one radio card.
      Semantics(
        selected: true,
        inMutuallyExclusiveGroup: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(controlRadius),
            border: Border.all(color: scheme.primary, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.radio_button_checked, color: scheme.primary),
                  const SizedBox(width: 12),
                  const _TonalIcon(Icons.phone_android),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'M-Pesa',
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'You will get a prompt on your phone',
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _mpesaGreen,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'M-PESA',
                        style: text.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('checkout-phone'),
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'M-Pesa number',
                  hintText: '0712 345 678',
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  /// Pinned under the form, so the CTA never scrolls off a short screen.
  Widget _payBar(_CheckoutCopy copy) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Pressable(
                    child: SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        key: const ValueKey('checkout-pay'),
                        style: brandButtonStyle(context),
                        onPressed: _busy ? null : _pay,
                        icon: const Icon(Icons.lock_outline, size: 20),
                        label: Text(
                          'Pay ${formatKes(_order!['totalCents'] as int)} '
                          '& ${copy.verb}',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    copy.footer,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _result(Json order) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final failed = _unsuccessful.contains(_status);
    final (badge, onBadge) = _status == 'succeeded'
        ? (scheme.primary.withValues(alpha: 0.14), scheme.primary)
        : failed
        ? (scheme.error.withValues(alpha: 0.14), scheme.error)
        : (scheme.surfaceContainerHighest, scheme.primary);
    Widget state(
      IconData icon,
      String title,
      String body,
      List<Widget> actions,
    ) => _card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PaymentSteps(status: _status),
            const SizedBox(height: 24),
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: badge, shape: BoxShape.circle),
                child: Icon(icon, size: 28, color: onBadge),
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            for (final (i, action) in actions.indexed) ...[
              if (i > 0) const SizedBox(height: 8),
              action,
            ],
          ],
        ),
      ),
    );
    final done = FilledButton(
      onPressed: () => context.pop(_status == 'succeeded'),
      child: const Text('Done'),
    );
    final retry = OutlinedButton(
      onPressed: () => setState(() => _paymentId = null),
      child: const Text('Try again'),
    );
    return switch (_status) {
      'succeeded' => state(
        Icons.check_circle_outline,
        'Payment received',
        switch (order['type']) {
          'post' => 'The post is unlocked. Your receipt is in My library.',
          'subscription' =>
            'Your subscription is active. Your receipt is in My library.',
          'ticket' => 'You have a ticket. Enjoy the stream!',
          'tip' => 'Your tip was sent. Thank you!',
          _ => 'Unlocked. Your receipt is in My library.',
        },
        [done],
      ),
      'failed' => state(
        Icons.error_outline,
        'Payment failed',
        _failureReason == 'insufficient_funds'
            ? 'M-Pesa said there were not enough funds. You were not charged.'
            : 'M-Pesa did not complete the payment. You were not charged.',
        [retry],
      ),
      'cancelled' => state(
        Icons.cancel_outlined,
        'Payment cancelled',
        'The M-Pesa prompt was cancelled. You were not charged.',
        [retry],
      ),
      'expired' => state(
        Icons.timer_off_outlined,
        'Payment expired',
        'The M-Pesa prompt timed out. You were not charged.',
        [retry],
      ),
      'reversed' => state(
        Icons.undo_rounded,
        'Payment reversed',
        'M-Pesa reversed this payment, so nothing was unlocked. Any money '
            'taken goes back to your M-Pesa account.',
        [retry],
      ),
      'under_review' => state(
        Icons.hourglass_empty,
        'Payment under review',
        'We are checking this payment. Access unlocks once it is confirmed.',
        [done],
      ),
      'still_waiting' => state(
        Icons.hourglass_empty,
        'Still waiting for M-Pesa',
        'If you entered your PIN, the payment may still arrive. Nothing '
            'unlocks until M-Pesa confirms it.',
        [
          FilledButton(
            onPressed: _checkAgain,
            child: const Text('Check again'),
          ),
          done,
        ],
      ),
      _ => state(
        Icons.phone_android,
        'Check your phone',
        'Enter your M-Pesa PIN on the prompt to pay '
            '${formatKes(order['totalCents'] as int)}. Waiting for M-Pesa to '
            'confirm…',
        [
          const ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(2)),
            child: LinearProgressIndicator(),
          ),
        ],
      ),
    };
  }
}

const _mpesaGreen = Color(0xFF3CA748);

/// What checkout says about each kind of order. Only what the server
/// actually grants is promised here.
typedef _CheckoutCopy = ({
  String subtitle,
  String label,
  String verb,
  String footer,
  List<(IconData, String)> benefits,
});

_CheckoutCopy _copyFor(Json order) {
  final handle = _handleIn(order['description'] as String);
  const oneOff = 'Secure M-Pesa payment · Instant access · No subscription';
  return switch (order['type']) {
    'post' => (
      subtitle: 'Unlock this post',
      label: 'Paid post',
      verb: 'unlock',
      footer: oneOff,
      benefits: const [
        (Icons.all_inclusive, 'Permanent access to this post'),
        (Icons.receipt_long_outlined, 'Receipt kept in My library'),
        (Icons.lock_open_outlined, 'Unlocks as soon as M-Pesa confirms'),
      ],
    ),
    'subscription' => (
      subtitle: 'Subscribe to @$handle',
      label: 'Monthly subscription',
      verb: 'subscribe',
      footer: 'Secure M-Pesa payment · Cancel any time in My library',
      benefits: const [
        (Icons.photo_library_outlined, 'All subscriber posts'),
        (Icons.chat_bubble_outline, 'Priority messages'),
        (Icons.event_repeat, 'Renews monthly, cancel any time'),
      ],
    ),
    'ticket' => (
      subtitle: 'Get your live ticket',
      label: 'Live ticket',
      verb: 'get ticket',
      footer: oneOff,
      benefits: const [
        (Icons.live_tv_outlined, 'Entry to this live stream'),
        (Icons.confirmation_number_outlined, 'One payment, no renewal'),
        (Icons.lock_open_outlined, 'Opens as soon as M-Pesa confirms'),
      ],
    ),
    'tip' => (
      subtitle: 'Send a live tip',
      label: 'Live tip',
      verb: 'send tip',
      footer: 'Secure M-Pesa payment · One-time · No subscription',
      benefits: [
        (Icons.favorite_outline, 'Goes to @$handle'),
        (Icons.payments_outlined, 'One payment, no renewal'),
        (Icons.bolt_outlined, 'Sent as soon as M-Pesa confirms'),
      ],
    ),
    _ => (
      subtitle: 'Unlock this attachment',
      label: 'Paid attachment',
      verb: 'unlock',
      footer: oneOff,
      benefits: const [
        (Icons.chat_outlined, 'Yours to keep in the chat'),
        (Icons.all_inclusive, 'Permanent access'),
        (Icons.lock_open_outlined, 'Unlocks as soon as M-Pesa confirms'),
      ],
    ),
  };
}

/// Image-led header: a blurred backdrop, a framed preview and what the fan
/// gets. Posts show their generic teaser cover, never the real media or a
/// blur of it (FR-DIS-003); everything else shows the creator's banner.
class _CheckoutHero extends StatelessWidget {
  const _CheckoutHero({required this.order, required this.copy});
  final Json order;
  final _CheckoutCopy copy;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final handle = _handleIn(order['description'] as String);
    final creatorId = order['creatorId'] as String? ?? handle;
    final cover = order['type'] == 'post'
        ? lockedCoverFor(order['itemId'] as String)
        : null;
    final preview = cover != null
        ? Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(cover, fit: BoxFit.cover),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Glass(
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                    color: Colors.black.withValues(alpha: 0.35),
                    child: const Padding(
                      padding: EdgeInsets.all(7),
                      child: Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )
        : Stack(
            fit: StackFit.expand,
            children: [
              CreatorBanner(id: creatorId),
              Center(
                child: CreatorAvatar(
                  id: creatorId,
                  name: handle,
                  size: 64,
                  ring: true,
                ),
              ),
            ],
          );
    final white = Colors.white.withValues(alpha: 0.88);
    return Stack(
      children: [
        Positioned.fill(
          child: cover != null
              // Scaled up so the blur never shows soft edges.
              ? ClipRect(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                    child: Transform.scale(
                      scale: 1.2,
                      child: Image.asset(cover, fit: BoxFit.cover),
                    ),
                  ),
                )
              : CreatorBanner(id: creatorId),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.5),
                ],
              ),
            ),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              // Below the app bar; the bottom clears the lifted panel.
              padding: EdgeInsets.fromLTRB(
                24,
                MediaQuery.paddingOf(context).top + 68 + 16,
                24,
                24 + 32,
              ),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 132,
                      height: 176,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(cardRadius),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.55),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(cardRadius - 1.5),
                        child: preview,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@$handle',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          copy.label,
                          style: text.bodyMedium?.copyWith(color: white),
                        ),
                        const SizedBox(height: 16),
                        for (final (icon, line) in copy.benefits)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(icon, size: 20, color: Colors.white),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    line,
                                    style: text.bodySmall?.copyWith(
                                      color: white,
                                      height: 1.3,
                                    ),
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
          ),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.order});
  final Json order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final fees = order['feesCents'] as int;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                'Price',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              formatKes(order['totalCents'] as int),
              style: text.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                fontFeatures: _tabular,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          order['recurring'] == true
              ? 'Renews every month until you cancel.'
              : 'One-time payment. No renewal.',
          textAlign: TextAlign.end,
          style: muted,
        ),
        if (fees > 0)
          Text(
            'Includes ${formatKes(fees)} fees',
            textAlign: TextAlign.end,
            style: muted?.copyWith(fontFeatures: _tabular),
          ),
      ],
    );
  }
}

/// Where the M-Pesa payment is: prompt sent, waiting, confirmed. Each step
/// has an icon and a label, so the state never relies on colour alone.
class _PaymentSteps extends StatelessWidget {
  const _PaymentSteps({required this.status});
  final String? status;

  @override
  Widget build(BuildContext context) {
    final failed = _unsuccessful.contains(status);
    final steps = <(String, _Step)>[
      ('Prompt sent', _Step.done),
      if (failed)
        ('Not completed', _Step.failed)
      else
        ('Waiting', status == 'succeeded' ? _Step.done : _Step.active),
      if (status == 'under_review')
        ('In review', _Step.active)
      else
        ('Confirmed', status == 'succeeded' ? _Step.done : _Step.todo),
    ];
    final scheme = Theme.of(context).colorScheme;
    bool reached(_Step s) => s == _Step.done || s == _Step.active;
    Widget line(bool lit) => Expanded(
      child: Container(
        height: 2,
        color: lit ? scheme.primary : scheme.outlineVariant,
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, (label, step)) in steps.indexed)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    if (i == 0) const Spacer() else line(reached(step)),
                    _StepDot(step),
                    if (i == steps.length - 1)
                      const Spacer()
                    else
                      line(reached(steps[i + 1].$2)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: step == _Step.todo
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

enum _Step { done, active, failed, todo }

class _StepDot extends StatelessWidget {
  const _StepDot(this.step);
  final _Step step;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (fill, border, icon, color) = switch (step) {
      _Step.done => (
        scheme.primary,
        scheme.primary,
        Icons.check,
        scheme.onPrimary,
      ),
      _Step.failed => (
        scheme.errorContainer,
        scheme.error,
        Icons.close,
        scheme.onErrorContainer,
      ),
      _Step.active => (
        scheme.surface,
        scheme.primary,
        Icons.more_horiz,
        scheme.primary,
      ),
      _Step.todo => (
        scheme.surface,
        scheme.outlineVariant,
        null,
        scheme.onSurfaceVariant,
      ),
    };
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 2),
      ),
      child: icon == null ? null : Icon(icon, size: 14, color: color),
    );
  }
}

/// IT.md F8, F9 and F11: purchases, receipts, refunds and subscriptions.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  Future<void> _refund(BuildContext context, WidgetRef ref, Json order) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request a refund'),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(labelText: 'What went wrong?'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send request'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(dioProvider)
          .post<void>(
            '/orders/${order['id']}/refund-requests',
            data: {'reason': reason.text.trim()},
          );
      ref.invalidate(purchasesProvider);
      if (context.mounted) _snack(context, 'Refund request sent');
    } catch (e) {
      if (context.mounted) _snack(context, apiErrorMessage(e));
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, Json sub) async {
    final ends = _date(context, sub['endsAt'] as String);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel subscription?'),
        content: Text('It will not renew. You keep access until $ends.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel subscription'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(dioProvider)
          .post<void>('/subscriptions/${sub['id']}/cancel');
      ref.invalidate(subscriptionsProvider);
    } catch (e) {
      if (context.mounted) _snack(context, apiErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My library'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Purchases'),
              Tab(text: 'Subscriptions'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            asyncBody(
              ref.watch(purchasesProvider),
              () => ref.invalidate(purchasesProvider),
              (orders) => orders.isEmpty
                  ? const StateView(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Nothing bought yet',
                    )
                  : ListView.separated(
                      padding: _pad(context),
                      itemCount: orders.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => Entrance(
                        index: i,
                        child: _purchase(context, ref, orders[i]),
                      ),
                    ),
            ),
            asyncBody(
              ref.watch(subscriptionsProvider),
              () => ref.invalidate(subscriptionsProvider),
              (subs) => subs.isEmpty
                  ? const StateView(
                      icon: Icons.star_outline,
                      title: 'No subscriptions',
                    )
                  : ListView.separated(
                      padding: _pad(context),
                      itemCount: subs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => Entrance(
                        index: i,
                        child: _subscription(context, ref, subs[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _purchase(BuildContext context, WidgetRef ref, Json o) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final description = o['description'] as String;
    final paid = o['status'] == 'paid';
    return _card(
      onTap: o['type'] == 'post'
          ? () => context.push('/p/${o['itemId']}')
          : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 14, paid ? 4 : 16, 14),
        child: Row(
          children: [
            CreatorAvatar(
              id: o['creatorId'] as String? ?? description,
              name: _handleIn(description),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(description, style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    '${formatKes(o['totalCents'] as int)} · '
                    '${orderStatusLabels[o['status']] ?? o['status']} · '
                    '${_date(context, o['createdAt'] as String)}',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: _tabular,
                    ),
                  ),
                ],
              ),
            ),
            if (paid)
              PopupMenuButton<String>(
                onSelected: (_) => _refund(context, ref, o),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'refund', child: Text('Request refund')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _subscription(BuildContext context, WidgetRef ref, Json s) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final creator = s['creator'] as Json;
    final active = s['status'] == 'active';
    return _card(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 14, active ? 8 : 16, 14),
        child: Row(
          children: [
            CreatorAvatar(
              id: creator['id'] as String? ?? '${creator['handle']}',
              name: creator['displayName'] as String? ?? '',
              ring: active,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('@${creator['handle']}', style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    '${formatKes(s['priceCents'] as int)}/month · '
                    '${active ? 'Renews ${_date(context, s['renewsAt'] as String)}' : 'Ends ${_date(context, s['endsAt'] as String)}'}',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: _tabular,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (active)
              TextButton(
                onPressed: () => _cancel(context, ref, s),
                child: const Text('Cancel'),
              )
            else
              Text(
                'Cancelled',
                style: text.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// IT.md C10. Every figure comes from the server's ledger.
class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: asyncBody(
        ref.watch(earningsProvider),
        () {
          ref.invalidate(earningsProvider);
        },
        (e) {
          Widget bucket(String label, String key) => Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatKes(e[key] as int),
                  style: text.titleMedium?.copyWith(fontFeatures: _tabular),
                ),
                Text(label, style: muted),
              ],
            ),
          );
          final canPay =
              (e['availableCents'] as int) >= (e['payoutMinimumCents'] as int);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(transactionsProvider);
              ref.invalidate(payoutRequestsProvider);
              ref.invalidate(earningsProvider);
              await ref.read(earningsProvider.future);
            },
            child: ListView(
              padding: _pad(context),
              children: [
                _card(
                  child: Stack(
                    children: [
                      const Positioned.fill(child: GlowBackground()),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Available',
                              style: text.labelLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                formatKes(e['availableCents'] as int),
                                key: const ValueKey('earnings-available'),
                                style: text.displayMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -1.5,
                                  fontFeatures: _tabular,
                                ),
                              ),
                            ),
                            const Divider(height: 32),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                bucket('Pending', 'pendingCents'),
                                bucket('Reserved', 'reservedCents'),
                                bucket('Paid out', 'paidOutCents'),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Pressable(
                              child: FilledButton(
                                style: brandButtonStyle(context),
                                onPressed: canPay
                                    ? () => context.push('/earnings/payout')
                                    : null,
                                child: const Text('Request payout'),
                              ),
                            ),
                            if (!canPay) ...[
                              const SizedBox(height: 8),
                              Text(
                                'You can request a payout from '
                                '${formatKes(e['payoutMinimumCents'] as int)}.',
                                textAlign: TextAlign.center,
                                style: muted,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Platform commission: ${e['commissionPercent']}% under your '
                    'agreement. New earnings stay pending until settlement.',
                    style: muted,
                  ),
                ),
                _PayoutHistory(),
                _section(context, 'Transactions'),
                _Transactions(),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Rows in one hairline card, split by inset dividers.
Widget _group(List<Widget> rows) => _card(
  child: Column(
    children: [
      for (final (i, row) in rows.indexed) ...[
        if (i > 0) const Divider(height: 1, indent: 72),
        row,
      ],
    ],
  ),
);

class _PayoutHistory extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payouts = ref.watch(payoutRequestsProvider).valueOrNull ?? const [];
    if (payouts.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(context, 'Payout requests'),
        _group([
          for (final p in payouts)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  const _TonalIcon(Icons.outbox),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatKes(p['amountCents'] as int),
                          style: text.titleMedium?.copyWith(
                            fontFeatures: _tabular,
                          ),
                        ),
                        Text(
                          '${p['destination']} · '
                          '${_date(context, p['createdAt'] as String)}',
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(999),
                      ),
                    ),
                    child: Text(
                      _payoutLabels[p['status']] ?? '${p['status']}',
                      style: text.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
        ]),
      ],
    );
  }
}

const _payoutLabels = {
  'requested': 'Requested',
  'under_review': 'In review',
  'approved': 'Approved',
  'processing': 'Processing',
  'paid': 'Paid',
  'failed': 'Failed',
  'cancelled': 'Cancelled',
};

class _Transactions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(transactionsProvider).valueOrNull ?? const [];
    if (txs.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    return _group([
      for (final t in txs)
        ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
          shape: const Border(),
          collapsedShape: const Border(),
          // Direction is carried by the arrow and the sign, not colour alone.
          leading: _TonalIcon(
            (t['netCents'] as int) < 0
                ? Icons.arrow_upward
                : Icons.arrow_downward,
          ),
          title: Text(t['description'] as String, style: text.titleSmall),
          subtitle: Text(
            _date(context, t['createdAt'] as String),
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          trailing: Text(
            ((t['netCents'] as int) < 0 ? '' : '+') +
                formatKes(t['netCents'] as int),
            style: text.titleSmall?.copyWith(
              fontFeatures: _tabular,
              color: (t['netCents'] as int) < 0
                  ? scheme.onSurface
                  : scheme.primary,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(72, 0, 16, 14),
          children: [
            for (final (label, key) in [
              ('Gross', 'grossCents'),
              ('Commission', 'commissionCents'),
              ('Processing fees', 'feesCents'),
              ('Net', 'netCents'),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(label, style: muted)),
                    Text(
                      formatKes(t[key] as int),
                      style: muted?.copyWith(fontFeatures: _tabular),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Status · ${t['status']}',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (t['contractRef'] != null)
                  Text(
                    'Agreement ${t['contractRef']}',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
    ]);
  }
}

// IT.md C11.
class PayoutRequestScreen extends ConsumerStatefulWidget {
  const PayoutRequestScreen({super.key});

  @override
  ConsumerState<PayoutRequestScreen> createState() =>
      _PayoutRequestScreenState();
}

class _PayoutRequestScreenState extends ConsumerState<PayoutRequestScreen> {
  final _amount = TextEditingController();
  final _key = newIdempotencyKey();
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit(Json earnings, Json method) async {
    final kes = int.tryParse(_amount.text);
    final min = earnings['payoutMinimumCents'] as int;
    final max = earnings['payoutMaximumCents'] as int;
    final available = earnings['availableCents'] as int;
    if (kes == null || kes * 100 < min || kes * 100 > max) {
      return _snack(
        context,
        'Enter between ${formatKes(min)} and ${formatKes(max)}',
      );
    }
    if (kes * 100 > available) {
      return _snack(context, 'That is more than your available balance');
    }
    // Re-authenticate before money leaves (IT.md C11 step 4).
    final bool confirmed;
    if (ref.read(lockProvider).hasPin == true) {
      confirmed = await showPinSheet(context, ref);
    } else {
      confirmed =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Confirm payout'),
              content: Text(
                'Send ${formatKes(kes * 100)} to ${method['phoneMasked']}?',
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
          ) ==
          true;
    }
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(dioProvider)
          .post<void>(
            '/creators/me/payout-requests',
            data: {
              'amountCents': kes * 100,
              'payoutMethodId': method['id'],
              'idempotencyKey': _key,
            },
          );
      ref.invalidate(earningsProvider);
      ref.invalidate(payoutRequestsProvider);
      if (!mounted) return;
      _snack(context, 'Payout requested');
      context.pop();
    } catch (e) {
      if (mounted) _snack(context, apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final earnings = ref.watch(earningsProvider).valueOrNull;
    final methods = ref.watch(payoutMethodsProvider).valueOrNull;
    final method = methods?.where((m) => m['verified'] == true).firstOrNull;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return Scaffold(
      appBar: AppBar(title: const Text('Request payout')),
      body: earnings == null || methods == null
          ? const SkeletonList(count: 3)
          : ListView(
              padding: _pad(context),
              children: [
                _card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available',
                          style: text.labelLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatKes(earnings['availableCents'] as int),
                            style: text.displaySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1,
                              fontFeatures: _tabular,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Minimum ${formatKes(earnings['payoutMinimumCents'] as int)}'
                          ' · maximum ${formatKes(earnings['payoutMaximumCents'] as int)}',
                          style: muted?.copyWith(fontFeatures: _tabular),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (method == null)
                  _card(
                    onTap: () => context.push('/onboarding/payout'),
                    child: ListTile(
                      leading: Icon(Icons.warning_amber, color: scheme.error),
                      title: const Text(
                        'Add and verify an M-Pesa number first',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  )
                else
                  _card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const _TonalIcon(Icons.phone_android),
                            title: Text('M-Pesa ${method['phoneMasked']}'),
                            subtitle: Text('${method['accountName']}'),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            key: const ValueKey('payout-amount'),
                            controller: _amount,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              prefixText: 'KSh ',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No payout fee. Payouts are reviewed and usually reach '
                            'M-Pesa within 1–2 working days.',
                            style: muted,
                          ),
                          const SizedBox(height: 16),
                          Pressable(
                            child: FilledButton(
                              key: const ValueKey('payout-submit'),
                              style: brandButtonStyle(context),
                              onPressed: _busy
                                  ? null
                                  : () => _submit(earnings, method),
                              child: const Text('Request payout'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
