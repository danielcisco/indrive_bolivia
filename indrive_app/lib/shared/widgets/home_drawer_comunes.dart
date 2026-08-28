import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'estado_verificacion_screen.dart';
import 'mis_calificaciones_screen.dart';
import 'seguridad_screen.dart';
import 'session_status_view.dart';

/// Tiles comunes a los Drawer de Cliente y Repartidor (sprint extra: menú
/// hamburguesa que junta todas las opciones en un solo lugar, incluida
/// seguridad). El Drawer en sí vive en cada feature (no acá, en
/// `shared/`) porque además necesita empujar pantallas propias del rol
/// (`MisEnviosScreen`/`MisEntregasScreen`+`RadarScreen`) — pero estos 5
/// accesos son idénticos en ambos roles, así que se arman una sola vez
/// acá y cada Drawer los intercala con sus propios ítems.
List<Widget> tilesComunesDeHomeDrawer(
  BuildContext context, {
  required String role,
  required String appLabel,
}) {
  void cerrarDrawerYAbrir(WidgetBuilder builder) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: builder));
  }

  return [
    ListTile(
      leading: const Icon(Icons.star_outline),
      title: const Text('Mis calificaciones'),
      onTap: () => cerrarDrawerYAbrir((_) => const MisCalificacionesScreen()),
    ),
    ListTile(
      leading: const Icon(Icons.verified_outlined),
      title: const Text('Mi verificación'),
      onTap: () =>
          cerrarDrawerYAbrir((_) => EstadoVerificacionScreen(role: role)),
    ),
    ListTile(
      leading: Icon(
        Icons.shield_outlined,
        color: Theme.of(context).colorScheme.error,
      ),
      title: const Text('Seguridad'),
      subtitle: const Text('Contacto de confianza y emergencias'),
      onTap: () => cerrarDrawerYAbrir((_) => const SeguridadScreen()),
    ),
    const Divider(),
    ListTile(
      leading: const Icon(Icons.account_circle_outlined),
      title: const Text('Cuenta'),
      onTap: () {
        Navigator.of(context).pop();
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            content: SessionStatusView(appLabel: appLabel),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      },
    ),
    ListTile(
      leading: const Icon(Icons.logout),
      title: const Text('Cerrar sesión'),
      onTap: () {
        Navigator.of(context).pop();
        FirebaseAuth.instance.signOut();
      },
    ),
  ];
}
