// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:edge_tts_demo/main.dart';

void main() {
  testWidgets('EdgeTTS Demo smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const EdgeTTSDemoApp());

    // Verify that the app title is displayed.
    expect(find.text('EdgeTTS Demo'), findsOneWidget);

    // Verify that the main UI elements are present.
    expect(find.text('Text to Convert'), findsOneWidget);
    expect(find.text('Voice Selection'), findsOneWidget);
    expect(find.text('Speech Controls'), findsOneWidget);
    expect(find.text('Convert & Play'), findsOneWidget);
  });
}
