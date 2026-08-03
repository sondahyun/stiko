import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

/// The signed-in user, kept minimal so a Firebase user maps cleanly onto it.
class AppUser {
  const AppUser({required this.uid, required this.email});

  final String uid;
  final String email;
}

/// A user-facing authentication failure carrying a friendly message.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Authentication contract, so the UI depends on behavior rather than Firebase.
abstract interface class AuthService {
  Stream<AppUser?> authStateChanges();
  AppUser? get currentUser;
  Future<void> signIn({required String email, required String password});
  Future<void> signUp({required String email, required String password});
  Future<void> signOut();
}

/// Firebase-backed authentication.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService([FirebaseAuth? auth])
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  AppUser? _map(User? user) =>
      user == null ? null : AppUser(uid: user.uid, email: user.email ?? '');

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(_map);

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return '이메일 형식이 올바르지 않습니다.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 올바르지 않습니다.';
      case 'email-already-in-use':
        return '이미 가입된 이메일입니다.';
      case 'weak-password':
        return '비밀번호가 너무 약합니다. 6자 이상 사용하세요.';
      case 'network-request-failed':
        return '네트워크 연결을 확인해 주세요.';
      case 'too-many-requests':
        return '잠시 후 다시 시도해 주세요.';
      default:
        return '인증 중 오류가 발생했습니다. (${e.code})';
    }
  }
}
