import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { domainModuleUrl } from './load-domain-module.mjs';

const {
  PAPER_COLUMNS, PAPER_ROWS, PAPER_HISTORY_LIMIT, PAPER_MAX_BODY, PAPER_CITY_IDS,
  createPaperWork, copyPaperWork, cutPaperStroke, undoPaper, setPaperFold, setPaperColor,
  togglePaperLight, judgePaper, paperCells, paperCellIsCut, parsePaperWork, serializePaperWork,
  mergePaperWork
} = await import(domainModuleUrl('PaperJourney'));
const { paperWorkRecordId, paperWorkFromRecords, paperWorkIsUnreadable, paperWorkRecord } =
  await import(domainModuleUrl('PaperJourneyRecords'));

// 测试只描述可重复的玩家笔迹与空间结果，不在这里复刻连通或评级算法。
// 故意为每城提供两种不同笔迹，避免把“多解”误写成一个硬编码答案的别名。
const point = (col, row) => ({ x: col / (PAPER_COLUMNS - 1), y: row / (PAPER_ROWS - 1) });
function stroke(work, coordinates, radius = 1) {
  const action = cutPaperStroke(work, coordinates.map(([x, y]) => point(x, y)), radius, work.updatedAt + 10);
  assert.equal(action.changed, true, '这条玩家笔迹应当实际改变纸面');
  return action.work;
}
function draw(cityId, strokes, radius = 1) {
  let work = createPaperWork(cityId, 100);
  for (const coordinates of strokes) work = stroke(work, coordinates, radius);
  return work;
}
function assertPassed(work) {
  const judgment = judgePaper(work);
  assert.equal(judgment.passed, true, JSON.stringify(judgment.checks.filter(check => !check.passed)));
  assert.equal(judgment.brokenCells.length, 0);
  assert.ok(work.completedAt > 0);
  assert.equal(work.completedMask, work.mask);
  return work;
}
const courtyardA = () => draw('paper-smx', [[[17, 21], [22, 21], [22, 26], [17, 26], [17, 23], [22, 23]]], 2);
const courtyardB = () => draw('paper-smx', [[[18, 21], [21, 25], [18, 26]]], 3);
const riverA = () => draw('paper-ly', [[[19, 9], [19, 38]]]);
const riverB = () => draw('paper-ly', [[[17, 9], [21, 18], [17, 27], [22, 38]]]);
const twinA = () => draw('paper-zz', [[[11, 10], [11, 28], [27, 28], [27, 10]]]);
const twinB = () => draw('paper-zz', [[[13, 10], [16, 23], [20, 30], [25, 23], [26, 10]]]);
const lanternA = () => draw('paper-kf', [[[9, 12], [11, 12]], [[27, 14], [29, 14]], [[17, 34], [20, 34]]]);
const lanternB = () => draw('paper-kf', [[[8, 15], [8, 18]], [[29, 27], [30, 27]], [[15, 36], [17, 36]], [[25, 8], [27, 8]]]);
const shellA = () => draw('paper-py', [[[12, 10]], [[20, 10]], [[28, 14]], [[29, 23]], [[23, 31]], [[15, 33]], [[8, 26]], [[7, 17]]]);
const shellB = () => draw('paper-py', [[[10, 10]], [[18, 10]], [[26, 14]], [[24, 22]], [[16, 24]], [[10, 31]], [[19, 36]], [[28, 34]]]);

test('paper: 五城空白纸均未完成，开灯、换色与切换折法不直接通关', () => {
  for (const cityId of PAPER_CITY_IDS) {
    let work = createPaperWork(cityId, 100);
    assert.equal(work.mask.length, 480);
    assert.equal(judgePaper(work).passed, false);
    work = togglePaperLight(work, 110).work;
    work = setPaperColor(work, '#A86B54', 120).work;
    work = setPaperFold(work, 'quarter', 130).work;
    assert.equal(judgePaper(work).passed, false);
    assert.equal(work.completedAt, 0);
  }
});

