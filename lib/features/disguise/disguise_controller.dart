import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs.dart';
import 'icon_switcher.dart';
import 'pin_store.dart';

enum Disguise {
  none('Raha', Icons.apps),
  weather('Weather', Icons.cloud),
  notes('Notes', Icons.sticky_note_2),
  calendar('Calendar', Icons.calendar_month),
  calculator('Calculator', Icons.calculate);

  const Disguise(this.label, this.icon);
  final String label;
  final IconData icon;

  /// Name understood by the native `app/icon_switcher` channel.
  String get iconName => this == none ? 'default' : name;
}

const disguiseKey = 'disguise.kind';

class DisguiseController extends Notifier<Disguise> {
  @override
  Disguise build() =>
      Disguise.values.asNameMap()[ref
          .watch(sharedPreferencesProvider)
          .get(disguiseKey)] ??
      Disguise.none;

  /// Throws [StateError] when enabling a disguise without a PIN: the PIN is
  /// the only way back into the real app.
  Future<void> set(Disguise disguise) async {
    if (disguise != Disguise.none &&
        !await ref.read(pinStoreProvider).hasPin()) {
      throw StateError('Set a PIN before enabling a disguise');
    }
    state = disguise;
    await ref
        .read(sharedPreferencesProvider)
        .setString(disguiseKey, disguise.name);
    await ref.read(iconSwitcherProvider).setIcon(disguise.iconName);
  }
}

final disguiseProvider = NotifierProvider<DisguiseController, Disguise>(
  DisguiseController.new,
);
