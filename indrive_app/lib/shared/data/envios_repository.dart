import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dart_geohash/dart_geohash.dart';

import '../domain/entities/envio.dart';
import '../domain/entities/oferta.dart';
import '../domain/value_objects/money.dart';

/// Tolerancia de gracia tras `expiraEn` para ofertas encoladas offline que
/// sincronizan poco después del cierre nominal de la subasta (regla no
/// negociable de CLAUDE.md: "tolerancia de gracia para cola offline").
const Duration ofertaGraceTolerance = Duration(minutes: 2);

class EnviosRepository {
  EnviosRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _geoHasher = GeoHasher();

  final FirebaseFirestore _firestore;
  final GeoHasher _geoHasher;

  CollectionReference<Map<String, dynamic>> get _envios =>
      _firestore.collection('envios');

  /// Crea un envío con un ID nuevo. `expiraEn` NO se fija aquí: lo calcula
  /// server-side la Cloud Function `setEnvioExpiration` a partir de
  /// `createdAt`.
  Future<String> crearEnvio({
    required String clienteId,
    required String descripcion,
    required GeoPoint origen,
    required GeoPoint destino,
    required Money montoOfertadoInicial,
  }) async {
    final ref = _envios.doc();
    await crearEnvioConId(
      ref.id,
      clienteId: clienteId,
      descripcion: descripcion,
      origen: origen,
      destino: destino,
      montoOfertadoInicial: montoOfertadoInicial,
    );
    return ref.id;
  }

  /// Igual que [crearEnvio] pero con un ID fijado por el llamador — usado
  /// por la cola offline (`OfflineActionQueue`), que pasa el UUIDv4 de la
  /// acción como `id`. Al usar `.set()` en vez de `.add()`, reintentar tras
  /// un fallo de red sobreescribe el mismo documento en vez de duplicarlo.
  Future<void> crearEnvioConId(
    String id, {
    required String clienteId,
    required String descripcion,
    required GeoPoint origen,
    required GeoPoint destino,
    required Money montoOfertadoInicial,
  }) {
    final origenGeohash = _geoHasher.encode(
      origen.longitude,
      origen.latitude,
      precision: 9,
    );
    return _envios.doc(id).set(
      Envio.createData(
        clienteId: clienteId,
        descripcion: descripcion,
        origen: origen,
        origenGeohash: origenGeohash,
        destino: destino,
        montoOfertadoInicial: montoOfertadoInicial,
      ),
    );
  }

  /// Fetch puntual de un envío por id (no es un stream: Sprint 3.1 no
  /// requiere tiempo real, eso llega con FCM en Fase 3.2/4.1).
  Future<Envio?> obtenerEnvio(String id) async {
    final snapshot = await _envios.doc(id).get();
    if (!snapshot.exists) return null;
    return Envio.fromFirestore(snapshot);
  }

