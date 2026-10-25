import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
const {
  compareVersions, copySnapshot, emptySnapshot, mergeRecords, parseSnapshot,
  pendingRecordCount, recordVersionConfirmed
} = await import(domainModuleUrl('ArchiveDomain'));
import { HERITAGE_SITES } from '../entry/src/main/ets/data/HeritageCatalog.ts';
import {
  ROAM_CHAPTERS, ROAM_CONTENT_REVISION, ROAM_REVIEW_STATUS, ROAM_SOURCES
} from '../entry/src/main/ets/data/RoamingCatalog.ts';
import { domainModuleUrl } from './load-domain-module.mjs';

const {
  completeRoamClue, makeRoamingMemoryContext, roamChoice, roamProgress, roamProgressRecordId
} = await import(domainModuleUrl('Roaming'));

const chapter = ROAM_CHAPTERS.find(item => item.city === '开封');
const first = chapter.clues[0];
const choice = first.options[0].id;
const note = (patch = {}) => ({
  id: 'note:roaming-compatibility', kind: 'note', siteId: 'smx-miaodigou', body: '我写下的观察',
  tags: ['河流'], updatedAt: 100, deviceId: 'device-a', deleted: false, ...patch
});
const progressFor = (target, index, records = [], timestamp = 100 + index) =>
  completeRoamClue(target, target.clues[index].id, target.clues[index].options[0].id,
    records, 'device-a', timestamp);
const snapshotOf = records => ({ ...emptySnapshot('device-a'), records });

test('roaming catalog has five independent chapters, fifteen usable clues and resolved offline references', () => {
  assert.equal(ROAM_REVIEW_STATUS, '初稿待校审');
  // 2026-10-24 开封三条线索按《东京梦华录》卷一「河道」改为史料版：
  // 州桥低平不通舟船、宋基—明桥—明末淤埋、州桥夜市三摊。内容修订号推进到 3；
  // 旧记忆保留各自冻结的旧修订号，不追改。
  assert.equal(ROAM_CONTENT_REVISION, 3);
  assert.deepEqual(ROAM_CHAPTERS.map(item => item.city), ['三门峡', '洛阳', '郑州', '开封', '濮阳']);
  const ids = ROAM_CHAPTERS.flatMap(item => [item.id, ...item.clues.map(clue => clue.id)]);
  assert.equal(ids.length, 20);
  assert.equal(new Set(ids).size, ids.length);
  assert.ok(ids.every(id => !HERITAGE_SITES.some(site => site.id === id)));
  assert.equal(new Set(ROAM_SOURCES.map(source => source.id)).size, ROAM_SOURCES.length);
  for (const item of ROAM_CHAPTERS) {
    assert.equal(item.clues.length, 3);
    assert.ok(item.opening && item.closing && item.scene && item.subtitle);
    assert.ok(item.relatedSiteIds.every(id => HERITAGE_SITES.some(site => site.id === id)));
    assert.ok(item.sourceIds.every(id => ROAM_SOURCES.some(source => source.id === id)));
    for (const clue of item.clues) {
      assert.ok(clue.body && clue.goal && clue.instruction && clue.era && clue.mode);
      assert.ok(clue.options.length >= 2);
      assert.equal(new Set(clue.options.map(option => option.id)).size, clue.options.length);
      assert.ok(clue.options.every(option => option.label && option.detail));
      assert.ok(clue.sourceIds.length > 0);
      assert.ok(clue.sourceIds.every(id => item.sourceIds.includes(id)));
      assert.ok(clue.sourceIds.every(id => ROAM_SOURCES.some(source => source.id === id)));
    }
  }
  // 不同来源可以在不同日期核对；统一钉死成同一天会迫使为了过测试而改日期，
  // 这里只要求每条都有可核对的 ISO 日期。
  assert.ok(ROAM_SOURCES.every(source => /^https?:\/\//.test(source.url) &&
    /^\d{4}-\d{2}-\d{2}$/.test(source.accessedAt)));
});

