import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'local/database.dart';

/// Coordinates all todo persistence.
///
/// Owns id and timestamp generation so the rest of the app never has to think
/// about them. [uuid] and [clock] are injectable to keep tests deterministic.
class TodoRepository {
  TodoRepository(
    this._db, {
    this._uuid = const Uuid(),
    this._clock = DateTime.now,
  });

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _clock;

  Stream<List<Todo>> watchTodos() => _db.watchTodos();

  Future<List<Todo>> getTodos() => _db.getAllTodos();

  /// Creates a new todo and returns the stored row.
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

  /// Updates editable fields. A null argument leaves that field unchanged.
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

  Future<void> toggleDone(String id, bool isDone) {
    return _db.patchTodo(
      id,
      TodosCompanion(isDone: Value(isDone), updatedAt: Value(_clock())),
    );
  }

  Future<void> deleteTodo(String id) => _db.deleteTodo(id);

  Future<void> clearCompleted() => _db.deleteCompleted();
}
