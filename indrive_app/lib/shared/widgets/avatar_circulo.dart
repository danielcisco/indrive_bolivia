import 'package:flutter/material.dart';

import '../domain/avatares.dart';

/// Círculo de avatar a partir de un [avatarId] (uno de `kAvatares`) —
/// extraído de `UserProfileHeader` para reusarlo también al mostrar la
/// identidad de la contraparte en el detalle de un envío.
class AvatarCirculo extends StatelessWidget {
  const AvatarCirculo({super.key, required this.avatarId});

  final String? avatarId;

  @override
  Widget build(BuildContext context) {
    final avatar = avatarPorId(avatarId);
    return CircleAvatar(
      backgroundColor: avatar.color,
      child: Icon(avatar.icono, color: Colors.white),
    );
  }
}
