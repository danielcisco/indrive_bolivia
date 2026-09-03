import 'package:flutter/material.dart';

import '../domain/entities/envio.dart';
import '../theme/colores_semanticos.dart';

/// Chip de estado con color — reemplaza `Text('Estado: ${envio.status.name}')`
/// (Sprint 16), que imprimía el enum crudo en camelCase (`pendienteOfertas`,
/// `enCurso`) directo en la UI. Colores semánticos fijos (no roles del
/// `ColorScheme`, que ya están tomados por la marca): verde para
/// "entregado" es una convención universal que no conviene mapear al verde
/// derivado de un seed distinto. `ColoresSemanticos` trae el par
/// claro/oscuro de cada uno, así el chip se adapta a `ThemeMode.system`.
class EstadoEnvioChip extends StatelessWidget {
  const EstadoEnvioChip({super.key, required this.status});

  final EnvioStatus status;

  (String, Color, Color) _estilo(BuildContext context) => switch (status) {
    EnvioStatus.pendienteOfertas => (
      'Pendiente',
      ColoresSemanticos.info(context).$1,
      ColoresSemanticos.info(context).$2,
    ),
    EnvioStatus.asignado => (
      'Asignado',
      ColoresSemanticos.advertencia(context).$1,
      ColoresSemanticos.advertencia(context).$2,
    ),
    EnvioStatus.enCurso => (
      'En curso',
      ColoresSemanticos.advertencia(context).$1,
      ColoresSemanticos.advertencia(context).$2,
    ),
    EnvioStatus.entregado => (
      'Entregado',
      ColoresSemanticos.exito(context).$1,
      ColoresSemanticos.exito(context).$2,
    ),
    EnvioStatus.cancelado => (
      'Cancelado',
      ColoresSemanticos.neutro(context).$1,
      ColoresSemanticos.neutro(context).$2,
    ),
    EnvioStatus.expirado => (
      'Expirado',
      ColoresSemanticos.neutro(context).$1,
      ColoresSemanticos.neutro(context).$2,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (etiqueta, colorTexto, colorFondo) = _estilo(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        etiqueta,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorTexto,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
