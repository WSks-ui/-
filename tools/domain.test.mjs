import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import {
  activeRecords, compareVersions, copySnapshot, emptySnapshot, filterSites,
  mergeRecords, nextTimestamp, parseSnapshot, putRecord, recommendSites,
  MAX_NOTE_TAGS_TEXT_LENGTH
} from '../entry/src/main/ets/domain/ArchiveDomain.ts';
import { HERITAGE_SITES } from '../entry/src/main/ets/data/HeritageCatalog.ts';
import { UnavailableSyncGateway } from '../entry/src/main/ets/sync/SyncGateway.ts';
import { archiveStoreForLaunch, DEFAULT_ARCHIVE_STORE } from '../entry/src/main/ets/platform/ArchiveLaunch.ts';
import { connectionReasons, cultureConnections, cultureTopics, personalCultureSites } from '../entry/src/main/ets/domain/CultureConnections.ts';
import { accountStoreName, changedAccountView, guestAccountView, validateAccountInput, validateAccountSession, validateAccountReply } from '../entry/src/main/ets/domain/AccountSync.ts';

test('account stores isolate account identity and test sessions without changing guest data', () => {
  const accountA = 'a'.repeat(32), accountB = 'b'.repeat(32);
  assert.notEqual(accountStoreName(accountA), accountStoreName(accountB));
  assert.ok(accountStoreName(accountA, 'yunheji_test_ui_run_a').startsWith('yunheji_test_ui_'));
  assert.throws(() => accountStoreName('../yunheji_archive_v1'));
  assert.throws(() => accountStoreName(accountA, 'yunheji_archive_v1'));
  assert.equal(DEFAULT_ARCHIVE_STORE, 'yunheji_archive_v1');
});

test('account authentication and sync responses reject invalid identity and statistics', () => {
  assert.throws(() => validateAccountInput('abc', '1234567890'));
  assert.throws(() => validateAccountInput('valid_name', 'short'));
  validateAccountInput('valid_name', '1234567890');
  const session = { accountId: 'a'.repeat(32), username: 'valid_name', token: 'b'.repeat(64), expiresAt: Date.now() + 60000 };
  assert.equal(validateAccountSession(session).accountId, session.accountId);
  assert.throws(() => validateAccountSession({ ...session, expiresAt: 0 }));
  const reply = { accountId: session.accountId, records: [], otherDevices: 0, conflictCount: 0, serverTime: Date.now() };
  validateAccountReply(reply, session.accountId);
  assert.throws(() => validateAccountReply(reply, 'b'.repeat(32)));
  assert.throws(() => validateAccountReply({ ...reply, otherDevices: -1 }, session.accountId));
});

test('account view never manufactures sync success for a guest or unavailable service', () => {
  const initial = guestAccountView();
  assert.equal(initial.signedIn, false); assert.equal(initial.lastSync, 0); assert.equal(initial.otherDevices, -1);
  const failed = changedAccountView(initial, { message: '连接失败', busy: false });
  assert.equal(failed.lastSync, 0); assert.equal(failed.signedIn, false);
  assert.equal(initial.message, '');
});

const all = { keyword: '', city: '全部城市', era: '全部年代', type: '全部类型' };
const record = (patch = {}) => ({
  id: 'note:a', kind: 'note', siteId: 'ly-erlitou', body: '观察记录', tags: ['研究资料'],
  updatedAt: 100, deviceId: 'device-a', deleted: false, ...patch
});

