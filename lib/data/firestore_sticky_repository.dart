import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import 'local/database.dart' show Sticky, Todo, StickyWithTodos;
import 'sticky_repository.dart';

/// Firestore-backed [StickyRepository]. Stores each user's board under
/// `users/{uid}/stickies/{stickyId}`, with the sticky's todos embedded as an
/// array on the document so a single listener drives both the board list and
/// an individual sticky window.
class FirestoreStickyRepository implements StickyRepository {
  FirestoreStickyRepository({
    required this.uid,
    FirebaseFirestore? firestore,
    this._uuid = const Uuid(),
    this._clock = DateTime.now,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _firestore;
  final Uuid _uuid;
  final DateTime Function() _clock;

  // A single collection listener shared by the board and trash views. Opening a
  // desktop_multi_window sub-window corrupts this engine's Firestore plugin
  // channel, so any query listener STARTED afterwards throws a
  // MissingPluginException on `listen` and then silently never emits — which is
  // why opening the trash (a new listener) after a sticky window was open left
  // it spinning forever. The board subscribes at launch, before any sub-window
  // can exist, so this one listener stays healthy; the trash view piggybacks on
  // it (replaying the cached snapshot) instead of starting its own.
  StreamController<List<StickyWithTodos>>? _allController;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _allSub;
  List<StickyWithTodos>? _latestAll;

  CollectionReference<Map<String, dynamic>> get _stickies =>
      _firestore.collection('users').doc(uid).collection('stickies');

  /// The one shared collection stream. A late subscriber (the trash view, opened
  /// after the board) is replayed the most recent snapshot and then follows live
  /// updates, all WITHOUT starting a new Firestore `listen` — the board's launch
  /// subscription is the only one that ever touches the plugin channel.
  Stream<List<StickyWithTodos>> _watchAllStickies() {
    _allController ??= StreamController<List<StickyWithTodos>>.broadcast(
      onListen: _ensureCollectionListener,
    );
    final StreamController<List<StickyWithTodos>> controller = _allController!;
    return Stream<List<StickyWithTodos>>.multi((
      MultiStreamController<List<StickyWithTodos>> sub,
    ) {
      final List<StickyWithTodos>? cached = _latestAll;
      if (cached != null) sub.addSync(cached);
      final StreamSubscription<List<StickyWithTodos>> inner = controller.stream
          .listen(sub.add, onError: sub.addError, onDone: sub.close);
      sub.onCancel = inner.cancel;
    });
  }

  void _ensureCollectionListener() {
    _allSub ??= _stickies.orderBy('sortOrder').snapshots().listen(
      (QuerySnapshot<Map<String, dynamic>> snap) {
        _latestAll = snap.docs.map(_toStickyWithTodos).toList();
        _allController?.add(_latestAll!);
      },
      onError: (Object e, StackTrace s) => _allController?.addError(e, s),
    );
  }

  @override
  Stream<List<StickyWithTodos>> watchBoard() {
    return _watchAllStickies().map(
      (List<StickyWithTodos> all) => all
          .where((StickyWithTodos s) => s.sticky.deletedAt == null)
          .toList(),
    );
  }

  @override
  Stream<List<StickyWithTodos>> watchTrash() {
    return _watchAllStickies().map((List<StickyWithTodos> all) {
      final List<StickyWithTodos> items = all
          .where((StickyWithTodos s) => s.sticky.deletedAt != null)
          .toList();
      items.sort(
        (StickyWithTodos a, StickyWithTodos b) =>
            (b.sticky.deletedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(
                  a.sticky.deletedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                ),
      );
      return items;
    });
  }

  /// Watches a single sticky, for a standalone sticky window.
  Stream<StickyWithTodos?> watchSticky(String stickyId) {
    return _stickies
        .doc(stickyId)
        .snapshots()
        .map(
          (DocumentSnapshot<Map<String, dynamic>> doc) =>
              doc.exists && doc.data()?['deletedAt'] == null
              ? _toStickyWithTodos(doc)
              : null,
        );
  }

  @override
  Future<Sticky> addSticky({int colorIndex = 0, String title = ''}) async {
    final DateTime now = _clock();
    final String id = _uuid.v4();
    final int order = now.millisecondsSinceEpoch;
    await _stickies.doc(id).set(<String, dynamic>{
      'title': title,
      'colorIndex': colorIndex,
      'opacity': 1.0,
      'sortOrder': order,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'deletedAt': null,
      'todos': <Map<String, dynamic>>[],
    });
    return Sticky(
      id: id,
      title: title,
      colorIndex: colorIndex,
      opacity: 1.0,
      sortOrder: order,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
  }

  @override
  Future<void> setStickyColor(String stickyId, int colorIndex) =>
      _stickies.doc(stickyId).update(<String, dynamic>{
        'colorIndex': colorIndex,
        'updatedAt': Timestamp.fromDate(_clock()),
      });

  @override
  Future<void> setStickyOpacity(String stickyId, double opacity) =>
      _stickies.doc(stickyId).update(<String, dynamic>{
        'opacity': opacity,
        'updatedAt': Timestamp.fromDate(_clock()),
      });

  @override
  Future<void> setStickyTitle(String stickyId, String title) =>
      _stickies.doc(stickyId).update(<String, dynamic>{
        'title': title,
        'updatedAt': Timestamp.fromDate(_clock()),
      });

  @override
  Future<void> moveStickyToTrash(String stickyId) {
    final DateTime now = _clock();
    return _stickies.doc(stickyId).update(<String, dynamic>{
      'deletedAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  @override
  Future<void> restoreSticky(String stickyId) {
    return _stickies.doc(stickyId).update(<String, dynamic>{
      'deletedAt': null,
      'updatedAt': Timestamp.fromDate(_clock()),
    });
  }

  @override
  Future<void> deleteSticky(String stickyId) =>
      _stickies.doc(stickyId).delete();

  @override
  Future<void> reorderStickies(List<Sticky> ordered) async {
    final WriteBatch batch = _firestore.batch();
    for (int i = 0; i < ordered.length; i++) {
      batch.update(_stickies.doc(ordered[i].id), <String, dynamic>{
        'sortOrder': i,
      });
    }
    await batch.commit();
  }

  @override
  Future<Todo> addTodo(String stickyId, String content) async {
    final DateTime now = _clock();
    final String id = _uuid.v4();
    final int order = now.millisecondsSinceEpoch;
    final Todo todo = Todo(
      id: id,
      stickyId: stickyId,
      content: content,
      isDone: false,
      sortOrder: order,
      createdAt: now,
      updatedAt: now,
    );
    await _mutateTodos(stickyId, (List<Map<String, dynamic>> todos) {
      todos.add(_todoToMap(todo));
      return todos;
    });
    return todo;
  }

  @override
  Future<void> editTodoContent(String todoId, String content) {
    return _editTodoInAnySticky(todoId, (Map<String, dynamic> t) {
      t['content'] = content;
      t['updatedAt'] = Timestamp.fromDate(_clock());
    });
  }

  @override
  Future<void> toggleTodo(String todoId, bool isDone) {
    return _editTodoInAnySticky(todoId, (Map<String, dynamic> t) {
      t['isDone'] = isDone;
      t['updatedAt'] = Timestamp.fromDate(_clock());
    });
  }

  @override
  Future<void> deleteTodo(String todoId) {
    return _editTodoInAnySticky(todoId, null, removeId: todoId);
  }

  @override
  Future<void> reorderTodos(List<Todo> ordered) async {
    if (ordered.isEmpty) return;
    final String stickyId = ordered.first.stickyId;
    final Map<String, int> orderById = <String, int>{
      for (int i = 0; i < ordered.length; i++) ordered[i].id: i,
    };
    await _mutateTodos(stickyId, (List<Map<String, dynamic>> todos) {
      for (final Map<String, dynamic> t in todos) {
        final int? order = orderById[t['id'] as String];
        if (order != null) t['sortOrder'] = order;
      }
      return todos;
    });
  }

  // Helpers -------------------------------------------------------------------

  StickyWithTodos _toStickyWithTodos(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    final Sticky sticky = Sticky(
      id: doc.id,
      title: data['title'] as String? ?? '',
      colorIndex: (data['colorIndex'] as num?)?.toInt() ?? 0,
      opacity: (data['opacity'] as num?)?.toDouble() ?? 1.0,
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt: _toDate(data['createdAt']),
      updatedAt: _toDate(data['updatedAt']),
      deletedAt: _toNullableDate(data['deletedAt']),
    );
    final List<Todo> todos =
        ((data['todos'] as List<dynamic>?) ?? <dynamic>[])
            .map((dynamic e) => _mapToTodo(doc.id, e as Map<String, dynamic>))
            .toList()
          ..sort((Todo a, Todo b) => a.sortOrder.compareTo(b.sortOrder));
    return StickyWithTodos(sticky, todos);
  }

  Todo _mapToTodo(String stickyId, Map<String, dynamic> m) => Todo(
    id: m['id'] as String,
    stickyId: stickyId,
    content: m['content'] as String? ?? '',
    isDone: m['isDone'] as bool? ?? false,
    sortOrder: (m['sortOrder'] as num?)?.toInt() ?? 0,
    createdAt: _toDate(m['createdAt']),
    updatedAt: _toDate(m['updatedAt']),
  );

  Map<String, dynamic> _todoToMap(Todo t) => <String, dynamic>{
    'id': t.id,
    'content': t.content,
    'isDone': t.isDone,
    'sortOrder': t.sortOrder,
    'createdAt': Timestamp.fromDate(t.createdAt),
    'updatedAt': Timestamp.fromDate(t.updatedAt),
  };

  DateTime _toDate(dynamic v) =>
      v is Timestamp ? v.toDate() : DateTime.fromMillisecondsSinceEpoch(0);

  DateTime? _toNullableDate(dynamic v) => v is Timestamp ? v.toDate() : null;

  /// Reads a sticky, transforms its todo array, and writes it back atomically.
  Future<void> _mutateTodos(
    String stickyId,
    List<Map<String, dynamic>> Function(List<Map<String, dynamic>>) transform,
  ) async {
    final DocumentReference<Map<String, dynamic>> ref = _stickies.doc(stickyId);
    await _firestore.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
      final List<Map<String, dynamic>> todos =
          ((snap.data()?['todos'] as List<dynamic>?) ?? <dynamic>[])
              .map(
                (dynamic e) =>
                    Map<String, dynamic>.from(e as Map<String, dynamic>),
              )
              .toList();
      tx.update(ref, <String, dynamic>{
        'todos': transform(todos),
        'updatedAt': Timestamp.fromDate(_clock()),
      });
    });
  }

  /// Finds the sticky that contains [todoId] and either edits that todo (via
  /// [edit]) or removes it (when [removeId] is set).
  Future<void> _editTodoInAnySticky(
    String todoId,
    void Function(Map<String, dynamic>)? edit, {
    String? removeId,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> all = await _stickies.get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in all.docs) {
      final List<dynamic> todos =
          (doc.data()['todos'] as List<dynamic>?) ?? <dynamic>[];
      final bool contains = todos.any(
        (dynamic e) => (e as Map<String, dynamic>)['id'] == todoId,
      );
      if (!contains) continue;
      await _mutateTodos(doc.id, (List<Map<String, dynamic>> list) {
        if (removeId != null) {
          list.removeWhere((Map<String, dynamic> t) => t['id'] == removeId);
        } else if (edit != null) {
          for (final Map<String, dynamic> t in list) {
            if (t['id'] == todoId) edit(t);
          }
        }
        return list;
      });
      return;
    }
  }
}
