import 'package:flutter_test/flutter_test.dart';

import 'package:signage_mobile_app/app.dart';
import 'package:signage_mobile_app/app_dependencies.dart';
import 'package:signage_mobile_app/app_environment.dart';
import 'package:signage_mobile_app/services/mock_auth_service.dart';
import 'package:signage_mobile_app/services/mock_content_service.dart';

void main() {
  testWidgets('로그인 후 메세지 탭 데이터와 상세 화면이 보인다', (tester) async {
    const environment = AppEnvironment(
      useMockAuthService: true,
      useMockContentService: true,
      serverBaseUrl: 'https://sg.cothink.co.kr',
      apiBaseUrl: 'https://sg.cothink.co.kr',
    );
    const dependencies = AppDependencies(
      authService: MockAuthService(),
      contentService: MockContentService(),
    );

    await tester.pumpWidget(
      const SignageMobileApp(
        environment: environment,
        dependencies: dependencies,
      ),
    );

    expect(find.text('로그인'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'admin');
    await tester.enterText(find.byType(TextFormField).at(1), '1234');
    await tester.tap(find.text('로그인'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('메세지'), findsOneWidget);
    expect(find.text('공지사항'), findsOneWidget);
    expect(find.text('Blossom 관리자님, 긴급메세지와 공지사항을 확인하세요.'), findsOneWidget);
    expect(find.text('수업 시작 30분 전 장비 점검'), findsOneWidget);

    await tester.tap(find.text('수업 시작 30분 전 장비 점검'));
    await tester.pumpAndSettle();

    expect(find.text('메세지 상세'), findsOneWidget);
    expect(find.textContaining('강의실 디스플레이 전원'), findsOneWidget);
  });
}
