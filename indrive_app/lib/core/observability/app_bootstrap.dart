import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import '../../firebase_options.dart';
import 'crashlytics_service.dart';

/// Bootstrap común a los tres entry points (Cliente, Repartidor, Admin):
/// inicializa Firebase y engancha Crashlytics antes de correr la app.
///
/// Firebase Performance Monitoring no necesita llamada explícita: queda
/// activo automáticamente en cuanto [Firebase.initializeApp] corre.
Future<void> bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await CrashlyticsService.initialize();
}
