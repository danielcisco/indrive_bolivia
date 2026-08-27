import 'package:flutter/material.dart';

/// Una opción de avatar: ícono predefinido + color, sin foto real (decisión
/// del sprint extra de UI: evita subida de imágenes, permisos de
/// cámara/galería y reglas de Storage nuevas para algo puramente
/// decorativo).
class AvatarOpcion {
  const AvatarOpcion(this.id, this.icono, this.color);

  final String id;
  final IconData icono;
  final Color color;
}

const kAvatares = [
  AvatarOpcion('moto_azul', Icons.two_wheeler, Colors.blue),
  AvatarOpcion('auto_verde', Icons.directions_car, Colors.green),
  AvatarOpcion('paquete_naranja', Icons.inventory_2, Colors.orange),
  AvatarOpcion('persona_morado', Icons.person, Colors.purple),
  AvatarOpcion('bici_teal', Icons.pedal_bike, Colors.teal),
  AvatarOpcion('estrella_ambar', Icons.star, Colors.amber),
  AvatarOpcion('casa_marron', Icons.home, Colors.brown),
  AvatarOpcion('rayo_rojo', Icons.bolt, Colors.red),
  AvatarOpcion('escudo_indigo', Icons.shield, Colors.indigo),
  AvatarOpcion('corazon_rosa', Icons.favorite, Colors.pink),
  AvatarOpcion('reloj_cyan', Icons.watch_later, Colors.cyan),
  AvatarOpcion('cohete_gris', Icons.rocket_launch, Colors.blueGrey),
];

/// Devuelve la opción con [id], o la primera de la lista (por defecto) si
/// es null o no coincide con ninguna — mismo criterio que "0 calificaciones
/// = todavía sin elegir" ya usado para el rating.
AvatarOpcion avatarPorId(String? id) {
  return kAvatares.firstWhere(
    (avatar) => avatar.id == id,
    orElse: () => kAvatares.first,
  );
}
