import 'package:flutter/widgets.dart';

import 'dart:async';

import 'app/bootstrap.dart';
import 'features/player/data/ios_video_cache.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(IosVideoCache.initialize());
  await bootstrap();
}
