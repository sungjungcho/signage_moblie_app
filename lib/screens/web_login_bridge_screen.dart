import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../models/user_session.dart';

class WebLoginBridgeScreen extends StatefulWidget {
  const WebLoginBridgeScreen({
    super.key,
    required this.serverBaseUrl,
    required this.userId,
    required this.password,
    required this.keepSignedIn,
  });

  final String serverBaseUrl;
  final String userId;
  final String password;
  final bool keepSignedIn;

  @override
  State<WebLoginBridgeScreen> createState() => _WebLoginBridgeScreenState();
}

class _WebLoginBridgeScreenState extends State<WebLoginBridgeScreen> {
  WebViewController? _controller;
  WebViewCookieManager? _cookieManager;
  bool _isSubmitting = false;
  bool _isCompleting = false;
  String? _errorMessage;

  bool get _supportsWebViewLogin {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  void initState() {
    super.initState();
    if (_supportsWebViewLogin) {
      _initController();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _completeWithError(
          '현재 실행 중인 플랫폼에서는 WebView 기반 운영 서버 로그인을 지원하지 않습니다. Android 또는 iPhone에서 테스트해주세요.',
        );
      });
    }
  }

  void _initController() {
    _cookieManager = WebViewCookieManager();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            await _handlePageFinished(url);
          },
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame == false) {
              return;
            }
            setState(() {
              _errorMessage = '로그인 페이지를 불러오지 못했습니다.';
            });
          },
        ),
      )
      ..loadHtmlString('<html><body style="background:#ffffff;"></body></html>');

    if (_controller!.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(kDebugMode);
      (_controller!.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    unawaited(_startLoginFlow());
  }

  Future<void> _startLoginFlow() async {
    try {
      await _cookieManager?.clearCookies();
    } catch (_) {}

    try {
      await _controller?.clearCache();
    } catch (_) {}

    try {
      await _controller?.clearLocalStorage();
    } catch (_) {}

    if (!mounted) {
      return;
    }

    await _controller?.loadRequest(Uri.parse('${widget.serverBaseUrl}/login'));
  }

  Future<void> _handlePageFinished(String url) async {
    if (!mounted || _isCompleting) {
      return;
    }

    final pageState = await _detectPageState(url);
    if (!mounted || _isCompleting) {
      return;
    }

    if (pageState == 'login' && !_isSubmitting) {
      setState(() {
        _errorMessage = null;
        _isSubmitting = true;
      });

      await Future<void>.delayed(const Duration(milliseconds: 900));
      final didSubmit = await _submitLoginForm();
      if (!mounted || _isCompleting) {
        return;
      }

      if (!didSubmit) {
        _completeWithError('운영 서버 로그인 폼을 찾지 못했습니다.');
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 2200));
      final nextPageState = await _detectPageState('');
      if (!mounted || _isCompleting) {
        return;
      }

      if (nextPageState == 'login') {
        _completeWithError('로그인에 실패했습니다. 계정을 다시 확인해 주세요.');
        return;
      }

      _completeWithSuccess();
      return;
    }

    if (pageState != 'login' && _isSubmitting) {
      _completeWithSuccess();
    }
  }

  Future<String> _detectPageState(String url) async {
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('/login')) {
      return 'login';
    }
    if (lowerUrl.contains('/admin')) {
      return 'admin';
    }

    const script = '''
      (() => {
        const text = (document.body?.innerText || '').toLowerCase();
        const hasPasswordField = !!document.querySelector(
          'input[type="password"], input[autocomplete="current-password"], input[aria-label*="비밀번호"], input[placeholder*="비밀번호"]'
        );
        if (hasPasswordField) {
          return 'login';
        }
        if (
          text.includes('login') ||
          text.includes('signin') ||
          text.includes('로그인')
        ) {
          return 'login';
        }
        return 'admin';
      })();
    ''';

    try {
      final result = await _controller!.runJavaScriptReturningResult(script);
      return _normalizeJavaScriptResult(result) ?? 'admin';
    } catch (_) {
      return 'admin';
    }
  }

  Future<bool> _submitLoginForm() async {
    final encodedUserId = jsonEncode(widget.userId.trim());
    final encodedPassword = jsonEncode(widget.password);

    final script = '''
      (() => {
        try {
          const usernameValue = $encodedUserId;
          const passwordValue = $encodedPassword;
          const visible = (element) => {
            if (!element) return false;
            const style = window.getComputedStyle(element);
            const rect = element.getBoundingClientRect();
            return (
              style.display !== 'none' &&
              style.visibility !== 'hidden' &&
              style.opacity !== '0' &&
              rect.width > 0 &&
              rect.height > 0
            );
          };
          const dispatchInput = (element, value) => {
            const prototype = Object.getPrototypeOf(element);
            const valueSetter = Object.getOwnPropertyDescriptor(prototype, 'value')?.set;
            element.focus();
            if (valueSetter) {
              valueSetter.call(element, value);
            } else {
              element.value = value;
            }
            element.dispatchEvent(new Event('input', { bubbles: true }));
            element.dispatchEvent(new Event('change', { bubbles: true }));
            element.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true }));
            element.blur();
          };

          const passwordField = Array.from(
            document.querySelectorAll(
              'input[type="password"], input[autocomplete="current-password"], input[aria-label*="비밀번호"], input[placeholder*="비밀번호"]'
            )
          ).find(visible);
          if (!passwordField) {
            return 'missing-password';
          }

          const form =
            passwordField.closest('form') ||
            passwordField.parentElement?.closest('form') ||
            document.querySelector('form');
          const usernameRoot = form || document;
          const usernameCandidates = Array.from(
            usernameRoot.querySelectorAll(
              'input[type="text"], input[type="email"], input[autocomplete="username"], input[placeholder*="아이디"], input[aria-label*="아이디"], input:not([type])'
            )
          ).filter((element) => visible(element) && element !== passwordField);
          const usernameField = usernameCandidates[0];

          if (!usernameField) {
            return 'missing-username';
          }

          dispatchInput(usernameField, usernameValue);
          dispatchInput(passwordField, passwordValue);

          const submitTarget = Array.from(
            (form || document).querySelectorAll(
              'button, input[type="submit"], input[type="button"], a, [role="button"]'
            )
          ).find((element) => {
            if (!visible(element)) return false;
            const text = (
              element.textContent ||
              element.getAttribute('value') ||
              element.getAttribute('aria-label') ||
              element.getAttribute('title') ||
              ''
            ).replace(/\\s+/g, '').toLowerCase();
            return (
              text.includes('\\ub85c\\uadf8\\uc778') ||
              text.includes('login') ||
              text.includes('signin') ||
              text.includes('submit')
            );
          });

          if (submitTarget && typeof submitTarget.click === 'function') {
            submitTarget.click();
            return 'submitted';
          }

          if (form) {
            form.requestSubmit ? form.requestSubmit() : form.submit();
            return 'submitted';
          }

          return 'error';
        } catch (error) {
          return 'error';
        }
      })();
    ''';

    try {
      final result = await _controller!.runJavaScriptReturningResult(script);
      return _normalizeJavaScriptResult(result) == 'submitted';
    } catch (_) {
      return false;
    }
  }

  String? _normalizeJavaScriptResult(Object? result) {
    if (result == null) {
      return null;
    }

    final raw = result.toString().trim();
    if (raw.length >= 2 &&
        ((raw.startsWith('"') && raw.endsWith('"')) ||
            (raw.startsWith("'") && raw.endsWith("'")))) {
      return raw.substring(1, raw.length - 1);
    }
    return raw;
  }

  void _completeWithSuccess() {
    if (!mounted || _isCompleting) {
      return;
    }

    _isCompleting = true;
    Navigator.of(context).pop(
      WebLoginResult.success(
        UserSession(
          userId: widget.userId.trim(),
          displayName: 'Blossom 관리자',
          keepSignedIn: widget.keepSignedIn,
        ),
      ),
    );
  }

  void _completeWithError(String message) {
    if (!mounted || _isCompleting) {
      return;
    }

    _isCompleting = true;
    Navigator.of(context).pop(WebLoginResult.failure(message));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF27364A),
      body: SafeArea(
        child: Stack(
          children: [
            if (_controller != null)
              Opacity(
                opacity: 0.02,
                child: IgnorePointer(
                  child: WebViewWidget(controller: _controller!),
                ),
              ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '운영 서버 로그인 확인 중',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage ??
                          '현재 로그인 화면 디자인은 유지한 채\n운영 서버의 웹 로그인 과정을 내부적으로 처리하고 있습니다.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFD7E7EA),
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WebLoginResult {
  const WebLoginResult._({
    this.session,
    this.errorMessage,
  });

  const WebLoginResult.success(UserSession session)
      : this._(session: session);

  const WebLoginResult.failure(String errorMessage)
      : this._(errorMessage: errorMessage);

  final UserSession? session;
  final String? errorMessage;
}
