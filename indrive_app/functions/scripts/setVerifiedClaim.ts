/**
 * Script puntual para marcar una cuenta (normalmente Repartidor) como
 * verificada (KYC aprobado). No se despliega junto a las Cloud Functions.
 *
 * Sustituye temporalmente el flujo de aprobación manual del panel Admin
 * (Fase 5, todavía no existe) para poder probar en desarrollo las
 * acciones que las Firestore Rules restringen a `isVerified == true`
 * (crear ofertas, aceptar un envío directo).
 *
 * Uso:
 *   1. Firebase Console -> Project Settings -> Service Accounts ->
 *      Generate new private key -> guardar como
 *      functions/scripts/serviceAccountKey.json (ya esta en .gitignore).
 *   2. npx ts-node scripts/setVerifiedClaim.ts <uid>
 */
import { readFileSync } from "fs";
import * as admin from "firebase-admin";

const [, , uid] = process.argv;

if (!uid) {
  console.error("Uso: npx ts-node scripts/setVerifiedClaim.ts <uid>");
  process.exit(1);
}

const serviceAccountPath =
  process.env.SERVICE_ACCOUNT_KEY_PATH ?? `${__dirname}/serviceAccountKey.json`;
const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, "utf8"));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

async function main() {
  const user = await admin.auth().getUser(uid);
  const role = user.customClaims?.role;
  if (!role) {
    throw new Error(
      `El usuario ${uid} todavía no tiene un rol asignado (assignInitialRole).`
    );
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
  console.log(`OK: ${uid} (role=${role}) ahora está verificado.`);
  process.exit(0);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
