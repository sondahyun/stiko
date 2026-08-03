import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// The signed-in user, kept minimal so a Firebase user maps cleanly onto it.
class AppUser {
  const AppUser({required this.uid, required this.email});

  final String uid;
  final String email;
}

/// Authentication contract. A Firebase-backed implementation replaces the
/// local stub once the Firebase project is connected.
abstract interface class AuthService {
  Stream<AppUser?> authStateChanges();
  AppUser? get currentUser;
  Future<void> signIn({required String email, required String password});
  Future<void> signUp({required String email, required String password});
  Future<void> signOut();
}

/// Temporary local stand-in used until Firebase is wired up.
///
/// It accepts any credentials and simply remembers the last email, so the
/// login / signup / logout flow works end to end before real auth exists.
class LocalStubAuthService implements AuthService {
  LocalStubAuthService() {
    _restore();
  }

  final StreamController<void> _changes = StreamController<void>.broadcast();
  AppUser? _current;

  static const String _kEmail = 'auth.stub.email';

  Future<void> _restore() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? email = prefs.getString(_kEmail);
    _current =
        email == null ? null : AppUser(uid: 'local-$email', email: email);
    _changes.add(null);
  }

  @override
  AppUser? get currentUser => _current;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _current;
    yield* _changes.stream.map((_) => _current);
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      _setUser(email);

  @override
  Future<void> signUp({required String email, required String password}) =>
      _setUser(email);

  Future<void> _setUser(String email) async {
    _current = AppUser(uid: 'local-$email', email: email);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEmail, email);
    _changes.add(null);
  }

  @override
  Future<void> signOut() async {
    _current = null;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kEmail);
    _changes.add(null);
  }
}
