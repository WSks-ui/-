import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import vm from 'node:vm';
import { domainModuleUrl } from './load-domain-module.mjs';
const domain = await import(domainModuleUrl('ArchiveDomain'));
import { ROAM_CHAPTERS, ROAM_SOURCES } from '../entry/src/main/ets/data/RoamingCatalog.ts';

const { makeRoamingMemoryContext } = await import(domainModuleUrl('Roaming'));

// 在内存中转译实际 Repository 源文件，平台替身仅用于故障注入，不进入应用包。
const require = createRequire(import.meta.url);
const ts = require(process.env.YUNHEJI_TYPESCRIPT);
const source = readFileSync(new URL('../entry/src/main/ets/data/LocalArchiveRepository.ets', import.meta.url), 'utf8');
const compiled = ts.transpileModule(source, {
  fileName: 'LocalArchiveRepository.ts',
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
}).outputText;

function fixture(seed = {}) {
  const cache = new Map(Object.entries(seed));
  let disk = new Map(cache);
  let failNextFlush = false;
  let writes = 0;
  const store = {
    async has(key) { return cache.has(key); },
    async get(key, fallback) {
      const value = cache.get(key);
      return typeof value === typeof fallback ? value : fallback;
    },
    async put(key, value) { writes++; cache.set(key, value); },
    async delete(key) { cache.delete(key); },
    async flush() {
      if (failNextFlush) { failNextFlush = false; throw new Error('DISK_FULL'); }
      disk = new Map(cache);
    }
  };
  const module = { exports: {} };
  const dependencies = {
    '@kit.ArkData': { preferences: { getPreferences: async () => store } },
    '@kit.ArkTS': { util: { generateRandomUUID: () => 'test-installation' } },
    '../domain/ArchiveDomain': domain
  };
  new vm.Script(compiled).runInNewContext({
    module, exports: module.exports,
    require(name) {
      assert.ok(name in dependencies, `Unexpected platform dependency: ${name}`);
      return dependencies[name];
    }
  });
  return {
    repo: new module.exports.LocalArchiveRepository({}),
    cache, disk: () => disk, writes: () => writes,
    failFlush: () => { failNextFlush = true; }
  };
}

test('repository initializes a genuinely absent snapshot and persists installation id', async () => {
  const f = fixture();
  const state = await f.repo.load();
  assert.equal(state.deviceId, 'test-installation');
  assert.equal(JSON.parse(f.disk().get('snapshot')).deviceId, state.deviceId);
});
test('repository reopens existing snapshot without rewriting it', async () => {
  const raw = JSON.stringify(domain.emptySnapshot('existing-device'));
  const f = fixture({ snapshot: raw });
  assert.equal((await f.repo.load()).deviceId, 'existing-device');
  assert.equal(f.writes(), 0);
});
test('repository rejects existing empty, corrupt and wrong-type values without clearing them', async () => {
  for (const value of ['', '{broken', true, 17]) {
    const f = fixture({ snapshot: value });
    await assert.rejects(f.repo.load(), /ARCHIVE_READ_FAILED/);
    assert.equal(f.cache.get('snapshot'), value);
    assert.equal(f.writes(), 0);
  }
});
test('repository does not initialize over an orphaned backup', async () => {
  const f = fixture({ previous_snapshot: JSON.stringify(domain.emptySnapshot('restore-me')) });
  await assert.rejects(f.repo.load(), /ARCHIVE_READ_FAILED/);
  assert.equal(f.writes(), 0);
});
test('failed flush leaves disk and current in-memory cache on confirmed snapshot', async () => {
  const f = fixture();
  const state = await f.repo.load();
  const before = f.disk().get('snapshot');
  state.lightEnabled = false;
  f.failFlush();
  await assert.rejects(f.repo.save(state), /ARCHIVE_WRITE_FAILED/);
  assert.equal(f.disk().get('snapshot'), before);
  assert.equal(f.cache.get('snapshot'), before);
});
test('queue recovers after a failed write', async () => {
  const f = fixture();
  const state = await f.repo.load();
  f.failFlush();
  await assert.rejects(f.repo.save({ ...state, lightEnabled: false }));
  await f.repo.save({ ...state, reducedMotion: true });
  assert.equal(JSON.parse(f.disk().get('snapshot')).reducedMotion, true);
  assert.equal(JSON.parse(f.disk().get('snapshot')).lightEnabled, true);
});
test('save captures input before caller mutates it', async () => {
  const f = fixture();
  const state = await f.repo.load();
  const saving = f.repo.save(state);
  state.reducedMotion = true;
  await saving;
  assert.equal(JSON.parse(f.disk().get('snapshot')).reducedMotion, false);
});
test('queued writes persist the last request and retain the previous confirmed version', async () => {
  const f = fixture();
  const initial = await f.repo.load();
  const first = { ...initial, lightEnabled: false };
  const second = { ...first, reducedMotion: true };
  await Promise.all([f.repo.save(first), f.repo.save(second)]);
  assert.equal(f.disk().get('snapshot'), JSON.stringify(second));
  assert.equal(f.disk().get('previous_snapshot'), JSON.stringify(first));
});
test('invalid schema is rejected before any write', async () => {
  const f = fixture();
  const state = await f.repo.load();
  const count = f.writes();
  await assert.rejects(f.repo.save({ ...state, schemaVersion: 999 }));
  assert.equal(f.writes(), count);
});

test('repository preserves frozen roaming sources and tombstones through queued persistence and reopen', async () => {
  const f = fixture();
  const state = await f.repo.load();
  const chapter = ROAM_CHAPTERS[3];
  const clue = chapter.clues[0];
  const roamingContext = makeRoamingMemoryContext(chapter, clue, clue.options[0].id, ROAM_SOURCES);
  const savedContext = structuredClone(roamingContext);
  state.records = [{
    id: 'note:roaming-repository', kind: 'note', siteId: chapter.id, body: '我想记住街与河交会的地方',
    tags: ['开封'], updatedAt: 100, deviceId: state.deviceId, deleted: false, roamingContext
  }];
  const saving = f.repo.save(state);
  state.records[0].roamingContext.sources[0].title = '保存发起后才改的草稿';
  await saving;
  const disk = JSON.parse(f.disk().get('snapshot'));
  assert.equal(disk.records[0].roamingContext.contentRevision, 1);
  assert.deepEqual(disk.records[0].roamingContext, savedContext);
  assert.deepEqual((await f.repo.load()).records[0].roamingContext, savedContext);
  const removed = domain.copySnapshot(disk);
  removed.records[0].updatedAt = 101;
  removed.records[0].deleted = true;
  const oldContext = structuredClone(savedContext);
  delete oldContext.contentRevision;
  removed.records.push({ ...disk.records[0], id: 'note:old-roaming-context', roamingContext: oldContext });
  await f.repo.save(removed);
  assert.equal((await f.repo.load()).records[0].deleted, true);
  assert.deepEqual((await f.repo.load()).records[0].roamingContext, savedContext);
  const oldReopened = (await f.repo.load()).records.find(record => record.id === 'note:old-roaming-context');
  assert.deepEqual(oldReopened.roamingContext, oldContext);
  assert.equal(Object.hasOwn(oldReopened.roamingContext, 'contentRevision'), false);
  assert.deepEqual(JSON.parse(f.disk().get('previous_snapshot')).records, disk.records);
});
