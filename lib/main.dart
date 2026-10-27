import 'package:flutter/widgets.dart';

import 'app/bootstrap.dart';
import 'features/player/data/ios_video_cache.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IosVideoCache.initialize();
  await bootstrap();
}
