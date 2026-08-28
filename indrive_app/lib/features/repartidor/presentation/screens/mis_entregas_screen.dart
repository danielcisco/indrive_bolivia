import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/domain/entities/envio.dart';
import '../../../../shared/widgets/envio_historial_card.dart';
import '../../../../shared/widgets/filtro_estado_chips.dart';
import '../../../../shared/widgets/soporte_whatsapp.dart';
import '../providers/mis_entregas_controller.dart';
import 'entrega_en_curso_screen.dart';

const _opcionesFiltro = <(EnvioStatus?, String)>[
  (null, 'Todas'),
  (EnvioStatus.asignado, 'Asignadas'),
  (EnvioStatus.enCurso, 'En curso'),
  (EnvioStatus.entregado, 'Entregadas'),
];

class MisEntregasScreen extends ConsumerStatefulWidget {
  const MisEntregasScreen({super.key, this.envioIdRecienAsignado});

  /// Presente cuando se llega acá por la notificación de "te asignaron un
  /// envío" (Sprint 14, contraoferta aceptada) — resalta esa entrega en
  /// la lista y muestra un aviso arriba, para que quede claro por qué
  /// apareció algo nuevo sin que el repartidor hiciera nada él mismo.
  final String? envioIdRecienAsignado;

  @override
  ConsumerState<MisEntregasScreen> createState() => _MisEntregasScreenState();
}

class _MisEntregasScreenState extends ConsumerState<MisEntregasScreen> {
  late bool _mostrarAviso = widget.envioIdRecienAsignado != null;

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(misEntregasControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis entregas'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: FiltroEstadoChips(
            opciones: _opcionesFiltro,
            seleccionado: estado.value?.filtro,
            onCambiar: (filtro) => ref
                .read(misEntregasControllerProvider.notifier)
                .cambiarFiltro(filtro),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_mostrarAviso)
            MaterialBanner(
              leading: const Icon(Icons.celebration_outlined),
              content: const Text(
                'El cliente aceptó tu propuesta — te asignaron el envío '
                'resaltado abajo.',
              ),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _mostrarAviso = false),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          Expanded(
            child: estado.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => const SupportErrorView(
                mensaje:
                    'No pudimos cargar tus entregas. Revisá tu conexión y '
                    'volvé a intentar.',
                app: 'Repartidor',
                motivo: 'no puedo ver mis entregas',
              ),
              data: (data) {
                Future<void> refrescar() => ref
                    .read(misEntregasControllerProvider.notifier)
                    .refrescar();

                if (data.entregas.isEmpty) {
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
                                Text('No tienes entregas activas por ahora.'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Historial agrupado por fecha (Sprint 21), mismo criterio
                // que mis_envios_screen.dart.
                final entradas = <Object>[];
                String? fechaAnterior;
                for (final envio in data.entregas) {
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
                                        .read(
                                          misEntregasControllerProvider
                                              .notifier,
                                        )
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
                      final esRecienAsignado =
                          envio.id == widget.envioIdRecienAsignado;
                      return Stack(
                        children: [
                          EnvioHistorialCard(
                            envio: envio,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    EntregaEnCursoScreen(envioId: envio.id),
                              ),
                            ),
                          ),
                          if (esRecienAsignado)
                            Positioned(
                              top: 8,
                              right: 24,
                              child: Icon(
                                Icons.fiber_new,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
