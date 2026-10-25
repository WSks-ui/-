import test from 'node:test';
import assert from 'node:assert/strict';
import { domainModuleUrl } from './load-domain-module.mjs';
const { emptySnapshot, mergeRecords, parseSnapshot } = await import(domainModuleUrl('ArchiveDomain'));
import { HERITAGE_SITES } from '../entry/src/main/ets/data/HeritageCatalog.ts';
import {
  CULTURAL_CITY_ORDER, CULTURAL_SITE_METADATA, EXPLORATION_SECTIONS, getCulturalSiteMetadata
} from '../entry/src/main/ets/domain/CulturalContent.ts';
import {
  decodeExplorationProgress, emptyExplorationProgress, encodeExplorationProgressRecord,
  explorationProgressRecordId, markSectionExplored
} from '../entry/src/main/ets/domain/ExplorationProgress.ts';

const originalIds = [
  'smx-yangshao', 'ly-erlitou', 'zz-shang', 'kf-iron-pagoda', 'py-qicheng',
  'smx-miaodigou', 'smx-guoguo', 'ly-yanshi-shang', 'ly-hanwei', 'ly-longmen',
  'zz-dahecun', 'zz-zhenghan', 'kf-fanta', 'kf-zhouqiao', 'py-xishuipo',
  'smx-xipo', 'kf-city-wall', 'py-cangjie', 'py-danguai', 'zz-duling-fangding'
];

const record = (patch = {}) => ({
  id: 'note:test', kind: 'note', siteId: 'smx-yangshao', body: '', tags: [],
  updatedAt: 1, deviceId: 'device-test', deleted: false, ...patch
});

test('catalog adds sourced Longshan and kiln entries while preserving all original ids and order', () => {
  const ids = HERITAGE_SITES.map((site) => site.id);
  assert.deepEqual(ids.slice(0, originalIds.length), originalIds);
  assert.equal(ids.length, 22);
  assert.equal(new Set(ids).size, 22);
  for (const city of CULTURAL_CITY_ORDER) {
    assert.equal(HERITAGE_SITES.filter((site) => site.city === city).length, city === '郑州' ? 6 : 4, `${city} coverage`);
  }
  assert.ok(HERITAGE_SITES.every((site) => site.reviewStatus === '初稿待校审'));
  assert.ok(HERITAGE_SITES.every((site) => typeof site.source.url === 'string' && site.source.url.startsWith('http')));
  assert.ok(HERITAGE_SITES.every((site) => Array.isArray(site.photos)));
});

test('every catalog record has separate procedural metadata and neutral learning sections', () => {
  assert.deepEqual(Object.keys(CULTURAL_SITE_METADATA).sort(), HERITAGE_SITES.map((site) => site.id).sort());
  for (const site of HERITAGE_SITES) {
    const metadata = getCulturalSiteMetadata(site.id);
    assert.ok(metadata?.proceduralPreset, `${site.id} needs a preset`);
    assert.equal(metadata.cityOrder, CULTURAL_CITY_ORDER.indexOf(site.city));
  }
  assert.equal(getCulturalSiteMetadata('not-in-catalog'), undefined);
  assert.deepEqual(EXPLORATION_SECTIONS.map((section) => section.id), [
    'overview', 'archaeology', 'history', 'poetry-travel'
  ]);
  assert.ok(EXPLORATION_SECTIONS.every((section) => section.percent === 25 && section.isArchaeologicalStratum === false));
  assert.ok(EXPLORATION_SECTIONS.find((section) => section.id === 'poetry-travel').sourceFields.includes('travel'));
});

test('legacy opened progress stays at zero until a section is explicitly completed', () => {
  const legacy = record({ id: 'progress:smx-yangshao', kind: 'progress', body: 'opened' });
  assert.deepEqual(decodeExplorationProgress([legacy], 'smx-yangshao'), {
    siteId: 'smx-yangshao', completedSectionIds: [], percent: 0, openedOnly: true
  });
});

test('each completed section has its own stable additive archive record', () => {
  const overview = encodeExplorationProgressRecord('smx-yangshao', 'overview', 10, 'device-a');
  const archaeology = encodeExplorationProgressRecord('smx-yangshao', 'archaeology', 11, 'device-b');
  assert.equal(overview.kind, 'progress');
  assert.equal(overview.tags.length, 0);
  assert.equal(overview.id, 'progress:smx-yangshao:overview');
  assert.equal(archaeology.id, 'progress:smx-yangshao:archaeology');
  assert.notEqual(overview.id, archaeology.id);
  assert.deepEqual(JSON.parse(overview.body), { version: 1, sectionId: 'overview', completed: true });
  const merged = mergeRecords([overview], [archaeology]);
  assert.equal(merged.records.length, 2, 'different section IDs should coexist across devices');
  const compatible = parseSnapshot(JSON.stringify({ ...emptySnapshot('device-a'), records: merged.records }));
  assert.equal(compatible.schemaVersion, 1);
  const decoded = decodeExplorationProgress([overview, archaeology], 'smx-yangshao');
  assert.deepEqual(decoded.completedSectionIds, ['overview', 'archaeology']);
  assert.equal(decoded.percent, 50);
  assert.equal(decoded.openedOnly, false);
});

test('next progress is ordered, idempotent and reaches 100% only after four sections', () => {
  let progress = emptyExplorationProgress('smx-yangshao');
  progress = markSectionExplored(progress, 'history');
  assert.equal(progress.percent, 25);
  assert.deepEqual(progress.completedSectionIds, ['history']);
  const same = markSectionExplored(progress, 'history');
  assert.strictEqual(same, progress);
  progress = markSectionExplored(progress, 'poetry-travel');
  progress = markSectionExplored(progress, 'overview');
  progress = markSectionExplored(progress, 'archaeology');
  assert.equal(progress.percent, 100);
  assert.deepEqual(progress.completedSectionIds, ['overview', 'archaeology', 'history', 'poetry-travel']);
  assert.deepEqual(emptyExplorationProgress('smx-yangshao').completedSectionIds, []);
  assert.equal(explorationProgressRecordId('smx-yangshao', 'poetry-travel'), 'progress:smx-yangshao:poetry-travel');
});

test('deleted, malformed and other-site records do not increase progress', () => {
  const valid = encodeExplorationProgressRecord('smx-yangshao', 'overview', 20, 'device-a');
  const malformed = { ...valid, id: 'progress:smx-yangshao:archaeology', body: '{bad json' };
  const wrongSite = { ...valid, id: 'progress:ly-erlitou:history', siteId: 'ly-erlitou' };
  const removed = { ...encodeExplorationProgressRecord('smx-yangshao', 'history', 30, 'device-a'), deleted: true };
  const decoded = decodeExplorationProgress([valid, malformed, wrongSite, removed], 'smx-yangshao');
  assert.deepEqual(decoded.completedSectionIds, ['overview']);
  assert.equal(decoded.percent, 25);
  assert.equal(decoded.openedOnly, false);
});

test('encoding rejects invalid progress keys and timestamps', () => {
  assert.throws(() => encodeExplorationProgressRecord('smx-yangshao', 'unknown', 1, 'device-a'));
  assert.throws(() => encodeExplorationProgressRecord('bad:site', 'overview', 1, 'device-a'));
  assert.throws(() => encodeExplorationProgressRecord('smx-yangshao', 'overview', -1, 'device-a'));
});
