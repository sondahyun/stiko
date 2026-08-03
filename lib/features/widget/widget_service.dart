import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../data/local/database.dart';

/// Pushes a summary of the board to the iOS / Android home and lock screen
/// widgets, sharing data through an App Group so the native widget can read it.
class WidgetService {
  const WidgetService._();

  /// Must match the App Group configured on the iOS Runner and widget targets.
  static const String appGroupId = 'group.io.github.sondahyun.stiko';

  /// Must match the SwiftUI widget's `kind` and the Android provider class.
  static const String iOSWidgetName = 'StikoWidget';
  static const String androidWidgetName = 'StikoWidgetProvider';

  static bool get _supported =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  /// Writes the current board summary and asks the OS to refresh the widget.
  static Future<void> sync(List<StickyWithTodos> board) async {
    if (!_supported) return;

    final List<Todo> todos = <Todo>[
      for (final StickyWithTodos s in board) ...s.todos,
    ];
    final List<Todo> incomplete =
        todos.where((Todo t) => !t.isDone).toList();
    final int done = todos.length - incomplete.length;

    try {
      await HomeWidget.setAppGroupId(appGroupId);
      await HomeWidget.saveWidgetData<int>('count', incomplete.length);
      await HomeWidget.saveWidgetData<int>('done', done);
      await HomeWidget.saveWidgetData<int>('total', todos.length);
      await HomeWidget.saveWidgetData<String>(
        'next',
        incomplete.isNotEmpty ? incomplete.first.content : '할 일 없음',
      );
      await HomeWidget.updateWidget(
        iOSName: iOSWidgetName,
        androidName: androidWidgetName,
      );
    } catch (_) {
      // The widget extension / App Group may not be set up yet; ignore so the
      // app keeps working without a configured widget.
    }
  }
}
