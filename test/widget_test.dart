import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flux_notes/main.dart';

void main() {
  testWidgets('HomeScreen has a title and a floating action button',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    // Verify that our app has the correct title.
    expect(find.text('My Notes'), findsOneWidget);

    // Verify that our app has a floating action button.
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
