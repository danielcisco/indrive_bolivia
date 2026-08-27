import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/providers.dart';
import '../../domain/usuario_admin.dart';

const _pageSize = 20;

class GestionUsuariosState {
  const GestionUsuariosState({
    required this.usuarios,
    required this.hasMore,
    required this.isLoadingMore,
    required this.lastDocument,
  });

  const GestionUsuariosState.initial()
    : usuarios = const [],
      hasMore = true,
      isLoadingMore = false,
      lastDocument = null;

  final List<UsuarioAdmin> usuarios;
  final bool hasMore;
  final bool isLoadingMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;

  GestionUsuariosState copyWith({
    List<UsuarioAdmin>? usuarios,
    bool? hasMore,
    bool? isLoadingMore,
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
  }) => GestionUsuariosState(
    usuarios: usuarios ?? this.usuarios,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    lastDocument: lastDocument ?? this.lastDocument,
  );
}

/// Lista paginada de todos los usuarios — mismo esqueleto que
/// `KycPendingController`/`PagosPendientesController` (sprint extra,
/// Grupo C).
class GestionUsuariosController extends AsyncNotifier<GestionUsuariosState> {
  @override
  Future<GestionUsuariosState> build() {
    return _cargarPagina(const GestionUsuariosState.initial());
  }

  Future<void> cargarMas() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    state = await AsyncValue.guard(() => _cargarPagina(current));
  }

  Future<GestionUsuariosState> _cargarPagina(
    GestionUsuariosState current,
  ) async {
    final repository = ref.read(usersRepositoryProvider);
    final snapshot = await repository.listarUsuarios(
      limit: _pageSize,
      startAfter: current.lastDocument,
    );
    final nuevos = snapshot.docs.map(UsuarioAdmin.fromFirestore).toList();
    return current.copyWith(
      usuarios: [...current.usuarios, ...nuevos],
      hasMore: nuevos.length == _pageSize,
      isLoadingMore: false,
      lastDocument: snapshot.docs.isNotEmpty
          ? snapshot.docs.last
          : current.lastDocument,
    );
  }
}

final gestionUsuariosControllerProvider =
    AsyncNotifierProvider<GestionUsuariosController, GestionUsuariosState>(
      GestionUsuariosController.new,
    );
