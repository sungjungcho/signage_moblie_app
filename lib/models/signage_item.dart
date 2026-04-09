enum SignageItemType { message, notice }

class SignageItem {
  const SignageItem({
    required this.id,
    required this.type,
    required this.title,
    required this.summary,
    required this.content,
    required this.publishedAt,
    required this.badge,
    this.isPinned = false,
  });

  final String id;
  final SignageItemType type;
  final String title;
  final String summary;
  final String content;
  final DateTime publishedAt;
  final String badge;
  final bool isPinned;
}
