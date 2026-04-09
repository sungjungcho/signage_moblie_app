import '../models/user_session.dart';
import 'auth_service.dart';

class MockAuthService implements AuthService {
  const MockAuthService();

  @override
  Future<UserSession> signIn({
    required String userId,
    required String password,
    required bool keepSignedIn,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));

    if (userId.trim().isEmpty || password.trim().isEmpty) {
      throw const AuthException('아이디와 비밀번호를 입력해주세요.');
    }

    if (password.length < 4) {
      throw const AuthException('비밀번호는 4자 이상이어야 합니다.');
    }

    return UserSession(
      userId: userId.trim(),
      displayName: 'Blossom 관리자',
      keepSignedIn: keepSignedIn,
    );
  }
}
