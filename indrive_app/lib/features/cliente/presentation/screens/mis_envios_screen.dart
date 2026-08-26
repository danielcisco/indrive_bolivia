import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/mis_envios_controller.dart';
import 'crear_envio_screen.dart';
import 'envio_detalle_screen.dart';

class MisEnviosScreen extends ConsumerWidget {
  const MisEnviosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(misEnviosControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis envíos')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CrearEnvioScreen())),
        child: const Icon(Icons.add),
      ),
      body: estado.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (data) {
          Future<void> refrescar() async {
            ref.invalidate(misEnviosControllerProvider);
            await ref.read(misEnviosControllerProvider.future);
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
                          Icon(Icons.local_shipping_outlined, size: 48),
                          SizedBox(height: 8),
                          Text('Todavía no tienes envíos.'),
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
                                  .read(misEnviosControllerProvider.notifier)
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
                    '${envio.status.name} · ${envio.montoOfertadoInicial.format()}',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EnvioDetalleScreen(envioId: envio.id),
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
