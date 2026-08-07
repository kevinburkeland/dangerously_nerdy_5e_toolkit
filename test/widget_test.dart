import 'package:flutter_test/flutter_test.dart';
import 'package:animate_objects_5e/main.dart';

void main() {
  testWidgets('App launches and displays landing screen', (WidgetTester tester) async {
    await tester.pumpWidget(const DangerouslyNerdy5eToolkitApp());
    expect(find.text('DangerouslyNerdy 5e Toolkit'), findsWidgets);
  });
}
