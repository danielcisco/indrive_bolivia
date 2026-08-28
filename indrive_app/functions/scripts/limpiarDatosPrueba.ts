/**
 * Script puntual de limpieza (no se despliega junto a las Cloud
 * Functions): borra TODOS los usuarios/repartidores de prueba — Auth,
 * `users/`, `perfiles_publicos/`, la colección `envios/` completa (con
 * sus subcolecciones, incluidas las calificaciones), y los archivos de
 * Storage bajo `kyc/`, `personal/`, `licencia/`, `vehiculo/`,
 * `comprobantes/` y `paquetes/` — salvo la cuenta indicada en
 * `--preservar`.
 *
 * Uso (mismo patrón que setVerifiedClaim.ts):
 *   npx ts-node scripts/limpiarDatosPrueba.ts --preservar <uid>
 *
 * Agregar --dry-run para solo listar qué se borraría, sin borrar nada.
 */
import { readFileSync } from "fs";
import * as admin from "firebase-admin";

const args = process.argv.slice(2);
const preservarIndex = args.indexOf("--preservar");
const uidPreservado =
  preservarIndex !== -1 ? args[preservarIndex + 1] : undefined;
const dryRun = args.includes("--dry-run");

if (!uidPreservado) {
  console.error(
    "Uso: npx ts-node scripts/limpiarDatosPrueba.ts --preservar <uid> [--dry-run]"
  );
  process.exit(1);
}

const serviceAccountPath =
  process.env.SERVICE_ACCOUNT_KEY_PATH ?? `${__dirname}/serviceAccountKey.json`;
const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, "utf8"));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: "indrive-entregas-villazon.firebasestorage.app",
});

async function borrarAuthExcepto(uid: string) {
  let borrados = 0;
  let pageToken: string | undefined;
  do {
    const result = await admin.auth().listUsers(1000, pageToken);
    const aBorrar = result.users
      .map((u) => u.uid)
      .filter((otroUid) => otroUid !== uid);
    if (aBorrar.length > 0) {
      console.log(`Auth: ${dryRun ? "[dry-run] " : ""}borrando ${aBorrar.length} cuentas...`);
      if (!dryRun) await admin.auth().deleteUsers(aBorrar);
      borrados += aBorrar.length;
    }
    pageToken = result.pageToken;
  } while (pageToken);
  return borrados;
}

async function borrarColeccionExcepto(coleccion: string, uid: string) {
  const snapshot = await admin.firestore().collection(coleccion).get();
  const docs = snapshot.docs.filter((doc) => doc.id !== uid);
  console.log(
    `${coleccion}: ${dryRun ? "[dry-run] " : ""}borrando ${docs.length} de ${snapshot.size} documentos...`
  );
  if (!dryRun) {
    const batchSize = 400;
    for (let i = 0; i < docs.length; i += batchSize) {
      const batch = admin.firestore().batch();
      for (const doc of docs.slice(i, i + batchSize)) batch.delete(doc.ref);
      await batch.commit();
    }
  }
  return docs.length;
}

async function borrarEnviosCompleto() {
  const ref = admin.firestore().collection("envios");
  const snapshot = await ref.get();
  console.log(
    `envios: ${dryRun ? "[dry-run] " : ""}borrando ${snapshot.size} envíos (con subcolecciones)...`
  );
  if (!dryRun) {
    await admin.firestore().recursiveDelete(ref);
  }
  return snapshot.size;
}

async function borrarStorage(uidPreservado: string) {
  const bucket = admin.storage().bucket();

  // kyc/, personal/, licencia/ y vehiculo/ están organizados por
  // {uid}/... (mismo patrón), así que a todos se les aplica el mismo
  // filtro de preservación; comprobantes/ y paquetes/ están organizados
  // por {envioId}/{uid}/... y ya se borran completos junto con envios/.
  const prefijosPorUid = ["kyc/", "personal/", "licencia/", "vehiculo/"];
  const archivosPorUid = await Promise.all(
    prefijosPorUid.map((prefix) => bucket.getFiles({ prefix }))
  );
  const aBorrarPorUid = archivosPorUid.flatMap(([archivos], i) =>
    archivos.filter(
      (f) => !f.name.startsWith(`${prefijosPorUid[i]}${uidPreservado}/`)
    )
  );

  const [archivosComprobantes] = await bucket.getFiles({
    prefix: "comprobantes/",
  });
  const [archivosPaquetes] = await bucket.getFiles({ prefix: "paquetes/" });

  const total =
    aBorrarPorUid.length + archivosComprobantes.length + archivosPaquetes.length;
  console.log(
    `Storage: ${dryRun ? "[dry-run] " : ""}borrando ${total} archivos ` +
      `(kyc/personal/licencia/vehiculo: ${aBorrarPorUid.length}, comprobantes/: ${archivosComprobantes.length}, paquetes/: ${archivosPaquetes.length})...`
  );
  if (!dryRun) {
    await Promise.all(
      [...aBorrarPorUid, ...archivosComprobantes, ...archivosPaquetes].map(
        (f) => f.delete()
      )
    );
  }
  return total;
}

async function main() {
  console.log(`Preservando uid: ${uidPreservado}${dryRun ? " (DRY RUN)" : ""}`);
  const authBorrados = await borrarAuthExcepto(uidPreservado!);
  const usersBorrados = await borrarColeccionExcepto("users", uidPreservado!);
  const perfilesBorrados = await borrarColeccionExcepto(
    "perfiles_publicos",
    uidPreservado!
  );
  const enviosBorrados = await borrarEnviosCompleto();
  const archivosBorrados = await borrarStorage(uidPreservado!);

  console.log("\nResumen:");
  console.log(`  Auth: ${authBorrados}`);
  console.log(`  users/: ${usersBorrados}`);
  console.log(`  perfiles_publicos/: ${perfilesBorrados}`);
  console.log(`  envios/: ${enviosBorrados}`);
  console.log(`  Storage: ${archivosBorrados}`);
  process.exit(0);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
