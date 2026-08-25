import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../domain/entities/envio.dart';

/// Mapa pequeño y no interactivo (modo "lite") con los 2 puntos de un
/// envío, en vez de mostrar coordenadas crudas. Sin tracking en vivo
/// todavía — eso es Sprint 4.1b.
class EnvioMapPreview extends StatelessWidget {
  const EnvioMapPreview({super.key, required this.envio});

  final Envio envio;

  @override
  Widget build(BuildContext context) {
    final origen = LatLng(envio.origen.latitude, envio.origen.longitude);
    final destino = LatLng(envio.destino.latitude, envio.destino.longitude);
    final centro = LatLng(
      (origen.latitude + destino.latitude) / 2,
      (origen.longitude + destino.longitude) / 2,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 220,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: centro, zoom: 13),
          liteModeEnabled: true,
          zoomControlsEnabled: false,
          markers: {
            Marker(
              markerId: const MarkerId('origen'),
              position: origen,
              infoWindow: const InfoWindow(title: 'Origen'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
            ),
            Marker(
              markerId: const MarkerId('destino'),
              position: destino,
              infoWindow: const InfoWindow(title: 'Destino'),
            ),
          },
        ),
      ),
    );
  }
}
