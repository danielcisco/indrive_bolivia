import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Debe coincidir exactamente con el `channelId` que usa la Cloud Function
/// `notifyNearbyRepartidores` (functions/src/index.ts) al enviar el
/// mensaje — si no coincide, Android no aplica la importancia alta.
const String kOfertasChannelId = 'ofertas_alta_prioridad';

/// Núcleo de notificaciones push (Sprint 3.2): canal de alta importancia,
/// registro del token FCM en `users/{uid}.fcmToken`, y despliegue de la
/// notificación en foreground (en background/terminada la muestra el SO
/// solo porque el mensaje trae `android.notification.channel_id`).
///
/// La notificación en foreground usa `fullScreenIntent` + `category: call`
/// (pendiente técnico post Sprint 5.1) para intentar mostrarse por encima
/// de la pantalla de bloqueo, estilo "llamada entrante" — desde Android 14
/// esto requiere que el usuario otorgue el permiso especial a mano en
/// Ajustes (no hay diálogo de runtime), no es algo que la app pueda forzar.
/// Al tocarla, la app pasa a primer plano con el comportamiento estándar
/// del SO (aterriza donde ya estaba el árbol de widgets); no se conectó un
/// handler de navegación propio a `RadarScreen` porque `core/` no debe
/// depender de `features/` — si se necesita, hay que resolverlo inyectando
/// el callback desde `main_repartidor.dart` vía override del provider.
class FcmService {
  FcmService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final FlutterLocalNotificationsPlugin _localNotifications;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  Future<void> initialize() async {
    // Requerido antes de crear canales o mostrar notificaciones — Sprint
    // 3.2 se saltó este paso porque la prueba de push quedó pendiente y
    // nunca lo delató. `background_location_service.dart` (Sprint 4.1b)
    // depende de que esto ya haya corrido.
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _crearCanalAltaPrioridad();
    await _messaging.requestPermission();

    final token = await _messaging.getToken();
    if (token != null) {
      await _guardarToken(token);
    }
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
      _guardarToken,
    );

    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
      _mostrarNotificacionLocal,
    );
  }

  Future<void> _crearCanalAltaPrioridad() async {
    const channel = AndroidNotificationChannel(
      kOfertasChannelId,
      'Ofertas cercanas',
      description: 'Avisos de nuevos envíos disponibles cerca de ti.',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  Future<void> _mostrarNotificacionLocal(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          kOfertasChannelId,
          'Ofertas cercanas',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.call,
          fullScreenIntent: true,
        ),
      ),
    );
  }

  Future<void> _guardarToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
  }
}
