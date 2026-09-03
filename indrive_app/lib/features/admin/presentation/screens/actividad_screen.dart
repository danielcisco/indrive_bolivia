import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/providers.dart';
import '../../../../shared/domain/entities/envio.dart';
import '../../../../shared/domain/entities/perfil_publico.dart';
import '../../../../shared/widgets/soporte_whatsapp.dart';

/// Clientes y repartidores con actividad ahora mismo (sprint extra) —
/// reusa exclusivamente streams acotados que ya existían para otras
/// pantallas (`repartidoresDisponiblesProvider`, `enviosEnCursoStreamProvider`)
/// más uno nuevo con la misma forma (`enviosPendientesOfertasStreamProvider`):
/// sin colección nueva, sin escrituras nuevas, sin tracking de presencia
/// de clientes (no existe, y agregarlo violaría la regla de "no streams
/// masivos" de CLAUDE.md sin necesidad — la actividad de un cliente ya
/// se ve reflejada en sus envíos activos).
class ActividadScreen extends StatefulWidget {
  const ActividadScreen({super.key});

  @override
  State<ActividadScreen> createState() => _ActividadScreenState();
}

class _ActividadScreenState extends State<ActividadScreen>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Repartidores'),
            Tab(text: 'Clientes'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [_TabRepartidores(), _TabClientes()],
          ),
        ),
      ],
    );
  }
}

String _nombrePerfil(AsyncValue<PerfilPublico?> perfil, {required String cargando}) {
  return perfil.when(
    loading: () => cargando,
    error: (error, _) => 'Error al cargar perfil',
    data: (valor) => valor == null
        ? 'Sin perfil registrado'
        : '${valor.nombre} ${valor.apellido} (@${valor.nick})',
  );
}

class _TabRepartidores extends ConsumerWidget {
  const _TabRepartidores();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enCurso = ref.watch(enviosEnCursoStreamProvider);
    final disponibles = ref.watch(repartidoresDisponiblesProvider);

    return ListView(
      children: [
        _encabezado(context, 'En entrega ahora', enCurso.value?.length),
        enCurso.when(
          loading: () => const _CargandoTile(),
          error: (error, _) => const _ErrorTile(
            mensaje: 'No pudimos cargar las entregas en curso.',
            motivo: 'no puedo ver las entregas en curso en Actividad',
          ),
          data: (envios) {
            final conRepartidor = envios
                .where((e) => e.repartidorAsignadoId != null)
                .toList();
            if (conRepartidor.isEmpty) {
              return const _VacioTile('Ningún repartidor en entrega ahora.');
            }
            return Column(
              children: [
                for (final envio in conRepartidor)
                  Consumer(
                    builder: (context, ref, _) {
                      final perfil = ref.watch(
                        perfilPublicoProvider(envio.repartidorAsignadoId!),
                      );
                      return ListTile(
                        leading: const Icon(Icons.local_shipping_outlined),
                        title: Text(
                          _nombrePerfil(perfil, cargando: 'Cargando...'),
                        ),
                        subtitle: Text(
                          '${envio.descripcion} · ${envio.montoOfertadoInicial.format()}',
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
        const Divider(height: 24),
        _encabezado(context, 'Disponibles', disponibles.value?.docs.length),
        disponibles.when(
          loading: () => const _CargandoTile(),
          error: (error, _) => const _ErrorTile(
            mensaje: 'No pudimos cargar los repartidores disponibles.',
            motivo: 'no puedo ver los repartidores disponibles en Actividad',
          ),
          data: (snapshot) {
            if (snapshot.docs.isEmpty) {
              return const _VacioTile('Ningún repartidor disponible ahora.');
            }
            return Column(
              children: [
                for (final doc in snapshot.docs)
                  Consumer(
                    builder: (context, ref, _) {
                      final perfil = ref.watch(perfilPublicoProvider(doc.id));
                      final tipoVehiculo = doc.data()['tipoVehiculo'] as String?;
                      return ListTile(
                        leading: Icon(
                          tipoVehiculo == 'auto'
                              ? Icons.directions_car_outlined
                              : Icons.two_wheeler_outlined,
                        ),
                        title: Text(
                          _nombrePerfil(perfil, cargando: 'Cargando...'),
                        ),
                        subtitle: Text(
                          tipoVehiculo == 'auto' ? 'Automóvil' : 'Motocicleta',
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TabClientes extends ConsumerWidget {
  const _TabClientes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enCurso = ref.watch(enviosEnCursoStreamProvider);
    final pendientes = ref.watch(enviosPendientesOfertasStreamProvider);

    Widget listaPorCliente(AsyncValue<List<Envio>> estado, String vacioMensaje, String errorMotivo) {
      return estado.when(
        loading: () => const _CargandoTile(),
        error: (error, _) => _ErrorTile(
          mensaje: 'No pudimos cargar los envíos.',
          motivo: errorMotivo,
        ),
        data: (envios) {
          if (envios.isEmpty) return _VacioTile(vacioMensaje);
          return Column(
            children: [
              for (final envio in envios)
                Consumer(
                  builder: (context, ref, _) {
                    final perfil = ref.watch(
                      perfilPublicoProvider(envio.clienteId),
                    );
                    return ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(
                        _nombrePerfil(perfil, cargando: 'Cargando...'),
                      ),
                      subtitle: Text(
                        '${envio.descripcion} · ${envio.montoOfertadoInicial.format()}',
                      ),
                    );
                  },
                ),
            ],
          );
        },
      );
    }

    return ListView(
      children: [
        _encabezado(context, 'Con envío en curso', enCurso.value?.length),
        listaPorCliente(
          enCurso,
          'Ningún cliente con un envío en curso ahora.',
          'no puedo ver clientes con envío en curso en Actividad',
        ),
        const Divider(height: 24),
        _encabezado(context, 'Esperando ofertas', pendientes.value?.length),
        listaPorCliente(
          pendientes,
          'Ningún cliente esperando ofertas ahora.',
          'no puedo ver clientes esperando ofertas en Actividad',
        ),
      ],
    );
  }
}

Widget _encabezado(BuildContext context, String titulo, int? cantidad) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      cantidad != null ? '$titulo ($cantidad)' : titulo,
      style: Theme.of(context).textTheme.titleSmall,
    ),
  );
}

class _CargandoTile extends StatelessWidget {
  const _CargandoTile();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: LinearProgressIndicator(),
  );
}

class _VacioTile extends StatelessWidget {
  const _VacioTile(this.mensaje);

  final String mensaje;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Text(mensaje),
  );
}

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.mensaje, required this.motivo});

  final String mensaje;
  final String motivo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: SupportErrorView(mensaje: mensaje, app: 'Admin', motivo: motivo),
  );
}
