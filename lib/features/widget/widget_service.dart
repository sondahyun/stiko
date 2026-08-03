import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../data/local/database.dart';
import '../../data/sticky_repository.dart';

/// Bridges the board to the iOS / Android home and lock screen widgets, sharing
/// data through an App Group. Also reconciles toggles the user made from the
/// widget (while the app was closed) back into the repository.
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

  /// Pushes the current board to the widget and applies any toggles made from
  /// the widget itself. [repo] is used to persist those toggles.
  static Future<void> sync(
    List<StickyWithTodos> board,
    StickyRepository repo,
  ) async {
    if (!_supported) return;
    try {
      await HomeWidget.setAppGroupId(appGroupId);

      // 1) Apply toggles the user tapped in the widget while the app was away.
      final Set<String> pendingIds = await _drainPending();
      for (final String id in pendingIds) {
        await repo.toggleTodo(id, true);
      }

      // 2) Publish the current incomplete todos for the widget to render,
      //    hiding any just toggled from the widget so they do not flash back.
      final List<Map<String, String>> incomplete = <Map<String, String>>[];
      int total = 0;
      int done = 0;
      for (final StickyWithTodos s in board) {
        for (final Todo t in s.todos) {
          total++;
          if (t.isDone || pendingIds.contains(t.id)) {
            done++;
          } else {
            incomplete.add(<String, String>{'id': t.id, 'content': t.content});
          }
        }
      }

      await HomeWidget.saveWidgetData<String>('todos', jsonEncode(incomplete));
      await HomeWidget.saveWidgetData<int>('count', incomplete.length);
      await HomeWidget.saveWidgetData<int>('done', done);
      await HomeWidget.saveWidgetData<int>('total', total);
      await HomeWidget.saveWidgetData<String>(
        'next',
        incomplete.isNotEmpty ? incomplete.first['content']! : '할 일 없음',
      );
      await HomeWidget.updateWidget(
        iOSName: iOSWidgetName,
        androidName: androidWidgetName,
      );
    } catch (_) {
      // Widget / App Group may not be configured on this platform; ignore.
    }
  }

  /// Reads and clears the ids the user completed from the widget.
  static Future<Set<String>> _drainPending() async {
    final String? raw = await HomeWidget.getWidgetData<String>('pending');
    if (raw == null || raw.isEmpty) return <String>{};
    Set<String> ids;
    try {
      ids = (jsonDecode(raw) as List<dynamic>).cast<String>().toSet();
    } catch (_) {
      ids = <String>{};
    }
    if (ids.isNotEmpty) {
      await HomeWidget.saveWidgetData<String>('pending', '[]');
    }
    return ids;
  }
}
