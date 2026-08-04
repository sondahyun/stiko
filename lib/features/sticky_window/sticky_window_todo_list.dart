import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/local/database.dart' show Todo, completedLast;
import 'sticky_window_todo_line.dart';

/// Reorderable checklist used by a standalone sticky window.
class StickyWindowTodoList extends StatefulWidget {
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
  State<StickyWindowTodoList> createState() => _StickyWindowTodoListState();
}

class _StickyWindowTodoListState extends State<StickyWindowTodoList> {
  List<Todo>? _order;

  List<Todo> _reconcile(List<Todo> todos) {
    final List<Todo> incoming = completedLast(todos);
    final List<Todo>? previous = _order;
    final Map<String, Todo> byId = <String, Todo>{
      for (final Todo todo in incoming) todo.id: todo,
    };
    if (previous == null ||
        previous.length != incoming.length ||
        previous.any(
          (Todo todo) =>
              !byId.containsKey(todo.id) ||
              byId[todo.id]!.isDone != todo.isDone,
        )) {
      return _order = List<Todo>.of(incoming);
    }
    return _order = <Todo>[for (final Todo todo in previous) byId[todo.id]!];
  }

  @override
  Widget build(BuildContext context) {
    final List<Todo> ordered = _reconcile(widget.todos);
    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
          sliver: SliverReorderableList(
            itemCount: ordered.length,
            onReorderItem: (int oldIndex, int newIndex) {
              final List<Todo> reordered = <Todo>[...ordered];
              final Todo moved = reordered.removeAt(oldIndex);

              // completedLast intentionally keeps the two states grouped.
              // Clamp the drop into the moved item's group so the saved order
              // and rendered order agree after the Firestore stream updates.
              final int incompleteCount = reordered
                  .where((Todo todo) => !todo.isDone)
                  .length;
              final int minIndex = moved.isDone ? incompleteCount : 0;
              final int maxIndex = moved.isDone
                  ? reordered.length
                  : incompleteCount;
              final int target = newIndex.clamp(minIndex, maxIndex);
              reordered.insert(target, moved);
              if (target != oldIndex) {
                setState(() => _order = reordered);
                unawaited(widget.onReorder(reordered));
              }
            },
            proxyDecorator:
                (Widget child, int index, Animation<double> animation) {
                  return Material(
                    color: Colors.transparent,
                    elevation: 4,
                    shadowColor: Colors.black26,
                    child: child,
                  );
                },
            itemBuilder: (BuildContext context, int index) {
              final Todo todo = ordered[index];
              return StickyWindowTodoLine(
                key: ValueKey<String>(todo.id),
                todo: todo,
                onToggle: (bool value) => widget.onToggle(todo, value),
                onEdit: (String content) => widget.onEdit(todo, content),
                onDelete: () => widget.onDelete(todo),
                dragHandle: Tooltip(
                  message: '순서 이동',
                  child: ReorderableDragStartListener(
                    key: ValueKey<String>('sticky-todo-drag-${todo.id}'),
                    index: index,
                    child: const MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 10,
                        ),
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
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(4, 0, 12, 12),
          sliver: SliverToBoxAdapter(
            child: KeyedSubtree(
              key: const ValueKey<String>('sticky-add-todo-row'),
              child: widget.addRow,
            ),
          ),
        ),
      ],
    );
  }
}
