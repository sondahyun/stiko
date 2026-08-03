import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'local/database.dart';

/// Contract for reading and mutating todos.
///
/// Keeping this as an interface lets the UI depend on behavior, not storage,
/// so a cloud-synced implementation can be swapped in later without touching
/// the widgets.
abstract interface class TodoRepository {
  Stream<List<Todo>> watchTodos();
  Future<List<Todo>> getTodos();
  Future<Todo> addTodo({required String title, String? note, int colorIndex});
  Future<void> editTodo(
    String id, {
    String? title,
    String? note,
    int? colorIndex,
  });
  Future<void> toggleDone(String id, bool isDone);
  Future<void> deleteTodo(String id);
  Future<void> clearCompleted();

  /// Persists a new manual ordering (top to bottom).
  Future<void> reorder(List<Todo> orderedTodos);
}

/// Drift-backed [TodoRepository].
///
/// Owns id and timestamp generation so the rest of the app never has to think
/// about them. [uuid] and [clock] are injectable to keep tests deterministic.
class LocalTodoRepository implements TodoRepository {
  LocalTodoRepository(
    this._db, {
    this._uuid = const Uuid(),
    this._clock = DateTime.now,
  });

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _clock;

  @override
  Stream<List<Todo>> watchTodos() => _db.watchTodos();

  @override
  Future<List<Todo>> getTodos() => _db.getAllTodos();

  @override
  Future<Todo> addTodo({
    required String title,
    String? note,
    int colorIndex = 0,
  }) async {
    final DateTime now = _clock();
    final String id = _uuid.v4();
    await _db.createTodo(
      TodosCompanion.insert(
        id: id,
        title: title,
        note: Value(note),
        colorIndex: Value(colorIndex),
        sortOrder: Value(now.millisecondsSinceEpoch),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return (await _db.getTodoById(id))!;
  }

  @override
  Future<void> editTodo(
    String id, {
    String? title,
    String? note,
    int? colorIndex,
  }) {
    return _db.patchTodo(
      id,
      TodosCompanion(
        title: title == null ? const Value.absent() : Value(title),
        note: note == null ? const Value.absent() : Value(note),
        colorIndex:
            colorIndex == null ? const Value.absent() : Value(colorIndex),
        updatedAt: Value(_clock()),
      ),
    );
  }

  @override
  Future<void> toggleDone(String id, bool isDone) {
    return _db.patchTodo(
      id,
      TodosCompanion(isDone: Value(isDone), updatedAt: Value(_clock())),
    );
  }

  @override
  Future<void> deleteTodo(String id) => _db.deleteTodo(id);

  @override
  Future<void> clearCompleted() => _db.deleteCompleted();

  @override
  Future<void> reorder(List<Todo> orderedTodos) =>
      _db.reorderByIds(<String>[for (final Todo t in orderedTodos) t.id]);
}
