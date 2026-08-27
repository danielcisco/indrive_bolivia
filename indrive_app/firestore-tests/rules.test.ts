/**
 * Tests de firestore.rules contra el emulador (no el proyecto real) — se
 * corren con:
 *   firebase emulators:exec --only firestore "cd firestore-tests && npm test"
 * desde D:\indrive_bolivia\indrive_app.
 *
 * Alcance deliberadamente no exhaustivo: cubre las reglas donde esta
 * sesión encontró bugs reales (users/{uid} con role/isVerified ausentes,
 * perfiles_publicos recién agregada) y la regla de mayor riesgo del
 * proyecto (prevención de doble asignación de un envío).
 */
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { GeoPoint, doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';
import { afterAll, afterEach, beforeAll, describe, it } from 'vitest';

let testEnv: RulesTestEnvironment;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'indrive-rules-test',
    firestore: {
      rules: readFileSync('../firestore.rules', 'utf8'),
      host: 'localhost',
      port: 8080,
    },
  });
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

afterAll(async () => {
  await testEnv.cleanup();
});

describe('users/{uid}', () => {
  it('el dueño puede crear su doc inicial sin role/isVerified', async () => {
    const cliente = testEnv.authenticatedContext('cliente1');
    await assertSucceeds(
      setDoc(doc(cliente.firestore(), 'users/cliente1'), { nombre: 'Ana' }),
    );
  });

  it('rechaza crear el doc propio con role incluido', async () => {
    const cliente = testEnv.authenticatedContext('cliente1');
    await assertFails(
      setDoc(doc(cliente.firestore(), 'users/cliente1'), {
        nombre: 'Ana',
        role: 'admin',
      }),
    );
  });

  it('permite agregar cedulaUrl cuando role/isVerified todavía no existen (bug real de esta sesión)', async () => {
    const uid = 'repartidor1';
    await testEnv.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), `users/${uid}`), {
        nombre: 'Beto',
        nick: 'beto',
      }),
    );
    const repartidor = testEnv.authenticatedContext(uid);
    await assertSucceeds(
      updateDoc(doc(repartidor.firestore(), `users/${uid}`), {
        cedulaUrl: 'https://ejemplo/foto.jpg',
      }),
    );
  });

  it('rechaza que el dueño cambie role/isVerified/isActive por su cuenta', async () => {
    const uid = 'repartidor2';
    await testEnv.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), `users/${uid}`), {
        nombre: 'Cato',
        role: 'repartidor',
        isVerified: false,
      }),
    );
    const repartidor = testEnv.authenticatedContext(uid, {
      role: 'repartidor',
      isVerified: false,
    });
    await assertFails(
      updateDoc(doc(repartidor.firestore(), `users/${uid}`), {
        isVerified: true,
      }),
    );
  });

  it('solo el dueño o un admin pueden leer', async () => {
    const uid = 'cliente3';
    await testEnv.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), `users/${uid}`), { nombre: 'Dora' }),
    );
    const otro = testEnv.authenticatedContext('otro-uid');
    await assertFails(getDoc(doc(otro.firestore(), `users/${uid}`)));

    const admin = testEnv.authenticatedContext('admin1', { role: 'admin' });
    await assertSucceeds(getDoc(doc(admin.firestore(), `users/${uid}`)));
  });
});

