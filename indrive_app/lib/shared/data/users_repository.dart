import 'package:cloud_firestore/cloud_firestore.dart';

class UsersRepository {
  UsersRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Guarda la última celda geohash conocida del repartidor — una foto
  /// puntual tomada cuando abre/refresca el Radar, no tracking en vivo
  /// (eso es Fase 4). La usa la Cloud Function `notifyNearbyRepartidores`
  /// para decidir a quién avisar de un envío nuevo cerca.
  Future<void> actualizarUltimaUbicacion(String uid, String geohash) {
    return _firestore.collection('users').doc(uid).set({
      'ultimaGeohash': geohash,
      'ultimaUbicacionActualizada': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
