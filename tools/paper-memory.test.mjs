import test from 'node:test';
import assert from 'node:assert/strict';
import { domainModuleUrl } from './load-domain-module.mjs';

const { createPaperWork, cutPaperStroke, copyPaperWork, togglePaperLight } = await import(domainModuleUrl('PaperJourney'));
const { copyPaperMemory, validPaperMemory } = await import(domainModuleUrl('PaperMemory'));
const { emptySnapshot, copySnapshot, parseSnapshot, compareVersions, mergeRecords, activeRecords } = await import(domainModuleUrl('ArchiveDomain'));

function contextFixture() {
  const blank = createPaperWork('paper-kf', 100);
  const work = cutPaperStroke(blank, [{ x: 0.22, y: 0.28 }, { x: 0.31, y: 0.28 }], 1, 110).work;
  return {
    version: 1, cityId: 'paper-kf', title: '让灯从纸里亮起来',
    culture: '这盏原创纸灯分别阅读北宋文献与清末以来灯彩；不是传统工艺复原。',
    work,
    sources: [{ id: 'paper-kf-lantern', title: '纸灯的透光',
      url: 'https://www.ihchina.cn/project_details/14067.html',
      quote: '资料摘要：汴京灯笼张的灯彩技艺自清末以来传承。', accessedAt: '2026-10-23', era: '清末以来灯彩 / 原创纸景' }]
  };
}

function oldRecord() {
  return { id: 'note:legacy', kind: 'note', siteId: 'zz-dahecun', body: '旧笔记：两只壶在腹部相通。',
    tags: ['器物观察', '自己的话'], updatedAt: 80, deviceId: 'device-a', deleted: false,
    stampType: '器物', paperTheme: 'jade', quotedPoemOrFact: '旧笔记保留自己的冻结摘录',
    snapshot3DPose: { version: 1, sceneType: 'material-study', yaw: 12, pitch: 7, zoom: 1.2,
      hotspotId: 'belly', sectionId: '', label: '腹部', proceduralPreset: 'dahecun_twin', sceneRevision: 1,
      rendererProfile: 'canvas', viewFrame: { width: 420, height: 360, textDensity: 1, dark: false } },
    aiAssist: { version: 1, question: '连接在哪里？', factIds: ['dahecun-opening'], contentRevision: 1,
      facts: [{ id: 'dahecun-opening', title: '腹部的通口', body: '两只陶壶腹部接合处有椭圆形通口。', sourceIds: ['museum-dahecun'] }] },
    roamingContext: { version: 1, chapterId: 'roam-zz-zhenwei', clueId: 'roam-zz-gates', sceneRevision: 1,
      contentRevision: 1, choiceId: 'zz-water-gate', excerpt: '旧漫游冻结摘录', title: '旧篇章', city: '郑州',
      sources: [{ id: 'roam-source-zhenghan', title: '郑韩故城资料',
        url: 'https://m.henan.gov.cn/2025/03-10/3134723.html', accessedAt: '2026-10-23' }] }
  };
}

function noteFixture() {
  return { id: 'note:paper', kind: 'note', siteId: 'kf-zhouqiao', body: '这些光孔让我想到夜里的街。',
    tags: ['开封', '纸上生城'], updatedAt: 200, deviceId: 'device-a', deleted: false,
    stampType: '纸上生城', paperTheme: 'jade', paperContext: contextFixture() };
}

function snapshotWith(records) {
  const snapshot = emptySnapshot('snapshot-device');
  snapshot.records = records;
  return snapshot;
}

test('paper-memory: 冻结复制完整作品与来源，之后重剪和改资料不会污染已经保存的记忆', () => {
  const source = contextFixture();
  const frozen = copyPaperMemory(source);
  const baseline = JSON.parse(JSON.stringify(frozen));
  source.work.history.push(source.work.mask);
  source.work = togglePaperLight(source.work, 150).work;
  source.sources[0].quote = '只在保存后改动的目录草稿';
  source.sources.push({ ...source.sources[0], id: 'another-source' });
  assert.deepEqual(frozen, baseline);
  assert.equal(validPaperMemory(frozen), true);
  assert.notEqual(source.work.light, frozen.work.light);
});

