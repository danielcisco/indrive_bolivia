import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Debe coincidir exactamente con el `channelId` que usa la Cloud Function
/// `notifyNearbyRepartidores` (functions/src/index.ts) al enviar el
/// mensaje — si no coincide, Android no aplica la importancia alta.
const String kOfertasChannelId = 'ofertas_alta_prioridad';

/// Avisos del ciclo de vida del envío para el Cliente (sprint extra,
/// Grupo D: aceptación directa, nueva contraoferta, expiración) — mismo
/// criterio de coincidencia exacta con las Cloud Functions que lo usan.
/// A diferencia de [kOfertasChannelId], es informativo, no urgente: sin
/// `fullScreenIntent` ni `category: call`.
const String kActualizacionesEnvioChannelId = 'actualizaciones_envio';

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
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _crearCanales();
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

  /// Crea los dos canales de una — esta misma clase la usan tanto
  /// Cliente como Repartidor, así que da igual cuál termine usando cada
  /// uno (crear un canal que nunca se dispara no tiene costo).
  Future<void> _crearCanales() async {
    const canalOfertas = AndroidNotificationChannel(
      kOfertasChannelId,
      'Ofertas cercanas',
      description: 'Avisos de nuevos envíos disponibles cerca de ti.',
      importance: Importance.high,
    );
    const canalActualizaciones = AndroidNotificationChannel(
      kActualizacionesEnvioChannelId,
      'Actualizaciones de tu envío',
      description:
          'Avisos cuando tu envío es aceptado, recibe una contraoferta, '
          'o vence sin que nadie lo tome.',
      importance: Importance.high,
    );
    final plugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await plugin?.createNotificationChannel(canalOfertas);
    await plugin?.createNotificationChannel(canalActualizaciones);
  }

  Future<void> _mostrarNotificacionLocal(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    // El canal viaja en el propio mensaje (lo fija la Cloud Function que
    // lo envía) — se elige el estilo de la notificación local según cuál
    // sea, en vez de asumir siempre el de ofertas.
    final channelId = message.notification?.android?.channelId ?? kOfertasChannelId;
    final esOfertaUrgente = channelId == kOfertasChannelId;
    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          esOfertaUrgente ? 'Ofertas cercanas' : 'Actualizaciones de tu envío',
          importance: Importance.high,
          priority: Priority.high,
          category: esOfertaUrgente ? AndroidNotificationCategory.call : null,
          fullScreenIntent: esOfertaUrgente,
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
