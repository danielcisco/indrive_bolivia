import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Selector de ubicación de pantalla completa: pin fijo en el centro, el
/// mapa se mueve debajo (patrón estándar de apps de delivery). Devuelve un
/// [GeoPoint] vía `Navigator.pop` al confirmar.
///
/// Reutilizado tanto para origen como para destino en `CrearEnvioScreen` —
/// una sola pantalla genérica en vez de dos casi idénticas.
class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key, required this.title, this.posicionInicial});

  final String title;
  final LatLng? posicionInicial;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  // Villazón, Potosí — centro por defecto si no hay lectura GPS previa.
  static const _fallback = LatLng(-22.0864, -65.5946);
  static const _pinSize = 48.0;

  late LatLng _centro = widget.posicionInicial ?? _fallback;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _centro, zoom: 16),
            onCameraMove: (position) => _centro = position.target,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),
          // El pin queda fijo en el centro de la pantalla; su punta (no su
          // centro geométrico) debe señalar la coordenada elegida, por eso
          // se desplaza hacia arriba la mitad de su alto.
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -_pinSize / 2),
                child: const Icon(
                  Icons.location_pin,
                  size: _pinSize,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).pop(GeoPoint(_centro.latitude, _centro.longitude)),
        icon: const Icon(Icons.check),
        label: const Text('Confirmar ubicación'),
      ),
    );
  }
}
