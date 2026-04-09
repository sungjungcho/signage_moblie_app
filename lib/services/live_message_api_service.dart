import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class LiveMessageApiService {
  LiveMessageApiService({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;

  Uri _buildUri(String path) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBase$normalizedPath');
  }

  Future<String> signIn({
    required String username,
    required String password,
  }) async {
    final response = await _httpClient.post(
      _buildUri('/api/auth/login'),
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    final payload = _decodeJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(payload, fallback: '로그인에 실패했습니다.'),
      );
    }

    final token = payload['token']?.toString() ?? '';
    if (token.isEmpty) {
      throw const ApiException('로그인 토큰을 받지 못했습니다.');
    }

    return token;
  }

  Future<List<LiveDevice>> fetchDevices({
    required String authToken,
  }) async {
    final response = await _httpClient.get(
      _buildUri('/api/devices'),
      headers: _cookieHeaders(authToken),
    );

    final payload = _decodeJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = payload is Map<String, dynamic>
          ? _extractErrorMessage(payload, fallback: '디바이스 목록을 불러오지 못했습니다.')
          : '디바이스 목록을 불러오지 못했습니다.';
      throw ApiException(message);
    }

    if (payload is! List) {
      throw const ApiException('디바이스 목록 응답 형식이 올바르지 않습니다.');
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
      final message = payload is Map<String, dynamic>
          ? _extractErrorMessage(payload, fallback: '운영 메세지 전송에 실패했습니다.')
          : '운영 메세지 전송에 실패했습니다.';
      throw ApiException(message);
    }

    if (payload is! Map<String, dynamic>) {
      throw const ApiException('알림 전송 응답 형식이 올바르지 않습니다.');
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
      final message = payload is Map<String, dynamic>
          ? _extractErrorMessage(payload, fallback: '전송 결과를 확인하지 못했습니다.')
          : '전송 결과를 확인하지 못했습니다.';
      throw ApiException(message);
    }

    if (payload is! List) {
      throw const ApiException('알림 조회 응답 형식이 올바르지 않습니다.');
    }

    return payload
        .whereType<Map>()
        .map((item) => LiveAlert.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Map<String, String> _cookieHeaders(String authToken) {
    return {
      'Cookie': 'auth_token=$authToken',
    };
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
  const LiveDevice({
    required this.id,
    required this.name,
  });

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
    final targetDeviceIds = json['targetDeviceIds'] is List
        ? (json['targetDeviceIds'] as List)
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    return LiveAlert(
      id: json['id']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      targetDeviceIds: targetDeviceIds,
      duration: json['duration'] is num ? (json['duration'] as num).toInt() : null,
    );
  }

  final String id;
  final String message;
  final List<String> targetDeviceIds;
  final int? duration;
}
