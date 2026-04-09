import 'app_environment.dart';
import 'services/auth_service.dart';
import 'services/content_service.dart';
import 'services/mock_auth_service.dart';
import 'services/mock_content_service.dart';
import 'services/remote_auth_service.dart';
import 'services/remote_content_service.dart';

class AppDependencies {
  const AppDependencies({
    required this.authService,
    required this.contentService,
  });

  final AuthService authService;
  final ContentService contentService;

  factory AppDependencies.fromEnvironment(AppEnvironment environment) {
    final authService = environment.useMockAuthService
        ? const MockAuthService()
        : RemoteAuthService(baseUrl: environment.apiBaseUrl);

    final contentService = environment.useMockContentService
        ? const MockContentService()
        : RemoteContentService(baseUrl: environment.apiBaseUrl);

    return AppDependencies(
      authService: authService,
      contentService: contentService,
    );
  }
}
