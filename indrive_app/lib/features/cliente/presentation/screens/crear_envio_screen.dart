import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/location/current_location.dart';
import '../../../../shared/domain/value_objects/money.dart';
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
  final _destinoLatController = TextEditingController();
  final _destinoLngController = TextEditingController();

  GeoPoint? _origen;
  bool _obteniendoUbicacion = false;
  String? _errorUbicacion;

  @override
  void dispose() {
    _descripcionController.dispose();
    _montoController.dispose();
    _destinoLatController.dispose();
    _destinoLngController.dispose();
    super.dispose();
  }

  Future<void> _usarUbicacionActual() async {
    setState(() {
      _obteniendoUbicacion = true;
      _errorUbicacion = null;
    });
    try {
      final posicion = await obtenerUbicacionActual();
      if (!mounted) return;
      setState(() {
        _origen = GeoPoint(posicion.latitude, posicion.longitude);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorUbicacion = error.toString());
    } finally {
      if (mounted) setState(() => _obteniendoUbicacion = false);
    }
  }

  Future<void> _enviar() async {
    final origen = _origen;
    if (!_formKey.currentState!.validate()) return;
    if (origen == null) {
      setState(() => _errorUbicacion = 'Primero obtén tu ubicación de origen.');
      return;
    }

    final destino = GeoPoint(
      double.parse(_destinoLatController.text),
      double.parse(_destinoLngController.text),
    );
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
              Text(
                _origen == null
                    ? 'Origen: sin definir'
                    : 'Origen: ${_origen!.latitude.toStringAsFixed(5)}, '
                          '${_origen!.longitude.toStringAsFixed(5)}',
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _obteniendoUbicacion ? null : _usarUbicacionActual,
                child: Text(
                  _obteniendoUbicacion ? 'Obteniendo...' : 'Usar mi ubicación actual',
                ),
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
              const Text(
                'Destino (temporal: coordenadas manuales — el selector '
                'de mapa llega en Fase 4)',
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _destinoLatController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(labelText: 'Latitud destino'),
                validator: (value) =>
                    double.tryParse(value ?? '') == null ? 'Inválido' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _destinoLngController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Longitud destino',
                ),
                validator: (value) =>
                    double.tryParse(value ?? '') == null ? 'Inválido' : null,
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
