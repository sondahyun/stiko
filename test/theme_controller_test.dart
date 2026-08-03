import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stiko/app/application/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('기본값은 시스템 모드다', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  test('setMode가 테마 모드를 바꾸고 유지한다', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);

    expect(container.read(themeModeProvider), ThemeMode.dark);
  });
}
