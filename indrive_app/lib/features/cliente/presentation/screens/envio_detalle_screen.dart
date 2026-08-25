import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/providers.dart';
import '../../../../shared/domain/entities/envio.dart';
import '../../../../shared/domain/entities/oferta.dart';
import '../../../../shared/widgets/calificacion_dialog.dart';
import '../../../../shared/widgets/envio_map_preview.dart';
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
      ref.invalidate(ofertasControllerProvider(envioId));
      ref.invalidate(misEnviosControllerProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Propuesta aceptada.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo aceptar: $error')));
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
        error: (error, _) => Center(child: Text('Error: $error')),
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
                    Text('Estado: ${envio.status.name}'),
                    Text(
                      'Monto inicial: ${envio.montoOfertadoInicial.format()}',
                    ),
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
                                : OutlinedButton(
                                    onPressed: () =>
                                        _calificar(context, ref, repartidorId),
                                    child: const Text('Calificar al repartidor'),
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
                  error: (error, _) => Center(child: Text('Error: $error')),
                  data: (data) {
                    if (data.ofertas.isEmpty) {
                      return const Center(
                        child: Text('Todavía no hay propuestas.'),
                      );
                    }
                    return ListView.builder(
                      itemCount: data.ofertas.length + (data.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= data.ofertas.length) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: data.isLoadingMore
                                  ? const CircularProgressIndicator()
                                  : OutlinedButton(
                                      onPressed: () => ref
                                          .read(
                                            ofertasControllerProvider(
                                              envioId,
                                            ).notifier,
                                          )
                                          .cargarMas(),
                                      child: const Text('Cargar más'),
                                    ),
                            ),
                          );
                        }
                        final oferta = data.ofertas[index];
                        final esAceptable =
                            puedeElegir &&
                            oferta.status == OfertaStatus.pendiente;
                        return ListTile(
                          title: Text(oferta.monto.format()),
                          subtitle: Text('Estado: ${oferta.status.name}'),
                          trailing: esAceptable
                              ? FilledButton(
                                  onPressed: () => _aceptarOferta(
                                    context,
                                    ref,
                                    oferta.id,
                                    oferta.repartidorId,
                                  ),
                                  child: const Text('Aceptar'),
                                )
                              : null,
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
