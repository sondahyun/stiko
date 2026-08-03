import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/platform_utils.dart';
import '../../../data/local/database.dart';
import '../../sticky/application/sticky_window.dart';
import '../../sticky/presentation/sticky_toolbar.dart';
import '../application/todo_providers.dart';
import 'widgets/todo_card.dart';
import 'widgets/todo_editor_sheet.dart';

/// Entry screen. Renders a compact sticky window on desktop and a regular
/// scaffold on mobile, sharing the same todo body.
class TodoListScreen extends ConsumerWidget {
  const TodoListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isDesktop) return const _DesktopStickyScaffold();
    return const _MobileScaffold();
  }
}

class _MobileScaffold extends ConsumerWidget {
  const _MobileScaffold();

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
          IconButton(
            tooltip: '설정',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(StikoRoutes.settings),
          ),
        ],
      ),
      body: const _TodoBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTodoEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('할 일'),
      ),
    );
  }
}

class _DesktopStickyScaffold extends ConsumerWidget {
  const _DesktopStickyScaffold();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool collapsed =
        ref.watch(stickyWindowControllerProvider.select((s) => s.collapsed));

    return Scaffold(
      body: Column(
        children: <Widget>[
          const StickyToolbar(),
          if (!collapsed) const Expanded(child: _TodoBody()),
        ],
      ),
      floatingActionButton: collapsed
          ? null
          : FloatingActionButton.small(
              onPressed: () => showTodoEditor(context),
              child: const Icon(Icons.add),
            ),
    );
  }
}

/// Shared list body: loading / error / empty / list.
class _TodoBody extends ConsumerWidget {
  const _TodoBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosAsync = ref.watch(todosStreamProvider);

    return todosAsync.when(
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
        return ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          buildDefaultDragHandles: false,
          itemCount: todos.length,
          onReorderItem: (oldIndex, newIndex) {
            final List<Todo> reordered = <Todo>[...todos];
            final Todo moved = reordered.removeAt(oldIndex);
            reordered.insert(newIndex, moved);
            ref.read(todoRepositoryProvider).reorder(reordered);
          },
          itemBuilder: (context, index) {
            final Todo todo = todos[index];
            return ReorderableDelayedDragStartListener(
              key: ValueKey<String>('item-${todo.id}'),
              index: index,
              child: Padding(
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
              ),
            );
          },
        );
      },
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
