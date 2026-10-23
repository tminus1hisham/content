import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../app/theme_controller.dart';
import '../../app/ui.dart';
import '../../core/money.dart';
import 'settings_screen.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeControllerProvider);
    final controller = ref.read(themeControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SettingsHeader('Theme'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => controller.setThemeMode(s.first),
            ),
          ),
          const SettingsHeader('Accent colour'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 12,
              children: [
                for (final (i, accent) in accents.indexed)
                  _Swatch(
                    accent: accent,
                    selected: i == settings.accentIndex,
                    onTap: () => controller.setAccent(i),
                  ),
              ],
            ),
          ),
          const SettingsHeader('Preview'),
          const _Preview(),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.accent,
    required this.selected,
    required this.onTap,
  });
  final AccentOption accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onAccent =
        ThemeData.estimateBrightnessForColor(accent.color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final duration = motion(context, shortDuration);
    return Semantics(
      label: accent.name,
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: Pressable(
        child: InkResponse(
          onTap: onTap,
          customBorder: const CircleBorder(),
          // Ring, a gap, then the accent's own gradient.
          child: AnimatedContainer(
            duration: duration,
            curve: easeOut,
            width: 52,
            height: 52,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? scheme.onSurface : scheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: Brand.forAccent(accent.color).gradient,
              ),
              child: AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: duration,
                curve: easeOut,
                child: Icon(Icons.check, color: onAccent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CreatorAvatar(id: 'preview', name: 'Creator name'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Creator name',
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Exclusive photo set',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        style: brandButtonStyle(context),
                        onPressed: () {},
                        child: Text('Unlock ${formatKes(25000)}'),
                      ),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('Tip'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
