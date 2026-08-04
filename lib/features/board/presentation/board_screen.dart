import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/platform_utils.dart';
import '../../../core/title_dialog.dart';
import '../../../data/local/database.dart';
import '../../sticky/application/sticky_window.dart';
import '../../sticky/presentation/sticky_toolbar.dart';
import '../../widget/widget_service.dart';
import '../application/board_providers.dart';
import 'widgets/sticky_note_card.dart';

/// Entry screen: the sticky board. Desktop shows a compact title list inside
/// the sticky window chrome; mobile shows full editable cards.
class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key});

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On resume, apply any todos the user completed from the widget while the
    // app was in the background.
    if (state == AppLifecycleState.resumed) {
      final List<StickyWithTodos>? board = ref
          .read(boardStreamProvider)
          .valueOrNull;
      if (board != null) {
        WidgetService.sync(board, ref.read(stickyRepositoryProvider));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep the home / lock screen widget in sync while the board is open.
    ref.watch(widgetSyncProvider);
    if (isDesktop) return const _DesktopBoard();
    return const _MobileBoard();
  }
}

class _MobileBoard extends StatelessWidget {
  const _MobileBoard();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('stiko'),
        actions: <Widget>[
          IconButton(
            tooltip: '휴지통',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => context.push(StikoRoutes.trash),
          ),
          IconButton(
            tooltip: '설정',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(StikoRoutes.settings),
          ),
        ],
      ),
      body: const _BoardBody(),
      floatingActionButton: const _AddStickyButton(),
    );
  }
}

class _DesktopBoard extends ConsumerWidget {
  const _DesktopBoard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool collapsed = ref.watch(
      stickyWindowControllerProvider.select((s) => s.collapsed),
    );

    return Scaffold(
      body: Column(
        children: <Widget>[
          const StickyToolbar(),
          if (!collapsed) const Expanded(child: _BoardBody()),
        ],
      ),
      floatingActionButton: collapsed
          ? null
          : const _AddStickyButton(small: true),
    );
  }
}

class _AddStickyButton extends ConsumerWidget {
  const _AddStickyButton({this.small = false});

  final bool small;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> add() async {
      final String? title = await _promptTitle(context);
      if (title == null) return;
      await ref.read(stickyRepositoryProvider).addSticky(title: title);
    }

    if (small) {
      return FloatingActionButton.small(
        onPressed: add,
        child: const Icon(Icons.add),
      );
    }
    return FloatingActionButton.extended(
      onPressed: add,
      icon: const Icon(Icons.add),
      label: const Text('스티커'),
    );
  }
}

/// Asks for a sticky title. Returns null if cancelled.
Future<String?> _promptTitle(BuildContext context) {
  return showTitleDialog(
    context,
    title: '새 스티커',
    hint: '예: 오늘 할 일',
    confirmLabel: '만들기',
  );
}

class _BoardBody extends ConsumerStatefulWidget {
  const _BoardBody();

  @override
  ConsumerState<_BoardBody> createState() => _BoardBodyState();
}

class _BoardBodyState extends ConsumerState<_BoardBody> {
  // Optimistic order: the just-dragged order is kept until the stream catches
  // up, so a reorder does not flicker back to the old order.
  List<StickyWithTodos>? _order;

  List<StickyWithTodos> _reconcile(List<StickyWithTodos> board) {
    final List<StickyWithTodos>? prev = _order;
    final Map<String, StickyWithTodos> byId = <String, StickyWithTodos>{
      for (final StickyWithTodos s in board) s.sticky.id: s,
    };
    if (prev == null ||
        prev.length != board.length ||
        prev.any((StickyWithTodos s) => !byId.containsKey(s.sticky.id))) {
      // First build, or stickers added / removed: adopt the stream order.
      return _order = List<StickyWithTodos>.of(board);
    }
    // Same stickers: keep the local order but refresh each item's data.
    return _order = <StickyWithTodos>[
      for (final StickyWithTodos s in prev) byId[s.sticky.id]!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final boardAsync = ref.watch(boardStreamProvider);

    return boardAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('불러오지 못했습니다\n$error', textAlign: TextAlign.center),
        ),
      ),
      data: (board) {
        if (board.isEmpty) {
          _order = null;
          return const _EmptyBoard();
        }
        final List<StickyWithTodos> items = _reconcile(board);
        return ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          buildDefaultDragHandles: false,
          itemCount: items.length,
          onReorderItem: (int oldIndex, int newIndex) {
            setState(() {
              final StickyWithTodos moved = items.removeAt(oldIndex);
              items.insert(newIndex, moved);
            });
            ref
                .read(stickyRepositoryProvider)
                .reorderStickies(
                  items.map((StickyWithTodos e) => e.sticky).toList(),
                );
          },
          proxyDecorator:
              (Widget child, int index, Animation<double> animation) {
                // Drag just the rounded card: the default decorator adds a boxy
                // Material shadow that bleeds past the card's corners.
                return AnimatedBuilder(
                  animation: animation,
                  child: child,
                  builder: (BuildContext context, Widget? inner) {
                    final double t = Curves.easeInOut.transform(
                      animation.value,
                    );
                    return Transform.scale(
                      scale: 1 + 0.03 * t,
                      child: Material(
                        type: MaterialType.transparency,
                        child: inner,
                      ),
                    );
                  },
                );
              },
          itemBuilder: (BuildContext context, int index) {
            final StickyWithTodos item = items[index];
            if (isDesktop) {
              return Padding(
                key: ValueKey<String>('sticky-${item.sticky.id}'),
                padding: const EdgeInsets.only(bottom: 12),
                child: StickyTitleRow(
                  data: item,
                  dragHandle: Tooltip(
                    message: '순서 이동',
                    child: ReorderableDragStartListener(
                      key: ValueKey<String>('sticky-drag-${item.sticky.id}'),
                      index: index,
                      child: const MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 10,
                          ),
                          child: Icon(
                            Icons.drag_indicator,
                            size: 18,
                            color: Colors.black38,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            return ReorderableDelayedDragStartListener(
              key: ValueKey<String>('sticky-${item.sticky.id}'),
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: StickyTitleRow(data: item),
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.sticky_note_2_outlined,
                        size: 56,
                        color: scheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '스티커가 없습니다',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '+ 를 눌러 첫 스티커를 만들어 보세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.outline),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }
}
