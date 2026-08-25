import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../shared/data/providers.dart';

/// Villazón, Potosí — mismo centro por defecto que `MapPickerScreen`.
const _centroVillazon = LatLng(-22.0864, -65.5946);

/// Mapa en vivo de todos los envíos `en_curso` (Sprint 5.1) — lee de
/// `enviosEnCursoStreamProvider` (stream acotado por status + `.limit()`,
/// ver `EnviosRepository.streamEnviosEnCurso`).
class LiveMapScreen extends ConsumerWidget {
  const LiveMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enviosEnCurso = ref.watch(enviosEnCursoStreamProvider);

    return enviosEnCurso.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (envios) {
        final marcadores = <Marker>{
          for (final envio in envios)
            if (envio.repartidorPosicionActual != null)
              Marker(
                markerId: MarkerId(envio.id),
                position: LatLng(
                  envio.repartidorPosicionActual!.latitude,
                  envio.repartidorPosicionActual!.longitude,
                ),
                infoWindow: InfoWindow(
                  title: envio.descripcion,
                  snippet: envio.montoOfertadoInicial.format(),
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
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text('${envios.length} entregas en curso'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
