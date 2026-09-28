import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_attendance_app/main.dart';

void main() {
  testWidgets('App renders login screen title and input fields', (WidgetTester tester) async {
    await tester.pumpWidget(const GeoAttendApp());

    expect(find.text('Welcome to GeoAttend'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });
}
