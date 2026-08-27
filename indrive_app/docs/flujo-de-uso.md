# Flujo de uso — inDrive Entregas (Villazón, Potosí)

## App Cliente

1. **Bienvenida** — pantalla que identifica la app ("App Cliente — Villazón, Potosí") con dos botones: "Registrarme" y "Ya tengo cuenta" (llevan al mismo flujo).
2. **Teléfono** — prefijo `+591` fijo, solo escribe los 8 dígitos → "Enviar código".
3. **Código SMS** recibido → "Confirmar".
4. **Si es un número nuevo**: pide Nombres, Apellidos, Nick y una foto de la Cédula de Identidad → "Continuar". (Si el número ya tenía cuenta, este paso se salta solo.)
5. **Home**: header arriba con avatar (elegible tocándolo), nombre/nick y ⭐ calificación; botones "Mis calificaciones" y "Mis envíos".
6. **Mis envíos**: lista filtrable por estado (Todos / Pendientes / Asignado / En curso / Entregado / Cancelado / Expirado) + botón "+" para crear un envío.
7. **Crear envío**: descripción, origen y destino en el mapa (con buscador de direcciones), monto ofertado → al publicar, cae directo en el detalle de ese mismo envío.
8. **Detalle (mientras está pendiente)**: cuenta regresiva, lista de contraofertas de repartidores (puede aceptar una), botón "Cancelar envío".
9. **Una vez asignado**: aparece la tarjeta "Tu repartidor" (nombre/nick/avatar) y el mapa muestra su posición en vivo (ícono de moto).
10. **Una vez entregado**: se muestra el método de pago y un botón para calificar al repartidor.

## App Repartidor

1. **Bienvenida** → teléfono → código (igual que Cliente).
2. **Si es nuevo**: Nombres, Apellidos, Nick, foto de Cédula → "Continuar".
3. **Si todavía no está verificado por el Admin**: pantalla "Verificación pendiente" — si le falta subir la foto se la pide ahí mismo; si ya la subió, espera en vivo la aprobación (se actualiza sola) y ahí se habilita "Continuar" con mensaje de bienvenida. Recién entonces entra a Home.
4. **Home**: header + botones "Radar de ofertas" y "Mis entregas".
5. **Radar**: envíos disponibles cerca, se actualiza solo cada 20 segundos (además de refresco manual).
6. **Detalle de un envío**: mapa, cuenta regresiva, "Aceptar directo" (con confirmación) o enviar una contraoferta con su propio monto.
7. **Al aceptar directo**: cae directo en "Entrega actual" (no en la lista general), con los datos del cliente (nombre/nick/avatar) y el mapa.
8. **Iniciar viaje** → arranca el tracking GPS en segundo plano → **Marcar como entregado**.
9. **Confirmar entrega**: elige método de pago (efectivo o QR con foto del comprobante) → se detiene el tracking → diálogo opcional para calificar al cliente → vuelve a "Mis entregas", ya actualizada sola mostrando la entrega como "Entregada".
10. **Mis entregas**: filtrable por Asignadas / En curso / Entregadas / Todas.

## Panel Admin (Web)

1. **Login** con email y contraseña.
2. **Mapa en vivo**: posición en tiempo real de todos los envíos en curso, con el nombre del repartidor visible.
3. **Verificación KYC**: repartidores pendientes con su foto de Cédula visible → "Aprobar".
4. **Pagos QR pendientes**: comprobantes subidos por repartidores → marcar como verificado.
5. **Usuarios**: lista de Clientes/Repartidores, ver detalle, suspender/reactivar cuentas.
