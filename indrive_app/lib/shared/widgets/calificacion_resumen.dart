import 'package:flutter/material.dart';

import '../domain/entities/perfil_publico.dart';

/// Calificación resumida (★ X.X (N)) junto al nombre en las tarjetas de
/// identidad de la contraparte — antes esas tarjetas no mostraban
/// ninguna señal de confianza, justo donde más importa (antes/durante la
/// entrega). "Sin calificaciones" si todavía no tiene ninguna.
class CalificacionResumen extends StatelessWidget {
  const CalificacionResumen({super.key, required this.perfil});

  final PerfilPublico perfil;

  @override
  Widget build(BuildContext context) {
    if (perfil.totalCalificaciones == 0) {
      return Text(
        'Sin calificaciones',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star,
          size: 16,
          color: Theme.of(context).colorScheme.secondary,
        ),
        const SizedBox(width: 2),
        Text(
          '${perfil.ratingPromedio.toStringAsFixed(1)} '
          '(${perfil.totalCalificaciones})',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
