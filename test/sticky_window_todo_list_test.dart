import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stiko/data/local/database.dart' show Todo;
import 'package:stiko/features/sticky_window/sticky_window_todo_list.dart';

void main() {
  Todo todo(String id, {bool isDone = false}) {
    final DateTime now = DateTime(2026, 8, 4);
    return Todo(
      id: id,
      stickyId: 'sticky-1',
      content: id,
      isDone: isDone,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  Widget subject(
    List<Todo> todos,
    Future<void> Function(List<Todo>) onReorder,
  ) {
    return MaterialApp(
      home: Scaffold(
        body: StickyWindowTodoList(
          todos: todos,
          addRow: const SizedBox(height: 40),
          onToggle: (_, _) async {},
          onEdit: (_, _) async {},
          onDelete: (_) async {},
          onReorder: onReorder,
        ),
      ),
    );
  }

  testWidgets('각 할 일에 순서 이동 드래그 핸들을 표시한다', (tester) async {
    await tester.pumpWidget(
      subject(<Todo>[todo('a'), todo('b')], (_) async {}),
    );

    expect(
      find.byKey(const ValueKey<String>('sticky-todo-drag-a')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('sticky-todo-drag-b')),
      findsOneWidget,
    );
  });

  testWidgets('빈 스티커에 첫 할 일을 추가해도 목록 요소가 충돌하지 않는다', (tester) async {
    await tester.pumpWidget(subject(const <Todo>[], (_) async {}));
    expect(
      find.byKey(const ValueKey<String>('sticky-add-todo-row')),
      findsOneWidget,
    );

    await tester.pumpWidget(subject(<Todo>[todo('first')], (_) async {}));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey<String>('sticky-todo-drag-first')),
      findsOneWidget,
    );
  });

  testWidgets('순서 이동 손잡이와 삭제 아이콘의 높이가 같다', (tester) async {
    await tester.pumpWidget(subject(<Todo>[todo('a')], (_) async {}));

    final double handleY = tester
        .getCenter(find.byKey(const ValueKey<String>('sticky-todo-drag-a')))
        .dy;
    final double deleteY = tester.getCenter(find.byTooltip('할 일 삭제')).dy;
    expect(deleteY, moreOrLessEquals(handleY, epsilon: 0.5));
  });

  testWidgets('할 일이 창을 넘쳐도 입력 행은 화면 안에 남는다', (tester) async {
    // Before the fix the add row scrolled away with the list, so a full sticky
    // looked like it had hit a to-do limit.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: StickyWindowTodoList(
              todos: <Todo>[for (int i = 0; i < 30; i++) todo('todo-$i')],
              addRow: const SizedBox(
                key: ValueKey<String>('add-row-body'),
                height: 40,
              ),
              onToggle: (_, _) async {},
              onEdit: (_, _) async {},
              onDelete: (_) async {},
              onReorder: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final Finder addRow = find.byKey(const ValueKey<String>('add-row-body'));
    expect(addRow, findsOneWidget);
    expect(tester.getRect(addRow).bottom, lessThanOrEqualTo(300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('드래그 순서를 저장 콜백에 전달한다', (tester) async {
    List<Todo>? saved;
    await tester.pumpWidget(
      subject(<Todo>[
        todo('a'),
        todo('b'),
        todo('c'),
      ], (List<Todo> ordered) async => saved = ordered),
    );

    await tester.drag(
      find.byKey(const ValueKey<String>('sticky-todo-drag-a')),
      const Offset(0, 140),
    );
    await tester.pumpAndSettle();

    expect(saved?.map((Todo item) => item.id), <String>['b', 'c', 'a']);
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .map((TextField field) => field.controller!.text),
      <String>['b', 'c', 'a'],
    );

    // Firestore can briefly emit the previous order while the write is in
    // flight. The just-dragged order must remain mounted during that update.
    await tester.pumpWidget(
      subject(<Todo>[
        todo('a'),
        todo('b'),
        todo('c'),
      ], (List<Todo> ordered) async => saved = ordered),
    );
    await tester.pump();
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .map((TextField field) => field.controller!.text),
      <String>['b', 'c', 'a'],
    );
  });

  testWidgets('완료 항목은 완료 그룹 안에서만 순서를 바꾼다', (tester) async {
    List<Todo>? saved;
    await tester.pumpWidget(
      subject(<Todo>[
        todo('open-a'),
        todo('open-b'),
        todo('done-a', isDone: true),
        todo('done-b', isDone: true),
      ], (List<Todo> ordered) async => saved = ordered),
    );

    final SliverReorderableList list = tester.widget<SliverReorderableList>(
      find.byType(SliverReorderableList),
    );
    list.onReorderItem!(3, 0);
    await tester.pump();

    expect(saved?.map((Todo item) => item.id), <String>[
      'open-a',
      'open-b',
      'done-b',
      'done-a',
    ]);
  });
}
