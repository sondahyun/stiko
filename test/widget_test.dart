import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stiko/app/app.dart';
import 'package:stiko/core/app_zoom.dart';
import 'package:stiko/data/local/database.dart';
import 'package:stiko/data/sticky_repository.dart';
import 'package:stiko/features/auth/application/auth_providers.dart';
import 'package:stiko/features/auth/application/auth_service.dart';
import 'package:stiko/features/board/application/board_providers.dart';
import 'package:stiko/features/board/presentation/sticky_detail_screen.dart';
import 'package:stiko/features/board/presentation/widgets/sticky_note_card.dart';
import 'package:stiko/features/sticky/application/sticky_window.dart';
import 'package:stiko/features/trash/presentation/trash_screen.dart';

Sticky _sticky({
  String id = 's1',
  int colorIndex = 0,
  String title = '',
  double opacity = 1.0,
}) {
  final DateTime now = DateTime(2026, 1, 1);
  return Sticky(
    id: id,
    title: title,
    colorIndex: colorIndex,
    opacity: opacity,
    sortOrder: 0,
    createdAt: now,
    updatedAt: now,
  );
}

Todo _todo({
  String id = 't1',
  String stickyId = 's1',
  String content = '할 일',
  bool isDone = false,
}) {
  final DateTime now = DateTime(2026, 1, 1);
  return Todo(
    id: id,
    stickyId: stickyId,
    content: content,
    isDone: isDone,
    sortOrder: 0,
    createdAt: now,
    updatedAt: now,
  );
}

/// In-memory fake so widget tests never touch Drift or its timers.
class FakeStickyRepository implements StickyRepository {
  FakeStickyRepository(
    this._board, {
    List<StickyWithTodos> trash = const <StickyWithTodos>[],
  }) : _trash = List<StickyWithTodos>.of(trash);

  final List<StickyWithTodos> _board;
  final List<StickyWithTodos> _trash;
  final List<(String id, bool isDone)> toggled = <(String, bool)>[];
  final List<List<String>> stickyOrders = <List<String>>[];
  final List<String> movedToTrash = <String>[];
  final List<String> restoredStickies = <String>[];
  final List<String> deletedStickies = <String>[];

  @override
  Stream<List<StickyWithTodos>> watchBoard() =>
      Stream<List<StickyWithTodos>>.value(_board);

  @override
  Stream<List<StickyWithTodos>> watchTrash() =>
      Stream<List<StickyWithTodos>>.value(_trash);

  @override
  Future<Sticky> addSticky({int colorIndex = 0, String title = ''}) async =>
      _sticky(id: 'new', colorIndex: colorIndex, title: title);

  @override
  Future<Todo> addTodo(String stickyId, String content) async =>
      _todo(stickyId: stickyId, content: content);

  @override
  Future<void> toggleTodo(String todoId, bool isDone) async =>
      toggled.add((todoId, isDone));

  @override
  Future<void> editTodoContent(String todoId, String content) async {}

  @override
  Future<void> deleteTodo(String todoId) async {}

  @override
  Future<void> deleteSticky(String stickyId) async {
    deletedStickies.add(stickyId);
  }

  @override
  Future<void> moveStickyToTrash(String stickyId) async {
    movedToTrash.add(stickyId);
  }

  @override
  Future<void> restoreSticky(String stickyId) async {
    restoredStickies.add(stickyId);
  }

  @override
  Future<void> setStickyColor(String stickyId, int colorIndex) async {}

  @override
  Future<void> setStickyOpacity(String stickyId, double opacity) async {}

  @override
  Future<void> setStickyTitle(String stickyId, String title) async {}

  @override
  Future<void> reorderStickies(List<Sticky> ordered) async {
    stickyOrders.add(<String>[for (final Sticky sticky in ordered) sticky.id]);
  }

  @override
  Future<void> reorderTodos(List<Todo> ordered) async {}
}

/// In-memory fake auth. Pass a [user] to start signed in.
class FakeAuthService implements AuthService {
  FakeAuthService({this.user});

