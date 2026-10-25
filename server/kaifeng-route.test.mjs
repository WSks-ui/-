import test from 'node:test';
import assert from 'node:assert/strict';
import https from 'node:https';
import { readFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createAccountService } from './account-service.mjs';

// 只验证 /ai/kaifeng 的路由、鉴权与“未配置”回退；模型本身在 kaifeng-ai.test.mjs 用替身覆盖。
// 不调用真实供应商，也不把账号、令牌或请求体写入日志。

const cert = readFileSync(new URL('../.local/account-sync/server.pem', import.meta.url));
const key = readFileSync(new URL('../.local/account-sync/server.key', import.meta.url));

function listen(service) {
  return new Promise(resolve => service.server.listen(0, '127.0.0.1', resolve));
}

test('kaifeng ai route requires a session and returns the configured service reply', async () => {
  const root = mkdtempSync(join(tmpdir(), 'yunheji-kaifeng-route-'));
  const calls = [];
  const kaifengAi = {
    available: true,
    run: async body => {
      calls.push(body);
      return { answer: '州桥低平，不通舟船。', cites: ['zf-low-flat'], anchor: 'bridge', refused: false };
    }
  };
  const service = createAccountService({ databasePath: join(root, 'accounts.sqlite'), cert, key, kaifengAi });
  await listen(service);
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
    const account = (await request('/auth/register', { username: 'kaifeng_ai_route', password: 'kaifeng_route_password' })).value;
    assert.equal((await request('/ai/kaifeng', { siteId: 'kf-zhouqiao' })).status, 401);
    const reply = await request('/ai/kaifeng',
      { siteId: 'kf-zhouqiao', mode: 'ask', question: '州桥为什么低平？', draft: '', city: '' }, account.token);
    assert.equal(reply.status, 200);
    assert.equal(reply.value.cites[0], 'zf-low-flat');
    assert.equal(calls.length, 1);
  } finally {
    await service.close();
    rmSync(root, { recursive: true, force: true });
  }
});

test('kaifeng ai route reports AI_NOT_CONFIGURED instead of a fake answer', async () => {
  const root = mkdtempSync(join(tmpdir(), 'yunheji-kaifeng-route-'));
  const service = createAccountService({ databasePath: join(root, 'accounts.sqlite'), cert, key,
    kaifengAi: { available: false, run: async () => { throw new Error('should not run'); } } });
  await listen(service);
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
    const account = (await request('/auth/register', { username: 'kaifeng_ai_empty', password: 'kaifeng_empty_password' })).value;
    const reply = await request('/ai/kaifeng',
      { siteId: 'kf-zhouqiao', mode: 'ask', question: '州桥为什么低平？' }, account.token);
    assert.equal(reply.status, 503);
    assert.equal(reply.value.code, 'AI_NOT_CONFIGURED');
  } finally {
    await service.close();
    rmSync(root, { recursive: true, force: true });
  }
});
