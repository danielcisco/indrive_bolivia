import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../domain/avatares.dart';
import 'avatar_circulo.dart';
import 'mis_calificaciones_screen.dart';

/// Header compartido por las 3 Home: avatar elegible (tocar abre un grid
/// de íconos predefinidos, sin subir fotos), nombre/nick del usuario
/// logueado (o su teléfono/email si todavía no los completó — caso de
/// Admin, que no pasa por el gate de perfil completo de `AuthGate`) y, si
/// [mostrarRating]
/// es true, su clasificación (⭐ promedio) al lado, que navega a
/// `MisCalificacionesScreen` al tocarla. Admin no recibe calificaciones,
/// así que su instancia pasa `mostrarRating: false` — y por eso también
/// es la señal que usa este widget para saber si tiene sentido ofrecer
/// editar nombre/nick (Admin nunca los completa).
class UserProfileHeader extends ConsumerWidget {
  const UserProfileHeader({super.key, required this.mostrarRating});

  final bool mostrarRating;

  Future<void> _elegirAvatar(BuildContext context, WidgetRef ref) async {
    final avatarId = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => GridView.count(
        crossAxisCount: 4,
        padding: const EdgeInsets.all(16),
        children: [
          for (final avatar in kAvatares)
            InkWell(
              onTap: () => Navigator.of(context).pop(avatar.id),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundColor: avatar.color,
                  child: Icon(avatar.icono, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
    if (avatarId == null) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await ref.read(usersRepositoryProvider).actualizarAvatar(uid, avatarId);
    ref.invalidate(miPerfilProvider);
  }

  Future<void> _editarPerfil(
    BuildContext context,
    WidgetRef ref, {
    required String nombreActual,
    required String apellidoActual,
    required String nickActual,
  }) async {
    final nombreController = TextEditingController(text: nombreActual);
    final apellidoController = TextEditingController(text: apellidoActual);
    final nickController = TextEditingController(text: nickActual);
    final guardar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar perfil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreController,
              decoration: const InputDecoration(labelText: 'Nombre'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: apellidoController,
              decoration: const InputDecoration(labelText: 'Apellido'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nickController,
              decoration: const InputDecoration(labelText: 'Nick'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (guardar != true) return;
    final nombre = nombreController.text.trim();
    final apellido = apellidoController.text.trim();
    final nick = nickController.text.trim();
    if (nombre.isEmpty || apellido.isEmpty || nick.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await ref
        .read(usersRepositoryProvider)
        .actualizarPerfil(uid, nombre: nombre, apellido: apellido, nick: nick);
    ref.invalidate(miPerfilProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final fallback = user?.phoneNumber ?? user?.email ?? 'Usuario';
    final perfil = ref.watch(miPerfilProvider).value;
    final identificador = (perfil != null && perfil.nombre.isNotEmpty)
        ? '${perfil.nombre} ${perfil.apellido} (@${perfil.nick})'
        : fallback;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Stack(
            children: [
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _elegirAvatar(context, ref),
                child: AvatarCirculo(avatarId: perfil?.avatarId),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, size: 12),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: (mostrarRating && perfil != null)
                  ? () => _editarPerfil(
                      context,
                      ref,
                      nombreActual: perfil.nombre,
                      apellidoActual: perfil.apellido,
                      nickActual: perfil.nick,
                    )
                  : null,
              child: Text(identificador, overflow: TextOverflow.ellipsis),
            ),
          ),
          if (mostrarRating)
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MisCalificacionesScreen(),
                ),
              ),
              child: ref
                  .watch(miRatingProvider)
                  .when(
                    loading: () => const SizedBox.shrink(),
                    error: (error, _) => const SizedBox.shrink(),
                    data: (r) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        r.total == 0
                            ? 'Sin calificaciones'
                            : '⭐ ${r.promedio.toStringAsFixed(1)}',
                      ),
                    ),
                  ),
            ),
        ],
      ),
    );
  }
}
