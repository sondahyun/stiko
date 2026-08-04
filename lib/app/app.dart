import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  /// Widget taps arrive here from the native iOS SceneDelegate as stiko:// URLs.
  static const MethodChannel _deeplink = MethodChannel('stiko/deeplink');

  @override
  void initState() {
    super.initState();
    // iOS (SceneDelegate) and Android (MainActivity) both wire up this channel;
    // other platforms have no native side, so skip it to avoid a plugin error.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android)) {
      _deeplink.setMethodCallHandler((MethodCall call) async {
        if (call.method == 'open') _openFromUrl(call.arguments as String?);
        return null;
      });
      // Cold start: the app was launched by tapping a widget.
      _deeplink.invokeMethod<String>('getInitial').then(_openFromUrl);
    }
  }

  void _openFromUrl(String? url) {
    if (url == null) return;
    final Uri? uri = Uri.tryParse(url);
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
