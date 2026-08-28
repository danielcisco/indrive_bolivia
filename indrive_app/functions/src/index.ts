import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";

admin.initializeApp();

setGlobalOptions({ region: "southamerica-east1", maxInstances: 10 });

const SELF_ASSIGNABLE_ROLES = ["cliente", "repartidor"] as const;
type SelfAssignableRole = (typeof SELF_ASSIGNABLE_ROLES)[number];

function isSelfAssignableRole(value: unknown): value is SelfAssignableRole {
  return (
    typeof value === "string" &&
    (SELF_ASSIGNABLE_ROLES as readonly string[]).includes(value)
  );
}

/**
 * Asigna el Custom Claim `role` a un usuario recien autenticado por telefono.
 *
 * Solo acepta 'cliente' | 'repartidor': el rol 'admin' nunca se auto-asigna
 * desde el cliente, para que nadie pueda escalar privilegios llamando esta
 * funcion directamente. Es idempotente: si el usuario ya tiene un rol, se
 * rechaza (un usuario no puede cambiar de rol despues del registro).
 */
export const assignInitialRole = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError(
      "unauthenticated",
      "Debes iniciar sesion antes de solicitar un rol."
    );
  }

  const role = request.data?.role;
  if (!isSelfAssignableRole(role)) {
    throw new HttpsError(
      "invalid-argument",
      `role debe ser uno de: ${SELF_ASSIGNABLE_ROLES.join(", ")}.`
    );
  }

  const existingUser = await admin.auth().getUser(uid);
  if (existingUser.customClaims?.role) {
    throw new HttpsError(
      "already-exists",
      "Este usuario ya tiene un rol asignado."
    );
  }

  const isVerified = false;
  await admin.auth().setCustomUserClaims(uid, { role, isVerified });

  await admin
    .firestore()
    .collection("users")
    .doc(uid)
    .set(
      {
        role,
        isVerified,
        phoneNumber: existingUser.phoneNumber ?? null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

  return { role, isVerified };
});

/**
 * Aprueba el KYC de un usuario (normalmente un repartidor), fijando
 * `isVerified: true` en su Custom Claim y en su documento de Firestore.
 *
 * Mismo patron de seguridad que assignInitialRole: el cliente nunca puede
 * escribir isVerified por su cuenta (ni las Firestore Rules ni las Auth
 * Rules se lo permiten), asi que esta es la unica via. Solo un admin
 * autenticado puede invocarla. Es idempotente: si el usuario ya esta
 * verificado, no vuelve a escribir.
 *
 * Sustituye en produccion al script manual scripts/setVerifiedClaim.ts
 * (que se mantiene como utilidad de desarrollo/debug).
 */
export const approveKyc = onCall(async (request) => {
  const callerRole = request.auth?.token?.role;
  if (callerRole !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Solo un administrador puede aprobar KYC."
    );
  }

  const uid = request.data?.uid;
  if (typeof uid !== "string" || uid.length === 0) {
    throw new HttpsError("invalid-argument", "uid es requerido.");
  }

  const targetUser = await admin.auth().getUser(uid);
  const role = targetUser.customClaims?.role;
  if (!role) {
    throw new HttpsError(
      "failed-precondition",
      `El usuario ${uid} todavia no tiene un rol asignado.`
    );
  }

  if (targetUser.customClaims?.isVerified === true) {
    return { uid, role, isVerified: true };
  }

  await admin.auth().setCustomUserClaims(uid, { role, isVerified: true });
  await admin
    .firestore()
    .collection("users")
    .doc(uid)
    .set(
      {
        isVerified: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

  return { uid, role, isVerified: true };
});

const SUBASTA_VENTANA_MINUTOS = 10;

/**
 * Fija `expiraEn` de un envio recien creado, server-side.
 *
 * El SDK cliente de Firestore solo puede pedir "la hora actual del
 * servidor" (serverTimestamp()), no "hora del servidor + N minutos" -
 * sumar un offset requiere el reloj del servidor. Por eso el vencimiento
 * de la subasta se calcula aqui, nunca con DateTime.now() del cliente
 * (regla no negociable de CLAUDE.md).
 */
export const setEnvioExpiration = onDocumentCreated(
  { document: "envios/{envioId}", region: "southamerica-east1" },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    if (data.expiraEn) return;

    const createdAt = data.createdAt as admin.firestore.Timestamp | undefined;
    const base = createdAt ?? admin.firestore.Timestamp.now();
    const expiraEn = admin.firestore.Timestamp.fromMillis(
      base.toMillis() + SUBASTA_VENTANA_MINUTOS * 60_000
    );

    await snapshot.ref.update({ expiraEn });
  }
);

