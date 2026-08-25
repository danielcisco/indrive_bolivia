import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/providers.dart';
import '../../../../shared/domain/entities/envio.dart';
import '../../../../shared/domain/value_objects/money.dart';
import '../../../../shared/widgets/envio_map_preview.dart';

/// Detalle de un envío desde el punto de vista del Repartidor: dos
/// acciones que ya existían en `EnviosRepository` desde Sprint 2.1 sin
/// ninguna pantalla que las usara.
class EnvioRepartidorDetalleScreen extends ConsumerStatefulWidget {
  const EnvioRepartidorDetalleScreen({super.key, required this.envioId});

  final String envioId;

  @override
  ConsumerState<EnvioRepartidorDetalleScreen> createState() =>
      _EnvioRepartidorDetalleScreenState();
}

class _EnvioRepartidorDetalleScreenState
    extends ConsumerState<EnvioRepartidorDetalleScreen> {
  final _montoController = TextEditingController();
  bool _procesando = false;
  String? _error;

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _aceptarDirecto() async {
    setState(() {
      _procesando = true;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await ref
          .read(enviosRepositoryProvider)
          .aceptarEnvioDirecto(envioId: widget.envioId, repartidorId: uid);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _enviarContraoferta(Envio envio) async {
    setState(() {
      _procesando = true;
      _error = null;
    });
    try {
      final monto = Money.parseBobString(_montoController.text);
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await ref
          .read(enviosRepositoryProvider)
          .enviarOferta(envio: envio, repartidorId: uid, monto: monto);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Contraoferta enviada.')));
        Navigator.of(context).pop();
      }
    } on FormatException {
      setState(() => _error = 'Monto inválido.');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final envioAsync = ref.watch(envioProvider(widget.envioId));

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del envío')),
      body: envioAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (envio) {
          if (envio == null) {
            return const Center(child: Text('Este envío ya no existe.'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  envio.descripcion,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Oferta inicial: ${envio.montoOfertadoInicial.format()}',
                ),
                const SizedBox(height: 12),
                EnvioMapPreview(envio: envio),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _procesando ? null : _aceptarDirecto,
                  child: const Text('Aceptar directo'),
                ),
                const SizedBox(height: 24),
                const Text('O envía una contraoferta:'),
                const SizedBox(height: 8),
                TextField(
                  controller: _montoController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Tu monto (Bs.)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _procesando
                      ? null
                      : () => _enviarContraoferta(envio),
                  child: const Text('Enviar contraoferta'),
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
          );
        },
      ),
    );
  }
}
