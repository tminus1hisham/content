import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'theme.dart';

/// Opens the "Schedule post" bottom sheet and returns the chosen local
/// [DateTime], or null if dismissed. [now] exists for tests.
Future<DateTime?> showSchedulePicker(
  BuildContext context, {
  DateTime? initial,
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _SchedulePickerSheet(now: reference, initial: initial),
  );
}

const _presetHours = [9, 12, 15, 18, 20, 22];
const _stripDays = 14;

class _SchedulePickerSheet extends StatefulWidget {
  const _SchedulePickerSheet({required this.now, this.initial});

  final DateTime now;
  final DateTime? initial;

  @override
  State<_SchedulePickerSheet> createState() => _SchedulePickerSheetState();
}

class _SchedulePickerSheetState extends State<_SchedulePickerSheet> {
  late final DateTime _today = DateUtils.dateOnly(widget.now);
  DateTime? _day;
  TimeOfDay? _time;
  bool _custom = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _day = DateUtils.dateOnly(initial);
      _time = TimeOfDay.fromDateTime(initial);
      _custom = !_presetHours.contains(initial.hour) || initial.minute != 0;
    }
  }

  DateTime _at(DateTime day, TimeOfDay time) =>
      DateTime(day.year, day.month, day.day, time.hour, time.minute);

  DateTime? get _selected =>
      _day == null || _time == null ? null : _at(_day!, _time!);

  bool _isPast(DateTime day, TimeOfDay time) =>
      !_at(day, time).isAfter(widget.now);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day != null && !_day!.isBefore(_today) ? _day! : _today,
      firstDate: _today,
      lastDate: widget.now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _day = DateUtils.dateOnly(picked));
  }

  Future<void> _pickCustomTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _custom && _time != null
          ? _time!
          : TimeOfDay.fromDateTime(widget.now.add(const Duration(hours: 1))),
    );
    if (picked != null) {
      setState(() {
        _time = picked;
        _custom = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    final selected = _selected;
    final canConfirm = selected != null && selected.isAfter(widget.now);
    final dayOnStrip =
        _day != null && _day!.difference(_today).inDays < _stripDays;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schedule post',
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Text(
            DateFormat.yMMMM().format(_day ?? _today),
            style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: scaler.scale(72).clamp(72, 220).toDouble(),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < _stripDays; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _DayPill(
                      key: Key('schedule-day-$i'),
                      date: DateUtils.addDaysToDate(_today, i),
                      isToday: i == 0,
                      selected: _day == DateUtils.addDaysToDate(_today, i),
                      onTap: () => setState(
                        () => _day = DateUtils.addDaysToDate(_today, i),
                      ),
                    ),
                  ),
                Center(
                  child: ActionChip(
                    key: const Key('schedule-more'),
                    avatar: const Icon(Icons.calendar_month, size: 18),
                    label: const Text('Pick a date'),
                    onPressed: _pickDate,
                  ),
                ),
              ],
            ),
          ),
          if (_day != null && !dayOnStrip) ...[
            const SizedBox(height: 8),
            Text(
              DateFormat('EEE, d MMM yyyy').format(_day!),
              style: text.bodyMedium?.copyWith(color: scheme.primary),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Time',
            style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final hour in _presetHours)
                _slot(context, TimeOfDay(hour: hour, minute: 0)),
              ChoiceChip(
                key: const Key('schedule-custom'),
                avatar: const Icon(Icons.schedule, size: 18),
                label: Text(
                  _custom && _time != null ? _time!.format(context) : 'Custom',
                ),
                selected: _custom && _time != null,
                onSelected: (_) => _pickCustomTime(),
              ),
            ],
          ),
          if (selected != null && !canConfirm) ...[
            const SizedBox(height: 20),
            Text(
              'That time has passed. Pick a later one.',
              style: text.bodyMedium?.copyWith(color: scheme.error),
            ),
          ] else if (selected != null) ...[
            const SizedBox(height: 20),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: const BorderRadius.all(
                  Radius.circular(controlRadius),
                ),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_available, color: scheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Goes live ${DateFormat('EEE, d MMM').format(selected)} · '
                        '${_time!.format(context)}',
                        style: text.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('schedule-confirm'),
              onPressed: canConfirm
                  ? () => Navigator.of(context).pop(selected)
                  : null,
              child: const Text('Schedule'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slot(BuildContext context, TimeOfDay slot) {
    final past = _day != null && _isPast(_day!, slot);
    return ChoiceChip(
      label: Text(slot.format(context)),
      selected: !_custom && _time == slot,
      onSelected: past
          ? null
          : (_) => setState(() {
              _time = slot;
              _custom = false;
            }),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    super.key,
    required this.date,
    required this.isToday,
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
  final bool isToday;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    final muted = selected ? scheme.onPrimary : scheme.onSurfaceVariant;
    final weekday = isToday ? 'Today' : DateFormat.E().format(date);
    return Semantics(
      button: true,
      selected: selected,
      label: DateFormat('EEEE, d MMMM').format(date),
      excludeSemantics: true,
      child: Material(
        color: selected ? scheme.primary : scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(controlRadius)),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(controlRadius)),
          ),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 56, minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekday,
                    style: theme.textTheme.labelMedium?.copyWith(color: muted),
                  ),
                  Text(
                    '${date.day}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
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
