import 'package:flutter/material.dart';

import '../../core/tracking/battery_optimization.dart';

/// Aviso de exclusión de optimización de batería, para notificaciones
/// confiables (sprint extra) — Repartidor ya tenía uno parecido pero solo
/// al iniciar un viaje (para el rastreo en segundo plano); las
/// notificaciones (envío aceptado, contraoferta, cerca tuyo, etc.)
/// importan desde el primer momento, no solo durante una entrega, y
/// Cliente no tenía ningún aviso — en Samsung/Xiaomi la app recién
/// instalada no queda exenta por su cuenta y el sistema puede empezar a
/// demorar o directamente no mostrar push en segundo plano después de un
/// rato sin uso.
///
/// Widget invisible: se cuelga una sola vez en el árbol de Home (no se
/// reconstruye en cada rebuild de Home gracias a que Flutter preserva el
/// State mientras el widget siga en la misma posición) y dispara el
/// diálogo apenas monta, si la app todavía no está excluida.
class BatteryOptimizationPrompt extends StatefulWidget {
  const BatteryOptimizationPrompt({super.key});

  @override
  State<BatteryOptimizationPrompt> createState() =>
      _BatteryOptimizationPromptState();
}

class _BatteryOptimizationPromptState
    extends State<BatteryOptimizationPrompt> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _confirmar();
    });
  }

  Future<void> _confirmar() async {
    if (await BatteryOptimization.estaExcluida()) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir de optimización de batería'),
        content: const Text(
          'Para que las notificaciones (envíos, ofertas, cambios de '
          'estado) no dejen de llegar en segundo plano — sobre todo en '
          'Xiaomi/Samsung — excluí la app de la optimización de batería.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () async {
              await BatteryOptimization.solicitarExclusion();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Excluir app'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
