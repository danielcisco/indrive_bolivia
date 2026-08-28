import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/providers.dart';
import '../../../../shared/widgets/battery_optimization_prompt.dart';
import '../../../../shared/widgets/envio_activo_card.dart';
import '../widgets/repartidor_home_drawer.dart';
import 'entrega_en_curso_screen.dart';
import 'mis_entregas_screen.dart';
import 'radar_screen.dart';
import 'subir_cedula_screen.dart';

/// Home de Repartidor (sprint extra: menú hamburguesa) — la identidad,
/// calificaciones, verificación, seguridad y cuenta se movieron al
/// `RepartidorHomeDrawer`; acá queda lo que se mira apenas se abre la
/// app: entrega activa, disponibilidad, aviso de KYC pendiente, y las 2
/// acciones principales (Radar / Mis entregas).
class RepartidorHomeScreen extends ConsumerWidget {
  const RepartidorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estadoKyc = ref.watch(miEstadoKycProvider);
    final entregaActiva = ref.watch(miEntregaActivaProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('inDrive Entregas — Repartidor')),
      drawer: const RepartidorHomeDrawer(),
      body: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const BatteryOptimizationPrompt(),
              entregaActiva.when(
                loading: () => const SizedBox.shrink(),
                error: (error, _) => const SizedBox.shrink(),
                data: (envio) {
                  if (envio == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: EnvioActivoCard(
                      envio: envio,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              EntregaEnCursoScreen(envioId: envio.id),
                        ),
                      ),
                    ),
                  );
                },
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
                    MaterialPageRoute(
                      builder: (_) => const MisEntregasScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Mis entregas'),
                ),
              ),
            ],
          ),
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
