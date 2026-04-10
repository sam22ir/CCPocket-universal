import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ccpocket_mobile/main.dart';

void main() {
  testWidgets('App smoke test', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CCPocketApp()));
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
