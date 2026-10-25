import test from 'node:test';
import assert from 'node:assert/strict';
import { domainModuleUrl } from './load-domain-module.mjs';

const { compareVersions, copySnapshot, emptySnapshot, mergeRecords, parseSnapshot, recordVersionConfirmed } =
  await import(domainModuleUrl('ArchiveDomain'));
const { emptyKaifengCity, parseKaifengCity, kaifengCityRecordId, serializeKaifengCity } =
  await import(domainModuleUrl('KaifengPuzzle'));
const { emptyDig, digRecordId, parseDig, serializeDig } = await import(domainModuleUrl('KaifengDig'));
const { kaifengDigFromRecords, kaifengDigRecord } = await import(domainModuleUrl('KaifengDigRecords'));
const { PAPER_COLUMNS, PAPER_ROWS, createPaperWork, cutPaperStroke, judgePaper, parsePaperWork } =
  await import(domainModuleUrl('PaperJourney'));
const { paperWorkRecord, paperWorkRecordId } = await import(domainModuleUrl('PaperJourneyRecords'));

const CHAPTER = 'roam-kf-night';
const cityRecord = (city, deviceId = 'device-a', updatedAt = city.updatedAt) => ({
  id: kaifengCityRecordId(city.chapterId), kind: 'progress', siteId: city.chapterId,
  body: serializeKaifengCity(city), tags: [], updatedAt, deviceId, deleted: false
});
const digRecord = (dig, deviceId = 'device-a', updatedAt = dig.updatedAt) => kaifengDigRecord(dig, deviceId, updatedAt);
const mergedRecord = (a, b) => mergeRecords([a], [b]).records[0];

// 直接覆盖所有真实同步入口共用的 mergeRecords，而不是再实现一份“测试专用合并”。
test('game progress: 城市实际合并完成并集、非空材料、最新桥灯和最早成志时间', () => {
  const a = emptyKaifengCity(CHAPTER, 100);
  a.acts.bridge = true;
  a.acts.note = true;
  a.layers.lower = 'song-base';
  a.motif.center = 'horse';
  a.closedAt = 90;
  const b = emptyKaifengCity(CHAPTER, 200);
  b.acts.layers = true;
  b.layers.middle = 'ming-deck';
  b.motif.bottom = 'cloud';
  b.bridge.x = 420;
  b.lights = [{ id: 'l1', x: 500, y: 600 }];
  b.closedAt = 190;
  const left = cityRecord(a, 'device-a');
  const right = cityRecord(b, 'device-b');
  const originals = structuredClone([left, right]);
  const result = mergedRecord(left, right);
  const city = parseKaifengCity(result.body);
  assert.equal(city.acts.bridge, true);
  assert.equal(city.acts.layers, true);
  assert.equal(city.acts.note, true);
  assert.equal(city.layers.lower, 'song-base');
  assert.equal(city.layers.middle, 'ming-deck');
  assert.equal(city.motif.center, 'horse');
  assert.equal(city.motif.bottom, 'cloud');
  assert.equal(city.bridge.x, 420);
  assert.deepEqual(city.lights, b.lights);
  assert.equal(city.closedAt, 90);
  assert.equal(result.updatedAt, right.updatedAt);
  assert.equal(result.deviceId, right.deviceId, '版本信封仍使用原版本比较的获选方');
  assert.deepEqual([left, right], originals, '不能修改仍被页面或调用方持有的旧记录');
  assert.deepEqual(mergedRecord(right, left), result);
});

test('game progress: 城市同刻冲突和多次收包稳定，双鹤并集不复制同一片', () => {
  const a = emptyKaifengCity(CHAPTER, 100);
  a.bridge.x = 300;
  a.motif.left = 'crane-a';
  const b = emptyKaifengCity(CHAPTER, 100);
  b.bridge.x = 600;
  b.motif.right = 'crane-a';
  const c = emptyKaifengCity(CHAPTER, 100);
  c.acts.lantern = true;
  c.motif.left = 'crane-b';
  const records = [cityRecord(a, 'device-a'), cityRecord(b, 'device-b'), cityRecord(c, 'device-c')];
  const ab = mergedRecord(records[0], records[1]);
  const partial = parseKaifengCity(ab.body);
  assert.equal([partial.motif.left, partial.motif.right].filter(value => value === 'crane-a').length, 1);
  const abc = mergedRecord(ab, records[2]);
  const reverse = mergedRecord(mergedRecord(records[2], records[1]), records[0]);
  assert.deepEqual(abc, reverse);
  const city = parseKaifengCity(abc.body);
  assert.ok(city);
  assert.deepEqual([city.motif.left, city.motif.right], ['crane-a', 'crane-b']);
  assert.equal(city.acts.lantern, true);
  assert.deepEqual(mergedRecord(abc, records[1]), abc, '重复收到原版本不能撤回已完成材料');
});

