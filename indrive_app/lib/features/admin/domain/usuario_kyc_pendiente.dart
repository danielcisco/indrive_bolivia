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
    required this.fotoPersonalUrl,
    required this.numeroLicencia,
    required this.licenciaFrenteUrl,
    required this.licenciaDorsoUrl,
    required this.selfieLicenciaUrl,
    required this.tipoVehiculo,
    required this.marcaVehiculo,
    required this.modeloVehiculo,
    required this.placaVehiculo,
    required this.fotoVehiculoUrl,
    required this.tarjetaCirculacionUrl,
    required this.soatUrl,
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
      fotoPersonalUrl: data['fotoPersonalUrl'] as String?,
      numeroLicencia: data['numeroLicencia'] as String?,
      licenciaFrenteUrl: data['licenciaFrenteUrl'] as String?,
      licenciaDorsoUrl: data['licenciaDorsoUrl'] as String?,
      selfieLicenciaUrl: data['selfieLicenciaUrl'] as String?,
      tipoVehiculo: data['tipoVehiculo'] as String?,
      marcaVehiculo: data['marcaVehiculo'] as String?,
      modeloVehiculo: data['modeloVehiculo'] as String?,
      placaVehiculo: data['placaVehiculo'] as String?,
      fotoVehiculoUrl: data['fotoVehiculoUrl'] as String?,
      tarjetaCirculacionUrl: data['tarjetaCirculacionUrl'] as String?,
      soatUrl: data['soatUrl'] as String?,
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

  /// Datos del wizard de registro (Sprints 18-20) — todos null en cuentas
  /// de antes de esos sprints, que nunca pasaron por este flujo.
  final String? fotoPersonalUrl;
  final String? numeroLicencia;
  final String? licenciaFrenteUrl;
  final String? licenciaDorsoUrl;
  final String? selfieLicenciaUrl;
  final String? tipoVehiculo;
  final String? marcaVehiculo;
  final String? modeloVehiculo;
  final String? placaVehiculo;
  final String? fotoVehiculoUrl;
  final String? tarjetaCirculacionUrl;
  final String? soatUrl;
}
