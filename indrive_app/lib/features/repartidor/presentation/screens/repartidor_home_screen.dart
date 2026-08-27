import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/providers.dart';
import '../../../../shared/widgets/mis_calificaciones_screen.dart';
import '../../../../shared/widgets/session_status_view.dart';
import '../../../../shared/widgets/user_profile_header.dart';
import 'mis_entregas_screen.dart';
import 'radar_screen.dart';
import 'subir_cedula_screen.dart';

class RepartidorHomeScreen extends ConsumerWidget {
  const RepartidorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estadoKyc = ref.watch(miEstadoKycProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('inDrive Entregas — Repartidor'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: UserProfileHeader(mostrarRating: true),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SessionStatusView(
              appLabel: 'App Repartidor — Villazón, Potosí',
            ),
            const _DisponibilidadSwitch(),
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

/// Disponible/no disponible para recibir ofertas (Sprint 8.4). Estado
/// optimista local: cambia el switch al toque y solo lo revierte si la
/// escritura falla — esperar el round-trip de `miDisponibilidadProvider`
/// para reflejar el toque haría el switch sentirse con lag.
class _DisponibilidadSwitch extends ConsumerStatefulWidget {
  const _DisponibilidadSwitch();

  @override
  ConsumerState<_DisponibilidadSwitch> createState() =>
      _DisponibilidadSwitchState();
}

class _DisponibilidadSwitchState extends ConsumerState<_DisponibilidadSwitch> {
  bool? _valorLocal;

  Future<void> _cambiar(bool valor) async {
    setState(() => _valorLocal = valor);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await ref
          .read(usersRepositoryProvider)
          .actualizarDisponibilidad(uid, valor);
    } catch (_) {
      if (mounted) setState(() => _valorLocal = !valor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disponibleAsync = ref.watch(miDisponibilidadProvider);
    return disponibleAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) => const SizedBox.shrink(),
      data: (disponible) {
        final valor = _valorLocal ?? disponible;
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SwitchListTile(
            title: const Text('Disponible para recibir ofertas'),
            value: valor,
            onChanged: _cambiar,
          ),
        );
      },
    );
  }
}
