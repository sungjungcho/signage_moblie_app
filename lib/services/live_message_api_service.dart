import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class LiveMessageApiService {
  LiveMessageApiService({required this.baseUrl, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;

  Uri _buildUri(String path) {
    final normalizedBase =
        baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBase$normalizedPath');
  }

  String _buildNoticeTitle(String content) {
    final normalized = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return '怨듭??ы빆';
    }
    if (normalized.length <= 20) {
      return normalized;
    }
    return '${normalized.substring(0, 20)}...';
  }

  Future<String> signIn({
    required String username,
    required String password,
  }) async {
    final response = await _httpClient.post(
      _buildUri('/api/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    final payload = _decodeJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(payload, fallback: '濡쒓렇?몄뿉 ?ㅽ뙣?덉뒿?덈떎.'),
      );
    }

    final token = payload['token']?.toString() ?? '';
    if (token.isEmpty) {
      throw const ApiException('濡쒓렇???좏겙??諛쏆? 紐삵뻽?듬땲??');
    }

    return token;
  }

  Future<List<LiveDevice>> fetchDevices({required String authToken}) async {
    final response = await _httpClient.get(
      _buildUri('/api/devices'),
      headers: _cookieHeaders(authToken),
    );

    final payload = _decodeJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          payload is Map<String, dynamic>
              ? _extractErrorMessage(
                payload,
                fallback: '?붾컮?댁뒪 紐⑸줉??遺덈윭?ㅼ? 紐삵뻽?듬땲??',
              )
              : '?붾컮?댁뒪 紐⑸줉??遺덈윭?ㅼ? 紐삵뻽?듬땲??';
      throw ApiException(message);
    }

    if (payload is! List) {
      throw const ApiException('?붾컮?댁뒪 紐⑸줉 ?묐떟 ?뺤떇???щ컮瑜댁? ?딆뒿?덈떎.');
    }

    return payload
        .whereType<Map>()
        .map((item) => LiveDevice.fromJson(Map<String, dynamic>.from(item)))
        .where((device) => device.id.isNotEmpty && device.name.isNotEmpty)
        .toList(growable: false);
  }

  Future<LiveAlert> sendAlert({
    required String authToken,
    required String message,
    required List<String> targetDeviceIds,
    required int duration,
  }) async {
    final response = await _httpClient.post(
      _buildUri('/api/alerts'),
      headers: {
        'Content-Type': 'application/json',
        ..._cookieHeaders(authToken),
      },
      body: jsonEncode({
        'message': message,
        'targetDeviceIds': targetDeviceIds,
        'duration': duration,
      }),
    );

    final payload = _decodeJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          payload is Map<String, dynamic>
              ? _extractErrorMessage(
                payload,
                fallback: '?댁쁺 硫붿꽭吏 ?꾩넚???ㅽ뙣?덉뒿?덈떎.',
              )
              : '?댁쁺 硫붿꽭吏 ?꾩넚???ㅽ뙣?덉뒿?덈떎.';
      throw ApiException(message);
    }

    if (payload is! Map<String, dynamic>) {
      throw const ApiException('?뚮┝ ?꾩넚 ?묐떟 ?뺤떇???щ컮瑜댁? ?딆뒿?덈떎.');
    }

    return LiveAlert.fromJson(payload);
  }

  Future<List<LiveAlert>> fetchAlertsForDevice({
    required String authToken,
    required String deviceId,
  }) async {
    final response = await _httpClient.get(
      _buildUri('/api/alerts?deviceId=$deviceId'),
      headers: _cookieHeaders(authToken),
    );

    final payload = _decodeJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          payload is Map<String, dynamic>
              ? _extractErrorMessage(
                payload,
                fallback: '?꾩넚 寃곌낵瑜??뺤씤?섏? 紐삵뻽?듬땲??',
              )
              : '?꾩넚 寃곌낵瑜??뺤씤?섏? 紐삵뻽?듬땲??';
      throw ApiException(message);
    }

    if (payload is! List) {
      throw const ApiException('?뚮┝ 議고쉶 ?묐떟 ?뺤떇???щ컮瑜댁? ?딆뒿?덈떎.');
    }

    return payload
        .whereType<Map>()
        .map((item) => LiveAlert.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<List<LiveNotice>> fetchNotices({
    required String authToken,
    required String deviceId,
    String? search,
  }) async {
    final query = <String, String>{};
    final normalizedSearch = search?.trim() ?? '';
    if (normalizedSearch.isNotEmpty) {
      query['search'] = normalizedSearch;
    }

    final uri = _buildUri(
      '/api/devices/$deviceId/notices',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await _httpClient.get(
      uri,
      headers: _cookieHeaders(authToken),
    );

    final payload = _decodeJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          payload is Map<String, dynamic>
              ? _extractErrorMessage(
                payload,
                fallback: '怨듭??ы빆 紐⑸줉??遺덈윭?ㅼ? 紐삵뻽?듬땲??',
              )
              : '怨듭??ы빆 紐⑸줉??遺덈윭?ㅼ? 紐삵뻽?듬땲??';
      throw ApiException(message);
    }

    if (payload is! List) {
      throw const ApiException('怨듭??ы빆 紐⑸줉 ?묐떟 ?뺤떇???щ컮瑜댁? ?딆뒿?덈떎.');
    }

    return payload
        .whereType<Map>()
        .map((item) => LiveNotice.fromJson(Map<String, dynamic>.from(item)))
        .where((notice) => notice.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<LiveNotice> createNotice({
    required String authToken,
    required String deviceId,
    required String content,
    required bool active,
    required int priority,
    required int fontSize,
  }) async {
    final title = _buildNoticeTitle(content);
    final response = await _httpClient.post(
      _buildUri('/api/devices/$deviceId/notices'),
      headers: {
        'Content-Type': 'application/json',
        ..._cookieHeaders(authToken),
      },
      body: jsonEncode({
        'title': title,
        'content': content,
        'category': '일반',
        'active': active,
        'priority': priority,
        'fontSize': fontSize,
      }),
    );

    final payload = _decodeJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          payload is Map<String, dynamic>
              ? _extractErrorMessage(
                payload,
                fallback: '怨듭??ы빆 ?깅줉???ㅽ뙣?덉뒿?덈떎.',
              )
              : '怨듭??ы빆 ?깅줉???ㅽ뙣?덉뒿?덈떎.';
      throw ApiException(message);
    }

    if (payload is! Map<String, dynamic>) {
      throw const ApiException('怨듭??ы빆 ?깅줉 ?묐떟 ?뺤떇???щ컮瑜댁? ?딆뒿?덈떎.');
    }

    return LiveNotice.fromJson(payload);
  }

  Future<LiveNotice> updateNotice({
    required String authToken,
    required String deviceId,
    required String noticeId,
    required String content,
    required bool favorite,
    required bool active,
    required int priority,
    required int fontSize,
  }) async {
    final title = _buildNoticeTitle(content);
    final response = await _httpClient.put(
      _buildUri('/api/devices/$deviceId/notices/$noticeId'),
      headers: {
        'Content-Type': 'application/json',
        ..._cookieHeaders(authToken),
      },
      body: jsonEncode({
        'title': title,
        'content': content,
        'category': '일반',
        'favorite': favorite,
        'active': active,
        'priority': priority,
        'fontSize': fontSize,
      }),
    );

    final payload = _decodeJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          payload is Map<String, dynamic>
              ? _extractErrorMessage(
                payload,
                fallback: '怨듭??ы빆 ??μ뿉 ?ㅽ뙣?덉뒿?덈떎.',
              )
              : '怨듭??ы빆 ??μ뿉 ?ㅽ뙣?덉뒿?덈떎.';
      throw ApiException(message);
    }

    if (payload is! Map<String, dynamic>) {
      throw const ApiException('怨듭??ы빆 ????묐떟 ?뺤떇???щ컮瑜댁? ?딆뒿?덈떎.');
    }

    return LiveNotice.fromJson(payload);
  }

  Future<void> deleteNotice({
    required String authToken,
    required String deviceId,
    required String noticeId,
  }) async {
    final response = await _httpClient.delete(
      _buildUri('/api/devices/$deviceId/notices/$noticeId'),
      headers: _cookieHeaders(authToken),
    );

    final payload = _decodeJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          payload is Map<String, dynamic>
              ? _extractErrorMessage(
                payload,
                fallback: '怨듭??ы빆 ??젣???ㅽ뙣?덉뒿?덈떎.',
              )
              : '怨듭??ы빆 ??젣???ㅽ뙣?덉뒿?덈떎.';
      throw ApiException(message);
    }
  }

  Future<void> deleteAllNoticesForDevice({
    required String authToken,
    required String deviceId,
  }) async {
    final response = await _httpClient.delete(
      _buildUri('/api/devices/$deviceId/notices'),
      headers: _cookieHeaders(authToken),
    );

    final payload = _decodeJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          payload is Map<String, dynamic>
              ? _extractErrorMessage(
                payload,
                fallback: '怨듭??ы빆 ?쇨큵 ??젣???ㅽ뙣?덉뒿?덈떎.',
              )
              : '怨듭??ы빆 ?쇨큵 ??젣???ㅽ뙣?덉뒿?덈떎.';
      throw ApiException(message);
    }
  }

  Future<LiveNotice> touchNoticeUsage({
    required String authToken,
    required String deviceId,
    required String noticeId,
  }) async {
    final response = await _httpClient.patch(
      _buildUri('/api/devices/$deviceId/notices/$noticeId'),
      headers: _cookieHeaders(authToken),
    );

    final payload = _decodeJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          payload is Map<String, dynamic>
              ? _extractErrorMessage(
                payload,
                fallback: '怨듭? ?ъ슜 ?대젰 諛섏쁺???ㅽ뙣?덉뒿?덈떎.',
              )
              : '怨듭? ?ъ슜 ?대젰 諛섏쁺???ㅽ뙣?덉뒿?덈떎.';
      throw ApiException(message);
    }

    if (payload is! Map<String, dynamic>) {
      throw const ApiException('怨듭? ?ъ슜 ?대젰 ?묐떟 ?뺤떇???щ컮瑜댁? ?딆뒿?덈떎.');
    }

    return LiveNotice.fromJson(payload);
  }

  Map<String, String> _cookieHeaders(String authToken) {
    return {'Cookie': 'auth_token=$authToken'};
  }

  dynamic _decodeJson(http.Response response) {
    if (response.body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      return jsonDecode(response.body);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String _extractErrorMessage(
    Map<String, dynamic> payload, {
    required String fallback,
  }) {
    final message = payload['message']?.toString().trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }

    final error = payload['error']?.toString().trim();
    if (error != null && error.isNotEmpty) {
      return error;
    }

    return fallback;
  }
}

