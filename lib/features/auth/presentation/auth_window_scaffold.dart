import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/platform_utils.dart';

/// Gives frameless desktop auth screens a draggable title bar while leaving
/// mobile auth screens unchanged.
class AuthWindowScaffold extends StatelessWidget {
  const AuthWindowScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          if (isDesktop) const _AuthWindowToolbar(),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _AuthWindowToolbar extends StatelessWidget {
  const _AuthWindowToolbar();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isMacOS = defaultTargetPlatform == TargetPlatform.macOS;

    return GestureDetector(
      key: const Key('auth-window-drag-region'),
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 44,
        color: scheme.surfaceContainerHighest,
        padding: EdgeInsets.only(left: isMacOS ? 88 : 12, right: 4),
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
            if (!isMacOS)
              IconButton(
                tooltip: '닫기',
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close),
                onPressed: windowManager.close,
              ),
          ],
        ),
      ),
    );
  }
}
