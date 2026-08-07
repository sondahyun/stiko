import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stiko/data/local/database.dart' show Todo;
import 'package:stiko/features/sticky_window/sticky_window_todo_line.dart';

void main() {
  Todo todo({String content = '기존 내용'}) {
    final DateTime now = DateTime(2026, 8, 4);
    return Todo(
      id: 'todo-1',
      stickyId: 'sticky-1',
      content: content,
      isDone: false,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  testWidgets('기존 할 일 내용을 수정하고 Enter로 저장한다', (tester) async {
    final List<String> edits = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StickyWindowTodoLine(
            todo: todo(),
            onToggle: (_) async {},
            onEdit: (String content) async => edits.add(content),
            onDelete: () async {},
          ),
        ),
      ),
    );

    final Finder editor = find.byKey(
      const ValueKey<String>('sticky-todo-editor-todo-1'),
    );
    await tester.enterText(editor, '수정된 내용');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(edits, <String>['수정된 내용']);
  });

  testWidgets('내용을 비우고 포커스를 옮기면 항목을 삭제한다', (tester) async {
    int deletes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              StickyWindowTodoLine(
                todo: todo(),
                onToggle: (_) async {},
                onEdit: (_) async {},
                onDelete: () async => deletes++,
              ),
              const TextField(key: ValueKey<String>('next-field')),
            ],
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('sticky-todo-editor-todo-1')),
      '   ',
    );
    await tester.tap(find.byKey(const ValueKey<String>('next-field')));
    await tester.pump();

    expect(deletes, 1);
  });

  testWidgets('삭제 버튼을 누르면 항목을 한 번만 삭제한다', (tester) async {
    int deletes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              StickyWindowTodoLine(
                todo: todo(),
                onToggle: (_) async {},
                onEdit: (_) async {},
                onDelete: () async => deletes++,
              ),
              const TextField(key: ValueKey<String>('next-field')),
            ],
          ),
        ),
      ),
    );

    // Focus the row first: losing focus must not add a second delete.
    await tester.tap(
      find.byKey(const ValueKey<String>('sticky-todo-editor-todo-1')),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('할 일 삭제'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('next-field')));
    await tester.pump();

    expect(deletes, 1);
  });

  testWidgets('긴 할 일은 행 높이가 늘어나며 다음 줄로 자동 줄바꿈한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 260,
              child: StickyWindowTodoLine(
                todo: todo(
                  content: 'chocopick에 rag 구현 작업을 추가하고 다음 단계까지 이어서 확인하기',
                ),
                onToggle: (_) async {},
                onEdit: (_) async {},
                onDelete: () async {},
                dragHandle: const SizedBox(width: 32, height: 40),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final Finder editor = find.byKey(
      const ValueKey<String>('sticky-todo-editor-todo-1'),
    );
    final TextField field = tester.widget<TextField>(editor);

    expect(field.maxLines, isNull);
    expect(field.textInputAction, TextInputAction.done);
    expect(tester.getSize(editor).height, greaterThan(48));
  });
}
