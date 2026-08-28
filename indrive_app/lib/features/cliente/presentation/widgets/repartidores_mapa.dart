import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../shared/data/providers.dart';
import '../../../../shared/widgets/marcador_repartidor.dart';
import '../../../../shared/widgets/soporte_whatsapp.dart';

const _centroVillazon = LatLng(-22.0864, -65.5946);

/// Mapa de repartidores disponibles cerca (sprint extra: "casi toda la
/// pantalla disponible" del Home, ahora que la navegación se movió al
/// Drawer) — lee `repartidores_disponibles/` (colección pública acotada,
/// ver `firestore.rules`), sin más info por pin que el ícono de
/// auto/moto según `tipoVehiculo`, coherente con "solo un ícono" pedido.
class RepartidoresMapa extends ConsumerStatefulWidget {
  const RepartidoresMapa({super.key});

  @override
  ConsumerState<RepartidoresMapa> createState() => _RepartidoresMapaState();
}

class _RepartidoresMapaState extends ConsumerState<RepartidoresMapa> {
  BitmapDescriptor? _iconoMoto;
  BitmapDescriptor? _iconoAuto;

  @override
  void initState() {
    super.initState();
    iconoRepartidor(tipoVehiculo: 'moto').then((icono) {
      if (mounted) setState(() => _iconoMoto = icono);
    });
    iconoRepartidor(tipoVehiculo: 'auto').then((icono) {
      if (mounted) setState(() => _iconoAuto = icono);
    });
  }

  @override
  Widget build(BuildContext context) {
    final repartidores = ref.watch(repartidoresDisponiblesProvider);

    return repartidores.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => const SupportErrorView(
        mensaje: 'No pudimos cargar el mapa de repartidores. Revisá tu '
            'conexión y volvé a intentar.',
        app: 'Cliente',
        motivo: 'no puedo ver el mapa de repartidores disponibles',
      ),
      data: (snapshot) {
        final marcadores = <Marker>{
          for (final doc in snapshot.docs)
            if (doc.data()['posicion'] is GeoPoint)
              Marker(
                markerId: MarkerId(doc.id),
                position: LatLng(
                  (doc.data()['posicion'] as GeoPoint).latitude,
                  (doc.data()['posicion'] as GeoPoint).longitude,
                ),
                icon:
                    (doc.data()['tipoVehiculo'] == 'auto'
                        ? _iconoAuto
                        : _iconoMoto) ??
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
              myLocationButtonEnabled: false,
            ),
            if (snapshot.docs.isEmpty)
              const Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'No hay repartidores disponibles cerca por ahora.',
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
