import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/soporte_whatsapp.dart';
import '../providers/pagos_pendientes_controller.dart';

class PagosPendientesScreen extends ConsumerWidget {
  const PagosPendientesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(pagosPendientesControllerProvider);

    ref.listen(pagosPendientesControllerProvider, (previous, next) {
      final error = next.error;
      if (error != null && previous?.error != error) {
        mostrarErrorConSoporte(
          context,
          ref,
          mensaje: 'No pudimos verificar el pago. Probá de nuevo.',
          app: 'Admin',
          motivo: 'no puedo verificar un pago QR',
        );
      }
    });

    return estado.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => const SupportErrorView(
        mensaje: 'No pudimos cargar los pagos pendientes. Revisá tu '
            'conexión y volvé a intentar.',
        app: 'Admin',
        motivo: 'no puedo ver la lista de pagos QR pendientes',
      ),
      data: (data) {
        Future<void> refrescar() async {
          ref.invalidate(pagosPendientesControllerProvider);
          await ref.read(pagosPendientesControllerProvider.future);
        }

        if (data.envios.isEmpty) {
          return RefreshIndicator(
            onRefresh: refrescar,
            child: ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_outlined, size: 48),
                        SizedBox(height: 8),
                        Text('No hay pagos QR pendientes de verificar.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: refrescar,
          child: ListView.builder(
            itemCount: data.envios.length + (data.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= data.envios.length) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: data.isLoadingMore
                        ? const CircularProgressIndicator()
                        : OutlinedButton(
                            onPressed: () => ref
                                .read(pagosPendientesControllerProvider.notifier)
                                .cargarMas(),
                            child: const Text('Cargar más'),
                          ),
                  ),
                );
              }
              final envio = data.envios[index];
              final verificando = data.verificando.contains(envio.id);
              final comprobanteUrl = envio.comprobanteUrl;
              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        envio.descripcion,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(envio.montoOfertadoInicial.format()),
                      const SizedBox(height: 8),
                      if (comprobanteUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            comprobanteUrl,
                            height: 220,
                            fit: BoxFit.contain,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: verificando
                              ? null
                              : () => ref
                                  .read(
                                    pagosPendientesControllerProvider.notifier,
                                  )
                                  .verificar(envio.id),
                          icon: verificando
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.verified_outlined),
                          label: Text(
                            verificando
                                ? 'Verificando...'
                                : 'Marcar como verificado',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