const NOTIFICATION_GEOHASH_PRECISION = 5;
const MAX_REPARTIDORES_A_NOTIFICAR = 100;

/**
 * Notifica por FCM de alta prioridad a los repartidores cuyo `ultimaGeohash`
 * (fijado por el cliente al abrir la pantalla de Radar) cae cerca del
 * origen de un envio recien creado.
 *
 * No hay tracking en segundo plano: `ultimaGeohash` es una foto puntual de
 * la ultima vez que el repartidor abrio el Radar, no una posicion en vivo
 * (eso es Fase 4). Por eso el radio de coincidencia aqui es mas ancho
 * (precision 5, ~5km) que el punto de partida del sondeo adaptativo del
 * cliente (precision 6) - mejor notificar de mas que dejar a alguien
 * cercano sin aviso por una foto de ubicacion ya desactualizada.
 */
export const notifyNearbyRepartidores = onDocumentCreated(
  { document: "envios/{envioId}", region: "southamerica-east1" },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    const origenGeohash = data.origenGeohash as string | undefined;
    if (!origenGeohash) return;

    const prefix = origenGeohash.substring(0, NOTIFICATION_GEOHASH_PRECISION);

    const usersSnapshot = await admin
      .firestore()
      .collection("users")
      .where("role", "==", "repartidor")
      .where("ultimaGeohash", ">=", prefix)
      .where("ultimaGeohash", "<", `${prefix}~`)
      .limit(MAX_REPARTIDORES_A_NOTIFICAR)
      .get();

    // Filtro por disponibilidad (Sprint 8.4) en memoria sobre el batch ya
    // acotado por MAX_REPARTIDORES_A_NOTIFICAR - no un nuevo indice
    // compuesto ni un filtro "!=" en la query, que forzaria uno. Ausente
    // se interpreta como disponible (mismo criterio que
    // UsersRepository.obtenerDisponibilidad en el cliente).
    const tokens = usersSnapshot.docs
      .filter((doc) => doc.data().disponible !== false)
      .map((doc) => doc.data().fcmToken as string | undefined)
      .filter((token): token is string => Boolean(token));

    if (tokens.length === 0) return;

    const descripcion =
      (data.descripcion as string | undefined) ?? "Nuevo envío";
    const montoCentavos =
      (data.montoOfertadoInicialCentavos as number | undefined) ?? 0;
    const montoBob = (montoCentavos / 100).toFixed(2);

    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: "Nuevo envío cerca de ti",
        body: `${descripcion} · Bs. ${montoBob}`,
      },
      data: {
        envioId: event.params.envioId,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "ofertas_alta_prioridad",
        },
      },
    });
  }
);

/**
 * Suspende o reactiva una cuenta (Sprint extra, Grupo C) - solo un admin
 * puede invocarla. "Suspender" usa el mecanismo real de Firebase Auth
 * (updateUser + revokeRefreshTokens), no un flag cosmetico: la cuenta
 * deja de poder loguearse de verdad, y una sesion ya abierta pierde su
 * validez en el proximo refresh en vez de seguir viva hasta que expire
 * sola. El espejo en Firestore (users/{uid}.isActive) es solo para que
 * el panel Admin pueda mostrar el estado sin llamar al Admin SDK en cada
 * lectura.
 */
