import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/confirm_sheet.dart';
import '../../app/motion.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../app/ui.dart';
import '../../core/api_client.dart';
import '../../core/money.dart';
import '../auth/auth_controller.dart';
import '../commerce/commerce_api.dart';
import '../content/content_api.dart';

/// Accessibility text sizes: side-by-side cards stack instead.
bool _largeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(14) / 14 > 1.4;

const _tabular = [FontFeature.tabularFigures()];

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final role = ref.watch(roleProvider);
    final user = ref.watch(authProvider).user;
    final roles = user?.roles ?? const <String>{};

    Future<void> becomeCreator() async {
      try {
        // Save the role first, so a failed save leaves the fan view in place.
        await ref.read(authProvider.notifier).setRoles({...roles, 'creator'});
        await ref.read(roleProvider.notifier).set(UserRole.creator);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
        }
      }
    }

    void setRole(UserRole r) => ref.read(roleProvider.notifier).set(r);

    final fan = role == UserRole.fan;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          // Clears the floating tab bar the shell draws over the body.
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (user != null)
                        CreatorAvatar(
                          id: user.id,
                          name: user.identifier,
                          size: 40,
                        ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Settings',
                        icon: const Icon(Icons.settings_outlined, size: 24),
                        onPressed: () => context.push('/settings'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    child: Text(
                      'Profile',
                      style: tt.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.75,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fan ? 'Fan account' : 'Creator account',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (roles.contains('fan')) ...[
                    const SizedBox(height: 24),
                    _Pair(
                      minHeight: 156,
                      children: [
                        _Workspace(
                          key: const ValueKey('workspace-fan'),
                          icon: Icons.explore_outlined,
                          title: 'Fan',
                          description: 'Browse, follow and collect',
                          selected: fan,
                          onTap: () => setRole(UserRole.fan),
                        ),
                        if (roles.contains('creator'))
                          _Workspace(
                            key: const ValueKey('workspace-creator'),
                            icon: Icons.videocam_outlined,
                            title: 'Creator',
                            description: 'Publish, go live and earn',
                            selected: !fan,
                            onTap: () => setRole(UserRole.creator),
                          )
                        else
                          _Workspace(
                            key: const ValueKey('workspace-creator'),
                            icon: Icons.videocam_outlined,
                            title: 'Become a creator',
                            description: 'Sell content and go live',
                            onTap: becomeCreator,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: motion(context, shortDuration),
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topCenter,
                      children: [...previous, ?current],
                    ),
                    child: fan
                        ? const _FanBody(key: ValueKey(UserRole.fan))
                        : const _CreatorBody(key: ValueKey(UserRole.creator)),
                  ),
                  const SizedBox(height: 32),
                  Pressable(
                    child: FilledButton.icon(
                      key: const ValueKey('profile-log-out'),
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.error,
                        foregroundColor: cs.onError,
                      ),
                      icon: const Icon(Icons.logout, size: 20),
                      label: const Text('Log out'),
                      onPressed: () async {
                        final confirmed = await showConfirmSheet(
                          context,
                          icon: Icons.logout,
                          title: 'Log out?',
                          message:
                              'You will need your email and password to '
                              'sign back in.',
                          confirmLabel: 'Log out',
                          destructive: true,
                        );
                        if (confirmed) {
                          await ref.read(authProvider.notifier).logout();
                        }
                      },
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

/// Counts strip, then My library and Settings.
class _FanBody extends ConsumerWidget {
  const _FanBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = [
      (
        ref.watch(subscriptionsProvider).whenData((l) => l.length),
        'Subscriptions',
        () => context.push('/library?tab=subscriptions'),
      ),
      (
        ref.watch(purchasesProvider).whenData((l) => l.length),
        'Purchases',
        () => context.push('/library'),
      ),
      (
        ref.watch(followingProvider).whenData((l) => l.length),
        'Following',
        () => context.go('/following'),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final rows = _largeText(context) || (box.maxWidth - 16) / 3 < 88;
            final cells = [
              for (final (value, label, onTap) in counts)
                _Count(value: value, label: label, row: rows, onTap: onTap),
            ];
            if (rows) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: cells,
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [for (final c in cells) Expanded(child: c)],
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        _Pair(
          minHeight: 156,
          children: [
            _QuietTile(
              icon: Icons.collections_bookmark_outlined,
              title: 'My library',
              subtitle: 'Purchases, receipts and subscriptions',
              onTap: () => context.push('/library'),
            ),
            const _SettingsTile(),
          ],
        ),
      ],
    );
  }
}

/// The Earnings summary is the earnings entry; Settings sits below it.
class _CreatorBody extends ConsumerWidget {
  const _CreatorBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final amount = ref
        .watch(earningsProvider)
        .whenData((e) => formatKes(e['availableCents'] as int));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Pressable(
          child: _Card(
            onTap: () => context.push('/earnings'),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Earnings', style: tt.titleMedium),
                      const SizedBox(height: 8),
                      _Value(
                        value: amount,
                        style: tt.headlineSmall,
                        skeletonWidth: 120,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const _SettingsTile(row: true),
      ],
    );
  }
}

/// Two equal-height cards side by side, stacked at large text sizes.
class _Pair extends StatelessWidget {
  const _Pair({required this.children, required this.minHeight});

  final List<Widget> children;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    if (_largeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: children,
      );
    }
    final sized = [
      for (final c in children)
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: c,
        ),
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [for (final c in sized) Expanded(child: c)],
      ),
    );
  }
}

/// Shared card: hairline border, 10% pressed ink, 2px primary focus ring.
/// [selected] non-null makes it one option of a radio group.
class _Card extends StatefulWidget {
  const _Card({
    required this.child,
    required this.onTap,
    this.padding = 16,
    this.color,
    this.selected,
  });

  final Widget child;
  final VoidCallback onTap;
  final double padding;
  final Color? color;
  final bool? selected;

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = widget.selected ?? false;
    final ink = cs.onSurface.withValues(alpha: 0.1);
    final ring = _focused || selected;
    return MergeSemantics(
      child: Semantics(
        button: true,
        inMutuallyExclusiveGroup: widget.selected != null,
        checked: widget.selected,
        child: Material(
          color: selected
              ? cs.secondaryContainer
              : widget.color ?? cs.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius),
            side: BorderSide(
              color: ring ? cs.primary : cs.outlineVariant,
              width: ring ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onFocusChange: (f) => setState(() => _focused = f),
            splashColor: ink,
            overlayColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.pressed)
                  ? ink
                  : s.contains(WidgetState.hovered)
                  ? cs.onSurface.withValues(alpha: 0.04)
                  : Colors.transparent,
            ),
            child: Padding(
              padding: EdgeInsets.all(widget.padding),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A Fan or Creator workspace option, or (without [selected]) the
/// Become a creator action.
class _Workspace extends StatelessWidget {
  const _Workspace({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.selected,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final selected = this.selected;
    final on = selected == true ? cs.onSecondaryContainer : cs.onSurface;
    final secondary = selected == true
        ? cs.onSecondaryContainer
        : cs.onSurfaceVariant;
    return Pressable(
      child: _Card(
        onTap: onTap,
        selected: selected,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 24, color: selected == null ? cs.primary : on),
                const Spacer(),
                Icon(
                  switch (selected) {
                    null => Icons.arrow_forward,
                    true => Icons.radio_button_checked,
                    false => Icons.radio_button_unchecked,
                  },
                  size: 24,
                  color: selected == true ? cs.primary : secondary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: tt.titleMedium?.copyWith(color: on)),
            const SizedBox(height: 6),
            Text(description, style: tt.bodySmall?.copyWith(color: secondary)),
          ],
        ),
      ),
    );
  }
}

/// One cell of the fan counts strip; [row] lays it out as a full-width row.
class _Count extends StatelessWidget {
  const _Count({
    required this.value,
    required this.label,
    required this.row,
    required this.onTap,
  });

  final AsyncValue<int> value;
  final String label;
  final bool row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final count = _Value(
      value: value.whenData((n) => '$n'),
      style: tt.headlineSmall?.copyWith(letterSpacing: -0.5),
      skeletonWidth: 32,
    );
    final name = Text(
      label,
      style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: row ? 0 : 96),
      child: _Card(
        onTap: onTap,
        padding: 12,
        child: row
            ? Row(
                spacing: 12,
                children: [
                  Expanded(child: name),
                  count,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [count, const SizedBox(height: 4), name],
              ),
      ),
    );
  }
}

/// A loaded figure, a skeleton the size of one while loading, "–" on error.
class _Value extends StatelessWidget {
  const _Value({
    required this.value,
    required this.style,
    required this.skeletonWidth,
  });

  final AsyncValue<String> value;
  final TextStyle? style;
  final double skeletonWidth;

  @override
  Widget build(BuildContext context) {
    final style = this.style?.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: _tabular,
    );
    return switch (value) {
      AsyncData(:final value) => Text(value, style: style),
      AsyncError() => Text('–', style: style),
      _ => Skeleton(
        width: skeletonWidth,
        height: MediaQuery.textScalerOf(
          context,
        ).scale((style?.fontSize ?? 24) * (style?.height ?? 1.2)),
      ),
    };
  }
}

class _QuietTile extends StatelessWidget {
  const _QuietTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.row = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// A full-width compact row instead of a tall tile.
  final bool row;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    if (row) {
      return Pressable(
        child: _Card(
          onTap: onTap,
          color: cs.surfaceContainer,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Row(
              spacing: 16,
              children: [
                Icon(icon, size: 24, color: cs.onSurface),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: tt.titleMedium),
                      Text(
                        subtitle,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      );
    }
    return Pressable(
      child: _Card(
        onTap: onTap,
        padding: 18,
        color: cs.surfaceContainer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: cs.onSurface),
            const SizedBox(height: 24),
            Text(title, style: tt.titleMedium),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({this.row = false});

  final bool row;

  @override
  Widget build(BuildContext context) => _QuietTile(
    row: row,
    icon: Icons.settings_outlined,
    title: 'Settings',
    subtitle: 'Privacy, lock and appearance',
    onTap: () => context.push('/settings'),
  );
}
