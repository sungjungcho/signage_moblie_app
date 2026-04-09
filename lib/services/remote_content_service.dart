import '../models/remote_signage_item.dart';
import '../models/signage_item.dart';
import 'api_client.dart';
import 'content_service.dart';

class RemoteContentService implements ContentService {
  RemoteContentService({
    required this.baseUrl,
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient(baseUrl: baseUrl);

  final String baseUrl;
  final ApiClient _apiClient;

  @override
  Future<List<SignageItem>> fetchMessages() async {
    return _fetchItems(
      path: '/messages',
      type: SignageItemType.message,
    );
  }

  @override
  Future<List<SignageItem>> fetchNotices() async {
    return _fetchItems(
      path: '/notices',
      type: SignageItemType.notice,
    );
  }

  Future<List<SignageItem>> _fetchItems({
    required String path,
    required SignageItemType type,
  }) async {
    try {
      final response = await _apiClient.getJsonObject(path);
      final rawItems = response['data'] is List<dynamic>
          ? response['data'] as List<dynamic>
          : response['items'] is List<dynamic>
              ? response['items'] as List<dynamic>
              : <dynamic>[];

      return rawItems
          .whereType<Map<String, dynamic>>()
          .map(RemoteSignageItem.fromJson)
          .map((item) => item.toDomain(type))
          .toList();
    } on ApiException catch (error) {
      throw StateError(error.message);
    }
  }
}
