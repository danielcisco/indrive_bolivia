import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../../core/auth/token_retry.dart';
import '../domain/entities/perfil_publico.dart';

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

  CollectionReference<Map<String, dynamic>> get _perfilesPublicos =>
      _firestore.collection('perfiles_publicos');

  /// Escribe [campos] en `users/{uid}` Y en `perfiles_publicos/{uid}` a la
  /// vez, en un solo batch atómico — evita que las dos copias del perfil
  /// (privada y pública) queden desincronizadas si una escritura falla y
  /// la otra no. Solo debe usarse con campos que además sean públicos
  /// (nombre, nick, avatarId) — la regla de `perfiles_publicos/{uid}`
  /// rechaza cualquier otro campo.
  Future<void> _guardarPerfil(String uid, Map<String, dynamic> campos) {
    final batch = _firestore.batch();
    batch.set(_users.doc(uid), campos, SetOptions(merge: true));
    batch.set(_perfilesPublicos.doc(uid), campos, SetOptions(merge: true));
    return batch.commit();
  }

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

  /// Prende/apaga la disponibilidad del repartidor para recibir ofertas
  /// (Sprint 8.4) — ausente en `users/{uid}` se interpreta como disponible
  /// (compatibilidad con cuentas existentes, sin backfill; ver
  /// `notifyNearbyRepartidores` en Cloud Functions, que filtra por esto).
  Future<void> actualizarDisponibilidad(String uid, bool disponible) {
    return _users.doc(uid).set({
      'disponible': disponible,
    }, SetOptions(merge: true));
  }

  /// Fetch puntual — `true` (disponible) si el campo todavía no existe.
  Future<bool> obtenerDisponibilidad(String uid) async {
    final snapshot = await _users.doc(uid).get();
    return snapshot.data()?['disponible'] as bool? ?? true;
  }

  /// Clientes y repartidores con KYC pendiente (`isVerified == false`),
  /// paginado — alimenta la pantalla de Verificación de identidad del
  /// panel Admin (Sprint 5.1; ampliado a Cliente en el Sprint 10 — antes
  /// solo mostraba repartidores, dejando pasar cuentas Cliente sin
  /// revisión). `whereIn` con los 2 roles usa el mismo índice compuesto
  /// que ya existía para `role == 'repartidor'`.
  Future<QuerySnapshot<Map<String, dynamic>>> listarUsuariosPendientesKyc({
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    var query = _users
        .where('role', whereIn: ['cliente', 'repartidor'])
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
  Future<void> aprobarKyc(String uid) {
    return conReintentoDeToken(
      () => _functions.httpsCallable('approveKyc').call({'uid': uid}),
    );
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

  /// Guarda el avatar elegido (uno de `kAvatares`, ver
  /// `lib/shared/domain/avatares.dart`) — en `users/{uid}` y su copia
  /// pública a la vez, ver `_guardarPerfil`.
  Future<void> actualizarAvatar(String uid, String avatarId) {
    return _guardarPerfil(uid, {'avatarId': avatarId});
  }

  /// Guarda nombre, apellido y nick (registro en 4 pasos) — mismo criterio
  /// que `actualizarAvatar`.
  Future<void> actualizarPerfil(
    String uid, {
    required String nombre,
    required String apellido,
    required String nick,
  }) {
    return _guardarPerfil(uid, {
      'nombre': nombre,
      'apellido': apellido,
      'nick': nick,
    });
  }

  /// Fetch puntual del propio perfil (privado, `users/{uid}`) — decide si
  /// `AuthGate` todavía tiene que mostrar `CompletarPerfilScreen`, y
  /// alimenta el header con nombre/nick/avatar.
  Future<PerfilPublico?> obtenerMiPerfil(String uid) async {
    final snapshot = await _users.doc(uid).get();
    final data = snapshot.data();
    if (data == null) return null;
    return PerfilPublico.fromMap(data);
  }

  /// Perfil público de OTRO usuario (`perfiles_publicos/{uid}`) — usado en
  /// el detalle de un envío para mostrar quién es la contraparte
  /// (Cliente↔Repartidor).
  Future<PerfilPublico?> obtenerPerfilPublico(String uid) async {
    final snapshot = await _perfilesPublicos.doc(uid).get();
    final data = snapshot.data();
    if (data == null) return null;
    return PerfilPublico.fromMap(data);
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

  /// Usuarios de un rol y estado de verificación específicos, paginado —
  /// alimenta las 4 secciones separadas (Cliente/Repartidor × Verificado/
  /// No verificado) de `GestionUsuariosScreen` (Sprint 11 — antes era una
  /// sola lista mezclada, difícil de escanear a simple vista). Mismo
  /// índice compuesto que ya usa `listarUsuariosPendientesKyc`
  /// (`role`+`isVerified`+`createdAt`).
  Future<QuerySnapshot<Map<String, dynamic>>> listarUsuariosPorRolYEstado({
    required String role,
    required bool verificado,
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    var query = _users
        .where('role', isEqualTo: role)
        .where('isVerified', isEqualTo: verificado)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.get();
  }

  /// Suspende (`activar: false`) o reactiva (`activar: true`) una cuenta
  /// vía la Cloud Function `establecerEstadoCuenta` — el cliente nunca
  /// puede tocar `isActive` directamente (ver `firestore.rules`).
  Future<void> establecerEstadoCuenta(String uid, {required bool activar}) {
    return conReintentoDeToken(
      () => _functions
          .httpsCallable('establecerEstadoCuenta')
          .call({'uid': uid, 'activar': activar}),
    );
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
