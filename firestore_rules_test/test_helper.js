import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export async function createTestEnv() {
  const rulesPath = path.resolve(__dirname, '..', 'firestore.rules');
  const rules = fs.readFileSync(rulesPath, 'utf8');

  let host = '127.0.0.1';
  let port = 8080;
  if (process.env.FIRESTORE_EMULATOR_HOST) {
    const [h, p] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
    host = h;
    port = parseInt(p, 10);
  }

  const testEnv = await initializeTestEnvironment({
    projectId: 'demo-dnd5e',
    firestore: {
      rules,
      host,
      port,
    },
  });

  return testEnv;
}
