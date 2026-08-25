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

    group('parseBobString', () {
      test('parsea enteros y decimales sin pasar por double', () {
        expect(Money.parseBobString('15').centavos, 1500);
        expect(Money.parseBobString('15.5').centavos, 1550);
        expect(Money.parseBobString('15.50').centavos, 1550);
        expect(Money.parseBobString('0.05').centavos, 5);
      });

      test('acepta coma como separador decimal', () {
        expect(Money.parseBobString('15,50').centavos, 1550);
      });

      test('ignora espacios alrededor del input', () {
        expect(Money.parseBobString(' 20.00 ').centavos, 2000);
      });

      test('rechaza más de 2 decimales', () {
        expect(
          () => Money.parseBobString('15.500'),
          throwsA(isA<FormatException>()),
        );
      });

      test('rechaza texto no numérico', () {
        expect(
          () => Money.parseBobString('abc'),
          throwsA(isA<FormatException>()),
        );
      });
    });
  });
}
