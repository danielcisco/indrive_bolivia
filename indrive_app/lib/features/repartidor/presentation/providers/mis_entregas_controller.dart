import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/providers.dart';
import '../../../../shared/domain/entities/envio.dart';

const _pageSize = 20;

class MisEntregasState {
  const MisEntregasState({
    required this.entregas,
    required this.hasMore,
    required this.isLoadingMore,
    required this.lastDocument,
  });

  const MisEntregasState.initial()
    : entregas = const [],
      hasMore = true,
      isLoadingMore = false,
      lastDocument = null;

  final List<Envio> entregas;
  final bool hasMore;
  final bool isLoadingMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;

  MisEntregasState copyWith({
    List<Envio>? entregas,
    bool? hasMore,
    bool? isLoadingMore,
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
  }) => MisEntregasState(
    entregas: entregas ?? this.entregas,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    lastDocument: lastDocument ?? this.lastDocument,
  );
}

/// Entregas activas del repartidor autenticado (asignadas o en curso) —
/// mismo patrón de paginación que `MisEnviosController`/`OfertasController`.
/// El filtro de estado se hace aquí, no en la query (ver
/// `EnviosRepository.listarEntregasDeRepartidor`).
class MisEntregasController extends AsyncNotifier<MisEntregasState> {
  @override
  Future<MisEntregasState> build() {
    return _cargarPagina(const MisEntregasState.initial());
  }

  Future<void> refrescar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _cargarPagina(const MisEntregasState.initial()),
    );
  }

  Future<void> cargarMas() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    state = await AsyncValue.guard(() => _cargarPagina(current));
  }

  Future<MisEntregasState> _cargarPagina(MisEntregasState current) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final repository = ref.read(enviosRepositoryProvider);
    final snapshot = await repository.listarEntregasDeRepartidor(
      uid,
      limit: _pageSize,
      startAfter: current.lastDocument,
    );
    final activas = snapshot.docs
        .map(Envio.fromFirestore)
        .where(
          (envio) =>
              envio.status == EnvioStatus.asignado ||
              envio.status == EnvioStatus.enCurso,
        )
        .toList();
    return current.copyWith(
      entregas: [...current.entregas, ...activas],
      hasMore: snapshot.docs.length == _pageSize,
      isLoadingMore: false,
      lastDocument: snapshot.docs.isNotEmpty
          ? snapshot.docs.last
          : current.lastDocument,
    );
  }
}

final misEntregasControllerProvider =
    AsyncNotifierProvider<MisEntregasController, MisEntregasState>(
      MisEntregasController.new,
    );
