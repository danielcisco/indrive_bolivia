import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/data/providers.dart';
import '../../../../shared/domain/entities/envio.dart';
import '../../../../shared/domain/value_objects/money.dart';
import 'mis_envios_controller.dart';

/// Publica un envío nuevo. Firestore por sí mismo cachea escrituras
/// offline, pero no da control sobre reintentos/backoff ni un ID
/// determinista — por eso, si no hay conectividad o la escritura directa
/// se cuelga, la acción se delega a [OfflineActionQueue] (Sprint 2.1).
class CrearEnvioController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Devuelve el id del envío nuevo si se escribió directo a Firestore, o
  /// `null` si se encoló offline (ahí todavía no existe ningún documento
  /// al que navegar — `CrearEnvioScreen` se queda en la lista en ese caso).
  ///
  /// [foto] es opcional y solo se sube si hay conexión — encolar un
  /// archivo para subir después es un mecanismo aparte que no se
  /// construye acá; sin conexión, el envío se publica sin foto.
  Future<String?> crear({
    required String descripcion,
    required GeoPoint origen,
    required GeoPoint destino,
    required Money montoOfertadoInicial,
    required CategoriaPaquete categoria,
    bool esFragil = false,
    File? foto,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final repository = ref.read(enviosRepositoryProvider);
    final queue = ref.read(offlineActionQueueProvider);
    // Generado acá (no dentro del repositorio) porque, si hay foto, hace
    // falta el id del envío ANTES de crear el documento para poder subirla
    // a `paquetes/{envioId}/...` — mismo id se usa para ambos.
    final id = const Uuid().v4();

    String? idCreado;
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
        'categoria': categoria.toFirestore(),
        'esFragil': esFragil,
      };

      if (!hayConexion) {
        await queue.enqueue(type: 'crear_envio', payload: payload);
        return;
      }

      try {
        String? fotoPaqueteUrl;
        if (foto != null) {
          fotoPaqueteUrl = await repository.subirFotoPaquete(
            envioId: id,
            clienteId: uid,
            archivo: foto,
          );
        }
        await repository
            .crearEnvioConId(
              id,
              clienteId: uid,
              descripcion: descripcion,
              origen: origen,
              destino: destino,
              montoOfertadoInicial: montoOfertadoInicial,
              categoria: categoria,
              fotoPaqueteUrl: fotoPaqueteUrl,
              esFragil: esFragil,
            )
            .timeout(const Duration(seconds: 10));
        idCreado = id;
        ref.invalidate(misEnviosControllerProvider);
      } on TimeoutException {
        await queue.enqueue(type: 'crear_envio', payload: payload);
      }
    });
    return idCreado;
  }
}

final crearEnvioControllerProvider =
    AsyncNotifierProvider<CrearEnvioController, void>(
      CrearEnvioController.new,
    );
