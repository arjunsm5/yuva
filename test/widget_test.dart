import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuva/main.dart'; // Ensure this points to the correct file

void main() {
  testWidgets('Yuva app loads and adds opportunity', (
      WidgetTester tester,
      ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());  // Use MyApp instead of YuvaApp

    // Verify that the app loads with the splash screen.
    expect(find.text('Yuva Opportunities'), findsNothing);  // SplashScreen might not show this text yet
    expect(find.text('New Opportunity'), findsNothing);

    // Wait for the splash screen to complete (if necessary).
    await tester.pumpAndSettle(); // If you have a delay, ensure it settles

    // Verify that the opportunity screen is shown after the splash screen.
    expect(find.text('Yuva Opportunities'), findsOneWidget);
    expect(find.text('New Opportunity'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();  // Wait for async operations (e.g., Firebase set)

    // Verify that a new opportunity is added.
    expect(find.text('New Opportunity'), findsOneWidget);
  });
}
