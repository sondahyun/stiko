import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../data/local/database.dart';
import '../application/board_providers.dart';
import 'widgets/sticky_note_card.dart';

/// Full-screen view of a single sticky's checklist. Used on mobile, where a
/// sticky opens as a page instead of a separate desktop window.
class StickyDetailScreen extends ConsumerWidget {
  const StickyDetailScreen({super.key, required this.stickyId});

  final String stickyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<StickyWithTodos>> boardAsync =
        ref.watch(boardStreamProvider);

    return boardAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('불러오지 못했습니다\n$error')),
      ),
      data: (List<StickyWithTodos> board) {
        StickyWithTodos? data;
        for (final StickyWithTodos e in board) {
          if (e.sticky.id == stickyId) {
            data = e;
            break;
          }
        }
        if (data == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('스티커가 삭제되었습니다')),
          );
        }

        final Sticky sticky = data.sticky;
        final Color color = StickyColors.at(sticky.colorIndex);
        // Composite over white so a transparent sticky shows as a white page
        // instead of an unreadable black one (there is nothing behind on mobile).
        final Color surface = Color.alphaBlend(color, Colors.white);
        final String title =
            sticky.title.trim().isNotEmpty ? sticky.title : '새 스티커';

        return Scaffold(
          backgroundColor: surface,
          appBar: AppBar(
            backgroundColor: surface,
            foregroundColor: Colors.black87,
            title: Text(title),
            actions: <Widget>[
              IconButton(
                tooltip: '제목 변경',
                icon: const Icon(Icons.edit_outlined, color: Colors.black54),
                onPressed: () => _renameSticky(context, ref, sticky),
              ),
              ColorMenu(stickyId: sticky.id, current: sticky.colorIndex),
              IconButton(
                tooltip: '스티커 삭제',
                icon: const Icon(Icons.delete_outline, color: Colors.black54),
                onPressed: () {
                  ref.read(stickyRepositoryProvider).deleteSticky(sticky.id);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 24),
            children: <Widget>[
              for (final Todo todo in data.todos)
                TodoLine(key: ValueKey<String>(todo.id), todo: todo),
              AddTodoLine(stickyId: sticky.id),
            ],
          ),
        );
      },
    );
  }

  Future<void> _renameSticky(
    BuildContext context,
    WidgetRef ref,
    Sticky sticky,
  ) async {
    final TextEditingController controller =
        TextEditingController(text: sticky.title);
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
    if (result != null) {
      await ref.read(stickyRepositoryProvider).setStickyTitle(sticky.id, result);
    }
  }
}
