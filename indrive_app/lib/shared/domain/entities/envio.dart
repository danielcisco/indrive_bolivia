import 'package:cloud_firestore/cloud_firestore.dart';

import '../value_objects/money.dart';

enum EnvioStatus {
  pendienteOfertas,
  asignado,
  enCurso,
  entregado,
  cancelado;

  static EnvioStatus fromFirestore(String value) => switch (value) {
    'pendiente_ofertas' => EnvioStatus.pendienteOfertas,
    'asignado' => EnvioStatus.asignado,
    'en_curso' => EnvioStatus.enCurso,
    'entregado' => EnvioStatus.entregado,
    'cancelado' => EnvioStatus.cancelado,
    _ => throw ArgumentError('EnvioStatus desconocido: $value'),
  };

  String toFirestore() => switch (this) {
    EnvioStatus.pendienteOfertas => 'pendiente_ofertas',
    EnvioStatus.asignado => 'asignado',
    EnvioStatus.enCurso => 'en_curso',
    EnvioStatus.entregado => 'entregado',
    EnvioStatus.cancelado => 'cancelado',
  };
}

enum MetodoPago {
  efectivo,
  qr;

  static MetodoPago fromFirestore(String value) => switch (value) {
    'efectivo' => MetodoPago.efectivo,
    'qr' => MetodoPago.qr,
    _ => throw ArgumentError('MetodoPago desconocido: $value'),
  };

  String toFirestore() => switch (this) {
    MetodoPago.efectivo => 'efectivo',
    MetodoPago.qr => 'qr',
  };
}

/// Entidad de dominio para un envío/subasta.
///
/// El mapeo a/desde Firestore vive en la propia entidad (no hay un DTO
/// separado): con una sola fuente de datos, mantener dos clases espejo
/// sería ceremonia sin beneficio real todavía.
class Envio {
  const Envio({
    required this.id,
    required this.clienteId,
    required this.status,
    required this.descripcion,
    required this.origen,
    required this.origenGeohash,
    required this.destino,
    required this.montoOfertadoInicial,
    required this.repartidorAsignadoId,
    required this.ofertaAceptadaId,
    required this.createdAt,
    required this.expiraEn,
    required this.repartidorPosicionActual,
    required this.repartidorPosicionActualizada,
    required this.metodoPago,
    required this.comprobanteUrl,
    required this.pagoVerificado,
  });

  factory Envio.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Envio(
      id: doc.id,
      clienteId: data['clienteId'] as String,
      status: EnvioStatus.fromFirestore(data['status'] as String),
      descripcion: data['descripcion'] as String,
      origen: data['origen'] as GeoPoint,
      origenGeohash: data['origenGeohash'] as String,
      destino: data['destino'] as GeoPoint,
      montoOfertadoInicial: Money.centavos(
        data['montoOfertadoInicialCentavos'] as int,
      ),
      repartidorAsignadoId: data['repartidorAsignadoId'] as String?,
      ofertaAceptadaId: data['ofertaAceptadaId'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      expiraEn: data['expiraEn'] as Timestamp?,
      repartidorPosicionActual: data['repartidorPosicionActual'] as GeoPoint?,
      repartidorPosicionActualizada:
          data['repartidorPosicionActualizada'] as Timestamp?,
      metodoPago: data['metodoPago'] != null
          ? MetodoPago.fromFirestore(data['metodoPago'] as String)
          : null,
      comprobanteUrl: data['comprobanteUrl'] as String?,
      pagoVerificado: data['pagoVerificado'] as bool? ?? false,
    );
  }

  final String id;
  final String clienteId;
  final EnvioStatus status;
  final String descripcion;
  final GeoPoint origen;
  final String origenGeohash;
  final GeoPoint destino;
  final Money montoOfertadoInicial;
  final String? repartidorAsignadoId;

  /// Se fija junto con [repartidorAsignadoId] cuando el cliente elige una
  /// propuesta específica (`EnviosRepository.aceptarOferta`) — queda null
  /// si en cambio un repartidor tomó el envío directo.
  final String? ofertaAceptadaId;

  /// Null hasta que el servidor confirma el `serverTimestamp()` del create.
  final Timestamp? createdAt;

  /// Fijado exclusivamente por la Cloud Function `setEnvioExpiration` — el
  /// cliente nunca escribe este campo (regla no negociable: nunca
  /// `DateTime.now()` del cliente para vencimientos).
  final Timestamp? expiraEn;

  /// Última posición reportada por el repartidor mientras el envío está
  /// `en_curso` (Sprint 4.1b) — null antes de que arranque el viaje.
  final GeoPoint? repartidorPosicionActual;
  final Timestamp? repartidorPosicionActualizada;

  /// Fijados por el repartidor junto con la transición a `entregado`
  /// (Sprint 6.1) — null hasta ese momento.
  final MetodoPago? metodoPago;

  /// Solo presente si [metodoPago] es [MetodoPago.qr].
  final String? comprobanteUrl;

  /// Solo lo escribe un Admin, revisando [comprobanteUrl] — un pago en
  /// efectivo no pasa por esta verificación (no tiene sentido para él).
  final bool pagoVerificado;

  /// Datos para `collection('envios').add(...)` al crear. No incluye
  /// `expiraEn` (lo fija la Cloud Function) ni `repartidorAsignadoId`
  /// (empieza null).
  static Map<String, dynamic> createData({
    required String clienteId,
    required String descripcion,
    required GeoPoint origen,
    required String origenGeohash,
    required GeoPoint destino,
    required Money montoOfertadoInicial,
  }) => {
    'clienteId': clienteId,
    'status': EnvioStatus.pendienteOfertas.toFirestore(),
    'descripcion': descripcion,
    'origen': origen,
    'origenGeohash': origenGeohash,
    'destino': destino,
    'montoOfertadoInicialCentavos': montoOfertadoInicial.centavos,
    'repartidorAsignadoId': null,
    'ofertaAceptadaId': null,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
