import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stiko/features/sticky/application/sticky_window.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('메인 창이 자식 창에서 받은 마지막 위치를 저장한다', () async {
    final dynamic result =
        await StickyWindowPositionStore.handleMainWindowMethod(
          const MethodCall(
            StickyWindowPositionStore.syncMethod,
            <String, Object>{'stickyId': 'sticky-1', 'left': 640.5, 'top': 180},
          ),
        );

    expect(result, isTrue);
    expect(
      await StickyWindowPositionStore.load('sticky-1'),
      const Offset(640.5, 180),
    );
  });

  test('자식 창이 저장한 위치를 메인 창 채널로 전달한다', () async {
    const MethodChannel windowsChannel = MethodChannel(
      'mixin.one/desktop_multi_window',
    );
    const MethodChannel syncChannel = MethodChannel(
      'mixin.one/desktop_multi_window/channels',
    );
    final List<MethodCall> syncCalls = <MethodCall>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowsChannel, (MethodCall call) async {
          if (call.method != 'getAllWindows') return null;
          return <Map<String, Object>>[
            <String, Object>{'windowId': 'main', 'windowArgument': ''},
            <String, Object>{
              'windowId': 'child',
              'windowArgument': '{"stickyId":"sticky-1"}',
            },
          ];
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(syncChannel, (MethodCall call) async {
          syncCalls.add(call);
          return true;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(windowsChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(syncChannel, null);
    });

    await StickyWindowPositionStore.saveAndSyncToMain(
      'sticky-1',
      const Offset(700, 240),
    );

    final MethodCall invokeCall = syncCalls.singleWhere(
      (MethodCall call) => call.method == 'invokeMethod',
    );
    final Map<Object?, Object?> arguments =
        invokeCall.arguments as Map<Object?, Object?>;
    expect(arguments['channel'], 'mixin.one/window_controller/main');
    expect(arguments['method'], StickyWindowPositionStore.syncMethod);
    expect(arguments['arguments'], <String, Object>{
      'stickyId': 'sticky-1',
      'left': 700.0,
      'top': 240.0,
    });
  });
}
