import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gym_eldeeb/main.dart';

void main() {
  testWidgets('GymElDeebApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: GymElDeebApp()));
    await tester.pump();

    // Verify that the app renders successfully
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
