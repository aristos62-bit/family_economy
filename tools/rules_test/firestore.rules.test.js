// ============================================================
// FILE: firestore.rules.test.js
// Path: tools/rules_test/firestore.rules.test.js
// Ρόλος: Emulator tests για το SEC-006b guard (create-only).
// Τρέχει με: npm run test:rules
// ============================================================

const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const PROJECT_ID = 'demo-family-economy';
const RULES = fs.readFileSync(
  path.resolve(__dirname, '../../firestore.rules'),
  'utf8',
);
const UID = 'user1';
const OTHER = 'user2';

let testEnv;
let passed = 0;

function db(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

async function seed(userId, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().collection('users').doc(userId).set(data);
  });
}

async function seedDoc(userId, collection, id, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .collection('users')
      .doc(userId)
      .collection(collection)
      .doc(id)
      .set(data);
  });
}

async function check(name, fn) {
  await testEnv.clearFirestore();
  await fn();
  passed += 1;
  console.log(`PASS  ${name}`);
}

async function main() {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });

  try {
    await check('create υποσυλλογής με ενεργό root -> allow', async () => {
      await seed(UID, { deleted: false });
      await assertSucceeds(
        db(UID)
          .collection('users')
          .doc(UID)
          .collection('transactions')
          .add({ amount: 1 }),
      );
    });

    await check('create με deleted:true -> deny', async () => {
      await seed(UID, { deleted: true });
      await assertFails(
        db(UID)
          .collection('users')
          .doc(UID)
          .collection('transactions')
          .add({ amount: 1 }),
      );
    });

    await check('create χωρίς root doc -> deny', async () => {
      await assertFails(
        db(UID)
          .collection('users')
          .doc(UID)
          .collection('transactions')
          .add({ amount: 1 }),
      );
    });

    await check('delete υποσυλλογής με deleted:true -> allow (cascade)', async () => {
      await seed(UID, { deleted: true });
      await seedDoc(UID, 'transactions', 't1', { amount: 1 });
      await assertSucceeds(
        db(UID)
          .collection('users')
          .doc(UID)
          .collection('transactions')
          .doc('t1')
          .delete(),
      );
    });

    await check('root doc create -> allow (onboarding)', async () => {
      await assertSucceeds(
        db(UID).collection('users').doc(UID).set({ deleted: false }),
      );
    });

    await check('create σε ξένο uid -> deny', async () => {
      await seed(OTHER, { deleted: false });
      await assertFails(
        db(UID)
          .collection('users')
          .doc(OTHER)
          .collection('transactions')
          .add({ amount: 1 }),
      );
    });

    console.log(`\n${passed} checks passed`);
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
