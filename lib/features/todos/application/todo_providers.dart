import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database.dart';
import '../../../data/todo_repository.dart';

/// Single shared database instance for the whole app.
final databaseProvider = Provider<AppDatabase>((ref) {
  final AppDatabase db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Repository that exposes todo operations to the UI layer.
final todoRepositoryProvider = Provider<TodoRepository>((ref) {
  return TodoRepository(ref.watch(databaseProvider));
});

/// Reactive stream of all todos, ordered for display.
final todosStreamProvider = StreamProvider<List<Todo>>((ref) {
  return ref.watch(todoRepositoryProvider).watchTodos();
});
