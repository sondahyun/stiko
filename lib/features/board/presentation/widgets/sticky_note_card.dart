import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:screen_retriever/screen_retriever.dart';

import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../core/platform_utils.dart';
import '../../../../data/local/database.dart';
import '../../../../data/sticky_repository.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/board_providers.dart';

/// Tracks which sticky is shown in which window so duplicates never open.
final Map<String, int> _openStickyWindows = <String, int>{};
final Set<String> _openingStickies = <String>{};

/// Opens a sticky: on desktop in its own floating window, on mobile by
/// navigating to a full-screen detail page.
void openSticky(BuildContext context, WidgetRef ref, String stickyId) {
  if (isDesktop) {
    openStickyWindow(ref, stickyId);
  } else {
    context.push(StikoRoutes.stickyPath(stickyId));
  }
}

/// Opens the given sticky in its own floating desktop window. If one is already
/// open for the sticky, brings it to the front instead of creating a duplicate.
Future<void> openStickyWindow(WidgetRef ref, String stickyId) async {
  if (_openingStickies.contains(stickyId)) return;
  _openingStickies.add(stickyId);
  try {
    final List<int> openIds = await DesktopMultiWindow.getAllSubWindowIds();
    final int? existing = _openStickyWindows[stickyId];
    if (existing != null && openIds.contains(existing)) {
      await WindowController.fromWindowId(existing).show();
      return;
    }
    final String uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    final WindowController window = await DesktopMultiWindow.createWindow(
      jsonEncode(<String, String>{'stickyId': stickyId, 'uid': uid}),
    );
    _openStickyWindows[stickyId] = window.windowId;
    const Size winSize = Size(300, 360);
    await window.setFrame(await _stickyWindowFrame(winSize, openIds.length));
    await window.setTitle('stiko');
    await window.show();
  } finally {
    _openingStickies.remove(stickyId);
  }
}

/// Places a new sticky window near the top-right of the primary display, with a
/// small cascade so multiple windows stay visible instead of stacking exactly.
///
/// macOS positions windows from a bottom-left origin (Cocoa), so a larger `top`
/// sits higher on screen; Windows and Linux use a top-left origin.
Future<Rect> _stickyWindowFrame(Size size, int cascadeIndex) async {
  const double margin = 24;
  const double step = 30;
  final double cascade = (cascadeIndex % 5) * step;
  try {
    final Display display = await screenRetriever.getPrimaryDisplay();
    final Size screen = display.size;
    final double left = screen.width - size.width - margin - cascade;
    final double top = defaultTargetPlatform == TargetPlatform.macOS
        ? screen.height - size.height - 44 - margin - cascade
        : margin + cascade;
    return Offset(left < 0 ? margin : left, top < 0 ? margin : top) & size;
  } catch (_) {
    return const Offset(500, 120) & size;
  }
}

/// Compact list row: shows the sticky's label (title, or its first to-do) and
/// progress. Tapping opens the sticky (a window on desktop, a page on mobile).
class StickyTitleRow extends ConsumerWidget {
  const StickyTitleRow({super.key, required this.data});

  final StickyWithTodos data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Composite over white so a transparent sticky reads as a plain card
    // rather than a black one on mobile, where nothing sits behind it.
    final Color surface =
        Color.alphaBlend(StickyColors.at(data.sticky.colorIndex), Colors.white);
    final bool hasTitle = data.sticky.title.trim().isNotEmpty;
    final String label = hasTitle
        ? data.sticky.title
        : (data.todos.isNotEmpty ? data.todos.first.content : '새 스티커');
    // Preview one to-do under the label; skip the first if it became the label.
    final List<Todo> previewTodos = hasTitle
        ? data.todos
        : (data.todos.length > 1 ? data.todos.sublist(1) : <Todo>[]);
    final String? previewLine =
        previewTodos.isNotEmpty ? previewTodos.first.content : null;
    final bool hasMore = previewTodos.length > 1;

    return Material(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openSticky(context, ref, data.sticky.id),
        // Opening a new OS window steals focus mid-tap, which can otherwise
        // leave the hover/press overlay stuck on the row. Keep it transparent.
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        focusColor: Colors.transparent,
        splashColor: Colors.black12,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (previewLine != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          previewLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    if (hasMore)
                      const Text(
                        '...',
                        style: TextStyle(color: Colors.black38, fontSize: 13),
                      ),
                  ],
                ),
              ),
              if (isDesktop)
                IconButton(
                  tooltip: '새 창으로 열기',
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.open_in_new, color: Colors.black54),
                  onPressed: () => openStickyWindow(ref, data.sticky.id),
                ),
              ColorMenu(
                stickyId: data.sticky.id,
                current: data.sticky.colorIndex,
              ),
              IconButton(
                tooltip: '스티커 삭제',
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, color: Colors.black54),
                onPressed: () =>
                    ref.read(stickyRepositoryProvider).deleteSticky(data.sticky.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single editable to-do row: a checkbox plus inline-editable text. Empty
/// text on blur deletes the to-do.
class TodoLine extends ConsumerStatefulWidget {
  const TodoLine({super.key, required this.todo});

  final Todo todo;

  @override
  ConsumerState<TodoLine> createState() => _TodoLineState();
}

class _TodoLineState extends ConsumerState<TodoLine> {
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

/// The trailing "add a to-do" row: type and submit to append a new to-do.
class AddTodoLine extends ConsumerStatefulWidget {
  const AddTodoLine({super.key, required this.stickyId});

  final String stickyId;

  @override
  ConsumerState<AddTodoLine> createState() => _AddTodoLineState();
}

class _AddTodoLineState extends ConsumerState<AddTodoLine> {
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
    if (mounted) _focus.requestFocus();
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

/// A palette popup for changing a sticky's color. The last entry is the
/// transparent option.
class ColorMenu extends ConsumerWidget {
  const ColorMenu({super.key, required this.stickyId, required this.current});

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
                if (i == StickyColors.palette.length - 1) ...<Widget>[
                  const SizedBox(width: 6),
                  const Text('투명', style: TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
