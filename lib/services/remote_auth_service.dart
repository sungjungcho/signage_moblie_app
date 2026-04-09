import '../models/remote_auth_payload.dart';
import '../models/user_session.dart';
import 'api_client.dart';
import 'auth_service.dart';

class RemoteAuthService implements AuthService {
  RemoteAuthService({
    required this.baseUrl,
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient(baseUrl: baseUrl);

  final String baseUrl;
  final ApiClient _apiClient;

  @override
  Future<UserSession> signIn({
    required String userId,
    required String password,
    required bool keepSignedIn,
  }) async {
    try {
      final payload = RemoteAuthPayload(
        userId: userId.trim(),
        password: password,
        keepSignedIn: keepSignedIn,
      );

      final response = await _apiClient.postJson(
        '/auth/login',
        body: payload.toJson(),
      );

      final authData = response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : response;

      final parsed = RemoteAuthResponse.fromJson(authData);
      if (parsed.userId.isEmpty) {
        throw const AuthException('로그인 응답에 사용자 정보가 없습니다.');
      }

      return parsed.toSession(fallbackKeepSignedIn: keepSignedIn);
    } on ApiException catch (error) {
      throw AuthException(error.message);
    }
  }
}
