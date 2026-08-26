import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/kyc_pending_controller.dart';

class KycPendingScreen extends ConsumerWidget {
  const KycPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(kycPendingControllerProvider);

    ref.listen(kycPendingControllerProvider, (previous, next) {
      final error = next.error;
      if (error != null && previous?.error != error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo aprobar: $error')),
        );
      }
    });

    return estado.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (data) {
        Future<void> refrescar() async {
          ref.invalidate(kycPendingControllerProvider);
          await ref.read(kycPendingControllerProvider.future);
        }

        if (data.repartidores.isEmpty) {
          return RefreshIndicator(
            onRefresh: refrescar,
            child: ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('No hay repartidores con KYC pendiente.'),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: refrescar,
          child: ListView.builder(
            itemCount: data.repartidores.length + (data.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= data.repartidores.length) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: data.isLoadingMore
                        ? const CircularProgressIndicator()
                        : OutlinedButton(
                            onPressed: () => ref
                                .read(kycPendingControllerProvider.notifier)
                                .cargarMas(),
                            child: const Text('Cargar más'),
                          ),
                  ),
                );
              }
              final repartidor = data.repartidores[index];
              final aprobando = data.aprobando.contains(repartidor.uid);
              final cedulaUrl = repartidor.cedulaUrl;
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
                      Text(repartidor.phoneNumber ?? repartidor.uid),
                      Text(
                        repartidor.createdAt != null
                            ? 'Registrado: ${repartidor.createdAt!.toDate()}'
                            : 'Fecha de registro no disponible',
                      ),
                      const SizedBox(height: 8),
                      if (cedulaUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            cedulaUrl,
                            height: 220,
                            fit: BoxFit.contain,
                          ),
                        )
                      else
                        const Text('Todavía no subió la foto de su Cédula.'),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: aprobando
                              ? null
                              : () => ref
                                  .read(kycPendingControllerProvider.notifier)
                                  .aprobar(repartidor.uid),
                          child: aprobando
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Aprobar'),
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
