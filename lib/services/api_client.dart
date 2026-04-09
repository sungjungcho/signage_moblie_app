import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({
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

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final response = await _httpClient.post(
      _buildUri(path),
      headers: {
        'Content-Type': 'application/json',
        ...?headers,
      },
      body: jsonEncode(body),
    );

    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> getJsonObject(
    String path, {
    Map<String, String>? headers,
  }) async {
    final response = await _httpClient.get(
      _buildUri(path),
      headers: headers,
    );

    return _decodeObject(response);
  }

  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, String>? headers,
  }) async {
    final response = await _httpClient.get(
      _buildUri(path),
      headers: headers,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'API 요청에 실패했습니다. statusCode=${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List<dynamic>) {
      throw const ApiException('API 응답이 배열 형식이 아닙니다.');
    }

    return decoded;
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'API 요청에 실패했습니다. statusCode=${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('API 응답이 객체 형식이 아닙니다.');
    }

    return decoded;
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;
}
