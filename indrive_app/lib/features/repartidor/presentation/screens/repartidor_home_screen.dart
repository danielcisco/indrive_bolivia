import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/providers.dart';
import '../../../../shared/widgets/mis_calificaciones_screen.dart';
import '../../../../shared/widgets/session_status_view.dart';
import 'mis_entregas_screen.dart';
import 'radar_screen.dart';
import 'subir_cedula_screen.dart';

class RepartidorHomeScreen extends ConsumerWidget {
  const RepartidorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estadoKyc = ref.watch(miEstadoKycProvider);
    final rating = ref.watch(miRatingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('inDrive Entregas — Repartidor')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SessionStatusView(
              appLabel: 'App Repartidor — Villazón, Potosí',
            ),
            // Diferido de KYC (seguimiento del Sprint 5.1): aviso solo
            // mientras no está verificado y todavía no subió ninguna
            // foto — una vez subida desaparece, aunque el admin todavía
            // no la haya revisado.
            estadoKyc.when(
              loading: () => const SizedBox.shrink(),
              error: (error, _) => const SizedBox.shrink(),
              data: (estado) {
                if (estado.isVerified || estado.cedulaUrl != null) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SubirCedulaScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.badge_outlined),
                      label: const Text('Subir foto de tu Cédula'),
                    ),
                  ),
                );
              },
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
                  MaterialPageRoute(builder: (_) => const RadarScreen()),
                ),
                icon: const Icon(Icons.radar),
                label: const Text('Radar de ofertas'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MisEntregasScreen()),
                ),
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Mis entregas'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
