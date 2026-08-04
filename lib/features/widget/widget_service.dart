import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../data/local/database.dart';
import '../../data/sticky_repository.dart';

/// Bridges the board to the iOS / Android home and lock screen widgets, sharing
/// data through an App Group. Also reconciles the checkboxes the user tapped in
/// the widget back into the repository.
class WidgetService {
  const WidgetService._();

  /// Must match the App Group on the iOS Runner and widget targets.
  static const String appGroupId = 'group.io.github.sondahyun.stiko';

  /// Must match the SwiftUI widget's `kind` and the Android provider class.
  static const String iOSWidgetName = 'StikoWidget';
  static const String androidWidgetName = 'StikoWidgetProvider';

  static bool get _supported =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  /// Pushes the current board to the widget and applies any checkbox taps made
  /// from the widget. [repo] persists those toggles. When [stickerIds] is not
  /// empty, only those stickers' todos are shown.
  static Future<void> sync(
    List<StickyWithTodos> board,
    StickyRepository repo, {
    Set<String> stickerIds = const <String>{},
  }) async {
    if (!_supported) return;
    try {
      await HomeWidget.setAppGroupId(appGroupId);

      // 1) Apply the checkbox taps the user made in the widget.
      final Map<String, bool> pending = await _drainPending();
      for (final MapEntry<String, bool> e in pending.entries) {
        await repo.toggleTodo(e.key, e.value);
      }

      // 2) Publish todos: open ones first, then completed ones (kept visible
      //    with a strikethrough), applying any not-yet-persisted taps.
      final List<Map<String, dynamic>> open = <Map<String, dynamic>>[];
      final List<Map<String, dynamic>> completed = <Map<String, dynamic>>[];
      for (final StickyWithTodos s in board) {
        if (stickerIds.isNotEmpty && !stickerIds.contains(s.sticky.id)) {
          continue;
        }
        for (final Todo t in s.todos) {
          final bool done = pending[t.id] ?? t.isDone;
          final Map<String, dynamic> entry = <String, dynamic>{
            'id': t.id,
            'content': t.content,
            'done': done,
            'stickyId': s.sticky.id,
          };
          (done ? completed : open).add(entry);
        }
      }
      final List<Map<String, dynamic>> all = <Map<String, dynamic>>[
        ...open,
        ...completed,
      ];

      // 3) Publish the full per-sticker breakdown so each iOS widget instance
      //    can be configured to show a different sticker (home vs lock, etc.).
      //    This list is NOT filtered by [stickerIds]; the widget picks its own.
      final List<Map<String, dynamic>> stickers = <Map<String, dynamic>>[];
      for (final StickyWithTodos s in board) {
        final List<Map<String, dynamic>> open = <Map<String, dynamic>>[];
        final List<Map<String, dynamic>> done = <Map<String, dynamic>>[];
        for (final Todo t in s.todos) {
          final bool isDone = pending[t.id] ?? t.isDone;
          final Map<String, dynamic> entry = <String, dynamic>{
            'id': t.id,
            'content': t.content,
            'done': isDone,
          };
          (isDone ? done : open).add(entry);
        }
        stickers.add(<String, dynamic>{
          'id': s.sticky.id,
          'name': _stickerName(s),
          'todos': <Map<String, dynamic>>[...open, ...done],
        });
      }

      await HomeWidget.saveWidgetData<String>('todos', jsonEncode(all));
      await HomeWidget.saveWidgetData<String>('stickers', jsonEncode(stickers));
      await HomeWidget.saveWidgetData<int>('count', open.length);
      await HomeWidget.saveWidgetData<String>(
        'next',
        open.isNotEmpty ? open.first['content'] as String : '할 일 없음',
      );
      await HomeWidget.updateWidget(
        iOSName: iOSWidgetName,
        androidName: androidWidgetName,
      );
    } catch (_) {
      // Widget / App Group may not be configured on this platform; ignore.
    }
  }

  /// A human label for a sticker: its title, else its first todo, else default.
  static String _stickerName(StickyWithTodos s) {
    if (s.sticky.title.trim().isNotEmpty) return s.sticky.title;
    if (s.todos.isNotEmpty) return s.todos.first.content;
    return '새 스티커';
  }

  /// Reads and clears the checkbox taps made in the widget, as id -> new state.
  static Future<Map<String, bool>> _drainPending() async {
    final String? raw = await HomeWidget.getWidgetData<String>('pending');
    if (raw == null || raw.isEmpty) return <String, bool>{};
    final Map<String, bool> result = <String, bool>{};
    try {
      for (final dynamic e in jsonDecode(raw) as List<dynamic>) {
        final Map<String, dynamic> m = e as Map<String, dynamic>;
        result[m['id'] as String] = m['done'] as bool;
      }
    } catch (_) {
      return <String, bool>{};
    }
    if (result.isNotEmpty) {
      await HomeWidget.saveWidgetData<String>('pending', '[]');
    }
    return result;
  }
}
