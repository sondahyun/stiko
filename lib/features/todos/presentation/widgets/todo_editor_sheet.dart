import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../data/local/database.dart';
import '../../application/todo_providers.dart';

/// Opens the add / edit bottom sheet. Pass [initial] to edit an existing todo.
Future<void> showTodoEditor(BuildContext context, {Todo? initial}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => TodoEditorSheet(initial: initial),
  );
}

/// Bottom sheet for creating a new todo or editing an existing one.
class TodoEditorSheet extends ConsumerStatefulWidget {
  const TodoEditorSheet({super.key, this.initial});

  final Todo? initial;

  @override
  ConsumerState<TodoEditorSheet> createState() => _TodoEditorSheetState();
}

class _TodoEditorSheetState extends ConsumerState<TodoEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late int _colorIndex;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initial?.title ?? '');
    _noteController = TextEditingController(text: widget.initial?.note ?? '');
    _colorIndex = widget.initial?.colorIndex ?? 0;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String title = _titleController.text.trim();
    if (title.isEmpty) return;
    final String note = _noteController.text.trim();
    final repo = ref.read(todoRepositoryProvider);

    if (_isEditing) {
      await repo.editTodo(
        widget.initial!.id,
        title: title,
        note: note,
        colorIndex: _colorIndex,
      );
    } else {
      await repo.addTodo(
        title: title,
        note: note.isEmpty ? null : note,
        colorIndex: _colorIndex,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: 20 + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _isEditing ? '할 일 편집' : '새 할 일',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: '제목',
              hintText: '무엇을 할까요?',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '메모 (선택)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          _ColorPicker(
            selected: _colorIndex,
            onSelected: (index) => setState(() => _colorIndex = index),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: Text(_isEditing ? '저장' : '추가'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        for (int i = 0; i < StickyColors.palette.length; i++)
          GestureDetector(
            onTap: () => onSelected(i),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: StickyColors.at(i),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected == i ? Colors.black87 : Colors.black26,
                  width: selected == i ? 2.5 : 1,
                ),
              ),
              child: selected == i
                  ? const Icon(Icons.check, size: 18, color: Colors.black87)
                  : null,
            ),
          ),
      ],
    );
  }
}
