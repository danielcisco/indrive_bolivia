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
    required this.filtro,
  });

  const MisEntregasState.initial({this.filtro})
    : entregas = const [],
      hasMore = true,
      isLoadingMore = false,
      lastDocument = null;

  final List<Envio> entregas;
  final bool hasMore;
  final bool isLoadingMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final EnvioStatus? filtro;

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
    filtro: filtro,
  );
}

/// Entregas del repartidor autenticado, paginadas y filtrables por estado
/// (asignado/en_curso/entregado — `null` = todas) — el filtro se aplica en
/// la query de Firestore (`EnviosRepository.listarEntregasDeRepartidor`),
/// no en memoria como antes: filtrar después de paginar cortaba la
/// paginación antes de tiempo porque `hasMore` se calculaba sobre el total
/// sin filtrar.
class MisEntregasController extends AsyncNotifier<MisEntregasState> {
  @override
  Future<MisEntregasState> build() {
    return _cargarPagina(const MisEntregasState.initial());
  }

  Future<void> refrescar() async {
    final filtroActual = state.valueOrNull?.filtro;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _cargarPagina(MisEntregasState.initial(filtro: filtroActual)),
    );
  }

  Future<void> cambiarFiltro(EnvioStatus? filtro) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _cargarPagina(MisEntregasState.initial(filtro: filtro)),
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
      status: current.filtro,
    );
    final nuevas = snapshot.docs.map(Envio.fromFirestore).toList();
    return current.copyWith(
      entregas: [...current.entregas, ...nuevas],
      hasMore: nuevas.length == _pageSize,
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
