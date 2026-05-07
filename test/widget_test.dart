// This is the basic smoke test for your app
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bhagavad_gita/main.dart';  // ← important: import your real main.dart

void main() {
  testWidgets('App smoke test - should build without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BhagavadGitaApp());  // ← changed from MyApp

    // Verify that the app title is present
    expect(find.text('Bhagavad Gita'), findsOneWidget);

    // You can add more basic checks if you want
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });
}