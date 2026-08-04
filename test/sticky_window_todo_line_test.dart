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
}
