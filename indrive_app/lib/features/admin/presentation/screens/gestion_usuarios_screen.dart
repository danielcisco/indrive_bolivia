import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/soporte_whatsapp.dart';
import '../providers/gestion_usuarios_controller.dart';
import 'usuario_detalle_screen.dart';

/// Cliente/Repartidor × Verificado/No verificado en 4 secciones separadas
/// (Sprint 11) — antes era una sola lista ordenada por fecha con todo
/// mezclado, que obligaba a leer el subtítulo de cada fila para saber a
/// qué grupo pertenecía.
class GestionUsuariosScreen extends ConsumerWidget {
  const GestionUsuariosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(gestionUsuariosControllerProvider);

    return estado.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => const SupportErrorView(
        mensaje: 'No pudimos cargar la lista de usuarios. Revisá tu '
            'conexión y volvé a intentar.',
        app: 'Admin',
        motivo: 'no puedo ver la lista de usuarios',
      ),
      data: (data) {
        final notifier = ref.read(gestionUsuariosControllerProvider.notifier);

        Future<void> refrescar() async {
          ref.invalidate(gestionUsuariosControllerProvider);
          await ref.read(gestionUsuariosControllerProvider.future);
        }

        return RefreshIndicator(
          onRefresh: refrescar,
          child: ListView(
            children: [
              ..._seccion(
                context,
                titulo: 'Clientes · No verificados',
                grupo: data.clientesNoVerificados,
                onCargarMas: notifier.cargarMasClientesNoVerificados,
              ),
              ..._seccion(
                context,
                titulo: 'Clientes · Verificados',
                grupo: data.clientesVerificados,
                onCargarMas: notifier.cargarMasClientesVerificados,
              ),
              ..._seccion(
                context,
                titulo: 'Repartidores · No verificados',
                grupo: data.repartidoresNoVerificados,
                onCargarMas: notifier.cargarMasRepartidoresNoVerificados,
              ),
              ..._seccion(
                context,
                titulo: 'Repartidores · Verificados',
                grupo: data.repartidoresVerificados,
                onCargarMas: notifier.cargarMasRepartidoresVerificados,
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _seccion(
    BuildContext context, {
    required String titulo,
    required GrupoUsuarios grupo,
    required VoidCallback onCargarMas,
  }) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          '$titulo (${grupo.usuarios.length}${grupo.hasMore ? '+' : ''})',
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
      if (grupo.usuarios.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Ninguna cuenta en este grupo.'),
        )
      else
        for (final usuario in grupo.usuarios)
          ListTile(
            title: Text(usuario.phoneNumber ?? usuario.uid),
            subtitle: Text(usuario.isActive ? 'Activo' : 'Suspendido'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => UsuarioDetalleScreen(usuario: usuario),
              ),
            ),
          ),
      if (grupo.hasMore)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: grupo.isLoadingMore
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: onCargarMas,
                    child: const Text('Cargar más'),
                  ),
          ),
        ),
      const Divider(height: 24),
    ];
  }
}
