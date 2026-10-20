import https from 'node:https';
import { readFileSync, mkdirSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { randomBytes, scrypt, timingSafeEqual, createHash } from 'node:crypto';
import { promisify } from 'node:util';
import { DatabaseSync } from 'node:sqlite';
import { pathToFileURL } from 'node:url';
import { mergeRecords, parseSnapshot } from '../entry/src/main/ets/domain/ArchiveDomain.ts';
import { validateAccountInput, validateServiceEndpoint } from '../entry/src/main/ets/domain/AccountSync.ts';
import { createAiObservationService, describeAiConfiguration, loadAiConfiguration } from './ai-observation.mjs';

const derivePassword = promisify(scrypt);
const digest = value => createHash('sha256').update(value).digest('hex');
const fail = (code, status = 400) => Object.assign(new Error(code), { status });
const sessionDuration = 12 * 60 * 60 * 1000;

// 独立账号服务只实现已授权的演示范围：注册 / 登录、账号隔离、真实 HTTPS 同步。
// SQLite 持久化记录与冲突版本；不把网络传输宣传为鸿蒙分布式数据库。
export function createAccountService({ databasePath, cert, key, now = Date.now, ai = undefined }) {
  const db = new DatabaseSync(databasePath);
  db.exec(`PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON;
    CREATE TABLE IF NOT EXISTS accounts(id TEXT PRIMARY KEY, username TEXT UNIQUE NOT NULL,
      salt TEXT NOT NULL, password_hash TEXT NOT NULL, records TEXT NOT NULL DEFAULT '[]');
    CREATE TABLE IF NOT EXISTS sessions(token_hash TEXT PRIMARY KEY, account_id TEXT NOT NULL
      REFERENCES accounts(id), expires_at INTEGER NOT NULL, device_id TEXT, touched_at INTEGER NOT NULL);
    CREATE TABLE IF NOT EXISTS conflicts(account_id TEXT NOT NULL REFERENCES accounts(id),
      content_hash TEXT NOT NULL, record TEXT NOT NULL, PRIMARY KEY(account_id,content_hash));`);
  const limits = new Map();
  const aiLimits = new Map();
  function rateLimit(key) {
    const bucket = limits.get(key) ?? { count: 0, until: now() + 60000 };
    if (bucket.until < now()) { bucket.count = 0; bucket.until = now() + 60000; }
    bucket.count++;
    limits.set(key, bucket);
    if (limits.size > 2000) for (const [name, value] of limits) if (value.until < now()) limits.delete(name);
    if (bucket.count > 15) throw fail('ACCOUNT_RATE_LIMITED', 429);
  }
  function aiRateLimit(accountId) {
    // 在线模型有真实费用，按已认证账号而不是 IP 限流；与登录限流分开，避免互相吞配额。
    const bucket = aiLimits.get(accountId) ?? { count: 0, until: now() + 60000 };
    if (bucket.until < now()) { bucket.count = 0; bucket.until = now() + 60000; }
    bucket.count++;
    aiLimits.set(accountId, bucket);
    if (aiLimits.size > 2000) for (const [name, value] of aiLimits) if (value.until < now()) aiLimits.delete(name);
    if (bucket.count > 20) throw fail('AI_RATE_LIMITED', 429);
  }
  function send(res, status, value) {
    res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
    res.end(JSON.stringify(value));
  }
  async function readBody(req) {
    const chunks = [];
    let bytes = 0;
    for await (const chunk of req) {
      bytes += chunk.length;
      if (bytes > 8 * 1024 * 1024) throw fail('ACCOUNT_PAYLOAD_TOO_LARGE', 413);
      chunks.push(chunk);
    }
    try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); }
    catch { throw fail('ACCOUNT_INVALID_REQUEST'); }
  }
  function authorize(req) {
    const bearer = req.headers.authorization ?? '';
    if (!/^Bearer [a-f0-9]{64}$/.test(bearer)) throw fail('ACCOUNT_SESSION_EXPIRED', 401);
    const tokenHash = digest(bearer.slice(7));
    const session = db.prepare('SELECT * FROM sessions WHERE token_hash=? AND expires_at>?').get(tokenHash, now());
    if (!session) throw fail('ACCOUNT_SESSION_EXPIRED', 401);
    return session;
  }
  const server = https.createServer({ cert, key, minVersion: 'TLSv1.2' }, async (req, res) => {
    try {
      const path = req.url;
      if (req.method === 'GET' && path === '/health') {
        send(res, 200, { service: 'yunheji-account', version: 1 }); return;
      }
      if (req.method !== 'POST') throw fail('ACCOUNT_NOT_FOUND', 404);
      if (path === '/auth/register' || path === '/auth/login') {
        const body = await readBody(req);
        if (typeof body.username !== 'string' || typeof body.password !== 'string') throw fail('ACCOUNT_INVALID_REQUEST');
        validateAccountInput(body.username, body.password);
        const username = body.username.trim().toLowerCase();
        rateLimit(`${req.socket.remoteAddress}:${username}`);
        let account = db.prepare('SELECT * FROM accounts WHERE username=?').get(username);
        if (path === '/auth/register') {
          if (account) throw fail('ACCOUNT_EXISTS', 409);
          const salt = randomBytes(16).toString('hex');
          const hash = (await derivePassword(body.password, salt, 64)).toString('hex');
          const id = randomBytes(16).toString('hex');
          try { db.prepare('INSERT INTO accounts(id,username,salt,password_hash) VALUES(?,?,?,?)').run(id, username, salt, hash); }
          catch (error) { if (error.code === 'ERR_SQLITE_ERROR') throw fail('ACCOUNT_EXISTS', 409); throw error; }
          account = { id, username };
        } else {
          // 即使账号不存在也计算哈希，错误统一显示，避免用返回差异探测账号。
          const hash = await derivePassword(body.password, account?.salt ?? '00000000000000000000000000000000', 64);
          if (!account || !timingSafeEqual(hash, Buffer.from(account.password_hash, 'hex'))) {
            throw fail('ACCOUNT_INVALID_CREDENTIALS', 401);
          }
        }
        const token = randomBytes(32).toString('hex');
        const expiresAt = now() + sessionDuration;
        db.prepare('DELETE FROM sessions WHERE expires_at<=?').run(now());
        db.prepare('INSERT INTO sessions(token_hash,account_id,expires_at,touched_at) VALUES(?,?,?,?)')
          .run(digest(token), account.id, expiresAt, now());
        send(res, 200, { accountId: account.id, username, token, expiresAt }); return;
      }
      const session = authorize(req);
      if (path === '/auth/logout') {
        db.prepare('DELETE FROM sessions WHERE token_hash=?').run(session.token_hash);
        send(res, 200, { loggedOut: true }); return;
      }
      if (path === '/ai/observe') {
        // AI 路由在现有 /sync 排他判断之前分派，不占用同步数据库事务；仍要求已认证账号。
        if (!ai || !ai.available) throw fail('AI_NOT_CONFIGURED', 503);
        aiRateLimit(session.account_id);
        const body = await readBody(req);
        const reply = await ai.run(body, session);
        send(res, 200, reply); return;
      }
      if (path !== '/sync') throw fail('ACCOUNT_NOT_FOUND', 404);
      const body = await readBody(req);
      if (!body || typeof body.deviceId !== 'string' || !/^[a-zA-Z0-9_-]{1,128}$/.test(body.deviceId)) {
        throw fail('ACCOUNT_INVALID_REQUEST');
      }
      let incoming;
      try {
        incoming = parseSnapshot(JSON.stringify({ schemaVersion: 1, deviceId: body.deviceId,
          records: body.records, lightEnabled: true, reducedMotion: false })).records;
      } catch { throw fail('ACCOUNT_INVALID_RESPONSE'); }
      if (incoming.some(record => record.updatedAt > now() + 5 * 60 * 1000)) throw fail('ACCOUNT_TIME_INVALID');
      // 事务内读取最新记录再合并，避免两个异步请求互相覆盖。服务端保留墓碑、
      // 落败版本；不根据客户端账号参数选库，隔离身份只能取自已验证的会话。
      db.exec('BEGIN IMMEDIATE');
      let merged;
      try {
        const account = db.prepare('SELECT records FROM accounts WHERE id=?').get(session.account_id);
        merged = mergeRecords(JSON.parse(account.records), incoming);
        if (merged.records.length > 10000) throw fail('ACCOUNT_RECORD_LIMIT');
        db.prepare('UPDATE accounts SET records=? WHERE id=?').run(JSON.stringify(merged.records), session.account_id);
        const insertConflict = db.prepare('INSERT OR IGNORE INTO conflicts(account_id,content_hash,record) VALUES(?,?,?)');
        for (const record of merged.conflicts) {
          const raw = JSON.stringify(record);
          insertConflict.run(session.account_id, digest(raw), raw);
        }
        db.prepare('UPDATE sessions SET device_id=?,touched_at=? WHERE token_hash=?')
          .run(body.deviceId, now(), session.token_hash);
        db.exec('COMMIT');
      } catch (error) { db.exec('ROLLBACK'); throw error; }
      const online = db.prepare('SELECT COUNT(DISTINCT device_id) AS n FROM sessions WHERE account_id=? AND expires_at>? AND touched_at>? AND device_id<>?')
        .get(session.account_id, now(), now() - 45000, body.deviceId).n;
      const conflictCount = db.prepare('SELECT COUNT(*) AS n FROM conflicts WHERE account_id=?').get(session.account_id).n;
      send(res, 200, { accountId: session.account_id, records: merged.records,
        otherDevices: online, conflictCount, serverTime: now() });
    } catch (error) {
      // 账号错误与 AI 错误都只返回稳定的类别码；供应商状态、密钥和原始正文不进入响应或日志。
      const known = typeof error.message === 'string' && /^(ACCOUNT|AI)_[A-Z_]+$/.test(error.message);
      const code = known ? error.message : 'ACCOUNT_SERVICE_ERROR';
      const expected = code !== 'ACCOUNT_SERVICE_ERROR';
      send(res, expected ? (error.status ?? 400) : 500, { code });
      // 不记录 URL 参数、账号、正文、密码、访问令牌或模型问题；错误日志只保留类别。
      if (!expected) process.stderr.write('账号服务处理失败：ACCOUNT_SERVICE_ERROR\n');
    }
  });
  server.requestTimeout = 15000;
  server.headersTimeout = 10000;
  return { server, close: () => { server.closeAllConnections(); return new Promise(resolveClose => server.close(() => { db.close(); resolveClose(); })); } };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const rootIndex = process.argv.indexOf('--root');
  const root = resolve(rootIndex >= 0 ? process.argv[rootIndex + 1] : '.local/account-sync');
  mkdirSync(root, { recursive: true });
  const config = JSON.parse(readFileSync(join(root, 'service.json'), 'utf8').replace(/^\uFEFF/, ''));
  // 模型配置不进仓库：默认读取被忽略的 .local/ai-observation/config.json，也可用 --ai-config 指定。
  const aiConfigIndex = process.argv.indexOf('--ai-config');
  const aiConfigPath = aiConfigIndex >= 0 ? resolve(process.argv[aiConfigIndex + 1]) : join(root, '..', 'ai-observation', 'config.json');
  let aiService;
  try {
    aiService = createAiObservationService({ configuration: loadAiConfiguration({ configPath: aiConfigPath }) });
  } catch {
    // 配置损坏时明确保持未配置；不要用示例回复冒充在线 AI，也不影响账号与同步。
    aiService = createAiObservationService({ configuration: { configured: false } });
  }
  const service = createAccountService({ databasePath: join(root, 'accounts.sqlite'),
    cert: readFileSync(join(root, 'server.pem')), key: readFileSync(join(root, 'server.key')), ai: aiService });
  // 监听地址与客户端共用同一条领域规则：默认回环；局域网演示时绑定指定私有 IPv4。
  // 不默认监听 0.0.0.0，避免把调试服务无意暴露到其他网卡。
  const host = typeof config.host === 'string' && config.host ? config.host : '127.0.0.1';
  if (!validateServiceEndpoint(`https://${host}:${config.port}`, true)) {
    throw new Error('服务监听地址只支持 localhost、127.0.0.0/8 或私有 IPv4。');
  }
  service.server.listen(config.port, host, () => {
    const ai = describeAiConfiguration(aiService.describe());
    process.stdout.write(`云河纪账号服务已启动：HTTPS / ${host}:${config.port}\n` +
      `AI 观察导览：${ai.configured ? `已配置 ${ai.provider}/${ai.model}` : '未配置（/ai/observe 返回 AI_NOT_CONFIGURED）'}\n`);
  });
  const stop = async () => { await service.close(); process.exit(0); };
  process.on('SIGTERM', stop);
  process.on('SIGINT', stop);
}
