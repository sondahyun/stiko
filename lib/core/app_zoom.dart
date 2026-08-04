import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keyboard-driven whole-interface zoom for desktop windows.
///
/// Unlike text scaling, this scales every rendered element and adjusts the
/// logical viewport so layout and pointer hit testing continue to work.
class AppZoom extends StatefulWidget {
  const AppZoom({super.key, required this.child});

  final Widget child;

  static const double minScale = 0.7;
  static const double maxScale = 1.4;
  static const double step = 0.1;

  @override
  State<AppZoom> createState() => _AppZoomState();
}

class _AppZoomState extends State<AppZoom> {
  double _scale = 1;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  void _setScale(double value) {
    final double next = value
        .clamp(AppZoom.minScale, AppZoom.maxScale)
        .toDouble();
    if (next == _scale) return;
    setState(() => _scale = next);
  }

  void _zoomIn() => _setScale(_scale + AppZoom.step);
  void _zoomOut() => _setScale(_scale - AppZoom.step);
  void _reset() => _setScale(1);

  bool _handleKeyEvent(KeyEvent event) {
    if ((event is! KeyDownEvent && event is! KeyRepeatEvent) ||
        !HardwareKeyboard.instance.isControlPressed) {
      return false;
    }

    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.add ||
        key == LogicalKeyboardKey.numpadAdd) {
      _zoomIn();
      return true;
    }
    if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract) {
      _zoomOut();
      return true;
    }
    if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
      _reset();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return widget.child;
        }

        final Size logicalSize = Size(
          constraints.maxWidth / _scale,
          constraints.maxHeight / _scale,
        );
        return ClipRect(
          child: Transform.scale(
            key: const Key('app-zoom-transform'),
            scale: _scale,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: logicalSize.width,
              height: logicalSize.height,
              child: MediaQuery(
                data: mediaQuery.copyWith(size: logicalSize),
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}
