import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/providers.dart';
import '../../../../shared/domain/entities/envio.dart';

const _pageSize = 20;

class PagosPendientesState {
  const PagosPendientesState({
    required this.envios,
    required this.hasMore,
    required this.isLoadingMore,
    required this.lastDocument,
    required this.verificando,
  });

  const PagosPendientesState.initial()
    : envios = const [],
      hasMore = true,
      isLoadingMore = false,
      lastDocument = null,
      verificando = const {};

  final List<Envio> envios;
  final bool hasMore;
  final bool isLoadingMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;

  /// IDs de envío con una verificación en vuelo — evita doble-tap en esa
  /// fila específica, mismo patrón que `KycPendingState.aprobando`.
  final Set<String> verificando;

  PagosPendientesState copyWith({
    List<Envio>? envios,
    bool? hasMore,
    bool? isLoadingMore,
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
    Set<String>? verificando,
  }) => PagosPendientesState(
    envios: envios ?? this.envios,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    lastDocument: lastDocument ?? this.lastDocument,
    verificando: verificando ?? this.verificando,
  );
}

/// Lista paginada de envíos entregados con pago QR sin verificar todavía
/// (Sprint 6.1) — mismo esqueleto que `KycPendingController`.
class PagosPendientesController extends AsyncNotifier<PagosPendientesState> {
  @override
  Future<PagosPendientesState> build() {
    return _cargarPagina(const PagosPendientesState.initial());
  }

  Future<void> cargarMas() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    state = await AsyncValue.guard(() => _cargarPagina(current));
  }

  Future<void> verificar(String envioId) async {
    final current = state.valueOrNull;
    if (current == null || current.verificando.contains(envioId)) return;

    state = AsyncData(
      current.copyWith(verificando: {...current.verificando, envioId}),
    );
    try {
      await ref.read(enviosRepositoryProvider).verificarPago(envioId);
      final sinVerificado = current.envios
          .where((envio) => envio.id != envioId)
          .toList();
      state = AsyncData(
        current.copyWith(
          envios: sinVerificado,
          verificando: {...current.verificando}..remove(envioId),
        ),
      );
    } catch (_) {
      state = AsyncData(
        current.copyWith(
          verificando: {...current.verificando}..remove(envioId),
        ),
      );
      rethrow;
    }
  }

  Future<PagosPendientesState> _cargarPagina(
    PagosPendientesState current,
  ) async {
    final repository = ref.read(enviosRepositoryProvider);
    final snapshot = await repository.listarPagosQrPendientes(
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

final pagosPendientesControllerProvider =
    AsyncNotifierProvider<PagosPendientesController, PagosPendientesState>(
      PagosPendientesController.new,
    );
