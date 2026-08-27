# Filtro por estado + navegación automática en Mis Envíos/Entregas

## Contexto

5 mejoras de UX pedidas sobre las listas de envíos/entregas y la navegación alrededor de ellas:

**Cliente**: (1) filtro por estado en "Mis envíos"; (2) tras crear un envío, ir directo a su detalle en vez de volver a la lista.

**Repartidor**: (3) que "Mis entregas" se actualice sola tras aceptar directo, y tenga el mismo filtro; (4) tras aceptar, ir directo al detalle de esa entrega (no a la lista general — esto refina el fix de navegación de un sprint anterior, que hoy manda a `MisEntregasScreen`); (5) que "Mis entregas" se actualice sola tras cobrar y calificar.

Hallazgos relevantes de la investigación (sin cambiar nada todavía):
- No existe ningún patrón de filtro/dropdown en el proyecto — terreno libre. Voy a usar `ChoiceChip` en una fila horizontal (visible de un vistazo, un toque para cambiar), como widget **compartido** nuevo, ya que se pide "el mismo elemento" en ambas apps.
- El repartidor de `MisEntregasController` hoy filtra `asignado`/`enCurso` **en memoria, después de paginar** (`mis_entregas_controller.dart:74-81`), con un bug latente ya documentado en el propio código: `hasMore` se calcula sobre el total sin filtrar, así que la paginación puede cortarse antes de tiempo. Mover el filtro a la query de Firestore resuelve esto de paso.
- `EnviosRepository.crearEnvio` ([envios_repository.dart:34-51](indrive_app/lib/shared/data/envios_repository.dart:34-51)) ya devuelve el `id` del envío nuevo — solo hay que dejarlo llegar hasta la pantalla.
- `CrearEnvioController.crear()` no lo expone (es `AsyncNotifier<void>`) — hay que devolverlo.
- Ninguno de los 2 puntos de "se actualiza sola" invalida hoy `misEntregasControllerProvider` — confirmado con grep, no existe esa llamada en `envio_repartidor_detalle_screen.dart` ni en `confirmar_entrega_screen.dart`.

## 1. Filtro por estado — widget compartido + query en Firestore

`lib/shared/widgets/filtro_estado_chips.dart` (nuevo): fila horizontal de `ChoiceChip` a partir de una lista de opciones `(EnvioStatus?, String etiqueta)` — cada pantalla define sus propias opciones (Cliente ve todo el ciclo de vida; Repartidor solo los estados que puede tener una entrega ya asignada: asignado/en_curso/entregado, sin pendiente/cancelado/expirado que no aplican a algo ya asignado).

- [envios_repository.dart](indrive_app/lib/shared/data/envios_repository.dart): `listarEnviosDeCliente` y `listarEntregasDeRepartidor` ganan un parámetro `EnvioStatus? status` — si no es null, agregan `.where('status', isEqualTo: status.toFirestore())` a la query (ya existe `toFirestore()` en el enum). Esto reemplaza el filtro en memoria de `listarEntregasDeRepartidor`, arreglando el bug de paginación de paso.
- [firestore.indexes.json](indrive_app/firestore.indexes.json): 2 índices compuestos nuevos — `clienteId+status+createdAt` y `repartidorAsignadoId+status+createdAt`.
- `MisEnviosState`/`MisEntregasState` ganan un campo `filtro` (`EnvioStatus?`), y sus controllers un método `cambiarFiltro(EnvioStatus?)` que reinicia la paginación con el nuevo filtro (mismo patrón que `refrescar()` ya existente en `MisEntregasController`/`RadarController`).
- Las 2 pantallas agregan `FiltroEstadoChips` debajo del AppBar (`bottom:` de un `PreferredSize`, mismo patrón que `UserProfileHeader`), conectado a `cambiarFiltro`.
- Default: "Todas" en ambas — para Repartidor esto cambia el comportamiento actual (hoy siempre filtra a activas sin que se pueda ver el historial completo); ahora "Todas" muestra asignado+en_curso+entregado, y el repartidor puede acotar con los chips si quiere solo lo activo.

## 2. Cliente: ir al detalle tras crear un envío

- [crear_envio_controller.dart](indrive_app/lib/features/cliente/presentation/providers/crear_envio_controller.dart): `crear()` pasa a devolver `Future<String?>` — el `id` en el camino feliz (escritura directa exitosa), `null` si se encoló offline (ahí no hay documento todavía, no tiene sentido navegar a un detalle que no existe aún).
- [crear_envio_screen.dart](indrive_app/lib/features/cliente/presentation/screens/crear_envio_screen.dart): si `crear()` devuelve un id, `Navigator.of(context).pushReplacement(...)` a `EnvioDetalleScreen(envioId: id)` en vez de `pop()` — así el botón "atrás" desde el detalle vuelve a "Mis envíos" (no al formulario). Si devuelve `null` (offline), se mantiene el `pop()` actual.

## 3 y 5. Repartidor: refrescar "Mis entregas" tras aceptar y tras cobrar+calificar

- [envio_repartidor_detalle_screen.dart](indrive_app/lib/features/repartidor/presentation/screens/envio_repartidor_detalle_screen.dart), `_aceptarDirecto`: agrega `ref.invalidate(misEntregasControllerProvider)` antes de navegar.
- [confirmar_entrega_screen.dart](indrive_app/lib/features/repartidor/presentation/screens/confirmar_entrega_screen.dart), `_confirmar`: agrega la misma invalidación justo antes del doble `pop()`.

## 4. Repartidor: ir a la entrega actual tras aceptar (no a la lista)

[envio_repartidor_detalle_screen.dart](indrive_app/lib/features/repartidor/presentation/screens/envio_repartidor_detalle_screen.dart), `_aceptarDirecto`: cambia el `push` de `MisEntregasScreen` por `EntregaEnCursoScreen(envioId: widget.envioId)` (mismo widget al que ya navega `MisEntregasScreen` al tocar un ítem) — mantiene el `popUntil((route) => route.isFirst)` previo para no apilar el detalle de "envío pendiente" debajo.

## Verificación

1. `flutter analyze` limpio.
2. `firebase deploy --only firestore:indexes` (los 2 índices nuevos).
3. Cliente: crear un envío → cae directo en su detalle; "atrás" vuelve a Mis Envíos. Los chips de estado filtran la lista correctamente.
4. Repartidor: aceptar directo un envío → cae directo en "Entrega actual" (no en la lista); al volver a "Mis entregas", ya aparece sin necesidad de refrescar a mano.
5. Repartidor: cobrar + calificar → al volver a "Mis entregas", el envío ya figura como "entregado" sin refrescar a mano. Los chips filtran correctamente (probar "Todas" vs "Entregado").
6. Commit.
