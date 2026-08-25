import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:indrive_app/core/tracking/location_accuracy_filter.dart';

Position _posicionConPrecision(double accuracy) {
  return Position(
    latitude: -22.0864,
    longitude: -65.5946,
    timestamp: DateTime.now(),
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  group('esPosicionValida', () {
    test('acepta una lectura con precisión mejor que el máximo', () {
      final posicion = _posicionConPrecision(10);
      expect(esPosicionValida(posicion, maxAccuracyMetros: 50), isTrue);
    });

    test('rechaza una lectura con precisión peor que el máximo', () {
      final posicion = _posicionConPrecision(120);
      expect(esPosicionValida(posicion, maxAccuracyMetros: 50), isFalse);
    });

    test('acepta exactamente en el límite', () {
      final posicion = _posicionConPrecision(50);
      expect(esPosicionValida(posicion, maxAccuracyMetros: 50), isTrue);
    });

    test('usa 50 metros como máximo por defecto', () {
      expect(esPosicionValida(_posicionConPrecision(49)), isTrue);
      expect(esPosicionValida(_posicionConPrecision(51)), isFalse);
    });
  });
}
