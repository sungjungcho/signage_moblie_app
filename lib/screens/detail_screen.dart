import 'package:flutter/material.dart';

import '../models/signage_item.dart';

class DetailScreen extends StatelessWidget {
  const DetailScreen({
    super.key,
    required this.item,
  });

  final SignageItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = item.type == SignageItemType.message
        ? const Color(0xFF25C1AE)
        : const Color(0xFFE98BB2);

    return Scaffold(
      appBar: AppBar(
        title: Text(item.type == SignageItemType.message ? '메세지 상세' : '공지사항 상세'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF27364A),
              Color(0xFFF5FBFA),
            ],
            stops: [0.0, 0.28],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x140F172A),
                    blurRadius: 28,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item.badge,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    item.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _formatDate(item.publishedAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF718396),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    item.content,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.7,
                      color: const Color(0xFF405264),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '${dateTime.year}.${dateTime.month}.${dateTime.day} $hour:$minute';
}
