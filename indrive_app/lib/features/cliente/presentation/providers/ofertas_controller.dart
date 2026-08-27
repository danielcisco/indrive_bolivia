import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/providers.dart';
import '../../../../shared/domain/entities/oferta.dart';

const _pageSize = 20;

class OfertasState {
  const OfertasState({
    required this.ofertas,
    required this.hasMore,
    required this.isLoadingMore,
    required this.lastDocument,
  });

  const OfertasState.initial()
    : ofertas = const [],
      hasMore = true,
      isLoadingMore = false,
      lastDocument = null;

  final List<Oferta> ofertas;
  final bool hasMore;
  final bool isLoadingMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;

  OfertasState copyWith({
    List<Oferta>? ofertas,
    bool? hasMore,
    bool? isLoadingMore,
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
  }) => OfertasState(
    ofertas: ofertas ?? this.ofertas,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    lastDocument: lastDocument ?? this.lastDocument,
  );
}

/// Lista paginada de propuestas de un envío. Mismo patrón que
/// [MisEnviosController] — reutilizado, no reimplementado.
///
/// `FamilyAsyncNotifier` no existe en Riverpod 3 — el argumento de familia
/// ahora se recibe por constructor (Riverpod llama `OfertasController.new`
/// con el envioId), no por parámetro de `build()`.
class OfertasController extends AsyncNotifier<OfertasState> {
  OfertasController(this._envioId);

  final String _envioId;

  @override
  Future<OfertasState> build() {
    return _cargarPagina(const OfertasState.initial());
  }

  Future<void> cargarMas() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    state = await AsyncValue.guard(() => _cargarPagina(current));
  }

  Future<void> refrescar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _cargarPagina(const OfertasState.initial()),
    );
  }

  Future<OfertasState> _cargarPagina(OfertasState current) async {
    final repository = ref.read(enviosRepositoryProvider);
    final snapshot = await repository.listarOfertas(
      _envioId,
      limit: _pageSize,
      startAfter: current.lastDocument,
    );
    final nuevas = snapshot.docs
        .map((doc) => Oferta.fromFirestore(doc, envioId: _envioId))
        .toList();
    return current.copyWith(
      ofertas: [...current.ofertas, ...nuevas],
      hasMore: nuevas.length == _pageSize,
      isLoadingMore: false,
      lastDocument: snapshot.docs.isNotEmpty
          ? snapshot.docs.last
          : current.lastDocument,
    );
  }
}

final ofertasControllerProvider =
    AsyncNotifierProvider.family<OfertasController, OfertasState, String>(
      OfertasController.new,
    );
