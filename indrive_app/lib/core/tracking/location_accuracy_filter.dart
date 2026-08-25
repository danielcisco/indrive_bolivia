import 'package:geolocator/geolocator.dart';

/// Precisión mínima aceptable (metros) para una lectura GPS del tracking
/// del repartidor. Lecturas peores que esto (ej. rebote de señal en
/// interiores) se descartan antes de escribirse a Firestore.
const double defaultMaxAccuracyMetros = 50;

/// Función pura (sin Firestore ni GPS real) para poder testear el filtro
/// de precisión sin dispositivo — el throttling por distancia lo resuelve
/// `distanceFilter` del propio proveedor de ubicación, esto solo filtra
/// calidad de la señal.
bool esPosicionValida(
  Position position, {
  double maxAccuracyMetros = defaultMaxAccuracyMetros,
}) {
  return position.accuracy <= maxAccuracyMetros;
}
