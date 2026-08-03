import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

/// Root widget of the stiko application.
class StikoApp extends StatelessWidget {
  const StikoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'stiko',
      debugShowCheckedModeBanner: false,
      theme: StikoTheme.light(),
      darkTheme: StikoTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
