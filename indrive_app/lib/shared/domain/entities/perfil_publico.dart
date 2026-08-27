/// Nombre/apellido/nick/avatar de un usuario, tal como vive en
/// `perfiles_publicos/{uid}` — la única parte del perfil visible para
/// otros usuarios (el resto de `users/{uid}` tiene campos sensibles como
/// `cedulaUrl`/`phoneNumber`, solo legibles por el propio dueño).
class PerfilPublico {
  const PerfilPublico({
    required this.nombre,
    required this.apellido,
    required this.nick,
    required this.avatarId,
  });

  factory PerfilPublico.fromMap(Map<String, dynamic> data) {
    return PerfilPublico(
      nombre: data['nombre'] as String? ?? '',
      apellido: data['apellido'] as String? ?? '',
      nick: data['nick'] as String? ?? '',
      avatarId: data['avatarId'] as String?,
    );
  }

  final String nombre;
  final String apellido;
  final String nick;
  final String? avatarId;
}
