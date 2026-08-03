import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stiko/data/local/database.dart';
import 'package:stiko/data/sticky_repository.dart';

void main() {
  late AppDatabase db;
  late StickyRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LocalStickyRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('addSticky가 빈 스티커를 만든다', () async {
    final Sticky sticky = await repo.addSticky(colorIndex: 2);

    expect(sticky.colorIndex, 2);

    final board = await repo.watchBoard().first;
    expect(board, hasLength(1));
    expect(board.first.todos, isEmpty);
  });

  test('addTodo가 스티커 안에 할 일을 넣는다', () async {
    final Sticky sticky = await repo.addSticky();

    await repo.addTodo(sticky.id, '우유 사기');

    final board = await repo.watchBoard().first;
    expect(board.first.todos.map((Todo t) => t.content), <String>['우유 사기']);
  });

  test('toggleTodo가 완료 상태를 바꾼다', () async {
    final Sticky sticky = await repo.addSticky();
    final Todo todo = await repo.addTodo(sticky.id, '운동');

    await repo.toggleTodo(todo.id, true);

    final board = await repo.watchBoard().first;
    expect(board.first.todos.first.isDone, isTrue);
  });

  test('editTodoContent가 내용을 수정한다', () async {
    final Sticky sticky = await repo.addSticky();
    final Todo todo = await repo.addTodo(sticky.id, '책');

    await repo.editTodoContent(todo.id, '소설');

    final board = await repo.watchBoard().first;
    expect(board.first.todos.first.content, '소설');
  });

  test('deleteSticky가 스티커와 그 안의 할 일을 함께 지운다', () async {
    final Sticky sticky = await repo.addSticky();
    final Todo todo = await repo.addTodo(sticky.id, 'A');

    await repo.deleteSticky(sticky.id);

    final board = await repo.watchBoard().first;
    expect(board, isEmpty);
    expect(await db.getTodoById(todo.id), isNull);
  });

  test('여러 스티커가 생성 순서대로 보인다', () async {
    final Sticky first = await repo.addSticky();
    final Sticky second = await repo.addSticky();
    await repo.addTodo(first.id, 'first');
    await repo.addTodo(second.id, 'second');

    final board = await repo.watchBoard().first;
    expect(board, hasLength(2));
    expect(board[0].sticky.id, first.id);
    expect(board[1].sticky.id, second.id);
  });
}