export const establecerEstadoCuenta = onCall(async (request) => {
  const callerRole = request.auth?.token?.role;
  if (callerRole !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Solo un administrador puede suspender o reactivar cuentas."
    );
  }

  const uid = request.data?.uid;
  const activar = request.data?.activar;
  if (typeof uid !== "string" || typeof activar !== "boolean") {
    throw new HttpsError(
      "invalid-argument",
      "uid y activar son requeridos."
    );
  }

  await admin.auth().updateUser(uid, { disabled: !activar });
  if (!activar) {
    await admin.auth().revokeRefreshTokens(uid);
  }

  await admin
    .firestore()
    .collection("users")
    .doc(uid)
    .set(
      {
        isActive: activar,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

  return { uid, isActive: activar };
});

/**
 * Mantiene el promedio de calificaciones de un usuario (Sprint extra,
 * Grupo B) cada vez que se crea una calificacion nueva.
 *
 * Recorrer todas las calificaciones de alguien para calcular su promedio
 * cada vez que hay que mostrarlo no escala (regla no negociable: nunca
 * queries sin cota). En cambio, users/{uid} guarda totalCalificaciones y
 * sumaEstrellas -mantenidos aqui dentro de una transaccion- y de ahi se
 * deriva ratingPromedio. Las calificaciones nunca se editan ni se borran
 * (ver firestore.rules), asi que un trigger de creacion alcanza - no hace
 * falta manejar updates ni deletes.
 */
export const actualizarRatingPromedio = onDocumentCreated(
  { document: "envios/{envioId}/calificaciones/{autorId}" },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    const paraId = data.paraId as string | undefined;
    const estrellas = data.estrellas as number | undefined;
    if (!paraId || typeof estrellas !== "number") return;

    const userRef = admin.firestore().collection("users").doc(paraId);
    await admin.firestore().runTransaction(async (transaction) => {
      const userSnap = await transaction.get(userRef);
      const totalPrevio = (userSnap.data()?.totalCalificaciones as number) ?? 0;
      const sumaPrevia = (userSnap.data()?.sumaEstrellas as number) ?? 0;

      const total = totalPrevio + 1;
      const suma = sumaPrevia + estrellas;

      transaction.set(
        userRef,
        {
          totalCalificaciones: total,
          sumaEstrellas: suma,
          ratingPromedio: suma / total,
        },
        { merge: true }
      );
    });
  }
);

/**
 * Notificaciones del ciclo de vida del envio para el Cliente (sprint
 * extra, Grupo D). Helper compartido por las 3 funciones de abajo -
 * evita triplicar la lectura de users/{uid}.fcmToken.
 */
async function enviarNotificacionAUsuario(
  uid: string,
  title: string,
  body: string,
  envioId: string,
  // Viaja en el payload junto a envioId para que el cliente (Sprint 14)
  // pueda decidir a qué pantalla navegar segun el tipo de aviso, no
  // siempre la misma - ver FcmService.onEnvioNotificationTap.
  tipo?: string
): Promise<void> {
  const userSnap = await admin.firestore().collection("users").doc(uid).get();
  const token = userSnap.data()?.fcmToken as string | undefined;
  if (!token) return;

  await admin.messaging().send({
    token,
    notification: { title, body },
    data: tipo ? { envioId, tipo } : { envioId },
    android: {
      priority: "high",
      notification: {
        channelId: "actualizaciones_envio",
      },
    },
  });
}

/**
 * Avisa al Cliente cuando un repartidor toma su envio directo (sin
 * negociar) - distinto de que el propio Cliente haya elegido una oferta
 * (esa es una accion suya, no hace falta avisarle de si misma).
 */
export const notificarAceptacionDirecta = onDocumentUpdated(
  "envios/{envioId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    const fueAceptacionDirecta =
      before.status === "pendiente_ofertas" &&
      after.status === "asignado" &&
      after.ofertaAceptadaId == null;
    if (!fueAceptacionDirecta) return;

    const clienteId = after.clienteId as string | undefined;
    const descripcion = (after.descripcion as string | undefined) ?? "tu envío";
    if (!clienteId) return;

    await enviarNotificacionAUsuario(
      clienteId,
      "¡Tu envío fue aceptado!",
      `Un repartidor aceptó "${descripcion}" directamente.`,
      event.params.envioId
    );
  }
);

