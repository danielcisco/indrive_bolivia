/**
 * Script puntual: configura CORS en el bucket de Storage para que el
 * panel Admin (Flutter Web) pueda cargar las fotos de Cédula con
 * Image.network — sin esto, el navegador bloquea la respuesta con
 * "HTTP request failed, statusCode: 0" aunque la URL sea correcta y la
 * Storage Rule permita la lectura (CORS es una restricción del navegador,
 * separada de las Rules). No se despliega junto a las Cloud Functions.
 *
 * Uso: npx ts-node scripts/setStorageCors.ts
 */
import { readFileSync } from "fs";
import * as admin from "firebase-admin";

const serviceAccountPath =
  process.env.SERVICE_ACCOUNT_KEY_PATH ?? `${__dirname}/serviceAccountKey.json`;
const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, "utf8"));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: "indrive-entregas-villazon.firebasestorage.app",
});

async function main() {
  const bucket = admin.storage().bucket();
  await bucket.setMetadata({
    cors: [
      {
        // "*" en vez de listar orígenes: `flutter run -d chrome` usa un
        // puerto localhost distinto cada vez, así que un origen fijo no
        // serviría. No afloja el control de acceso real: las URLs de
        // descarga de Storage ya dependen de su token, no de las Rules
        // en el momento de la lectura, y las Rules siguen gobernando
        // quien puede pedir esa URL desde el SDK.
        origin: ["*"],
        method: ["GET"],
        maxAgeSeconds: 3600,
      },
    ],
  });
  console.log("CORS configurado en el bucket.");
  process.exit(0);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
