import 'dart:async';

import 'package:flutter/material.dart';

import '../models/signage_item.dart';
import '../models/user_session.dart';
import '../services/api_client.dart';
import '../services/live_message_api_service.dart';

String _formatShortDate(DateTime? value) {
  if (value == null) return '미설정';
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year.$month.$day';
}

String _buildNoticePreviewTitle(String content) {
  final normalized = content.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) return '공지사항';
  if (normalized.length <= 18) return normalized;
  return '${normalized.substring(0, 18)}...';
}

const List<String> _noticeColorOptions = <String>[
  '#000000',
  '#0F172A',
  '#111827',
  '#1F2937',
  '#FFFFFF',
  '#E2E8F0',
  '#FDE68A',
  '#FECDD3',
  '#CCFBF1',
  '#EDE9FE',
];

Color _hexToColor(String hex) {
  final normalized = hex.replaceAll('#', '').trim().toUpperCase();
  final sixDigit = normalized.length == 6 ? normalized : '000000';
  return Color(int.parse('FF$sixDigit', radix: 16));
}

String _noticeModeSummary(_NoticeDisplaySettings settings) {
  if (settings.mode == _NoticeDisplayMode.ticker) {
    return '높이 ${settings.tickerHeight}px · ${settings.tickerDirection.label}';
  }
  if (settings.mode == _NoticeDisplayMode.sidePanel) {
    return '너비 ${settings.sidePanelWidth}px';
  }
  return '팝업 미리보기';
}

String _noticeModeApiValue(_NoticeDisplayMode mode) {
  switch (mode) {
    case _NoticeDisplayMode.ticker:
      return 'ticker';
    case _NoticeDisplayMode.sidePanel:
      return 'side_panel';
    case _NoticeDisplayMode.popupCycle:
      return 'popup_cycle';
  }
}

String _tickerDirectionApiValue(_NoticeTickerDirection direction) {
  switch (direction) {
    case _NoticeTickerDirection.staticText:
      return 'static';
    case _NoticeTickerDirection.rtl:
      return 'rtl';
    case _NoticeTickerDirection.ltr:
      return 'ltr';
  }
}

String _fontFamilyApiValue(_NoticeFontFamilyOption fontFamily) {
  switch (fontFamily) {
    case _NoticeFontFamilyOption.arial:
      return 'Arial, Helvetica, sans-serif';
    case _NoticeFontFamilyOption.trebuchet:
      return '"Trebuchet MS", Helvetica, sans-serif';
    case _NoticeFontFamilyOption.segoe:
      return '"Segoe UI", Arial, sans-serif';
    case _NoticeFontFamilyOption.times:
      return '"Times New Roman", Times, serif';
    case _NoticeFontFamilyOption.georgia:
      return 'Georgia, serif';
    case _NoticeFontFamilyOption.courier:
      return '"Courier New", Courier, monospace';
  }
}

class NoticeManageTab extends StatefulWidget {
  const NoticeManageTab({
    super.key,
    required this.initialItems,
    this.loadLiveDevices = false,
    this.serverBaseUrl,
    this.session,
  });

  final List<SignageItem> initialItems;
  final bool loadLiveDevices;
  final String? serverBaseUrl;
  final UserSession? session;

  @override
  State<NoticeManageTab> createState() => _NoticeManageTabState();
}

class _NoticeManageTabState extends State<NoticeManageTab> {
  static const String _allDevices = '__all__';

  static const List<_DeviceOption> _fallbackDevices = [
    _DeviceOption(id: _allDevices, label: '전체 디바이스'),
    _DeviceOption(id: 'board-1', label: '게시판 A'),
    _DeviceOption(id: 'board-2', label: '게시판 B'),
    _DeviceOption(id: 'board-3', label: '게시판 C'),
    _DeviceOption(id: 'lobby-main', label: '로비 메인'),
    _DeviceOption(id: 'test-260331', label: '테스트 260331'),
  ];

  final _searchController = TextEditingController();
  final _contentController = TextEditingController();

  late final List<_ManagedNotice> _notices;
  late List<_DeviceOption> _devices;

  String _selectedDeviceId = _allDevices;
  String? _editingNoticeId;
  String? _previewNoticeId;
  bool _showEditor = false;
  bool _isLoadingDevices = false;
  bool _isLoadingNotices = false;
  bool _isSavingNotice = false;
  bool _isApplyingNotice = false;
  bool _isSyncingLiveDevices = false;
  String? _deviceLoadMessage;
  String? _noticeLoadMessage;

  _NoticeDisplaySettings _displaySettings = const _NoticeDisplaySettings();
  _NoticeDraft _draft = _NoticeDraft.empty();

  bool get _canLoadLiveDevices =>
      widget.loadLiveDevices &&
      (widget.serverBaseUrl?.isNotEmpty ?? false) &&
      (widget.session?.userId.trim().isNotEmpty ?? false) &&
      (widget.session?.loginPassword?.isNotEmpty ?? false);

  List<_DeviceOption> get _selectableDevices => _devices
      .where((device) => device.id != _allDevices)
      .toList(growable: false);

  bool get _isDeviceSelected => _selectedDeviceId != _allDevices;