test('game progress: 探方的大局号和历史最佳进入通用合并，旧局晚时钟不冻结后续操作', () => {
  const old = { ...emptyDig(CHAPTER, 1, 900), bestGrade: '甲' };
  const next = { ...emptyDig(CHAPTER, 2, 100), answerColumn: 1 };
  const merged = mergedRecord(digRecord(old, 'device-a'), digRecord(next, 'device-b'));
  const state = kaifengDigFromRecords([merged], CHAPTER);
  assert.equal(state.attempt, 2);
  assert.equal(state.bestGrade, '甲');
  assert.equal(state.answerColumn, 1);
  assert.equal(state.updatedAt, 100);
  assert.equal(merged.updatedAt, 900, '原版本信封仍取较大逻辑时间');
  const edited = { ...next, answerColumn: 4, updatedAt: 200 };
  const received = mergedRecord(merged, digRecord(edited, 'device-b'));
  assert.equal(parseDig(received.body).answerColumn, 4);
  assert.equal(parseDig(received.body).bestGrade, '甲');
  assert.deepEqual(mergedRecord(digRecord(edited, 'device-b'), merged), received);
  assert.deepEqual(mergedRecord(received, digRecord(old, 'device-a')), received);
});

test('game progress: 探方同局同刻的选择稳定，最佳并入不会反过来改变局面', () => {
  const a = { ...emptyDig(CHAPTER, 2, 100), answerColumn: 1, bestGrade: '甲' };
  const b = { ...emptyDig(CHAPTER, 2, 100), answerColumn: 3 };
  const c = { ...emptyDig(CHAPTER, 2, 100), answerColumn: 2, bestGrade: '乙' };
  const records = [digRecord(a, 'device-a'), digRecord(b, 'device-b'), digRecord(c, 'device-c')];
  const merged = mergedRecord(mergedRecord(records[0], records[1]), records[2]);
  const reverse = mergedRecord(mergedRecord(records[2], records[1]), records[0]);
  assert.deepEqual(merged, reverse);
  assert.equal(parseDig(merged.body).answerColumn, 3);
  assert.equal(parseDig(merged.body).bestGrade, '甲');
});

test('game progress: 墓碑继续使用旧版本规则，合法旧 note 的镜头和冻结 AI 依据不受影响', () => {
  const progress = cityRecord(emptyKaifengCity(CHAPTER, 100));
  const deleted = { ...progress, deviceId: 'device-b', deleted: true };
  assert.equal(mergedRecord(progress, deleted).deleted, true);
  assert.deepEqual(mergedRecord(deleted, progress), deleted);
  const note = { id: 'note:legacy', kind: 'note', siteId: 'zz-duling', body: '原笔记', tags: ['旧标签'],
    updatedAt: 100, deviceId: 'device-a', deleted: false,
    snapshot3DPose: { version: 1, sceneType: 'bronze', yaw: 0, pitch: 0, zoom: 1,
      hotspotId: '', sectionId: '', label: '原镜头' },
    aiAssist: { version: 1, question: '原问题', factIds: ['old-fact'], contentRevision: 1,
      facts: [{ id: 'old-fact', title: '保存时的事实', body: '保存时的事实正文', sourceIds: ['old-source'] }] } };
  const edited = { ...note, body: '新正文', updatedAt: 200, deviceId: 'device-b' };
  const record = mergedRecord(note, edited);
  assert.deepEqual(record, edited);
  assert.equal(compareVersions(record, edited), 0);
  assert.equal(recordVersionConfirmed(record, [edited]), true);
  const snapshot = { ...emptySnapshot('local-device'), records: [record] };
  assert.deepEqual(parseSnapshot(JSON.stringify(copySnapshot(snapshot))), snapshot);
});

test('game progress: 未识别、正文损坏或章节不匹配时保留原文并继续旧 LWW', () => {
  const valid = digRecord(emptyDig(CHAPTER, 1, 100));
  const broken = { ...valid, body: '{broken', updatedAt: 200, deviceId: 'device-b' };
  assert.deepEqual(mergedRecord(valid, broken), broken);
  const otherChapter = { ...emptyDig('roam-ly-spring', 2, 200), bestGrade: '甲' };
  const mismatch = { ...valid, body: serializeDig(otherChapter), updatedAt: 200, deviceId: 'device-b' };
  assert.deepEqual(mergedRecord(valid, mismatch), mismatch);
  const ordinary = { ...valid, id: 'progress:legacy', body: 'opened' };
  const newer = { ...ordinary, body: 'still-opened', updatedAt: 200, deviceId: 'device-b' };
  assert.deepEqual(mergedRecord(ordinary, newer), newer);
  const oldCity = cityRecord(emptyKaifengCity(CHAPTER, 100));
  const oversized = { ...emptyKaifengCity(CHAPTER, 200), lights: [{ id: 'x'.repeat(1800), x: 1, y: 1 }] };
  const opaqueCity = { ...oldCity, body: JSON.stringify(oversized), updatedAt: 200, deviceId: 'device-b' };
  assert.ok(opaqueCity.body.length < 4000, '旧 v1 信封仍允许归档这份正文');
  assert.deepEqual(mergedRecord(oldCity, opaqueCity), opaqueCity,
    '新玩法 codec 的更小自上限不能阻断旧快照合并或改写原文');
});

