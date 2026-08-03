import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/firestore_sticky_repository.dart';
import '../../../data/local/database.dart';
import '../../../data/sticky_repository.dart';
import '../../auth/application/auth_providers.dart';
import '../../widget/widget_service.dart';

/// Repository backed by the signed-in user's Firestore data. Rebuilds when the
/// user changes so each account sees only its own board.
final stickyRepositoryProvider = Provider<StickyRepository>((ref) {
  final String uid =
      ref.watch(authStateProvider).valueOrNull?.uid ?? 'anonymous';
  return FirestoreStickyRepository(uid: uid);
});

/// Reactive stream of every sticky with its todos, ordered for display.
final boardStreamProvider = StreamProvider<List<StickyWithTodos>>((ref) {
  return ref.watch(stickyRepositoryProvider).watchBoard();
});

/// Mirrors the board to the home and lock screen widgets whenever it changes.
/// Watch this where the board is shown to keep the widget up to date.
final widgetSyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<List<StickyWithTodos>>>(
    boardStreamProvider,
    (AsyncValue<List<StickyWithTodos>>? prev,
        AsyncValue<List<StickyWithTodos>> next) {
      final List<StickyWithTodos>? board = next.valueOrNull;
      if (board != null) WidgetService.sync(board);
    },
    fireImmediately: true,
  );
});
