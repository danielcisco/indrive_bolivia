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
/// Fuera de alcance aquí: la pantalla completa estilo "llamada entrante"
/// (FullScreenIntent) — queda como tarea de seguimiento explícita, no a
/// medio construir.
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
