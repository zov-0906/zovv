import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/theme_controller.dart';
import '../features/startup/data/startup_history.dart';
import 'zovv_app.dart';

Future<void> bootstrap() async {
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Color(0xFFF7F8FB),
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  final history = LocalStartupHistory();
  final hasCompletedStartup = await history.hasCompleted();
  final theme = ThemeController(preference: LocalThemePreference());
  await theme.load();
  runApp(
    ZovvApp(
      history: history,
      hasCompletedStartup: hasCompletedStartup,
      themeController: theme,
    ),
  );
}
