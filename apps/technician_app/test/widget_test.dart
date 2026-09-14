import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:technician_app/app/app.dart';

void main() {
  testWidgets('App smoke test - verifies login page renders', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: TechnicianApp(),
      ),
    );

    // Verify that the login page title is displayed.
    expect(find.text('BookUrTechnician Pro'), findsOneWidget);
  });
}
