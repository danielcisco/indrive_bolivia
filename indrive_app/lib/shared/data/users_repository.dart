import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class UsersRepository {
  UsersRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'southamerica-east1'),
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Guarda la última celda geohash conocida del repartidor — una foto
  /// puntual tomada cuando abre/refresca el Radar, no tracking en vivo
  /// (eso es Fase 4). La usa la Cloud Function `notifyNearbyRepartidores`
  /// para decidir a quién avisar de un envío nuevo cerca.
  Future<void> actualizarUltimaUbicacion(String uid, String geohash) {
    return _users.doc(uid).set({
      'ultimaGeohash': geohash,
      'ultimaUbicacionActualizada': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Repartidores con KYC pendiente (`isVerified == false`), paginado —
  /// alimenta la pantalla de Verificación KYC del panel Admin (Sprint 5.1).
  Future<QuerySnapshot<Map<String, dynamic>>> listarRepartidoresPendientesKyc({
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    var query = _users
        .where('role', isEqualTo: 'repartidor')
        .where('isVerified', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.get();
  }

  /// Aprueba el KYC de [uid] vía la Cloud Function `approveKyc` — el
  /// cliente nunca escribe `isVerified` directamente (ni las Firestore
  /// Rules ni el token se lo permiten), solo un admin autenticado puede
  /// invocar esta función (validado server-side).
  Future<void> aprobarKyc(String uid) async {
    await _functions.httpsCallable('approveKyc').call({'uid': uid});
  }

  /// Sube la foto de la Cédula a `kyc/{uid}/` (regla ya existente desde
  /// antes de este sprint de seguimiento: dueño lee/escribe, admin lee) y
  /// devuelve su URL de descarga. contentType explícito por el mismo
  /// motivo que `EnviosRepository.subirComprobante`: sin esto la
  /// inferencia automática puede no reconocer el archivo de la cámara
  /// como imagen y la regla de Storage lo rechaza sin explicar por qué.
  Future<String> subirFotoCedula({
    required String uid,
    required File archivo,
  }) async {
    final ref = _storage.ref('kyc/$uid/${const Uuid().v4()}.jpg');
    await ref.putFile(archivo, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  /// Guarda la URL ya subida en el documento del usuario. Sin cambios de
  /// Rules: la regla de `users/{uid}` ya permite al dueño escribir campos
  /// nuevos (solo `role`/`isVerified` son inmutables para él).
  Future<void> guardarCedulaUrl(String uid, String url) {
    return _users.doc(uid).set({
      'cedulaUrl': url,
    }, SetOptions(merge: true));
  }

  /// Fetch puntual — decide si `RepartidorHomeScreen` todavía tiene que
  /// mostrar el aviso de "subí tu Cédula".
  Future<String?> obtenerCedulaUrl(String uid) async {
    final snapshot = await _users.doc(uid).get();
    return snapshot.data()?['cedulaUrl'] as String?;
  }

  /// Promedio de calificaciones (0-5, `0` = todavía sin ninguna) — lo
  /// mantiene la Cloud Function `actualizarRatingPromedio`, nunca se
  /// calcula acá recorriendo calificaciones (sprint extra, Grupo B).
  Future<({double promedio, int total})> obtenerMiRating(String uid) async {
    final snapshot = await _users.doc(uid).get();
    final data = snapshot.data();
    return (
      promedio: (data?['ratingPromedio'] as num?)?.toDouble() ?? 0,
      total: data?['totalCalificaciones'] as int? ?? 0,
    );
  }

  /// Todos los usuarios (Cliente + Repartidor mezclados), paginado —
  /// alimenta `GestionUsuariosScreen` del panel Admin (sprint extra,
  /// Grupo C).
  Future<QuerySnapshot<Map<String, dynamic>>> listarUsuarios({
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    var query = _users.orderBy('createdAt', descending: true).limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.get();
  }

  /// Suspende (`activar: false`) o reactiva (`activar: true`) una cuenta
  /// vía la Cloud Function `establecerEstadoCuenta` — el cliente nunca
  /// puede tocar `isActive` directamente (ver `firestore.rules`).
  Future<void> establecerEstadoCuenta(String uid, {required bool activar}) {
    return _functions
        .httpsCallable('establecerEstadoCuenta')
        .call({'uid': uid, 'activar': activar});
  }

  /// Calificaciones recibidas por [uid], sin importar de qué envío
  /// vinieron — collection group query sobre la subcolección
  /// `calificaciones` (vive en `envios/{envioId}/calificaciones/{autorId}`,
  /// ver `Calificacion`), paginada.
  Future<QuerySnapshot<Map<String, dynamic>>> obtenerMisCalificaciones(
    String uid, {
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    var query = _firestore
        .collectionGroup('calificaciones')
        .where('paraId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.get();
  }
}
