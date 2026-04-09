import '../models/signage_item.dart';

abstract class ContentService {
  Future<List<SignageItem>> fetchMessages();
  Future<List<SignageItem>> fetchNotices();
}
