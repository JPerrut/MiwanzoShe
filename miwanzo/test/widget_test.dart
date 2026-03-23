import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:miwanzo/src/app.dart';

void main() {
  testWidgets('Miwanzo exibe estado inicial', (WidgetTester tester) async {
    await tester.pumpWidget(const MiwanzoApp());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
