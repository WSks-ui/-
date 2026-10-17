import test from 'node:test';
import assert from 'node:assert/strict';
import { domainModuleUrl } from './load-domain-module.mjs';
import { copySnapshot, compareVersions, emptySnapshot, mergeRecords, parseSnapshot } from '../entry/src/main/ets/domain/ArchiveDomain.ts';
import { HERITAGE_SITES } from '../entry/src/main/ets/data/HeritageCatalog.ts';
import {
  STAMP_TYPES, PAPER_THEMES, defaultStampForSite, isMemoryPostcard, memoryPoseLabel,
  memoryQuoteForSite, memorySeasonLabel, paperThemeLabel
} from '../entry/src/main/ets/domain/MemoryJournal.ts';

// ArkTS 使用无扩展名导入；仅改测试装载路径，执行与应用相同的回放判定源码。
const { resolveMemoryReplay } = await import(domainModuleUrl('MemoryReplay'));

const note = (patch = {}) => ({
  id: 'note:memory-test', kind: 'note', siteId: 'ly-erlitou', body: '记住这一刻', tags: ['城市'],
  updatedAt: 100, deviceId: 'device-a', deleted: false, ...patch
});
const pose = () => ({
  version: 1, sceneType: 'relic_inspector', yaw: 0.75, pitch: 0.3, zoom: 1.2,
  hotspotId: 'form', sectionId: '', label: '器形观察'
});
const observationPose = () => ({
  ...pose(), hotspotId: 'opening', label: '', proceduralPreset: 'dahecun_pottery',
  sceneRevision: 2, rendererProfile: 'native-raster-v1',
  viewFrame: { width: 360, height: 280, textDensity: 3.5, dark: false }
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

test('recorded framing metadata survives copies, tombstones and snapshot round trips without migration', () => {
  const original = postcard({ siteId: 'zz-dahecun', snapshot3DPose: observationPose() });
  const source = { ...emptySnapshot('device-a'), records: [original, { ...original, id: 'note:frame-deleted', deleted: true }] };
  const parsed = parseSnapshot(JSON.stringify(source));
  assert.deepEqual(parsed, source);
  const copied = copySnapshot(parsed);
  copied.records[0].snapshot3DPose.viewFrame.width = 720;
  copied.records[0].snapshot3DPose.viewFrame.textDensity = 2;
  copied.records[0].snapshot3DPose.viewFrame.dark = true;
  assert.deepEqual(parsed.records[0].snapshot3DPose.viewFrame, observationPose().viewFrame);
  assert.deepEqual(copied.records[1], source.records[1]);
  assert.equal(parsed.records[0].updatedAt, 100);

  // 未来支持名单不影响归档；实际损坏的扩展必须触发既有读取保护，不能被悄悄抹掉。
  const future = { ...observationPose(), sceneType: 'future_scene', sceneRevision: 7, rendererProfile: 'future-renderer' };
  const futureSnapshot = { ...emptySnapshot('device-a'), records: [postcard({ snapshot3DPose: future })] };
  assert.deepEqual(copySnapshot(parseSnapshot(JSON.stringify(futureSnapshot))), futureSnapshot);
  for (const patch of [{ sceneRevision: 0 }, { rendererProfile: 7 }, { viewFrame: null },
    { viewFrame: { width: 360, height: 0 } }, { viewFrame: { width: 360, height: 280, textDensity: -1 } }]) {
    assert.throws(() => parseSnapshot(JSON.stringify({ ...source,
      records: [postcard({ snapshot3DPose: { ...observationPose(), ...patch } })] })), /ARCHIVE_INVALID_RECORD/);
  }
});

test('scene and framing changes participate in canonical versions and sync conflicts', () => {
  const original = postcard({ siteId: 'zz-dahecun', snapshot3DPose: observationPose() });
  const reversePose = Object.fromEntries(Object.entries(observationPose()).reverse());
  reversePose.viewFrame = Object.fromEntries(Object.entries(reversePose.viewFrame).reverse());
  assert.equal(compareVersions(original, { ...original, snapshot3DPose: reversePose }), 0);
  const changes = [
    { proceduralPreset: 'future_preset' }, { sceneRevision: 3 }, { rendererProfile: 'future-renderer' },
    ...[{ width: 400 }, { height: 300 }, { textDensity: 2 }, { dark: true }].map((patch) =>
      ({ viewFrame: { ...observationPose().viewFrame, ...patch } }))
  ];
  for (const patch of changes) {
    const changed = { ...original, snapshot3DPose: { ...observationPose(), ...patch } };
    assert.notEqual(compareVersions(original, changed), 0);
    assert.deepEqual(mergeRecords([original], [changed]).records, mergeRecords([changed], [original]).records);
    const merged = mergeRecords([original], [{ ...changed, deviceId: 'device-b' }]);
    assert.deepEqual(merged.conflicts, [original]);
    assert.deepEqual(merged.records[0].snapshot3DPose, changed.snapshot3DPose);
  }
});

test('replay separates old camera recovery from fully recorded native framing', () => {
  const legacyPose = pose();
  const legacy = resolveMemoryReplay('ly-erlitou', legacyPose);
  assert.equal(legacy.state, 'legacy');
  assert.equal(legacy.canReplay, true);
  assert.equal(legacy.message, '旧版视角，原取景未记录');
  assert.equal(legacy.proceduralPreset, 'erlitou_palace');
  assert.equal(legacy.sceneRevision, 1);
  assert.equal(Object.hasOwn(legacyPose, 'sceneRevision'), false);
  assert.equal(Object.hasOwn(legacyPose, 'viewFrame'), false);

  const recorded = observationPose();
  const resolved = resolveMemoryReplay('zz-dahecun', recorded);
  assert.equal(resolved.state, 'ready');
  assert.equal(resolved.canReplay, true);
  assert.equal(resolved.sceneRevision, 2);
  assert.equal(memoryPoseLabel(recorded), '腹部通口');
  resolved.viewFrame.width = 500;
  assert.equal(recorded.viewFrame.width, 360);
  const missingDensity = { ...recorded, viewFrame: { width: 360, height: 280, dark: false } };
  assert.equal(resolveMemoryReplay('zz-dahecun', missingDensity).state, 'legacy');
  const oldRevision = { ...recorded, sceneRevision: 1, hotspotId: 'form' };
  assert.equal(resolveMemoryReplay('zz-dahecun', oldRevision).state, 'ready');
  const slice = { ...recorded, sceneType: 'stratum_slice', hotspotId: '', sectionId: 'archaeology' };
  assert.equal(resolveMemoryReplay('zz-dahecun', slice).state, 'ready');
});

test('unmatched archives, revisions, selections and camera values never report a replay as ready', () => {
  assert.equal(resolveMemoryReplay('unknown-site', observationPose()).state, 'unavailable');
  assert.equal(resolveMemoryReplay('zz-dahecun').canReplay, false);
  const patches = [
    { version: 2 }, { proceduralPreset: 'erlitou_palace' }, { sceneRevision: 3 },
    { rendererProfile: 'webgl2-v1' }, { sceneType: 'river_sandbox' },
    { hotspotId: 'form' }, { sectionId: 'overview' }, { pitch: 0.81 }, { zoom: 1.61 }
  ];
  for (const patch of patches) {
    const saved = { ...observationPose(), ...patch };
    const result = resolveMemoryReplay('zz-dahecun', saved);
    assert.equal(result.state, 'unavailable', JSON.stringify(patch));
    assert.equal(result.canReplay, false);
    assert.ok(result.message.length > 0);
    assert.deepEqual(saved, { ...observationPose(), ...patch });
  }
  assert.equal(resolveMemoryReplay('ly-erlitou', { ...observationPose(), proceduralPreset: 'erlitou_palace' }).canReplay, false);
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

test('both expanded observations preserve their own selected detail and recorded frame through archive replay', () => {
  const cases = [
    { siteId: 'smx-miaodigou', preset: 'miaodigou_pottery', hotspot: 'kilns', label: '西部陶窑' },
    { siteId: 'zz-duling-fangding', preset: 'duling_fangding', hotspot: 'corners', label: '四个折角' }
  ];
  for (const item of cases) {
    const savedPose = { ...observationPose(), proceduralPreset: item.preset, hotspotId: item.hotspot };
    const saved = { ...emptySnapshot('device-a'), records: [postcard({ siteId: item.siteId, snapshot3DPose: savedPose })] };
    const received = parseSnapshot(JSON.stringify(copySnapshot(saved))).records[0];
    assert.deepEqual(received.snapshot3DPose, savedPose);
    assert.equal(resolveMemoryReplay(item.siteId, received.snapshot3DPose).state, 'ready');
    assert.equal(memoryPoseLabel(received.snapshot3DPose), item.label);
    // 新部位不能混入旧修订；旧记录仍能按原三热点恢复，而且不会自动补场景或取景元数据。
    assert.equal(resolveMemoryReplay(item.siteId, { ...savedPose, sceneRevision: 1 }).canReplay, false);
    const old = pose();
    assert.equal(resolveMemoryReplay(item.siteId, old).state, 'legacy');
    assert.equal(Object.hasOwn(old, 'sceneRevision'), false);
    assert.equal(Object.hasOwn(old, 'viewFrame'), false);
  }
});
