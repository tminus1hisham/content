import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/prefs.dart';
import 'pin_pad.dart';

const decoyNotesKey = 'decoy.notes';

class _Note {
  _Note(this.id, this.text, this.updated);
  final String id;
  String text;
  DateTime updated;

  Map<String, Object> toJson() => {
    'id': id,
    'text': text,
    'updated': updated.millisecondsSinceEpoch,
  };
}

/// Working notes app: list, create, edit, delete; stored in prefs as JSON.
class DecoyNotes extends ConsumerStatefulWidget {
  const DecoyNotes({super.key});

  @override
  ConsumerState<DecoyNotes> createState() => _DecoyNotesState();
}

class _DecoyNotesState extends ConsumerState<DecoyNotes> {
  late final List<_Note> _notes = _load();

  List<_Note> _load() {
    final raw = ref.read(sharedPreferencesProvider).get(decoyNotesKey);
    if (raw is! String) return [];
    try {
      final decoded = jsonDecode(raw);
      return [
        if (decoded is List)
          for (final n in decoded)
            if (n case {
              'id': String id,
              'text': String text,
              'updated': int updated,
            })
              _Note(id, text, DateTime.fromMillisecondsSinceEpoch(updated)),
      ];
    } on FormatException {
      return [];
    }
  }

  Future<void> _save() => ref
      .read(sharedPreferencesProvider)
      .setString(decoyNotesKey, jsonEncode([for (final n in _notes) n]));

  Future<void> _edit(_Note? note) async {
    final theme = Theme.of(context);
    final text = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => Theme(
          data: theme,
          child: _NoteEditor(initial: note?.text ?? ''),
        ),
      ),
    );
    if (text == null || text == note?.text) return;
    setState(() {
      if (text.trim().isEmpty) {
        _notes.remove(note);
      } else if (note != null) {
        note
          ..text = text
          ..updated = DateTime.now();
      } else {
        final now = DateTime.now();
        _notes.add(_Note('${now.microsecondsSinceEpoch}', text, now));
      }
      _notes.sort((a, b) => b.updated.compareTo(a.updated));
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const DecoyTitle('Notes')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New note',
        onPressed: () => _edit(null),
        child: const Icon(Icons.add),
      ),
      body: _notes.isEmpty
          ? const Center(child: Text('No notes yet'))
          : ListView.builder(
              itemCount: _notes.length,
              itemBuilder: (context, i) {
                final note = _notes[i];
                final lines = note.text.trim().split('\n');
                return Dismissible(
                  key: ValueKey(note.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: const Icon(Icons.delete_outline),
                  ),
                  onDismissed: (_) {
                    setState(() => _notes.remove(note));
                    _save();
                  },
                  child: ListTile(
                    title: Text(
                      lines.first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        DateFormat.yMMMd().format(note.updated),
                        if (lines.length > 1) lines[1],
                      ].join('  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _edit(note),
                  ),
                );
              },
            ),
    );
  }
}

/// Pops with the edited text on back; with '' on delete.
class _NoteEditor extends StatefulWidget {
  const _NoteEditor({required this.initial});
  final String initial;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<String>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _controller.text);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Note'),
          actions: [
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => Navigator.pop(context, ''),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _controller,
            autofocus: widget.initial.isEmpty,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration.collapsed(hintText: 'Note'),
          ),
        ),
      ),
    );
  }
}
