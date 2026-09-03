import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/location/current_location.dart';
import '../../../../shared/data/providers.dart';
import '../../../../shared/widgets/battery_optimization_prompt.dart';
import '../../../../shared/widgets/envio_activo_card.dart';
import '../widgets/radar_mapa.dart';
import '../widgets/repartidor_home_drawer.dart';
import 'entrega_en_curso_screen.dart';
import 'mis_entregas_screen.dart';
import 'radar_screen.dart';
import 'subir_cedula_screen.dart';

/// Home de Repartidor (sprint extra: menú hamburguesa + mapa) — la
/// identidad, calificaciones, verificación, seguridad, tema y cuenta se
/// movieron al `RepartidorHomeDrawer`; el mapa de envíos pendientes
/// aprovecha el espacio que dejaron esos botones. Debajo del mapa queda
/// lo que se necesita ver siempre: entrega activa, disponibilidad, aviso
/// de KYC pendiente. Radar y Mis entregas viven en la barra de
/// navegación inferior en vez de botones sueltos en el body (sprint de
/// rediseño).
class RepartidorHomeScreen extends ConsumerWidget {
  const RepartidorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estadoKyc = ref.watch(miEstadoKycProvider);
    final entregaActiva = ref.watch(miEntregaActivaProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('inDrive Entregas — Repartidor')),
      drawer: const RepartidorHomeDrawer(),
      body: Column(
        children: [
          const BatteryOptimizationPrompt(),
          const Expanded(child: RadarMapa()),
          Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
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
                  // Diferido de KYC (seguimiento del Sprint 5.1): aviso
                  // solo mientras no está verificado y todavía no subió
                  // ninguna foto — una vez subida desaparece, aunque el
                  // admin todavía no la haya revisado.
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
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 1:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RadarScreen()),
              );
            case 2:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MisEntregasScreen()),
              );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.radar),
            label: 'Radar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            label: 'Mis entregas',
          ),
        ],
      ),
    );
  }
}

/// Disponible/no disponible para recibir ofertas (Sprint 8.4). Estado
/// optimista local: cambia el switch al toque y solo lo revierte si la
/// escritura falla — esperar el round-trip de `miDisponibilidadProvider`
/// para reflejar el toque haría el switch sentirse con lag.
///
/// Sprint extra: además de `disponible` en `users/{uid}`, ahora también
/// publica/retira la posición en `repartidores_disponibles/{uid}` (mapa
/// del Home de Cliente) — al prender el switch sube una lectura GPS
/// puntual, al apagarlo borra el documento entero.
class _DisponibilidadSwitch extends ConsumerStatefulWidget {
  const _DisponibilidadSwitch();

  @override
  ConsumerState<_DisponibilidadSwitch> createState() =>
      _DisponibilidadSwitchState();
}

class _DisponibilidadSwitchState extends ConsumerState<_DisponibilidadSwitch> {
  bool? _valorLocal;

  @override
  void initState() {
    super.initState();
    // Refresca la posición publicada cada vez que se reabre el Home ya
    // disponible — sin esto, un repartidor que dejó el switch prendido
    // ayer y se movió desde entonces seguiría apareciendo en el punto
    // viejo hasta el próximo toque del switch.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final disponible = await ref
          .read(usersRepositoryProvider)
          .obtenerDisponibilidad(uid);
      if (disponible) await _publicarPosicion(uid);
    });
  }

  Future<void> _publicarPosicion(String uid) async {
    try {
      final posicion = await obtenerUbicacionActual();
      final tipoVehiculo = await ref
          .read(usersRepositoryProvider)
          .obtenerTipoVehiculo(uid);
      await ref
          .read(usersRepositoryProvider)
          .publicarDisponibilidad(
            uid,
            posicion: GeoPoint(posicion.latitude, posicion.longitude),
            tipoVehiculo: tipoVehiculo,
          );
    } catch (_) {
      // Falla silenciosa a propósito: no bloquea el switch (la
      // disponibilidad para ofertas ya quedó guardada), solo el mapa del
      // Cliente no muestra a este repartidor hasta el próximo intento.
    }
  }

  Future<void> _cambiar(bool valor) async {
    setState(() => _valorLocal = valor);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await ref
          .read(usersRepositoryProvider)
          .actualizarDisponibilidad(uid, valor);
      if (valor) {
        await _publicarPosicion(uid);
      } else {
        await ref.read(usersRepositoryProvider).retirarDisponibilidad(uid);
      }
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
