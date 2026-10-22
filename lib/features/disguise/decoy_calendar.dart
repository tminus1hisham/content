import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/prefs.dart';
import 'pin_pad.dart';

const decoyEventsKey = 'decoy.events';

/// Working month calendar; tap a day to view or add events (stored in prefs
/// as JSON: `{"2026-10-22": ["Dentist 3pm"]}`).
class DecoyCalendar extends ConsumerStatefulWidget {
  const DecoyCalendar({super.key});

  @override
  ConsumerState<DecoyCalendar> createState() => _DecoyCalendarState();
}

class _DecoyCalendarState extends ConsumerState<DecoyCalendar> {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static final _dayKey = DateFormat('yyyy-MM-dd');

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late final Map<String, List<String>> _events = _load();

  Map<String, List<String>> _load() {
    final raw = ref.read(sharedPreferencesProvider).get(decoyEventsKey);
    if (raw is! String) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final MapEntry(:key, :value) in decoded.entries)
          if (key is String && value is List)
            key: [...value.whereType<String>()],
      };
    } on FormatException {
      return {};
    }
  }

  Future<void> _save() => ref
      .read(sharedPreferencesProvider)
      .setString(decoyEventsKey, jsonEncode(_events));

  Future<void> _openDay(DateTime day) async {
    final key = _dayKey.format(day);
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          final events = _events[key] ?? [];
          void add() {
            final text = controller.text.trim();
            if (text.isEmpty) return;
            controller.clear();
            setSheet(() => (_events[key] ??= []).add(text));
            setState(() {});
            _save();
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat.yMMMMEEEEd().format(day),
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                if (events.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No events'),
                  ),
                for (final (i, event) in events.indexed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text(event),
                    trailing: IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        setSheet(() {
                          events.removeAt(i);
                          if (events.isEmpty) _events.remove(key);
                        });
                        setState(() {});
                        _save();
                      },
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: 'New event',
                        ),
                        onSubmitted: (_) => add(),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Add',
                      icon: const Icon(Icons.add),
                      onPressed: add,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = _month.weekday - 1;
    return Scaffold(
      appBar: AppBar(title: const DecoyTitle('Calendar')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
              ),
              Expanded(
                child: Text(
                  DateFormat.yMMMM().format(_month),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1),
                ),
              ),
            ],
          ),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final d in _weekdays)
                Center(
                  child: Text(d, style: Theme.of(context).textTheme.labelSmall),
                ),
              for (var i = 0; i < leading; i++) const SizedBox(),
              for (var day = 1; day <= daysInMonth; day++)
                _dayCell(DateTime(_month.year, _month.month, day), now, scheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayCell(DateTime date, DateTime now, ColorScheme scheme) {
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final hasEvents = _events.containsKey(_dayKey.format(date));
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => _openDay(date),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isToday ? scheme.primaryContainer : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${date.day}'),
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasEvents ? scheme.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
