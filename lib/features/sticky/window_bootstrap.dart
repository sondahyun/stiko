import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/platform_utils.dart';
import 'application/sticky_window.dart';

/// Configures the desktop window to look and behave like a sticky note:
/// small, frameless, and floating if the user pinned it last time.
///
/// No-op on mobile platforms.
Future<void> initStickyWindow() async {
  if (!isDesktop) return;

  await windowManager.ensureInitialized();
  final bool alwaysOnTop = await WindowSettingsStore.loadAlwaysOnTop();

  const WindowOptions options = WindowOptions(
    size: Size(320, 460),
    minimumSize: Size(260, 120),
    center: false,
    backgroundColor: Color(0x00000000),
    titleBarStyle: TitleBarStyle.hidden,
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    if (alwaysOnTop) {
      await windowManager.setAlwaysOnTop(true);
    }
    await windowManager.show();
    await windowManager.focus();
  });
}
