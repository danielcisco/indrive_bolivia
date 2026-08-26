import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/providers.dart';
import '../../../../shared/widgets/mis_calificaciones_screen.dart';
import '../../../../shared/widgets/session_status_view.dart';
import 'mis_envios_screen.dart';

class ClienteHomeScreen extends ConsumerWidget {
  const ClienteHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rating = ref.watch(miRatingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('inDrive Entregas — Cliente')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SessionStatusView(
              appLabel: 'App Cliente — Villazón, Potosí',
            ),
            const SizedBox(height: 16),
            rating.when(
              loading: () => const SizedBox.shrink(),
              error: (error, _) => const SizedBox.shrink(),
              data: (r) => Text(
                r.total == 0
                    ? 'Sin calificaciones todavía'
                    : '⭐ ${r.promedio.toStringAsFixed(1)} · ${r.total} calificaciones',
              ),
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MisCalificacionesScreen(),
                ),
              ),
              icon: const Icon(Icons.star_outline),
              label: const Text('Mis calificaciones'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MisEnviosScreen()),
                ),
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Mis envíos'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
