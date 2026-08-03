import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stiko/app/app.dart';
import 'package:stiko/data/local/database.dart';
import 'package:stiko/data/todo_repository.dart';
import 'package:stiko/features/todos/application/todo_providers.dart';

/// Builds a [Todo] with fixed, deterministic timestamps for widget tests.
Todo _todo({
  String id = 't1',
  String title = '할 일',
  String? note,
  bool isDone = false,
  int colorIndex = 0,
}) {
  final DateTime now = DateTime(2026, 1, 1);
  return Todo(
    id: id,
    title: title,
    note: note,
    isDone: isDone,
    colorIndex: colorIndex,
    sortOrder: 0,
    createdAt: now,
    updatedAt: now,
  );
}

/// In-memory fake so widget tests never touch Drift or its timers.
class FakeTodoRepository implements TodoRepository {
  FakeTodoRepository(this._seed);

  final List<Todo> _seed;
  final List<(String id, bool isDone)> toggled = <(String, bool)>[];
  final List<String> deleted = <String>[];

  @override
  Stream<List<Todo>> watchTodos() => Stream<List<Todo>>.value(_seed);

  @override
  Future<List<Todo>> getTodos() async => _seed;

  @override
  Future<Todo> addTodo({
    required String title,
    String? note,
    int colorIndex = 0,
  }) async =>
      _todo(title: title, note: note, colorIndex: colorIndex);

  @override
  Future<void> editTodo(
    String id, {
    String? title,
    String? note,
    int? colorIndex,
  }) async {}

  @override
  Future<void> toggleDone(String id, bool isDone) async =>
      toggled.add((id, isDone));

  @override
  Future<void> deleteTodo(String id) async => deleted.add(id);

  @override
  Future<void> clearCompleted() async {}

  @override
  Future<void> reorder(List<Todo> orderedTodos) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Widget bootstrap(TodoRepository repo) {
    return ProviderScope(
      overrides: <Override>[todoRepositoryProvider.overrideWithValue(repo)],
      child: const StikoApp(),
    );
  }

  testWidgets('할 일이 없으면 빈 상태 안내가 보인다', (tester) async {
    await tester.pumpWidget(bootstrap(FakeTodoRepository(const <Todo>[])));
    await tester.pumpAndSettle();

    expect(find.text('stiko'), findsOneWidget);
    expect(find.text('할 일이 없습니다'), findsOneWidget);
  });

  testWidgets('저장된 할 일이 목록에 표시된다', (tester) async {
    await tester.pumpWidget(
      bootstrap(FakeTodoRepository(<Todo>[_todo(title: '장보기')])),
    );
    await tester.pumpAndSettle();

    expect(find.text('장보기'), findsOneWidget);
    expect(find.text('할 일이 없습니다'), findsNothing);
  });

  testWidgets('체크박스를 누르면 toggleDone이 호출된다', (tester) async {
    final FakeTodoRepository repo =
        FakeTodoRepository(<Todo>[_todo(id: 'abc', title: '완료할 일')]);
    await tester.pumpWidget(bootstrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(repo.toggled, contains(('abc', true)));
  });
}
