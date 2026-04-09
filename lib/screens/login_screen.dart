import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../app_scope.dart';
import '../models/user_session.dart';
import '../services/auth_service.dart';
import '../services/mock_auth_service.dart';
import 'home_screen.dart';
import 'password_reset_bridge_screen.dart';
import 'web_login_bridge_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberLogin = true;
  bool _isSubmitting = false;

  bool get _supportsWebViewLogin {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _openPasswordReset() async {
    final url = AppScope.of(context).environment.passwordResetUrl;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PasswordResetBridgeScreen(loginUrl: url),
      ),
    );
  }

  Future<void> _submitLogin() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final scope = AppScope.of(context);
      late final UserSession session;
      final useMockAuth =
          scope.environment.useMockAuthService || !_supportsWebViewLogin;

      if (useMockAuth) {
        session = await const MockAuthService().signIn(
          userId: _idController.text,
          password: _passwordController.text,
          keepSignedIn: _rememberLogin,
        );
      } else {
        final result = await Navigator.of(context).push<WebLoginResult>(
          MaterialPageRoute<WebLoginResult>(
            builder: (_) => WebLoginBridgeScreen(
              serverBaseUrl: scope.environment.serverBaseUrl,
              userId: _idController.text,
              password: _passwordController.text,
              keepSignedIn: _rememberLogin,
            ),
          ),
        );

        if (!mounted) {
          return;
        }

        if (result?.session == null) {
          throw AuthException(
            result?.errorMessage ?? '운영 서버 로그인 확인에 실패했습니다.',
          );
        }

        session = result!.session!;
      }

      if (!mounted) {
        return;
      }

      final sessionWithCredentials = session.copyWith(
        loginPassword: _passwordController.text,
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => HomeScreen(session: sessionWithCredentials),
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF27364A),
              Color(0xFF25C1AE),
              Color(0xFFF5FBFA),
            ],
            stops: [0.0, 0.34, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 48,
                left: -10,
                child: _AccentBubble(
                  size: 110,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              Positioned(
                top: 150,
                right: -18,
                child: _AccentBubble(
                  size: 140,
                  color: const Color(0xFFEAA2C0).withValues(alpha: 0.28),
                ),
              ),
              Positioned(
                bottom: 180,
                left: 18,
                child: _AccentBubble(
                  size: 72,
                  color: const Color(0xFF9DE7DA).withValues(alpha: 0.28),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 18),
                        Container(
                          width: 128,
                          height: 128,
                          margin: const EdgeInsets.only(bottom: 28),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: const Color(0xFFE9A5C2),
                              width: 6,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1F102A43),
                                blurRadius: 28,
                                offset: Offset(0, 16),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'BLOSSOM',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: const Color(0xFF2C6FB7),
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          'The Blossom English & Storybooks',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            height: 1.12,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x180F172A),
                                blurRadius: 36,
                                offset: Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  '로그인',
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '로그인 후 메세지와 공지사항 화면으로 이동합니다.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF617386),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                TextFormField(
                                  controller: _idController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: '아이디',
                                    hintText: 'example@blossom.com',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return '아이디를 입력해주세요.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submitLogin(),
                                  decoration: InputDecoration(
                                    labelText: '비밀번호',
                                    hintText: '비밀번호를 입력해주세요',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return '비밀번호를 입력해주세요.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _rememberLogin,
                                      activeColor: const Color(0xFF25C1AE),
                                      onChanged: (value) {
                                        setState(() {
                                          _rememberLogin = value ?? false;
                                        });
                                      },
                                    ),
                                    const Expanded(
                                      child: Text('로그인 상태 유지'),
                                    ),
                                    TextButton(
                                      onPressed: _openPasswordReset,
                                      child: const Text('비밀번호 찾기'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 56,
                                  child: FilledButton(
                                    onPressed: _submitLogin,
                                    style: FilledButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    child: _isSubmitting
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('로그인'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccentBubble extends StatelessWidget {
  const _AccentBubble({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
