import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database.dart';
import '../../../data/sticky_repository.dart';

/// Single shared database instance for the whole app.
final databaseProvider = Provider<AppDatabase>((ref) {
  final AppDatabase db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Repository that exposes board operations to the UI layer.
final stickyRepositoryProvider = Provider<StickyRepository>((ref) {
  return LocalStickyRepository(ref.watch(databaseProvider));
});

/// Reactive stream of every sticky with its todos, ordered for display.
final boardStreamProvider = StreamProvider<List<StickyWithTodos>>((ref) {
  return ref.watch(stickyRepositoryProvider).watchBoard();
});
