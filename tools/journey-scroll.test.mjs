import test from 'node:test';
import assert from 'node:assert/strict';
import { domainModuleUrl } from './load-domain-module.mjs';
import { HERITAGE_SITES } from '../entry/src/main/ets/data/HeritageCatalog.ts';
import { encodeExplorationProgressRecord } from '../entry/src/main/ets/domain/ExplorationProgress.ts';

// 只调整 ArkTS 无扩展名导入的装载地址；测试执行应用的同一份领域源码。
const { buildJourneyScroll } = await import(domainModuleUrl('JourneyScroll'));
const note = (siteId, patch = {}) => ({
  id: `note:scroll:${siteId}`, kind: 'note', siteId, body: '我记下这次屏幕观察。', tags: [],
  updatedAt: 100, deviceId: 'scroll-test', deleted: false, ...patch
});
const favorite = siteId => ({
  id: `favorite:${siteId}`, kind: 'favorite', siteId, body: '', tags: [],
  updatedAt: 100, deviceId: 'scroll-test', deleted: false
});
const framedNote = (siteId, patch = {}) => note(siteId, {
  stampType: '商都吉金', paperTheme: 'ochre',
  snapshot3DPose: {
    version: 1, sceneType: 'relic_inspector', yaw: 0.34, pitch: 0.14, zoom: 0.98,
    hotspotId: 'opening', sectionId: '', label: '腹部通口', proceduralPreset: 'dahecun_pottery',
    sceneRevision: 2, rendererProfile: 'native-raster-v1', viewFrame: { width: 294.857, height: 300, textDensity: 3.5 }
  }, ...patch
});
const entries = model => model.groups.flatMap(group => group.entries);
const entryFor = (model, siteId) => entries(model).find(entry => entry.site.id === siteId);
const stepFor = (model, siteId) => model.steps.find(step => step.site.id === siteId);

test('empty scroll keeps four sourced reading steps without inventing personal history', () => {
  const model = buildJourneyScroll(HERITAGE_SITES, []);
  assert.equal(model.route.id, 'earth-and-fire');
  assert.deepEqual(model.steps.map(step => step.site.id),
    ['smx-miaodigou', 'zz-dahecun', 'zz-duling-fangding', 'kf-iron-pagoda']);
  assert.deepEqual(model.steps.map(step => step.index), [1, 2, 3, 4]);
  assert.deepEqual(model.groups, []);
  assert.equal(model.noteCount, 0);
  assert.equal(model.personalSiteCount, 0);
  assert.equal(model.progress.completedCount, 0);
  assert.equal(model.progress.nextSiteId, 'smx-miaodigou');
  for (const step of model.steps) {
    assert.deepEqual(step.site.source, HERITAGE_SITES.find(site => site.id === step.site.id).source);
    assert.equal(step.favorite, false);
    assert.equal(step.exploredPercent, 0);
    assert.equal(step.completed, false);
  }
  assert.match(model.steps[0].readingReason, /陶窑.*布局/);
  assert.match(model.steps[1].readingReason, /腹部.*相通/);
  assert.match(model.steps[2].readingReason, /正中.*折角/);
  assert.match(model.steps[3].readingReason, /琉璃.*构件/);
});

test('ordinary notes enter the scroll while route completion keeps the existing postcard rule', () => {
  const ordinary = note('zz-duling-fangding');
  const framed = framedNote('zz-dahecun');
  const model = buildJourneyScroll(HERITAGE_SITES, [ordinary, framed]);
  assert.equal(model.noteCount, 2);
  assert.equal(model.personalSiteCount, 2);
  assert.deepEqual(model.groups.map(group => group.city), ['郑州']);
  assert.deepEqual(entryFor(model, 'zz-dahecun').notes, [framed]);
  assert.deepEqual(entryFor(model, 'zz-duling-fangding').notes, [ordinary]);
  assert.equal(stepFor(model, 'zz-duling-fangding').noteCount, 1);
  assert.equal(stepFor(model, 'zz-duling-fangding').completed, false);
  assert.equal(stepFor(model, 'zz-dahecun').completed, true);
  assert.deepEqual(model.progress.completedSiteIds, ['zz-dahecun']);
  assert.equal(model.progress.percent, 25);
});

