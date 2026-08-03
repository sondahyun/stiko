import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/firestore_sticky_repository.dart';
import '../../../data/local/database.dart';
import '../../../data/sticky_repository.dart';
import '../../auth/application/auth_providers.dart';

/// Repository backed by the signed-in user's Firestore data. Rebuilds when the
/// user changes so each account sees only its own board.
final stickyRepositoryProvider = Provider<StickyRepository>((ref) {
  final String uid =
      ref.watch(authStateProvider).valueOrNull?.uid ?? 'anonymous';
  return FirestoreStickyRepository(uid: uid);
});

/// Reactive stream of every sticky with its todos, ordered for display.
final boardStreamProvider = StreamProvider<List<StickyWithTodos>>((ref) {
  return ref.watch(stickyRepositoryProvider).watchBoard();
});