  /// Envíos abiertos a ofertas, paginado (nunca una query sin cota).
  Future<QuerySnapshot<Map<String, dynamic>>> listarEnviosPendientes({
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    var query = _envios
        .where('status', isEqualTo: EnvioStatus.pendienteOfertas.toFirestore())
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.get();
  }

  /// Envíos pendientes cuyo `origenGeohash` cae dentro del rango de
  /// [prefix] (radar del Repartidor) — paginado. `RadarController` decide
  /// qué tan largo hacer `prefix` (sondeo adaptativo: celda más chica o
  /// más grande según cuántos resultados haya).
  Future<QuerySnapshot<Map<String, dynamic>>> buscarEnviosCercanos(
    String prefix, {
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    var query = _envios
        .where('status', isEqualTo: EnvioStatus.pendienteOfertas.toFirestore())
        .where('origenGeohash', isGreaterThanOrEqualTo: prefix)
        .where('origenGeohash', isLessThan: '$prefix~')
        .orderBy('origenGeohash')
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.get();
  }

  /// Envíos del cliente [clienteId], paginado.
  Future<QuerySnapshot<Map<String, dynamic>>> listarEnviosDeCliente(
    String clienteId, {
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    var query = _envios
        .where('clienteId', isEqualTo: clienteId)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.get();
  }

  /// Ofertas de un envío, paginado.
  Future<QuerySnapshot<Map<String, dynamic>>> listarOfertas(
    String envioId, {
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    var query = _envios
        .doc(envioId)
        .collection('ofertas')
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.get();
  }

  /// Envía una contraoferta. Rechaza localmente si el envío ya venció más
  /// allá de la tolerancia de gracia — evita una escritura que las rules
  /// rechazarían de todas formas, pero la validación real de seguridad
  /// vive en `firestore.rules`, no aquí.
  Future<void> enviarOferta({
    required Envio envio,
    required String repartidorId,
    required Money monto,
  }) async {
    final expiraEn = envio.expiraEn;
    if (expiraEn != null) {
      final limite = expiraEn.toDate().add(ofertaGraceTolerance);
      if (DateTime.now().isAfter(limite)) {
        throw StateError('La subasta del envío ${envio.id} ya venció.');
      }
    }
    await _envios
        .doc(envio.id)
        .collection('ofertas')
        .add(Oferta.createData(repartidorId: repartidorId, monto: monto));
  }

  /// Un repartidor toma directamente un envío pendiente. Transacción
  /// atómica: lee el estado actual y solo escribe si sigue sin asignar —
  /// previene la doble asignación exigida por CLAUDE.md sin necesitar una
  /// Cloud Function (las Firestore Rules validan la misma precondición
  /// sobre los datos leídos dentro de la transacción).
  Future<void> aceptarEnvioDirecto({
    required String envioId,
    required String repartidorId,
  }) {
    final ref = _envios.doc(envioId);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data();
      if (data == null) {
        throw StateError('El envío $envioId no existe.');
      }
      final status = EnvioStatus.fromFirestore(data['status'] as String);
      final yaAsignado = data['repartidorAsignadoId'] != null;
      if (status != EnvioStatus.pendienteOfertas || yaAsignado) {
        throw StateError('El envío $envioId ya fue asignado a otro repartidor.');
      }
      transaction.update(ref, {
        'status': EnvioStatus.asignado.toFirestore(),
        'repartidorAsignadoId': repartidorId,
      });
    });
  }

  /// El cliente elige una propuesta específica entre las recibidas.
  /// Transacción atómica acotada a 2 documentos (el envío y la oferta
  /// elegida) — las demás ofertas pendientes del mismo envío no se tocan;
  /// la UI las trata como cerradas en cuanto `envio.status` deja de ser
  /// `pendiente_ofertas`.
  Future<void> aceptarOferta({
    required String envioId,
    required String ofertaId,
    required String repartidorId,
  }) {
    final envioRef = _envios.doc(envioId);
    final ofertaRef = envioRef.collection('ofertas').doc(ofertaId);
    return _firestore.runTransaction((transaction) async {
      final envioSnap = await transaction.get(envioRef);
      final ofertaSnap = await transaction.get(ofertaRef);
      final envioData = envioSnap.data();
      final ofertaData = ofertaSnap.data();
      if (envioData == null || ofertaData == null) {
        throw StateError('El envío $envioId o la oferta $ofertaId no existen.');
      }

      final status = EnvioStatus.fromFirestore(envioData['status'] as String);
      final yaAsignado = envioData['repartidorAsignadoId'] != null;
      if (status != EnvioStatus.pendienteOfertas || yaAsignado) {
        throw StateError('El envío $envioId ya fue asignado.');
      }

      final ofertaStatus = OfertaStatus.fromFirestore(
        ofertaData['status'] as String,
      );
      if (ofertaStatus != OfertaStatus.pendiente) {
        throw StateError('La oferta $ofertaId ya no está pendiente.');
      }

      transaction.update(envioRef, {
        'status': EnvioStatus.asignado.toFirestore(),
        'repartidorAsignadoId': repartidorId,
        'ofertaAceptadaId': ofertaId,
      });
      transaction.update(ofertaRef, {
        'status': OfertaStatus.aceptada.toFirestore(),
      });
    });
  }
}
