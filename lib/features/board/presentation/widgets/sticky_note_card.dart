import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
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
import '../../../auth/application/auth_service.dart';
import '../../../sticky/application/sticky_window.dart';
import '../../application/board_providers.dart';

final Set<String> _openingStickies = <String>{};

/// Stickies mid-navigation on mobile, so a rapid double tap does not push the
/// detail page twice (which would need two back presses to undo).
final Set<String> _navigatingStickies = <String>{};

/// Opens a sticky: on desktop in its own floating window, on mobile by
/// navigating to a full-screen detail page.
Future<void> openSticky(
  BuildContext context,
  WidgetRef ref,
  String stickyId,
) async {
  if (isDesktop) {
    await openStickyWindow(ref, stickyId);
    return;
  }
  if (_navigatingStickies.contains(stickyId)) return;
  _navigatingStickies.add(stickyId);
  Future<void>.delayed(
    const Duration(milliseconds: 600),
    () => _navigatingStickies.remove(stickyId),
  );
  await context.push(StikoRoutes.stickyPath(stickyId));
}

/// Opens the given sticky in its own floating desktop window. If one is already
/// open for the sticky, brings it to the front instead of creating a duplicate.
Future<void> openStickyWindow(WidgetRef ref, String stickyId) async {
  if (_openingStickies.contains(stickyId)) return;
  _openingStickies.add(stickyId);
  try {
    final List<WindowController> windows = await WindowController.getAll();
    WindowController? existing;
    int stickyWindowCount = 0;
    for (final WindowController window in windows) {
      final String? openStickyId = _stickyIdFromArguments(window.arguments);
      if (openStickyId != null) stickyWindowCount++;
      if (openStickyId == stickyId) existing = window;
    }
    if (existing != null) {
      await existing.show();
      await existing.invokeMethod<void>('window_focus');
      return;
    }
    final AppUser? user =
        ref.read(authStateProvider).valueOrNull ??
        ref.read(authServiceProvider).currentUser;
    if (user == null || user.uid.isEmpty) return;
    final String uid = user.uid;
    const Size winSize = Size(300, 360);
    final Offset? savedPosition = await StickyWindowPositionStore.load(
      stickyId,
    );
    final Rect frame = savedPosition == null
        ? await _stickyWindowFrame(winSize, stickyWindowCount)
        : await _restoredStickyWindowFrame(winSize, savedPosition);
    await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: jsonEncode(<String, Object>{
          'stickyId': stickyId,
          'uid': uid,
          'left': frame.left,
          'top': frame.top,
          'width': frame.width,
          'height': frame.height,
        }),
      ),
    );
  } finally {
    _openingStickies.remove(stickyId);
  }
}

/// Restores a sticky to its last closed position. If that display is no longer
/// connected, the frame is clamped into the primary display's work area.
Future<Rect> _restoredStickyWindowFrame(Size size, Offset position) async {
  try {
    List<Display> displays;
    try {
      displays = await screenRetriever.getAllDisplays();
    } catch (_) {
      displays = <Display>[await screenRetriever.getPrimaryDisplay()];
    }

    Display? display;
    for (final Display candidate in displays) {
      final Offset origin = candidate.visiblePosition ?? Offset.zero;
      final Size workArea = candidate.visibleSize ?? candidate.size;
      if ((origin & workArea).contains(position)) {
        display = candidate;
        break;
      }
    }
    display ??= await screenRetriever.getPrimaryDisplay();
    return _clampStickyWindowFrame(position, size, display, margin: 0);
  } catch (_) {
    return position & size;
  }
}

Rect _clampStickyWindowFrame(
  Offset position,
  Size size,
  Display display, {
  required double margin,
}) {
  final Offset origin = display.visiblePosition ?? Offset.zero;
  final Size workArea = display.visibleSize ?? display.size;
  final double minLeft = origin.dx + margin;
  final double minTop = origin.dy + margin;
  final double maxLeft = origin.dx + workArea.width - size.width - margin;
  final double maxTop = origin.dy + workArea.height - size.height - margin;
  return Offset(
        position.dx.clamp(minLeft, maxLeft < minLeft ? minLeft : maxLeft),
        position.dy.clamp(minTop, maxTop < minTop ? minTop : maxTop),
      ) &
      size;
}

String? _stickyIdFromArguments(String arguments) {
  if (arguments.isEmpty) return null;
  try {
    final Object? value = jsonDecode(arguments);
    if (value is! Map<String, dynamic>) return null;
    final Object? stickyId = value['stickyId'];
    return stickyId is String ? stickyId : null;
  } on FormatException {
    return null;
  }
}