test('every city can complete three sequential clues without notes, account or online data', () => {
  for (const item of ROAM_CHAPTERS) {
    let records = [];
    assert.deepEqual(roamProgress(records, item), {
      completedIds: [], nextClueId: item.clues[0].id, completedCount: 0, total: 3, completed: false
    });
    item.clues.forEach((clue, index) => {
      records = mergeRecords(records, [progressFor(item, index, records)]).records;
      const state = roamProgress(records, item);
      assert.equal(state.completedCount, index + 1);
      assert.deepEqual(state.completedIds, item.clues.slice(0, index + 1).map(value => value.id));
      assert.equal(state.nextClueId, index < 2 ? item.clues[index + 1].id : '');
      assert.equal(state.completed, index === 2);
      assert.equal(roamChoice(records, item.id, clue.id), clue.options[0].id);
    });
    assert.equal(records.length, 3);
    assert.ok(records.every(record => record.kind === 'progress' && record.siteId === item.id));
    assert.ok(records.every(record => record.id.startsWith('progress:roam:v1:')));
    assert.equal(parseSnapshot(JSON.stringify(snapshotOf(records))).schemaVersion, 1);
  }
});

test('locked clues reject completion and one city never unlocks another city', () => {
  const later = chapter.clues[1];
  assert.throws(() => completeRoamClue(chapter, later.id, later.options[0].id, [], 'device-a', 100),
    /ROAM_CLUE_LOCKED/);
  const other = ROAM_CHAPTERS[0];
  const records = [progressFor(other, 0)];
  assert.equal(roamProgress(records, chapter).completedCount, 0);
  assert.equal(roamProgress(records, chapter).nextClueId, first.id);
  assert.throws(() => completeRoamClue(chapter, first.id, 'not-an-option', records, 'device-a', 101),
    /ROAM_INVALID_CHOICE/);
  assert.equal(records.length, 1);
});

test('legacy opened, four reading sections, favorites and ordinary notes never count as roaming', () => {
  const old = [
    note({ id: 'progress:kf-zhouqiao', kind: 'progress', siteId: 'kf-zhouqiao', body: 'opened' }),
    note({ id: `progress:${chapter.id}`, kind: 'progress', siteId: chapter.id, body: 'opened' }),
    note({ id: `favorite:${chapter.id}`, kind: 'favorite', siteId: chapter.id }),
    note({ siteId: chapter.id }),
    ...['overview', 'archaeology', 'history', 'poetry-travel'].map(sectionId => note({
      id: `progress:${chapter.id}:${sectionId}`, kind: 'progress', siteId: chapter.id,
      body: JSON.stringify({ version: 1, sectionId, completed: true })
    }))
  ];
  assert.equal(roamProgress(old, chapter).completedCount, 0);
  assert.equal(roamChoice(old, chapter.id, first.id), '');
  assert.deepEqual(parseSnapshot(JSON.stringify(snapshotOf(old))).records, old);
});

test('repeating a confirmed choice is idempotent and returns a separate record object', () => {
  const saved = progressFor(chapter, 0);
  const repeated = completeRoamClue(chapter, first.id, choice, [saved], 'device-b', 999);
  assert.deepEqual(repeated, saved);
  assert.notEqual(repeated, saved);
  repeated.tags.push('不应回写');
  assert.deepEqual(saved.tags, []);
  assert.equal(mergeRecords([saved], [saved, saved]).records.length, 1);
});

test('roaming progress uses deterministic LWW, keeps tombstones and blocks a broken prefix', () => {
  const saved = progressFor(chapter, 0);
  const second = progressFor(chapter, 1, [saved]);
  const removed = { ...saved, updatedAt: 200, deviceId: 'device-b', deleted: true };
  const incoming = [saved, second, removed];
  const merged = mergeRecords([], incoming).records;
  assert.deepEqual(mergeRecords(incoming, []).records, merged);
  assert.equal(roamChoice(incoming, chapter.id, first.id), '');
  assert.deepEqual(roamProgress(incoming, chapter).completedIds, []);
  assert.equal(merged.find(item => item.id === removed.id).deleted, true);
  const equalTimeDelete = { ...saved, deviceId: 'device-0', deleted: true };
  assert.equal(roamProgress([saved, equalTimeDelete], chapter).completedCount, 0);
  assert.throws(() => completeRoamClue(chapter, first.id, choice, merged, 'device-a', 200),
    /ROAM_STALE_TIMESTAMP/);
  const resumed = completeRoamClue(chapter, first.id, choice, merged, 'device-a', 201);
  const recovered = mergeRecords(merged, [resumed]).records;
  assert.equal(roamProgress(recovered, chapter).completedCount, 2);
  assert.equal(roamProgress(recovered, chapter).nextClueId, chapter.clues[2].id);
});

