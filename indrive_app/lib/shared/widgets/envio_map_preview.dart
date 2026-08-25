import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../domain/entities/envio.dart';

/// Mapa pequeño y no interactivo (modo "lite") con los puntos de un envío
/// — origen y destino siempre, y la posición en vivo del repartidor cuando
/// está disponible (envío `en_curso`, Sprint 4.1b). Al usarse junto con
/// `envioStreamProvider`, cada actualización de posición reconstruye este
/// widget con el marcador en su lugar nuevo — no hay animación suave (el
/// modo lite renderiza una instantánea), pero se actualiza solo, sin que
/// el usuario tenga que refrescar.
class EnvioMapPreview extends StatelessWidget {
  const EnvioMapPreview({super.key, required this.envio});

  final Envio envio;

  @override
  Widget build(BuildContext context) {
    final origen = LatLng(envio.origen.latitude, envio.origen.longitude);
    final destino = LatLng(envio.destino.latitude, envio.destino.longitude);
    final posicionRepartidor = envio.repartidorPosicionActual;
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
            if (posicionRepartidor != null)
              Marker(
                markerId: const MarkerId('repartidor'),
                position: LatLng(
                  posicionRepartidor.latitude,
                  posicionRepartidor.longitude,
                ),
                infoWindow: const InfoWindow(title: 'Repartidor'),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure,
                ),
              ),
          },
        ),
      ),
    );
  }
}
