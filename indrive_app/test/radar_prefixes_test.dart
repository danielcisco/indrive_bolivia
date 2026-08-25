import 'package:flutter_test/flutter_test.dart';
import 'package:indrive_app/features/repartidor/presentation/providers/radar_controller.dart';

void main() {
  group('prefijosParaSondeoAdaptativo', () {
    test('genera prefijos decrecientes del más específico al más amplio', () {
      final prefijos = prefijosParaSondeoAdaptativo(
        '6s1673f4w',
        precisionInicial: 6,
        precisionMinima: 3,
      );
      expect(prefijos, ['6s1673', '6s167', '6s16', '6s1']);
    });

    test('se detiene en precisionMinima aunque sea igual a la inicial', () {
      final prefijos = prefijosParaSondeoAdaptativo(
        '6s1673f4w',
        precisionInicial: 4,
        precisionMinima: 4,
      );
      expect(prefijos, ['6s16']);
    });

    test('cada prefijo es efectivamente prefijo del geohash completo', () {
      const geohash = '6s1673f4w';
      final prefijos = prefijosParaSondeoAdaptativo(geohash);
      for (final prefijo in prefijos) {
        expect(geohash.startsWith(prefijo), isTrue);
      }
    });
  });
}
