import { before, after, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { collection, collectionGroup, doc, setDoc, getDoc, getDocs, deleteDoc, updateDoc,
         query, orderBy, documentId, limit, Timestamp, deleteField } from 'firebase/firestore';

let env;
const uid = 'rules-player-a';
const other = 'rules-player-b';
const id = '00000000-0000-0000-0000-000000000001';
const authenticated = user => env.authenticatedContext(user, { firebase: { sign_in_provider: 'google.com' } }).firestore();
const ref = (db, user = uid, gameID = id) => doc(db, `users/${user}/games/${gameID}`);
const valid = (fields = {}) => ({ schemaVersion: 1, gameID: id, ownerID: uid,
  finishedAt: Timestamp.fromDate(new Date()), difficulty: 'easy', outcome: 'won', duration: 42.5, mistakes: 0, ...fields });

before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-sudokuly', firestore: {
    host: '127.0.0.1', port: 8080, rules: await readFile(new URL('../../firestore.rules', import.meta.url), 'utf8') } });
});
beforeEach(async () => { await env.clearFirestore(); });
after(async () => { await env.cleanup(); });

test('owner can create, read, page and retry an identical result', async () => {
  const db = authenticated(uid), data = valid();
  await assertSucceeds(setDoc(ref(db), data));
  await assertSucceeds(setDoc(ref(db), data));
  assert.equal((await assertSucceeds(getDoc(ref(db)))).data().duration, 42.5);
  const page = await assertSucceeds(getDocs(query(collection(db, `users/${uid}/games`), orderBy('finishedAt', 'desc'), orderBy(documentId(), 'desc'), limit(100))));
  assert.equal(page.size, 1);
});
test('all three outcomes and offline past timestamps can be saved', async () => {
  const db = authenticated(uid);
  for (const [outcome, duration, mistakes] of [['won', 100, 1], ['mistakes', 90, 3], ['timedOut', 900, 2]]) {
    const gameID = randomUUID().toUpperCase();
    await assertSucceeds(setDoc(ref(db, uid, gameID), valid({ gameID, outcome, duration, mistakes, finishedAt: Timestamp.fromDate(new Date('2025-01-01')) })));
  }
});
test('unsigned and anonymous callers cannot get, list, create or delete history', async () => {
  await setDoc(ref(authenticated(uid)), valid());
  const callers = [env.unauthenticatedContext().firestore(), env.authenticatedContext(uid, { firebase: { sign_in_provider: 'anonymous' } }).firestore()];
  for (const db of callers) {
    await assertFails(getDoc(ref(db)));
    await assertFails(getDocs(query(collection(db, `users/${uid}/games`), limit(100))));
    await assertFails(setDoc(ref(db), valid()));
    await assertFails(deleteDoc(ref(db)));
  }
});
test('another UID cannot read, query, write, change or delete this user’s game', async () => {
  await setDoc(ref(authenticated(uid)), valid());
  const db = authenticated(other);
  await assertFails(getDoc(ref(db)));
  await assertFails(getDocs(query(collection(db, `users/${uid}/games`), limit(100))));
  await assertFails(setDoc(ref(db), valid()));
  await assertFails(updateDoc(ref(db), { ownerID: other }));
  await assertFails(deleteDoc(ref(db)));
  await assertSucceeds(setDoc(ref(db, other), valid({ ownerID: other })));
});
test('unknown collections, parent profiles and a global collection-group query stay closed', async () => {
  const db = authenticated(uid);
  await setDoc(ref(db), valid());
  await assertFails(setDoc(doc(db, `users/${uid}`), { isAdmin: true }));
  await assertFails(getDoc(doc(db, `users/${other}`)));
  await assertFails(setDoc(doc(db, 'public/arbitrary'), { value: 1 }));
  await assertFails(getDocs(query(collectionGroup(db, 'games'), limit(100))));
});
test('list must be bounded, including the 400-item account cleanup query', async () => {
  const db = authenticated(uid), games = collection(db, `users/${uid}/games`);
  await assertFails(getDocs(games));
  await assertFails(getDocs(query(games, limit(401))));
  await assertSucceeds(getDocs(query(games, limit(400))));
});
test('result fields are immutable and ownership cannot be reassigned', async () => {
  const db = authenticated(uid);
  await setDoc(ref(db), valid());
  for (const fields of [{ ownerID: other }, { duration: 43 }, { finishedAt: Timestamp.fromDate(new Date('2025-01-01')) },
    { outcome: 'mistakes', mistakes: 3 }, { difficulty: 'hard' }, { schemaVersion: 2 }]) {
    await assertFails(updateDoc(ref(db), fields));
  }
});

const invalidCases = [
  ['owner mismatch', { ownerID: other }], ['empty owner', { ownerID: '' }],
  ['oversized owner', { ownerID: 'x'.repeat(129) }], ['ID mismatch', { gameID: randomUUID() }],
  ['oversized ID', { gameID: 'x'.repeat(10000) }], ['invalid level', { difficulty: 'master' }],
  ['oversized level', { difficulty: 'x'.repeat(10000) }], ['invalid outcome', { outcome: 'active' }],
  ['oversized outcome', { outcome: 'x'.repeat(10000) }], ['wrong date type', { finishedAt: 'today' }],
  ['future date', { finishedAt: Timestamp.fromDate(new Date(Date.now() + 3600000)) }],
  ['too early date', { finishedAt: Timestamp.fromDate(new Date('1999-01-01')) }],
  ['wrong duration type', { duration: '42' }], ['negative duration', { duration: -1 }],
  ['deadline overflow', { duration: 901 }], ['infinite duration', { duration: Infinity }],
  ['NaN duration', { duration: NaN }], ['fractional mistakes', { mistakes: 1.5 }],
  ['wrong mistakes type', { mistakes: '0' }], ['negative mistakes', { mistakes: -1 }],
  ['too many mistakes', { mistakes: 4 }], ['win with three mistakes', { mistakes: 3 }],
  ['early timeout', { outcome: 'timedOut', duration: 42 }],
  ['mistakes without three attempts', { outcome: 'mistakes', mistakes: 2 }],
  ['missing version', { schemaVersion: deleteField() }], ['wrong version', { schemaVersion: 2 }],
  ['extra role', { isAdmin: true }], ['extra large payload', { extraData: 'x'.repeat(100000) }],
  ['extra traversal path', { imageBucket: '../users/other' }], ['extra array', { board: Array(81).fill(5) }]
];
for (const [name, mutation] of invalidCases) {
  test(`reject ${name} on create and update`, async () => {
    const db = authenticated(uid);
    const base = valid();
    const data = { ...base, ...mutation };
    if (name === 'missing version') delete data.schemaVersion;
    await assertFails(setDoc(ref(db), data));
    await setDoc(ref(db), base);
    await assertFails(updateDoc(ref(db), mutation));
  });
}
test('every required field is mandatory on create and update', async () => {
  const db = authenticated(uid);
  for (const field of Object.keys(valid())) {
    const gameID = randomUUID().toUpperCase();
    const base = valid({ gameID });
    const data = { ...base }; delete data[field];
    await assertFails(setDoc(ref(db, uid, gameID), data));
    await setDoc(ref(db, uid, gameID), base);
    await assertFails(updateDoc(ref(db, uid, gameID), { [field]: deleteField() }));
  }
});
test('owner can delete history for account erasure without granting delete to others', async () => {
  const db = authenticated(uid);
  await setDoc(ref(db), valid());
  await assertSucceeds(deleteDoc(ref(db)));
  assert.equal((await getDoc(ref(db))).exists(), false);
});
