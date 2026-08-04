import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/local/database.dart' show Todo;

/// An inline-editable to-do row used by a standalone sticky window.
class StickyWindowTodoLine extends StatefulWidget {
  const StickyWindowTodoLine({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Todo todo;
  final Future<void> Function(bool isDone) onToggle;
  final Future<void> Function(String content) onEdit;
  final Future<void> Function() onDelete;

  @override
  State<StickyWindowTodoLine> createState() => _StickyWindowTodoLineState();
}

class _StickyWindowTodoLineState extends State<StickyWindowTodoLine> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  late String _lastCommittedContent;

  @override
  void initState() {
    super.initState();
    _lastCommittedContent = widget.todo.content;
    _controller = TextEditingController(text: widget.todo.content);
    _focus = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant StickyWindowTodoLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.todo.id != widget.todo.id) {
      _replaceText(widget.todo.content);
      _lastCommittedContent = widget.todo.content;
      return;
    }
    if (!_focus.hasFocus && oldWidget.todo.content != widget.todo.content) {
      _replaceText(widget.todo.content);
      _lastCommittedContent = widget.todo.content;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _replaceText(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) unawaited(_commit());
  }

  Future<void> _commit() async {
    final String content = _controller.text.trim();
    if (content == _lastCommittedContent) return;

    final String previous = _lastCommittedContent;
    _lastCommittedContent = content;
    if (_controller.text != content) _replaceText(content);
    try {
      if (content.isEmpty) {
        await widget.onDelete();
      } else {
        await widget.onEdit(content);
      }
    } catch (error) {
      _lastCommittedContent = previous;
      debugPrint('Failed to edit sticky to-do: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Checkbox(
          value: widget.todo.isDone,
          onChanged: (bool? value) =>
              unawaited(widget.onToggle(value ?? false)),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: const BorderSide(color: Colors.black45),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: TextField(
            key: ValueKey<String>('sticky-todo-editor-${widget.todo.id}'),
            controller: _controller,
            focusNode: _focus,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => unawaited(_commit()),
            style: TextStyle(
              color: Colors.black87,
              decoration: widget.todo.isDone
                  ? TextDecoration.lineThrough
                  : null,
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
