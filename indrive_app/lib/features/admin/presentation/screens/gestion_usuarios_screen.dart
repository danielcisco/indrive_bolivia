import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/gestion_usuarios_controller.dart';
import 'usuario_detalle_screen.dart';

class GestionUsuariosScreen extends ConsumerWidget {
  const GestionUsuariosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(gestionUsuariosControllerProvider);

    return estado.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (data) {
        Future<void> refrescar() async {
          ref.invalidate(gestionUsuariosControllerProvider);
          await ref.read(gestionUsuariosControllerProvider.future);
        }

        if (data.usuarios.isEmpty) {
          return RefreshIndicator(
            onRefresh: refrescar,
            child: ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No hay usuarios todavía.')),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: refrescar,
          child: ListView.builder(
            itemCount: data.usuarios.length + (data.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= data.usuarios.length) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: data.isLoadingMore
                        ? const CircularProgressIndicator()
                        : OutlinedButton(
                            onPressed: () => ref
                                .read(gestionUsuariosControllerProvider.notifier)
                                .cargarMas(),
                            child: const Text('Cargar más'),
                          ),
                  ),
                );
              }
              final usuario = data.usuarios[index];
              return ListTile(
                title: Text(usuario.phoneNumber ?? usuario.uid),
                subtitle: Text(
                  '${usuario.role ?? 'sin rol'} · '
                  '${usuario.isActive ? 'Activo' : 'Suspendido'}'
                  '${usuario.isVerified ? ' · Verificado' : ''}',
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UsuarioDetalleScreen(usuario: usuario),
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
