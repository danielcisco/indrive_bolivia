import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class UsersRepository {
  UsersRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _functions =
          functions ??
          FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

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
}
