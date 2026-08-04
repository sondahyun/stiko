import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'features/sticky/window_bootstrap.dart';
import 'features/sticky_window/sticky_window_screen.dart';
import 'firebase_options.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // A sticky opened in its own floating window (desktop multi-window).
  if (args.isNotEmpty && args.first == 'multi_window') {
    await windowManager.ensureInitialized();
    final WindowController window = await WindowController.fromCurrentEngine();
    final Map<String, dynamic> arg =
        jsonDecode(window.arguments) as Map<String, dynamic>;
    final Size size = Size(
      (arg['width'] as num).toDouble(),
      (arg['height'] as num).toDouble(),
    );
    final Offset position = Offset(
      (arg['left'] as num).toDouble(),
      (arg['top'] as num).toDouble(),
    );

    await window.setWindowMethodHandler((MethodCall call) async {
      if (call.method == 'window_focus') {
        await windowManager.show();
        await windowManager.focus();
        return;
      }
      throw MissingPluginException('Unknown window method: ${call.method}');
    });

    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: size,
        minimumSize: const Size(260, 120),
        backgroundColor: const Color(0x00000000),
        title: 'stiko',
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
      ),
      () async {
        await windowManager.setPosition(position);
        await windowManager.show();
        await windowManager.focus();
      },
    );
    runApp(
      StickyWindowRoot(
        stickyId: arg['stickyId'] as String,
        uid: arg['uid'] as String,
      ),
    );
    return;
  }

  await initStickyWindow();
  runApp(const ProviderScope(child: StikoApp()));
}
