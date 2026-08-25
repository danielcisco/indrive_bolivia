import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dart_geohash/dart_geohash.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/location/current_location.dart';
import '../../../../shared/data/providers.dart';
import '../../../../shared/domain/entities/envio.dart';

const _precisionInicial = 6;
const _precisionMinima = 3;
const _minimoResultadosDeseados = 3;
const _pageSize = 20;

/// Secuencia de prefijos de geohash a probar, del más específico (celda
/// chica) al más amplio, sin bajar de [precisionMinima]. Función pura
/// (sin Firestore) — así el "sondeo adaptativo" que pide CLAUDE.md queda
/// testeado sin dispositivo ni emulador.
List<String> prefijosParaSondeoAdaptativo(
  String geohashCompleto, {
  int precisionInicial = _precisionInicial,
  int precisionMinima = _precisionMinima,
}) {
  return [
    for (
      var precision = precisionInicial;
      precision >= precisionMinima;
      precision--
    )
      geohashCompleto.substring(0, precision),
  ];
}

class RadarState {
  const RadarState({
    required this.envios,
    required this.hasMore,
    required this.isLoadingMore,
    required this.lastDocument,
    required this.prefijoUsado,
  });

  const RadarState.initial()
    : envios = const [],
      hasMore = false,
      isLoadingMore = false,
      lastDocument = null,
      prefijoUsado = null;

  final List<Envio> envios;
  final bool hasMore;
  final bool isLoadingMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final String? prefijoUsado;

  RadarState copyWith({
    List<Envio>? envios,
    bool? hasMore,
    bool? isLoadingMore,
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
    String? prefijoUsado,
  }) => RadarState(
    envios: envios ?? this.envios,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    lastDocument: lastDocument ?? this.lastDocument,
    prefijoUsado: prefijoUsado ?? this.prefijoUsado,
  );
}

/// Radar del repartidor: sondeo adaptativo por prefijo de geohash (no un
/// stream continuo — se refresca al entrar y con acción explícita del
/// usuario, tal como exige CLAUDE.md).
class RadarController extends AsyncNotifier<RadarState> {
  final _geoHasher = GeoHasher();

  @override
  Future<RadarState> build() {
    return _buscar();
  }

  Future<void> refrescar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_buscar);
  }

  Future<void> cargarMas() async {
    final current = state.valueOrNull;
    if (current == null ||
        !current.hasMore ||
        current.isLoadingMore ||
        current.prefijoUsado == null) {
      return;
    }
    state = AsyncData(current.copyWith(isLoadingMore: true));
    state = await AsyncValue.guard(() => _siguientePagina(current));
  }

  Future<RadarState> _buscar() async {
    final posicion = await obtenerUbicacionActual();
    final geohashCompleto = _geoHasher.encode(
      posicion.longitude,
      posicion.latitude,
      precision: 9,
    );

    final uid = FirebaseAuth.instance.currentUser!.uid;
    await ref
        .read(usersRepositoryProvider)
        .actualizarUltimaUbicacion(uid, geohashCompleto);

    final repository = ref.read(enviosRepositoryProvider);
    for (final prefijo in prefijosParaSondeoAdaptativo(geohashCompleto)) {
      final snapshot = await repository.buscarEnviosCercanos(
        prefijo,
        limit: _pageSize,
      );
      final alcanzoMinimo = snapshot.docs.length >= _minimoResultadosDeseados;
      final esUltimoIntento = prefijo.length == _precisionMinima;
      if (alcanzoMinimo || esUltimoIntento) {
        final envios = snapshot.docs.map(Envio.fromFirestore).toList();
        return RadarState(
          envios: envios,
          hasMore: envios.length == _pageSize,
          isLoadingMore: false,
          lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
          prefijoUsado: prefijo,
        );
      }
    }
    return const RadarState.initial();
  }

  Future<RadarState> _siguientePagina(RadarState current) async {
    final repository = ref.read(enviosRepositoryProvider);
    final snapshot = await repository.buscarEnviosCercanos(
      current.prefijoUsado!,
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

final radarControllerProvider =
    AsyncNotifierProvider<RadarController, RadarState>(RadarController.new);
