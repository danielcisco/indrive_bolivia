import 'package:flutter/material.dart';

import '../domain/entities/envio.dart';

/// Chip de estado con color — reemplaza `Text('Estado: ${envio.status.name}')`
/// (Sprint 16), que imprimía el enum crudo en camelCase (`pendienteOfertas`,
/// `enCurso`) directo en la UI. Colores semánticos fijos (no roles del
/// `ColorScheme`, que ya están tomados por la marca): verde para
/// "entregado" es una convención universal que no conviene mapear al verde
/// derivado de un seed distinto.
class EstadoEnvioChip extends StatelessWidget {
  const EstadoEnvioChip({super.key, required this.status});

  final EnvioStatus status;

  static const _verde = Color(0xFF2E7D32);
  static const _verdeFondo = Color(0xFFE3F2E5);
  static const _ambar = Color(0xFF8A5A00);
  static const _ambarFondo = Color(0xFFFCEACB);
  static const _azul = Color(0xFF0B5FFF);
  static const _azulFondo = Color(0xFFE3ECFF);
  static const _gris = Color(0xFF5F6368);
  static const _grisFondo = Color(0xFFE8E9EA);

  (String, Color, Color) get _estilo => switch (status) {
    EnvioStatus.pendienteOfertas => ('Pendiente', _azul, _azulFondo),
    EnvioStatus.asignado => ('Asignado', _ambar, _ambarFondo),
    EnvioStatus.enCurso => ('En curso', _ambar, _ambarFondo),
    EnvioStatus.entregado => ('Entregado', _verde, _verdeFondo),
    EnvioStatus.cancelado => ('Cancelado', _gris, _grisFondo),
    EnvioStatus.expirado => ('Expirado', _gris, _grisFondo),
  };

  @override
  Widget build(BuildContext context) {
    final (etiqueta, colorTexto, colorFondo) = _estilo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        etiqueta,
        style: TextStyle(
          color: colorTexto,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
