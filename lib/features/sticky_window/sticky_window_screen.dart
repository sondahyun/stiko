import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../app/theme.dart';
import '../../data/firestore_sticky_repository.dart';
import '../../data/local/database.dart' show StickyWithTodos, Todo;

/// Root widget of a standalone sticky window (one OS window per sticky).
class StickyWindowRoot extends StatelessWidget {
  const StickyWindowRoot({
    super.key,
    required this.windowId,
    required this.stickyId,
    required this.uid,
  });

  final int windowId;
  final String stickyId;
  final String uid;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: StikoTheme.light(),
      darkTheme: StikoTheme.dark(),
      home: StickyWindowScreen(
        windowId: windowId,
        stickyId: stickyId,
        uid: uid,
      ),
    );
  }
}

/// A single sticky's checklist in its own window: title bar (drag to move,
/// double-tap to collapse), pin (always on top), collapse / expand, and close.
class StickyWindowScreen extends StatefulWidget {
  const StickyWindowScreen({
    super.key,
    required this.windowId,
    required this.stickyId,
    required this.uid,
  });

  final int windowId;
  final String stickyId;
  final String uid;

  @override
  State<StickyWindowScreen> createState() => _StickyWindowScreenState();
}

class _StickyWindowScreenState extends State<StickyWindowScreen> {
  late final FirestoreStickyRepository _repo;
  late final Stream<StickyWithTodos?> _stickyStream;
  final TextEditingController _addController = TextEditingController();
  final FocusNode _addFocus = FocusNode();

  static const double _barHeight = 44;
  bool _collapsed = false;
  bool _pinned = false;
  bool _resizing = false;
  double _expandedHeight = 360;

  @override
  void initState() {
    super.initState();
    _repo = FirestoreStickyRepository(uid: widget.uid);
    _stickyStream = _repo.watchSticky(widget.stickyId);
  }

  @override
  void dispose() {
    _addController.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final String text = _addController.text.trim();
    if (text.isEmpty) return;
    _addController.clear();
    await _repo.addTodo(widget.stickyId, text);
    if (mounted) _addFocus.requestFocus();
  }

  Future<void> _togglePin() async {
    final bool next = !_pinned;
    setState(() => _pinned = next);
    await windowManager.setAlwaysOnTop(next);
  }

  Future<void> _toggleCollapse() async {
    // Guard against overlapping calls (collapse button + toolbar double-tap
    // firing together) that would desync window size and _collapsed state.
    if (_resizing) return;
    _resizing = true;
    try {
      final Size size = await windowManager.getSize();
      if (!_collapsed) {
        if (size.height > _barHeight + 20) _expandedHeight = size.height;
        await windowManager.setSize(Size(size.width, _barHeight));
        if (mounted) setState(() => _collapsed = true);
      } else {
        await windowManager.setSize(Size(size.width, _expandedHeight));
        if (mounted) setState(() => _collapsed = false);
      }
    } finally {
      _resizing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<StickyWithTodos?>(
        stream: _stickyStream,
        builder: (BuildContext context, AsyncSnapshot<StickyWithTodos?> snap) {
          final StickyWithTodos? data = snap.data;
          final Color color = StickyColors.at(data?.sticky.colorIndex ?? 0);
          final String title =
              (data != null && data.sticky.title.trim().isNotEmpty)
                  ? data.sticky.title
                  : '새 스티커';
          return Container(
            color: color,
            child: Column(
              children: <Widget>[
                _toolbar(title),
                if (!_collapsed)
                  Expanded(
                    child: !snap.hasData
                        ? const Center(child: CircularProgressIndicator())
                        : data == null
                            ? const Center(child: Text('스티커가 삭제되었습니다'))
                            : _todoList(data),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _toolbar(String title) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: _toggleCollapse,
      child: Container(
        height: _barHeight,
        color: Colors.black.withValues(alpha: 0.06),
        padding: EdgeInsets.only(
          left: defaultTargetPlatform == TargetPlatform.macOS ? 88 : 12,
          right: 4,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            IconButton(
              tooltip: _pinned ? '항상 위 해제' : '항상 위 고정',
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                _pinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: _pinned ? const Color(0xFF6E5E17) : Colors.black54,
              ),
              onPressed: _togglePin,
            ),
            IconButton(
              tooltip: _collapsed ? '펴기' : '접기',
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                _collapsed ? Icons.unfold_more : Icons.unfold_less,
                color: Colors.black54,
              ),
              onPressed: _toggleCollapse,
            ),
            IconButton(
              tooltip: '닫기',
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, color: Colors.black54),
              onPressed: () => WindowController.fromWindowId(widget.windowId).close(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _todoList(StickyWithTodos data) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 12),
      children: <Widget>[
        for (final Todo t in data.todos)
          Row(
            children: <Widget>[
              Checkbox(
                value: t.isDone,
                onChanged: (bool? v) => _repo.toggleTodo(t.id, v ?? false),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: const BorderSide(color: Colors.black45),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  t.content,
                  style: TextStyle(
                    color: Colors.black87,
                    decoration: t.isDone ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.black45,
                  ),
                ),
              ),
            ],
          ),
        Row(
          children: <Widget>[
            const SizedBox(
              width: 40,
              child: Icon(Icons.add, size: 18, color: Colors.black38),
            ),
            Expanded(
              child: TextField(
                controller: _addController,
                focusNode: _addFocus,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '할 일 입력...',
                  hintStyle: TextStyle(color: Colors.black38),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
