import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/providers.dart';
import '../../domain/usuario_kyc_pendiente.dart';

const _pageSize = 20;

class KycPendingState {
  const KycPendingState({
    required this.usuarios,
    required this.hasMore,
    required this.isLoadingMore,
    required this.lastDocument,
    required this.aprobando,
  });

  const KycPendingState.initial()
    : usuarios = const [],
      hasMore = true,
      isLoadingMore = false,
      lastDocument = null,
      aprobando = const {};

  final List<UsuarioKycPendiente> usuarios;
  final bool hasMore;
  final bool isLoadingMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;

  /// uids con una aprobación en vuelo — evita doble-tap en esa fila
  /// específica sin bloquear el resto de la lista.
  final Set<String> aprobando;

  KycPendingState copyWith({
    List<UsuarioKycPendiente>? usuarios,
    bool? hasMore,
    bool? isLoadingMore,
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
    Set<String>? aprobando,
  }) => KycPendingState(
    usuarios: usuarios ?? this.usuarios,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    lastDocument: lastDocument ?? this.lastDocument,
    aprobando: aprobando ?? this.aprobando,
  );
}

/// Lista paginada de usuarios con KYC pendiente (Sprint 5.1). Mismo
/// esqueleto que `MisEnviosController`/`RadarController`: nunca una query
/// sin cota.
class KycPendingController extends AsyncNotifier<KycPendingState> {
  @override
  Future<KycPendingState> build() {
    return _cargarPagina(const KycPendingState.initial());
  }

  Future<void> cargarMas() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    state = await AsyncValue.guard(() => _cargarPagina(current));
  }

  Future<void> aprobar(String uid) async {
    final current = state.value;
    if (current == null || current.aprobando.contains(uid)) return;

    state = AsyncData(
      current.copyWith(aprobando: {...current.aprobando, uid}),
    );
    try {
      await ref.read(usersRepositoryProvider).aprobarKyc(uid);
      final sinAprobado = current.usuarios
          .where((repartidor) => repartidor.uid != uid)
          .toList();
      state = AsyncData(
        current.copyWith(
          usuarios: sinAprobado,
          aprobando: {...current.aprobando}..remove(uid),
        ),
      );
    } catch (_) {
      state = AsyncData(
        current.copyWith(aprobando: {...current.aprobando}..remove(uid)),
      );
      rethrow;
    }
  }

  Future<KycPendingState> _cargarPagina(KycPendingState current) async {
    final repository = ref.read(usersRepositoryProvider);
    final snapshot = await repository.listarUsuariosPendientesKyc(
      limit: _pageSize,
      startAfter: current.lastDocument,
    );
    final nuevos = snapshot.docs
        .map(UsuarioKycPendiente.fromFirestore)
        .toList();
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

final kycPendingControllerProvider =
    AsyncNotifierProvider<KycPendingController, KycPendingState>(
      KycPendingController.new,
    );
