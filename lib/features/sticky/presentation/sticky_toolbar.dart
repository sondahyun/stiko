import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../application/sticky_window.dart';

/// Draggable toolbar at the top of the desktop sticky window.
///
/// Drag it to move the window, double-tap to collapse, and use the buttons to
/// pin (always on top), collapse / expand, or close.
class StickyToolbar extends ConsumerWidget {
  const StickyToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StickyWindowState windowState =
        ref.watch(stickyWindowControllerProvider);
    final StickyWindowController controller =
        ref.read(stickyWindowControllerProvider.notifier);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    // Leave room for the macOS traffic-light buttons on the left.
    final double leftInset =
        defaultTargetPlatform == TargetPlatform.macOS ? 72 : 12;

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
              tooltip: windowState.alwaysOnTop ? '항상 위 해제' : '항상 위 고정',
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              isSelected: windowState.alwaysOnTop,
              icon: const Icon(Icons.push_pin_outlined),
              selectedIcon: const Icon(Icons.push_pin),
              onPressed: controller.toggleAlwaysOnTop,
            ),
            IconButton(
              tooltip: windowState.collapsed ? '펴기' : '접기',
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                windowState.collapsed ? Icons.unfold_more : Icons.unfold_less,
              ),
              onPressed: controller.toggleCollapsed,
            ),
            IconButton(
              tooltip: '닫기',
              iconSize: 18,
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
