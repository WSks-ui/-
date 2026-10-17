import test from 'node:test';
import assert from 'node:assert/strict';
import { copySnapshot, compareVersions, emptySnapshot, mergeRecords, parseSnapshot } from '../entry/src/main/ets/domain/ArchiveDomain.ts';
import { HERITAGE_SITES } from '../entry/src/main/ets/data/HeritageCatalog.ts';
import {
  STAMP_TYPES, PAPER_THEMES, defaultStampForSite, isMemoryPostcard, memoryPoseLabel,
  memoryQuoteForSite, memorySeasonLabel, paperThemeLabel
} from '../entry/src/main/ets/domain/MemoryJournal.ts';

const note = (patch = {}) => ({
  id: 'note:memory-test', kind: 'note', siteId: 'ly-erlitou', body: '记住这一刻', tags: ['城市'],
  updatedAt: 100, deviceId: 'device-a', deleted: false, ...patch
});
const pose = () => ({
  version: 1, sceneType: 'relic_inspector', yaw: 0.75, pitch: 0.3, zoom: 1.2,
  hotspotId: 'form', sectionId: '', label: '器形观察'
});
const postcard = (patch = {}) => note({
  stampType: '夏都寻踪', paperTheme: 'jade', quotedPoemOrFact: HERITAGE_SITES[1].summary,
  snapshot3DPose: pose(), ...patch
});

test('legacy v1 notes stay ordinary notes without invented postcard fields', () => {
  const snapshot = { ...emptySnapshot('device-a'), records: [note()] };
  const parsed = parseSnapshot(JSON.stringify(snapshot));
  assert.deepEqual(parsed, snapshot);
  assert.deepEqual(copySnapshot(parsed), snapshot);
  assert.equal(isMemoryPostcard(parsed.records[0]), false);
  for (const key of ['stampType', 'paperTheme', 'quotedPoemOrFact', 'snapshot3DPose']) {
    assert.equal(Object.hasOwn(parsed.records[0], key), false);
    assert.equal(Object.hasOwn(copySnapshot(parsed).records[0], key), false);
  }
});

test('postcard metadata round trips, copies deeply and remains on deletion tombstones', () => {
  const source = { ...emptySnapshot('device-a'), records: [postcard(), postcard({ id: 'note:deleted', deleted: true })] };
  const parsed = parseSnapshot(JSON.stringify(source));
  assert.deepEqual(parsed, source);
  assert.throws(() => parseSnapshot(JSON.stringify({ ...source,
    records: [postcard({ snapshot3DPose: { ...pose(), yaw: '不是角度数值' } })] })));
  const copy = copySnapshot(parsed);
  copy.records[0].snapshot3DPose.yaw = 2;
  copy.records[0].tags.push('新标签');
  assert.equal(parsed.records[0].snapshot3DPose.yaw, 0.75);
  assert.deepEqual(parsed.records[0].tags, ['城市']);
  assert.deepEqual(copy.records[1], source.records[1]);
  assert.equal(isMemoryPostcard(copy.records[1]), false);
  assert.equal(mergeRecords([source.records[1]], [postcard({ id: 'note:deleted', updatedAt: 99 })]).records[0].deleted, true);
});

test('metadata differences take part in deterministic versions and cross-device conflict retention', () => {
  const original = postcard();
  const changedPaper = postcard({ paperTheme: 'rose' });
  const changedStamp = postcard({ stampType: '河洛拾遗' });
  const changedQuote = postcard({ quotedPoemOrFact: '另一段已有摘录' });
  const changedPose = postcard({ snapshot3DPose: { ...pose(), yaw: 0.8 } });
  for (const changed of [changedPaper, changedStamp, changedQuote, changedPose]) {
    assert.notEqual(compareVersions(original, changed), 0);
    assert.deepEqual(mergeRecords([original], [changed]).records, mergeRecords([changed], [original]).records);
    const remote = { ...changed, deviceId: 'device-b' };
    const merged = mergeRecords([original], [remote]);
    assert.equal(merged.conflicts.length, 1);
    assert.deepEqual(merged.conflicts[0], original);
  }
  const reversePoseProperties = Object.fromEntries(Object.entries(pose()).reverse());
  assert.equal(compareVersions(original, postcard({ snapshot3DPose: reversePoseProperties })), 0);
});

test('journal helpers use explicit decoration, existing catalog prose and approximate calendar labels', () => {
  assert.deepEqual(STAMP_TYPES, ['河洛拾遗', '夏都寻踪', '商都吉金', '汴京梦华', '仰韶初光']);
  assert.deepEqual(PAPER_THEMES, ['rose', 'ochre', 'jade', 'ink']);
  assert.equal(defaultStampForSite(HERITAGE_SITES[1]), '夏都寻踪');
  assert.equal(defaultStampForSite(HERITAGE_SITES[0]), '仰韶初光');
  assert.ok(HERITAGE_SITES.every((site) => STAMP_TYPES.includes(defaultStampForSite(site))));
  assert.equal(paperThemeLabel('jade'), '青玉笺');
  assert.equal(memoryQuoteForSite(HERITAGE_SITES[1]), HERITAGE_SITES[1].summary);
  assert.equal(memoryQuoteForSite({ ...HERITAGE_SITES[1], summary: '', overview: '遗址'.repeat(100) }).length, 160);
  assert.equal(memoryPoseLabel(pose()), '器形观察');
  assert.equal(memoryPoseLabel(), '未记录视角');
  assert.equal(memorySeasonLabel(new Date(2026, 9, 17, 12).getTime()), '寒露 · 时令近似');
  assert.equal(isMemoryPostcard(note({ paperTheme: 'rose' })), true);
  assert.equal(isMemoryPostcard(note({ stampType: '河洛拾遗' })), true);
  assert.equal(isMemoryPostcard(note({ stampType: '未知主题' })), false);
});
