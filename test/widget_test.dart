import 'package:flutter_test/flutter_test.dart';
import 'package:my_ludo/main.dart';

void main() {
  testWidgets('App starts and shows home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyLudoApp());
    expect(find.text('MY LUDO'), findsOneWidget);
  });
}
