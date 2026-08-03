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

  Future<void> _rename(String current) async {
    final TextEditingController controller =
        TextEditingController(text: current);
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('제목 변경'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: '제목',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (String v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) await _repo.setStickyTitle(widget.stickyId, result);
  }

  Future<void> _showStyle(int colorIndex, double opacity) {
    int localColor = colorIndex;
    double localOpacity = opacity;
    return showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setSheet) => AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
          content: SizedBox(
            width: 260,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('색상',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    for (int i = 0; i < StickyColors.palette.length; i++)
                      GestureDetector(
                        onTap: () {
                          setSheet(() => localColor = i);
                          _repo.setStickyColor(widget.stickyId, i);
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: StickyColors.at(i),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: i == localColor
                                  ? Colors.black87
                                  : Colors.black26,
                              width: i == localColor ? 2.5 : 1,
                            ),
                          ),
                          child: i == localColor
                              ? const Icon(Icons.check,
                                  size: 15, color: Colors.black87)
                              : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    const Text('투명도',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('${(localOpacity * 100).round()}%',
                        style: const TextStyle(color: Colors.black54)),
                  ],
                ),
                Slider(
                  value: localOpacity,
                  min: StickyColors.minOpacity,
                  max: 1.0,
                  onChanged: (double v) => setSheet(() => localOpacity = v),
                  onChangeEnd: (double v) =>
                      _repo.setStickyOpacity(widget.stickyId, v),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<StickyWithTodos?>(
        stream: _stickyStream,
        builder: (BuildContext context, AsyncSnapshot<StickyWithTodos?> snap) {
          final StickyWithTodos? data = snap.data;
          final int colorIndex = data?.sticky.colorIndex ?? 0;
          final double opacity = data?.sticky.opacity ?? 1.0;
          final String rawTitle = data?.sticky.title ?? '';
          // Opaque "frosted" look: lower opacity blends the pastel toward white
          // for a soft, readable card. (A truly see-through window rendered
          // dark and let clicks fall through, so we keep it opaque.)
          final Color color = StickyColors.surface(colorIndex, opacity);
          final String title =
              rawTitle.trim().isNotEmpty ? rawTitle : '새 스티커';
          return Container(
            color: color,
            child: Column(
              children: <Widget>[
                _toolbar(title, rawTitle, colorIndex, opacity),
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

  Widget _toolbar(
    String title,
    String rawTitle,
    int colorIndex,
    double opacity,
  ) {
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
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _rename(rawTitle),
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
            ),
            IconButton(
              tooltip: '색상 / 투명도',
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.palette_outlined, color: Colors.black54),
              onPressed: () => _showStyle(colorIndex, opacity),
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
