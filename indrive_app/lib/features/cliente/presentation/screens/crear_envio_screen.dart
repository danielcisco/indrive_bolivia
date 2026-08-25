import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

import '../../../../core/location/current_location.dart';
import '../../../../shared/domain/value_objects/money.dart';
import '../../../../shared/widgets/map_picker_screen.dart';
import '../providers/crear_envio_controller.dart';

class CrearEnvioScreen extends ConsumerStatefulWidget {
  const CrearEnvioScreen({super.key});

  @override
  ConsumerState<CrearEnvioScreen> createState() => _CrearEnvioScreenState();
}

class _CrearEnvioScreenState extends ConsumerState<CrearEnvioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionController = TextEditingController();
  final _montoController = TextEditingController();

  GeoPoint? _origen;
  GeoPoint? _destino;
  String? _errorUbicacion;

  @override
  void dispose() {
    _descripcionController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  /// Intenta centrar el picker en el GPS actual; si falla (permiso
  /// denegado, GPS apagado), el picker igual abre centrado en Villazón —
  /// una lectura fallida no debe bloquear elegir la ubicación a mano.
  Future<LatLng?> _posicionInicialPara({GeoPoint? preferida}) async {
    if (preferida != null) {
      return LatLng(preferida.latitude, preferida.longitude);
    }
    try {
      final posicion = await obtenerUbicacionActual();
      return LatLng(posicion.latitude, posicion.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> _elegirOrigen() async {
    setState(() => _errorUbicacion = null);
    final inicial = await _posicionInicialPara();
    if (!mounted) return;
    final resultado = await Navigator.of(context).push<GeoPoint>(
      MaterialPageRoute(
        builder: (_) =>
            MapPickerScreen(title: 'Elegir origen', posicionInicial: inicial),
      ),
    );
    if (resultado != null && mounted) {
      setState(() => _origen = resultado);
    }
  }

  Future<void> _elegirDestino() async {
    setState(() => _errorUbicacion = null);
    final inicial = await _posicionInicialPara(preferida: _origen);
    if (!mounted) return;
    final resultado = await Navigator.of(context).push<GeoPoint>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          title: 'Elegir destino',
          posicionInicial: inicial,
        ),
      ),
    );
    if (resultado != null && mounted) {
      setState(() => _destino = resultado);
    }
  }

  Future<void> _enviar() async {
    final origen = _origen;
    final destino = _destino;
    if (!_formKey.currentState!.validate()) return;
    if (origen == null || destino == null) {
      setState(
        () => _errorUbicacion = 'Elige el origen y el destino en el mapa.',
      );
      return;
    }

    final monto = Money.parseBobString(_montoController.text);

    await ref
        .read(crearEnvioControllerProvider.notifier)
        .crear(
          descripcion: _descripcionController.text.trim(),
          origen: origen,
          destino: destino,
          montoOfertadoInicial: monto,
        );

    if (!mounted) return;
    final estado = ref.read(crearEnvioControllerProvider);
    if (!estado.hasError) {
      Navigator.of(context).pop();
    }
  }

  String _formatearPunto(GeoPoint? punto) {
    if (punto == null) return 'sin definir';
    return '${punto.latitude.toStringAsFixed(5)}, '
        '${punto.longitude.toStringAsFixed(5)}';
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(crearEnvioControllerProvider);
    ref.listen(crearEnvioControllerProvider, (previous, next) {
      final error = next.error;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Crear envío')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción del paquete',
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                    ? 'Requerido'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _montoController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monto ofertado (Bs.)',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Requerido';
                  try {
                    Money.parseBobString(value);
                    return null;
                  } on FormatException {
                    return 'Monto inválido';
                  }
                },
              ),
              const SizedBox(height: 24),
              Text('Origen: ${_formatearPunto(_origen)}'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _elegirOrigen,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Elegir origen en el mapa'),
              ),
              const SizedBox(height: 16),
              Text('Destino: ${_formatearPunto(_destino)}'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _elegirDestino,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Elegir destino en el mapa'),
              ),
              if (_errorUbicacion != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _errorUbicacion!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: estado.isLoading ? null : _enviar,
                child: Text(estado.isLoading ? 'Enviando...' : 'Publicar envío'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
