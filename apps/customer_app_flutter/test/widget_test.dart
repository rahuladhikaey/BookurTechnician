// Widget test for BookUrTechnician Customer App.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app_flutter/main.dart';

void main() {
  testWidgets('App smoke test — renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: CustomerApp()),
    );
    // App should render the onboarding screen initially
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
