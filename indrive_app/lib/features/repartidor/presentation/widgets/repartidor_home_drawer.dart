import 'package:flutter/material.dart';

import '../../../../shared/widgets/home_drawer_comunes.dart';
import '../../../../shared/widgets/user_profile_header.dart';

/// Menú hamburguesa del Home de Repartidor (sprint extra) — junta en un
/// solo lugar lo que no es acción diaria inmediata (Radar/Mis entregas,
/// disponibilidad, KYC pendiente se quedan en el body porque son lo que
/// se mira apenas se abre la app).
class RepartidorHomeDrawer extends StatelessWidget {
  const RepartidorHomeDrawer({super.key});

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
            ...tilesComunesDeHomeDrawer(
              context,
              role: 'repartidor',
              appLabel: 'App Repartidor — Villazón, Potosí',
            ),
          ],
        ),
      ),
    );
  }
}
