import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/providers.dart';
import '../../domain/usuario_admin.dart';

const _pageSize = 20;

/// Página de un grupo (rol + estado de verificación) — mismo esqueleto de
/// paginación que `KycPendingState`/`PagosPendientesState`, replicado 4
/// veces por `GestionUsuariosState` (Sprint 11) en vez de una sola lista
/// mezclada de Cliente+Repartidor y verificado+no verificado.
class GrupoUsuarios {
  const GrupoUsuarios({
    required this.usuarios,
    required this.hasMore,
    required this.isLoadingMore,
    required this.lastDocument,
  });

  const GrupoUsuarios.initial()
    : usuarios = const [],
      hasMore = true,
      isLoadingMore = false,
      lastDocument = null;

  final List<UsuarioAdmin> usuarios;
  final bool hasMore;
  final bool isLoadingMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;

  GrupoUsuarios copyWith({
    List<UsuarioAdmin>? usuarios,
    bool? hasMore,
    bool? isLoadingMore,
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
  }) => GrupoUsuarios(
    usuarios: usuarios ?? this.usuarios,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    lastDocument: lastDocument ?? this.lastDocument,
  );
}

class GestionUsuariosState {
  const GestionUsuariosState({
    required this.clientesNoVerificados,
    required this.clientesVerificados,
    required this.repartidoresNoVerificados,
    required this.repartidoresVerificados,
  });

  const GestionUsuariosState.initial()
    : clientesNoVerificados = const GrupoUsuarios.initial(),
      clientesVerificados = const GrupoUsuarios.initial(),
      repartidoresNoVerificados = const GrupoUsuarios.initial(),
      repartidoresVerificados = const GrupoUsuarios.initial();

  final GrupoUsuarios clientesNoVerificados;
  final GrupoUsuarios clientesVerificados;
  final GrupoUsuarios repartidoresNoVerificados;
  final GrupoUsuarios repartidoresVerificados;

  GestionUsuariosState copyWith({
    GrupoUsuarios? clientesNoVerificados,
    GrupoUsuarios? clientesVerificados,
    GrupoUsuarios? repartidoresNoVerificados,
    GrupoUsuarios? repartidoresVerificados,
  }) => GestionUsuariosState(
    clientesNoVerificados: clientesNoVerificados ?? this.clientesNoVerificados,
    clientesVerificados: clientesVerificados ?? this.clientesVerificados,
    repartidoresNoVerificados:
        repartidoresNoVerificados ?? this.repartidoresNoVerificados,
    repartidoresVerificados:
        repartidoresVerificados ?? this.repartidoresVerificados,
  );
}

/// 4 listas independientes, cada una paginada por su cuenta (Sprint 11) —
/// separar Cliente/Repartidor y Verificado/No verificado en 4 queries en
/// vez de filtrar una sola lista en memoria evita traer usuarios de más:
/// cada sección solo pide lo que necesita mostrar.
class GestionUsuariosController extends AsyncNotifier<GestionUsuariosState> {
  @override
  Future<GestionUsuariosState> build() async {
    final grupos = await Future.wait([
      _cargarGrupo(role: 'cliente', verificado: false),
      _cargarGrupo(role: 'cliente', verificado: true),
      _cargarGrupo(role: 'repartidor', verificado: false),
      _cargarGrupo(role: 'repartidor', verificado: true),
    ]);
    return GestionUsuariosState(
      clientesNoVerificados: grupos[0],
      clientesVerificados: grupos[1],
      repartidoresNoVerificados: grupos[2],
      repartidoresVerificados: grupos[3],
    );
  }

  Future<GrupoUsuarios> _cargarGrupo({
    required String role,
    required bool verificado,
    GrupoUsuarios? current,
  }) async {
    final base = current ?? const GrupoUsuarios.initial();
    final repository = ref.read(usersRepositoryProvider);
    final snapshot = await repository.listarUsuariosPorRolYEstado(
      role: role,
      verificado: verificado,
      limit: _pageSize,
      startAfter: base.lastDocument,
    );
    final nuevos = snapshot.docs.map(UsuarioAdmin.fromFirestore).toList();
    return base.copyWith(
      usuarios: [...base.usuarios, ...nuevos],
      hasMore: nuevos.length == _pageSize,
      isLoadingMore: false,
      lastDocument: snapshot.docs.isNotEmpty
          ? snapshot.docs.last
          : base.lastDocument,
    );
  }

  Future<void> cargarMasClientesNoVerificados() async {
    final current = state.value;
    final grupo = current?.clientesNoVerificados;
    if (current == null || grupo == null || !grupo.hasMore || grupo.isLoadingMore) {
      return;
    }
    state = AsyncData(
      current.copyWith(clientesNoVerificados: grupo.copyWith(isLoadingMore: true)),
    );
    final actualizado = await _cargarGrupo(
      role: 'cliente',
      verificado: false,
      current: grupo,
    );
    state = AsyncData(state.value!.copyWith(clientesNoVerificados: actualizado));
  }

  Future<void> cargarMasClientesVerificados() async {
    final current = state.value;
    final grupo = current?.clientesVerificados;
    if (current == null || grupo == null || !grupo.hasMore || grupo.isLoadingMore) {
      return;
    }
    state = AsyncData(
      current.copyWith(clientesVerificados: grupo.copyWith(isLoadingMore: true)),
    );
    final actualizado = await _cargarGrupo(
      role: 'cliente',
      verificado: true,
      current: grupo,
    );
    state = AsyncData(state.value!.copyWith(clientesVerificados: actualizado));
  }

  Future<void> cargarMasRepartidoresNoVerificados() async {
    final current = state.value;
    final grupo = current?.repartidoresNoVerificados;
    if (current == null || grupo == null || !grupo.hasMore || grupo.isLoadingMore) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        repartidoresNoVerificados: grupo.copyWith(isLoadingMore: true),
      ),
    );
    final actualizado = await _cargarGrupo(
      role: 'repartidor',
      verificado: false,
      current: grupo,
    );
    state = AsyncData(
      state.value!.copyWith(repartidoresNoVerificados: actualizado),
    );
  }

  Future<void> cargarMasRepartidoresVerificados() async {
    final current = state.value;
    final grupo = current?.repartidoresVerificados;
    if (current == null || grupo == null || !grupo.hasMore || grupo.isLoadingMore) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        repartidoresVerificados: grupo.copyWith(isLoadingMore: true),
      ),
    );
    final actualizado = await _cargarGrupo(
      role: 'repartidor',
      verificado: true,
      current: grupo,
    );
    state = AsyncData(
      state.value!.copyWith(repartidoresVerificados: actualizado),
    );
  }
}

final gestionUsuariosControllerProvider =
    AsyncNotifierProvider<GestionUsuariosController, GestionUsuariosState>(
      GestionUsuariosController.new,
    );
