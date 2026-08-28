import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../shared/widgets/marcador_repartidor.dart';
import '../../../../shared/widgets/soporte_whatsapp.dart';
import '../providers/radar_controller.dart';
import '../screens/envio_repartidor_detalle_screen.dart';

const _centroVillazon = LatLng(-22.0864, -65.5946);

/// Mapa de envíos pendientes cerca del repartidor (sprint extra: "casi
/// toda la pantalla disponible" del Home, ahora que la navegación se
/// movió al Drawer) — mismos datos que ya trae `radarControllerProvider`
/// (sondeo adaptativo por geohash, ver su doc para el porqué no es un
/// stream), solo que acá se dibujan como pines en vez de una lista. Cada
/// pin es un ícono de paquete ámbar, sin más info que eso hasta que se
/// toca — coherente con "solo un ícono" pedido para este mapa.
class RadarMapa extends ConsumerStatefulWidget {
  const RadarMapa({super.key});

  @override
  ConsumerState<RadarMapa> createState() => _RadarMapaState();
}

class _RadarMapaState extends ConsumerState<RadarMapa> {
  BitmapDescriptor? _icono;

  @override
  void initState() {
    super.initState();
    iconoEnvioPendiente().then((icono) {
      if (mounted) setState(() => _icono = icono);
    });
  }

  @override
  Widget build(BuildContext context) {
    final radar = ref.watch(radarControllerProvider);

    return radar.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => const SupportErrorView(
        mensaje: 'No pudimos cargar el radar. Revisá tu conexión y el '
            'permiso de ubicación.',
        app: 'Repartidor',
        motivo: 'no puedo ver el mapa de envíos cercanos',
      ),
      data: (estado) {
        final marcadores = <Marker>{
          for (final envio in estado.envios)
            Marker(
              markerId: MarkerId(envio.id),
              position: LatLng(envio.origen.latitude, envio.origen.longitude),
              icon:
                  _icono ??
                  BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueOrange,
                  ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      EnvioRepartidorDetalleScreen(envioId: envio.id),
                ),
              ),
            ),
        };

        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _centroVillazon,
                zoom: 14,
              ),
              markers: marcadores,
              myLocationButtonEnabled: false,
            ),
            if (estado.envios.isEmpty)
              const Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'No hay envíos pendientes cerca por ahora.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
