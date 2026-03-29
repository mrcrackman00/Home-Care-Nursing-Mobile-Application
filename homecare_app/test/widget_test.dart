import 'package:flutter_test/flutter_test.dart';
import 'package:homecare_app/main.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await tester.pumpWidget(const HomeCareApp());
  });
}
