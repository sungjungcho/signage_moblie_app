import 'signage_item.dart';

class RemoteSignageItem {
  const RemoteSignageItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.publishedAt,
    required this.badge,
    required this.isPinned,
  });

  final String id;
  final String title;
  final String summary;
  final String content;
  final DateTime publishedAt;
  final String badge;
  final bool isPinned;

  factory RemoteSignageItem.fromJson(Map<String, dynamic> json) {
    final publishedValue = json['publishedAt'] ?? json['createdAt'];
    final parsedDate = publishedValue is String
        ? DateTime.tryParse(publishedValue)
        : null;

    return RemoteSignageItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      summary: (json['summary'] ?? json['excerpt'] ?? '').toString(),
      content: (json['content'] ?? json['body'] ?? '').toString(),
      publishedAt: parsedDate ?? DateTime.now(),
      badge: (json['badge'] ?? json['category'] ?? '안내').toString(),
      isPinned: json['isPinned'] == true || json['pinned'] == true,
    );
  }

  SignageItem toDomain(SignageItemType type) {
    return SignageItem(
      id: id,
      type: type,
      title: title,
      summary: summary.isEmpty ? content : summary,
      content: content,
      publishedAt: publishedAt,
      badge: badge,
      isPinned: isPinned,
    );
  }
}
