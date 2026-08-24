/**
 * Script puntual para crear el primer usuario admin (o promover a otro).
 * No se despliega junto a las Cloud Functions.
 *
 * Uso:
 *   1. Firebase Console -> Project Settings -> Service Accounts ->
 *      Generate new private key -> guardar como
 *      functions/scripts/serviceAccountKey.json (ya esta en .gitignore).
 *   2. npx ts-node scripts/setAdminClaim.ts <uid>
 */
import { readFileSync } from "fs";
import * as admin from "firebase-admin";

const [, , uid] = process.argv;

if (!uid) {
  console.error("Uso: npx ts-node scripts/setAdminClaim.ts <uid>");
  process.exit(1);
}

const serviceAccountPath =
  process.env.SERVICE_ACCOUNT_KEY_PATH ?? `${__dirname}/serviceAccountKey.json`;
const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, "utf8"));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

async function main() {
  await admin.auth().setCustomUserClaims(uid, { role: "admin", isVerified: true });
  await admin
    .firestore()
    .collection("users")
    .doc(uid)
    .set(
      {
        role: "admin",
        isVerified: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  console.log(`OK: ${uid} ahora tiene el rol admin.`);
  process.exit(0);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
