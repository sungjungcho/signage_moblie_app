import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../models/user_session.dart';

class MessageComposeTab extends StatefulWidget {
  const MessageComposeTab({
    super.key,
    this.initialDevices = const [
      '로비 사이니지',
      '카운터 모니터',
      '대기실 디스플레이',
      '상담실 TV',
    ],
    this.loadLiveDevices = false,
    this.serverBaseUrl,
    this.session,
  });

  final List<String> initialDevices;
  final bool loadLiveDevices;
  final String? serverBaseUrl;
  final UserSession? session;

  @override
  State<MessageComposeTab> createState() => _MessageComposeTabState();
}

class _MessageComposeTabState extends State<MessageComposeTab> {
  static const int _maxMessageLength = 500;

  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _minuteController = TextEditingController(text: '0');
  final _secondController = TextEditingController(text: '30');
  final _selectedDevices = <String>{};
  final _recentMessages = <_SentMessageRecord>[];

  late List<String> _devices;
  WebViewController? _controller;
  bool _isLoadingDevices = false;
  String? _deviceLoadMessage;
  bool _triedLiveDeviceLoad = false;
  bool _isSyncingLiveDevices = false;

  bool get _supportsWebView {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  bool get _canLoadLiveDevices =>
      widget.loadLiveDevices &&
      _supportsWebView &&
      (widget.serverBaseUrl?.isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    _devices = List<String>.from(widget.initialDevices);
    _messageController.addListener(_onMessageChanged);

    if (_canLoadLiveDevices) {
      _initLiveDeviceLoader();
    } else {
      _deviceLoadMessage = '등록된 디바이스 목록을 확인할 수 있습니다.';
    }
  }

  @override
  void dispose() {
    _messageController
      ..removeListener(_onMessageChanged)
      ..dispose();
    _minuteController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  void _onMessageChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _initLiveDeviceLoader() {
    _triedLiveDeviceLoad = true;
    _isLoadingDevices = true;
    _deviceLoadMessage = '로그인한 계정의 디바이스 목록을 불러오는 중입니다.';

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async => _loadDevicesFromServer(),
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame == false) {
              return;
            }

            setState(() {
              _isLoadingDevices = false;
              _deviceLoadMessage = '디바이스 목록을 불러오지 못했습니다.';
            });
          },
        ),
      )
      ..loadHtmlString('<html><body style="background:#fff;"></body></html>');

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(kDebugMode);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _controller = controller;
    unawaited(controller.loadRequest(Uri.parse('${widget.serverBaseUrl!}/admin')));
  }

  Future<void> _loadDevicesFromServer() async {
    final controller = _controller;
    if (controller == null || !mounted || _isSyncingLiveDevices) {
      return;
    }

    _isSyncingLiveDevices = true;
    final isAuthenticated = await _ensureAuthenticated(controller);
    if (!mounted) {
      _isSyncingLiveDevices = false;
      return;
    }

    if (!isAuthenticated) {
      setState(() {
        _isLoadingDevices = false;
        _deviceLoadMessage = '로그인 세션을 확인하지 못해 사용자 디바이스 목록을 불러오지 못했습니다.';
      });
      _isSyncingLiveDevices = false;
      return;
    }

    final pageState = await _detectPageState(controller);
    if (!mounted) {
      _isSyncingLiveDevices = false;
      return;
    }

    if (pageState == 'login') {
      setState(() {
        _isLoadingDevices = false;
        _deviceLoadMessage = '로그인 세션을 찾지 못해 디바이스 목록을 불러오지 못했습니다.';
      });
      _isSyncingLiveDevices = false;
      return;
    }

      await _clickManageStartIfPresent(controller);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _openEmergencyAlertIfPresent(controller);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final tabs = await _readTabsFromPage(controller);
      final emergencyIndex = tabs.indexWhere(_isEmergencyTab);
      if (emergencyIndex >= 0) {
        await _switchToTab(controller, tabs[emergencyIndex]);
        await Future<void>.delayed(const Duration(milliseconds: 450));
      }

      final liveDevices = await _readDeviceOptions(controller);
    if (!mounted) {
      _isSyncingLiveDevices = false;
      return;
    }

    if (liveDevices.isEmpty) {
      setState(() {
        _isLoadingDevices = false;
        _deviceLoadMessage = '등록된 디바이스 목록을 찾지 못했습니다.';
      });
      _isSyncingLiveDevices = false;
      return;
    }

      setState(() {
        _devices = liveDevices.map((item) => item.label).toList(growable: false);
        _selectedDevices.clear();
        _isLoadingDevices = false;
        _deviceLoadMessage = '로그인한 사용자 기준 디바이스 ${_devices.length}대를 불러왔습니다.';
      });
    _isSyncingLiveDevices = false;
  }

  Future<void> _reloadLiveDevices() async {
    if (!_canLoadLiveDevices || _controller == null) {
      return;
    }

    setState(() {
      _isLoadingDevices = true;
      _deviceLoadMessage = '디바이스 목록을 다시 불러오는 중입니다.';
    });

    await _controller!.loadRequest(Uri.parse('${widget.serverBaseUrl!}/admin'));
  }

  Future<String> _detectPageState(WebViewController controller) async {
    const script = '''
      (() => {
        try {
          const normalize = (value) =>
            (value || '').replace(/\\s+/g, '').trim().toLowerCase();
          const bodyText = normalize(document.body?.innerText || '');
          const passwordFields = Array.from(
            document.querySelectorAll(
              'input[type="password"], input[autocomplete="current-password"], input[aria-label*="鍮꾨?踰덊샇"], input[placeholder*="鍮꾨?踰덊샇"]'
            )
          );
          const hasVisiblePasswordField = passwordFields.some((element) => {
            const style = window.getComputedStyle(element);
            const rect = element.getBoundingClientRect();
            return (
              style.display !== 'none' &&
              style.visibility !== 'hidden' &&
              style.opacity !== '0' &&
              rect.width > 0 &&
              rect.height > 0
            );
          });

          if (
            bodyText.includes('\\ub514\\ubc14\\uc774\\uc2a4\\uc5f0\\uacb0\\ud558\\uae30') ||
            bodyText.includes('\\uad00\\ub9ac\\uc2dc\\uc791\\ud558\\uae30')
          ) {
            return 'choice';
          }

          if (hasVisiblePasswordField) {
            return 'login';
          }

          return 'admin';
        } catch (error) {
          return 'admin';
        }
      })();
    ''';

    try {
      final result = await controller.runJavaScriptReturningResult(script);
      return _normalizeJavaScriptResult(result) ?? 'admin';
    } catch (_) {
      return 'admin';
    }
  }

  Future<bool> _ensureAuthenticated(WebViewController controller) async {
    final pageState = await _detectPageState(controller);
    if (pageState != 'login') {
      return true;
    }

    final session = widget.session;
    final password = session?.loginPassword;
    if (session == null || password == null || password.isEmpty) {
      return false;
    }

    if (mounted) {
      setState(() {
        _isLoadingDevices = true;
        _deviceLoadMessage = '로그인한 사용자로 디바이스 목록을 확인하기 위해 관리자 화면에 다시 로그인하고 있습니다.';
      });
    }

    final didSubmit = await _submitLoginForm(
      controller: controller,
      userId: session.userId,
      password: password,
    );
    if (!didSubmit) {
      return false;
    }

    await Future<void>.delayed(const Duration(milliseconds: 2200));
    final nextPageState = await _detectPageState(controller);
    return nextPageState != 'login';
  }

  Future<bool> _submitLoginForm({
    required WebViewController controller,
    required String userId,
    required String password,
  }) async {
    final encodedUserId = jsonEncode(userId.trim());
    final encodedPassword = jsonEncode(password);

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
              'input[type="password"], input[autocomplete="current-password"], input[aria-label*="鍮꾨?踰덊샇"], input[placeholder*="鍮꾨?踰덊샇"]'
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
              'input[type="text"], input[type="email"], input[autocomplete="username"], input[placeholder*="?꾩씠??], input[aria-label*="?꾩씠??], input:not([type])'
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
      final result = await controller.runJavaScriptReturningResult(script);
      return _normalizeJavaScriptResult(result) == 'submitted';
    } catch (_) {
      return false;
    }
  }

  Future<void> _clickManageStartIfPresent(WebViewController controller) async {
    const script = '''
      (() => {
        try {
          const normalize = (value) =>
            (value || '').replace(/\\s+/g, '').trim().toLowerCase();
          const isVisible = (element) => {
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
          const getText = (element) =>
            normalize(
              element?.textContent ||
              element?.getAttribute?.('value') ||
              element?.getAttribute?.('aria-label') ||
              element?.getAttribute?.('title') ||
              ''
            );
          const keywords = [
            '\\uad00\\ub9ac\\uc2dc\\uc791\\ud558\\uae30',
            '\\uad00\\ub9ac\\uc2dc\\uc791',
            'manage',
          ].map(normalize);
          const candidates = Array.from(
            document.querySelectorAll(
              'button, a, [role="button"], input[type="button"], input[type="submit"]'
            )
          );

          for (const element of candidates) {
            const text = getText(element);
            if (!isVisible(element) || !keywords.some((keyword) => text.includes(keyword))) {
              continue;
            }
            element.click();
            return;
          }
        } catch (error) {}
      })();
    ''';

    try {
      await controller.runJavaScript(script);
    } catch (_) {}
  }

  Future<void> _openEmergencyAlertIfPresent(WebViewController controller) async {
    const script = '''
      (() => {
        try {
          const normalize = (value) =>
            (value || '').replace(/\\s+/g, '').trim().toLowerCase();
          const isVisible = (element) => {
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
          const targets = Array.from(
            document.querySelectorAll(
              'button, a, [role="button"], input[type="button"], input[type="submit"]'
            )
          );

          for (const element of targets) {
            const text = normalize(
              element.textContent ||
              element.getAttribute('value') ||
              element.getAttribute('aria-label') ||
              ''
            );
            if (
              isVisible(element) &&
              (text.includes('\\uae34\\uae09\\uc54c\\ub9bc') ||
               text.includes('\\uae34\\uae09\\uacf5\\uc9c0'))
            ) {
              element.click();
              return;
            }
          }
        } catch (error) {}
      })();
    ''';

    try {
      await controller.runJavaScript(script);
    } catch (_) {}
  }

  Future<List<String>> _readTabsFromPage(WebViewController controller) async {
    const script = '''
      (() => {
        try {
          const menuSelector =
            'nav, [role="navigation"], [role="tablist"], header, aside, .tabs, .tab, .menu, .nav';
          const isVisible = (element) => {
            const style = window.getComputedStyle(element);
            const rect = element.getBoundingClientRect();
            return (
              style.display !== 'none' &&
              style.visibility !== 'hidden' &&
              style.opacity !== '0' &&
              rect.width > 32 &&
              rect.height > 20 &&
              rect.bottom > 0
            );
          };
          const textOf = (element) => (element.textContent || '').replace(/\\s+/g, ' ').trim();
          const isLikelyMenu = (element) =>
            element.matches('[role="tab"]') ||
            element.getAttribute('aria-selected') !== null ||
            element.closest(menuSelector) !== null;

          const seen = new Set();
          const tabs = [];
          const candidates = document.querySelectorAll(
            '[role="tab"], button, a, [onclick], [data-state], [data-tab]'
          );

          for (const element of candidates) {
            const label = textOf(element);
            if (
              !label ||
              label.length > 24 ||
              !isVisible(element) ||
              !isLikelyMenu(element) ||
              seen.has(label)
            ) {
              continue;
            }

            seen.add(label);
            tabs.push(label);
          }

          return JSON.stringify(tabs);
        } catch (error) {
          return JSON.stringify([]);
        }
      })();
    ''';

    try {
      final result = await controller.runJavaScriptReturningResult(script);
      final payload = _normalizeJavaScriptResult(result) ?? '[]';
      final decoded = jsonDecode(payload);
      if (decoded is! List) {
        return const [];
      }
      return decoded.whereType<String>().toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _switchToTab(WebViewController controller, String label) async {
    final target = jsonEncode(label);
    try {
      await controller.runJavaScript('''
        (() => {
          try {
            const expected = $target;
            const textOf = (element) => (element.textContent || '').replace(/\\s+/g, ' ').trim();
            const candidates = document.querySelectorAll(
              '[role="tab"], button, a, [onclick], [data-state], [data-tab]'
            );

            for (const element of candidates) {
              if (textOf(element) === expected) {
                element.click();
                return;
              }
            }

            for (const element of candidates) {
              if (textOf(element).includes(expected)) {
                element.click();
                return;
              }
            }
          } catch (error) {}
        })();
      ''');
    } catch (_) {}
  }

  Future<List<_EmergencyDeviceOption>> _readDeviceOptions(
    WebViewController controller,
  ) async {
    const script = '''
      (() => {
        try {
          const normalize = (value) =>
            (value || '').replace(/\\s+/g, ' ').trim();
          const compact = (value) =>
            normalize(value).replace(/\\s+/g, '').toLowerCase();
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
              element?.getAttribute?.('aria-label') ||
              element?.getAttribute?.('title') ||
              element?.getAttribute?.('value') ||
              ''
            );
          const sendButtons = Array.from(
            document.querySelectorAll('button, input[type="button"], input[type="submit"], a')
          ).filter((element) => {
            const text = compact(textOf(element));
            return (
              visible(element) &&
              (text.includes('\\uc54c\\ub9bc\\uc804\\uc1a1') ||
               text.includes('\\uae34\\uae09\\uc54c\\ub9bc\\uc804\\uc1a1') ||
               text === '\\uc804\\uc1a1')
            );
          });
          const sendButton = sendButtons[0] || null;
          const formRoot =
            sendButton?.closest('form') ||
            sendButton?.closest('table') ||
            sendButton?.closest('.form') ||
            sendButton?.closest('.container') ||
            sendButton?.parentElement ||
            document.body;

          const selectableCandidates = Array.from(
            formRoot.querySelectorAll(
              'input[type="radio"], input[type="checkbox"], [role="radio"], [role="checkbox"], [role="option"], label, li, tr, td, [data-value], [data-id]'
            )
          );

          const options = [];
          const seen = new Set();

          for (const element of selectableCandidates) {
            const target =
              element.matches('input[type="radio"], input[type="checkbox"], [role="radio"], [role="checkbox"], [role="option"]')
                ? element
                : element.querySelector(
                    'input[type="radio"], input[type="checkbox"], [role="radio"], [role="checkbox"], [role="option"]'
                  ) || element;

            if (!target || !visible(target)) continue;

            const labelCandidates = [
              textOf(target.closest('label')),
              textOf(target.nextElementSibling),
              textOf(target.parentElement?.querySelector('label')),
              textOf(
                target.parentElement?.querySelector(
                  'span, strong, em, p, div, td'
                )
              ),
              textOf(element.matches('label') ? element : null),
            ];
            const label = labelCandidates.find((value) => value && compact(value).length >= 2);
            if (!label) continue;

            const normalizedLabel = compact(label);
            if (
              normalizedLabel.includes('\\uc804\\uc1a1') ||
              normalizedLabel.includes('\\uc124\\uc815') ||
              normalizedLabel.includes('\\ub0b4\\uc6a9') ||
              normalizedLabel.includes('\\uc54c\\ub9bc\\ub0b4\\uc6a9') ||
              normalizedLabel.includes('\\uc54c\\ub9bc\\ud45c\\uc2dc\\uc2dc\\uac04') ||
              normalizedLabel.includes('\\ud45c\\uc2dc\\uc2dc\\uac04') ||
              normalizedLabel.includes('\\ub178\\ucd9c\\uc2dc\\uac04') ||
              normalizedLabel.includes('\\uba54\\uc138\\uc9c0\\ub0b4\\uc6a9') ||
              normalizedLabel.includes('\\ub300\\uc0c1\\ub514\\ubc14\\uc774\\uc2a4') ||
              normalizedLabel.includes('\\ub300\\uc0c1\\ub514\\ubc14\\uc774\\uc2a4\\uc120\\ud0dd') ||
              normalizedLabel.includes('\\ub514\\ubc14\\uc774\\uc2a4\\ubaa9\\ub85d') ||
              normalizedLabel.includes('\\uc120\\ud0dd\\ud574\\uc8fc\\uc138\\uc694') ||
              normalizedLabel.includes('\\uac80\\uc0c9') ||
              normalizedLabel.includes('\\uc544\\uc774\\ub514') ||
              normalizedLabel.includes('\\ube44\\ubc00\\ubc88\\ud638') ||
              normalizedLabel.includes('\\uc774\\uba54\\uc77c') ||
              normalizedLabel.includes('\\uae34\\uae09\\uc54c\\ub9bc') ||
              normalizedLabel.includes('\\uacf5\\uc9c0\\uc0ac\\ud56d') ||
              seen.has(normalizedLabel)
            ) {
              continue;
            }

            const isSelected =
              !!target.checked ||
              target.getAttribute?.('aria-checked') === 'true' ||
              target.getAttribute?.('aria-selected') === 'true';

            options.push({ label, isSelected });
            seen.add(normalizedLabel);
          }

          return JSON.stringify(options);
        } catch (error) {
          return '[]';
        }
      })();
    ''';

    try {
      final result = await controller.runJavaScriptReturningResult(script);
      final normalized = _normalizeJavaScriptResult(result) ?? '[]';
      final decoded = jsonDecode(normalized);
      if (decoded is! List) {
        return const [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => _EmergencyDeviceOption(
              label: item['label']?.toString() ?? '',
              isSelected: item['isSelected'] == true,
            ),
          )
          .where((item) => item.label.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  String? _normalizeJavaScriptResult(Object? result) {
    if (result == null) {
      return null;
    }
    if (result is String) {
      final trimmed = result.trim();
      if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
        final decoded = jsonDecode(trimmed);
        return decoded is String ? decoded : trimmed;
      }
      return trimmed;
    }
    return result.toString();
  }

  bool _isEmergencyTab(String label) {
    final normalized = label.toLowerCase().replaceAll(' ', '');
    return normalized.contains('湲닿툒') &&
        (normalized.contains('?뚮┝') || normalized.contains('怨듭?'));
  }

  bool _isSelectAllDevice(String label) {
    final normalized = label.replaceAll(' ', '');
    return normalized.contains('전체') && normalized.contains('선택');
  }

  List<String> _actualDevices() {
    return _devices
        .where((device) => !_isSelectAllDevice(device))
        .toList(growable: false);
  }

  void _incrementTime(TextEditingController controller, int delta, int maxValue) {
    final currentValue = int.tryParse(controller.text) ?? 0;
    final nextValue = (currentValue + delta).clamp(0, maxValue);
    controller.text = '$nextValue';
    setState(() {});
  }

  void _toggleAllDevices(bool? checked) {
    final actualDevices = _actualDevices();
    setState(() {
      if (checked ?? false) {
        _selectedDevices
          ..clear()
          ..addAll(actualDevices);
      } else {
        _selectedDevices.clear();
      }
    });
  }

  void _toggleDevice(String device, bool? checked) {
    if (_isSelectAllDevice(device)) {
      _toggleAllDevices(checked);
      return;
    }

    setState(() {
      if (checked ?? false) {
        _selectedDevices.add(device);
      } else {
        _selectedDevices.remove(device);
      }
    });
  }

  void _resetForm() {
    _messageController.clear();
    _minuteController.text = '0';
    _secondController.text = '30';
    setState(() {
      _selectedDevices.clear();
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전송할 디바이스를 1개 이상 선택해주세요.')),
      );
      return;
    }

    final minutes = (int.tryParse(_minuteController.text) ?? 0).clamp(0, 99);
    final seconds = (int.tryParse(_secondController.text) ?? 0).clamp(0, 59);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('메세지 전송 확인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConfirmLine(label: '내용', value: _messageController.text.trim()),
            const SizedBox(height: 12),
            _ConfirmLine(label: '노출 시간', value: '${minutes}분 ${seconds}초'),
            const SizedBox(height: 12),
            _ConfirmLine(label: '디바이스', value: _selectedDevices.join(', ')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('전송'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _recentMessages.insert(
        0,
        _SentMessageRecord(
          message: _messageController.text.trim(),
          durationLabel: '${minutes}분 ${seconds}초',
          devices: _selectedDevices.toList(growable: false),
          sentAt: DateTime.now(),
        ),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('메세지 전송 요청이 준비되었습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actualDevices = _actualDevices();
    final allSelected =
        actualDevices.isNotEmpty &&
        actualDevices.every(_selectedDevices.contains);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        _HeaderCard(
          isLoadingDevices: _isLoadingDevices,
          canReload: _canLoadLiveDevices,
          message: _deviceLoadMessage ??
              '전송할 내용과 노출 시간을 입력하고 디바이스를 선택해주세요.',
          onReload: _reloadLiveDevices,
        ),
        const SizedBox(height: 18),
        _FormCard(
          formKey: _formKey,
          theme: theme,
          maxMessageLength: _maxMessageLength,
          messageController: _messageController,
          minuteController: _minuteController,
          secondController: _secondController,
          allSelected: allSelected,
          devices: _devices,
          selectedDevices: _selectedDevices,
          triedLiveDeviceLoad: _triedLiveDeviceLoad,
          onIncreaseMinute: () => _incrementTime(_minuteController, 1, 99),
          onDecreaseMinute: () => _incrementTime(_minuteController, -1, 99),
          onIncreaseSecond: () => _incrementTime(_secondController, 1, 59),
          onDecreaseSecond: () => _incrementTime(_secondController, -1, 59),
          onToggleAllDevices: _toggleAllDevices,
          onToggleDevice: _toggleDevice,
          onReset: _resetForm,
          onSubmit: _submit,
        ),
        if (_recentMessages.isNotEmpty) ...[
          const SizedBox(height: 18),
          _HistoryCard(records: _recentMessages),
        ],
        if (_canLoadLiveDevices && _controller != null)
          Offstage(
            offstage: true,
            child: IgnorePointer(
              child: SizedBox(
                width: 1,
                height: 1,
                child: WebViewWidget(controller: _controller!),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.isLoadingDevices,
    required this.canReload,
    required this.message,
    required this.onReload,
  });

  final bool isLoadingDevices;
  final bool canReload;
  final String message;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF27364A),
            Color(0xFF31506D),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F1E3448),
            blurRadius: 24,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '메세지 전송 화면',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.5,
            ),
          ),
          if (canReload) ...[
            const SizedBox(height: 18),
            if (isLoadingDevices)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            else
              FilledButton.tonal(
                onPressed: onReload,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                  foregroundColor: Colors.white,
                ),
                child: const Text('디바이스 다시 불러오기'),
              ),
          ],
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.formKey,
    required this.theme,
    required this.maxMessageLength,
    required this.messageController,
    required this.minuteController,
    required this.secondController,
    required this.allSelected,
    required this.devices,
    required this.selectedDevices,
    required this.triedLiveDeviceLoad,
    required this.onIncreaseMinute,
    required this.onDecreaseMinute,
    required this.onIncreaseSecond,
    required this.onDecreaseSecond,
    required this.onToggleAllDevices,
    required this.onToggleDevice,
    required this.onReset,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final ThemeData theme;
  final int maxMessageLength;
  final TextEditingController messageController;
  final TextEditingController minuteController;
  final TextEditingController secondController;
  final bool allSelected;
  final List<String> devices;
  final Set<String> selectedDevices;
  final bool triedLiveDeviceLoad;
  final VoidCallback onIncreaseMinute;
  final VoidCallback onDecreaseMinute;
  final VoidCallback onIncreaseSecond;
  final VoidCallback onDecreaseSecond;
  final ValueChanged<bool?> onToggleAllDevices;
  final void Function(String device, bool? checked) onToggleDevice;
  final VoidCallback onReset;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '내용',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: messageController,
              maxLength: maxMessageLength,
              minLines: 5,
              maxLines: 7,
              decoration: InputDecoration(
                hintText: '긴급하게 노출할 메세지를 입력해주세요.',
                filled: true,
                fillColor: const Color(0xFFF6FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                counterText: '',
              ),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return '메세지 내용을 입력해주세요.';
                }
                if (trimmed.length > maxMessageLength) {
                  return '메세지는 500자 이내로 입력해주세요.';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${messageController.text.length}/$maxMessageLength',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6B7B8C),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '노출 시간',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TimeNumberField(
                    label: '분',
                    controller: minuteController,
                    maxValue: 99,
                    onIncrease: onIncreaseMinute,
                    onDecrease: onDecreaseMinute,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _TimeNumberField(
                    label: '초',
                    controller: secondController,
                    maxValue: 59,
                    onIncrease: onIncreaseSecond,
                    onDecrease: onDecreaseSecond,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              '디바이스 목록',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (devices.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6FAFB),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  triedLiveDeviceLoad
                      ? '실시간 디바이스가 없습니다. 다시 불러오기를 시도해주세요.'
                      : '등록된 디바이스가 없습니다.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B7B8C),
                  ),
                ),
              )
            else
              ...[
                ...devices.map(
                  (device) => CheckboxListTile(
                    value: device.replaceAll(' ', '').contains('전체') &&
                            device.replaceAll(' ', '').contains('선택')
                        ? allSelected
                        : selectedDevices.contains(device),
                    onChanged: (checked) => onToggleDevice(device, checked),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(device),
                  ),
                ),
              ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReset,
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onSubmit,
                    child: const Text('전송'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.records,
  });

  final List<_SentMessageRecord> records;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '최근 전송 이력',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          ...records.map(
            (record) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _SentHistoryCard(record: record),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeNumberField extends StatelessWidget {
  const _TimeNumberField({
    required this.label,
    required this.controller,
    required this.maxValue,
    required this.onIncrease,
    required this.onDecrease,
  });

  final String label;
  final TextEditingController controller;
  final int maxValue;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF6FAFB),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: label,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
              ),
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed == null) {
                  return;
                }

                if (parsed > maxValue) {
                  controller.text = '$maxValue';
                  controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: controller.text.length),
                  );
                }
              },
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: onIncrease,
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
              IconButton(
                onPressed: onDecrease,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmLine extends StatelessWidget {
  const _ConfirmLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: const Color(0xFF6B7B8C),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SentHistoryCard extends StatelessWidget {
  const _SentHistoryCard({
    required this.record,
  });

  final _SentMessageRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FAFB),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            record.message,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '노출 시간: ${record.durationLabel}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF6B7B8C),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '디바이스: ${record.devices.join(', ')}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF6B7B8C),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '전송 시각: ${_formatDateTime(record.sentAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF6B7B8C),
            ),
          ),
        ],
      ),
    );
  }
}

class _SentMessageRecord {
  const _SentMessageRecord({
    required this.message,
    required this.durationLabel,
    required this.devices,
    required this.sentAt,
  });

  final String message;
  final String durationLabel;
  final List<String> devices;
  final DateTime sentAt;
}

class _EmergencyDeviceOption {
  const _EmergencyDeviceOption({
    required this.label,
    required this.isSelected,
  });

  final String label;
  final bool isSelected;
}

String _formatDateTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '${dateTime.year}.${dateTime.month}.${dateTime.day} $hour:$minute';
}



