import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/domain/entities/envio.dart';
import '../../../../shared/widgets/envio_historial_card.dart';
import '../../../../shared/widgets/filtro_estado_chips.dart';
import '../../../../shared/widgets/soporte_whatsapp.dart';
import '../providers/mis_envios_controller.dart';
import 'crear_envio_screen.dart';
import 'envio_detalle_screen.dart';

const _opcionesFiltro = <(EnvioStatus?, String)>[
  (null, 'Todos'),
  (EnvioStatus.pendienteOfertas, 'Pendientes'),
  (EnvioStatus.asignado, 'Asignado'),
  (EnvioStatus.enCurso, 'En curso'),
  (EnvioStatus.entregado, 'Entregado'),
  (EnvioStatus.cancelado, 'Cancelado'),
  (EnvioStatus.expirado, 'Expirado'),
];

class MisEnviosScreen extends ConsumerWidget {
  const MisEnviosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(misEnviosControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis envíos'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: FiltroEstadoChips(
            opciones: _opcionesFiltro,
            seleccionado: estado.value?.filtro,
            onCambiar: (filtro) => ref
                .read(misEnviosControllerProvider.notifier)
                .cambiarFiltro(filtro),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CrearEnvioScreen())),
        child: const Icon(Icons.add),
      ),
      body: estado.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const SupportErrorView(
          mensaje: 'No pudimos cargar tus envíos. Revisá tu conexión y '
              'volvé a intentar.',
          app: 'Cliente',
          motivo: 'no puedo ver mis envíos',
        ),
        data: (data) {
          // No usa ref.invalidate(): eso vuelve a construir el provider
          // desde MisEnviosState.initial() sin filtro, perdiendo el que
          // el usuario ya eligió. cambiarFiltro(data.filtro) refresca
          // manteniendo el mismo filtro seleccionado.
          Future<void> refrescar() => ref
              .read(misEnviosControllerProvider.notifier)
              .cambiarFiltro(data.filtro);

          if (data.envios.isEmpty) {
            return RefreshIndicator(
              onRefresh: refrescar,
              child: ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_shipping_outlined, size: 48),
                          SizedBox(height: 8),
                          Text('Todavía no tienes envíos.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Historial agrupado por fecha (Sprint 21): una entrada de
          // encabezado (String) antes de la primera card de cada día
          // distinto — los envíos ya llegan ordenados por createdAt
          // descendente, así que alcanza con comparar contra el anterior.
          final entradas = <Object>[];
          String? fechaAnterior;
          for (final envio in data.envios) {
            final fecha = formatearFechaCorta(envio.createdAt);
            if (fecha != fechaAnterior) {
              entradas.add(fecha);
              fechaAnterior = fecha;
            }
            entradas.add(envio);
          }

          return RefreshIndicator(
            onRefresh: refrescar,
            child: ListView.builder(
              itemCount: entradas.length + (data.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= entradas.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: data.isLoadingMore
                          ? const CircularProgressIndicator()
                          : OutlinedButton(
                              onPressed: () => ref
                                  .read(misEnviosControllerProvider.notifier)
                                  .cargarMas(),
                              child: const Text('Cargar más'),
                            ),
                    ),
                  );
                }
                final entrada = entradas[index];
                if (entrada is String) {
                  return FechaGrupoHeader(fecha: entrada);
                }
                final envio = entrada as Envio;
                return EnvioHistorialCard(
                  envio: envio,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EnvioDetalleScreen(envioId: envio.id),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
