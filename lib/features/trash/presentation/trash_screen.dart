import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../data/local/database.dart';
import '../../board/application/board_providers.dart';

/// Soft-deleted stickies can be restored or permanently removed here.
class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double leftInset = defaultTargetPlatform == TargetPlatform.macOS
        ? 72
        : 0;
    final AsyncValue<List<StickyWithTodos>> trash = ref.watch(
      trashStreamProvider,
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leadingWidth: leftInset + 44,
        leading: Padding(
          padding: EdgeInsets.only(left: leftInset),
          child: const BackButton(),
        ),
        title: const Text('휴지통', style: TextStyle(fontSize: 17)),
      ),
      body: trash.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('휴지통을 불러오지 못했습니다\n$error'),
          ),
        ),
        data: (List<StickyWithTodos> items) => items.isEmpty
            ? const _EmptyTrash()
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (BuildContext context, int index) =>
                    _TrashItem(data: items[index]),
              ),
      ),
    );
  }
}

class _TrashItem extends ConsumerWidget {
  const _TrashItem({required this.data});

  final StickyWithTodos data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Sticky sticky = data.sticky;
    final String title = sticky.title.trim().isEmpty ? '새 스티커' : sticky.title;
    final String todoSummary = data.todos.isEmpty
        ? '할 일 없음'
        : '할 일 ${data.todos.length}개';

    return Card(
      key: ValueKey<String>('trash-${sticky.id}'),
      color: StickyColors.surface(sticky.colorIndex, sticky.opacity),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(todoSummary),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              tooltip: '복원',
              icon: const Icon(Icons.restore),
              onPressed: () => _restore(context, ref, sticky),
            ),
            IconButton(
              tooltip: '영구 삭제',
              icon: Icon(
                Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => _deleteForever(context, ref, sticky),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    Sticky sticky,
  ) async {
    await ref.read(stickyRepositoryProvider).restoreSticky(sticky.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('스티커를 복원했습니다.')));
  }

  Future<void> _deleteForever(
    BuildContext context,
    WidgetRef ref,
    Sticky sticky,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('스티커를 영구 삭제할까요?'),
            content: const Text('스티커와 모든 할 일이 완전히 삭제되며 되돌릴 수 없습니다.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('영구 삭제'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await ref.read(stickyRepositoryProvider).deleteSticky(sticky.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('스티커를 영구 삭제했습니다.')));
  }
}

class _EmptyTrash extends StatelessWidget {
  const _EmptyTrash();

  @override
  Widget build(BuildContext context) {
    final Color outline = Theme.of(context).colorScheme.outline;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.delete_outline, size: 56, color: outline),
          const SizedBox(height: 12),
          Text('휴지통이 비어 있습니다', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('삭제한 스티커가 여기에 보입니다.', style: TextStyle(color: outline)),
        ],
      ),
    );
  }
}
