import '../models/signage_item.dart';

class MockSignageRepository {
  const MockSignageRepository();

  Future<List<SignageItem>> fetchMessages() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    return [
      SignageItem(
        id: 'message-1',
        type: SignageItemType.message,
        title: '수업 시작 30분 전 장비 점검',
        summary: '강의실 디스플레이와 음향 장비 상태를 확인해주세요.',
        content:
            '오늘 첫 수업 전까지 강의실 디스플레이 전원, 음향 장비 연결 상태, 출석 단말 네트워크 연결을 모두 확인해주세요. 이상이 있는 경우 운영 담당자에게 바로 공유해 주세요.',
        publishedAt: DateTime(2026, 4, 9, 8, 30),
        badge: '긴급',
        isPinned: true,
      ),
      SignageItem(
        id: 'message-2',
        type: SignageItemType.message,
        title: '기상 상황에 따른 오후 수업 변동 가능',
        summary: '오후 3시 이후 수업 운영 여부를 재공지할 예정입니다.',
        content:
            '기상 악화 가능성으로 인해 오후 시간대 수업 일정이 일부 변동될 수 있습니다. 운영 여부는 오후 1시 30분에 최종 공지되며, 앱과 웹에 동시에 반영될 예정입니다.',
        publishedAt: DateTime(2026, 4, 9, 10, 0),
        badge: '중요',
      ),
      SignageItem(
        id: 'message-3',
        type: SignageItemType.message,
        title: '모바일 앱 연동 준비 상태',
        summary: '현재는 샘플 데이터로 구성되어 있으며 API 연결 준비 중입니다.',
        content:
            '앱 화면은 현재 목업 데이터를 표시하고 있습니다. 다음 단계에서는 로그인 인증, 메세지 조회, 공지사항 조회를 실제 서버 API에 연결할 예정입니다.',
        publishedAt: DateTime(2026, 4, 8, 17, 45),
        badge: '안내',
      ),
    ];
  }

  Future<List<SignageItem>> fetchNotices() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    return [
      SignageItem(
        id: 'notice-1',
        type: SignageItemType.notice,
        title: '4월 학부모 상담 일정 안내',
        summary: '이번 주 내로 신청 링크와 가능 시간표를 배포합니다.',
        content:
            '4월 학부모 상담은 4월 셋째 주부터 진행됩니다. 상담 신청 링크와 시간표는 이번 주 금요일 오후에 공지될 예정이며, 각 반별 가능한 시간대를 함께 안내드립니다.',
        publishedAt: DateTime(2026, 4, 8, 15, 0),
        badge: '공지',
        isPinned: true,
      ),
      SignageItem(
        id: 'notice-2',
        type: SignageItemType.notice,
        title: '신규 교재 입고 완료',
        summary: '리딩북과 스토리북 재고가 시스템에 반영되었습니다.',
        content:
            '신규 리딩북, 스토리북 재고 반영이 완료되었습니다. 필요한 반은 관리자에게 요청하시면 수업 일정에 맞춰 배부하겠습니다.',
        publishedAt: DateTime(2026, 4, 7, 14, 20),
        badge: '업데이트',
      ),
      SignageItem(
        id: 'notice-3',
        type: SignageItemType.notice,
        title: '앱 공지사항 화면 설계 초안',
        summary: '목록, 상세, 읽음 상태를 확장할 수 있도록 구조를 잡고 있습니다.',
        content:
            '공지사항 화면은 모바일에 맞춘 별도 UI로 구성하고 있으며, 이후 읽음 처리, 검색, 필터링 같은 기능도 단계적으로 확장할 수 있도록 설계 중입니다.',
        publishedAt: DateTime(2026, 4, 6, 9, 40),
        badge: '개발',
      ),
    ];
  }
}
