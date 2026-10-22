import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'web_icon_stub.dart' if (dart.library.js_interop) 'web_icon_web.dart';

/// Swaps the launcher icon (Android activity-alias / iOS alternate icon) or,
/// on web, the favicon and tab title. [name] is `default` or a disguise name.
class IconSwitcher {
  static const channel = MethodChannel('app/icon_switcher');

  Future<void> setIcon(String name) async {
    if (kIsWeb) return setWebIcon(name);
    try {
      await channel.invokeMethod<void>('setIcon', name);
    } on MissingPluginException {
      // Desktop and widget tests have no native handler.
    }
  }
}

final iconSwitcherProvider = Provider<IconSwitcher>((ref) => IconSwitcher());
