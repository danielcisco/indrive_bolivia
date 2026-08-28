import 'package:flutter/material.dart';

import '../../../../shared/widgets/home_drawer_comunes.dart';
import '../../../../shared/widgets/user_profile_header.dart';
import '../screens/mis_envios_screen.dart';

/// Menú hamburguesa del Home de Cliente (sprint extra) — reemplaza los
/// botones sueltos que antes vivían en el body: junta en un solo lugar
/// todo lo que no es la acción principal (crear/ver envíos, que se queda
/// como botón grande en el body).
class ClienteHomeDrawer extends StatelessWidget {
  const ClienteHomeDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: const Align(
                alignment: Alignment.bottomLeft,
                child: UserProfileHeader(mostrarRating: true),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: const Text('Mis envíos'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MisEnviosScreen()),
                );
              },
            ),
            const Divider(),
            ...tilesComunesDeHomeDrawer(
              context,
              role: 'cliente',
              appLabel: 'App Cliente — Villazón, Potosí',
            ),
          ],
        ),
      ),
    );
  }
}