test('shared topics recalculate after tag updates and tombstones cannot revive old entries', () => {
  const twin = framedNote('zz-dahecun', { tags: ['材质观察', '材质观察'] });
  const ding = note('zz-duling-fangding', { tags: ['材质观察'] });
  const before = buildJourneyScroll(HERITAGE_SITES, [twin, ding]);
  for (const entry of entries(before)) {
    assert.ok(entry.reasons.includes('我的专题：材质观察'));
    assert.ok(entry.reasons.includes('同在郑州'));
    assert.equal(entry.reasons.filter(reason => reason === '我的专题：材质观察').length, 1);
  }
  const threePeers = buildJourneyScroll(HERITAGE_SITES,
    [twin, ding, note('smx-miaodigou', { tags: ['材质观察'] })]);
  assert.equal(entryFor(threePeers, 'zz-dahecun').reasons.filter(reason => reason === '我的专题：材质观察').length, 1);
  const retagged = { ...twin, tags: ['内部结构'], updatedAt: 200 };
  const afterTag = buildJourneyScroll(HERITAGE_SITES, [twin, ding, retagged]);
  assert.ok(entries(afterTag).every(entry => !entry.reasons.some(reason => reason.startsWith('我的专题：'))));
  assert.ok(entries(afterTag).every(entry => entry.reasons.includes('同在郑州')));
  const tombstone = { ...retagged, updatedAt: 300, deleted: true };
  const afterDelete = buildJourneyScroll(HERITAGE_SITES, [twin, tombstone, ding, retagged, twin]);
  assert.equal(afterDelete.noteCount, 1);
  assert.equal(afterDelete.personalSiteCount, 1);
  assert.equal(entryFor(afterDelete, 'zz-dahecun'), undefined);
  assert.deepEqual(entryFor(afterDelete, 'zz-duling-fangding').reasons, []);
  assert.equal(stepFor(afterDelete, 'zz-dahecun').completed, false);
  assert.equal(afterDelete.progress.completedCount, 0);
});

test('favorites and valid section progress are independent, while opened markers stay out', () => {
  const kept = favorite('zz-dahecun');
  const partial = encodeExplorationProgressRecord('smx-miaodigou', 'overview', 101, 'scroll-test');
  const complete = ['overview', 'archaeology', 'history'].map((sectionId, index) =>
    encodeExplorationProgressRecord('zz-duling-fangding', sectionId, 110 + index, 'scroll-test'));
  const opened = { ...note('kf-iron-pagoda'), id: 'progress:kf-iron-pagoda', kind: 'progress', body: 'opened' };
  const invalid = { ...opened, id: 'progress:kf-iron-pagoda:overview',
    body: JSON.stringify({ version: 1, sectionId: 'history', completed: true }) };
  const model = buildJourneyScroll(HERITAGE_SITES, [kept, partial, ...complete, opened, invalid]);
  assert.equal(model.noteCount, 0);
  assert.equal(model.personalSiteCount, 3);
  assert.equal(entryFor(model, 'zz-dahecun').favorite, true);
  assert.equal(entryFor(model, 'zz-dahecun').exploredPercent, 0);
  assert.equal(stepFor(model, 'zz-dahecun').completed, false);
  assert.equal(entryFor(model, 'smx-miaodigou').favorite, false);
  assert.equal(entryFor(model, 'smx-miaodigou').exploredPercent, 25);
  assert.equal(stepFor(model, 'smx-miaodigou').completed, false);
  assert.equal(entryFor(model, 'zz-duling-fangding').exploredPercent, 75);
  assert.equal(stepFor(model, 'zz-duling-fangding').completed, true);
  assert.equal(entryFor(model, 'kf-iron-pagoda'), undefined);
  const afterDelete = buildJourneyScroll(HERITAGE_SITES, [kept, partial, ...complete,
    { ...kept, updatedAt: 200, deleted: true }, { ...partial, updatedAt: 200, deleted: true }]);
  assert.deepEqual(entries(afterDelete).map(entry => entry.site.id), ['zz-duling-fangding']);
});

test('route city order and note ties stay stable without mutating inputs or using outside records', () => {
  const sites = structuredClone(HERITAGE_SITES).reverse();
  const records = [
    note('zz-dahecun', { id: 'note:z', tags: ['卷外标签'] }),
    note('zz-dahecun', { id: 'note:a' }),
    note('zz-dahecun', { id: 'note:older', updatedAt: 50 }),
    note('ly-erlitou', { tags: ['卷外标签'] }),
    favorite('ly-erlitou'), favorite('kf-iron-pagoda'), favorite('smx-miaodigou')
  ];
  const original = structuredClone({ sites, records });
  const model = buildJourneyScroll(sites, records);
  assert.deepEqual(model.groups.map(group => group.city), ['三门峡', '郑州', '开封']);
  assert.equal(model.noteCount, 3);
  assert.equal(model.personalSiteCount, 3);
  assert.deepEqual(entryFor(model, 'zz-dahecun').notes.map(record => record.id), ['note:a', 'note:z', 'note:older']);
  assert.ok(!entries(model).some(entry => entry.site.id === 'ly-erlitou'));
  assert.ok(entries(model).every(entry => !entry.reasons.includes('我的专题：卷外标签')));
  assert.deepEqual({ sites, records }, original);
  assert.deepEqual(buildJourneyScroll([...sites].reverse(), [...records].reverse()), model);
});