test('game progress: 合成内容只有收到同一版本回包才确认，双方重复交换后收敛', () => {
  const a = emptyKaifengCity(CHAPTER, 100);
  a.layers.lower = 'song-base';
  const b = emptyKaifengCity(CHAPTER, 200);
  b.layers.upper = 'burial-silt';
  const left = cityRecord(a, 'device-a');
  const right = cityRecord(b, 'device-b');
  const server = mergedRecord(left, right);
  assert.equal(recordVersionConfirmed(server, [right]), false);
  assert.equal(recordVersionConfirmed(server, [server]), true);
  const deviceA = mergedRecord(left, server);
  const deviceB = mergedRecord(right, server);
  assert.deepEqual(deviceA, server);
  assert.deepEqual(deviceB, server);
  assert.deepEqual(mergedRecord(deviceA, deviceB), server);
});

function paperStroke(work, start, end, time) {
  const points = [start, end].map(([col, row]) => ({ x: col / (PAPER_COLUMNS - 1), y: row / (PAPER_ROWS - 1) }));
  const action = cutPaperStroke(work, points, 1, time);
  assert.equal(action.changed, true);
  return action.work;
}

test('game progress: 纸景当前剪口整条LWW，正反交换不合成双方未剪过的mask', () => {
  const blank = createPaperWork('paper-kf', 100);
  const a = paperStroke(blank, [8, 12], [12, 12], 200);
  const b = paperStroke(blank, [27, 14], [31, 14], 300);
  const left = paperWorkRecord(a, 'device-a', a.updatedAt);
  const right = paperWorkRecord(b, 'device-b', b.updatedAt);
  const merged = mergedRecord(left, right);
  assert.deepEqual(mergedRecord(right, left), merged);
  const work = parsePaperWork(merged.body);
  assert.deepEqual(work, b, 'mask/history/纸色/折法须来自同一当前版本');
  assert.notEqual(work.mask, a.mask);
  assert.equal(work.history.length, 1, '两台设备的一剪不能拼成两次撤销历史');
  assert.equal(merged.id, paperWorkRecordId('paper-kf'));
  assert.deepEqual(mergedRecord(merged, left), merged);
});

test('game progress: 较新纸景编辑保留已完成快照，回包只有完整合成版本才确认', () => {
  let completed = createPaperWork('paper-kf', 100);
  completed = paperStroke(completed, [9, 12], [11, 12], 110);
  completed = paperStroke(completed, [27, 14], [29, 14], 120);
  completed = paperStroke(completed, [17, 34], [20, 34], 130);
  assert.equal(judgePaper(completed).passed, true);
  assert.ok(completed.completedAt > 0);
  const edited = paperStroke(createPaperWork('paper-kf', 200), [19, 10], [19, 16], 300);
  assert.equal(edited.completedAt, 0);
  const left = paperWorkRecord(completed, 'device-a', completed.updatedAt);
  const right = paperWorkRecord(edited, 'device-b', edited.updatedAt);
  const merged = mergedRecord(left, right);
  const work = parsePaperWork(merged.body);
  assert.equal(work.mask, edited.mask, '当前编辑不被历史完成图替换');
  assert.equal(work.completedMask, completed.completedMask);
  assert.equal(work.completedPaper, completed.completedPaper);
  assert.equal(work.completedAt, completed.completedAt);
  assert.deepEqual(mergedRecord(right, left), merged);
  assert.equal(recordVersionConfirmed(merged, [right]), false,
    '同时间同设备信封仍不足以确认额外保留的完成快照');
  assert.equal(recordVersionConfirmed(merged, [merged]), true);
  assert.deepEqual(mergedRecord(merged, right), merged);
});

test('game progress: 纸景墓碑保持原优先规则，身份或正文不匹配保留原LWW记录', () => {
  const work = createPaperWork('paper-kf', 100);
  const record = paperWorkRecord(work, 'device-a', 100);
  const tombstone = { ...record, deleted: true, deviceId: 'device-b' };
  assert.deepEqual(mergedRecord(record, tombstone), tombstone);
  assert.deepEqual(mergedRecord(tombstone, record), tombstone);
  const wrongCity = { ...record, body: JSON.stringify(createPaperWork('paper-ly', 200)), updatedAt: 200, deviceId: 'device-b' };
  assert.deepEqual(mergedRecord(record, wrongCity), wrongCity);
  const wrongSite = { ...record, siteId: 'paper-ly', updatedAt: 200, deviceId: 'device-b' };
  assert.deepEqual(mergedRecord(record, wrongSite), wrongSite);
  const broken = { ...record, body: '{broken', updatedAt: 200, deviceId: 'device-b' };
  assert.deepEqual(mergedRecord(record, broken), broken);
});
