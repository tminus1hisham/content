import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart' show usingFakeBackend;
import '../core/demo_images.dart';

import 'motion.dart';
import 'theme.dart';

/// Gradient CTA for money and hero actions (Subscribe, Unlock, Pay, ...). A
/// [FilledButton] style rather than a widget, so keys and
/// `tester.widget<FilledButton>` keep working.
ButtonStyle brandButtonStyle(BuildContext context) {
  final brand = Brand.of(context);
  final scheme = Theme.of(context).colorScheme;
  return FilledButton.styleFrom(
    backgroundColor: Colors.transparent,
    disabledBackgroundColor: Colors.transparent,
    foregroundColor: brandInk,
    disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
    shadowColor: Colors.transparent,
    textStyle: Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
    backgroundBuilder: (context, states, child) {
      final disabled = states.contains(WidgetState.disabled);
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: disabled ? null : brand.gradient,
          color: disabled ? scheme.onSurface.withValues(alpha: 0.12) : null,
          borderRadius: const BorderRadius.all(Radius.circular(controlRadius)),
        ),
        child: child,
      );
    },
  );
}

/// App bar for a tab's root screen: a large title, matching the headings on
/// Discover, Studio and Profile.
AppBar tabAppBar(BuildContext context, String title, {List<Widget>? actions}) =>
    AppBar(
      toolbarHeight: 76,
      title: Text(title, style: Theme.of(context).textTheme.headlineMedium),
      actions: actions,
    );

/// Scales its child to [scale] while pressed. Visual only: the child keeps its
/// own InkWell or button for taps, focus and semantics.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.scale = 0.97});
  final Widget child;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  Offset _start = Offset.zero;

  // The press can outlive the widget: a long-press that moves its tile
  // disposes it before the finger lifts.
  void _set(bool down) {
    if (mounted && _down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) {
        _start = e.position;
        _set(true);
      },
      // A drag is a scroll, not a press.
      onPointerMove: (e) {
        if ((e.position - _start).distance > kTouchSlop) _set(false);
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: motion(context, pressDuration),
        curve: easeOut,
        child: widget.child,
      ),
    );
  }
}

/// The two soft accent glows from the splash screen, for headers.
class GlowBackground extends StatelessWidget {
  const GlowBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final brand = Brand.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final s = dark ? 1.4 : 1.0;
    // Orange over near-black reads as brown, so pink leads after dark.
    final top = dark ? brand.glowB : brand.glowA;
    final bottom = dark ? brand.glowA : brand.glowB;
    RadialGradient glow(Alignment at, double radius, Color c, double a) =>
        RadialGradient(
          center: at,
          radius: radius,
          colors: [
            c.withValues(alpha: a * s),
            c.withValues(alpha: 0),
          ],
        );
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: glow(const Alignment(1.1, -0.8), 1.15, top, .15),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: glow(const Alignment(-1.1, 0.9), 1.1, bottom, .1),
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted panel for floating chrome (tab bar, sticky CTAs, media badges).
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.color,
    this.border,
  });
  final Widget child;
  final BorderRadius borderRadius;
  final Color? color;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color:
                color ??
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
            borderRadius: borderRadius,
            border: border,
          ),
          child: child,
        ),
      ),
    );
  }
}

int _hash(String s) => s.codeUnits.fold(7, (a, b) => (a * 31 + b) & 0x7fffffff);

// Warm, brand-family pairs: every creator looks distinct but on-brand.
const _identityPairs = [
  (Color(0xFFFF9A43), Color(0xFFE0466A)),
  (Color(0xFFEC6A72), Color(0xFFA8346F)),
  (Color(0xFFFF65A1), Color(0xFF8E3392)),
  (Color(0xFFFFB86B), Color(0xFFD9506A)),
  (Color(0xFFF0567A), Color(0xFF6E2754)),
  (Color(0xFFFFA07A), Color(0xFFC23A6C)),
];

/// Stable identity colours, also used when a profile has no demo photo.
(Color, Color) identityColors(String id) =>
    _identityPairs[_hash(id) % _identityPairs.length];

/// "12.4K followers" style counts.
String compactCount(int n) => NumberFormat.compact().format(n);

class CreatorAvatar extends StatelessWidget {
  const CreatorAvatar({
    super.key,
    required this.id,
    required this.name,
    this.size = 44,
    this.ring = false,
  });
  final String id;
  final String name;
  final double size;

