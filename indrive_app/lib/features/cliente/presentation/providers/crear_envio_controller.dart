import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/providers.dart';
import '../../../../shared/domain/value_objects/money.dart';
import 'mis_envios_controller.dart';

/// Publica un envío nuevo. Firestore por sí mismo cachea escrituras
/// offline, pero no da control sobre reintentos/backoff ni un ID
/// determinista — por eso, si no hay conectividad o la escritura directa
/// se cuelga, la acción se delega a [OfflineActionQueue] (Sprint 2.1).
class CrearEnvioController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> crear({
    required String descripcion,
    required GeoPoint origen,
    required GeoPoint destino,
    required Money montoOfertadoInicial,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final repository = ref.read(enviosRepositoryProvider);
    final queue = ref.read(offlineActionQueueProvider);

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final conectividad = await Connectivity().checkConnectivity();
      final hayConexion = conectividad.any(
        (resultado) => resultado != ConnectivityResult.none,
      );

      final payload = {
        'clienteId': uid,
        'descripcion': descripcion,
        'origenLat': origen.latitude,
        'origenLng': origen.longitude,
        'destinoLat': destino.latitude,
        'destinoLng': destino.longitude,
        'montoCentavos': montoOfertadoInicial.centavos,
      };

      if (!hayConexion) {
        await queue.enqueue(type: 'crear_envio', payload: payload);
        return;
      }

      try {
        await repository
            .crearEnvio(
              clienteId: uid,
              descripcion: descripcion,
              origen: origen,
              destino: destino,
              montoOfertadoInicial: montoOfertadoInicial,
            )
            .timeout(const Duration(seconds: 10));
        ref.invalidate(misEnviosControllerProvider);
      } on TimeoutException {
        await queue.enqueue(type: 'crear_envio', payload: payload);
      }
    });
  }
}

final crearEnvioControllerProvider =
    AsyncNotifierProvider<CrearEnvioController, void>(
      CrearEnvioController.new,
    );
