import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
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
    final int windowId = int.parse(args[1]);
    final Map<String, dynamic> arg =
        jsonDecode(args[2]) as Map<String, dynamic>;
    runApp(
      StickyWindowRoot(
        windowId: windowId,
        stickyId: arg['stickyId'] as String,
        uid: arg['uid'] as String,
      ),
    );
    return;
  }

  await initStickyWindow();
  runApp(const ProviderScope(child: StikoApp()));
}