test('all seed cities are covered and stable ids are unique', () => {
  assert.equal(new Set(HERITAGE_SITES.map(s => s.id)).size, HERITAGE_SITES.length);
  assert.equal(new Set(HERITAGE_SITES.map(s => s.city)).size, 5);
  assert.ok(HERITAGE_SITES.every(s => s.reviewStatus === '初稿待校审'));
});
test('empty query returns all records', () => {
  assert.equal(filterSites(HERITAGE_SITES, all).length, HERITAGE_SITES.length);
});
test('city era type and keyword filters intersect', () => {
  assert.deepEqual(filterSites(HERITAGE_SITES, {
    keyword: '  青铜 都城  ', city: '洛阳', era: '夏商', type: '都城遗址'
  }).map(s => s.id), ['ly-erlitou']);
});
test('impossible combination is empty rather than ignoring filters', () => {
  assert.equal(filterSites(HERITAGE_SITES, { ...all, city: '洛阳', era: '宋' }).length, 0);
});
test('whitespace-only search is empty query', () => {
  assert.equal(filterSites(HERITAGE_SITES, { ...all, keyword: '   ' }).length, 5);
});
test('active records hide tombstones and sort latest first', () => {
  const records = [record(), record({ id: 'note:b', updatedAt: 200 }), record({ id: 'note:c', deleted: true })];
  assert.deepEqual(activeRecords(records, 'note').map(r => r.id), ['note:b', 'note:a']);
});
test('upsert replaces one logical record', () => {
  assert.equal(putRecord([record()], record({ body: 'new' })).length, 1);
});
test('logical timestamp handles local clock rollback', () => {
  assert.equal(nextTimestamp([record({ updatedAt: 1000 })], 50), 1001);
});
test('latest timestamp wins and losing content is retained', () => {
  const result = mergeRecords([record()], [record({ deviceId: 'device-b', updatedAt: 200, body: 'new' })]);
  assert.equal(result.records[0].body, 'new');
  assert.equal(result.conflicts[0].body, '观察记录');
});
test('same timestamp has deterministic device tie break', () => {
  const a = record(), b = record({ deviceId: 'device-b', body: 'second' });
  assert.deepEqual(mergeRecords([a], [b]).records, mergeRecords([b], [a]).records);
  assert.ok(compareVersions(b, a) > 0);
});
test('semantic equality ignores property insertion order', () => {
  const a = record();
  const b = Object.fromEntries(Object.entries(a).reverse());
  assert.equal(compareVersions(a, b), 0);
});
test('equal timestamp deletion wins over live record', () => {
  const result = mergeRecords([record()], [record({ deleted: true, deviceId: 'device-0' })]);
  assert.equal(result.records[0].deleted, true);
});
test('old offline version cannot resurrect deleted record', () => {
  const deleted = record({ deleted: true, updatedAt: 200 });
  assert.equal(mergeRecords([deleted], [record()]).records[0].deleted, true);
});
test('merge is idempotent and has no conflict for identical records', () => {
  const result = mergeRecords([record()], [record()]);
  assert.equal(result.records.length, 1);
  assert.equal(result.conflicts.length, 0);
});
test('merge is commutative across multiple ids and versions', () => {
  const a = [record(), record({ id: 'note:b' })];
  const b = [record({ updatedAt: 300, deviceId: 'device-b' }), record({ id: 'note:c' })];
  assert.deepEqual(mergeRecords(a, b).records, mergeRecords(b, a).records);
});
test('snapshot copies cannot mutate source tags', () => {
  const data = emptySnapshot('device-a');
  data.records = [record()];
  const copy = copySnapshot(data);
  copy.records[0].tags.push('new');
  assert.deepEqual(data.records[0].tags, ['研究资料']);
});
test('snapshot round trips unicode and timestamps', () => {
  const data = emptySnapshot('device-a');
  data.records = [record()];
  assert.deepEqual(parseSnapshot(JSON.stringify(data)), data);
});
test('corrupt or future snapshots are rejected', () => {
  for (const raw of ['{', 'null', '{}', JSON.stringify({ ...emptySnapshot('a'), schemaVersion: 2 })]) {
    assert.throws(() => parseSnapshot(raw));
  }
});
test('invalid records and duplicate ids are rejected', () => {
  for (const records of [[record({ body: 3 })], [record({ updatedAt: -1 })],
    [record({ tags: [null] })], [record(), record()], [record({ body: 'a'.repeat(4001) })]]) {
    assert.throws(() => parseSnapshot(JSON.stringify({ ...emptySnapshot('a'), records })));
  }
});
test('maximum legal note and tags round trip without truncation', () => {
  const tags = Array.from({ length: 20 }, (_, i) => `${i}`.padEnd(40, '文'));
  assert.equal(tags.join('，').length, MAX_NOTE_TAGS_TEXT_LENGTH);
  const snapshot = { ...emptySnapshot('device-a'), records: [record({ body: '河'.repeat(4000), tags })] };
  assert.deepEqual(parseSnapshot(JSON.stringify(snapshot)), snapshot);
  for (const invalidTags of [tags.concat(['多余']), ['文'.repeat(41)]]) {
    assert.throws(() => parseSnapshot(JSON.stringify({ ...snapshot, records: [record({ tags: invalidTags })] })));
  }
});
test('UI test store is accepted only for a bounded debug-only namespace', () => {
  assert.equal(archiveStoreForLaunch('yunheji_test_ui_123_case', true), 'yunheji_test_ui_123_case');
  assert.equal(archiveStoreForLaunch('yunheji_test_ui_123_case', false), DEFAULT_ARCHIVE_STORE);
  for (const candidate of [undefined, 17, {}, '', 'yunheji_test_ui_', '../snapshot',
    'yunheji_test_ui_/archive', 'yunheji_test_ui_' + 'a'.repeat(81), 'yunheji_archive_v1']) {
    assert.equal(archiveStoreForLaunch(candidate, true), DEFAULT_ARCHIVE_STORE);
  }
});
test('recommendations exclude current and favorites and explain ranking', () => {
  const favorites = [record({ id: 'favorite:ly-erlitou', kind: 'favorite' })];
  const result = recommendSites(HERITAGE_SITES, favorites, 'smx-yangshao');
  assert.equal(result[0].site.id, 'zz-shang');
  assert.ok(result[0].reason.includes('夏商'));
  assert.ok(result.every(r => !['ly-erlitou', 'smx-yangshao'].includes(r.site.id)));
});
test('cold start recommendations are deterministic', () => {
  assert.deepEqual(recommendSites(HERITAGE_SITES, []), recommendSites(HERITAGE_SITES.slice().reverse(), []));
});
test('progress is an input to local recommendations', () => {
  const result = recommendSites(HERITAGE_SITES, [record({ kind: 'progress' })], 'ly-erlitou');
  assert.equal(result[0].site.id, 'zz-shang');
});
test('landing recommendations do not repeat already viewed content', () => {
  const result = recommendSites(HERITAGE_SITES, [record({ kind: 'progress' })]);
  assert.ok(result.every(r => r.site.id !== 'ly-erlitou'));
});
test('unconfigured sync never claims success', async () => {
  const gateway = new UnavailableSyncGateway();
  assert.equal(gateway.status().lastSuccessfulSync, 0);
  assert.equal(gateway.status().connectedDevices, 0);
  await assert.rejects(gateway.exchange([]), /DISTRIBUTED_SYNC_NOT_CONFIGURED/);
});
test('all catalog illustrations are bundled offline', () => {
  for (const site of HERITAGE_SITES) {
    assert.ok(existsSync(fileURLToPath(new URL(`../entry/src/main/resources/base/media/${site.illustration}`, import.meta.url))));
  }
});
test('light and dark themes contain identical resource keys', () => {
  const colors = path => JSON.parse(readFileSync(new URL(path, import.meta.url), 'utf8')).color.map(x => x.name).sort();
  assert.deepEqual(colors('../entry/src/main/resources/base/element/color.json'),
    colors('../entry/src/main/resources/dark/element/color.json'));
});

