import 'package:flutter_test/flutter_test.dart';

import 'package:indrive_app/main_cliente.dart';

void main() {
  testWidgets('ClienteApp monta sin excepciones', (WidgetTester tester) async {
    await tester.pumpWidget(const ClienteApp());

    expect(find.text('inDrive Entregas — Cliente'), findsOneWidget);
    expect(find.text('App Cliente — Villazón, Potosí'), findsOneWidget);
  });
}
