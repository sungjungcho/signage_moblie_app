import 'package:flutter/material.dart';

import '../models/signage_item.dart';

class NoticeManageTab extends StatefulWidget {
  const NoticeManageTab({
    super.key,
    required this.initialItems,
  });

  final List<SignageItem> initialItems;

  @override
  State<NoticeManageTab> createState() => _NoticeManageTabState();
}

class _NoticeManageTabState extends State<NoticeManageTab> {
  static const String _allDevices = '__all__';

  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  String _selectedDeviceId = _allDevices;
  String _selectedCategory = '전체';
  String _draftCategory = '일반';
  bool _showAddForm = false;
  bool _noticeEnabled = true;
  String _displayMode = '하단 티커';
  int _itemDurationSec = 8;
  int _maxItems = 3;
  double _tickerHeight = 88;
  double _sidePanelWidth = 320;

  final List<_DeviceOption> _devices = const [
    _DeviceOption(id: _allDevices, label: '전체 디바이스'),
    _DeviceOption(id: 'board-1', label: '게시판1'),
    _DeviceOption(id: 'board-2', label: '게시판2'),
    _DeviceOption(id: 'board-3', label: '게시판3'),
    _DeviceOption(id: 'test-260331', label: '260331_테스트'),
    _DeviceOption(id: 'test-2260404', label: '2260404_1테스트'),
  ];

  List<String> get _categories {
    final categories = <String>{'전체', '일반', '시설안내', '학사알림', '진료변경'};
    for (final item in widget.initialItems) {
      final badge = item.badge.trim();
      if (badge.isNotEmpty && badge != '공지') {
        categories.add(badge);
      }
    }
    return categories.toList(growable: false);
  }

  bool get _isAllDevicesSelected => _selectedDeviceId == _allDevices;

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _addNotice() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 내용을 입력해주세요.')),
      );
      return;
    }

    _titleController.clear();
    _contentController.clear();
    setState(() {
      _showAddForm = false;
      _draftCategory = '일반';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('공지사항 등록 화면만 우선 구성했습니다.')),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF6FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '디바이스 선택',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedDeviceId,
                decoration: _inputDecoration('공지 대상 디바이스를 선택해주세요.'),
                items: _devices
                    .map(
                      (device) => DropdownMenuItem<String>(
                        value: device.id,
                        child: Text(device.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedDeviceId = value;
                    _showAddForm = false;
                  });
                },
              ),
            ],
          ),
        ),
        if (!_isAllDevicesSelected) ...[
          const SizedBox(height: 18),
          _SectionCard(
            accentColor: const Color(0xFF0EA5B7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '디스플레이 공지 표시 방식',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _displayMode,
                  decoration: _inputDecoration('표시 모드를 선택해주세요.'),
                  items: const [
                    DropdownMenuItem(value: '하단 티커', child: Text('하단 티커')),
                    DropdownMenuItem(value: '측면 패널', child: Text('측면 패널')),
                    DropdownMenuItem(value: '팝업 순환', child: Text('팝업 순환')),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _displayMode = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StepperField(
                        label: '노출 시간(초)',
                        value: _itemDurationSec,
                        min: 3,
                        max: 60,
                        onChanged: (value) {
                          setState(() {
                            _itemDurationSec = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StepperField(
                        label: '최대 개수',
                        value: _maxItems,
                        min: 1,
                        max: 20,
                        onChanged: (value) {
                          setState(() {
                            _maxItems = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: _noticeEnabled,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('공지 오버레이 사용'),
                  onChanged: (value) {
                    setState(() {
                      _noticeEnabled = value;
                    });
                  },
                ),
                if (_displayMode == '하단 티커') ...[
                  const SizedBox(height: 8),
                  Text('하단 티커 높이', style: theme.textTheme.labelLarge),
                  Slider(
                    value: _tickerHeight,
                    min: 48,
                    max: 220,
                    activeColor: const Color(0xFF0EA5B7),
                    onChanged: (value) {
                      setState(() {
                        _tickerHeight = value;
                      });
                    },
                  ),
                ],
                if (_displayMode == '측면 패널') ...[
                  const SizedBox(height: 8),
                  Text('측면 패널 너비', style: theme.textTheme.labelLarge),
                  Slider(
                    value: _sidePanelWidth,
                    min: 240,
                    max: 720,
                    activeColor: const Color(0xFF0EA5B7),
                    onChanged: (value) {
                      setState(() {
                        _sidePanelWidth = value;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 8),
                _NoticePreviewBox(
                  displayMode: _displayMode,
                  tickerHeight: _tickerHeight,
                  sidePanelWidth: _sidePanelWidth,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5B7),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('공지 표시 설정이 적용되었습니다.')),
                          );
                        },
                        child: const Text('공지 적용'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('해당 디바이스 공지가 취소되었습니다.')),
                          );
                        },
                        child: const Text('공지 취소'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.tonal(
                    onPressed: () {
                      setState(() {
                        _showAddForm = !_showAddForm;
                      });
                    },
                    child: Text(_showAddForm ? '등록 닫기' : '새 공지사항 등록'),
                  ),
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: _inputDecoration('카테고리'),
                      items: _categories
                          .map(
                            (category) => DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedCategory = value;
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _searchController,
                      decoration: _inputDecoration('제목 또는 내용 검색').copyWith(
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              if (_showAddForm) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF8F5),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFB8E6DE)),
                  ),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _draftCategory,
                        decoration: _inputDecoration('카테고리'),
                        items: _categories
                            .where((category) => category != '전체')
                            .map(
                              (category) => DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _draftCategory = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _titleController,
                        decoration: _inputDecoration('공지 제목'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _contentController,
                        maxLines: 4,
                        decoration: _inputDecoration('공지 내용'),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _addNotice,
                          child: const Text('등록'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    this.accentColor,
  });

  final Widget child;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: accentColor == null
            ? null
            : Border.all(color: accentColor!.withValues(alpha: 0.22)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StepperField extends StatelessWidget {
  const _StepperField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FAFB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: value > min ? () => onChanged(value - 1) : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              Expanded(
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              IconButton(
                onPressed: value < max ? () => onChanged(value + 1) : null,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoticePreviewBox extends StatelessWidget {
  const _NoticePreviewBox({
    required this.displayMode,
    required this.tickerHeight,
    required this.sidePanelWidth,
  });

  final String displayMode;
  final double tickerHeight;
  final double sidePanelWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF111827),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.3,
                  colors: [
                    Color(0x3322D3EE),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          if (displayMode == '하단 티커')
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: tickerHeight.clamp(48, 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xDD020617),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '진료 일정 변경 안내가 하단 공지 바 형태로 노출됩니다.',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          if (displayMode == '측면 패널')
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: Container(
                width: sidePanelWidth.clamp(180, 260),
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xD90F172A),
                  borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '공지사항',
                      style: TextStyle(
                        color: Color(0xFF67E8F9),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '측면 패널 미리보기',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '공지 본문이 오른쪽 패널 안에서 카드처럼 노출됩니다.',
                      style: TextStyle(
                        color: Color(0xFFE5E7EB),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (displayMode == '팝업 순환')
            Center(
              child: Container(
                width: 240,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xF8111827),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF2DD4BF)),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '팝업 순환',
                      style: TextStyle(
                        color: Color(0xFF99F6E4),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '중요 공지가 중앙 팝업 형태로 일정 시간씩 번갈아 표시됩니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DeviceOption {
  const _DeviceOption({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}
