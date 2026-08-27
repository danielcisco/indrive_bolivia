import 'dart:async';

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
const _intervaloSondeo = Duration(seconds: 20);

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
/// stream continuo de Firestore, tal como exige CLAUDE.md) — pero sí
/// automático: se relanza solo cada [_intervaloSondeo] mientras la
/// pantalla está abierta, además de al entrar y con refresco manual. Sin
/// esto, un envío nuevo publicado por el Cliente no aparecía hasta que el
/// repartidor lo pedía a mano. `autoDispose` para que el timer (y el GPS
/// que dispara cada sondeo) se corte solo al salir de la pantalla, no
/// quede sondeando en segundo plano para siempre.
class RadarController extends AsyncNotifier<RadarState> {
  final _geoHasher = GeoHasher();

  @override
  Future<RadarState> build() {
    final timer = Timer.periodic(
      _intervaloSondeo,
      (_) => _actualizarSilenciosamente(),
    );
    ref.onDispose(timer.cancel);
    return _buscar();
  }

  Future<void> refrescar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_buscar);
  }

  /// Igual que [refrescar] pero sin pasar por `AsyncLoading` — evita que
  /// la lista parpadee a una pantalla de carga cada vez que el sondeo
  /// automático corre solo en segundo plano. Si falla, se ignora: la
  /// lista se queda con lo último bueno y se reintenta en el próximo tick.
  Future<void> _actualizarSilenciosamente() async {
    try {
      final nuevo = await _buscar();
      state = AsyncData(nuevo);
    } catch (_) {
      // Falla silenciosa a propósito, ver doc del método — cubre tanto
      // errores de red como el caso raro de que el provider ya se haya
      // descartado justo cuando este tick estaba a mitad de camino
      // (el timer se cancela en `ref.onDispose`, así que no debería
      // volver a dispararse después, pero un tick ya en vuelo sí puede
      // resolver tarde).
    }
  }

  Future<void> cargarMas() async {
    final current = state.value;
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
    AsyncNotifierProvider.autoDispose<RadarController, RadarState>(
      RadarController.new,
    );
