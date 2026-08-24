import 'package:flutter_test/flutter_test.dart';
import 'package:indrive_app/shared/domain/value_objects/money.dart';

void main() {
  group('Money', () {
    test('suma y resta operan en centavos enteros', () {
      const a = Money.centavos(1500);
      const b = Money.centavos(250);
      expect((a + b).centavos, 1750);
      expect((a - b).centavos, 1250);
    });

    test('format() muestra bolivianos con 2 decimales', () {
      expect(const Money.centavos(1500).format(), 'Bs. 15.00');
      expect(const Money.centavos(105).format(), 'Bs. 1.05');
    });

    test('comparadores operan sobre centavos', () {
      expect(const Money.centavos(200) > const Money.centavos(100), isTrue);
      expect(const Money.centavos(100) < const Money.centavos(200), isTrue);
      expect(const Money.centavos(100) == const Money.centavos(100), isTrue);
    });

    test('rechaza montos negativos', () {
      expect(() => Money.centavos(-1), throwsA(isA<AssertionError>()));
    });
  });
}