/// Places a new sticky window close to the clicked card and clamps it to the
/// current display's work area. A small cascade keeps multiple windows visible.
Future<Rect> _stickyWindowFrame(Size size, int cascadeIndex) async {
  const double margin = 24;
  const double step = 30;
  final double cascade = (cascadeIndex % 5) * step;
  try {
    final Offset cursor = await screenRetriever.getCursorScreenPoint();
    List<Display> displays;
    try {
      displays = await screenRetriever.getAllDisplays();
    } catch (_) {
      displays = <Display>[await screenRetriever.getPrimaryDisplay()];
    }

    Display? display;
    for (final Display candidate in displays) {
      final Offset origin = candidate.visiblePosition ?? Offset.zero;
      final Size workArea = candidate.visibleSize ?? candidate.size;
      if ((origin & workArea).contains(cursor)) {
        display = candidate;
        break;
      }
    }
    display ??= await screenRetriever.getPrimaryDisplay();

    double left = cursor.dx + margin + cascade;
    final Offset origin = display.visiblePosition ?? Offset.zero;
    final Size workArea = display.visibleSize ?? display.size;
    final double maxLeft = origin.dx + workArea.width - size.width - margin;
    if (left > maxLeft) {
      left = cursor.dx - size.width - margin - cascade;
    }
    final double top = cursor.dy - 44 + cascade;
    return _clampStickyWindowFrame(
      Offset(left, top),
      size,
      display,
      margin: margin,
    );
  } catch (_) {
    return Offset(500 + cascade, 120 + cascade) & size;
  }
}

/// Compact list row: shows the sticky's label (title, or its first to-do) and
/// progress. Tapping opens the sticky (a window on desktop, a page on mobile).
class StickyTitleRow extends ConsumerWidget {
  const StickyTitleRow({super.key, required this.data});

  final StickyWithTodos data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Composite over white so lower opacity reads as a lighter card rather than
    // a black hole on mobile, where nothing sits behind the row.
    final Color surface = StickyColors.surface(
      data.sticky.colorIndex,
      data.sticky.opacity,
    );
    final List<Todo> ordered = completedLast(data.todos);
    final bool hasTitle = data.sticky.title.trim().isNotEmpty;
    final String label = hasTitle
        ? data.sticky.title
        : (ordered.isNotEmpty ? ordered.first.content : '새 스티커');
    // Preview one to-do under the label; skip the first if it became the label.
    final List<Todo> previewTodos = hasTitle
        ? ordered
        : (ordered.length > 1 ? ordered.sublist(1) : <Todo>[]);
    final String? previewLine = previewTodos.isNotEmpty
        ? previewTodos.first.content
        : null;
    final bool hasMore = previewTodos.length > 1;

    return Material(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey<String>('sticky-card-${data.sticky.id}'),
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
              IconButton(
                tooltip: '스티커 삭제',
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, color: Colors.black54),
                onPressed: () => ref
                    .read(stickyRepositoryProvider)
                    .deleteSticky(data.sticky.id),
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
          onChanged: (bool? v) => ref
              .read(stickyRepositoryProvider)
              .toggleTodo(widget.todo.id, v ?? false),
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
/// Opens the color + opacity editor for a sticky as a bottom sheet.
Future<void> showStickyStyle(
  BuildContext context,
  WidgetRef ref, {
  required String stickyId,
  required int colorIndex,
  required double opacity,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext ctx) => _StickyStyleSheet(
      stickyId: stickyId,
      colorIndex: colorIndex,
      opacity: opacity,
    ),
  );
}

/// A palette icon that opens the color + opacity editor.
class StickyStyleButton extends ConsumerWidget {
  const StickyStyleButton({
    super.key,
    required this.stickyId,
    required this.colorIndex,
    required this.opacity,
  });

  final String stickyId;
  final int colorIndex;
  final double opacity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: '색상 / 투명도',
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.palette_outlined, color: Colors.black54),
      onPressed: () => showStickyStyle(
        context,
        ref,
        stickyId: stickyId,
        colorIndex: colorIndex,
        opacity: opacity,
      ),
    );
  }
}

/// Bottom sheet: the 6 palette colors plus an opacity slider that applies to
/// whichever color is chosen.
class _StickyStyleSheet extends ConsumerStatefulWidget {
  const _StickyStyleSheet({
    required this.stickyId,
    required this.colorIndex,
    required this.opacity,
  });

  final String stickyId;
  final int colorIndex;
  final double opacity;

  @override
  ConsumerState<_StickyStyleSheet> createState() => _StickyStyleSheetState();
}

class _StickyStyleSheetState extends ConsumerState<_StickyStyleSheet> {
  late double _opacity = widget.opacity;
  late int _colorIndex = widget.colorIndex;

  @override
  Widget build(BuildContext context) {
    final StickyRepository repo = ref.read(stickyRepositoryProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('색상', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: <Widget>[
                for (int i = 0; i < StickyColors.palette.length; i++)
                  GestureDetector(
                    onTap: () {
                      setState(() => _colorIndex = i);
                      repo.setStickyColor(widget.stickyId, i);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: StickyColors.at(i),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: i == _colorIndex
                              ? Colors.black87
                              : Colors.black26,
                          width: i == _colorIndex ? 2.5 : 1,
                        ),
                      ),
                      child: i == _colorIndex
                          ? const Icon(
                              Icons.check,
                              size: 18,
                              color: Colors.black87,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                const Text(
                  '투명도',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${(_opacity * 100).round()}%',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
            Slider(
              value: _opacity,
              min: StickyColors.minOpacity,
              max: 1.0,
              onChanged: (double v) => setState(() => _opacity = v),
              onChangeEnd: (double v) =>
                  repo.setStickyOpacity(widget.stickyId, v),
            ),
          ],
        ),
      ),
    );
  }
}
