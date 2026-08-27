import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/providers.dart';
import '../../../../shared/domain/entities/envio.dart';
import '../../../../shared/domain/value_objects/money.dart';
import '../../../../shared/widgets/avatar_circulo.dart';
import '../../../../shared/widgets/countdown_timer.dart';
import '../../../../shared/widgets/envio_map_preview.dart';
import '../../../../shared/widgets/soporte_whatsapp.dart';
import '../providers/mis_entregas_controller.dart';
import 'entrega_en_curso_screen.dart';

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

  Future<void> _confirmarYAceptarDirecto() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Aceptar este envío?'),
        content: const Text(
          'Te vas a comprometer a hacer esta entrega. No se puede '
          'deshacer una vez confirmado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, aceptar'),
          ),
        ],
      ),
    );
    if (confirmar == true) await _aceptarDirecto();
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
      // "Mis entregas" no se refresca sola con esto (no es la pantalla que
      // se muestra a continuación) — sin invalidar, seguiría mostrando la
      // lista de antes de aceptar si el repartidor vuelve ahí después.
      ref.invalidate(misEntregasControllerProvider);
      if (mounted) {
        // Antes volvía a la lista general ("Mis entregas"); ahora va
        // directo a la entrega recién aceptada — se salta Radar y este
        // detalle (popUntil el Home) para no dejarlos apilados debajo.
        Navigator.of(context).popUntil((route) => route.isFirst);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EntregaEnCursoScreen(envioId: widget.envioId),
          ),
        );
      }
    } on StateError {
      // El repository lanza esto cuando la transacción atómica detecta que
      // otro repartidor ya lo tomó — no es una falla real, es una carrera
      // perdida, así que el mensaje es accionable, no un error genérico.
      if (mounted) {
        setState(
          () => _error = 'Este envío ya fue tomado por otro repartidor.',
        );
      }
    } catch (_) {
      if (mounted) {
        mostrarErrorConSoporte(
          context,
          ref,
          mensaje: 'No pudimos aceptar el envío. Probá de nuevo.',
          app: 'Repartidor',
          motivo: 'no puedo aceptar un envío directo (${widget.envioId})',
        );
      }
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
    } catch (_) {
      if (mounted) {
        mostrarErrorConSoporte(
          context,
          ref,
          mensaje: 'No pudimos enviar tu contraoferta. Probá de nuevo.',
          app: 'Repartidor',
          motivo: 'no puedo enviar una contraoferta (${widget.envioId})',
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Stream, no fetch puntual (antes usaba envioProvider) — mismo motivo
    // que el detalle del Cliente: si otro repartidor lo acepta primero o
    // el envío expira mientras esta pantalla está abierta, se refleja
    // solo en vez de que el repartidor intente aceptar algo que ya no
    // está disponible.
    final envioAsync = ref.watch(envioStreamProvider(widget.envioId));

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del envío')),
      body: envioAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const SupportErrorView(
          mensaje: 'No pudimos cargar este envío. Revisá tu conexión y '
              'volvé a intentar.',
          app: 'Repartidor',
          motivo: 'no puedo ver el detalle de un envío',
        ),
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
                Text('Categoría: ${envio.categoria.etiqueta}'),
                const SizedBox(height: 8),
                Text(
                  'Oferta inicial: ${envio.montoOfertadoInicial.format()}',
                ),
                if (envio.fotoPaqueteUrl != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(envio.fotoPaqueteUrl!, height: 160),
                  ),
                ],
                const SizedBox(height: 8),
                CountdownTimer(expiraEn: envio.expiraEn),
                const SizedBox(height: 12),
                _ClienteCard(clienteId: envio.clienteId),
                const SizedBox(height: 12),
                EnvioMapPreview(envio: envio),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _procesando ? null : _confirmarYAceptarDirecto,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Aceptar directo'),
                  ),
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
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _procesando
                        ? null
                        : () => _enviarContraoferta(envio),
                    icon: const Icon(Icons.reply_outlined),
                    label: const Text('Enviar contraoferta'),
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
          );
        },
      ),
    );
  }
}

/// Identidad del cliente — perfil público (nombre/nick/avatar, sin datos
/// sensibles) para que el Repartidor sepa a quién le va a entregar.
class _ClienteCard extends ConsumerWidget {
  const _ClienteCard({required this.clienteId});

  final String clienteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfilAsync = ref.watch(perfilPublicoProvider(clienteId));
    return perfilAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) => const SizedBox.shrink(),
      data: (perfil) {
        if (perfil == null) return const SizedBox.shrink();
        return Card(
          child: ListTile(
            leading: AvatarCirculo(avatarId: perfil.avatarId),
            title: const Text('Cliente'),
            subtitle: Text('${perfil.nombre} ${perfil.apellido} (@${perfil.nick})'),
          ),
        );
      },
    );
  }
}
