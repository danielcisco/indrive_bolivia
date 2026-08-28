import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/providers.dart';
import '../../../../shared/domain/entities/envio.dart';
import '../../../../shared/domain/entities/oferta.dart';
import '../../../../shared/widgets/avatar_circulo.dart';
import '../../../../shared/widgets/calificacion_dialog.dart';
import '../../../../shared/widgets/countdown_timer.dart';
import '../../../../shared/widgets/envio_map_preview.dart';
import '../../../../shared/widgets/soporte_whatsapp.dart';
import '../providers/mis_envios_controller.dart';
import '../providers/ofertas_controller.dart';

class EnvioDetalleScreen extends ConsumerWidget {
  const EnvioDetalleScreen({super.key, required this.envioId});

  final String envioId;

  Future<void> _aceptarOferta(
    BuildContext context,
    WidgetRef ref,
    String ofertaId,
    String repartidorId,
  ) async {
    try {
      await ref
          .read(enviosRepositoryProvider)
          .aceptarOferta(
            envioId: envioId,
            ofertaId: ofertaId,
            repartidorId: repartidorId,
          );
      ref.invalidate(misEnviosControllerProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Propuesta aceptada.')));
      }
    } catch (_) {
      if (context.mounted) {
        mostrarErrorConSoporte(
          context,
          ref,
          mensaje: 'Esa propuesta ya no está disponible — puede que otro '
              'repartidor haya sido asignado justo antes. Probá con otra.',
          app: 'Cliente',
          motivo: 'no puedo aceptar una propuesta de mi envío $envioId',
        );
      }
    }
  }

  Future<void> _rechazarOferta(
    BuildContext context,
    WidgetRef ref,
    String ofertaId,
  ) async {
    try {
      await ref
          .read(enviosRepositoryProvider)
          .rechazarOferta(envioId: envioId, ofertaId: ofertaId);
    } catch (_) {
      if (context.mounted) {
        mostrarErrorConSoporte(
          context,
          ref,
          mensaje: 'No pudimos rechazar la propuesta. Probá de nuevo.',
          app: 'Cliente',
          motivo: 'no puedo rechazar una propuesta de mi envío $envioId',
        );
      }
    }
  }

