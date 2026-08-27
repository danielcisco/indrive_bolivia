import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dart_geohash/dart_geohash.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../domain/entities/calificacion.dart';
import '../domain/entities/envio.dart';
import '../domain/entities/oferta.dart';
import '../domain/value_objects/money.dart';

/// Tolerancia de gracia tras `expiraEn` para ofertas encoladas offline que
/// sincronizan poco después del cierre nominal de la subasta (regla no
/// negociable de CLAUDE.md: "tolerancia de gracia para cola offline").
const Duration ofertaGraceTolerance = Duration(minutes: 2);

class EnviosRepository {
  EnviosRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance,
      _geoHasher = GeoHasher();

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
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

  /// Fetch puntual de un envío por id (no es un stream: no siempre hace
  /// falta tiempo real, ver [streamEnvio] para cuando sí).
  Future<Envio?> obtenerEnvio(String id) async {
    final snapshot = await _envios.doc(id).get();
    if (!snapshot.exists) return null;
    return Envio.fromFirestore(snapshot);
  }

  /// Listener en tiempo real de un único documento — usado mientras un
  /// envío está `en_curso` para reflejar la posición del repartidor sin
  /// que el Cliente tenga que refrescar. Un stream sobre un solo documento
  /// es barato y es exactamente el caso que sí amerita tiempo real, a
  /// diferencia de escuchar colecciones enteras ("streams masivos", que
  /// CLAUDE.md sí prohíbe).
  Stream<Envio?> streamEnvio(String id) {
    return _envios
        .doc(id)
        .snapshots()
        .map((snapshot) => snapshot.exists ? Envio.fromFirestore(snapshot) : null);
  }

