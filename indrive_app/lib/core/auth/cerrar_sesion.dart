import 'package:firebase_auth/firebase_auth.dart';

import 'app_lock_service.dart';

/// Cierra sesión y borra el PIN/preferencia de huella local (sprint
/// extra: bloqueo con huella/PIN) — el PIN vive en `flutter_secure_storage`
/// del DISPOSITIVO, no de la cuenta; sin esto, otra cuenta que inicie
/// sesión en el mismo celular se encontraría pidiendo el PIN de la
/// cuenta anterior antes de poder entrar. Reemplaza a
/// `FirebaseAuth.instance.signOut` en todos los botones de "Cerrar
/// sesión" de la app.
Future<void> cerrarSesionYBorrarBloqueo() async {
  await AppLockService().borrarTodo();
  await FirebaseAuth.instance.signOut();
}
