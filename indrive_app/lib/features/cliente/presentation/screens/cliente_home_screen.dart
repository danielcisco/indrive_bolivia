import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/providers.dart';
import '../../../../shared/widgets/battery_optimization_prompt.dart';
import '../../../../shared/widgets/envio_activo_card.dart';
import '../widgets/cliente_home_drawer.dart';
import '../widgets/repartidores_mapa.dart';
import 'crear_envio_screen.dart';
import 'envio_detalle_screen.dart';
import 'mis_envios_screen.dart';

/// Home de Cliente (sprint extra: menú hamburguesa + mapa) — la
/// identidad, calificaciones, verificación, seguridad, tema y cuenta se
/// movieron al `ClienteHomeDrawer`; el mapa de repartidores disponibles
/// aprovecha el espacio que dejaron esos botones. Debajo del mapa queda
/// lo que se necesita ver siempre: envío activo (si hay uno). Los accesos
/// de uso diario (crear envío, ver mis envíos) viven en la barra de
/// navegación inferior en vez de botones sueltos en el body (sprint de
/// rediseño) — antes "Crear envío" quedaba a 2 toques (Home → Mis envíos
/// → botón "+"), ahora es un toque directo.
class ClienteHomeScreen extends ConsumerWidget {
  const ClienteHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final envioActivo = ref.watch(miEnvioActivoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('inDrive Entregas — Cliente')),
      drawer: const ClienteHomeDrawer(),
      body: Column(
        children: [
          const BatteryOptimizationPrompt(),
          const Expanded(child: RepartidoresMapa()),
          envioActivo.when(
            loading: () => const SizedBox.shrink(),
            error: (error, _) => const SizedBox.shrink(),
            data: (envio) {
              if (envio == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.all(16),
                child: EnvioActivoCard(
                  envio: envio,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EnvioDetalleScreen(envioId: envio.id),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 1:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CrearEnvioScreen()),
              );
            case 2:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MisEnviosScreen()),
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
            icon: Icon(Icons.add_circle_outline),
            label: 'Crear envío',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            label: 'Mis envíos',
          ),
        ],
      ),
    );
  }
}