  /// Accent gradient ring: subscribed, or live.
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final (a, b) = identityColors(id);
    final photo = usingFakeBackend ? demoImageFor(id, number: 4) : null;
    final face = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: photo == null
            ? null
            : DecorationImage(
                image: AssetImage(photo),
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.6),
              ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [a, b],
        ),
      ),
      child: photo != null
          ? null
          : Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              // Decorative and inside a fixed circle: the name is shown alongside.
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: size * 0.42,
                height: 1,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: Colors.white,
              ),
            ),
    );
    final avatar = ring
        ? Container(
            padding: EdgeInsets.all(math.max(2, size * 0.05)),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: Brand.of(context).gradient,
            ),
            child: Container(
              padding: EdgeInsets.all(math.max(2, size * 0.04)),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.surface,
              ),
              child: face,
            ),
          )
        : face;
    return ExcludeSemantics(child: avatar);
  }
}

/// Demo profile photo cover, with a generated cover for other profiles.
class CreatorBanner extends StatelessWidget {
  const CreatorBanner({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final photo = usingFakeBackend ? demoImageFor(id, number: 4) : null;
    if (photo != null) {
      return Image.asset(
        photo,
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.5),
        color: Colors.black.withValues(alpha: 0.55),
        colorBlendMode: BlendMode.darken,
        excludeFromSemantics: true,
      );
    }
    final (a, b) = identityColors(id);
    final h = _hash(id);
    Alignment at(int seed) =>
        Alignment((seed % 200) / 100 - 1, (seed ~/ 200 % 200) / 100 - 1);
    BoxDecoration pool(Alignment center, double radius, Color c, double a) =>
        BoxDecoration(
          gradient: RadialGradient(
            center: center,
            radius: radius,
            colors: [
              c.withValues(alpha: a),
              c.withValues(alpha: 0),
            ],
          ),
        );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(b, Colors.black, 0.45)!,
            Color.lerp(a, Colors.black, 0.78)!,
          ],
        ),
      ),
      child: DecoratedBox(
        decoration: pool(at(h), 1.1, a, 0.85),
        child: DecoratedBox(
          decoration: pool(at(h ~/ 7 + 91), 0.9, b, 0.7),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Placeholder block for skeletons.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius = 8});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Pulses its child while mounted, i.e. only while something is loading.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(
      begin: 0.45,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
    child: widget.child,
  );
}

/// Loading state for lists: rows shaped like the content that's coming.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 5, this.itemHeight = 76});
  final int count;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Loading',
      child: ExcludeSemantics(
        child: Shimmer(
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: count,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, _) => Container(
              height: itemHeight,
              padding: const EdgeInsets.all(16),
              alignment: Alignment.bottomLeft,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: const BorderRadius.all(
                  Radius.circular(cardRadius),
                ),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: const Row(
                children: [
                  Skeleton(width: 44, height: 44, radius: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton(width: 140),
                        SizedBox(height: 8),
                        Skeleton(width: 90, height: 12),
                      ],
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
}

/// Shared empty / error look: a lit icon, a title, an optional way forward.
class StateView extends StatelessWidget {
  const StateView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final brand = Brand.of(context);
    final content = Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
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
                child: Icon(icon, size: 30, color: scheme.primary),
              ),
              const SizedBox(height: 20),
              Text(title, textAlign: TextAlign.center, style: text.titleMedium),
              if (message != null) ...[
                const SizedBox(height: 6),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      ),
    );
    // Scrolls when given a bounded box (large text); sits inline in slivers.
    return LayoutBuilder(
      builder: (context, constraints) => constraints.hasBoundedHeight
          ? Center(child: SingleChildScrollView(child: content))
          : content,
    );
  }
}

/// Fades and rises its child in once, staggered by [index] (capped, so long
/// lists never wait).
class Entrance extends StatefulWidget {
  const Entrance({super.key, this.index = 0, required this.child});
  final int index;
  final Widget child;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _t;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final delay = 40 * math.min<int>(widget.index, 8);
    final total = 300 + delay;
    final controller = _controller = AnimationController(
      vsync: this,
      duration: motion(context, Duration(milliseconds: total)),
    );
    _t = CurvedAnimation(
      parent: controller,
      curve: Interval(delay / total, 1, curve: easeOut),
    );
    if (controller.duration == Duration.zero) {
      controller.value = 1;
    } else {
      controller.forward();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _t,
    child: AnimatedBuilder(
      animation: _t,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, 8 * (1 - _t.value)),
        child: child,
      ),
      child: widget.child,
    ),
  );
}
