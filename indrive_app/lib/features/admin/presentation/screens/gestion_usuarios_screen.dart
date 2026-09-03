import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/colores_semanticos.dart';
import '../../../../shared/widgets/envio_historial_card.dart'
    show formatearFechaCorta;
import '../../../../shared/widgets/soporte_whatsapp.dart';
import '../providers/gestion_usuarios_controller.dart';
import 'usuario_detalle_screen.dart';

/// Cliente/Repartidor × Verificado/No verificado en tabs anidados —
/// mismo patrón que `KycPendingScreen`/`PagosPendientesScreen`
/// (Pendientes/Historial): antes eran 4 secciones apiladas en un solo
/// `ListView`, que obligaba a deslizar bastante para llegar, por
/// ejemplo, a los repartidores verificados. Los 4 grupos de datos no
/// cambian — solo cómo se presentan.
class GestionUsuariosScreen extends ConsumerStatefulWidget {
  const GestionUsuariosScreen({super.key});

  @override
  ConsumerState<GestionUsuariosScreen> createState() =>
      _GestionUsuariosScreenState();
}

class _GestionUsuariosScreenState extends ConsumerState<GestionUsuariosScreen>
    with TickerProviderStateMixin {
  late final _rolController = TabController(length: 2, vsync: this);
  late final _estadoClienteController = TabController(length: 2, vsync: this);
  late final _estadoRepartidorController = TabController(
    length: 2,
    vsync: this,
  );

  @override
  void dispose() {
    _rolController.dispose();
    _estadoClienteController.dispose();
    _estadoRepartidorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(gestionUsuariosControllerProvider);

    return estado.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => const SupportErrorView(
        mensaje:
            'No pudimos cargar la lista de usuarios. Revisá tu '
            'conexión y volvé a intentar.',
        app: 'Admin',
        motivo: 'no puedo ver la lista de usuarios',
      ),
      data: (data) {
        final notifier = ref.read(gestionUsuariosControllerProvider.notifier);

        Future<void> refrescar() async {
          ref.invalidate(gestionUsuariosControllerProvider);
          await ref.read(gestionUsuariosControllerProvider.future);
        }

        return Column(
          children: [
            TabBar(
              controller: _rolController,
              tabs: const [
                Tab(text: 'Clientes'),
                Tab(text: 'Repartidores'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _rolController,
                children: [
                  _RolTab(
                    tabController: _estadoClienteController,
                    noVerificados: data.clientesNoVerificados,
                    verificados: data.clientesVerificados,
                    onCargarMasNoVerificados:
                        notifier.cargarMasClientesNoVerificados,
                    onCargarMasVerificados:
                        notifier.cargarMasClientesVerificados,
                    onRefrescar: refrescar,
                  ),
                  _RolTab(
                    tabController: _estadoRepartidorController,
                    noVerificados: data.repartidoresNoVerificados,
                    verificados: data.repartidoresVerificados,
                    onCargarMasNoVerificados:
                        notifier.cargarMasRepartidoresNoVerificados,
                    onCargarMasVerificados:
                        notifier.cargarMasRepartidoresVerificados,
                    onRefrescar: refrescar,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Un rol (Clientes o Repartidores) con su propio tab interno de
/// No verificados/Verificados.
class _RolTab extends StatelessWidget {
  const _RolTab({
    required this.tabController,
    required this.noVerificados,
    required this.verificados,
    required this.onCargarMasNoVerificados,
    required this.onCargarMasVerificados,
    required this.onRefrescar,
  });

  final TabController tabController;
  final GrupoUsuarios noVerificados;
  final GrupoUsuarios verificados;
  final VoidCallback onCargarMasNoVerificados;
  final VoidCallback onCargarMasVerificados;
  final Future<void> Function() onRefrescar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: tabController,
          labelStyle: Theme.of(context).textTheme.labelMedium,
          tabs: [
            Tab(
              text:
                  'No verificados (${noVerificados.usuarios.length}${noVerificados.hasMore ? '+' : ''})',
            ),
            Tab(
              text:
                  'Verificados (${verificados.usuarios.length}${verificados.hasMore ? '+' : ''})',
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              _ListaUsuarios(
                grupo: noVerificados,
                onCargarMas: onCargarMasNoVerificados,
                onRefrescar: onRefrescar,
              ),
              _ListaUsuarios(
                grupo: verificados,
                onCargarMas: onCargarMasVerificados,
                onRefrescar: onRefrescar,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ListaUsuarios extends StatelessWidget {
  const _ListaUsuarios({
    required this.grupo,
    required this.onCargarMas,
    required this.onRefrescar,
  });

  final GrupoUsuarios grupo;
  final VoidCallback onCargarMas;
  final Future<void> Function() onRefrescar;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefrescar,
      child: grupo.usuarios.isEmpty
          ? ListView(
              // Con un solo hijo, RefreshIndicator igual necesita una
              // lista scrolleable para que el gesto de deslizar funcione.
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                  child: Text('Ninguna cuenta en este grupo.'),
                ),
              ],
            )
          : ListView.builder(
              itemCount: grupo.usuarios.length + (grupo.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= grupo.usuarios.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: grupo.isLoadingMore
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : TextButton(
                              onPressed: onCargarMas,
                              child: const Text('Cargar más'),
                            ),
                    ),
                  );
                }
                final usuario = grupo.usuarios[index];
                final (colorEstado, colorEstadoFondo) = usuario.isActive
                    ? ColoresSemanticos.exito(context)
                    : ColoresSemanticos.neutro(context);
                final registrado = formatearFechaCorta(usuario.createdAt);
                final calificacion = usuario.totalCalificaciones > 0
                    ? '★ ${usuario.ratingPromedio.toStringAsFixed(1)} (${usuario.totalCalificaciones})'
                    : 'Sin calificaciones';
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        usuario.role == 'repartidor'
                            ? Icons.two_wheeler_outlined
                            : Icons.person_outline,
                      ),
                    ),
                    title: Text(usuario.phoneNumber ?? usuario.uid),
                    subtitle: Text(
                      registrado.isEmpty
                          ? calificacion
                          : 'Desde $registrado · $calificacion',
                    ),
                    trailing: Chip(
                      label: Text(usuario.isActive ? 'Activo' : 'Suspendido'),
                      labelStyle: TextStyle(color: colorEstado),
                      backgroundColor: colorEstadoFondo,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UsuarioDetalleScreen(usuario: usuario),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
