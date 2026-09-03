# Observabilidad — Crashlytics + Performance Monitoring

Ambos SDK ya estaban en el proyecto desde el Sprint 1 (`pubspec.yaml`), pero sin ningún uso más allá del handler genérico de errores fatales. Este documento cubre lo que se agregó: claves/logs de negocio en Crashlytics (Sprint A) y trazas custom de Performance (Sprint B), más las decisiones que se tomaron y por qué.

## Por qué no se agregó Sentry (todavía)

Se evaluó un pedido más amplio de observabilidad que incluía Sentry. Se descartó por ahora: agregarlo encima de Crashlytics sería doble captura del mismo error con dos dashboards distintos, sin un gap concreto que lo justifique. La única razón real para reconsiderarlo sería un problema específico de Crashlytics en el panel Admin (Web) — hoy `CrashlyticsService.initialize()` es un no-op en Web a propósito (Crashlytics no soporta Flutter Web), así que el Admin no tiene ningún crash reporting activo. Si eso se vuelve un problema real, ahí se evalúa Sentry acotado solo al Admin — no antes, y no para las 3 apps.

## Eventos de Crashlytics (`CrashlyticsService.logEvento`)

Cada uno se dispara justo después de la escritura exitosa a Firestore, en `lib/shared/data/envios_repository.dart`. `envioId` y los campos de `extra` quedan como **custom keys** — no solo aparecen en el breadcrumb del evento, quedan pegados a CUALQUIER crash posterior de la misma sesión.

| Evento | Cuándo | Datos extra |
|---|---|---|
| `envio_creado` | Cliente publica un envío nuevo | `categoria`, `esFragil` |
| `oferta_enviada` | Repartidor envía una contraoferta | `repartidorId`, `monto` |
| `oferta_rechazada` | Cliente rechaza una propuesta | `ofertaId` |
| `oferta_aceptada` | Cliente acepta una propuesta específica | `ofertaId`, `repartidorId` |
| `envio_asignado_directo` | Repartidor toma un envío sin pasar por oferta | `repartidorId` |
| `envio_cancelado` | Cliente cancela un envío sin asignar | — |
| `viaje_iniciado` | Repartidor confirma la recogida | — |
| `envio_entregado` | Repartidor marca la entrega como completada | `metodoPago` |
| `pago_verificado` | Admin verifica un pago QR | — |

### Gap conocido: `expirado`

El estado `expirado` lo fija exclusivamente el barrido programado `expirarEnviosVencidos` (Cloud Function `onSchedule`, cada 5 minutos) — es la única transición de todo el proyecto que no pasa por un método de `EnviosRepository` con un call site del lado cliente. No tiene evento de Crashlytics porque no hay dónde ponerlo sin inventar un mecanismo aparte (ej. detectarlo al observar el stream, con el riesgo de loggear en cada rebuild). Si en el uso real esto termina siendo un punto ciego importante (ej. sospecha de "ofertas fantasma" que expiran sin que nadie se entere a tiempo), es un sprint aparte, no algo para forzar acá.

## Trazas de Performance (`PerformanceService.medir`)

| Traza | Dónde | Qué mide |
|---|---|---|
| `crear_envio` | `CrearEnvioController.crear()` | Latencia de subir la foto (si hay) + escribir el envío nuevo — solo el camino online, no la rama que encola offline |
| `aceptar_oferta` | `EnviosRepository.aceptarOferta()` | Latencia de la transacción atómica que asigna el envío |
| `actualizar_radar` | `RadarController._buscar()` | Latencia del sondeo adaptativo por geohash — cubre tanto el refresco manual como el sondeo automático cada 20s, porque ambos pasan por este mismo método |

Cada traza registra el atributo `resultado` (`ok`/`error`) además del tiempo.

## Cómo revisar esto en producción

1. **Crashlytics**: [Firebase Console](https://console.firebase.google.com) → proyecto `indrive-entregas-villazon` → Crashlytics (menú lateral) → elegir la app (Cliente/Repartidor — Admin no tiene datos, ver arriba). Al abrir un crash puntual, la pestaña "Keys" muestra los custom keys pegados a esa sesión (`envio_id`, `repartidorId`, etc.), y "Logs" muestra la secuencia de eventos de negocio que llevaron hasta ahí.
2. **Performance**: Firebase Console → Performance (menú lateral) → pestaña "Custom traces". Ahí aparecen `crear_envio`, `aceptar_oferta` y `actualizar_radar` con percentiles de duración y tasa de éxito/error una vez que haya datos reales de dispositivos.

Ninguno de los dos se puede verificar desde este entorno de desarrollo (hace falta un dispositivo real enviando datos a Firebase) — queda pendiente de la primera vez que la app corra en un celular de verdad.
