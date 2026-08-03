import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_service.dart';

/// The active auth service. Swapped to a Firebase implementation later.
final authServiceProvider = Provider<AuthService>((ref) {
  return LocalStubAuthService();
});

/// Reactive current-user stream, used to gate the app behind sign-in.
final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});
