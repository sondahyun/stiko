import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'local/database.dart';

/// Contract for reading and mutating the sticky board.
///
/// Keeping this as an interface lets the UI depend on behavior, not storage, so
/// a cloud-synced implementation can be swapped in later.
abstract interface class StickyRepository {
  Stream<List<StickyWithTodos>> watchBoard();

  Future<Sticky> addSticky({int colorIndex});
  Future<void> setStickyColor(String stickyId, int colorIndex);
  Future<void> deleteSticky(String stickyId);
  Future<void> reorderStickies(List<Sticky> ordered);

  Future<Todo> addTodo(String stickyId, String content);
  Future<void> editTodoContent(String todoId, String content);
  Future<void> toggleTodo(String todoId, bool isDone);
  Future<void> deleteTodo(String todoId);
  Future<void> reorderTodos(List<Todo> ordered);
}

/// Drift-backed [StickyRepository]. Owns id and timestamp generation.
class LocalStickyRepository implements StickyRepository {
  LocalStickyRepository(
    this._db, {
    this._uuid = const Uuid(),
    this._clock = DateTime.now,
  });

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _clock;

  @override
  Stream<List<StickyWithTodos>> watchBoard() => _db.watchBoard();

  @override
  Future<Sticky> addSticky({int colorIndex = 0}) async {
    final DateTime now = _clock();
    final String id = _uuid.v4();
    final int order = now.millisecondsSinceEpoch;
    await _db.createSticky(
      StickiesCompanion.insert(
        id: id,
        colorIndex: Value(colorIndex),
        sortOrder: Value(order),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return Sticky(
      id: id,
      colorIndex: colorIndex,
      sortOrder: order,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<void> setStickyColor(String stickyId, int colorIndex) =>
      _db.updateStickyColor(stickyId, colorIndex, _clock());

  @override
  Future<void> deleteSticky(String stickyId) => _db.deleteSticky(stickyId);

  @override
  Future<void> reorderStickies(List<Sticky> ordered) =>
      _db.reorderStickiesByIds(<String>[for (final Sticky s in ordered) s.id]);

  @override
  Future<Todo> addTodo(String stickyId, String content) async {
    final DateTime now = _clock();
    final String id = _uuid.v4();
    await _db.createTodo(
      TodosCompanion.insert(
        id: id,
        stickyId: stickyId,
        content: content,
        sortOrder: Value(now.millisecondsSinceEpoch),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return (await _db.getTodoById(id))!;
  }

  @override
  Future<void> editTodoContent(String todoId, String content) => _db.patchTodo(
        todoId,
        TodosCompanion(content: Value(content), updatedAt: Value(_clock())),
      );

  @override
  Future<void> toggleTodo(String todoId, bool isDone) => _db.patchTodo(
        todoId,
        TodosCompanion(isDone: Value(isDone), updatedAt: Value(_clock())),
      );

  @override
  Future<void> deleteTodo(String todoId) => _db.deleteTodo(todoId);

  @override
  Future<void> reorderTodos(List<Todo> ordered) =>
      _db.reorderTodosByIds(<String>[for (final Todo t in ordered) t.id]);
}
