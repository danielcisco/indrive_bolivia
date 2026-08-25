import 'package:cloud_firestore/cloud_firestore.dart';

/// Repartidor con KYC pendiente de aprobación (`isVerified == false`).
///
/// Concepto admin-only (no vive en `shared/domain`): solo lo consume la
/// pantalla de Verificación KYC del panel Admin.
class RepartidorKycPendiente {
  const RepartidorKycPendiente({
    required this.uid,
    required this.phoneNumber,
    required this.createdAt,
  });

  factory RepartidorKycPendiente.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return RepartidorKycPendiente(
      uid: doc.id,
      phoneNumber: data['phoneNumber'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  final String uid;
  final String? phoneNumber;
  final Timestamp? createdAt;
}
