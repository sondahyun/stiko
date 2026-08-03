import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stiko/app/app.dart';

void main() {
  testWidgets('앱이 정상적으로 렌더링되고 홈 화면이 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: StikoApp()));
    await tester.pumpAndSettle();

    expect(find.text('stiko'), findsOneWidget);
    expect(find.text('할 일이 없습니다'), findsOneWidget);
  });
}
