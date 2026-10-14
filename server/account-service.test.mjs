import test from 'node:test';
import assert from 'node:assert/strict';
import https from 'node:https';
import { readFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { createAccountService } from './account-service.mjs';
import { accountStoreName, validateAccountReply } from '../entry/src/main/ets/domain/AccountSync.ts';

const record = patch => ({ id: 'note:device_a:1', kind: 'note', siteId: 'ly-erlitou', body: '城垣与道路',
  tags: ['都城研学'], updatedAt: 100, deviceId: 'device_a', deleted: false, ...patch });
const cert = readFileSync(new URL('../.local/account-sync/server.pem', import.meta.url));
const key = readFileSync(new URL('../.local/account-sync/server.key', import.meta.url));

test('HTTPS account isolation, durable merge, offline edits, tombstones, conflicts and revoked sessions', async () => {
  const root = mkdtempSync(join(tmpdir(), 'yunheji-account-test-'));
  const databasePath = join(root, 'accounts.sqlite');
  let time = Date.now();
  const service = createAccountService({ databasePath, cert, key, now: () => time });
  await new Promise(resolve => service.server.listen(0, '127.0.0.1', resolve));
  const port = service.server.address().port;
  const request = (path, body, token = '') => new Promise((resolve, reject) => {
    const req = https.request({ hostname: '127.0.0.1', port, path, method: 'POST', ca: cert,
      headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) } }, res => {
      let data = '';
      res.on('data', chunk => { data += chunk; });
      res.on('end', () => resolve({ status: res.statusCode, value: JSON.parse(data) }));
    });
    req.on('error', reject); req.end(JSON.stringify(body));
  });
  try {
    const a = (await request('/auth/register', { username: 'test_account_a', password: 'secure_test_password_a' })).value;
    assert.equal((await request('/auth/login', { username: 'test_account_a', password: 'wrong_password' })).status, 401);
    const b = (await request('/auth/login', { username: 'TEST_ACCOUNT_A', password: 'secure_test_password_a' })).value;
    assert.equal(a.accountId, b.accountId);
    const other = (await request('/auth/register', { username: 'test_account_b', password: 'secure_test_password_b' })).value;
    assert.notEqual(accountStoreName(a.accountId), accountStoreName(other.accountId));
    assert.throws(() => accountStoreName('../guest'));
    const sync = (session, deviceId, records) => request('/sync', { deviceId, records }, session.token);
    await sync(a, 'device_a', [record()]);
    const pulled = (await sync(b, 'device_b', [])).value;
    assert.equal(pulled.records[0].body, '城垣与道路');
    assert.equal(pulled.otherDevices, 1);
    validateAccountReply(pulled, a.accountId);
    assert.throws(() => validateAccountReply(pulled, other.accountId));
    assert.deepEqual((await sync(other, 'device_c', [])).value.records, []);
    await sync(b, 'device_b', [record({ body: '离线后的新观察', deviceId: 'device_b', updatedAt: 200 })]);
    const stale = (await sync(a, 'device_a', [record()])).value;
    assert.equal(stale.records[0].body, '离线后的新观察');
    assert.ok(stale.conflictCount > 0);
    await sync(a, 'device_a', [record({ deleted: true, updatedAt: 300 })]);
    assert.equal((await sync(b, 'device_b', [record()])).value.records[0].deleted, true);
    assert.equal((await sync(b, 'device_b', [record({ tags: Array(21).fill('越界') })])).status, 400);
    assert.equal((await sync(b, 'device_b', [record({ updatedAt: time + 600000 })])).value.code, 'ACCOUNT_TIME_INVALID');
    const before = (await sync(a, 'device_a', [])).value.records;
    assert.equal(before.length, 1); assert.equal(before[0].deleted, true);
    await request('/auth/logout', {}, b.token);
    assert.equal((await sync(b, 'device_b', [])).status, 401);
    time += 46000;
    assert.equal((await sync(a, 'device_a', [])).value.otherDevices, 0);
    const audit = new DatabaseSync(databasePath);
    const persisted = audit.prepare('SELECT * FROM accounts WHERE id=?').get(a.accountId);
    assert.ok(!persisted.password_hash.includes('secure_test'));
    assert.equal(persisted.password_hash.length, 128);
    assert.ok(!JSON.stringify(audit.prepare('SELECT * FROM sessions').all()).includes(a.token));
    audit.close();
  } finally { await service.close(); }
  const reopened = createAccountService({ databasePath, cert, key });
  const audit = new DatabaseSync(databasePath);
  assert.equal(JSON.parse(audit.prepare('SELECT records FROM accounts WHERE username=?').get('test_account_a').records)[0].deleted, true);
  audit.close();
  // 未监听的 service.close 也须关闭 SQLite。
  await reopened.close();
  rmSync(root, { recursive: true, force: true });
});
