import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/tracking/background_location_service.dart';
import '../../../../core/tracking/battery_optimization.dart';
import '../../../../shared/data/providers.dart';
import '../../../../shared/domain/entities/envio.dart';
import '../../../../shared/widgets/envio_map_preview.dart';
import 'confirmar_entrega_screen.dart';

/// Pantalla de una entrega activa: "Iniciar viaje" arranca el Foreground
/// Service de tracking (con el onboarding de batería antes, si hace
/// falta); "Marcar como entregado" lo detiene.
class EntregaEnCursoScreen extends ConsumerStatefulWidget {
  const EntregaEnCursoScreen({super.key, required this.envioId});

  final String envioId;

  @override
  ConsumerState<EntregaEnCursoScreen> createState() =>
      _EntregaEnCursoScreenState();
}

class _EntregaEnCursoScreenState extends ConsumerState<EntregaEnCursoScreen> {
  bool _procesando = false;
  String? _error;

  Future<bool> _confirmarOnboardingBateria() async {
    if (await BatteryOptimization.estaExcluida()) return true;
    if (!mounted) return true;
    final continuar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir de optimización de batería'),
        content: const Text(
          'Para que el rastreo no se corte mientras la app está en '
          'segundo plano (sobre todo en Xiaomi/Samsung), excluye la app '
          'de la optimización de batería.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () async {
              await BatteryOptimization.solicitarExclusion();
              if (context.mounted) Navigator.of(context).pop(true);
            },
            child: const Text('Excluir app'),
          ),
        ],
      ),
    );
    return continuar ?? true;
  }

  Future<void> _iniciarViaje() async {
    setState(() {
      _procesando = true;
      _error = null;
    });
    try {
      await _confirmarOnboardingBateria();
      await ref.read(enviosRepositoryProvider).iniciarViaje(widget.envioId);
      await iniciarTracking(widget.envioId);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  /// El registro del método de pago + comprobante (Sprint 6.1) vive en
  /// `ConfirmarEntregaScreen`, no acá — ese paso reemplaza la llamada
  /// directa a `marcarEntregado` que había antes.
  void _irAConfirmarEntrega() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConfirmarEntregaScreen(envioId: widget.envioId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final envioAsync = ref.watch(envioStreamProvider(widget.envioId));

    return Scaffold(
      appBar: AppBar(title: const Text('Entrega')),
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
                Text('Estado: ${envio.status.name}'),
                const SizedBox(height: 12),
                EnvioMapPreview(envio: envio),
                const SizedBox(height: 24),
                if (envio.status == EnvioStatus.asignado)
                  FilledButton(
                    onPressed: _procesando ? null : _iniciarViaje,
                    child: Text(_procesando ? 'Iniciando...' : 'Iniciar viaje'),
                  )
                else if (envio.status == EnvioStatus.enCurso)
                  FilledButton(
                    onPressed: _irAConfirmarEntrega,
                    child: const Text('Marcar como entregado'),
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
