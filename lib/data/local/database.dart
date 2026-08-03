import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// A single todo item, persisted locally.
///
/// [id] is a client-generated UUID so the same row can later be matched to a
/// remote document when cloud sync is added.
class Todos extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 500)();
  TextColumn get note => text().nullable()();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();

  /// Manual ordering key. Lower values appear first.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Todos])
class AppDatabase extends _$AppDatabase {
  /// Opens the on-device database. Pass a custom [executor] (for example an
  /// in-memory one) in tests.
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'stiko'));

  @override
  int get schemaVersion => 1;

  /// Emits the full todo list, ordered for display, on every change.
  Stream<List<Todo>> watchTodos() => _ordered().watch();

  /// Reads the full todo list once.
  Future<List<Todo>> getAllTodos() => _ordered().get();

  Future<Todo?> getTodoById(String id) =>
      (select(todos)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> createTodo(TodosCompanion entry) => into(todos).insert(entry);

  /// Applies a partial update to the row with [id].
  Future<void> patchTodo(String id, TodosCompanion patch) =>
      (update(todos)..where((t) => t.id.equals(id))).write(patch);

  Future<int> deleteTodo(String id) =>
      (delete(todos)..where((t) => t.id.equals(id))).go();

  Future<int> deleteCompleted() =>
      (delete(todos)..where((t) => t.isDone.equals(true))).go();

  /// Rewrites [sortOrder] so the stored order matches [orderedIds] top down.
  Future<void> reorderByIds(List<String> orderedIds) async {
    await batch((batch) {
      for (int i = 0; i < orderedIds.length; i++) {
        batch.update(
          todos,
          TodosCompanion(sortOrder: Value(i)),
          where: (t) => t.id.equals(orderedIds[i]),
        );
      }
    });
  }

  SimpleSelectStatement<$TodosTable, Todo> _ordered() {
    return select(todos)
      ..orderBy([
        (t) => OrderingTerm(expression: t.sortOrder),
        (t) => OrderingTerm(expression: t.createdAt),
      ]);
  }
}
