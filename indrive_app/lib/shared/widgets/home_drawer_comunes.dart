import 'package:flutter/material.dart';

import '../../core/auth/cerrar_sesion.dart';
import 'estado_verificacion_screen.dart';
import 'mis_calificaciones_screen.dart';
import 'seguridad_screen.dart';
import 'selector_tema.dart';
import 'session_status_view.dart';

/// Tiles comunes a los Drawer de Cliente y Repartidor (sprint extra: menú
/// hamburguesa que junta todas las opciones en un solo lugar, incluida
/// seguridad). El Drawer en sí vive en cada feature (no acá, en
/// `shared/`) porque además necesita empujar pantallas propias del rol
/// (`MisEnviosScreen`/`MisEntregasScreen`+`RadarScreen`) — pero estos 5
/// accesos son idénticos en ambos roles, así que se arman una sola vez
/// acá y cada Drawer los intercala con sus propios ítems.
///
/// Cada ítem va envuelto en su propia `Card` (sprint de rediseño) — antes
/// era una lista corrida sin separación visual entre opciones, que se
/// sentía como un bloque de texto más que como un menú.
List<Widget> tilesComunesDeHomeDrawer(
  BuildContext context, {
  required String role,
  required String appLabel,
}) {
  void cerrarDrawerYAbrir(WidgetBuilder builder) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: builder));
  }

  Widget tarjeta(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Card(child: child),
  );

  return [
    tarjeta(
      ListTile(
        leading: const Icon(Icons.star_outline),
        title: const Text('Mis calificaciones'),
        onTap: () =>
            cerrarDrawerYAbrir((_) => const MisCalificacionesScreen()),
      ),
    ),
    tarjeta(
      ListTile(
        leading: const Icon(Icons.verified_outlined),
        title: const Text('Mi verificación'),
        onTap: () =>
            cerrarDrawerYAbrir((_) => EstadoVerificacionScreen(role: role)),
      ),
    ),
    tarjeta(
      ListTile(
        leading: Icon(
          Icons.shield_outlined,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('Seguridad'),
        subtitle: const Text('Contacto de confianza y emergencias'),
        onTap: () => cerrarDrawerYAbrir((_) => const SeguridadScreen()),
      ),
    ),
    tarjeta(
      ListTile(
        leading: const Icon(Icons.brightness_6_outlined),
        title: const Text('Tema'),
        onTap: () {
          Navigator.of(context).pop();
          mostrarSelectorTema(context);
        },
      ),
    ),
    const SizedBox(height: 12),
    tarjeta(
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
    ),
    tarjeta(
      ListTile(
        leading: Icon(
          Icons.logout,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(
          'Cerrar sesión',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        onTap: () {
          Navigator.of(context).pop();
          cerrarSesionYBorrarBloqueo();
        },
      ),
    ),
  ];
}
