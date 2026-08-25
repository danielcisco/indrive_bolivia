import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/radar_controller.dart';
import 'envio_repartidor_detalle_screen.dart';

class RadarScreen extends ConsumerWidget {
  const RadarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(radarControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Radar de ofertas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(radarControllerProvider.notifier).refrescar(),
          ),
        ],
      ),
      body: estado.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (data) {
          Future<void> refrescar() =>
              ref.read(radarControllerProvider.notifier).refrescar();

          if (data.envios.isEmpty) {
            return RefreshIndicator(
              onRefresh: refrescar,
              child: ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text('No hay envíos cerca por ahora.'),
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
                                  .read(radarControllerProvider.notifier)
                                  .cargarMas(),
                              child: const Text('Cargar más'),
                            ),
                    ),
                  );
                }
                final envio = data.envios[index];
                return ListTile(
                  title: Text(envio.descripcion),
                  subtitle: Text(
                    'Oferta inicial: ${envio.montoOfertadoInicial.format()}',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          EnvioRepartidorDetalleScreen(envioId: envio.id),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
