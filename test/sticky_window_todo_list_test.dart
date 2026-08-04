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

    final ReorderableListView list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
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
