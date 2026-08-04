import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../../../app/router.dart';
import '../application/sticky_window.dart';

/// Draggable toolbar at the top of the desktop sticky window.
///
/// Drag it to move the window, double-tap to collapse, and use the buttons to
/// open settings, pin (always on top), collapse / expand, or close.
class StickyToolbar extends ConsumerWidget {
  const StickyToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StickyWindowState windowState = ref.watch(
      stickyWindowControllerProvider,
    );
    final StickyWindowController controller = ref.read(
      stickyWindowControllerProvider.notifier,
    );
    final ColorScheme scheme = Theme.of(context).colorScheme;

    // Leave room for the macOS traffic-light buttons on the left.
    final double leftInset = defaultTargetPlatform == TargetPlatform.macOS
        ? 88
        : 12;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: controller.toggleCollapsed,
      child: Container(
        height: 44,
        color: scheme.surfaceContainerHighest,
        padding: EdgeInsets.only(left: leftInset, right: 4),
        child: Row(
          children: <Widget>[
            Text(
              'stiko',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: '휴지통',
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => context.push(StikoRoutes.trash),
            ),
            IconButton(
              tooltip: '설정',
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push(StikoRoutes.settings),
            ),
            IconButton(
              tooltip: windowState.alwaysOnTop ? '항상 위 해제' : '항상 위 고정',
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              visualDensity: VisualDensity.compact,
              icon: Icon(
                windowState.alwaysOnTop
                    ? Icons.push_pin
                    : Icons.push_pin_outlined,
                color: windowState.alwaysOnTop ? const Color(0xFF6E5E17) : null,
              ),
              onPressed: controller.toggleAlwaysOnTop,
            ),
            IconButton(
              tooltip: windowState.collapsed ? '펴기' : '접기',
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              visualDensity: VisualDensity.compact,
              icon: Icon(
                windowState.collapsed ? Icons.unfold_more : Icons.unfold_less,
              ),
              onPressed: controller.toggleCollapsed,
            ),
            IconButton(
              tooltip: '닫기',
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close),
              onPressed: () => windowManager.close(),
            ),
          ],
        ),
      ),
    );
  }
}