  Future<void> _cancelarEnvio(BuildContext context, WidgetRef ref) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar este envío?'),
        content: const Text(
          'Los repartidores ya no van a poder aceptarlo ni mandar '
          'contraofertas. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await ref.read(enviosRepositoryProvider).cancelarEnvio(envioId);
      ref.invalidate(misEnviosControllerProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Envío cancelado.')));
      }
    } catch (_) {
      if (context.mounted) {
        mostrarErrorConSoporte(
          context,
          ref,
          mensaje: 'No pudimos cancelar el envío. Probá de nuevo.',
          app: 'Cliente',
          motivo: 'no puedo cancelar mi envío $envioId',
        );
      }
    }
  }

  Future<void> _calificar(
    BuildContext context,
    WidgetRef ref,
    String repartidorId,
  ) async {
    final resultado = await mostrarCalificacionDialog(
      context,
      tituloParaQuien: 'el repartidor',
    );
    if (resultado == null) return;
    await ref
        .read(enviosRepositoryProvider)
        .crearCalificacion(
          envioId: envioId,
          autorId: FirebaseAuth.instance.currentUser!.uid,
          paraId: repartidorId,
          estrellas: resultado.estrellas,
          comentario: resultado.comentario,
        );
    ref.invalidate(miCalificacionProvider(envioId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Stream (no fetch puntual): mientras el envío está en_curso, la
    // posición del repartidor cambia y esta pantalla debe reflejarlo sin
    // que el usuario tenga que refrescar manualmente.
    final envioAsync = ref.watch(envioStreamProvider(envioId));
    final ofertasAsync = ref.watch(ofertasControllerProvider(envioId));

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del envío')),
      body: envioAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const SupportErrorView(
          mensaje: 'No pudimos cargar este envío. Revisá tu conexión y '
              'volvé a intentar.',
          app: 'Cliente',
          motivo: 'no puedo ver el detalle de un envío',
        ),
        data: (envio) {
          if (envio == null) {
            return const Center(child: Text('Este envío ya no existe.'));
          }
          final puedeElegir = envio.status == EnvioStatus.pendienteOfertas;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      envio.descripcion,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('Categoría: ${envio.categoria.etiqueta}'),
                    Text('Estado: ${envio.status.name}'),
                    Text(
                      'Monto inicial: ${envio.montoOfertadoInicial.format()}',
                    ),
                    if (envio.fotoPaqueteUrl != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          envio.fotoPaqueteUrl!,
                          height: 160,
                        ),
                      ),
                    ],
                    if (envio.status == EnvioStatus.pendienteOfertas) ...[
                      const SizedBox(height: 8),
                      CountdownTimer(expiraEn: envio.expiraEn),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _cancelarEnvio(context, ref),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancelar envío'),
                      ),
                    ],
                    if (envio.repartidorAsignadoId != null) ...[
                      const SizedBox(height: 12),
                      _RepartidorAsignadoCard(
                        repartidorId: envio.repartidorAsignadoId!,
                      ),
                    ],
                    if (envio.status == EnvioStatus.asignado ||
                        envio.status == EnvioStatus.enCurso) ...[
                      const SizedBox(height: 12),
                      _CodigoEntregaCard(envioId: envioId),
                    ],
                    const SizedBox(height: 12),
                    EnvioMapPreview(envio: envio),
                    if (envio.status == EnvioStatus.entregado) ...[
                      const SizedBox(height: 12),
                      Text(switch (envio.metodoPago) {
                        null => 'Método de pago no registrado.',
                        MetodoPago.efectivo => 'Pago: efectivo.',
                        MetodoPago.qr when envio.pagoVerificado =>
                          'Pago QR verificado ✓',
                        MetodoPago.qr => 'Pago QR: verificación pendiente.',
                      }),
                      const SizedBox(height: 8),
                      Consumer(
                        builder: (context, ref, _) {
                          final calificacionAsync = ref.watch(
                            miCalificacionProvider(envioId),
                          );
                          final repartidorId = envio.repartidorAsignadoId;
                          if (repartidorId == null) {
                            return const SizedBox.shrink();
                          }
                          return calificacionAsync.when(
                            loading: () => const SizedBox.shrink(),
                            error: (error, _) => const SizedBox.shrink(),
                            data: (calificacion) => calificacion != null
                                ? const Text('Ya calificaste este envío.')
                                : OutlinedButton.icon(
                                    onPressed: () =>
                                        _calificar(context, ref, repartidorId),
                                    icon: const Icon(Icons.star_outline),
                                    label: const Text('Calificar al repartidor'),
                                  ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ofertasAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => const SupportErrorView(
                    mensaje: 'No pudimos cargar las propuestas de este '
                        'envío. Revisá tu conexión y volvé a intentar.',
                    app: 'Cliente',
                    motivo: 'no puedo ver las propuestas de mi envío',
                  ),
                  data: (ofertas) {
                    if (ofertas.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox_outlined, size: 48),
                            SizedBox(height: 8),
                            Text('Todavía no hay propuestas.'),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: ofertas.length,
                      itemBuilder: (context, index) {
                        final oferta = ofertas[index];
                        final esAccionable =
                            puedeElegir &&
                            oferta.status == OfertaStatus.pendiente;
                        return _OfertaTile(
                          oferta: oferta,
                          esAccionable: esAccionable,
                          onAceptar: () => _aceptarOferta(
                            context,
                            ref,
                            oferta.id,
                            oferta.repartidorId,
                          ),
                          onRechazar: () =>
                              _rechazarOferta(context, ref, oferta.id),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Una propuesta recibida, con quién la mandó (Sprint 13 — antes solo
/// mostraba el monto, sin decir de qué repartidor era) y, si todavía se
/// puede elegir, los botones para aceptarla o rechazarla.
class _OfertaTile extends ConsumerWidget {
  const _OfertaTile({
    required this.oferta,
    required this.esAccionable,
    required this.onAceptar,
    required this.onRechazar,
  });

  final Oferta oferta;
  final bool esAccionable;
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfilAsync = ref.watch(perfilPublicoProvider(oferta.repartidorId));
    final nombreRepartidor = perfilAsync.when(
      loading: () => 'Cargando...',
      error: (error, _) => 'Repartidor',
      data: (perfil) =>
          perfil == null ? 'Repartidor' : '${perfil.nombre} (@${perfil.nick})',
    );
    return ListTile(
      title: Text(oferta.monto.format()),
      subtitle: Text('$nombreRepartidor · ${oferta.status.name}'),
      trailing: esAccionable
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: onRechazar,
                  icon: const Icon(Icons.close),
                  tooltip: 'Rechazar',
                ),
                FilledButton(
                  onPressed: onAceptar,
                  child: const Text('Aceptar'),
                ),
              ],
            )
          : null,
    );
  }
}

/// Código de entrega (Sprint 8.2): el cliente se lo dicta al repartidor en
/// mano al recibir el paquete, nunca por otro canal — evita que alguien
/// que interceptó la app del repartidor pueda "confirmar" una entrega que
/// no ocurrió.
class _CodigoEntregaCard extends ConsumerWidget {
  const _CodigoEntregaCard({required this.envioId});

  final String envioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codigoAsync = ref.watch(codigoEntregaProvider(envioId));
    return codigoAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) => const SizedBox.shrink(),
      data: (codigo) {
        if (codigo == null) return const SizedBox.shrink();
        return Card(
          child: ListTile(
            leading: const Icon(Icons.pin_outlined),
            title: const Text('Código de entrega'),
            subtitle: const Text(
              'Dáselo al repartidor solo cuando recibas el paquete.',
            ),
            trailing: Text(
              codigo,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        );
      },
    );
  }
}

/// Identidad del repartidor asignado — perfil público (nombre/nick/avatar,
/// sin datos sensibles) para que el Cliente sepa quién va a hacer la
/// entrega.
class _RepartidorAsignadoCard extends ConsumerWidget {
  const _RepartidorAsignadoCard({required this.repartidorId});

  final String repartidorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfilAsync = ref.watch(perfilPublicoProvider(repartidorId));
    return perfilAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) => const SizedBox.shrink(),
      data: (perfil) {
        if (perfil == null) return const SizedBox.shrink();
        return Card(
          child: ListTile(
            leading: AvatarCirculo(avatarId: perfil.avatarId),
            title: const Text('Tu repartidor'),
            subtitle: Text('${perfil.nombre} ${perfil.apellido} (@${perfil.nick})'),
          ),
        );
      },
    );
  }
}
