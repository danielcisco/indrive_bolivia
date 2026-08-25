import 'package:cloud_firestore/cloud_firestore.dart';

/// Calificación cruzada entre Cliente y Repartidor tras una entrega
/// (Sprint 6.1). Vive en `envios/{envioId}/calificaciones/{autorId}` — el
/// UID del autor como ID de documento evita que la misma persona pueda
/// calificar dos veces el mismo envío (un segundo intento es "update", no
/// "create", y las Rules no permiten update sobre esta subcolección).
class Calificacion {
  const Calificacion({
    required this.envioId,
    required this.autorId,
    required this.paraId,
    required this.estrellas,
    required this.comentario,
    required this.createdAt,
  });

  factory Calificacion.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String envioId,
  }) {
    final data = doc.data()!;
    return Calificacion(
      envioId: envioId,
      autorId: data['autorId'] as String,
      paraId: data['paraId'] as String,
      estrellas: data['estrellas'] as int,
      comentario: data['comentario'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  final String envioId;
  final String autorId;
  final String paraId;
  final int estrellas;
  final String? comentario;
  final Timestamp? createdAt;

  static Map<String, dynamic> createData({
    required String autorId,
    required String paraId,
    required int estrellas,
    String? comentario,
  }) => {
    'autorId': autorId,
    'paraId': paraId,
    'estrellas': estrellas,
    'comentario': comentario,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