test('paper-memory: schema v1 copy/parse 同时保留纸景与所有旧笔记字段', () => {
  const legacy = oldRecord();
  const paper = { ...noteFixture(), snapshot3DPose: legacy.snapshot3DPose, aiAssist: legacy.aiAssist,
    roamingContext: legacy.roamingContext, quotedPoemOrFact: legacy.quotedPoemOrFact };
  const original = snapshotWith([legacy, paper]);
  const copied = copySnapshot(original);
  assert.deepEqual(copied, original);
  assert.deepEqual(parseSnapshot(JSON.stringify(copied)), original);
  copied.records[1].paperContext.work.history.length = 0;
  copied.records[1].paperContext.sources[0].title = '副本改名';
  copied.records[1].snapshot3DPose.viewFrame.width = 900;
  copied.records[1].aiAssist.facts[0].body = '副本事实';
  copied.records[1].roamingContext.sources[0].title = '副本来源';
  assert.deepEqual(original.records[1], paper);
  assert.equal(original.records[1].paperContext.work.history.length, 1);
});

test('paper-memory: 旧普通note缺省paperContext，不补作品、来源、时间戳或新身份', () => {
  const legacy = oldRecord();
  const snapshot = snapshotWith([legacy]);
  const copied = copySnapshot(snapshot);
  const reopened = parseSnapshot(JSON.stringify(copied));
  assert.equal(reopened.schemaVersion, 1);
  assert.deepEqual(reopened.records[0], legacy);
  assert.equal(Object.hasOwn(reopened.records[0], 'paperContext'), false);
  assert.equal(Object.hasOwn(copied.records[0], 'paperContext'), false);
  assert.equal(reopened.records[0].updatedAt, 80);
});

test('paper-memory: 完整冻结纸景及来源参与同时间版本比较，不能被误当同一条记录', () => {
  const baseline = noteFixture();
  const mutations = [
    context => { context.work = cutPaperStroke(context.work, [{ x: 0.7, y: 0.65 }, { x: 0.78, y: 0.65 }], 1, 160).work; },
    context => { context.sources[0].quote = '另一版冻结摘录'; },
    context => { context.sources[0].era = '修改过的年代标签'; },
    context => { context.sources[0].url = 'https://www.ihchina.cn/another-page'; },
    context => { context.culture = '另一份原创纸景说明'; }
  ];
  for (const mutate of mutations) {
    const changed = JSON.parse(JSON.stringify(baseline));
    mutate(changed.paperContext);
    assert.notEqual(compareVersions(baseline, changed), 0);
    assert.equal(Math.sign(compareVersions(baseline, changed)), -Math.sign(compareVersions(changed, baseline)));
    assert.deepEqual(mergeRecords([baseline], [changed]).records, mergeRecords([changed], [baseline]).records);
  }
});

test('paper-memory: 远端较新note保留整份冻结上下文，合并不拼接两份来源或剪口', () => {
  const local = noteFixture();
  const remote = JSON.parse(JSON.stringify(local));
  remote.deviceId = 'device-b'; remote.updatedAt = 300; remote.body = '另一端由我修改的正文';
  remote.paperContext.sources[0].quote = '这页实际保存时的另一版材料';
  remote.paperContext.work = copyPaperWork(remote.paperContext.work);
  const merged = mergeRecords([local], [remote]);
  assert.deepEqual(merged.records, [remote]);
  assert.deepEqual(merged.conflicts, [local]);
  assert.equal(merged.records[0].paperContext.sources.length, 1);
  assert.deepEqual(parseSnapshot(JSON.stringify(snapshotWith(merged.records))).records[0], remote);
});

