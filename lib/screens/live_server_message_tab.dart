import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class LiveServerMessageTab extends StatefulWidget {
  const LiveServerMessageTab({
    super.key,
    required this.serverBaseUrl,
  });

  final String serverBaseUrl;

  @override
  State<LiveServerMessageTab> createState() => _LiveServerMessageTabState();
}

class _LiveServerMessageTabState extends State<LiveServerMessageTab> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;
  List<String> _tabs = const [];
  List<_EmergencyDeviceOption> _devices = const [];

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            await _syncFromServer();
          },
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame == false) {
              return;
            }
            setState(() {
              _isLoading = false;
              _errorMessage = '운영 서버 긴급메세지 화면을 읽지 못했습니다.';
            });
          },
        ),
      )
      ..loadHtmlString('<html><body style="background:#ffffff;"></body></html>');

    if (_controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(kDebugMode);
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    unawaited(_controller.loadRequest(Uri.parse('${widget.serverBaseUrl}/admin')));
  }

  Future<void> _syncFromServer() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final pageState = await _detectPageState();
    if (!mounted) {
      return;
    }

    if (pageState == 'login') {
      setState(() {
        _isLoading = false;
        _errorMessage = '운영 서버 로그인 세션을 찾지 못했습니다. 다시 로그인해주세요.';
      });
      return;
    }

    await _clickManageStartIfPresent();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _openEmergencyAlertIfPresent();
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final tabs = await _readTabsFromPage();
    final emergencyIndex = tabs.indexWhere(_isEmergencyTab);
    if (emergencyIndex >= 0) {
      await _switchToTab(tabs[emergencyIndex]);
      await Future<void>.delayed(const Duration(milliseconds: 450));
    }

    final devices = await _readEmergencyDeviceOptionsFromPage();
    if (!mounted) {
      return;
    }

    setState(() {
      _tabs = tabs;
      _devices = devices;
      _isLoading = false;
      if (devices.isEmpty) {
        _errorMessage = '운영 서버에 연결했지만 긴급알림 디바이스 목록을 찾지 못했습니다.';
      }
    });
  }

  Future<String> _detectPageState() async {
    const script = '''
      (() => {
        try {
          const normalize = (value) =>
            (value || '').replace(/\\s+/g, '').trim().toLowerCase();
          const bodyText = normalize(document.body?.innerText || '');
          const passwordFields = Array.from(
            document.querySelectorAll('input[type="password"]')
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
      final result = await _controller.runJavaScriptReturningResult(script);
      return _normalizeJavaScriptResult(result) ?? 'admin';
    } catch (_) {
      return 'admin';
    }
  }

  Future<void> _clickManageStartIfPresent() async {
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
      await _controller.runJavaScript(script);
    } catch (_) {}
  }

  Future<List<String>> _readTabsFromPage() async {
    const script = '''
      (() => {
        try {
          const MENU_SELECTOR =
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
            element.closest(MENU_SELECTOR) !== null;

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
      final result = await _controller.runJavaScriptReturningResult(script);
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

  Future<void> _switchToTab(String label) async {
    final target = jsonEncode(label);
    await _controller.runJavaScript('''
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
  }

  Future<void> _openEmergencyAlertIfPresent() async {
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
      await _controller.runJavaScript(script);
    } catch (_) {}
  }

  Future<List<_EmergencyDeviceOption>> _readEmergencyDeviceOptionsFromPage() async {
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
              textOf(target.parentElement),
              textOf(target.closest('td')),
              textOf(target.closest('tr')),
              textOf(element),
            ];
            const label = labelCandidates.find((value) => value && compact(value).length >= 2);
            if (!label) continue;

            const normalizedLabel = compact(label);
            if (
              normalizedLabel.includes('\\uc804\\uc1a1') ||
              normalizedLabel.includes('\\uc124\\uc815') ||
              normalizedLabel.includes('\\uae34\\uae09\\uc54c\\ub9bc') ||
              normalizedLabel.includes('\\uacf5\\uc9c0\\uc0ac\\ud56d') ||
              seen.has(normalizedLabel)
            ) {
              continue;
            }

            let id = target.getAttribute?.('data-signage-device-option');
            if (!id) {
              id = `signage-device-\${options.length + 1}`;
              target.setAttribute?.('data-signage-device-option', id);
            }

            const isSelected =
              !!target.checked ||
              target.getAttribute?.('aria-checked') === 'true' ||
              target.getAttribute?.('aria-selected') === 'true';

            options.push({ id, label, isSelected });
            seen.add(normalizedLabel);
          }

          return JSON.stringify(options);
        } catch (error) {
          return '[]';
        }
      })();
    ''';

    try {
      final result = await _controller.runJavaScriptReturningResult(script);
      final normalized = _normalizeJavaScriptResult(result) ?? '[]';
      final decoded = jsonDecode(normalized);
      if (decoded is! List) {
        return const [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => _EmergencyDeviceOption(
              id: item['id']?.toString() ?? '',
              label: item['label']?.toString() ?? '',
              isSelected: item['isSelected'] == true,
            ),
          )
          .where((item) => item.id.isNotEmpty && item.label.isNotEmpty)
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
    return normalized.contains('긴급') && normalized.contains('알림');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        _StatusHero(
          isLoading: _isLoading,
          errorMessage: _errorMessage,
          tabCount: _tabs.length,
          deviceCount: _devices.length,
          onRetry: () {
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
            unawaited(
              _controller.loadRequest(Uri.parse('${widget.serverBaseUrl}/admin')),
            );
          },
        ),
        const SizedBox(height: 18),
        _InfoBlock(
          title: '운영 서버에서 확인된 메뉴',
          subtitle: _tabs.isEmpty ? '아직 읽은 메뉴가 없습니다.' : _tabs.join(' | '),
          icon: Icons.tab_rounded,
          accentColor: const Color(0xFF2F7AEE),
        ),
        const SizedBox(height: 14),
        for (final device in _devices) ...[
          _DeviceCard(device: device),
          const SizedBox(height: 12),
        ],
        if (_devices.isEmpty && !_isLoading)
          const _InfoBlock(
            title: '공지사항 탭은 아직 목업 데이터 유지',
            subtitle: '현재 확인한 운영 서버 관리자 앱 소스에서는 공지사항 목록을 동일한 방식으로 읽어오는 지점이 바로 보이지 않아, 다음 단계에서 별도로 연결이 필요합니다.',
            icon: Icons.info_outline_rounded,
            accentColor: Color(0xFFE98BB2),
          ),
        const SizedBox(height: 160),
        Opacity(
          opacity: 0.01,
          child: IgnorePointer(
            child: SizedBox(
              width: 1,
              height: 1,
              child: WebViewWidget(controller: _controller),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({
    required this.isLoading,
    required this.errorMessage,
    required this.tabCount,
    required this.deviceCount,
    required this.onRetry,
  });

  final bool isLoading;
  final String? errorMessage;
  final int tabCount;
  final int deviceCount;
  final VoidCallback onRetry;

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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '운영 서버 긴급메세지 연동',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            errorMessage ??
                (isLoading
                    ? '로그인 세션을 유지한 상태로 /admin 화면의 긴급알림 정보를 읽는 중입니다.'
                    : '실서버에서 탭 $tabCount개, 디바이스 $deviceCount개를 확인했습니다.'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              else
                FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF27364A),
                  ),
                  child: const Text('다시 읽기'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accentColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5E7186),
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
  });

  final _EmergencyDeviceOption device;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = device.isSelected
        ? const Color(0xFF25C1AE)
        : const Color(0xFF2F7AEE);

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
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              device.isSelected ? Icons.check_circle_outline : Icons.tv_outlined,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  device.isSelected ? '현재 웹 관리자 화면에서 선택됨' : '선택 가능한 디바이스',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF718396),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyDeviceOption {
  const _EmergencyDeviceOption({
    required this.id,
    required this.label,
    required this.isSelected,
  });

  final String id;
  final String label;
  final bool isSelected;
}
