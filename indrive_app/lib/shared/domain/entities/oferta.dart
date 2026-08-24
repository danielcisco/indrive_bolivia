import 'package:cloud_firestore/cloud_firestore.dart';

import '../value_objects/money.dart';

enum OfertaStatus {
  pendiente,
  aceptada,
  rechazada;

  static OfertaStatus fromFirestore(String value) => switch (value) {
    'pendiente' => OfertaStatus.pendiente,
    'aceptada' => OfertaStatus.aceptada,
    'rechazada' => OfertaStatus.rechazada,
    _ => throw ArgumentError('OfertaStatus desconocido: $value'),
  };

  String toFirestore() => switch (this) {
    OfertaStatus.pendiente => 'pendiente',
    OfertaStatus.aceptada => 'aceptada',
    OfertaStatus.rechazada => 'rechazada',
  };
}

/// Contraoferta de un repartidor sobre un [Envio], vive en la subcolección
/// `envios/{envioId}/ofertas` (no en un array dentro del envío, para poder
/// paginar en vez de leer una lista sin cota).
class Oferta {
  const Oferta({
    required this.id,
    required this.envioId,
    required this.repartidorId,
    required this.status,
    required this.monto,
    required this.createdAt,
  });

  factory Oferta.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String envioId,
  }) {
    final data = doc.data()!;
    return Oferta(
      id: doc.id,
      envioId: envioId,
      repartidorId: data['repartidorId'] as String,
      status: OfertaStatus.fromFirestore(data['status'] as String),
      monto: Money.centavos(data['montoOfertadoCentavos'] as int),
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  final String id;
  final String envioId;
  final String repartidorId;
  final OfertaStatus status;
  final Money monto;
  final Timestamp? createdAt;

  static Map<String, dynamic> createData({
    required String repartidorId,
    required Money monto,
  }) => {
    'repartidorId': repartidorId,
    'status': OfertaStatus.pendiente.toFirestore(),
    'montoOfertadoCentavos': monto.centavos,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
