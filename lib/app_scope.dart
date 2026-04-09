import 'package:flutter/widgets.dart';

import 'app_environment.dart';
import 'services/auth_service.dart';
import 'services/content_service.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.environment,
    required this.authService,
    required this.contentService,
    required super.child,
  });

  final AppEnvironment environment;
  final AuthService authService;
  final ContentService contentService;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope가 위젯 트리에 없습니다.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) {
    return environment != oldWidget.environment ||
        authService != oldWidget.authService ||
        contentService != oldWidget.contentService;
  }
}
