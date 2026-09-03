/// Nombre/apellido/nick/avatar de un usuario, tal como vive en
/// `perfiles_publicos/{uid}` — la única parte del perfil visible para
/// otros usuarios (el resto de `users/{uid}` tiene campos sensibles como
/// `cedulaUrl`/`phoneNumber`, solo legibles por el propio dueño).
///
/// `ratingPromedio`/`totalCalificaciones` son un espejo (sprint de
/// rediseño) de los mismos campos en `users/{uid}` — se escriben ahí
/// porque son la única forma de que la contraparte de un envío vea la
/// calificación sin poder leer `users/{uid}` (ver
/// `functions/actualizarRatingPromedio`).
class PerfilPublico {
  const PerfilPublico({
    required this.nombre,
    required this.apellido,
    required this.nick,
    required this.avatarId,
    required this.ratingPromedio,
    required this.totalCalificaciones,
  });

  factory PerfilPublico.fromMap(Map<String, dynamic> data) {
    return PerfilPublico(
      nombre: data['nombre'] as String? ?? '',
      apellido: data['apellido'] as String? ?? '',
      nick: data['nick'] as String? ?? '',
      avatarId: data['avatarId'] as String?,
      ratingPromedio: (data['ratingPromedio'] as num?)?.toDouble() ?? 0,
      totalCalificaciones: data['totalCalificaciones'] as int? ?? 0,
    );
  }

  final String nombre;
  final String apellido;
  final String nick;
  final String? avatarId;
  final double ratingPromedio;
  final int totalCalificaciones;
}
