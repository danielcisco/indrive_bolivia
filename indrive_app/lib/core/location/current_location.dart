import 'package:geolocator/geolocator.dart';

/// Pide permiso de ubicación si hace falta y devuelve una lectura GPS
/// puntual. Compartido por Cliente (origen de un envío) y Repartidor
/// (radar) — sin throttling ni streaming continuo, eso es para el
/// seguimiento en vivo del repartidor en Fase 4.
Future<Position> obtenerUbicacionActual() async {
  var permiso = await Geolocator.checkPermission();
  if (permiso == LocationPermission.denied) {
    permiso = await Geolocator.requestPermission();
  }
  if (permiso == LocationPermission.denied ||
      permiso == LocationPermission.deniedForever) {
    throw StateError(
      'Permiso de ubicación denegado. Actívalo en Ajustes para continuar.',
    );
  }
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw StateError('El GPS está desactivado en el dispositivo.');
  }
  return Geolocator.getCurrentPosition();
}
