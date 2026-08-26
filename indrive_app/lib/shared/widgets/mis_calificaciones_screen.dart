import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/mis_calificaciones_controller.dart';

/// Calificaciones que recibió el usuario autenticado (sprint extra, Grupo
/// B) — compartida por Cliente y Repartidor, mismo criterio que
/// `MapPickerScreen`: una pantalla completa puede vivir en `shared/widgets/`
/// cuando no tiene nada específico de un rol.
class MisCalificacionesScreen extends ConsumerWidget {
  const MisCalificacionesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(misCalificacionesControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis calificaciones')),
      body: estado.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (data) {
          if (data.calificaciones.isEmpty) {
            return const Center(
              child: Text('Todavía no recibiste ninguna calificación.'),
            );
          }
          return ListView.builder(
            itemCount: data.calificaciones.length + (data.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= data.calificaciones.length) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: data.isLoadingMore
                        ? const CircularProgressIndicator()
                        : OutlinedButton(
                            onPressed: () => ref
                                .read(
                                  misCalificacionesControllerProvider.notifier,
                                )
                                .cargarMas(),
                            child: const Text('Cargar más'),
                          ),
                  ),
                );
              }
              final calificacion = data.calificaciones[index];
              return ListTile(
                title: Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < calificacion.estrellas
                          ? Icons.star
                          : Icons.star_border,
                      color: Colors.amber,
                      size: 18,
                    ),
                  ),
                ),
                subtitle: calificacion.comentario != null
                    ? Text(calificacion.comentario!)
                    : null,
                trailing: calificacion.createdAt != null
                    ? Text(
                        '${calificacion.createdAt!.toDate().day}/'
                        '${calificacion.createdAt!.toDate().month}',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
