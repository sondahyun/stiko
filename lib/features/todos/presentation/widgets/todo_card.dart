import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../data/local/database.dart';

/// A single todo rendered as a colored sticky note.
///
/// Swipe from right to left to delete, tap the body to edit, tap the checkbox
/// to toggle completion.
class TodoCard extends StatelessWidget {
  const TodoCard({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
  });

  final Todo todo;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final Color color = StickyColors.at(todo.colorIndex);
    const Color textColor = Colors.black87;
    final bool hasNote = todo.note != null && todo.note!.trim().isNotEmpty;

    return Dismissible(
      key: ValueKey<String>(todo.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Checkbox(
                  value: todo.isDone,
                  onChanged: (value) => onToggle(value ?? false),
                  shape: const CircleBorder(),
                  side: const BorderSide(color: textColor, width: 1.5),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        todo.title,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.3,
                          color: textColor,
                          decoration: todo.isDone
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: textColor,
                        ),
                      ),
                      if (hasNote)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            todo.note!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: textColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
