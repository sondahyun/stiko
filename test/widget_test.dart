import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stiko/app/app.dart';
import 'package:stiko/data/local/database.dart';
import 'package:stiko/data/sticky_repository.dart';
import 'package:stiko/features/auth/application/auth_providers.dart';
import 'package:stiko/features/auth/application/auth_service.dart';
import 'package:stiko/features/board/application/board_providers.dart';

Sticky _sticky({String id = 's1', int colorIndex = 0, String title = ''}) {
  final DateTime now = DateTime(2026, 1, 1);
  return Sticky(
    id: id,
    title: title,
    colorIndex: colorIndex,
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
  FakeStickyRepository(this._board);

  final List<StickyWithTodos> _board;
  final List<(String id, bool isDone)> toggled = <(String, bool)>[];

  @override
  Stream<List<StickyWithTodos>> watchBoard() =>
      Stream<List<StickyWithTodos>>.value(_board);

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
  Future<void> deleteSticky(String stickyId) async {}

  @override
  Future<void> setStickyColor(String stickyId, int colorIndex) async {}

  @override
  Future<void> setStickyTitle(String stickyId, String title) async {}

  @override
  Future<void> reorderStickies(List<Sticky> ordered) async {}

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

  testWidgets('로그인하지 않으면 로그인 화면으로 이동한다', (tester) async {
    await tester.pumpWidget(
      bootstrap(
        FakeStickyRepository(const <StickyWithTodos>[]),
        auth: FakeAuthService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, '로그인'), findsOneWidget);
    expect(find.text('스티커가 없습니다'), findsNothing);
  });

  testWidgets('로그인 상태에서 스티커가 없으면 빈 안내가 보인다', (tester) async {
    await tester.pumpWidget(
      bootstrap(FakeStickyRepository(const <StickyWithTodos>[])),
    );
    await tester.pumpAndSettle();

    expect(find.text('스티커가 없습니다'), findsOneWidget);
  });

  testWidgets('스티커 안의 할 일이 표시된다', (tester) async {
    final List<StickyWithTodos> board = <StickyWithTodos>[
      StickyWithTodos(_sticky(), <Todo>[_todo(content: '장보기')]),
    ];
    await tester.pumpWidget(bootstrap(FakeStickyRepository(board)));
    await tester.pumpAndSettle();

    expect(find.text('장보기'), findsOneWidget);
  });

  testWidgets('체크박스를 누르면 toggleTodo가 호출된다', (tester) async {
    final FakeStickyRepository repo = FakeStickyRepository(<StickyWithTodos>[
      StickyWithTodos(_sticky(), <Todo>[_todo(id: 'abc', content: '완료할 일')]),
    ]);
    await tester.pumpWidget(bootstrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(repo.toggled, contains(('abc', true)));
  });
}
