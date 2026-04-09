import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/signage_item.dart';
import '../models/user_session.dart';
import 'detail_screen.dart';
import 'login_screen.dart';
import 'message_compose_tab.dart';
import 'notice_manage_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.session,
  });

  final UserSession session;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<_HomeScreenData>? _screenDataFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenDataFuture ??= _loadScreenData();
  }

  Future<_HomeScreenData> _loadScreenData() async {
    final contentService = AppScope.of(context).contentService;
    final results = await Future.wait<List<SignageItem>>([
      contentService.fetchMessages(),
      contentService.fetchNotices(),
    ]);

    return _HomeScreenData(
      messages: results[0],
      notices: results[1],
    );
  }

  Future<void> _refresh() async {
    final future = _loadScreenData();
    setState(() {
      _screenDataFuture = future;
    });
    await future;
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  bool _supportsLiveDeviceLoad() {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final useLiveMessageDevices =
        !scope.environment.useMockAuthService && _supportsLiveDeviceLoad();
    final screenDataFuture = _screenDataFuture ?? _loadScreenData();

    return DefaultTabController(
      length: 2,
      initialIndex: 0,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 96,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Blossom Signage',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.session.displayName}님, 메세지와 공지사항을 확인하세요.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: '새로고침',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: '로그아웃',
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const TabBar(
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Color(0xFF27364A),
                unselectedLabelColor: Colors.white,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                tabs: [
                  Tab(text: '메세지'),
                  Tab(text: '공지사항'),
                ],
              ),
            ),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF25C1AE),
                Color(0xFFEFF9F7),
              ],
              stops: [0.0, 0.38],
            ),
          ),
          child: FutureBuilder<_HomeScreenData>(
            future: screenDataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          color: Colors.white,
                          size: 56,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '데이터를 불러오지 못했습니다.',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _refresh,
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final data = snapshot.requireData;

              return TabBarView(
                children: [
                  MessageComposeTab(
                    session: widget.session,
                    loadLiveDevices: useLiveMessageDevices,
                    serverBaseUrl: scope.environment.serverBaseUrl,
                  ),
                  RefreshIndicator(
                    onRefresh: _refresh,
                    child: NoticeManageTab(initialItems: data.notices),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ItemListTab extends StatelessWidget {
  const _ItemListTab({
    required this.heroBadge,
    required this.heroTitle,
    required this.heroDescription,
    required this.items,
  });

  final String heroBadge;
  final String heroTitle;
  final String heroDescription;
  final List<SignageItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        _HeroPanel(
          badge: heroBadge,
          title: heroTitle,
          description: heroDescription,
        ),
        const SizedBox(height: 18),
        for (final item in items) ...[
          _ItemCard(item: item),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.badge,
    required this.title,
    required this.description,
  });

  final String badge;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF27364A),
            Color(0xFF31506D),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F1E3448),
            blurRadius: 24,
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
              color: const Color(0xFF25C1AE),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge,
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.86),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
  });

  final SignageItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = const Color(0xFFE98BB2);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DetailScreen(item: item),
            ),
          );
        },
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 22,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.campaign_outlined,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (item.isPinned)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '고정',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: accentColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.summary,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF5E7186),
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          item.badge,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatDate(item.publishedAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF8D9CAE),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeScreenData {
  const _HomeScreenData({
    required this.messages,
    required this.notices,
  });

  final List<SignageItem> messages;
  final List<SignageItem> notices;
}

String _formatDate(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '${dateTime.year}.${dateTime.month}.${dateTime.day} $hour:$minute';
}