  /// Envíos actualmente `en_curso`, en tiempo real y acotado por
  /// `.limit()` — alimenta el mapa en vivo del panel Admin (Sprint 5.1).
  ///
  /// Es un stream sobre una colección filtrada, no sobre un único
  /// documento como [streamEnvio] — se justifica igual: está acotado por
  /// `status` (solo entregas activas, un número chico en la operación real
  /// de Villazón) y por `.limit()`, así que no es el "stream masivo sobre
  /// toda la colección" que CLAUDE.md prohíbe.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamEnviosEnCurso({
    int limit = 100,
  }) {
    return _envios
        .where('status', isEqualTo: EnvioStatus.enCurso.toFirestore())
        .limit(limit)
        .snapshots();
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

  /// Envíos del cliente [clienteId], paginado — [status] opcional filtra a
  /// un solo estado (ver `firestore.indexes.json` para el índice
  /// compuesto que esto necesita).
  Future<QuerySnapshot<Map<String, dynamic>>> listarEnviosDeCliente(
    String clienteId, {
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    EnvioStatus? status,
  }) {
    Query<Map<String, dynamic>> query = _envios.where(
      'clienteId',
      isEqualTo: clienteId,
    );
    if (status != null) {
      query = query.where('status', isEqualTo: status.toFirestore());
    }
    query = query.orderBy('createdAt', descending: true).limit(limit);
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

  /// El cliente dueño cancela mientras el envío siga sin asignar. Sin
  /// transacción: a diferencia de aceptar un envío, acá no hay una
  /// condición de carrera real que prevenir (nadie más escribe `status`
  /// al mismo tiempo que el propio dueño cancelando el suyo).
  Future<void> cancelarEnvio(String envioId) {
    return _envios.doc(envioId).update({
      'status': EnvioStatus.cancelado.toFirestore(),
    });
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

  /// Entregas del repartidor [repartidorId], paginado — [status] opcional
  /// filtra a un solo estado (asignado/en_curso/entregado; ver
  /// `firestore.indexes.json` para el índice compuesto que esto necesita).
  Future<QuerySnapshot<Map<String, dynamic>>> listarEntregasDeRepartidor(
    String repartidorId, {
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    EnvioStatus? status,
  }) {
    Query<Map<String, dynamic>> query = _envios.where(
      'repartidorAsignadoId',
      isEqualTo: repartidorId,
    );
    if (status != null) {
      query = query.where('status', isEqualTo: status.toFirestore());
    }
    query = query.orderBy('createdAt', descending: true).limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.get();
  }

  /// El repartidor asignado arranca el viaje — dispara el Foreground
  /// Service de tracking (ver `lib/core/tracking/`). No hace falta pasar
  /// el uid del repartidor: la Firestore Rule valida que quien escribe sea
  /// `repartidorAsignadoId`, el cliente no necesita repetirlo.
  Future<void> iniciarViaje(String envioId) {
    return _envios.doc(envioId).update({
      'status': EnvioStatus.enCurso.toFirestore(),
    });
  }

  /// El repartidor asignado marca la entrega como completada — detiene el
  /// tracking. El método de pago y el comprobante (si es QR) se fijan en
  /// esta misma escritura (Sprint 6.1): las Rules exigen que viajen juntos
  /// con la transición a `entregado`, no en un update aparte.
  Future<void> marcarEntregado(
    String envioId, {
    required MetodoPago metodoPago,
    String? comprobanteUrl,
  }) {
    return _envios.doc(envioId).update({
      'status': EnvioStatus.entregado.toFirestore(),
      'metodoPago': metodoPago.toFirestore(),
      'comprobanteUrl': ?comprobanteUrl,
    });
  }

  /// Sube la foto del comprobante QR a Storage y devuelve su URL de
  /// descarga. La compresión en cliente (regla no negociable de
  /// CLAUDE.md) la hace `image_picker` al capturar la foto, no este
  /// método — ver `ConfirmarEntregaScreen`.
  ///
  /// El path incluye el uid del repartidor (no solo el envioId) para que
  /// la regla de Storage pueda validar el dueño comparando directo contra
  /// `request.auth.uid` (mismo patrón que `/kyc/{uid}/`), sin depender de
  /// un `firestore.get()` cruzado en la escritura.
  Future<String> subirComprobante({
    required String envioId,
    required String repartidorId,
    required File archivo,
  }) async {
    final ref = _storage.ref(
      'comprobantes/$envioId/$repartidorId/${const Uuid().v4()}.jpg',
    );
    // contentType explícito: sin esto, la inferencia automática de
    // putFile() puede no reconocer el archivo temporal de la cámara como
    // imagen, y la regla de Storage (`contentType.matches('image/.*')`)
    // lo rechaza con un "unauthorized" que no explica el motivo real.
    await ref.putFile(
      archivo,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  /// Un Admin marca como verificado el comprobante QR de un envío ya
  /// entregado — único campo que el rol admin puede tocar sobre `envios`
  /// (ver `firestore.rules`).
  Future<void> verificarPago(String envioId) {
    return _envios.doc(envioId).update({'pagoVerificado': true});
  }

  /// Envíos entregados con pago QR todavía sin verificar, paginado —
  /// alimenta `PagosPendientesScreen` del panel Admin (Sprint 6.1).
  Future<QuerySnapshot<Map<String, dynamic>>> listarPagosQrPendientes({
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    var query = _envios
        .where('status', isEqualTo: EnvioStatus.entregado.toFirestore())
        .where('metodoPago', isEqualTo: MetodoPago.qr.toFirestore())
        .where('pagoVerificado', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.get();
  }

  CollectionReference<Map<String, dynamic>> _calificaciones(String envioId) =>
      _envios.doc(envioId).collection('calificaciones');

  /// Fetch puntual: existe si [autorId] ya calificó este envío — se usa
  /// para ocultar el botón "Calificar" una vez hecho.
  Future<Calificacion?> obtenerCalificacionDe(
    String envioId,
    String autorId,
  ) async {
    final snapshot = await _calificaciones(envioId).doc(autorId).get();
    if (!snapshot.exists) return null;
    return Calificacion.fromFirestore(snapshot, envioId: envioId);
  }

  /// Crea la calificación con el UID del autor como ID de documento —
  /// previene una segunda calificación del mismo usuario (ver
  /// `Calificacion`).
  Future<void> crearCalificacion({
    required String envioId,
    required String autorId,
    required String paraId,
    required int estrellas,
    String? comentario,
  }) {
    return _calificaciones(envioId).doc(autorId).set(
      Calificacion.createData(
        autorId: autorId,
        paraId: paraId,
        estrellas: estrellas,
        comentario: comentario,
      ),
    );
  }

  /// Escrito desde el Foreground Service en cada lectura GPS válida
  /// (filtrada por precisión, ya throttleada por distancia por
  /// `distanceFilter` — ver `background_location_service.dart`).
  Future<void> actualizarPosicionRepartidor({
    required String envioId,
    required GeoPoint posicion,
  }) {
    return _envios.doc(envioId).update({
      'repartidorPosicionActual': posicion,
      'repartidorPosicionActualizada': FieldValue.serverTimestamp(),
    });
  }
}