test('paper-memory: 删除保留纸景墓碑，旧设备重新合并不能复活记录', () => {
  const saved = noteFixture();
  const tombstone = { ...saved, deleted: true, updatedAt: 400, deviceId: 'device-b' };
  const merged = mergeRecords([tombstone], [saved]).records;
  assert.equal(activeRecords(merged, 'note').length, 0);
  assert.equal(merged.length, 1);
  assert.equal(merged[0].deleted, true);
  assert.deepEqual(merged[0].paperContext, saved.paperContext);
  assert.deepEqual(parseSnapshot(JSON.stringify(snapshotWith(merged))).records, merged);
});

test('paper-memory: 损坏作品或来源拒绝整条快照，不删除扩展后假装普通note读取成功', () => {
  const note = noteFixture();
  const mutations = [
    context => { context.work.mask = 'broken'; },
    context => { delete context.work.completedMask; },
    context => { context.work.cityId = 'paper-ly'; },
    context => { context.version = 2; },
    context => { context.sources = []; },
    context => { context.sources[0].url = 'not-a-source-url'; },
    context => { context.sources[0].quote = ''; },
    context => { context.sources[0].accessedAt = 'unknown'; }
  ];
  for (const mutate of mutations) {
    const damaged = JSON.parse(JSON.stringify(note));
    mutate(damaged.paperContext);
    const raw = JSON.stringify(snapshotWith([damaged]));
    assert.equal(validPaperMemory(damaged.paperContext), false);
    assert.throws(() => parseSnapshot(raw), /ARCHIVE_INVALID_RECORD/);
    assert.equal(JSON.parse(raw).records[0].paperContext !== undefined, true, '拒绝读取不能删改原始字节里的扩展');
    assert.equal(JSON.parse(raw).records[0].body, note.body);
  }
});

test('paper-memory: 用户保存时冻结选中的excerpt，之后重选和重剪不会改写旧note', () => {
  const selected = '纸灯的透光\n清末以来灯彩 / 原创纸景\n资料摘要：汴京灯笼张的灯彩技艺自清末以来传承。';
  const draft = contextFixture();
  draft.excerpt = selected;
  const note = { ...noteFixture(), paperContext: copyPaperMemory(draft) };
  const stored = copySnapshot(snapshotWith([note]));
  draft.excerpt = '另一段后来才选中的文字';
  draft.work = cutPaperStroke(draft.work, [{ x: 0.7, y: 0.65 }, { x: 0.8, y: 0.65 }], 1, 180).work;
  draft.sources[0].quote = '资料以后发生修订';
  const reopened = parseSnapshot(JSON.stringify(stored));
  assert.equal(reopened.records[0].paperContext.excerpt, selected);
  assert.deepEqual(reopened.records[0].paperContext.work, note.paperContext.work);
  assert.deepEqual(reopened.records[0].paperContext.sources, note.paperContext.sources);
  assert.equal(reopened.records[0].body, note.body);
  assert.equal(reopened.records[0].roamingContext, undefined);
});

test('paper-memory: 同版本不同excerpt参与比较，缺省保持缺省且损坏摘录不被静默删掉', () => {
  const noExcerpt = noteFixture();
  assert.equal(Object.hasOwn(copyPaperMemory(noExcerpt.paperContext), 'excerpt'), false);
  const selected = { ...noExcerpt, paperContext: { ...copyPaperMemory(noExcerpt.paperContext), excerpt: '我选中的一段材料' } };
  const changed = { ...noExcerpt, paperContext: { ...copyPaperMemory(noExcerpt.paperContext), excerpt: '另一段材料' } };
  assert.notEqual(compareVersions(noExcerpt, selected), 0);
  assert.notEqual(compareVersions(selected, changed), 0);
  assert.deepEqual(mergeRecords([selected], [changed]).records, mergeRecords([changed], [selected]).records);
  for (const excerpt of [42, '过长'.repeat(1201)]) {
    const malformed = { ...noExcerpt, paperContext: { ...copyPaperMemory(noExcerpt.paperContext), excerpt } };
    assert.equal(validPaperMemory(malformed.paperContext), false);
    assert.throws(() => parseSnapshot(JSON.stringify(snapshotWith([malformed]))), /ARCHIVE_INVALID_RECORD/);
    assert.equal(malformed.paperContext.excerpt, excerpt);
  }
});