/**
 * Avisa al Repartidor cuando el Cliente elige su contraoferta (Sprint 14)
 * - antes de esto, la unica forma de enterarse era abrir la app y
 * encontrarse el envio ya asignado en "Mis entregas" por casualidad. Es
 * el complemento de notificarAceptacionDirecta: esa avisa al Cliente
 * cuando el Repartidor toma directo, esta avisa al Repartidor cuando el
 * Cliente elige su propuesta.
 */
export const notificarOfertaAceptada = onDocumentUpdated(
  "envios/{envioId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    const fueContraofertaAceptada =
      before.ofertaAceptadaId == null && after.ofertaAceptadaId != null;
    if (!fueContraofertaAceptada) return;

    const repartidorId = after.repartidorAsignadoId as string | undefined;
    const descripcion = (after.descripcion as string | undefined) ?? "un envío";
    if (!repartidorId) return;

    await enviarNotificacionAUsuario(
      repartidorId,
      "¡Te asignaron un envío!",
      `El cliente aceptó tu propuesta para "${descripcion}".`,
      event.params.envioId,
      "oferta_aceptada"
    );
  }
);

/**
 * Avisa al Cliente cuando el repartidor confirma la recogida del paquete
 * (Sprint 8.2/8.3) - la transicion asignado -> en_curso ya existia desde
 * antes ("Iniciar viaje"), esto solo le suma el aviso; no hay un
 * EnvioStatus nuevo para "recogido".
 */
export const notificarRecogida = onDocumentUpdated(
  "envios/{envioId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    const fueRecogida =
      before.status === "asignado" && after.status === "en_curso";
    if (!fueRecogida) return;

    const clienteId = after.clienteId as string | undefined;
    const descripcion = (after.descripcion as string | undefined) ?? "tu envío";
    if (!clienteId) return;

    await enviarNotificacionAUsuario(
      clienteId,
      "Tu repartidor recogió el paquete",
      `Va en camino con "${descripcion}".`,
      event.params.envioId
    );
  }
);

/**
 * Avisa al Cliente cuando recibe una contraoferta nueva.
 */
export const notificarNuevaContraoferta = onDocumentCreated(
  "envios/{envioId}/ofertas/{ofertaId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const envioSnap = await admin
      .firestore()
      .collection("envios")
      .doc(event.params.envioId)
      .get();
    const envioData = envioSnap.data();
    const clienteId = envioData?.clienteId as string | undefined;
    if (!clienteId) return;

    const monto = snapshot.data().montoOfertadoCentavos as number | undefined;
    const montoBob = ((monto ?? 0) / 100).toFixed(2);

    await enviarNotificacionAUsuario(
      clienteId,
      "Recibiste una contraoferta",
      `Un repartidor te ofreció Bs. ${montoBob} por tu envío.`,
      event.params.envioId
    );
  }
);

const MAX_ENVIOS_A_EXPIRAR_POR_CORRIDA = 100;

/**
 * Barrido programado (primer onSchedule del proyecto): cierra los
 * envios cuya ventana de subasta ya paso sin que nadie los tomara. Los
 * pasa a "expirado" -distinto de "cancelado", que es una decision del
 * Cliente- y avisa. Corre cada 5 minutos; la ventana de subasta son 10,
 * asi que el peor caso es ~5 min de demora. Paginado con .limit() -
 * nunca una query sin cota, ni siquiera en un cron.
 */
export const expirarEnviosVencidos = onSchedule(
  "every 5 minutes",
  async () => {
    const ahora = admin.firestore.Timestamp.now();
    const snapshot = await admin
      .firestore()
      .collection("envios")
      .where("status", "==", "pendiente_ofertas")
      .where("expiraEn", "<", ahora)
      .limit(MAX_ENVIOS_A_EXPIRAR_POR_CORRIDA)
      .get();

    for (const doc of snapshot.docs) {
      await doc.ref.update({ status: "expirado" });
      const clienteId = doc.data().clienteId as string | undefined;
      const descripcion =
        (doc.data().descripcion as string | undefined) ?? "tu envío";
      if (clienteId) {
        await enviarNotificacionAUsuario(
          clienteId,
          "Se venció el tiempo de tu envío",
          `Nadie tomó "${descripcion}" a tiempo. Podés volver a publicarlo.`,
          doc.id
        );
      }
    }
  }
);