describe('perfiles_publicos/{uid}', () => {
  it('cualquier usuario autenticado puede leer', async () => {
    const uid = 'repartidor4';
    await testEnv.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), `perfiles_publicos/${uid}`), {
        nombre: 'Eva',
        apellido: 'Lopez',
        nick: 'eva',
      }),
    );
    const otro = testEnv.authenticatedContext('otro-uid');
    await assertSucceeds(
      getDoc(doc(otro.firestore(), `perfiles_publicos/${uid}`)),
    );
  });

  it('el dueño puede escribir solo con los 4 campos permitidos', async () => {
    const uid = 'repartidor5';
    const dueno = testEnv.authenticatedContext(uid);
    await assertSucceeds(
      setDoc(doc(dueno.firestore(), `perfiles_publicos/${uid}`), {
        nombre: 'Fabi',
        apellido: 'Ruiz',
        nick: 'fabi',
        avatarId: 'moto_azul',
      }),
    );
  });

  it('rechaza un campo extra no permitido', async () => {
    const uid = 'repartidor6';
    const dueno = testEnv.authenticatedContext(uid);
    await assertFails(
      setDoc(doc(dueno.firestore(), `perfiles_publicos/${uid}`), {
        nombre: 'Gus',
        apellido: 'Diaz',
        nick: 'gus',
        telefono: '+59171234567',
      }),
    );
  });

  it('rechaza que alguien escriba el perfil público de otro uid', async () => {
    const intruso = testEnv.authenticatedContext('intruso');
    await assertFails(
      setDoc(doc(intruso.firestore(), 'perfiles_publicos/victima'), {
        nombre: 'X',
        apellido: 'Y',
        nick: 'x',
      }),
    );
  });
});

describe('envios/{envioId}: creación y prevención de doble asignación', () => {
  const envioBase = {
    clienteId: 'cliente10',
    descripcion: 'Paquete chico',
    origen: new GeoPoint(-22.09, -65.6),
    origenGeohash: '6x1qhu',
    destino: new GeoPoint(-22.1, -65.59),
    montoOfertadoInicialCentavos: 1500,
    status: 'pendiente_ofertas',
    repartidorAsignadoId: null,
    ofertaAceptadaId: null,
    categoria: 'documentos',
  };

  it('el cliente dueño puede crear un envío pendiente válido', async () => {
    const cliente = testEnv.authenticatedContext('cliente10', {
      role: 'cliente',
      isVerified: true,
    });
    await assertSucceeds(
      setDoc(doc(cliente.firestore(), 'envios/envioA'), envioBase),
    );
  });

  it('rechaza crear un envío a nombre de otro clienteId', async () => {
    const cliente = testEnv.authenticatedContext('cliente10', {
      role: 'cliente',
      isVerified: true,
    });
    await assertFails(
      setDoc(doc(cliente.firestore(), 'envios/envioB'), {
        ...envioBase,
        clienteId: 'otro-cliente',
      }),
    );
  });

  it('rechaza que un cliente NO verificado cree un envío (Sprint 10)', async () => {
    const cliente = testEnv.authenticatedContext('cliente10', {
      role: 'cliente',
      isVerified: false,
    });
    await assertFails(
      setDoc(doc(cliente.firestore(), 'envios/envioNoVerificado'), envioBase),
    );
  });

  it('un repartidor verificado puede aceptar un envío pendiente', async () => {
    await testEnv.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'envios/envioC'), envioBase),
    );
    const repartidor = testEnv.authenticatedContext('repartidorA', {
      role: 'repartidor',
      isVerified: true,
    });
    await assertSucceeds(
      updateDoc(doc(repartidor.firestore(), 'envios/envioC'), {
        status: 'asignado',
        repartidorAsignadoId: 'repartidorA',
      }),
    );
  });

  it('un repartidor NO verificado no puede aceptar', async () => {
    await testEnv.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'envios/envioD'), envioBase),
    );
    const repartidor = testEnv.authenticatedContext('repartidorB', {
      role: 'repartidor',
      isVerified: false,
    });
    await assertFails(
      updateDoc(doc(repartidor.firestore(), 'envios/envioD'), {
        status: 'asignado',
        repartidorAsignadoId: 'repartidorB',
      }),
    );
  });

  it('un segundo repartidor no puede aceptar un envío que ya quedó asignado', async () => {
    await testEnv.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'envios/envioE'), {
        ...envioBase,
        status: 'asignado',
        repartidorAsignadoId: 'repartidorPrimero',
      }),
    );
    const segundo = testEnv.authenticatedContext('repartidorSegundo', {
      role: 'repartidor',
      isVerified: true,
    });
    await assertFails(
      updateDoc(doc(segundo.firestore(), 'envios/envioE'), {
        status: 'asignado',
        repartidorAsignadoId: 'repartidorSegundo',
      }),
    );
  });
});
