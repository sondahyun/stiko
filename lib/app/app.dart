import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../core/app_zoom.dart';
import 'application/theme_controller.dart';
import 'router.dart';
import 'theme.dart';

/// Root widget of the stiko application.
class StikoApp extends ConsumerStatefulWidget {
  const StikoApp({super.key});

  @override
  ConsumerState<StikoApp> createState() => _StikoAppState();
}

class _StikoAppState extends ConsumerState<StikoApp> {
  StreamSubscription<Uri?>? _widgetClick;

  @override
  void initState() {
    super.initState();
    // Open the tapped sticker when the app is launched or resumed from a
    // widget. The widget's URL is stiko://sticker/<id> (or stiko://board).
    _widgetClick = HomeWidget.widgetClicked.listen(_openFromWidget);
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_openFromWidget);
  }

  @override
  void dispose() {
    _widgetClick?.cancel();
    super.dispose();
  }

  void _openFromWidget(Uri? uri) {
    if (uri == null || uri.host != 'sticker' || uri.pathSegments.isEmpty) return;
    final String id = uri.pathSegments.first;
    // Defer until the router is mounted (and past any auth redirect).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appRouterProvider).push(StikoRoutes.stickyPath(id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'stiko',
      debugShowCheckedModeBanner: false,
      theme: StikoTheme.light(),
      darkTheme: StikoTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (BuildContext context, Widget? child) =>
          AppZoom(child: child ?? const SizedBox.shrink()),
    );
  }
}