test('culture graph explains shared era and content without inventing links', () => {
  const links = cultureConnections(HERITAGE_SITES, 'ly-erlitou');
  assert.equal(links[0].site.id, 'zz-shang');
  assert.ok(links[0].reasons.includes('同属夏商时期'));
  assert.ok(links[0].reasons.includes('同为都城遗址'));
  assert.deepEqual(connectionReasons(HERITAGE_SITES[0], HERITAGE_SITES[3]), []);
});

test('personal graph derives only from live known favorites and notes', () => {
  const records = [record(), record({ id: 'favorite:a', kind: 'favorite', siteId: 'ly-erlitou' }),
    record({ id: 'note:b', siteId: 'kf-iron-pagoda' }),
    record({ id: 'note:c', siteId: 'smx-yangshao', deleted: true }),
    record({ id: 'note:d', siteId: 'not-in-catalog' })];
  assert.deepEqual(personalCultureSites(HERITAGE_SITES, records).map(s => s.id), ['ly-erlitou', 'kf-iron-pagoda']);
});

test('custom note topic creates a real personal connection and removes with deleted note', () => {
  const records = [record({ siteId: 'smx-yangshao', tags: ['我的专题'] }),
    record({ id: 'note:b', siteId: 'kf-iron-pagoda', tags: ['我的专题'] })];
  assert.deepEqual(cultureTopics(records), ['我的专题']);
  assert.equal(personalCultureSites(HERITAGE_SITES, records, '我的专题').length, 2);
  assert.deepEqual(connectionReasons(HERITAGE_SITES[0], HERITAGE_SITES[3], records), ['我的专题：我的专题']);
  records[1].deleted = true;
  assert.deepEqual(connectionReasons(HERITAGE_SITES[0], HERITAGE_SITES[3], records), []);
  assert.equal(personalCultureSites(HERITAGE_SITES, records, '我的专题').length, 1);
});
