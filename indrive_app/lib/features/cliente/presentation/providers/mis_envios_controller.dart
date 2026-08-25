import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/providers.dart';
import '../../../../shared/domain/entities/envio.dart';

const _pageSize = 20;

class MisEnviosState {
  const MisEnviosState({
    required this.envios,
    required this.hasMore,
    required this.isLoadingMore,
    required this.lastDocument,
  });

  const MisEnviosState.initial()
    : envios = const [],
      hasMore = true,
      isLoadingMore = false,
      lastDocument = null;

  final List<Envio> envios;
  final bool hasMore;
  final bool isLoadingMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;

  MisEnviosState copyWith({
    List<Envio>? envios,
    bool? hasMore,
    bool? isLoadingMore,
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
  }) => MisEnviosState(
    envios: envios ?? this.envios,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    lastDocument: lastDocument ?? this.lastDocument,
  );
}

/// Lista paginada de los envíos del cliente autenticado. `cargarMas()` pide
/// la siguiente página — nunca una query sin cota (regla no negociable de
/// CLAUDE.md).
class MisEnviosController extends AsyncNotifier<MisEnviosState> {
  @override
  Future<MisEnviosState> build() {
    return _cargarPagina(const MisEnviosState.initial());
  }

  Future<void> cargarMas() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    state = await AsyncValue.guard(() => _cargarPagina(current));
  }

  Future<MisEnviosState> _cargarPagina(MisEnviosState current) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final repository = ref.read(enviosRepositoryProvider);
    final snapshot = await repository.listarEnviosDeCliente(
      uid,
      limit: _pageSize,
      startAfter: current.lastDocument,
    );
    final nuevos = snapshot.docs.map(Envio.fromFirestore).toList();
    return current.copyWith(
      envios: [...current.envios, ...nuevos],
      hasMore: nuevos.length == _pageSize,
      isLoadingMore: false,
      lastDocument: snapshot.docs.isNotEmpty
          ? snapshot.docs.last
          : current.lastDocument,
    );
  }
}

final misEnviosControllerProvider =
    AsyncNotifierProvider<MisEnviosController, MisEnviosState>(
      MisEnviosController.new,
    );