test('paper: 快速两端点笔迹剪出连续线段，外框仍可夹持', () => {
  const work = draw('paper-ly', [[[19, 0], [19, 47]]]);
  for (let row = 1; row < PAPER_ROWS - 1; row++) assert.equal(paperCellIsCut(work, 19, row), true);
  assert.equal(paperCellIsCut(work, 19, 0), false);
  assert.equal(paperCellIsCut(work, 19, PAPER_ROWS - 1), false);
  assert.equal(judgePaper(work).brokenCells.length, 0);
});

test('paper: 对折、四折在展开纸面形成真实镜像，换折法不修改旧剪口', () => {
  for (const fold of ['mirror', 'quarter']) {
    let work = setPaperFold(createPaperWork('paper-kf', 100), fold, 110).work;
    work = stroke(work, [[7, 10], [12, 14]]);
    const cells = paperCells(work.mask);
    for (let row = 0; row < PAPER_ROWS; row++) {
      for (let col = 0; col < PAPER_COLUMNS; col++) {
        assert.equal(cells[row * PAPER_COLUMNS + col], cells[row * PAPER_COLUMNS + PAPER_COLUMNS - 1 - col]);
        if (fold === 'quarter') assert.equal(cells[row * PAPER_COLUMNS + col], cells[(PAPER_ROWS - 1 - row) * PAPER_COLUMNS + col]);
      }
    }
    assert.equal(setPaperFold(work, 'none', 120).work.mask, work.mask);
  }
});

test('paper: 闭环剪断真实纸岛会反馈，撤回后原纸连通恢复', () => {
  const before = createPaperWork('paper-smx', 100);
  const broken = stroke(before, [[12, 14], [27, 14], [27, 33], [12, 33], [12, 14]]);
  const verdict = judgePaper(broken);
  assert.equal(verdict.passed, false);
  assert.ok(verdict.brokenCells.length > 0);
  assert.ok(verdict.connectedRatio < 1);
  assert.ok(verdict.title.includes('断开'));
  const restored = undoPaper(broken, 200).work;
  assert.equal(restored.mask, before.mask);
  assert.equal(judgePaper(restored).brokenCells.length, 0);
});

test('paper: 三门峡至少两种院落形状成立，只有细缝或切坏院壁不能冒充院落', () => {
  const a = assertPassed(courtyardA());
  const b = assertPassed(courtyardB());
  assert.notEqual(a.mask, b.mask);
  assert.equal(judgePaper(draw('paper-smx', [[[16, 23], [23, 23]]])).passed, false);
  const noWall = stroke(a, [[8, 15], [10, 32]], 2);
  assert.equal(judgePaper(noWall).checks.find(check => check.id === 'courtyard-walls').passed, false);
});

test('paper: 洛阳直河与弯河都贯通，上下两段未连或损坏两岸会失败', () => {
  const a = assertPassed(riverA());
  const b = assertPassed(riverB());
  assert.notEqual(a.mask, b.mask);
  const apart = draw('paper-ly', [[[19, 9], [19, 18]], [[19, 29], [19, 38]]]);
  assert.equal(judgePaper(apart).checks.find(check => check.id === 'river-window').passed, false);
  const noBank = stroke(a, [[6, 11], [6, 36]], 3);
  assert.equal(judgePaper(noBank).checks.find(check => check.id === 'river-banks').passed, false);
});

test('paper: 郑州两种双口共享腹腔成立，分离腹腔与只在上方横连都失败', () => {
  const a = assertPassed(twinA());
  const b = assertPassed(twinB());
  assert.notEqual(a.mask, b.mask);
  const separate = draw('paper-zz', [[[11, 10], [11, 28]], [[27, 10], [27, 28]]]);
  assert.equal(judgePaper(separate).checks.find(check => check.id === 'twin-chamber').passed, false);
  const topOnly = draw('paper-zz', [[[11, 10], [27, 10]]]);
  assert.equal(judgePaper(topOnly).passed, false);
  assert.equal(judgePaper(topOnly).checks.find(check => check.id === 'twin-mouths').passed, false);
});

