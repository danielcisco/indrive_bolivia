import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/tracking/background_location_service.dart';
import '../../../../core/tracking/battery_optimization.dart';
import '../../../../shared/data/providers.dart';
import '../../../../shared/domain/entities/envio.dart';
import '../../../../shared/widgets/envio_map_preview.dart';
import '../../../../shared/widgets/estado_envio_chip.dart';
import '../../../../shared/widgets/soporte_whatsapp.dart';
import 'confirmar_entrega_screen.dart';

/// Pantalla de una entrega activa: "Confirmar recogida" arranca el
/// Foreground Service de tracking (con el onboarding de batería antes, si
/// hace falta) — la transición sigue siendo asignado→en_curso, sin un
/// EnvioStatus nuevo para "recogido" (Sprint 8.3); "Marcar como entregado"
/// lo detiene.
class EntregaEnCursoScreen extends ConsumerStatefulWidget {
  const EntregaEnCursoScreen({super.key, required this.envioId});

  final String envioId;

  @override
  ConsumerState<EntregaEnCursoScreen> createState() =>
      _EntregaEnCursoScreenState();
}

class _EntregaEnCursoScreenState extends ConsumerState<EntregaEnCursoScreen> {
  bool _procesando = false;

  /// `static` a propósito (no una preferencia persistida): "Ahora no"
  /// deja de insistir mientras la app siga abierta, incluso entre
  /// entregas distintas, pero vuelve a preguntar en el próximo arranque —
  /// mismo criterio de sesión que `AppLockGate`/`BatteryOptimizationPrompt`,
  /// a pedido del usuario.
  static bool _ubicacionDescartadaEnEstaSesion = false;
  static bool _bateriaViajeDescartadaEnEstaSesion = false;

  /// Bug real (Sprint 15): nada en la app pedía nunca el permiso de
  /// ubicación "todo el tiempo" antes de arrancar el tracking — solo se
  /// pedía "mientras se usa la app" (una sola vez, desde Radar/el picker
  /// de origen). Sin ese permiso el stream de posición del Foreground
  /// Service simplemente no emitía nada, sin ningún error visible: el
  /// repartidor confirmaba la recogida con normalidad, pero
  /// `repartidorPosicionActual` nunca se escribía, así que ni el Cliente
  /// ni el Admin veían el ícono en el mapa. Android no ofrece "todo el
  /// tiempo" en el diálogo de permiso normal desde Android 11 — hay que
  /// mandar al usuario a Ajustes a mano.
  Future<bool> _confirmarPermisoUbicacion() async {
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.always) return true;
    if (_ubicacionDescartadaEnEstaSesion) return true;
    if (!mounted) return true;
    final continuar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubicación en segundo plano'),
        content: const Text(
          'Para que el cliente vea dónde estás mientras vas en camino, '
          'la app necesita el permiso de ubicación "Permitir todo el '
          'tiempo" — Android no lo pide directo, hay que activarlo a '
          'mano en Ajustes → Permisos → Ubicación.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              _ubicacionDescartadaEnEstaSesion = true;
              Navigator.of(context).pop(true);
            },
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () async {
              await Geolocator.openAppSettings();
              if (context.mounted) Navigator.of(context).pop(true);
            },
            child: const Text('Abrir Ajustes'),
          ),
        ],
      ),
    );
    return continuar ?? true;
  }

  Future<bool> _confirmarOnboardingBateria() async {
    if (await BatteryOptimization.estaExcluida()) return true;
    if (_bateriaViajeDescartadaEnEstaSesion) return true;
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
            onPressed: () {
              _bateriaViajeDescartadaEnEstaSesion = true;
              Navigator.of(context).pop(true);
            },
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
    setState(() => _procesando = true);
    try {
      await _confirmarPermisoUbicacion();
      await _confirmarOnboardingBateria();
      await ref.read(enviosRepositoryProvider).iniciarViaje(widget.envioId);
      await iniciarTracking(widget.envioId);
    } catch (_) {
      if (mounted) {
        mostrarErrorConSoporte(
          context,
          ref,
          mensaje: 'No pudimos confirmar la recogida. Probá de nuevo.',
          app: 'Repartidor',
          motivo: 'no puedo confirmar la recogida (${widget.envioId})',
        );
      }
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
    // Mismo dato que `envioAsync.when(data: ...)` usa abajo — acá afuera
    // para poder armar el botón anclado del `bottomNavigationBar`, que
    // vive a nivel Scaffold y no dentro del `body`.
    final envio = envioAsync.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Entrega')),
      body: envioAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const SupportErrorView(
          mensaje:
              'No pudimos cargar esta entrega. Revisá tu conexión y '
              'volvé a intentar.',
          app: 'Repartidor',
          motivo: 'no puedo ver una entrega en curso',
        ),
        data: (envio) {
          if (envio == null) {
            return const Center(child: Text('Este envío ya no existe.'));
          }
          return Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    envio.descripcion,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  EstadoEnvioChip(status: envio.status),
                  if (envio.esFragil) ...[
                    const SizedBox(height: 8),
                    Chip(
                      avatar: const Icon(Icons.warning_amber_outlined, size: 18),
                      label: const Text('Frágil — manejar con cuidado'),
                      backgroundColor: Theme.of(context).colorScheme.errorContainer,
                    ),
                  ],
                  const SizedBox(height: 12),
                  EnvioMapPreview(envio: envio),
                ],
              ),
            ),
          );
        },
      ),
      // Anclado abajo (mismo patrón que crear_envio_screen.dart): un solo
      // botón al final de un SingleChildScrollView se pierde de vista
      // apenas la descripción/mapa ocupan algo de alto.
      bottomNavigationBar: switch (envio?.status) {
        EnvioStatus.asignado => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _procesando ? null : _iniciarViaje,
              icon: const Icon(Icons.play_arrow_outlined),
              label: Text(
                _procesando ? 'Confirmando...' : 'Confirmar recogida',
              ),
            ),
          ),
        ),
        EnvioStatus.enCurso => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _irAConfirmarEntrega,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Marcar como entregado'),
            ),
          ),
        ),
        _ => null,
      },
    );
  }
}
