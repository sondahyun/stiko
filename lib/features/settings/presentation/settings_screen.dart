import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/application/theme_controller.dart';
import '../../../app/theme.dart';
import '../../../data/local/database.dart';
import '../../auth/application/auth_providers.dart';
import '../../board/application/board_providers.dart';
import '../../widget/widget_settings.dart';

/// App settings: account, theme mode selection, and basic app info.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode mode = ref.watch(themeModeProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final email = ref.watch(authStateProvider).valueOrNull?.email;

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: <Widget>[
          const _SectionHeader('계정'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(email ?? '로그인 정보 없음'),
          ),
          ListTile(
            leading: Icon(Icons.logout, color: scheme.error),
            title: Text('로그아웃', style: TextStyle(color: scheme.error)),
            onTap: () => ref.read(authServiceProvider).signOut(),
          ),
          const Divider(),
          const _SectionHeader('테마'),
          _ThemeTile(label: '시스템 설정 따르기', value: ThemeMode.system, current: mode),
          _ThemeTile(label: '라이트', value: ThemeMode.light, current: mode),
          _ThemeTile(label: '다크', value: ThemeMode.dark, current: mode),
          const Divider(),
          const _SectionHeader('위젯에 표시할 스티커'),
          const _WidgetStickerSection(),
          const Divider(),
          const ListTile(
            title: Text('stiko'),
            subtitle: Text('버전 1.0.0'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _ThemeTile extends ConsumerWidget {
  const _ThemeTile({
    required this.label,
    required this.value,
    required this.current,
  });

  final String label;
  final ThemeMode value;
  final ThemeMode current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool selected = value == current;
    return ListTile(
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () => ref.read(themeModeProvider.notifier).setMode(value),
    );
  }
}

/// Lets the user pick which stickers the widget shows. No selection shows all.
class _WidgetStickerSection extends ConsumerWidget {
  const _WidgetStickerSection();

  static String _label(StickyWithTodos item) {
    if (item.sticky.title.trim().isNotEmpty) return item.sticky.title;
    if (item.todos.isNotEmpty) return item.todos.first.content;
    return '새 스티커';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Set<String> selection = ref.watch(widgetStickerSelectionProvider);
    final AsyncValue<List<StickyWithTodos>> boardAsync =
        ref.watch(boardStreamProvider);

    return boardAsync.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (List<StickyWithTodos> board) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              '선택한 스티커의 할 일만 위젯에 보여요. 아무것도 선택하지 않으면 전체가 표시됩니다.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          if (board.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text('스티커가 없습니다'),
            ),
          for (final StickyWithTodos item in board)
            CheckboxListTile(
              value: selection.contains(item.sticky.id),
              onChanged: (_) => ref
                  .read(widgetStickerSelectionProvider.notifier)
                  .toggle(item.sticky.id),
              secondary: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: StickyColors.at(item.sticky.colorIndex),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black26),
                ),
              ),
              title: Text(
                _label(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
