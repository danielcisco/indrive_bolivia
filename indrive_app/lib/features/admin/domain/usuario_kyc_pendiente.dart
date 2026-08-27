import 'package:cloud_firestore/cloud_firestore.dart';

/// Cliente o Repartidor con KYC pendiente de aprobación
/// (`isVerified == false`) — antes del Sprint 10 esta lista solo incluía
/// repartidores; ahora cubre ambos roles para que nadie pueda usar el
/// sistema (ni publicar envíos ni aceptarlos) sin haber sido revisado.
///
/// Concepto admin-only (no vive en `shared/domain`): solo lo consume la
/// pantalla de Verificación de identidad del panel Admin.
class UsuarioKycPendiente {
  const UsuarioKycPendiente({
    required this.uid,
    required this.role,
    required this.phoneNumber,
    required this.createdAt,
    required this.cedulaUrl,
  });

  factory UsuarioKycPendiente.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return UsuarioKycPendiente(
      uid: doc.id,
      role: data['role'] as String? ?? 'sin rol',
      phoneNumber: data['phoneNumber'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      cedulaUrl: data['cedulaUrl'] as String?,
    );
  }

  final String uid;

  /// 'cliente' o 'repartidor' — para que el Admin sepa a quién está
  /// aprobando (la tarjeta ya no dice "repartidor" para todos).
  final String role;
  final String? phoneNumber;
  final Timestamp? createdAt;

  /// Foto subida por el usuario (diferido de KYC, seguimiento del Sprint
  /// 5.1) — null si todavía no subió nada.
  final String? cedulaUrl;
}
