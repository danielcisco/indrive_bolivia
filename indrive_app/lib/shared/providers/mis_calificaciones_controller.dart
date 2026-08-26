import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../domain/entities/calificacion.dart';

const _pageSize = 20;

class MisCalificacionesState {
  const MisCalificacionesState({
    required this.calificaciones,
    required this.hasMore,
    required this.isLoadingMore,
    required this.lastDocument,
  });

  const MisCalificacionesState.initial()
    : calificaciones = const [],
      hasMore = true,
      isLoadingMore = false,
      lastDocument = null;

  final List<Calificacion> calificaciones;
  final bool hasMore;
  final bool isLoadingMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;

  MisCalificacionesState copyWith({
    List<Calificacion>? calificaciones,
    bool? hasMore,
    bool? isLoadingMore,
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
  }) => MisCalificacionesState(
    calificaciones: calificaciones ?? this.calificaciones,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    lastDocument: lastDocument ?? this.lastDocument,
  );
}

/// Calificaciones recibidas por el usuario autenticado, paginadas —
/// compartido por Cliente y Repartidor (sprint extra, Grupo B). Mismo
/// esqueleto que `KycPendingController`/`PagosPendientesController`, pero
/// vive en `shared/` porque no es lógica de un rol específico.
class MisCalificacionesController
    extends AsyncNotifier<MisCalificacionesState> {
  @override
  Future<MisCalificacionesState> build() {
    return _cargarPagina(const MisCalificacionesState.initial());
  }

  Future<void> cargarMas() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    state = await AsyncValue.guard(() => _cargarPagina(current));
  }

  Future<MisCalificacionesState> _cargarPagina(
    MisCalificacionesState current,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final repository = ref.read(usersRepositoryProvider);
    final snapshot = await repository.obtenerMisCalificaciones(
      uid,
      limit: _pageSize,
      startAfter: current.lastDocument,
    );
    final nuevas = snapshot.docs
        .map(
          (doc) => Calificacion.fromFirestore(
            doc,
            // Collection group: el envío dueño de esta calificación es el
            // padre del padre (envios/{envioId}/calificaciones/{autorId}).
            envioId: doc.reference.parent.parent!.id,
          ),
        )
        .toList();
    return current.copyWith(
      calificaciones: [...current.calificaciones, ...nuevas],
      hasMore: nuevas.length == _pageSize,
      isLoadingMore: false,
      lastDocument: snapshot.docs.isNotEmpty
          ? snapshot.docs.last
          : current.lastDocument,
    );
  }
}

final misCalificacionesControllerProvider =
    AsyncNotifierProvider<MisCalificacionesController, MisCalificacionesState>(
      MisCalificacionesController.new,
    );
