import '../models/user_session.dart';

abstract class AuthService {
  Future<UserSession> signIn({
    required String userId,
    required String password,
    required bool keepSignedIn,
  });
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;
}