  _ManagedNotice? get _previewNotice {
    final previewId = _previewNoticeId;
    if (previewId == null) return null;
    for (final notice in _notices) {
      if (notice.id == previewId) return notice;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _devices = List<_DeviceOption>.from(_fallbackDevices);
    _notices = <_ManagedNotice>[];

    _searchController.addListener(() => setState(() {}));
    _contentController.addListener(() {
      if (mounted && _showEditor) setState(() {});
    });

    if (_canLoadLiveDevices) {
      _devices = const [_DeviceOption(id: _allDevices, label: '전체 디바이스')];
      _isLoadingDevices = true;
      _deviceLoadMessage = '로그인한 계정의 디바이스 목록을 불러오는 중입니다.';
      unawaited(_loadDevicesFromServer());
    } else {
      _deviceLoadMessage = '현재 목록은 테스트용 디바이스입니다.';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  String _defaultDraftDeviceId() {
    if (_selectedDeviceId != _allDevices &&
        _devices.any((device) => device.id == _selectedDeviceId)) {
      return _selectedDeviceId;
    }
    if (_selectableDevices.isNotEmpty) return _selectableDevices.first.id;
    return _allDevices;
  }

  Future<String> _authenticateNoticeApi() async {
    final username = widget.session?.userId.trim() ?? '';
    final password = widget.session?.loginPassword ?? '';
    if (username.isEmpty || password.isEmpty || widget.serverBaseUrl == null) {
      throw const ApiException('로그인 정보가 없어 공지사항을 불러올 수 없습니다.');
    }

    final apiService = LiveMessageApiService(baseUrl: widget.serverBaseUrl!);
    return apiService.signIn(username: username, password: password);
  }

  LiveMessageApiService _noticeApi() {
    final baseUrl = widget.serverBaseUrl;
    if (baseUrl == null || baseUrl.trim().isEmpty) {
      throw const ApiException('서버 주소가 없어 공지사항 API를 호출할 수 없습니다.');
    }
    return LiveMessageApiService(baseUrl: baseUrl);
  }

  void _replaceNotices(List<_ManagedNotice> notices) {
    _notices
      ..clear()
      ..addAll(notices);
    if (_previewNoticeId != null &&
        !_notices.any((notice) => notice.id == _previewNoticeId)) {
      _previewNoticeId = _notices.isEmpty ? null : _notices.first.id;
    } else if (_previewNoticeId == null && _notices.isNotEmpty) {
      _previewNoticeId = _notices.first.id;
    }
  }

  List<_ManagedNotice> _mapLiveNotices(
    List<LiveNotice> notices,
    Map<String, String> deviceLabelById,
  ) {
    return notices
        .map(
          (notice) => _ManagedNotice(
            id: notice.id,
            title: notice.title,
            content: notice.content,
            category: notice.category,
            deviceId: notice.deviceId,
            deviceLabel: deviceLabelById[notice.deviceId] ?? notice.deviceId,
            favorite: notice.favorite,
            active: notice.active,
            priority: notice.priority,
            fontSize: notice.fontSize,
            createdAt: notice.createdAt,
            updatedAt: notice.updatedAt,
            usageCount: notice.usageCount,
            lastUsedAt: notice.lastUsedAt,
            startAt: notice.startAt,
            endAt: notice.endAt,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _loadNoticesFromServer({String? authToken}) async {
    if (!mounted || !_canLoadLiveDevices) return;

    setState(() {
      _isLoadingNotices = true;
      _noticeLoadMessage = '공지사항 목록을 불러오는 중입니다.';
    });

    try {
      final token = authToken ?? await _authenticateNoticeApi();
      final apiService = _noticeApi();
      final devices = _selectableDevices;
      if (devices.isEmpty) {
        if (!mounted) return;
        setState(() {
          _replaceNotices(const []);
          _isLoadingNotices = false;
          _noticeLoadMessage = '등록된 디바이스가 없어 공지사항 목록이 비어 있습니다.';
        });
        return;
      }

      final deviceLabelById = {
        for (final device in devices) device.id: device.label,
      };
      final results = await Future.wait<List<LiveNotice>>(
        devices.map(
          (device) =>
              apiService.fetchNotices(authToken: token, deviceId: device.id),
        ),
      );
      final mergedById = <String, LiveNotice>{};
      for (final items in results) {
        for (final notice in items) {
          mergedById[notice.id] = notice;
        }
      }
      final merged = mergedById.values.toList(growable: false);

      if (!mounted) return;
      setState(() {
        _replaceNotices(_mapLiveNotices(merged, deviceLabelById));
        _isLoadingNotices = false;
        _noticeLoadMessage =
            merged.isEmpty
                ? '등록된 공지사항이 없습니다.'
                : '서버에 등록된 공지사항 ${merged.length}건을 불러왔습니다.';
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _replaceNotices(const []);
        _isLoadingNotices = false;
        _noticeLoadMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _replaceNotices(const []);
        _isLoadingNotices = false;
        _noticeLoadMessage = '공지사항 목록을 불러오지 못했습니다.';
      });
    }
  }

  Future<void> _loadDevicesFromServer() async {
    if (!mounted || _isSyncingLiveDevices) return;

    _isSyncingLiveDevices = true;
    try {
      final username = widget.session?.userId.trim() ?? '';
      final password = widget.session?.loginPassword ?? '';
      if (username.isEmpty ||
          password.isEmpty ||
          widget.serverBaseUrl == null) {
        throw const ApiException('로그인 정보가 없어 디바이스 목록을 불러올 수 없습니다.');
      }

      final apiService = LiveMessageApiService(baseUrl: widget.serverBaseUrl!);
      final authToken = await apiService.signIn(
        username: username,
        password: password,
      );
      final liveDevices = await apiService.fetchDevices(authToken: authToken);

      if (!mounted) return;
      setState(() {
        _devices = [
          const _DeviceOption(id: _allDevices, label: '전체 디바이스'),
          ...liveDevices.map(
            (device) => _DeviceOption(id: device.id, label: device.name),
          ),
        ];
        if (!_devices.any((device) => device.id == _selectedDeviceId)) {
          _selectedDeviceId = _allDevices;
        }
        if (!_selectableDevices.any((device) => device.id == _draft.deviceId)) {
          _draft = _draft.copyWith(deviceId: _defaultDraftDeviceId());
        }
        _isLoadingDevices = false;
        _deviceLoadMessage =
            liveDevices.isEmpty
                ? '등록된 디바이스를 찾지 못했습니다.'
                : '로그인한 사용자 기준 디바이스 ${liveDevices.length}대를 불러왔습니다.';
      });
      await _loadNoticesFromServer(authToken: authToken);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _devices = List<_DeviceOption>.from(_fallbackDevices);
        _selectedDeviceId = _allDevices;
        _draft = _draft.copyWith(deviceId: _defaultDraftDeviceId());
        _isLoadingDevices = false;
        _deviceLoadMessage = '${error.message} 테스트용 목록을 표시합니다.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _devices = List<_DeviceOption>.from(_fallbackDevices);
        _selectedDeviceId = _allDevices;
        _draft = _draft.copyWith(deviceId: _defaultDraftDeviceId());
        _isLoadingDevices = false;
        _deviceLoadMessage = '디바이스 목록을 불러오지 못해 테스트용 목록을 표시합니다.';
      });
    } finally {
      _isSyncingLiveDevices = false;
    }
  }

  Future<void> _reloadLiveDevices() async {
    if (!_canLoadLiveDevices) return;
    setState(() {
      _isLoadingDevices = true;
      _deviceLoadMessage = '디바이스 목록을 다시 불러오는 중입니다.';
    });
    await _loadDevicesFromServer();
  }

  List<_ManagedNotice> get _filteredNotices {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _notices
        .where((notice) {
          final haystack =
              '${notice.title} ${notice.content} ${notice.category} ${notice.deviceLabel}'
                  .toLowerCase();
          return query.isEmpty || haystack.contains(query);
        })
        .toList(growable: false);

    filtered.sort((a, b) {
      final priorityCompare = b.priority.compareTo(a.priority);
      if (priorityCompare != 0) return priorityCompare;

      final favoriteCompare = b.favoriteFlag.compareTo(a.favoriteFlag);
      if (favoriteCompare != 0) return favoriteCompare;

      final bLastUsed = b.lastUsedAt ?? b.createdAt;
      final aLastUsed = a.lastUsedAt ?? a.createdAt;
      final lastUsedCompare = bLastUsed.compareTo(aLastUsed);
      if (lastUsedCompare != 0) return lastUsedCompare;

      return b.createdAt.compareTo(a.createdAt);
    });

    return filtered;
  }

  void _toggleEditor([_ManagedNotice? notice]) {
    setState(() {
      if (notice == null) {
        _editingNoticeId = null;
        _draft = _NoticeDraft.empty(deviceId: _defaultDraftDeviceId());
        _contentController.clear();
      } else {
        _editingNoticeId = notice.id;
        _previewNoticeId = notice.id;
        _draft = _NoticeDraft.fromNotice(notice);
        _contentController.text = notice.content;
      }
      _showEditor = !_showEditor || notice != null;
    });
  }

  void _selectPreviewNotice(_ManagedNotice notice) {
    setState(() {
      _previewNoticeId = notice.id;
    });
  }

  Future<void> _saveNotice() async {
    final previousId = _editingNoticeId;
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      await showDialog<void>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('필수 입력'),
              content: const Text('공지 내용은 필수 입력입니다.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('확인'),
                ),
              ],
            ),
      );
      return;
    }

    final previousNotice =
        previousId == null
            ? null
            : _notices.firstWhere((e) => e.id == previousId);
    if (previousNotice == null && !_isDeviceSelected) {
      await showDialog<void>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('디바이스 선택'),
              content: const Text('상단에서 공지사항을 등록할 디바이스를 먼저 선택해 주세요.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('확인'),
                ),
              ],
            ),
      );
      return;
    }

    final targetDeviceId = previousNotice?.deviceId ?? _selectedDeviceId;
    if (!_canLoadLiveDevices) {
      final notice = _ManagedNotice(
        id: previousId ?? 'notice-${DateTime.now().microsecondsSinceEpoch}',
        title: '',
        content: content,
        category: previousNotice?.category ?? '일반',
        deviceId: targetDeviceId,
        deviceLabel: _deviceLabelFor(targetDeviceId),
        favorite: _draft.favorite,
        active: _draft.active,
        priority: _draft.priority,
        fontSize: _draft.fontSize.round(),
        createdAt: previousNotice?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        usageCount: previousNotice?.usageCount ?? 0,
        lastUsedAt: previousNotice?.lastUsedAt,
        startAt: previousNotice?.startAt,
        endAt: previousNotice?.endAt,
      );
      setState(() {
        if (previousId == null) {
          _notices.insert(0, notice);
        } else {
          final index = _notices.indexWhere((item) => item.id == previousId);
          if (index >= 0) _notices[index] = notice;
        }
        _showEditor = false;
        _editingNoticeId = null;
        _draft = _NoticeDraft.empty(deviceId: _selectedDeviceId);
        _contentController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(previousId == null ? '공지사항을 등록했습니다.' : '공지사항을 저장했습니다.'),
        ),
      );
      return;
    }

    setState(() => _isSavingNotice = true);
    try {
      final token = await _authenticateNoticeApi();
      final apiService = _noticeApi();
      if (previousId == null) {
        await apiService.createNotice(
          authToken: token,
          deviceId: targetDeviceId,
          content: content,
          active: _draft.active,
          priority: _draft.priority,
          fontSize: _draft.fontSize.round(),
        );
      } else {
        await apiService.updateNotice(
          authToken: token,
          deviceId: targetDeviceId,
          noticeId: previousId,
          content: content,
          favorite: _draft.favorite,
          active: _draft.active,
          priority: _draft.priority,
          fontSize: _draft.fontSize.round(),
        );
      }

      if (!mounted) return;
      setState(() {
        _showEditor = false;
        _editingNoticeId = null;
        _draft = _NoticeDraft.empty(deviceId: _selectedDeviceId);
        _contentController.clear();
      });
      await _loadNoticesFromServer(authToken: token);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(previousId == null ? '공지사항을 등록했습니다.' : '공지사항을 저장했습니다.'),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('공지사항 저장에 실패했습니다.')));
    } finally {
      if (mounted) setState(() => _isSavingNotice = false);
    }
  }

  Future<void> _registerNotice(_ManagedNotice notice) async {
    if (!_isDeviceSelected) {
      await showDialog<void>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('디바이스 선택'),
              content: const Text('상단에서 공지사항을 등록할 디바이스를 먼저 선택해 주세요.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('확인'),
                ),
              ],
            ),
      );
      return;
    }

    final targetDeviceId = _selectedDeviceId;
    if (!_canLoadLiveDevices) {
      final copiedNotice = _ManagedNotice(
        id: 'notice-${DateTime.now().microsecondsSinceEpoch}',
        title: notice.title,
        content: notice.content,
        category: notice.category,
        deviceId: targetDeviceId,
        deviceLabel: _deviceLabelFor(targetDeviceId),
        favorite: notice.favorite,
        active: notice.active,
        priority: notice.priority,
        fontSize: notice.fontSize,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        usageCount: 0,
        lastUsedAt: null,
        startAt: notice.startAt,
        endAt: notice.endAt,
      );
      setState(() {
        _notices.insert(0, copiedNotice);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_deviceLabelFor(targetDeviceId)}에 공지사항을 등록했습니다.'),
        ),
      );
      return;
    }

    try {
      final token = await _authenticateNoticeApi();
      await _noticeApi().createNotice(
        authToken: token,
        deviceId: targetDeviceId,
        content: notice.content,
        active: notice.active,
        priority: notice.priority,
        fontSize: notice.fontSize,
      );
      await _loadNoticesFromServer(authToken: token);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_deviceLabelFor(targetDeviceId)}에 공지사항을 등록했습니다.'),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('공지사항 등록에 실패했습니다.')));
    }
  }

  Future<void> _deleteNoticeLocal(_ManagedNotice notice) async {
    setState(() {
      _notices.removeWhere((item) => item.id == notice.id);
      if (_editingNoticeId == notice.id) {
        _showEditor = false;
        _editingNoticeId = null;
        _draft = _NoticeDraft.empty(deviceId: _selectedDeviceId);
        _contentController.clear();
      }
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('공지사항을 삭제했습니다.')));
  }

  void _toggleFavoriteLocal(_ManagedNotice notice) {
    setState(() {
      final index = _notices.indexWhere((item) => item.id == notice.id);
      if (index < 0) return;
      _notices[index] = notice.copyWith(
        favorite: !notice.favorite,
        updatedAt: DateTime.now(),
      );
    });
  }

  void _toggleActiveLocal(_ManagedNotice notice) {
    setState(() {
      final index = _notices.indexWhere((item) => item.id == notice.id);
      if (index < 0) return;
      _notices[index] = notice.copyWith(
        active: !notice.active,
        updatedAt: DateTime.now(),
      );
    });
  }

  void _markAsSentLocal(_ManagedNotice notice) {
    setState(() {
      final index = _notices.indexWhere((item) => item.id == notice.id);
      if (index < 0) return;
      _notices[index] = notice.copyWith(
        lastUsedAt: DateTime.now(),
        usageCount: notice.usageCount + 1,
        updatedAt: DateTime.now(),
      );
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('긴급 전송 이력을 반영했습니다.')));
  }

  void _cancelNoticesForDeviceLocal() {
    if (!_isDeviceSelected) return;
    setState(() {
      _notices.removeWhere((notice) => notice.deviceId == _selectedDeviceId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_deviceLabelFor(_selectedDeviceId)}의 공지사항을 모두 취소했습니다.',
        ),
      ),
    );
  }

  Future<void> _deleteNotice(_ManagedNotice notice) async {
    if (!_canLoadLiveDevices) {
      await _deleteNoticeLocal(notice);
      return;
    }
    try {
      final token = await _authenticateNoticeApi();
      await _noticeApi().deleteNotice(
        authToken: token,
        deviceId: notice.deviceId,
        noticeId: notice.id,
      );
      if (!mounted) return;
      if (_editingNoticeId == notice.id) {
        setState(() {
          _showEditor = false;
          _editingNoticeId = null;
          _draft = _NoticeDraft.empty(deviceId: _selectedDeviceId);
          _contentController.clear();
        });
      }
      await _loadNoticesFromServer(authToken: token);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('공지사항을 삭제했습니다.')));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('공지사항 삭제에 실패했습니다.')));
    }
  }

  Future<void> _toggleFavorite(_ManagedNotice notice) async {
    if (!_canLoadLiveDevices) {
      _toggleFavoriteLocal(notice);
      return;
    }
    try {
      final token = await _authenticateNoticeApi();
      await _noticeApi().updateNotice(
        authToken: token,
        deviceId: notice.deviceId,
        noticeId: notice.id,
        content: notice.content,
        favorite: !notice.favorite,
        active: notice.active,
        priority: notice.priority,
        fontSize: notice.fontSize,
      );
      await _loadNoticesFromServer(authToken: token);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('즐겨찾기 변경에 실패했습니다.')));
    }
  }

  Future<void> _toggleActive(_ManagedNotice notice) async {
    if (!_canLoadLiveDevices) {
      _toggleActiveLocal(notice);
      return;
    }
    try {
      final token = await _authenticateNoticeApi();
      await _noticeApi().updateNotice(
        authToken: token,
        deviceId: notice.deviceId,
        noticeId: notice.id,
        content: notice.content,
        favorite: notice.favorite,
        active: !notice.active,
        priority: notice.priority,
        fontSize: notice.fontSize,
      );
      await _loadNoticesFromServer(authToken: token);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('활성 상태 변경에 실패했습니다.')));
    }
  }

  Future<void> _markAsSent(_ManagedNotice notice) async {
    if (!_canLoadLiveDevices) {
      _markAsSentLocal(notice);
      return;
    }
    try {
      final token = await _authenticateNoticeApi();
      await _noticeApi().touchNoticeUsage(
        authToken: token,
        deviceId: notice.deviceId,
        noticeId: notice.id,
      );
      await _loadNoticesFromServer(authToken: token);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('긴급 전송 이력을 반영했습니다.')));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('긴급 전송 이력 반영에 실패했습니다.')));
    }
  }

  Future<void> _cancelNoticesForDevice() async {
    if (!_isDeviceSelected) return;
    if (!_canLoadLiveDevices) {
      _cancelNoticesForDeviceLocal();
      return;
    }
    try {
      final token = await _authenticateNoticeApi();
      await _noticeApi().deleteAllNoticesForDevice(
        authToken: token,
        deviceId: _selectedDeviceId,
      );
      await _loadNoticesFromServer(authToken: token);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_deviceLabelFor(_selectedDeviceId)}의 공지사항을 모두 취소했습니다.',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('공지사항 일괄 취소에 실패했습니다.')));
    }
  }

  Future<void> _applyPreviewNotice() async {
    if (!_isDeviceSelected) {
      await showDialog<void>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('디바이스 선택'),
              content: const Text('상단에서 공지사항을 적용할 디바이스를 먼저 선택해 주세요.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('확인'),
                ),
              ],
            ),
      );
      return;
    }

    final notice = _previewNotice;
    if (notice == null) {
      await showDialog<void>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('공지사항 선택'),
              content: const Text('적용할 공지사항을 먼저 선택해 주세요.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('확인'),
                ),
              ],
            ),
      );
      return;
    }

    final targetDeviceId = _selectedDeviceId;
    final targetDeviceLabel = _deviceLabelFor(targetDeviceId);

    if (!_canLoadLiveDevices) {
      setState(() {
        final index = _notices.indexWhere(
          (item) => item.id == notice.id && item.deviceId == targetDeviceId,
        );

        if (index >= 0) {
          final current = _notices[index];
          _notices[index] = current.copyWith(
            active: true,
            lastUsedAt: DateTime.now(),
            usageCount: current.usageCount + 1,
            updatedAt: DateTime.now(),
          );
          _previewNoticeId = current.id;
          return;
        }

        final appliedNotice = _ManagedNotice(
          id:
              notice.deviceId == targetDeviceId
                  ? notice.id
                  : 'notice-${DateTime.now().microsecondsSinceEpoch}',
          title: notice.title,
          content: notice.content,
          category: notice.category,
          deviceId: targetDeviceId,
          deviceLabel: targetDeviceLabel,
          favorite: notice.favorite,
          active: true,
          priority: notice.priority,
          fontSize: notice.fontSize,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          usageCount: notice.usageCount + 1,
          lastUsedAt: DateTime.now(),
          startAt: notice.startAt,
          endAt: notice.endAt,
        );

        if (notice.deviceId == targetDeviceId) {
          final sameDeviceIndex = _notices.indexWhere(
            (item) => item.id == notice.id,
          );
          if (sameDeviceIndex >= 0) {
            _notices[sameDeviceIndex] = appliedNotice;
          } else {
            _notices.insert(0, appliedNotice);
          }
        } else {
          _notices.insert(0, appliedNotice);
        }
        _previewNoticeId = appliedNotice.id;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$targetDeviceLabel에 공지사항을 적용했습니다.')),
      );
      return;
    }

    setState(() => _isApplyingNotice = true);
    try {
      final token = await _authenticateNoticeApi();
      final apiService = _noticeApi();
      final displaySettingsPayload = _displaySettings.toApiJson();

      String appliedNoticeId = notice.id;
      if (notice.deviceId == targetDeviceId) {
        final updated = await apiService.updateNotice(
          authToken: token,
          deviceId: targetDeviceId,
          noticeId: notice.id,
          content: notice.content,
          favorite: notice.favorite,
          active: true,
          priority: notice.priority,
          fontSize: notice.fontSize,
        );
        appliedNoticeId = updated.id;
      } else {
        final created = await apiService.createNotice(
          authToken: token,
          deviceId: targetDeviceId,
          content: notice.content,
          active: true,
          priority: notice.priority,
          fontSize: notice.fontSize,
        );
        appliedNoticeId = created.id;
      }

      await apiService.updateDisplaySettings(
        authToken: token,
        deviceId: targetDeviceId,
        settings: displaySettingsPayload,
      );
      await apiService.applyDisplaySettings(
        authToken: token,
        deviceId: targetDeviceId,
      );

      await apiService.touchNoticeUsage(
        authToken: token,
        deviceId: targetDeviceId,
        noticeId: appliedNoticeId,
      );
      await _loadNoticesFromServer(authToken: token);
      if (!mounted) return;
      setState(() {
        _previewNoticeId = appliedNoticeId;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$targetDeviceLabel에 공지사항을 적용했습니다.')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('공지 적용에 실패했습니다.')));
    } finally {
      if (mounted) setState(() => _isApplyingNotice = false);
    }
  }

  String _deviceLabelFor(String deviceId) {
    return _devices
        .firstWhere(
          (device) => device.id == deviceId,
          orElse: () => const _DeviceOption(id: '', label: '미확인 디바이스'),
        )
        .label;
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF6FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notices = _filteredNotices;
    final previewNotice = _previewNotice;
    final draftPreviewContent = _contentController.text.trim();
    final useDraftPreview = _showEditor && draftPreviewContent.isNotEmpty;
    final previewTitle =
        useDraftPreview
            ? _buildNoticePreviewTitle(draftPreviewContent)
            : _buildNoticePreviewTitle(previewNotice?.content ?? '');
    final previewContent =
        useDraftPreview
            ? draftPreviewContent
            : (previewNotice?.content ??
                '입력 중인 공지 내용이나 선택한 공지사항이 이 영역에 표시됩니다.');
    final previewFontSize =
        useDraftPreview
            ? _draft.fontSize.round()
            : (previewNotice?.fontSize ?? _draft.fontSize.round());

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '디바이스 선택',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_canLoadLiveDevices)
                    IconButton(
                      tooltip: '디바이스 새로고침',
                      onPressed: _isLoadingDevices ? null : _reloadLiveDevices,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedDeviceId,
                decoration: _inputDecoration('공지 대상 디바이스를 선택해 주세요'),
                items: _devices
                    .map(
                      (device) => DropdownMenuItem<String>(
                        value: device.id,
                        child: Text(device.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedDeviceId = value;
                    _draft = _draft.copyWith(deviceId: value);
                    _showEditor = false;
                    _editingNoticeId = null;
                  });
                },
              ),
              if (_deviceLoadMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _deviceLoadMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF475569),
                  ),
                ),
              ],
              if (_isLoadingDevices) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(minHeight: 3),
              ],
            ],
          ),
        ),
        if (_isDeviceSelected) ...[
          const SizedBox(height: 18),
          _SectionCard(
            accentColor: const Color(0xFF0EA5B7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '디스플레이 공지 표시 방식',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: 280,
                      child: DropdownButtonFormField<_NoticeDisplayMode>(
                        value: _displaySettings.mode,
                        decoration: _inputDecoration('표시 모드를 선택해 주세요'),
                        items: _NoticeDisplayMode.values
                            .map(
                              (mode) => DropdownMenuItem<_NoticeDisplayMode>(
                                value: mode,
                                child: Text(mode.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(
                            () =>
                                _displaySettings = _displaySettings.copyWith(
                                  mode: value,
                                ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: 280,
                      child: _StepperField(
                        label: '최대 노출 개수',
                        value: _displaySettings.maxItems,
                        min: 1,
                        max: 20,
                        onChanged:
                            (value) => setState(
                              () =>
                                  _displaySettings = _displaySettings.copyWith(
                                    maxItems: value,
                                  ),
                            ),
                      ),
                    ),
                    SizedBox(
                      width: 280,
                      child: DropdownButtonFormField<_NoticeFontFamilyOption>(
                        value: _displaySettings.fontFamily,
                        decoration: _inputDecoration('폰트를 선택해 주세요'),
                        items: _NoticeFontFamilyOption.values
                            .map(
                              (font) =>
                                  DropdownMenuItem<_NoticeFontFamilyOption>(
                                    value: font,
                                    child: Text(font.label),
                                  ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(
                            () =>
                                _displaySettings = _displaySettings.copyWith(
                                  fontFamily: value,
                                ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: 280,
                      child: _StepperField(
                        label: '항목 노출 시간(초)',
                        value: _displaySettings.itemDurationSec,
                        min: 3,
                        max: 60,
                        onChanged:
                            (value) => setState(
                              () =>
                                  _displaySettings = _displaySettings.copyWith(
                                    itemDurationSec: value,
                                  ),
                            ),
                      ),
                    ),
                    SizedBox(
                      width: 280,
                      child: _NoticeColorField(
                        label: '${_displaySettings.mode.label} 배경색',
                        value: _displaySettings.backgroundColorHex,
                        onChanged:
                            (value) => setState(
                              () =>
                                  _displaySettings = _displaySettings.copyWith(
                                    backgroundColorHex: value,
                                  ),
                            ),
                      ),
                    ),
                    SizedBox(
                      width: 280,
                      child: _NoticeColorField(
                        label: '${_displaySettings.mode.label} 글자색',
                        value: _displaySettings.textColorHex,
                        onChanged:
                            (value) => setState(
                              () =>
                                  _displaySettings = _displaySettings.copyWith(
                                    textColorHex: value,
                                  ),
                            ),
                      ),
                    ),
                    SizedBox(
                      width: 280,
                      child: SwitchListTile.adaptive(
                        value: _displaySettings.enabled,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('공지 오버레이 사용'),
                        onChanged:
                            (value) => setState(
                              () =>
                                  _displaySettings = _displaySettings.copyWith(
                                    enabled: value,
                                  ),
                            ),
                      ),
                    ),
                    if (_displaySettings.mode == _NoticeDisplayMode.ticker)
                      SizedBox(
                        width: 280,
                        child: DropdownButtonFormField<_NoticeTickerDirection>(
                          value: _displaySettings.tickerDirection,
                          decoration: _inputDecoration('티커 방향을 선택해 주세요'),
                          items: _NoticeTickerDirection.values
                              .map(
                                (direction) =>
                                    DropdownMenuItem<_NoticeTickerDirection>(
                                      value: direction,
                                      child: Text(direction.label),
                                    ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(
                              () =>
                                  _displaySettings = _displaySettings.copyWith(
                                    tickerDirection: value,
                                  ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
                if (_displaySettings.mode == _NoticeDisplayMode.ticker) ...[
                  const SizedBox(height: 12),
                  Text('하단 티커 높이', style: theme.textTheme.labelLarge),
                  Slider(
                    value: _displaySettings.tickerHeight.toDouble(),
                    min: 48,
                    max: 220,
                    activeColor: const Color(0xFF0EA5B7),
                    onChanged:
                        (value) => setState(
                          () =>
                              _displaySettings = _displaySettings.copyWith(
                                tickerHeight: value.round(),
                              ),
                        ),
                  ),
                ] else if (_displaySettings.mode ==
                    _NoticeDisplayMode.sidePanel) ...[
                  const SizedBox(height: 12),
                  Text('우측 패널 너비', style: theme.textTheme.labelLarge),
                  Slider(
                    value: _displaySettings.sidePanelWidth.toDouble(),
                    min: 240,
                    max: 720,
                    activeColor: const Color(0xFF0EA5B7),
                    onChanged:
                        (value) => setState(
                          () =>
                              _displaySettings = _displaySettings.copyWith(
                                sidePanelWidth: value.round(),
                              ),
                        ),
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FDFF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFB6E6F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '적용 전 미리보기',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F4C5C),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '입력한 공지 내용, 글자 크기, 색상과 모드별 높이/너비를 바로 확인할 수 있습니다.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF4B5563),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('글자 ${previewFontSize}px'),
                          Text(_noticeModeSummary(_displaySettings)),
                          Text(_displaySettings.fontFamily.label),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _NoticePreviewBox(
                  settings: _displaySettings,
                  previewTitle: previewTitle,
                  previewContent: previewContent,
                  fontSize: previewFontSize,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5B7),
                        ),
                        onPressed:
                            _isApplyingNotice ? null : _applyPreviewNotice,
                        child: Text(_isApplyingNotice ? '적용 중...' : '공지 적용'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _cancelNoticesForDevice,
                        child: const Text('공지 취소'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.tonal(
                    onPressed: () => _toggleEditor(),
                    child: Text(_showEditor ? '등록 닫기' : '새 공지사항 등록'),
                  ),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _searchController,
                      decoration: _inputDecoration(
                        '내용 검색',
                      ).copyWith(prefixIcon: const Icon(Icons.search_rounded)),
                    ),
                  ),
                ],
              ),
              if (_showEditor) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF8F5),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFB8E6DE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _editingNoticeId == null ? '공지사항 등록' : '공지사항 수정',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6FAFB),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _isDeviceSelected
                              ? '등록 대상 디바이스: ${_deviceLabelFor(_selectedDeviceId)}'
                              : _editingNoticeId != null
                              ? '등록 대상 디바이스: ${_deviceLabelFor(_notices.firstWhere((item) => item.id == _editingNoticeId).deviceId)}'
                              : '상단에서 디바이스를 먼저 선택해 주세요.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _contentController,
                        maxLines: 4,
                        decoration: _inputDecoration('공지 내용'),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _StepperField(
                              label: '우선순위',
                              value: _draft.priority,
                              min: 0,
                              max: 10,
                              onChanged:
                                  (value) => setState(
                                    () =>
                                        _draft = _draft.copyWith(
                                          priority: value,
                                        ),
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _LabeledValueCard(
                              label: '글자 크기',
                              value: '${_draft.fontSize.round()}px',
                              child: Slider(
                                value: _draft.fontSize,
                                min: 16,
                                max: 72,
                                divisions: 14,
                                activeColor: const Color(0xFF0F766E),
                                onChanged:
                                    (value) => setState(
                                      () =>
                                          _draft = _draft.copyWith(
                                            fontSize: value,
                                          ),
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _ToggleChip(
                            label: '활성',
                            selected: _draft.active,
                            onTap:
                                () => setState(
                                  () =>
                                      _draft = _draft.copyWith(
                                        active: !_draft.active,
                                      ),
                                ),
                          ),
                          _ToggleChip(
                            label: '즐겨찾기',
                            selected: _draft.favorite,
                            onTap:
                                () => setState(
                                  () =>
                                      _draft = _draft.copyWith(
                                        favorite: !_draft.favorite,
                                      ),
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: _isSavingNotice ? null : _saveNotice,
                              child: Text(
                                _isSavingNotice
                                    ? '저장 중...'
                                    : (_editingNoticeId == null ? '등록' : '저장'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _showEditor = false;
                                  _editingNoticeId = null;
                                  _draft = _NoticeDraft.empty(
                                    deviceId: _selectedDeviceId,
                                  );
                                  _contentController.clear();
                                });
                              },
                              child: const Text('취소'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              if (_noticeLoadMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  _noticeLoadMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF475569),
                  ),
                ),
              ],
              if (_isLoadingNotices) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(minHeight: 3),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (notices.isEmpty)
          _SectionCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Text(
                '조건에 맞는 공지사항이 없습니다.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          )
        else
          ...notices.map(
            (notice) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _NoticeCard(
                notice: notice,
                isSelected: notice.id == _previewNoticeId,
                onSelect: () => _selectPreviewNotice(notice),
                onRegister: () => _registerNotice(notice),
                onFavoriteToggle: () => _toggleFavorite(notice),
                onEdit: () => _toggleEditor(notice),
                onDelete: () => _deleteNotice(notice),
              ),
            ),
          ),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.notice,
    required this.isSelected,
    required this.onSelect,
    required this.onRegister,
    required this.onFavoriteToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final _ManagedNotice notice;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onRegister;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _formatDate(DateTime? value) => _formatShortDate(value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onSelect,
      child: _SectionCard(
        accentColor: isSelected ? const Color(0xFF0EA5B7) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ActionChip(
                        avatar: Icon(
                          notice.favorite
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color:
                              notice.favorite
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF64748B),
                          size: 18,
                        ),
                        label: Text(notice.favorite ? '즐겨찾기' : '보관'),
                        onPressed: onFavoriteToggle,
                      ),
                      _Pill(
                        label: notice.deviceLabel,
                        foreground: const Color(0xFF155E75),
                        background: const Color(0xFFE0F2FE),
                      ),
                      _Pill(
                        label: notice.active ? '활성' : '비활성',
                        foreground:
                            notice.active
                                ? const Color(0xFF166534)
                                : const Color(0xFF991B1B),
                        background:
                            notice.active
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFFEE2E2),
                      ),
                      _Pill(
                        label: '우선순위 ${notice.priority}',
                        foreground: const Color(0xFF5B21B6),
                        background: const Color(0xFFEDE9FE),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '삭제',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _buildNoticePreviewTitle(notice.content),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                _MetaText(label: '글자 크기', value: '${notice.fontSize}px'),
                _MetaText(
                  label: '최근 사용',
                  value: _formatDate(notice.lastUsedAt),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onRegister,
                    child: const Text('등록'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: onEdit,
                    child: const Text('수정'),
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.accentColor});

  final Widget child;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border:
            accentColor == null
                ? null
                : Border.all(color: accentColor!.withValues(alpha: 0.24)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StepperField extends StatelessWidget {
  const _StepperField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FAFB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: value > min ? () => onChanged(value - 1) : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              Expanded(
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: value < max ? () => onChanged(value + 1) : null,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LabeledValueCard extends StatelessWidget {
  const _LabeledValueCard({
    required this.label,
    required this.value,
    required this.child,
  });

  final String label;
  final String value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FAFB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label),
              const Spacer(),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          child,
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _NoticePreviewBox extends StatelessWidget {
  const _NoticePreviewBox({
    required this.settings,
    required this.previewTitle,
    required this.previewContent,
    required this.fontSize,
  });

  final _NoticeDisplaySettings settings;
  final String previewTitle;
  final String previewContent;
  final int fontSize;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _hexToColor(settings.backgroundColorHex);
    final textColor = _hexToColor(settings.textColorHex);
    final fontFamily = settings.fontFamily.flutterFontFamily;

    return Container(
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF111827)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.3,
                  colors: [Color(0x3322D3EE), Colors.transparent],
                ),
              ),
            ),
          ),
          if (settings.mode == _NoticeDisplayMode.ticker)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: settings.tickerHeight.toDouble().clamp(48, 220),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: backgroundColor.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
                child: _NoticePreviewTicker(
                  text: '공지 $previewTitle: $previewContent',
                  direction: settings.tickerDirection,
                  fontSize: fontSize,
                  textColor: textColor,
                  backgroundColor: backgroundColor,
                  fontFamily: fontFamily,
                ),
              ),
            ),
          if (settings.mode == _NoticeDisplayMode.sidePanel)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: Container(
                width: settings.sidePanelWidth.toDouble().clamp(240, 720),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: backgroundColor.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.horizontal(
                    right: Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '공지사항',
                      style: TextStyle(
                        color: Color(0xFF67E8F9),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      previewTitle,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontFamily: fontFamily,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      previewContent,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        height: 1.5,
                        fontSize: fontSize.clamp(16, 24).toDouble(),
                        fontFamily: fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (settings.mode == _NoticeDisplayMode.popupCycle)
            Center(
              child: Container(
                width: 240,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF2DD4BF)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '순환 팝업',
                      style: TextStyle(
                        color: Color(0xFF99F6E4),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      previewTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontFamily: fontFamily,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      previewContent,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        height: 1.5,
                        fontSize: fontSize.clamp(16, 24).toDouble(),
                        fontFamily: fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: const Color(0xFF475569),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _NoticeColorField extends StatelessWidget {
  const _NoticeColorField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _noticeColorOptions
              .map((option) {
                final isSelected = option == value;
                final optionColor = _hexToColor(option);
                return GestureDetector(
                  onTap: () => onChanged(option),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: optionColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            isSelected
                                ? const Color(0xFF0EA5B7)
                                : const Color(0xFFD5DFE7),
                        width: isSelected ? 3 : 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x120F172A),
                          blurRadius: 10,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child:
                        isSelected
                            ? Icon(
                              Icons.check_rounded,
                              size: 18,
                              color:
                                  optionColor.computeLuminance() > 0.5
                                      ? const Color(0xFF0F172A)
                                      : Colors.white,
                            )
                            : null,
                  ),
                );
              })
              .toList(growable: false),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _NoticePreviewTicker extends StatelessWidget {
  const _NoticePreviewTicker({
    required this.text,
    required this.direction,
    required this.fontSize,
    required this.textColor,
    required this.backgroundColor,
    required this.fontFamily,
  });

  final String text;
  final _NoticeTickerDirection direction;
  final int fontSize;
  final Color textColor;
  final Color backgroundColor;
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: textColor,
        fontSize: fontSize.clamp(16, 28).toDouble(),
        fontFamily: fontFamily,
        fontWeight: FontWeight.w600,
      ),
    );

    if (direction == _NoticeTickerDirection.staticText) {
      return Container(
        width: double.infinity,
        color: backgroundColor,
        alignment: Alignment.centerLeft,
        child: textWidget,
      );
    }

    final alignment =
        direction == _NoticeTickerDirection.rtl
            ? Alignment.centerRight
            : Alignment.centerLeft;
    final icon =
        direction == _NoticeTickerDirection.rtl
            ? Icons.west_rounded
            : Icons.east_rounded;

    return Container(
      width: double.infinity,
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: textColor.withValues(alpha: 0.82)),
          const SizedBox(width: 8),
          Expanded(child: Align(alignment: alignment, child: textWidget)),
        ],
      ),
    );
  }
}

class _DeviceOption {
  const _DeviceOption({required this.id, required this.label});

  final String id;
  final String label;
}

enum _NoticeDisplayMode {
  ticker('하단 티커'),
  sidePanel('우측 패널'),
  popupCycle('팝업 순환');

  const _NoticeDisplayMode(this.label);

  final String label;
}

enum _NoticeTickerDirection {
  staticText('고정'),
  rtl('오른쪽에서 왼쪽'),
  ltr('왼쪽에서 오른쪽');

  const _NoticeTickerDirection(this.label);

  final String label;
}

enum _NoticeFontFamilyOption {
  arial('Arial', null),
  trebuchet('Trebuchet MS', null),
  segoe('Segoe UI', null),
  times('Times New Roman', 'serif'),
  georgia('Georgia', 'serif'),
  courier('Courier New', 'monospace');

  const _NoticeFontFamilyOption(this.label, this.flutterFontFamily);

  final String label;
  final String? flutterFontFamily;
}

class _NoticeDisplaySettings {
  const _NoticeDisplaySettings({
    this.enabled = true,
    this.mode = _NoticeDisplayMode.ticker,
    this.tickerDirection = _NoticeTickerDirection.rtl,
    this.backgroundColorHex = '#000000',
    this.textColorHex = '#FFFFFF',
    this.fontFamily = _NoticeFontFamilyOption.arial,
    this.itemDurationSec = 8,
    this.maxItems = 3,
    this.tickerHeight = 88,
    this.sidePanelWidth = 448,
  });

  final bool enabled;
  final _NoticeDisplayMode mode;
  final _NoticeTickerDirection tickerDirection;
  final String backgroundColorHex;
  final String textColorHex;
  final _NoticeFontFamilyOption fontFamily;
  final int itemDurationSec;
  final int maxItems;
  final int tickerHeight;
  final int sidePanelWidth;

  Map<String, dynamic> toApiJson() {
    return {
      'notice_enabled': enabled ? 1 : 0,
      'notice_default_mode': _noticeModeApiValue(mode),
      'notice_ticker_direction': _tickerDirectionApiValue(tickerDirection),
      'notice_background_color': backgroundColorHex,
      'notice_text_color': textColorHex,
      'notice_font_family': _fontFamilyApiValue(fontFamily),
      'notice_item_duration_sec': itemDurationSec,
      'notice_max_items': maxItems,
      'notice_ticker_height_px': tickerHeight,
      'notice_side_panel_width_px': sidePanelWidth,
    };
  }

  _NoticeDisplaySettings copyWith({
    bool? enabled,
    _NoticeDisplayMode? mode,
    _NoticeTickerDirection? tickerDirection,
    String? backgroundColorHex,
    String? textColorHex,
    _NoticeFontFamilyOption? fontFamily,
    int? itemDurationSec,
    int? maxItems,
    int? tickerHeight,
    int? sidePanelWidth,
  }) {
    return _NoticeDisplaySettings(
      enabled: enabled ?? this.enabled,
      mode: mode ?? this.mode,
      tickerDirection: tickerDirection ?? this.tickerDirection,
      backgroundColorHex: backgroundColorHex ?? this.backgroundColorHex,
      textColorHex: textColorHex ?? this.textColorHex,
      fontFamily: fontFamily ?? this.fontFamily,
      itemDurationSec: itemDurationSec ?? this.itemDurationSec,
      maxItems: maxItems ?? this.maxItems,
      tickerHeight: tickerHeight ?? this.tickerHeight,
      sidePanelWidth: sidePanelWidth ?? this.sidePanelWidth,
    );
  }
}

class _NoticeDraft {
  const _NoticeDraft({
    required this.category,
    required this.deviceId,
    required this.favorite,
    required this.active,
    required this.priority,
    required this.fontSize,
    this.startAt,
    this.endAt,
  });

  static const String _allDevicesValue = '__all__';

  factory _NoticeDraft.empty({String? deviceId}) {
    return _NoticeDraft(
      category: '일반',
      deviceId:
          deviceId == null || deviceId == _allDevicesValue
              ? _allDevicesValue
              : deviceId,
      favorite: false,
      active: true,
      priority: 0,
      fontSize: 32,
    );
  }

  factory _NoticeDraft.fromNotice(_ManagedNotice notice) {
    return _NoticeDraft(
      category: notice.category,
      deviceId: notice.deviceId,
      favorite: notice.favorite,
      active: notice.active,
      priority: notice.priority,
      fontSize: notice.fontSize.toDouble(),
      startAt: notice.startAt,
      endAt: notice.endAt,
    );
  }

  final String category;
  final String deviceId;
  final bool favorite;
  final bool active;
  final int priority;
  final double fontSize;
  final DateTime? startAt;
  final DateTime? endAt;

  _NoticeDraft copyWith({
    String? category,
    String? deviceId,
    bool? favorite,
    bool? active,
    int? priority,
    double? fontSize,
    DateTime? startAt,
    DateTime? endAt,
    bool clearStartAt = false,
    bool clearEndAt = false,
  }) {
    return _NoticeDraft(
      category: category ?? this.category,
      deviceId: deviceId ?? this.deviceId,
      favorite: favorite ?? this.favorite,
      active: active ?? this.active,
      priority: priority ?? this.priority,
      fontSize: fontSize ?? this.fontSize,
      startAt: clearStartAt ? null : (startAt ?? this.startAt),
      endAt: clearEndAt ? null : (endAt ?? this.endAt),
    );
  }
}

class _ManagedNotice {
  const _ManagedNotice({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.deviceId,
    required this.deviceLabel,
    required this.favorite,
    required this.active,
    required this.priority,
    required this.fontSize,
    required this.createdAt,
    required this.updatedAt,
    required this.usageCount,
    this.lastUsedAt,
    this.startAt,
    this.endAt,
  });

  final String id;
  final String title;
  final String content;
  final String category;
  final String deviceId;
  final String deviceLabel;
  final bool favorite;
  final bool active;
  final int priority;
  final int fontSize;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int usageCount;
  final DateTime? lastUsedAt;
  final DateTime? startAt;
  final DateTime? endAt;

  int get favoriteFlag => favorite ? 1 : 0;

  _ManagedNotice copyWith({
    String? title,
    String? content,
    String? category,
    String? deviceId,
    String? deviceLabel,
    bool? favorite,
    bool? active,
    int? priority,
    int? fontSize,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? usageCount,
    DateTime? lastUsedAt,
    DateTime? startAt,
    DateTime? endAt,
  }) {
    return _ManagedNotice(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      deviceId: deviceId ?? this.deviceId,
      deviceLabel: deviceLabel ?? this.deviceLabel,
      favorite: favorite ?? this.favorite,
      active: active ?? this.active,
      priority: priority ?? this.priority,
      fontSize: fontSize ?? this.fontSize,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      usageCount: usageCount ?? this.usageCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
    );
  }
}
