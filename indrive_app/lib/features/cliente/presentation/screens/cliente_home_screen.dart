import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/providers.dart';
import '../../../../shared/widgets/battery_optimization_prompt.dart';
import '../../../../shared/widgets/envio_activo_card.dart';
import '../widgets/cliente_home_drawer.dart';
import 'envio_detalle_screen.dart';
import 'mis_envios_screen.dart';

/// Home de Cliente (sprint extra: menú hamburguesa) — la identidad, las
/// calificaciones, la verificación, seguridad y la cuenta se movieron al
/// `ClienteHomeDrawer`; acá solo queda lo que importa ver de entrada: el
/// envío activo (si hay uno) y la acción principal.
class ClienteHomeScreen extends ConsumerWidget {
  const ClienteHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final envioActivo = ref.watch(miEnvioActivoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('inDrive Entregas — Cliente')),
      drawer: const ClienteHomeDrawer(),
      // Scrollbar siempre visible (sprint extra) — con la card de envío
      // activo + el aviso de batería, en un celular chico el contenido
      // puede pasar del alto disponible; antes no había ninguna señal de
      // que hubiera algo más para ver deslizando.
      body: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const BatteryOptimizationPrompt(),
              envioActivo.when(
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
                          builder: (_) => EnvioDetalleScreen(envioId: envio.id),
                        ),
                      ),
                    ),
                  );
                },
              ),
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
      ),
    );
  }
}
