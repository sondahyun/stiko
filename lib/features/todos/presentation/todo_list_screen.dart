import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database.dart';
import '../application/todo_providers.dart';
import 'widgets/todo_card.dart';
import 'widgets/todo_editor_sheet.dart';

/// Main screen listing every todo as a sticky note.
class TodoListScreen extends ConsumerWidget {
  const TodoListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosAsync = ref.watch(todosStreamProvider);
    final bool hasCompleted =
        todosAsync.valueOrNull?.any((t) => t.isDone) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('stiko'),
        actions: <Widget>[
          if (hasCompleted)
            IconButton(
              tooltip: '완료된 항목 지우기',
              icon: const Icon(Icons.cleaning_services_outlined),
              onPressed: () =>
                  ref.read(todoRepositoryProvider).clearCompleted(),
            ),
        ],
      ),
      body: todosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '할 일을 불러오지 못했습니다\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (todos) {
          if (todos.isEmpty) return const _EmptyState();
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            itemCount: todos.length,
            itemBuilder: (context, index) {
              final Todo todo = todos[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TodoCard(
                  todo: todo,
                  onToggle: (value) => ref
                      .read(todoRepositoryProvider)
                      .toggleDone(todo.id, value),
                  onTap: () => showTodoEditor(context, initial: todo),
                  onDelete: () =>
                      ref.read(todoRepositoryProvider).deleteTodo(todo.id),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTodoEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('할 일'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.sticky_note_2_outlined, size: 64, color: scheme.outline),
          const SizedBox(height: 16),
          Text('할 일이 없습니다', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '아래 + 버튼으로 첫 할 일을 추가해 보세요',
            style: TextStyle(color: scheme.outline),
          ),
        ],
      ),
    );
  }
}
