import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Se dibuja a 96px de resolución para que se vea nítido en pantallas de
// alta densidad, pero se le pide a Maps que lo muestre a _tamanoLogico —
// sin esto, Maps lo mostraba a 96 píxeles LÓGICOS (el doble o más de lo
// que mide un pin normal), desproporcionado en el mapa.
const _tamano = 96.0;
const _tamanoLogico = 40.0;

Future<BitmapDescriptor>? _cache;

/// Ícono de marcador para la posición en vivo del repartidor (círculo azul
/// con `Icons.two_wheeler`) — reemplaza el pin default `hueAzure` que se
/// usaba en `EnvioMapPreview` y `LiveMapScreen`, para que se identifique de
/// un vistazo entre origen/destino/otros pines del mapa. Se genera una
/// sola vez por sesión de la app (patrón estándar de Flutter para íconos
/// de marker sin agregar un asset de imagen) y se cachea acá, compartido
/// por los dos mapas que lo usan.
Future<BitmapDescriptor> iconoRepartidor() {
  return _cache ??= _generar();
}

Future<BitmapDescriptor> _generar() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  canvas.drawCircle(
    const Offset(_tamano / 2, _tamano / 2),
    _tamano / 2,
    Paint()..color = Colors.blue,
  );

  final painter = TextPainter(textDirection: TextDirection.ltr)
    ..text = TextSpan(
      text: String.fromCharCode(Icons.two_wheeler.codePoint),
      style: TextStyle(
        fontSize: _tamano * 0.6,
        fontFamily: Icons.two_wheeler.fontFamily,
        package: Icons.two_wheeler.fontPackage,
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
