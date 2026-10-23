import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../features/auth/auth_controller.dart' show isAdult;
import 'motion.dart';
import 'theme.dart';
import 'ui.dart';

/// Wheel bottom sheet for the 18+ gate. Returns the chosen date, or null when
/// dismissed. The wheel starts at today and Continue stays disabled until the
/// wheel has been moved, so a passing date is never pre-selected.
Future<DateTime?> showBirthDatePicker(BuildContext context, {DateTime? now}) {
  final today = now ?? DateTime.now();
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _BirthDateSheet(now: today),
  );
}

int _wholeYears(DateTime birthDate, DateTime now) {
  var age = now.year - birthDate.year;
  if (now.month < birthDate.month ||
      (now.month == birthDate.month && now.day < birthDate.day)) {
    age--;
  }
  return age;
}

class _BirthDateSheet extends StatefulWidget {
  const _BirthDateSheet({required this.now});
  final DateTime now;

  @override
  State<_BirthDateSheet> createState() => _BirthDateSheetState();
}

class _BirthDateSheetState extends State<_BirthDateSheet> {
  late DateTime _today;
  late DateTime _chosen;
  bool _moved = false;

  @override
  void initState() {
    super.initState();
    _today = DateTime(widget.now.year, widget.now.month, widget.now.day);
    _chosen = _today;
  }

  Future<void> _typeInstead() async {
    final now = widget.now;
    final picked = await showDatePicker(
      context: context,
      initialEntryMode: DatePickerEntryMode.input,
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked != null && mounted) Navigator.of(context).pop(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final adult = isAdult(_chosen, widget.now);
    const tabular = [FontFeature.tabularFigures()];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Date of birth',
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                DateFormat('d MMMM y').format(_chosen),
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: tabular,
                ),
              ),
              if (_moved)
                AnimatedContainer(
                  duration: motion(context, shortDuration),
                  curve: easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: adult
                        ? scheme.primaryContainer
                        : scheme.errorContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_wholeYears(_chosen, widget.now)} years',
                    style: text.labelLarge?.copyWith(
                      color: adult
                          ? scheme.onPrimaryContainer
                          : scheme.onErrorContainer,
                      fontFeatures: tabular,
                    ),
                  ),
                )
              else
                Text(
                  'Scroll to your birthday',
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 216,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: theme.brightness,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                    fontFeatures: tabular,
                  ),
                ),
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                dateOrder: DatePickerDateOrder.dmy,
                initialDateTime: _today,
                maximumDate: _today,
                minimumYear: widget.now.year - 120,
                maximumYear: widget.now.year,
                selectionOverlayBuilder:
                    (context, {required columnCount, required selectedIndex}) =>
                        // One lit band across all columns, not three pills.
                        Container(
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.horizontal(
                              left: selectedIndex == 0
                                  ? const Radius.circular(controlRadius)
                                  : Radius.zero,
                              right: selectedIndex == columnCount - 1
                                  ? const Radius.circular(controlRadius)
                                  : Radius.zero,
                            ),
                            border: Border.symmetric(
                              horizontal: BorderSide(
                                color: scheme.outlineVariant,
                              ),
                            ),
                          ),
                        ),
                onDateTimeChanged: (value) => setState(() {
                  _chosen = DateTime(value.year, value.month, value.day);
                  _moved = true;
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Pressable(
            child: FilledButton(
              key: const ValueKey('dob-continue'),
              style: brandButtonStyle(context),
              onPressed: _moved
                  ? () => Navigator.of(context).pop(_chosen)
                  : null,
              child: const Text('Continue'),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            key: const ValueKey('dob-type'),
            onPressed: _typeInstead,
            child: const Text('Type it instead'),
          ),
        ],
      ),
    );
  }
}
