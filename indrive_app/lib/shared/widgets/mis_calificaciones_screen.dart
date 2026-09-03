import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../domain/entities/calificacion.dart';
import '../providers/mis_calificaciones_controller.dart';
import 'avatar_circulo.dart';
import 'soporte_whatsapp.dart';

/// Calificaciones que recibió el usuario autenticado (sprint extra, Grupo
/// B) — compartida por Cliente y Repartidor, mismo criterio que
/// `MapPickerScreen`: una pantalla completa puede vivir en `shared/widgets/`
/// cuando no tiene nada específico de un rol.
///
/// Cada fila muestra quién calificó (sprint de rediseño) — antes solo se
/// veían estrellas + comentario + fecha, sin decir de quién era la
/// calificación.
class MisCalificacionesScreen extends ConsumerWidget {
  const MisCalificacionesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(misCalificacionesControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis calificaciones')),
      body: estado.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const SupportErrorView(
          mensaje: 'No pudimos cargar tus calificaciones. Revisá tu '
              'conexión y volvé a intentar.',
          app: 'Cliente/Repartidor',
          motivo: 'no puedo ver mis calificaciones',
        ),
        data: (calificaciones) {
          if (calificaciones.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_outline, size: 48),
                  SizedBox(height: 8),
                  Text('Todavía no recibiste ninguna calificación.'),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: calificaciones.length,
            itemBuilder: (context, index) =>
                _CalificacionCard(calificacion: calificaciones[index]),
          );
        },
      ),
    );
  }
}

class _CalificacionCard extends ConsumerWidget {
  const _CalificacionCard({required this.calificacion});

  final Calificacion calificacion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfilAsync = ref.watch(perfilPublicoProvider(calificacion.autorId));
    final nombre = perfilAsync.when(
      loading: () => 'Cargando...',
      error: (error, _) => 'Usuario',
      data: (perfil) => perfil == null ? 'Usuario' : perfil.nombre,
    );
    final avatarId = perfilAsync.value?.avatarId;
    final fecha = calificacion.createdAt;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarCirculo(avatarId: avatarId),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nombre,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < calificacion.estrellas
                              ? Icons.star
                              : Icons.star_border,
                          color: Theme.of(context).colorScheme.secondary,
                          size: 16,
                        ),
                      ),
                    ),
                    if (fecha != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${fecha.toDate().day}/${fecha.toDate().month}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (calificacion.comentario != null) ...[
              const SizedBox(height: 10),
              Text(
                '"${calificacion.comentario}"',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