test('paper: 开封多种分散光窗成立，连成一条缝或挤在一处不成立', () => {
  const a = assertPassed(lanternA());
  const b = assertPassed(lanternB());
  assert.notEqual(a.mask, b.mask);
  assert.equal(judgePaper(draw('paper-kf', [[[8, 15], [30, 15]]])).passed, false);
  const clustered = draw('paper-kf', [[[10, 20], [12, 20]], [[16, 20], [18, 20]], [[13, 25], [15, 25]]]);
  assert.equal(judgePaper(clustered).checks.find(check => check.id === 'lantern-spread').passed, false);
});

test('paper: 濮阳离散弧环与折线都成立，单缝、远散点与只有水平展开不成立', () => {
  const a = assertPassed(shellA());
  const b = assertPassed(shellB());
  assert.notEqual(a.mask, b.mask);
  assert.equal(judgePaper(draw('paper-py', [[[7, 15], [30, 30]]])).passed, false);
  const horizontal = draw('paper-py', [[[5, 20]], [[11, 20]], [[17, 20]], [[23, 20]], [[29, 20]], [[35, 20]]]);
  assert.equal(judgePaper(horizontal).passed, false);
  const remote = draw('paper-py', [[[3, 4]], [[19, 4]], [[36, 4]], [[3, 43]], [[19, 43]], [[36, 43]]]);
  assert.equal(judgePaper(remote).passed, false);
});

test('paper: 剪空纸面不能绕过五城空间与支撑目标', () => {
  for (const cityId of PAPER_CITY_IDS) {
    let work = createPaperWork(cityId, 100);
    for (let row = 5; row < PAPER_ROWS - 1; row += 9) work = stroke(work, [[3, row], [36, row]], 6);
    const verdict = judgePaper(work);
    assert.equal(verdict.passed, false);
    assert.equal(verdict.checks.find(check => check.id === 'paper-body').passed, false);
  }
});

test('paper: 同一剪口不重复加历史，四步撤销逐步恢复且复制不共享数组', () => {
  let work = createPaperWork('paper-kf', 100);
  const masks = [work.mask];
  for (let index = 0; index < 6; index++) {
    work = stroke(work, [[6 + index * 5, 12], [7 + index * 5, 12]]);
    masks.push(work.mask);
  }
  assert.equal(work.history.length, PAPER_HISTORY_LIMIT);
  const repeat = cutPaperStroke(work, [point(31, 12), point(32, 12)], 1, 300);
  assert.equal(repeat.changed, false);
  assert.deepEqual(repeat.work.history, work.history);
  const copied = copyPaperWork(work); copied.history.length = 0;
  assert.equal(work.history.length, PAPER_HISTORY_LIMIT);
  for (let index = 5; index >= 2; index--) {
    work = undoPaper(work, work.updatedAt + 10).work;
    assert.equal(work.mask, masks[index]);
  }
  assert.equal(undoPaper(work, 500).changed, false);
});

test('paper: 成立作品冻结后可以继续编辑或撤回，开灯不影响判断', () => {
  let work = assertPassed(lanternA());
  const frozenMask = work.completedMask;
  work = stroke(work, [[9, 12], [28, 14]]);
  assert.equal(judgePaper(work).passed, false);
  assert.equal(work.completedMask, frozenMask);
  assert.ok(work.completedAt > 0);
  assert.deepEqual(judgePaper(togglePaperLight(work, 500).work), judgePaper(work));
  const undone = undoPaper(work, 600).work;
  assert.equal(undone.mask, frozenMask);
  assert.equal(undone.completedMask, frozenMask);
});

