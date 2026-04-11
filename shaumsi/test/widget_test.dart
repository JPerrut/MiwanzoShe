import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shaumsi/src/app.dart';

void main() {
  testWidgets('ShauMsi exige senha antes de liberar o app', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ShauMsiApp());

    expect(find.text('ShauMsi protegido'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
