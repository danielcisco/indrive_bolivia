import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../shared/data/providers.dart';
import '../../../../shared/widgets/marcador_repartidor.dart';
import '../../../../shared/widgets/soporte_whatsapp.dart';

/// Villazón, Potosí — mismo centro por defecto que `MapPickerScreen`.
const _centroVillazon = LatLng(-22.0864, -65.5946);

/// Mapa en vivo de todos los envíos `en_curso` (Sprint 5.1) — lee de
/// `enviosEnCursoStreamProvider` (stream acotado por status + `.limit()`,
/// ver `EnviosRepository.streamEnviosEnCurso`).
class LiveMapScreen extends ConsumerStatefulWidget {
  const LiveMapScreen({super.key});

  @override
  ConsumerState<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends ConsumerState<LiveMapScreen> {
  BitmapDescriptor? _iconoRepartidor;

  @override
  void initState() {
    super.initState();
    iconoRepartidor().then((icono) {
      if (mounted) setState(() => _iconoRepartidor = icono);
    });
  }

  @override
  Widget build(BuildContext context) {
    final enviosEnCurso = ref.watch(enviosEnCursoStreamProvider);

    return enviosEnCurso.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => const SupportErrorView(
        mensaje: 'No pudimos cargar el mapa en vivo. Revisá tu conexión y '
            'volvé a intentar.',
        app: 'Admin',
        motivo: 'no puedo ver el mapa en vivo',
      ),
      data: (envios) {
        // Nombre del repartidor de cada envío — perfiles_publicos/{uid} es
        // lectura abierta a cualquier autenticado (Admin incluido), así
        // que alcanza con watchear el provider por cada uno, sin lógica
        // nueva de datos.
        String nombreRepartidor(String? repartidorId) {
          if (repartidorId == null) return 'Sin repartidor';
          return ref
              .watch(perfilPublicoProvider(repartidorId))
              .when(
                loading: () => 'Repartidor: cargando...',
                error: (error, _) => 'Repartidor: error al cargar perfil',
                // Cuenta que nunca completó nombre/apellido/nick (ej. de
                // antes de que existiera ese paso) — no es un estado de
                // carga, es que perfiles_publicos/{uid} no existe.
                data: (perfil) => perfil == null
                    ? 'Repartidor sin perfil registrado'
                    : '${perfil.nombre} ${perfil.apellido} (@${perfil.nick})',
              );
        }

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
                  title: nombreRepartidor(envio.repartidorAsignadoId),
                  snippet:
                      '${envio.descripcion} · ${envio.montoOfertadoInicial.format()}',
                ),
                icon:
                    _iconoRepartidor ??
                    BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${envios.length} entregas en curso',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      for (final envio in envios)
                        Text(
                          nombreRepartidor(envio.repartidorAsignadoId),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
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
