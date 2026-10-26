import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Ambient (looping or scheduled) decoration is disabled while widget tests run:
/// a permanent ticker makes `pumpAndSettle` unreliable and nothing is on screen.
/// Screenshots on a real device keep the effect.
bool get ambientMotionEnabled {
  if (kIsWeb) return true;
  return Platform.environment['FLUTTER_TEST'] != 'true';
}
