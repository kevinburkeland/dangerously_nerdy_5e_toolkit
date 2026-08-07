import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/main.dart';

void main() {
  testWidgets('App launches and displays landing screen', (WidgetTester tester) async {
    await tester.pumpWidget(const DangerouslyNerdy5eToolkitApp());
    expect(find.text('DangerouslyNerdy 5e Toolkit'), findsWidgets);
  });
}
