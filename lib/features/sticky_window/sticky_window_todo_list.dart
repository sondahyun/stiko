import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/local/database.dart' show Todo, completedLast;
import 'sticky_window_todo_line.dart';

/// Reorderable checklist used by a standalone sticky window.
class StickyWindowTodoList extends StatelessWidget {
  const StickyWindowTodoList({
    super.key,
    required this.todos,
    required this.addRow,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onReorder,
  });

  final List<Todo> todos;
  final Widget addRow;
  final Future<void> Function(Todo todo, bool isDone) onToggle;
  final Future<void> Function(Todo todo, String content) onEdit;
  final Future<void> Function(Todo todo) onDelete;
  final Future<void> Function(List<Todo> ordered) onReorder;

  @override
  Widget build(BuildContext context) {
    final List<Todo> ordered = completedLast(todos);
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 12),
      buildDefaultDragHandles: false,
      itemCount: ordered.length + 1,
      onReorderItem: (int oldIndex, int newIndex) {
        if (oldIndex >= ordered.length) return;
        final List<Todo> reordered = <Todo>[...ordered];
        final Todo moved = reordered.removeAt(oldIndex);

        // completedLast intentionally keeps the two states grouped. Clamp the
        // drop position into the moved item's group so the saved order and the
        // rendered order cannot disagree after the Firestore stream updates.
        final int incompleteCount = reordered
            .where((Todo todo) => !todo.isDone)
            .length;
        final int minIndex = moved.isDone ? incompleteCount : 0;
        final int maxIndex = moved.isDone ? reordered.length : incompleteCount;
        final int target = newIndex.clamp(minIndex, maxIndex);
        reordered.insert(target, moved);
        if (target != oldIndex) unawaited(onReorder(reordered));
      },
      proxyDecorator: (Widget child, int index, Animation<double> animation) {
        return Material(
          color: Colors.transparent,
          elevation: 4,
          shadowColor: Colors.black26,
          child: child,
        );
      },
      itemBuilder: (BuildContext context, int index) {
        if (index == ordered.length) {
          return KeyedSubtree(
            key: const ValueKey<String>('sticky-add-todo-row'),
            child: addRow,
          );
        }
        final Todo todo = ordered[index];
        return StickyWindowTodoLine(
          key: ValueKey<String>(todo.id),
          todo: todo,
          onToggle: (bool value) => onToggle(todo, value),
          onEdit: (String content) => onEdit(todo, content),
          onDelete: () => onDelete(todo),
          dragHandle: Tooltip(
            message: '순서 이동',
            child: ReorderableDragStartListener(
              key: ValueKey<String>('sticky-todo-drag-${todo.id}'),
              index: index,
              child: const MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  child: Icon(
                    Icons.drag_indicator,
                    size: 18,
                    color: Colors.black38,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
