import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../domain/entities/envio.dart';
import 'estado_envio_chip.dart';

const _mesesAbreviados = [
  'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
];

/// "28 Abr" a partir de un `Timestamp` (Sprint 21) — sin paquete `intl`,
/// que el proyecto no usa en ningún otro lado, para algo tan chico.
String formatearFechaCorta(Timestamp? timestamp) {
  if (timestamp == null) return '';
  final fecha = timestamp.toDate();
  return '${fecha.day} ${_mesesAbreviados[fecha.month - 1]}';
}

String _formatearHora(Timestamp? timestamp) {
  if (timestamp == null) return '';
  final fecha = timestamp.toDate();
  return '${fecha.hour.toString().padLeft(2, '0')}:'
      '${fecha.minute.toString().padLeft(2, '0')}';
}

IconData _iconoCategoria(CategoriaPaquete categoria) => switch (categoria) {
  CategoriaPaquete.documentos => Icons.description_outlined,
  CategoriaPaquete.paqueteChico => Icons.inventory_2_outlined,
  CategoriaPaquete.paqueteMediano => Icons.inventory_outlined,
  CategoriaPaquete.encomiendaMercado => Icons.shopping_basket_outlined,
};

/// Tarjeta de historial de un envío/entrega (Sprint 21) — reemplaza el
/// `ListTile` plano de "Mis envíos"/"Mis entregas": ícono según categoría,
/// hora, monto y `EstadoEnvioChip`, mismo criterio visual en las dos
/// pantallas.
class EnvioHistorialCard extends StatelessWidget {
  const EnvioHistorialCard({
    super.key,
    required this.envio,
    required this.onTap,
  });

  final Envio envio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primaryContainer,
                child: Icon(
                  _iconoCategoria(envio.categoria),
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      envio.descripcion,
                      style: Theme.of(context).textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatearHora(envio.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    envio.montoOfertadoInicial.format(),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  EstadoEnvioChip(status: envio.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Encabezado de grupo de fecha ("28 Abr") — se inserta antes de la
/// primera card de cada día distinto en la lista, mismo criterio que el
/// historial de referencia.
class FechaGrupoHeader extends StatelessWidget {
  const FechaGrupoHeader({super.key, required this.fecha});

  final String fecha;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        fecha,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
