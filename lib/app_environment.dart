class AppEnvironment {
  const AppEnvironment({
    required this.useMockAuthService,
    required this.useMockContentService,
    required this.serverBaseUrl,
    required this.apiBaseUrl,
    required this.passwordResetUrl,
  });

  final bool useMockAuthService;
  final bool useMockContentService;
  final String serverBaseUrl;
  final String apiBaseUrl;
  final String passwordResetUrl;

  static const AppEnvironment current = AppEnvironment(
    useMockAuthService: false,
    useMockContentService: true,
    serverBaseUrl: 'https://sg.cothink.co.kr',
    apiBaseUrl: 'https://sg.cothink.co.kr',
    passwordResetUrl: 'https://sg.cothink.co.kr/login',
  );
}
