import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stiko/data/local/database.dart';
import 'package:stiko/data/todo_repository.dart';

void main() {
  late AppDatabase db;
  late TodoRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LocalTodoRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('addTodo가 새 할 일을 저장한다', () async {
    final todo = await repo.addTodo(title: '우유 사기');

    expect(todo.title, '우유 사기');
    expect(todo.isDone, isFalse);

    final all = await repo.getTodos();
    expect(all, hasLength(1));
    expect(all.first.id, todo.id);
  });

  test('toggleDone이 완료 상태를 바꾼다', () async {
    final todo = await repo.addTodo(title: '운동하기');

    await repo.toggleDone(todo.id, true);

    final updated = await db.getTodoById(todo.id);
    expect(updated!.isDone, isTrue);
  });

  test('editTodo가 제목만 수정하고 다른 필드는 유지한다', () async {
    final todo = await repo.addTodo(title: '책 읽기', note: '2장까지');

    await repo.editTodo(todo.id, title: '소설 읽기');

    final updated = await db.getTodoById(todo.id);
    expect(updated!.title, '소설 읽기');
    expect(updated.note, '2장까지');
  });

  test('deleteTodo가 할 일을 삭제한다', () async {
    final todo = await repo.addTodo(title: '삭제 대상');

    await repo.deleteTodo(todo.id);

    expect(await repo.getTodos(), isEmpty);
  });

  test('clearCompleted가 완료된 할 일만 제거한다', () async {
    final done = await repo.addTodo(title: '완료됨');
    await repo.addTodo(title: '진행중');
    await repo.toggleDone(done.id, true);

    await repo.clearCompleted();

    final remaining = await repo.getTodos();
    expect(remaining, hasLength(1));
    expect(remaining.first.title, '진행중');
  });

  test('reorder가 저장 순서를 바꾼다', () async {
    final Todo a = await repo.addTodo(title: 'A');
    final Todo b = await repo.addTodo(title: 'B');
    final Todo c = await repo.addTodo(title: 'C');

    await repo.reorder(<Todo>[c, a, b]);

    final List<Todo> ordered = await repo.getTodos();
    expect(
      ordered.map((Todo t) => t.title).toList(),
      <String>['C', 'A', 'B'],
    );
  });

  test('watchTodos가 추가를 방출한다', () {
    expectLater(
      repo.watchTodos(),
      emitsThrough(predicate<List<Todo>>((list) => list.length == 1)),
    );

    repo.addTodo(title: '스트림 테스트');
  });
}
