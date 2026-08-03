import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../data/local/database.dart';
import '../../../../data/sticky_repository.dart';
import '../../application/board_providers.dart';

/// A single sticky note: a colored card holding an inline, editable checklist.
///
/// There is no add button. Type into the bottom line and press Enter to add a
/// todo; type into an existing line to edit it; clear a line to remove it.
class StickyNoteCard extends ConsumerWidget {
  const StickyNoteCard({super.key, required this.data});

  final StickyWithTodos data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color color = StickyColors.at(data.sticky.colorIndex);

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 4, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Spacer(),
                _ColorMenu(
                  stickyId: data.sticky.id,
                  current: data.sticky.colorIndex,
                ),
                IconButton(
                  tooltip: '스티커 삭제',
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, color: Colors.black54),
                  onPressed: () =>
                      ref.read(stickyRepositoryProvider).deleteSticky(
                            data.sticky.id,
                          ),
                ),
              ],
            ),
            for (final Todo todo in data.todos)
              _TodoLine(key: ValueKey<String>(todo.id), todo: todo),
            _AddTodoLine(stickyId: data.sticky.id),
          ],
        ),
      ),
    );
  }
}

/// One existing todo: a checkbox plus inline-editable text.
class _TodoLine extends ConsumerStatefulWidget {
  const _TodoLine({super.key, required this.todo});

  final Todo todo;

  @override
  ConsumerState<_TodoLine> createState() => _TodoLineState();
}

class _TodoLineState extends ConsumerState<_TodoLine> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.todo.content);
    _focus = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) _commit();
  }

  void _commit() {
    final String text = _controller.text.trim();
    final StickyRepository repo = ref.read(stickyRepositoryProvider);
    if (text.isEmpty) {
      repo.deleteTodo(widget.todo.id);
    } else if (text != widget.todo.content) {
      repo.editTodoContent(widget.todo.id, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Checkbox(
          value: widget.todo.isDone,
          onChanged: (bool? v) =>
              ref.read(stickyRepositoryProvider).toggleTodo(
                    widget.todo.id,
                    v ?? false,
                  ),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: const BorderSide(color: Colors.black45),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _commit(),
            style: TextStyle(
              color: Colors.black87,
              decoration:
                  widget.todo.isDone ? TextDecoration.lineThrough : null,
              decorationColor: Colors.black45,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 6),
            ),
          ),
        ),
      ],
    );
  }
}

/// The always-present bottom line: type and press Enter to add a todo.
class _AddTodoLine extends ConsumerStatefulWidget {
  const _AddTodoLine({required this.stickyId});

  final String stickyId;

  @override
  ConsumerState<_AddTodoLine> createState() => _AddTodoLineState();
}

class _AddTodoLineState extends ConsumerState<_AddTodoLine> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final String text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await ref.read(stickyRepositoryProvider).addTodo(widget.stickyId, text);
    if (!mounted) return;
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const SizedBox(
          width: 40,
          child: Icon(Icons.add, size: 18, color: Colors.black38),
        ),
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _add(),
            style: const TextStyle(color: Colors.black87),
            decoration: const InputDecoration(
              isDense: true,
              hintText: '할 일 입력...',
              hintStyle: TextStyle(color: Colors.black38),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 6),
            ),
          ),
        ),
      ],
    );
  }
}

/// Popup to change a sticky's color.
class _ColorMenu extends ConsumerWidget {
  const _ColorMenu({required this.stickyId, required this.current});

  final String stickyId;
  final int current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<int>(
      tooltip: '색상 변경',
      icon: const Icon(Icons.palette_outlined, size: 18, color: Colors.black54),
      onSelected: (int i) =>
          ref.read(stickyRepositoryProvider).setStickyColor(stickyId, i),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
        for (int i = 0; i < StickyColors.palette.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Row(
              children: <Widget>[
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: StickyColors.at(i),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black26),
                  ),
                ),
                const SizedBox(width: 10),
                if (i == current)
                  const Icon(Icons.check, size: 16)
                else
                  const SizedBox(width: 16),
              ],
            ),
          ),
      ],
    );
  }
}
