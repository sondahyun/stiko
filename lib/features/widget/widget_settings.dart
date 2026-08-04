import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which stickers the home / lock screen widget shows. An empty set means
/// "show every sticker". Stored per device.
final widgetStickerSelectionProvider =
    StateNotifierProvider<WidgetStickerSelection, Set<String>>(
  (ref) => WidgetStickerSelection(),
);

class WidgetStickerSelection extends StateNotifier<Set<String>> {
  WidgetStickerSelection() : super(<String>{}) {
    _load();
  }

  static const String _key = 'widget_sticker_ids';

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    state = (prefs.getStringList(_key) ?? const <String>[]).toSet();
  }

  /// Adds or removes [stickyId] from the widget's shown stickers.
  Future<void> toggle(String stickyId) async {
    final Set<String> next = <String>{...state};
    if (!next.remove(stickyId)) next.add(stickyId);
    state = next;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next.toList());
  }
}
