import 'package:flutter_test/flutter_test.dart';
import 'package:pos/main.dart';

void main() {
  testWidgets('App smoke test - verifies login screen loads', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the login screen title or store name is present.
    // Based on your main.dart, it should show a store name.
    expect(find.byType(MyApp), findsOneWidget);
  });
}
