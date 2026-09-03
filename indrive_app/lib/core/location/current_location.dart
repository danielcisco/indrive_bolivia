import 'package:geolocator/geolocator.dart';

/// Se resetea con cada arranque de la app (variable de archivo, no
/// persistida) — evita volver a llamar `Geolocator.requestPermission()`
/// más de una vez por sesión. Sin esto, el sondeo automático del radar de
/// Repartidor (cada 20s mientras Home está abierto) vuelve a disparar el
/// diálogo nativo de Android en cada ciclo mientras el permiso siga en
/// `denied`, sin que el usuario haya tocado nada.
bool _permisoSolicitadoEnEstaSesion = false;

/// Pide permiso de ubicación si hace falta y devuelve una lectura GPS
/// puntual. Compartido por Cliente (origen de un envío) y Repartidor
/// (radar) — sin throttling ni streaming continuo, eso es para el
/// seguimiento en vivo del repartidor en Fase 4.
Future<Position> obtenerUbicacionActual() async {
  var permiso = await Geolocator.checkPermission();
  if (permiso == LocationPermission.denied && !_permisoSolicitadoEnEstaSesion) {
    _permisoSolicitadoEnEstaSesion = true;
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
