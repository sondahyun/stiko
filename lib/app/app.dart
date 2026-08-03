import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/theme_controller.dart';
import 'router.dart';
import 'theme.dart';

/// Root widget of the stiko application.
class StikoApp extends ConsumerWidget {
  const StikoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'stiko',
      debugShowCheckedModeBanner: false,
      theme: StikoTheme.light(),
      darkTheme: StikoTheme.dark(),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
