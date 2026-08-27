import 'package:flutter/material.dart';

import '../domain/entities/envio.dart';

/// Fila horizontal de chips para filtrar una lista de envíos por estado —
/// compartida por "Mis envíos" (Cliente) y "Mis entregas" (Repartidor):
/// cada pantalla define sus propias [opciones] (los estados relevantes
/// difieren entre ambas), pero el control es el mismo en las dos apps.
class FiltroEstadoChips extends StatelessWidget {
  const FiltroEstadoChips({
    super.key,
    required this.opciones,
    required this.seleccionado,
    required this.onCambiar,
  });

  /// Cada opción es (estado, etiqueta) — estado `null` significa "Todas".
  final List<(EnvioStatus?, String)> opciones;
  final EnvioStatus? seleccionado;
  final ValueChanged<EnvioStatus?> onCambiar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final (estado, etiqueta) in opciones)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(etiqueta),
                selected: seleccionado == estado,
                onSelected: (_) => onCambiar(estado),
              ),
            ),
        ],
      ),
    );
  }
}
