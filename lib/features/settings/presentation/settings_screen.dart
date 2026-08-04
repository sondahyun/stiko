import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/application/theme_controller.dart';
import '../../auth/application/auth_providers.dart';

/// App settings: account, theme mode selection, and basic app info.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode mode = ref.watch(themeModeProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final email = ref.watch(authStateProvider).valueOrNull?.email;

    // On macOS the window's traffic lights sit at the top-left, so inset the
    // back button and title to keep them from overlapping the close button.
    final double leftInset =
        defaultTargetPlatform == TargetPlatform.macOS ? 72 : 0;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leadingWidth: leftInset + 44,
        leading: Padding(
          padding: EdgeInsets.only(left: leftInset),
          child: const BackButton(),
        ),
        title: const Text('설정', style: TextStyle(fontSize: 17)),
      ),
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
