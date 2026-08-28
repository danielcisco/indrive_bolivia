import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Se dibuja a 96px de resolución para que se vea nítido en pantallas de
// alta densidad, pero se le pide a Maps que lo muestre a _tamanoLogico —
// sin esto, Maps lo mostraba a 96 píxeles LÓGICOS (el doble o más de lo
// que mide un pin normal), desproporcionado en el mapa.
const _tamano = 96.0;
const _tamanoLogico = 40.0;

final Map<String, Future<BitmapDescriptor>> _cache = {};

/// Ícono de marcador para la posición en vivo del repartidor (círculo azul
/// con `Icons.two_wheeler`/`Icons.directions_car`, según [tipoVehiculo]) —
/// reemplaza el pin default `hueAzure` que se usaba en `EnvioMapPreview` y
/// `LiveMapScreen`, para que se identifique de un vistazo entre
/// origen/destino/otros pines del mapa. Se genera una sola vez por tipo por
/// sesión de la app (patrón estándar de Flutter para íconos de marker sin
/// agregar un asset de imagen) y se cachea acá, compartido por los mapas
/// que lo usan.
///
/// [tipoVehiculo] es `'auto'` o cualquier otra cosa (incluido null/'moto')
/// — moto es el default porque es el vehículo más común en la operación
/// real de Villazón.
Future<BitmapDescriptor> iconoRepartidor({String? tipoVehiculo}) {
  final clave = tipoVehiculo == 'auto' ? 'auto' : 'moto';
  return _cache.putIfAbsent(
    clave,
    () => _generar(
      icono: tipoVehiculo == 'auto' ? Icons.directions_car : Icons.two_wheeler,
      color: Colors.blue,
    ),
  );
}

/// Ícono de marcador para un envío pendiente en el radar del Repartidor
/// (sprint extra) — ámbar en vez de azul, para no confundirse con los
/// marcadores de posición de repartidor que ya usan azul en el resto de
/// la app.
Future<BitmapDescriptor> iconoEnvioPendiente() {
  return _cache.putIfAbsent(
    'envio_pendiente',
    () => _generar(icono: Icons.inventory_2_outlined, color: Colors.amber.shade800),
  );
}

Future<BitmapDescriptor> _generar({
  required IconData icono,
  required Color color,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  canvas.drawCircle(
    const Offset(_tamano / 2, _tamano / 2),
    _tamano / 2,
    Paint()..color = color,
  );

  final painter = TextPainter(textDirection: TextDirection.ltr)
    ..text = TextSpan(
      text: String.fromCharCode(icono.codePoint),
      style: TextStyle(
        fontSize: _tamano * 0.6,
        fontFamily: icono.fontFamily,
        package: icono.fontPackage,
        color: Colors.white,
      ),
    )
    ..layout();
  painter.paint(
    canvas,
    Offset((_tamano - painter.width) / 2, (_tamano - painter.height) / 2),
  );

  final imagen = await recorder.endRecording().toImage(
    _tamano.toInt(),
    _tamano.toInt(),
  );
  final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(
    bytes!.buffer.asUint8List(),
    width: _tamanoLogico,
    height: _tamanoLogico,
  );
}
