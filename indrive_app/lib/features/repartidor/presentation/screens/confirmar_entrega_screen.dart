import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/tracking/background_location_service.dart';
import '../../../../shared/data/providers.dart';
import '../../../../shared/domain/entities/envio.dart';
import '../../../../shared/widgets/calificacion_dialog.dart';
import '../providers/mis_entregas_controller.dart';

/// Último paso antes de completar una entrega (Sprint 6.1): el repartidor
/// registra cómo cobró y, si fue QR, adjunta una foto del comprobante — es
/// quien está físicamente presente verificando que el pago ocurrió, por
/// eso esto vive acá y no en el lado del Cliente.
class ConfirmarEntregaScreen extends ConsumerStatefulWidget {
  const ConfirmarEntregaScreen({super.key, required this.envioId});

  final String envioId;

  @override
  ConsumerState<ConfirmarEntregaScreen> createState() =>
      _ConfirmarEntregaScreenState();
}

class _ConfirmarEntregaScreenState
    extends ConsumerState<ConfirmarEntregaScreen> {
  MetodoPago _metodoPago = MetodoPago.efectivo;
  final _codigoController = TextEditingController();
  XFile? _foto;
  bool _procesando = false;
  String? _error;

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _tomarFoto() async {
    // imageQuality + maxWidth: compresión en cliente antes de subir (regla
    // no negociable de CLAUDE.md), sin paquete de compresión aparte.
    final foto = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (foto != null && mounted) setState(() => _foto = foto);
  }

  Future<void> _confirmar() async {
    setState(() {
      _procesando = true;
      _error = null;
    });
    try {
      final repository = ref.read(enviosRepositoryProvider);

      String? comprobanteUrl;
      if (_metodoPago == MetodoPago.qr) {
        comprobanteUrl = await repository.subirComprobante(
          envioId: widget.envioId,
          repartidorId: FirebaseAuth.instance.currentUser!.uid,
          archivo: File(_foto!.path),
        );
      }

      await repository.marcarEntregado(
        widget.envioId,
        metodoPago: _metodoPago,
        codigoIngresado: _codigoController.text.trim(),
        comprobanteUrl: comprobanteUrl,
      );
      detenerTracking();

      if (mounted) {
        final envio = await repository.obtenerEnvio(widget.envioId);
        if (envio != null && mounted) {
          final resultado = await mostrarCalificacionDialog(
            context,
            tituloParaQuien: 'el cliente',
          );
          if (resultado != null) {
            await repository.crearCalificacion(
              envioId: widget.envioId,
              autorId: FirebaseAuth.instance.currentUser!.uid,
              paraId: envio.clienteId,
              estrellas: resultado.estrellas,
              comentario: resultado.comentario,
            );
          }
        }
      }

      // Sin esto, "Mis entregas" seguía mostrando el envío como
      // asignado/en_curso hasta que el repartidor la refrescara a mano.
      ref.invalidate(misEntregasControllerProvider);
      if (mounted) {
        Navigator.of(context)
          ..pop()
          ..pop();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final faltaFoto = _metodoPago == MetodoPago.qr && _foto == null;
    final faltaCodigo = _codigoController.text.trim().length != 4;
    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar entrega')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Código que te dio el cliente'),
            const SizedBox(height: 8),
            TextField(
              controller: _codigoController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Código de 4 dígitos'),
            ),
            const SizedBox(height: 16),
            const Text('¿Cómo te pagó el cliente?'),
            RadioGroup<MetodoPago>(
              groupValue: _metodoPago,
              onChanged: (value) => setState(() => _metodoPago = value!),
              child: Column(
                children: const [
                  RadioListTile<MetodoPago>(
                    title: Text('Efectivo'),
                    value: MetodoPago.efectivo,
                  ),
                  RadioListTile<MetodoPago>(
                    title: Text('QR'),
                    value: MetodoPago.qr,
                  ),
                ],
              ),
            ),
            if (_metodoPago == MetodoPago.qr) ...[
              const SizedBox(height: 8),
              if (_foto != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(_foto!.path), height: 180),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _tomarFoto,
                icon: const Icon(Icons.camera_alt),
                label: Text(
                  _foto == null
                      ? 'Tomar foto del comprobante'
                      : 'Repetir foto',
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_procesando || faltaFoto || faltaCodigo)
                    ? null
                    : _confirmar,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  _procesando ? 'Confirmando...' : 'Confirmar entrega',
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
