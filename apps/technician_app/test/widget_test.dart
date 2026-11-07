import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:technician_app/features/auth/presentation/login_page.dart';

void main() {
  testWidgets('App smoke test - verifies login page renders', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginPage(),
        ),
      ),
    );

    // Verify that the login page title is displayed.
    expect(find.text('Join Technician Member'), findsOneWidget);
  });
}
