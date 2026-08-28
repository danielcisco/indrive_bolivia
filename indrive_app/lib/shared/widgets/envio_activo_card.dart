import 'package:flutter/material.dart';

import '../domain/entities/envio.dart';
import 'estado_envio_chip.dart';

/// Card de "esto tenés activo ahora" para el Home (Sprint 16) — antes había
/// que entrar a "Mis envíos"/"Mis entregas" para enterarse de si algo
/// seguía en curso; la Home era un menú de botones sin ningún resumen.
class EnvioActivoCard extends StatelessWidget {
  const EnvioActivoCard({super.key, required this.envio, required this.onTap});

  final Envio envio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.local_shipping_outlined,
                color: Theme.of(context).colorScheme.primary,
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
                    const SizedBox(height: 4),
                    EstadoEnvioChip(status: envio.status),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
