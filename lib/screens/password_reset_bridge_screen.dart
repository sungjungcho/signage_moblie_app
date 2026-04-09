import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class PasswordResetBridgeScreen extends StatefulWidget {
  const PasswordResetBridgeScreen({
    super.key,
    required this.loginUrl,
  });

  final String loginUrl;

  @override
  State<PasswordResetBridgeScreen> createState() =>
      _PasswordResetBridgeScreenState();
}

class _PasswordResetBridgeScreenState extends State<PasswordResetBridgeScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  String? _errorMessage;

  bool get _supportsWebView {
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
    if (_supportsWebView) {
      _initController();
    } else {
      unawaited(_openExternally());
    }
  }

  Future<void> _openExternally() async {
    final opened = await launchUrl(
      Uri.parse(widget.loginUrl),
      mode: LaunchMode.externalApplication,
    );

    if (!mounted) {
      return;
    }

    if (!opened) {
      setState(() {
        _errorMessage = '비밀번호 찾기 페이지를 열지 못했습니다.';
      });
      return;
    }

    Navigator.of(context).pop();
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            await _activatePasswordReset();
          },
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame == false) {
              return;
            }
            setState(() {
              _isLoading = false;
              _errorMessage = '비밀번호 찾기 페이지를 불러오지 못했습니다.';
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.loginUrl));

    if (_controller!.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(kDebugMode);
      (_controller!.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
  }

  Future<void> _activatePasswordReset() async {
    if (!mounted || _controller == null) {
      return;
    }

    const script = '''
      (() => {
        try {
          const normalize = (value) =>
            (value || '').replace(/\\s+/g, '').trim().toLowerCase();
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
          const textOf = (element) =>
            normalize(
              element?.textContent ||
                element?.getAttribute?.('value') ||
                element?.getAttribute?.('aria-label') ||
                element?.getAttribute?.('title') ||
                ''
            );

          const targets = Array.from(
            document.querySelectorAll(
              'a, button, [role="button"], input[type="button"], input[type="submit"]'
            )
          );

          for (const element of targets) {
            const text = textOf(element);
            if (!visible(element)) continue;
            if (
              text.includes('\\ube44\\ubc00\\ubc88\\ud638\\ucc3e\\uae30') ||
              text.includes('\\ube44\\ubc88\\ucc3e\\uae30') ||
              text.includes('forgotpassword') ||
              text.includes('resetpassword') ||
              text.includes('findpassword')
            ) {
              element.click();
              return 'clicked';
            }
          }

          return 'not-found';
        } catch (error) {
          return 'error';
        }
      })();
    ''';

    try {
      final result = await _controller!.runJavaScriptReturningResult(script);
      final normalized = _normalizeJavaScriptResult(result);

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        if (normalized == 'not-found') {
          _errorMessage = '비밀번호 찾기 버튼을 자동으로 찾지 못했습니다. 화면에서 직접 선택해주세요.';
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = '비밀번호 찾기 화면 활성화에 실패했습니다.';
      });
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
      final decoded = jsonDecode(raw);
      return decoded is String ? decoded : raw;
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('비밀번호 찾기'),
      ),
      body: _controller == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorMessage ?? '비밀번호 찾기 페이지를 여는 중입니다.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Stack(
              children: [
                WebViewWidget(controller: _controller!),
                if (_isLoading)
                  Container(
                    color: Colors.white.withValues(alpha: 0.9),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                if (_errorMessage != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF27364A),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.white,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
