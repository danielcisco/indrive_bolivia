import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/location/places_service.dart';

/// Selector de ubicación de pantalla completa: pin fijo en el centro, el
/// mapa se mueve debajo (patrón estándar de apps de delivery). Devuelve un
/// [GeoPoint] vía `Navigator.pop` al confirmar.
///
/// Reutilizado tanto para origen como para destino en `CrearEnvioScreen` —
/// una sola pantalla genérica en vez de dos casi idénticas.
///
/// Incluye un buscador (Places Autocomplete) que solo mueve la cámara del
/// mapa hasta el lugar elegido — la confirmación sigue siendo manual
/// (arrastrar + botón "Confirmar ubicación"), así el usuario puede afinar
/// el punto si el resultado de la búsqueda no es exacto.
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

  GoogleMapController? _controller;
  final _busquedaController = TextEditingController();
  Timer? _debounce;
  List<SugerenciaLugar> _sugerencias = [];
  bool _buscando = false;
  String? _errorBusqueda;

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _alCambiarTexto(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _sugerencias = [];
        _errorBusqueda = null;
      });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _buscar(query),
    );
  }

  Future<void> _buscar(String query) async {
    setState(() {
      _buscando = true;
      _errorBusqueda = null;
    });
    try {
      final sugerencias = await buscarSugerencias(query);
      if (!mounted) return;
      setState(() => _sugerencias = sugerencias);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorBusqueda = 'No se pudo buscar: $error');
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _elegirSugerencia(SugerenciaLugar sugerencia) async {
    setState(() {
      _sugerencias = [];
      _busquedaController.text = sugerencia.texto;
      _buscando = true;
    });
    try {
      final coordenadas = await obtenerCoordenadas(sugerencia.placeId);
      _centro = coordenadas;
      await _controller?.animateCamera(CameraUpdate.newLatLng(coordenadas));
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorBusqueda = 'No se pudo ubicar el lugar: $error');
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _centro, zoom: 16),
            onMapCreated: (controller) => _controller = controller,
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Material(
                    elevation: 3,
                    borderRadius: BorderRadius.circular(12),
                    child: TextField(
                      controller: _busquedaController,
                      onChanged: _alCambiarTexto,
                      decoration: InputDecoration(
                        hintText: 'Buscar dirección o lugar...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _buscando
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  if (_errorBusqueda != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Material(
                        elevation: 3,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _errorBusqueda!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_sugerencias.isNotEmpty)
                    Material(
                      elevation: 3,
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 240),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _sugerencias.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final sugerencia = _sugerencias[index];
                            return ListTile(
                              leading: const Icon(Icons.place_outlined),
                              title: Text(sugerencia.texto),
                              onTap: () => _elegirSugerencia(sugerencia),
                            );
                          },
                        ),
                      ),
                    ),
                ],
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