test('paper: codec 保留展开图、撤销和完成快照，损坏或残缺作品不补成空白纸', () => {
  let work = assertPassed(shellA());
  work = stroke(work, [[12, 10], [20, 10]]);
  const text = serializePaperWork(work);
  assert.ok(text.length < PAPER_MAX_BODY);
  assert.deepEqual(parsePaperWork(text), work);
  const baseline = JSON.parse(text);
  const badValues = [
    { ...baseline, version: 2 }, { ...baseline, revision: 2 }, { ...baseline, cityId: 'roam-kf-night' },
    { ...baseline, mask: '0' }, { ...baseline, mask: 'g'.repeat(480) }, { ...baseline, light: 'true' },
    { ...baseline, history: Array(5).fill(baseline.mask) }, { ...baseline, fold: 'octuple' },
    { ...baseline, completedAt: baseline.updatedAt + 1 }, { ...baseline, completedMask: createPaperWork('paper-py', 1).mask }
  ];
  for (const bad of badValues) assert.equal(parsePaperWork(JSON.stringify(bad)), undefined);
  const missing = { ...baseline }; delete missing.completedMask;
  assert.equal(parsePaperWork(JSON.stringify(missing)), undefined);
  assert.equal(parsePaperWork('not-json'), undefined);
});

test('paper: 显式合并采用较新当前编辑并保留成立作品，不按位合成两端剪口', () => {
  const completed = assertPassed(lanternA());
  const newer = draw('paper-kf', [[[17, 20], [22, 20]]]);
  newer.updatedAt = completed.updatedAt + 100;
  const merged = mergePaperWork(completed, newer);
  assert.equal(merged.mask, newer.mask);
  assert.equal(merged.completedMask, completed.mask);
  assert.equal(merged.completedAt, completed.completedAt);
  assert.equal(judgePaper(merged).passed, false);
  assert.deepEqual(mergePaperWork(newer, completed), merged);
  assert.deepEqual(parsePaperWork(serializePaperWork(merged)), merged);
  const simultaneousColor = copyPaperWork(completed);
  simultaneousColor.paper = '#996644'; simultaneousColor.completedPaper = '#996644';
  assert.deepEqual(mergePaperWork(completed, simultaneousColor), mergePaperWork(simultaneousColor, completed));
  assert.throws(() => mergePaperWork(completed, createPaperWork('paper-smx', 100)), /CITY_MISMATCH/);
});

test('paper: 记录身份稳定，读回遵守 LWW 与墓碑，外层城市和正文城市必须一致', () => {
  const work = assertPassed(riverA());
  const record = paperWorkRecord(work, 'device-a', work.updatedAt + 20);
  assert.equal(record.id, 'progress:paper-journey:v1:paper-ly');
  assert.equal(record.kind, 'progress');
  assert.equal(record.siteId, 'paper-ly');
  assert.equal(record.roamingContext, undefined);
  assert.equal(paperWorkFromRecords([record], 'paper-ly').mask, work.mask);
  assert.equal(paperWorkFromRecords([record, { ...record, deleted: true, updatedAt: record.updatedAt + 1 }], 'paper-ly'), undefined);
  assert.equal(paperWorkFromRecords([{ ...record, siteId: 'paper-smx' }], 'paper-ly'), undefined);
  assert.equal(paperWorkFromRecords([{ ...record, body: serializePaperWork(createPaperWork('paper-smx', 1)) }], 'paper-ly'), undefined);
  assert.throws(() => paperWorkRecordId('paper-new-city'));
  assert.equal(paperWorkFromRecords([record], 'paper-new-city'), undefined);
});

