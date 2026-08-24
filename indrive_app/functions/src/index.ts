import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

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
