# Documentación y notas de sesión

Carpeta con los documentos generados durante las sesiones de trabajo con Claude, y las notas de planificación (Plan Mode) que se fueron escribiendo a medida que se diseñaba cada sprint. No es documentación de producto formal — es el registro de trabajo, útil para retomar contexto.

## Documentos

- **[resumen-sesion.html](resumen-sesion.html)** — resumen exhaustivo y cronológico de la sesión más larga: buscador de direcciones, identidad visual, rediseño del registro con KYC, gate de verificación, filtros, despliegue a Hosting, tests. Incluye bugs encontrados y el porqué de cada decisión.
- **[flujo-de-uso.md](flujo-de-uso.md)** — guía en texto plano del flujo de uso completo de las 3 apps (Cliente, Repartidor, Admin), paso a paso.
- **[flujo-indrive-entregas.html](flujo-indrive-entregas.html)** — diagrama de flujo de actividad de las 3 apps + explicación de KYC + observaciones de UX (origen de varios pedidos posteriores, como el buscador de direcciones).
- **[bitacora-indrive-villazon.html](bitacora-indrive-villazon.html)** — bitácora de una sesión anterior.
- **[observabilidad.md](observabilidad.md)** — eventos de Crashlytics y trazas de Performance agregados en el sprint de observabilidad, qué mide cada uno y cómo revisarlos en Firebase Console.

## Planes (`planes/`)

Cada archivo es un plan escrito en Plan Mode antes de implementar un cambio no trivial — quedan con nombres autogenerados (no descriptivos), pero cada uno documenta el contexto, el diseño elegido y por qué, del cambio que precede.