test('paper: 已存在的损坏纸景可与空库区分，检查保留原正文与所有记录', () => {
  const record = paperWorkRecord(assertPassed(riverA()), 'device-a', 300);
  const invalid = [
    { ...record, body: '{broken' },
    { ...record, kind: 'note' },
    { ...record, siteId: 'paper-smx' },
    { ...record, body: serializePaperWork(createPaperWork('paper-smx', 100)) },
    { ...record, body: JSON.stringify({ ...createPaperWork('paper-ly', 100), mask: '0' }) }
  ];
  for (const damaged of invalid) {
    const unrelated = paperWorkRecord(createPaperWork('paper-kf', 100), 'device-b', 100);
    const records = [unrelated, damaged];
    const original = JSON.stringify(records);
    assert.equal(paperWorkFromRecords(records, 'paper-ly'), undefined);
    assert.equal(paperWorkIsUnreadable(records, 'paper-ly'), true,
      '同一稳定ID的身份或正文损坏，下一剪必须被保存入口拒绝');
    assert.equal(paperWorkIsUnreadable(records, 'paper-kf'), false);
    assert.equal(JSON.stringify(records), original, '检查不能修复、替换或清空原始记录');
  }
  assert.equal(paperWorkIsUnreadable([], 'paper-ly'), false, '真正没有记录才是新纸');
  assert.equal(paperWorkIsUnreadable([record], 'paper-ly'), false);
  assert.equal(paperWorkIsUnreadable([record], 'paper-new-city'), false);
});

test('paper: 损坏保护遵守有效版本与墓碑，较新的坏记录不能被较旧可读记录掩盖', () => {
  const readable = paperWorkRecord(assertPassed(riverA()), 'device-a', 300);
  const broken = { ...readable, body: '{broken', updatedAt: 400, deviceId: 'device-b' };
  for (const records of [[readable, broken], [broken, readable]]) {
    assert.equal(paperWorkIsUnreadable(records, 'paper-ly'), true);
    assert.equal(paperWorkFromRecords(records, 'paper-ly'), undefined);
  }
  const removed = { ...broken, deleted: true, updatedAt: 500 };
  assert.equal(paperWorkIsUnreadable([broken, removed], 'paper-ly'), false, '有效墓碑按原语义处理');
  assert.equal(paperWorkFromRecords([broken, removed], 'paper-ly'), undefined);
  const restored = { ...readable, updatedAt: 600 };
  assert.equal(paperWorkIsUnreadable([broken, restored], 'paper-ly'), false,
    '显式恢复产生新的可读版本后可以继续，不自动回退或改坏记录');
  assert.equal(paperWorkFromRecords([broken, restored], 'paper-ly').mask, parsePaperWork(readable.body).mask);
});

test('paper: 五城材料各有出处与原创边界，不把作品当遗址或工序复原', async () => {
  // 数据文件只有 type 导入或下面两项数据依赖；装载当前源码，不复制目录内容到断言里。
  const dataUrl = source => `data:text/javascript;base64,${Buffer.from(source).toString('base64')}`;
  const readData = name => stripTypeScriptTypes(readFileSync(new URL(`../entry/src/main/ets/data/${name}.ts`, import.meta.url), 'utf8'));
  const roamUrl = dataUrl(readData('RoamingCatalog'));
  const heritageUrl = dataUrl(readData('HeritageCatalog'));
  const catalogSource = readData('PaperJourneyCatalog')
    .replace("from './RoamingCatalog'", `from '${roamUrl}'`)
    .replace("from './HeritageCatalog'", `from '${heritageUrl}'`);
  const { PAPER_CITIES } = await import(dataUrl(catalogSource));
  assert.deepEqual(PAPER_CITIES.map(city => city.id), PAPER_CITY_IDS);
  for (const city of PAPER_CITIES) {
    assert.equal(city.sources.length, 3);
    assert.match(city.culture, /原创/);
    assert.ok(city.sources.every(source => source.quote && source.era && /^https?:\/\//.test(source.url)));
    assert.deepEqual(city.sourceIds, city.sources.map(source => source.id));
    assert.ok(city.photo === '' || city.photo.startsWith('photos/'));
  }
});
