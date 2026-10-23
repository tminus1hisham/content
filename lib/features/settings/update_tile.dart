import 'package:flutter/material.dart';
import 'package:flutter_ota_update/flutter_ota_update.dart';

import 'settings_screen.dart';

/// "Check for updates" row: looks for a newer APK on the repo's latest
/// GitHub release and opens the Android installer. Android only.
class UpdateTile extends StatefulWidget {
  const UpdateTile({super.key});

  @override
  State<UpdateTile> createState() => _UpdateTileState();
}

class _UpdateTileState extends State<UpdateTile> {
  final _ota = FlutterOtaUpdate(owner: 'tminus1hisham', repo: 'content');

  bool _busy = false;
  String? _status;

  void _say(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _status = 'Checking…';
    });
    try {
      final release = await _ota.checkForUpdate();
      if (!mounted) return;
      if (release == null) {
        _say("You're on the latest version.");
      } else if (await _confirm(release) == true) {
        await _install(release);
      }
    } on Exception {
      if (mounted) _say("Couldn't check for updates. Try again later.");
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  Future<bool?> _confirm(OtaRelease release) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Version ${release.version} is ready'),
      content: release.notes.isEmpty
          ? null
          : SingleChildScrollView(child: Text(release.notes)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Update'),
        ),
      ],
    ),
  );

  Future<void> _install(OtaRelease release) async {
    try {
      await _ota.downloadAndInstall(
        release,
        onProgress: (received, total) {
          if (!mounted || total <= 0) return;
          setState(() => _status = 'Downloading… ${received * 100 ~/ total}%');
        },
      );
    } on OtaException {
      if (mounted) _say("The update couldn't be installed. Try again later.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      icon: Icons.system_update_outlined,
      title: 'Check for updates',
      subtitle: _status,
      chevron: false,
      onTap: _busy ? () {} : _check,
    );
  }
}
