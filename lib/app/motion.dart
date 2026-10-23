import 'package:flutter/widgets.dart';

/// Strong ease-out: entrances and press feedback.
const easeOut = Cubic(0.23, 1, 0.32, 1);

/// On-screen movement and morphs.
const easeInOut = Cubic(0.77, 0, 0.175, 1);

/// iOS-like sheet curve.
const easeDrawer = Cubic(0.32, 0.72, 0, 1);

const pressDuration = Duration(milliseconds: 140);
const shortDuration = Duration(milliseconds: 200);
const mediumDuration = Duration(milliseconds: 300);

/// [d], or zero when the user asked the OS to reduce motion.
Duration motion(BuildContext context, Duration d) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