test('changing a completed choice makes a new version while malformed or unrelated records stay incomplete', () => {
  const saved = progressFor(chapter, 0);
  const changed = completeRoamClue(chapter, first.id, first.options[1].id, [saved], 'device-b', 101);
  assert.equal(roamChoice([saved, changed], chapter.id, first.id), first.options[1].id);
  assert.equal(roamProgress([saved, changed], chapter).completedCount, 1);
  const invalidRecords = [
    { ...saved, body: 'opened' },
    { ...saved, siteId: 'kf-zhouqiao' },
    { ...saved, kind: 'note' },
    { ...saved, body: JSON.stringify({ version: 2, chapterId: chapter.id, clueId: first.id, choiceId: choice, completed: true }) },
    { ...saved, body: JSON.stringify({ version: 1, chapterId: chapter.id, clueId: first.id, choiceId: 'other-choice', completed: true }) }
  ];
  for (const invalid of invalidRecords) assert.equal(roamProgress([invalid], chapter).completedCount, 0);
  assert.equal(roamProgressRecordId(chapter.id, first.id), saved.id);
});

test('memory context freezes the chosen clue, explanation and cited source objects', () => {
  const sources = ROAM_SOURCES.map(source => ({ ...source }));
  const target = structuredClone(chapter);
  const targetClue = target.clues[0];
  // 与界面调用一致：显式传入当前内容修订号，避免默认值与目录常量各说一套。
  const frozen = makeRoamingMemoryContext(target, targetClue, choice, sources, ROAM_CONTENT_REVISION);
  const expected = structuredClone(frozen);
  assert.equal(frozen.version, 1);
  assert.equal(frozen.sceneRevision, 1);
  assert.equal(frozen.contentRevision, ROAM_CONTENT_REVISION);
  assert.equal(frozen.chapterId, chapter.id);
  assert.equal(frozen.clueId, first.id);
  assert.equal(frozen.choiceId, choice);
  assert.ok(frozen.excerpt.includes(first.body));
  assert.ok(frozen.excerpt.includes(first.options[0].detail));
  targetClue.body = '资料日后修订';
  targetClue.options[0].detail = '选项日后修订';
  sources.find(source => source.id === frozen.sources[0].id).title = '来源日后修订';
  assert.deepEqual(frozen, expected);
  assert.throws(() => makeRoamingMemoryContext(chapter, first, choice, []), /ROAM_SOURCE_NOT_FOUND/);
});

test('content revision freezes the supplied catalog revision and old contexts stay absent through parse and copy', () => {
  const revised = makeRoamingMemoryContext(chapter, first, choice, ROAM_SOURCES, 7);
  assert.equal(revised.contentRevision, 7);
  const previousContext = structuredClone(revised);
  delete previousContext.contentRevision;
  const before = note({ roamingContext: previousContext });
  const current = note({ id: 'note:revision-seven', roamingContext: revised });
  const parsed = parseSnapshot(JSON.stringify(snapshotOf([before, current])));
  const copied = copySnapshot(parsed);
  assert.equal(Object.hasOwn(parsed.records[0].roamingContext, 'contentRevision'), false);
  assert.equal(Object.hasOwn(copied.records[0].roamingContext, 'contentRevision'), false);
  assert.equal(copied.records[1].roamingContext.contentRevision, 7);
  assert.notEqual(compareVersions(before, { ...before, roamingContext: revised }), 0);
  assert.throws(() => makeRoamingMemoryContext(chapter, first, choice, ROAM_SOURCES, 0), /ROAM_INVALID_CONTENT_REVISION/);
});

