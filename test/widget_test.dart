import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stiko/app/app.dart';
import 'package:stiko/data/local/database.dart';
import 'package:stiko/data/sticky_repository.dart';
import 'package:stiko/features/board/application/board_providers.dart';

Sticky _sticky({String id = 's1', int colorIndex = 0}) {
  final DateTime now = DateTime(2026, 1, 1);
  return Sticky(
    id: id,
    colorIndex: colorIndex,
    sortOrder: 0,
    createdAt: now,
    updatedAt: now,
  );
}

Todo _todo({
  String id = 't1',
  String stickyId = 's1',
  String content = '할 일',
  bool isDone = false,
}) {
  final DateTime now = DateTime(2026, 1, 1);
  return Todo(
    id: id,
    stickyId: stickyId,
    content: content,
    isDone: isDone,
    sortOrder: 0,
    createdAt: now,
    updatedAt: now,
  );
}

/// In-memory fake so widget tests never touch Drift or its timers.
class FakeStickyRepository implements StickyRepository {
  FakeStickyRepository(this._board);

  final List<StickyWithTodos> _board;
  final List<(String id, bool isDone)> toggled = <(String, bool)>[];
  int addStickyCount = 0;

  @override
  Stream<List<StickyWithTodos>> watchBoard() =>
      Stream<List<StickyWithTodos>>.value(_board);

  @override
  Future<Sticky> addSticky({int colorIndex = 0}) async {
    addStickyCount++;
    return _sticky(id: 'new', colorIndex: colorIndex);
  }

  @override
  Future<Todo> addTodo(String stickyId, String content) async =>
      _todo(stickyId: stickyId, content: content);

  @override
  Future<void> toggleTodo(String todoId, bool isDone) async =>
      toggled.add((todoId, isDone));

  @override
  Future<void> editTodoContent(String todoId, String content) async {}

  @override
  Future<void> deleteTodo(String todoId) async {}

  @override
  Future<void> deleteSticky(String stickyId) async {}

  @override
  Future<void> setStickyColor(String stickyId, int colorIndex) async {}

  @override
  Future<void> reorderStickies(List<Sticky> ordered) async {}

  @override
  Future<void> reorderTodos(List<Todo> ordered) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Widget bootstrap(StickyRepository repo) {
    return ProviderScope(
      overrides: <Override>[stickyRepositoryProvider.overrideWithValue(repo)],
      child: const StikoApp(),
    );
  }

  testWidgets('스티커가 없으면 빈 안내가 보인다', (tester) async {
    await tester.pumpWidget(bootstrap(FakeStickyRepository(const <StickyWithTodos>[])));
    await tester.pumpAndSettle();

    expect(find.text('스티커가 없습니다'), findsOneWidget);
  });

  testWidgets('스티커 안의 할 일이 표시된다', (tester) async {
    final List<StickyWithTodos> board = <StickyWithTodos>[
      StickyWithTodos(_sticky(), <Todo>[_todo(content: '장보기')]),
    ];
    await tester.pumpWidget(bootstrap(FakeStickyRepository(board)));
    await tester.pumpAndSettle();

    expect(find.text('장보기'), findsOneWidget);
    expect(find.text('스티커가 없습니다'), findsNothing);
  });

  testWidgets('체크박스를 누르면 toggleTodo가 호출된다', (tester) async {
    final FakeStickyRepository repo = FakeStickyRepository(<StickyWithTodos>[
      StickyWithTodos(_sticky(), <Todo>[_todo(id: 'abc', content: '완료할 일')]),
    ]);
    await tester.pumpWidget(bootstrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(repo.toggled, contains(('abc', true)));
  });
}
