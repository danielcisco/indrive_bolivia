import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/mis_entregas_controller.dart';
import 'entrega_en_curso_screen.dart';

class MisEntregasScreen extends ConsumerWidget {
  const MisEntregasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(misEntregasControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis entregas')),
      body: estado.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (data) {
          Future<void> refrescar() =>
              ref.read(misEntregasControllerProvider.notifier).refrescar();

          if (data.entregas.isEmpty) {
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
                          Text('No tienes entregas activas por ahora.'),
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
              itemCount: data.entregas.length + (data.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= data.entregas.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: data.isLoadingMore
                          ? const CircularProgressIndicator()
                          : OutlinedButton(
                              onPressed: () => ref
                                  .read(misEntregasControllerProvider.notifier)
                                  .cargarMas(),
                              child: const Text('Cargar más'),
                            ),
                    ),
                  );
                }
                final envio = data.entregas[index];
                return ListTile(
                  title: Text(envio.descripcion),
                  subtitle: Text(envio.status.name),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EntregaEnCursoScreen(envioId: envio.id),
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