  AppUser? user;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  AppUser? get currentUser => user;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield user;
    yield* _changes.stream.map((_) => user);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    user = AppUser(uid: 'u', email: email);
    _changes.add(null);
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    user = AppUser(uid: 'u', email: email);
    _changes.add(null);
  }

  @override
  Future<void> signOut() async {
    user = null;
    _changes.add(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Widget bootstrap(StickyRepository repo, {AuthService? auth}) {
    return ProviderScope(
      overrides: <Override>[
        stickyRepositoryProvider.overrideWithValue(repo),
        authServiceProvider.overrideWithValue(
          auth ??
              FakeAuthService(
                user: const AppUser(uid: 'u', email: 't@t.com'),
              ),
        ),
      ],
      child: const StikoApp(),
    );
  }

  Widget bootstrapScreen(Widget child, StickyRepository repo) {
    return ProviderScope(
      overrides: <Override>[
        stickyRepositoryProvider.overrideWithValue(repo),
        authServiceProvider.overrideWithValue(
          FakeAuthService(
            user: const AppUser(uid: 'u', email: 't@t.com'),
          ),
        ),
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('Ctrl +, -, 0으로 전체 UI 배율을 조절한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppZoom(child: ColoredBox(color: Colors.amber)),
      ),
    );
    await tester.pump();

    double scale() => tester
        .widget<Transform>(find.byKey(const Key('app-zoom-transform')))
        .transform
        .getMaxScaleOnAxis();

    expect(scale(), 1);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(scale(), closeTo(1.1, 0.001));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(scale(), closeTo(1, 0.001));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(scale(), closeTo(1.1, 0.001));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(scale(), closeTo(1, 0.001));
  });

  testWidgets(
    '로그인하지 않으면 로그인 화면으로 이동한다',
    (tester) async {
      await tester.pumpWidget(
        bootstrap(
          FakeStickyRepository(const <StickyWithTodos>[]),
          auth: FakeAuthService(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('auth-window-drag-region')), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '로그인'), findsOneWidget);
      expect(find.text('스티커가 없습니다'), findsNothing);

      await tester.tap(find.text('계정이 없으신가요? 회원가입'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('auth-window-drag-region')), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '회원가입'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('로그인 상태에서 스티커가 없으면 빈 안내가 보인다', (tester) async {
    await tester.pumpWidget(
      bootstrap(FakeStickyRepository(const <StickyWithTodos>[])),
    );
    await tester.pumpAndSettle();

    expect(find.text('스티커가 없습니다'), findsOneWidget);
  });

  testWidgets(
    '데스크톱 스티커 목록을 손잡이로 드래그해 순서를 저장한다',
    (tester) async {
      final FakeStickyRepository repo = FakeStickyRepository(<StickyWithTodos>[
        StickyWithTodos(_sticky(id: 's1', title: '첫 번째'), const <Todo>[]),
        StickyWithTodos(_sticky(id: 's2', title: '두 번째'), const <Todo>[]),
        StickyWithTodos(_sticky(id: 's3', title: '세 번째'), const <Todo>[]),
      ]);
      await tester.pumpWidget(bootstrap(repo));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('sticky-drag-s1')),
        findsOneWidget,
      );
      await tester.drag(
        find.byKey(const ValueKey<String>('sticky-drag-s1')),
        const Offset(0, 180),
      );
      await tester.pumpAndSettle();

      expect(repo.stickyOrders.last, <String>['s2', 's1', 's3']);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    '열린 스티커는 삭제를 막고 창을 닫은 뒤 삭제한다',
    (tester) async {
      const MethodChannel windowChannel = MethodChannel(
        'mixin.one/desktop_multi_window',
      );
      bool childOpen = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(windowChannel, (MethodCall call) async {
            if (call.method != 'getAllWindows') return null;
            return <Map<String, Object?>>[
              <String, Object?>{'windowId': 'main', 'windowArgument': ''},
              if (childOpen)
                <String, Object?>{
                  'windowId': 'child',
                  'windowArgument': jsonEncode(<String, Object>{
                    'stickyId': 's1',
                  }),
                },
            ];
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(windowChannel, null);
      });

      final StickyWithTodos item = StickyWithTodos(
        _sticky(id: 's1', title: '삭제 테스트'),
        const <Todo>[],
      );
      final FakeStickyRepository repo = FakeStickyRepository(<StickyWithTodos>[
        item,
      ]);
      await tester.pumpWidget(
        bootstrapScreen(Scaffold(body: StickyTitleRow(data: item)), repo),
      );

      await tester.tap(find.byTooltip('휴지통으로 이동'));
      await tester.pump();

      expect(find.text('휴지통으로 이동하려면 스티커 창을 먼저 닫아 주세요.'), findsOneWidget);
      expect(repo.movedToTrash, isEmpty);

      childOpen = false;
      await tester.tap(find.byTooltip('휴지통으로 이동'));
      await tester.pump();

      expect(repo.movedToTrash, <String>['s1']);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('상단 휴지통 버튼으로 빈 휴지통을 연다', (tester) async {
    await tester.pumpWidget(
      bootstrap(FakeStickyRepository(const <StickyWithTodos>[])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('휴지통'));
    await tester.pumpAndSettle();

    expect(find.text('휴지통이 비어 있습니다'), findsOneWidget);
  });

  testWidgets('휴지통에서 스티커를 복원하고 영구 삭제한다', (tester) async {
    final StickyWithTodos first = StickyWithTodos(
      _sticky(id: 's1', title: '복원 메모'),
      <Todo>[_todo(id: 't1', stickyId: 's1')],
    );
    final StickyWithTodos second = StickyWithTodos(
      _sticky(id: 's2', title: '삭제 메모'),
      const <Todo>[],
    );
    final FakeStickyRepository repo = FakeStickyRepository(
      const <StickyWithTodos>[],
      trash: <StickyWithTodos>[first, second],
    );
    await tester.pumpWidget(bootstrapScreen(const TrashScreen(), repo));
    await tester.pumpAndSettle();

    expect(find.text('복원 메모'), findsOneWidget);
    expect(find.text('할 일 1개'), findsOneWidget);
    await tester.tap(find.byTooltip('복원').first);
    await tester.pump();
    expect(repo.restoredStickies, <String>['s1']);

    await tester.tap(find.byTooltip('영구 삭제').last);
    await tester.pumpAndSettle();
    expect(find.text('스티커를 영구 삭제할까요?'), findsOneWidget);
    expect(repo.deletedStickies, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, '영구 삭제'));
    await tester.pumpAndSettle();
    expect(repo.deletedStickies, <String>['s2']);
  });

  testWidgets(
    '데스크톱에서 목록을 누르면 스티커 새 창을 연다',
    (tester) async {
      const MethodChannel channel = MethodChannel(
        'mixin.one/desktop_multi_window',
      );
      const MethodChannel screenChannel = MethodChannel(
        'dev.leanflutter.plugins/screen_retriever',
      );
      final List<MethodCall> calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            calls.add(call);
            return switch (call.method) {
              'getAllWindows' => <Map<String, Object?>>[],
              'createWindow' => 'test-window',
              _ => null,
            };
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(screenChannel, (MethodCall call) async {
            const Map<String, Object> display = <String, Object>{
              'id': 'test-display',
              'size': <String, double>{'width': 1920, 'height': 1080},
              'visiblePosition': <String, double>{'dx': 0, 'dy': 0},
              'visibleSize': <String, double>{'width': 1920, 'height': 1040},
            };
            return switch (call.method) {
              'getCursorScreenPoint' => <String, double>{'dx': 400, 'dy': 300},
              'getAllDisplays' => <String, Object>{
                'displays': <Map<String, Object>>[display],
              },
              'getPrimaryDisplay' => display,
              _ => null,
            };
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(screenChannel, null);
      });

      final StickyWithTodos item = StickyWithTodos(_sticky(title: '할일'), <Todo>[
        _todo(content: '목록 클릭 테스트'),
      ]);
      await tester.pumpWidget(
        bootstrapScreen(
          StickyTitleRow(data: item),
          FakeStickyRepository(<StickyWithTodos>[item]),
        ),
      );

      await tester.tap(find.text('할일'));
      await tester.pumpAndSettle();

      final List<MethodCall> createCalls = calls
          .where((MethodCall call) => call.method == 'createWindow')
          .toList();
      expect(createCalls, hasLength(1));
      final Map<Object?, Object?> configuration =
          createCalls.single.arguments as Map<Object?, Object?>;
      final Map<String, dynamic> windowArguments =
          jsonDecode(configuration['arguments']! as String)
              as Map<String, dynamic>;
      expect(windowArguments['stickyId'], 's1');
      expect(windowArguments['uid'], 'u');
      expect(windowArguments['left'], 424);
      expect(windowArguments['top'], 256);

      await StickyWindowPositionStore.save('s1', const Offset(760, 210));
      await tester.tap(find.text('할일'));
      await tester.pumpAndSettle();

      final List<MethodCall> reopenedCreateCalls = calls
          .where((MethodCall call) => call.method == 'createWindow')
          .toList();
      expect(reopenedCreateCalls, hasLength(2));
      final Map<Object?, Object?> reopenedConfiguration =
          reopenedCreateCalls.last.arguments as Map<Object?, Object?>;
      final Map<String, dynamic> reopenedArguments =
          jsonDecode(reopenedConfiguration['arguments']! as String)
              as Map<String, dynamic>;
      expect(reopenedArguments['left'], 760);
      expect(reopenedArguments['top'], 210);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('스티커 상세에서 할 일이 표시된다', (tester) async {
    final List<StickyWithTodos> board = <StickyWithTodos>[
      StickyWithTodos(_sticky(), <Todo>[_todo(content: '장보기')]),
    ];
    await tester.pumpWidget(
      bootstrapScreen(
        const StickyDetailScreen(stickyId: 's1'),
        FakeStickyRepository(board),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('장보기'), findsOneWidget);
  });

  testWidgets('상세에서 체크박스를 누르면 toggleTodo가 호출된다', (tester) async {
    final FakeStickyRepository repo = FakeStickyRepository(<StickyWithTodos>[
      StickyWithTodos(_sticky(), <Todo>[_todo(id: 'abc', content: '완료할 일')]),
    ]);
    await tester.pumpWidget(
      bootstrapScreen(const StickyDetailScreen(stickyId: 's1'), repo),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(repo.toggled, contains(('abc', true)));
  });
}
