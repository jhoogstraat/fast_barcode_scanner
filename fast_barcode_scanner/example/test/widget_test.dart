import 'package:fast_barcode_scanner_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HomeScreen renders scanner entry actions',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('Fast Barcode Scanner'), findsOneWidget);
    expect(find.text('Open Scanner'), findsOneWidget);
    expect(find.text('Scan image'), findsOneWidget);
  });
}