class LiveDevice {
  const LiveDevice({required this.id, required this.name});

  factory LiveDevice.fromJson(Map<String, dynamic> json) {
    return LiveDevice(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  final String id;
  final String name;
}

class LiveAlert {
  const LiveAlert({
    required this.id,
    required this.message,
    required this.targetDeviceIds,
    this.duration,
  });

  factory LiveAlert.fromJson(Map<String, dynamic> json) {
    final targetDeviceIds =
        json['targetDeviceIds'] is List
            ? (json['targetDeviceIds'] as List)
                .map((item) => item.toString())
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
            : const <String>[];

    return LiveAlert(
      id: json['id']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      targetDeviceIds: targetDeviceIds,
      duration:
          json['duration'] is num ? (json['duration'] as num).toInt() : null,
    );
  }

  final String id;
  final String message;
  final List<String> targetDeviceIds;
  final int? duration;
}

class LiveNotice {
  const LiveNotice({
    required this.id,
    required this.deviceId,
    required this.title,
    required this.content,
    required this.category,
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

  factory LiveNotice.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String key) {
      final raw = json[key]?.toString().trim();
      if (raw == null || raw.isEmpty) {
        return null;
      }
      return DateTime.tryParse(raw)?.toLocal();
    }

    int parseInt(String key, int fallback) {
      final value = json[key];
      if (value is num) {
        return value.toInt();
      }
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    return LiveNotice(
      id: json['id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      category:
          json['category']?.toString().trim().isEmpty ?? true
              ? '?쇰컲'
              : json['category']!.toString(),
      favorite: parseInt('favorite', 0) == 1,
      active: parseInt('active', 1) == 1,
      priority: parseInt('priority', 0),
      fontSize: parseInt('fontSize', 32),
      createdAt: parseDate('createdAt') ?? DateTime.now(),
      updatedAt: parseDate('updatedAt') ?? DateTime.now(),
      usageCount: parseInt('usageCount', 0),
      lastUsedAt: parseDate('lastUsedAt'),
      startAt: parseDate('startAt'),
      endAt: parseDate('endAt'),
    );
  }

  final String id;
  final String deviceId;
  final String title;
  final String content;
  final String category;
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
}
