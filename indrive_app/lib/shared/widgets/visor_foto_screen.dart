import 'package:flutter/material.dart';

import 'red_network_image.dart';

/// Visor de foto a pantalla completa con zoom (sprint extra: revisión de
/// KYC) — el Admin necesita poder ampliar cada documento/foto del
/// repartidor para leer detalles (número de placa, vencimiento, etc.),
/// no alcanza con la miniatura de 100x100 de la tarjeta.
void mostrarFotoCompleta(BuildContext context, String url, {String? titulo}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: titulo != null ? Text(titulo) : null,
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: RedNetworkImage(url),
          ),
        ),
      ),
    ),
  );
}
