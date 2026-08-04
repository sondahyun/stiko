import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// A sticky note: a colored container that holds a list of todos.
class Stickies extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();
  RealColumn get opacity => real().withDefault(const Constant(1.0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A single checkable line inside a sticky.
class Todos extends Table {
  TextColumn get id => text()();
  TextColumn get stickyId =>
      text().references(Stickies, #id, onDelete: KeyAction.cascade)();
  TextColumn get content => text().withLength(max: 500)();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A sticky paired with its ordered todos, ready for display.
class StickyWithTodos {
  StickyWithTodos(this.sticky, this.todos);

  final Sticky sticky;
  final List<Todo> todos;
}

/// Orders todos with incomplete ones first and completed ones sunk to the
/// bottom, matching how the widget shows them. Each group keeps its saved order.
List<Todo> completedLast(List<Todo> todos) => <Todo>[
  ...todos.where((Todo t) => !t.isDone),
  ...todos.where((Todo t) => t.isDone),
];

@DriftDatabase(tables: [Stickies, Todos])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'stiko'));

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 4) {
        for (final table in allTables) {
          await m.deleteTable(table.actualTableName);
        }
        await m.createAll();
        return;
      }
      if (from < 5) {
        await m.addColumn(stickies, stickies.deletedAt);
      }
    },
  );

  /// Emits every sticky with its todos, ordered for display, on each change.
  Stream<List<StickyWithTodos>> watchBoard() => _watchStickies(trashed: false);

  /// Emits soft-deleted stickies so they can be restored or removed forever.
  Stream<List<StickyWithTodos>> watchTrash() => _watchStickies(trashed: true);

  Stream<List<StickyWithTodos>> _watchStickies({required bool trashed}) {
    final query =
        select(stickies).join(<Join>[
            leftOuterJoin(todos, todos.stickyId.equalsExp(stickies.id)),
          ])
          ..where(
            trashed
                ? stickies.deletedAt.isNotNull()
                : stickies.deletedAt.isNull(),
          )
          ..orderBy(<OrderingTerm>[
            if (trashed)
              OrderingTerm(
                expression: stickies.deletedAt,
                mode: OrderingMode.desc,
              ),
            OrderingTerm(expression: stickies.sortOrder),
            OrderingTerm(expression: todos.sortOrder),
          ]);

    return query.watch().map((rows) {
      final grouped = <String, StickyWithTodos>{};
      for (final row in rows) {
        final sticky = row.readTable(stickies);
        final todo = row.readTableOrNull(todos);
        final entry = grouped.putIfAbsent(
          sticky.id,
          () => StickyWithTodos(sticky, <Todo>[]),
        );
        if (todo != null) entry.todos.add(todo);
      }
      return grouped.values.toList();
    });
  }

  // Sticky operations ---------------------------------------------------------

  Future<void> createSticky(StickiesCompanion sticky) =>
      into(stickies).insert(sticky);

  Future<void> updateStickyColor(String id, int colorIndex, DateTime now) {
    return (update(stickies)..where((t) => t.id.equals(id))).write(
      StickiesCompanion(colorIndex: Value(colorIndex), updatedAt: Value(now)),
    );
  }

  Future<void> updateStickyOpacity(String id, double opacity, DateTime now) {
    return (update(stickies)..where((t) => t.id.equals(id))).write(
      StickiesCompanion(opacity: Value(opacity), updatedAt: Value(now)),
    );
  }

  Future<void> updateStickyTitle(String id, String title, DateTime now) {
    return (update(stickies)..where((t) => t.id.equals(id))).write(
      StickiesCompanion(title: Value(title), updatedAt: Value(now)),
    );
  }

  Future<void> moveStickyToTrash(String id, DateTime now) {
    return (update(stickies)..where((t) => t.id.equals(id))).write(
      StickiesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  Future<void> restoreSticky(String id, DateTime now) {
    return (update(stickies)..where((t) => t.id.equals(id))).write(
      StickiesCompanion(
        deletedAt: const Value<DateTime?>(null),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> deleteSticky(String id) {
    return transaction(() async {
      await (delete(todos)..where((t) => t.stickyId.equals(id))).go();
      await (delete(stickies)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<void> reorderStickiesByIds(List<String> orderedIds) async {
    await batch((batch) {
      for (int i = 0; i < orderedIds.length; i++) {
        batch.update(
          stickies,
          StickiesCompanion(sortOrder: Value(i)),
          where: (t) => t.id.equals(orderedIds[i]),
        );
      }
    });
  }

  // Todo operations -----------------------------------------------------------

  Future<void> createTodo(TodosCompanion todo) => into(todos).insert(todo);

  Future<Todo?> getTodoById(String id) =>
      (select(todos)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> patchTodo(String id, TodosCompanion patch) =>
      (update(todos)..where((t) => t.id.equals(id))).write(patch);

  Future<void> deleteTodo(String id) =>
      (delete(todos)..where((t) => t.id.equals(id))).go();

  Future<void> reorderTodosByIds(List<String> orderedIds) async {
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
}
