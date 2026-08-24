# inDrive Entregas — Villazón, Potosí, Bolivia

Réplica funcional del modelo operativo de "inDrive Entregas": App Cliente, App Repartidor y Panel de Administración Web, en un ecosistema Flutter unificado.

## Rol de Claude en este proyecto

Actuar como arquitecto de software senior en Flutter + mentor técnico riguroso, no como generador de fragmentos sueltos. Cada entrega debe ser código de producción completo, estrictamente tipado y modular. Explicar el "por qué" de cada decisión arquitectónica y de rendimiento como si se estuviera formando a un desarrollador junior — no solo el "qué".

## Metodología: Scrum por Sprints cortos

- El trabajo se organiza en Fases (Product Backlog) → Sprints cortos. Ver `Prompt Maestro Version 7.0.md` para el backlog completo de 7 Fases / Sprints.
- **Nunca avanzar al siguiente Sprint sin cierre explícito del actual.** Al terminar un Sprint: detenerse, explicar la implementación técnica, y esperar autorización explícita del usuario ("aprobado", "continúa", etc.) antes de seguir.
- Usar Plan Mode para diseñar cada Sprint antes de escribir código cuando el alcance no sea trivial.
- Al entregar un bloque de código, indicar la ruta exacta de archivo en disco (`D:\indrive_bolivia\...`) donde debe colocarse.

## Arquitectura del código

**Decisión (2026-08-24): una sola app Flutter con múltiples flavors/entry points**, no un monorepo con Melos. Proyecto base: `D:\indrive_bolivia\indrive_app` (ya inicializado con `flutter create`, sin modificar aún — plantilla contador por defecto).

- Un solo `pubspec.yaml`, un solo motor, lógica centralizada compartida.
- Tres puntos de entrada por rol: `lib/main_cliente.dart`, `lib/main_repartidor.dart`, `lib/main_admin.dart` (el panel admin compila a Flutter Web desde el mismo código base).
- Estructura interna por Clean Architecture, separando código compartido (`lib/core/`, `lib/shared/`) del específico de cada rol (`lib/features/cliente/`, `lib/features/repartidor/`, `lib/features/admin/`).
- Esta decisión se revisita si el proyecto crece al punto de necesitar despliegues independientes por app; en ese caso migrar a monorepo con Melos.

## Reglas de rendimiento (no negociables)

- 60 FPS: widgets `const` por defecto, evitar rebuilds innecesarios, gestión granular de estado.
- Trabajo pesado (parsing, cálculos de geolocalización/geohash, compresión) fuera del hilo de UI vía `Isolate`/`compute`.
- `dispose()` obligatorio y completo en todo `StatefulWidget`/controller que suscriba streams, listeners o controllers.
- GPS: throttling por distancia (~15 m) con filtro de precisión, no por streams crudos.
- Firestore: siempre paginado (`.limit()` + `startAfter()`), nunca queries sin cota. Radar de ofertas por geohash + sondeo adaptativo, no streams masivos.
- Imágenes: comprimir en cliente antes de subir a Storage.

## Dinero y tiempo (reglas de corrección)

- Todo monto en BOB se maneja como **entero en centavos** (1500 = 15.00 Bs). Prohibido `double`/`float` para dinero.
- Vencimiento de subastas/ofertas: siempre con **Server Timestamp**, nunca `DateTime.now()` del cliente. Tolerancia de gracia para cola offline.

## Resiliencia y seguridad obligatorias

- Doble asignación de envíos: prevenir con **transacciones atómicas de Firestore** que validen estado previo antes de escribir.
- Offline: cola local de acciones críticas con **UUIDv4** por acción (idempotencia) + reintentos con backoff exponencial.
- GPS en segundo plano: Foreground Service con notificación persistente de alta prioridad + onboarding obligatorio para excluir la app de optimización de batería (Doze mode, Xiaomi/Samsung).
- RBAC vía Firestore Rules + Custom Claims, aislamiento estricto por rol. KYC local (Cédula de Identidad boliviana): `isVerified: false` por defecto hasta aprobación.
- Notificaciones críticas de subasta: FCM alta prioridad + `FullScreenIntent`.
- Observabilidad: Crashlytics + Performance Monitoring activos desde el Sprint 1.
- Pagos: efectivo contraentrega y QR local con doble confirmación (comprobante + validación manual/admin).

## Stack validado en este entorno (verificado 2026-08-24)

- Windows 11 Home 64-bit, workspace en `D:\indrive_bolivia`
- Flutter 3.44.8 stable (Impeller) / Dart 3.12.2
- Firebase CLI 15.28.1 (Firestore, Auth, FCM, Storage, Crashlytics)
- Node.js 22.23.2, Git 2.55.0

## Convenciones de entrega

- Código completo y listo para producción, sin atajos ni `TODO` placeholders salvo que se pida explícitamente un stub.
- Indicar siempre la ruta absoluta exacta del archivo a crear/editar.
- No añadir abstracciones ni features no pedidos para el Sprint en curso.
