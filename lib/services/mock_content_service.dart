import '../data/mock_signage_repository.dart';
import '../models/signage_item.dart';
import 'content_service.dart';

class MockContentService implements ContentService {
  const MockContentService({
    MockSignageRepository repository = const MockSignageRepository(),
  }) : _repository = repository;

  final MockSignageRepository _repository;

  @override
  Future<List<SignageItem>> fetchMessages() {
    return _repository.fetchMessages();
  }

  @override
  Future<List<SignageItem>> fetchNotices() {
    return _repository.fetchNotices();
  }
}