test('old records keep their shape and roaming notes round trip with pose, AI, decoration and tombstones', () => {
  const legacy = note();
  const context = makeRoamingMemoryContext(chapter, first, choice, ROAM_SOURCES);
  const rich = note({
    id: 'note:all-optional-fields', roamingContext: context, stampType: 'river', paperTheme: 'warm',
    quotedPoemOrFact: '我选下的摘录',
    snapshot3DPose: {
      version: 1, sceneType: 'pottery', yaw: 0.7, pitch: 0.2, zoom: 1.2,
      hotspotId: 'kiln', sectionId: 'archaeology', label: '原来的陶窑观察',
      sceneRevision: 2, viewFrame: { width: 500, height: 480, dark: false }
    },
    aiAssist: {
      version: 1, question: '我先前问过的问题', factIds: ['original-fact'], contentRevision: 1,
      facts: [{ id: 'original-fact', title: '原冻结依据', body: '原冻结正文', sourceIds: ['original-source'] }]
    }
  });
  const tombstone = note({ id: 'note:roaming-tombstone', deleted: true, roamingContext: context });
  const snapshot = snapshotOf([legacy, rich, tombstone]);
  const parsed = parseSnapshot(JSON.stringify(snapshot));
  assert.deepEqual(parsed, snapshot);
  const copied = copySnapshot(parsed);
  assert.equal(Object.hasOwn(copied.records[0], 'roamingContext'), false);
  copied.records[1].roamingContext.sources[0].title = '草稿中的更改';
  copied.records[1].snapshot3DPose.viewFrame.width = 900;
  copied.records[1].aiAssist.facts[0].body = '草稿中的更改';
  assert.equal(parsed.records[1].roamingContext.sources[0].title, context.sources[0].title);
  assert.equal(parsed.records[1].snapshot3DPose.viewFrame.width, 500);
  assert.equal(parsed.records[1].aiAssist.facts[0].body, '原冻结正文');
  assert.equal(mergeRecords([rich, tombstone], [legacy]).records.length, 3);
  assert.equal(mergeRecords([tombstone], [note({ id: tombstone.id, roamingContext: context, updatedAt: 99 })]).records[0].deleted, true);
});

test('canonical version comparison includes every roaming field and ignores property insertion order', () => {
  const context = makeRoamingMemoryContext(chapter, first, choice, ROAM_SOURCES);
  const saved = note({ roamingContext: context });
  const reorderedContext = Object.fromEntries(Object.entries(context).reverse());
  reorderedContext.sources = context.sources.map(source => Object.fromEntries(Object.entries(source).reverse()));
  assert.equal(compareVersions(saved, note({ roamingContext: reorderedContext })), 0);
  const patches = [
    { chapterId: 'roam-another-chapter' }, { clueId: 'roam-another-clue' }, { sceneRevision: 2 }, { contentRevision: 2 },
    { choiceId: 'another-choice' }, { excerpt: '新摘录' }, { title: '新篇名' }, { city: '洛阳' },
    ...['id', 'title', 'url', 'accessedAt'].map(key => ({
      sources: [{ ...context.sources[0], [key]: key === 'url' ? 'https://example.org/changed' : 'changed' }]
    }))
  ];
  for (const patch of patches) {
    const changed = note({ roamingContext: { ...context, ...patch } });
    assert.notEqual(compareVersions(saved, changed), 0);
    assert.equal(recordVersionConfirmed(changed, [saved]), false);
    assert.equal(pendingRecordCount([changed], [saved]), 1);
    assert.deepEqual(mergeRecords([saved], [changed]).records, mergeRecords([changed], [saved]).records);
  }
});

test('broken roaming context rejects the whole snapshot instead of silently discarding saved evidence', () => {
  const context = makeRoamingMemoryContext(chapter, first, choice, ROAM_SOURCES);
  for (const patch of [{ version: 2 }, { sceneRevision: 0 }, { contentRevision: 0 }, { contentRevision: 1.5 },
    { contentRevision: '1' }, { sources: [] }, { excerpt: '' },
    { sources: [{ ...context.sources[0], accessedAt: '' }] }]) {
    assert.throws(() => parseSnapshot(JSON.stringify(snapshotOf([
      note({ roamingContext: { ...context, ...patch } })
    ]))), /ARCHIVE_INVALID_RECORD/);
  }
});

test('roaming domain stays independent from UI, platform storage and online service calls', () => {
  const source = readFileSync(new URL('../entry/src/main/ets/domain/Roaming.ts', import.meta.url), 'utf8');
  assert.doesNotMatch(source, /@kit\.|@ohos\.|fetch\(|http\.request|preferences\./);
});
