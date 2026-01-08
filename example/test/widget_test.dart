// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App starts at home screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthNotifier(),
        child: MyApp(navigatorKey: navigatorKey),
      ),
    );

    // Verify that we start at Home screen with Guest status
    expect(find.text('Status: Guest'), findsOneWidget);
    expect(find.text('Go to Login'), findsOneWidget);
  });
}
