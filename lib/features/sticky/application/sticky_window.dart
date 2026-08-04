import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/platform_utils.dart';

/// Persists sticky-window preferences that should survive app restarts.
class WindowSettingsStore {
  const WindowSettingsStore._();

  static const String _kAlwaysOnTop = 'window.alwaysOnTop';

  static Future<bool> loadAlwaysOnTop() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAlwaysOnTop) ?? false;
  }

  static Future<void> saveAlwaysOnTop(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAlwaysOnTop, value);
  }
}

/// Persists the last closed position of each standalone sticky window.
class StickyWindowPositionStore {
  const StickyWindowPositionStore._();

  static String _key(String stickyId) =>
      'window.stickyPosition.${Uri.encodeComponent(stickyId)}';

  static Future<Offset?> load(String stickyId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // Sticky windows run in separate Flutter engines, each with its own cache.
    await prefs.reload();
    final String? value = prefs.getString(_key(stickyId));
    if (value == null) return null;

    try {
      final Object? decoded = jsonDecode(value);
      if (decoded is! List<dynamic> || decoded.length != 2) return null;
      final Object? left = decoded[0];
      final Object? top = decoded[1];
      if (left is! num || top is! num) return null;
      final Offset position = Offset(left.toDouble(), top.toDouble());
      return position.dx.isFinite && position.dy.isFinite ? position : null;
    } on FormatException {
      return null;
    }
  }

  static Future<void> save(String stickyId, Offset position) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(stickyId),
      jsonEncode(<double>[position.dx, position.dy]),
    );
  }
}

/// Runtime state of the desktop sticky window.
class StickyWindowState {
  const StickyWindowState({this.alwaysOnTop = false, this.collapsed = false});

  final bool alwaysOnTop;
  final bool collapsed;

  StickyWindowState copyWith({bool? alwaysOnTop, bool? collapsed}) {
    return StickyWindowState(
      alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
      collapsed: collapsed ?? this.collapsed,
    );
  }
}

/// Controls the desktop sticky window: always-on-top and collapse / expand.
///
/// Every window_manager call is guarded by [isDesktop] so the controller is a
/// harmless no-op on mobile.
class StickyWindowController extends Notifier<StickyWindowState> {
  static const double _collapsedHeight = 44;
  double _expandedHeight = 460;

  @override
  StickyWindowState build() {
    _restore();
    return const StickyWindowState();
  }

  Future<void> _restore() async {
    if (!isDesktop) return;
    final bool onTop = await WindowSettingsStore.loadAlwaysOnTop();
    if (onTop != state.alwaysOnTop) {
      state = state.copyWith(alwaysOnTop: onTop);
    }
  }

  /// Toggles whether the window floats above all other windows.
  Future<void> toggleAlwaysOnTop() async {
    final bool next = !state.alwaysOnTop;
    state = state.copyWith(alwaysOnTop: next);
    if (!isDesktop) return;
    await windowManager.setAlwaysOnTop(next);
    await WindowSettingsStore.saveAlwaysOnTop(next);
  }

  /// Rolls the window up to just its toolbar, or restores it.
  Future<void> toggleCollapsed() async {
    final bool next = !state.collapsed;
    if (isDesktop) {
      final Size size = await windowManager.getSize();
      if (next) {
        _expandedHeight = size.height;
        await windowManager.setSize(Size(size.width, _collapsedHeight));
      } else {
        await windowManager.setSize(Size(size.width, _expandedHeight));
      }
    }
    state = state.copyWith(collapsed: next);
  }
}

final stickyWindowControllerProvider =
    NotifierProvider<StickyWindowController, StickyWindowState>(
  StickyWindowController.new,
);
