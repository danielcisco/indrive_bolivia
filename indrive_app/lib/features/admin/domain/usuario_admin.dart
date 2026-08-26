import 'package:cloud_firestore/cloud_firestore.dart';

/// Fila de `GestionUsuariosScreen` (sprint extra, Grupo C) — todo lo que
/// vive en `users/{uid}` a esta altura del proyecto. Admin-only, por eso
/// no es una entidad `shared/`.
class UsuarioAdmin {
  const UsuarioAdmin({
    required this.uid,
    required this.phoneNumber,
    required this.role,
    required this.isVerified,
    required this.isActive,
    required this.ratingPromedio,
    required this.totalCalificaciones,
    required this.createdAt,
  });

  factory UsuarioAdmin.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return UsuarioAdmin(
      uid: doc.id,
      phoneNumber: data['phoneNumber'] as String?,
      role: data['role'] as String?,
      isVerified: data['isVerified'] as bool? ?? false,
      // Ausente == nunca suspendida == activa (mismo default que usa la
      // regla de Firestore vía .get('isActive', true)).
      isActive: data['isActive'] as bool? ?? true,
      ratingPromedio: (data['ratingPromedio'] as num?)?.toDouble() ?? 0,
      totalCalificaciones: data['totalCalificaciones'] as int? ?? 0,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  final String uid;
  final String? phoneNumber;
  final String? role;
  final bool isVerified;
  final bool isActive;
  final double ratingPromedio;
  final int totalCalificaciones;
  final Timestamp? createdAt;
}
