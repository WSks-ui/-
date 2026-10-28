import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { domainModuleUrl } from './load-domain-module.mjs';

const { freezeMarketMemory, copyMarketMemory, validMarketMemory, canonicalMarketMemory } =
  await import(domainModuleUrl('MarketMemory'));
const { createMarketNight, applyMarketNightAction, beginMarketNightRound, advanceMarketNightBatch,
  endMarketNightRound } = await import(domainModuleUrl('RiverMarketV2'));
const { copySnapshot, parseSnapshot, compareVersions, mergeRecords, recordVersionConfirmed } =
  await import(domainModuleUrl('ArchiveDomain'));
const dataUrl = source => `data:text/javascript;base64,${Buffer.from(source).toString('base64')}`;
const { MARKET_CULTURES, MARKET_CULTURE_ENTRIES, MARKET_CULTURE_BOUNDARY,
  cultureIdForNight, marketCultureForId, recommendMarketCultures } = await import(dataUrl(stripTypeScriptTypes(
  readFileSync(new URL('../entry/src/main/ets/data/MarketCultureCatalog.ts', import.meta.url), 'utf8'))));

function context() {
  const entry = MARKET_CULTURES[1];
  const state = createMarketNight('night-2', 'west', 100);
  state.tourZone = 0;
  return freezeMarketMemory(state, entry.title, entry.revision, [entry.source], entry.quote);
}
function note(patch = {}) {
  return { id: 'note:market-a', kind: 'note', siteId: MARKET_CULTURES[1].id, body: '夜归人的一杯茶',
    tags: ['开封', '茶'], updatedAt: 200, deviceId: 'device-a', deleted: false, marketContext: context(), ...patch };
}
function snapshot(records) { return { schemaVersion: 1, deviceId: 'device-a', lightEnabled: true, reducedMotion: false, records }; }

test('market memory: 从真实三夜state冻结布局和摘要，无需通关也不保留逐客或整个state', () => {
  const state = createMarketNight('night-3', 'east', 100);
  const entry = MARKET_CULTURES[2];
  const frozen = freezeMarketMemory(state, entry.title, entry.revision, [entry.source], entry.quote);
  assert.equal(validMarketMemory(frozen), true);
  assert.equal(frozen.nightId, 'night-3'); assert.equal(frozen.routeId, 'east');
  assert.equal(frozen.round, 0); assert.equal(frozen.batch, 0);
  assert.deepEqual(Object.keys(frozen.layout).sort(), ['lamps', 'stalls', 'tourZone']);
  assert.deepEqual(Object.keys(frozen.summary).sort(), ['arrivals', 'cash', 'festivalServed', 'served', 'teaServed']);
  assert.equal(frozen.stock, undefined); assert.equal(frozen.reports, undefined); assert.equal(frozen.visits, undefined);
  state.stalls[2].workers = 0; state.lamps[1] = false; state.cash = 1; state.tourZone = 2;
  assert.equal(frozen.layout.stalls[2].workers, 2); assert.equal(frozen.layout.lamps[1], true);
  assert.equal(frozen.summary.cash, entry.nightId === 'night-3' ? 90 : 0); assert.equal(frozen.layout.tourZone, -1);
});

test('market memory: 缺油真实批次只冻结实际亮街，备市收市保留布置灯位且copy/parse往返不变', () => {
  const entry = MARKET_CULTURES[0];
  let state = createMarketNight('night-1', 'balanced', 100);
  const freeze = () => freezeMarketMemory(state, entry.title, entry.revision, [entry.source], entry.quote);
  const begin = () => {
    const result = beginMarketNightRound(state, state.updatedAt + 1);
    assert.equal(result.changed, true); state = result.state;
  };
  const batch = () => {
    const result = advanceMarketNightBatch(state, state.updatedAt + 1); state = result.state; return result.report;
  };
  const end = () => {
    const result = endMarketNightRound(state, state.updatedAt + 1);
    assert.equal(result.changed, true); state = result.state;
  };
  // 只用公开开段/迎客/收段动作，让原中街灯连续两段耗油；不直接改库存或造批次。
  for (let round = 0; round < 2; round++) { begin(); batch(); batch(); batch(); end(); }
  assert.equal(state.stock.oil, 1); assert.equal(state.round, 2); assert.equal(state.phase, 'prepare');
  for (const zone of [0, 2]) {
    const result = applyMarketNightAction(state, { kind: 'lamp', zone, on: true }, state.updatedAt + 1);
    assert.equal(result.changed, true); state = result.state;
  }
  assert.deepEqual(state.lamps, [true, true, true]);
  assert.deepEqual(freeze().layout.lamps, [true, true, true], '备市冻结用户布置');
  begin();
  assert.equal(state.phase, 'running'); assert.equal(state.stock.oil, 0);
  assert.deepEqual(state.effectiveLamps, [false, true, false]);
  assert.deepEqual(freeze().layout.lamps, [false, true, false], '开段后不能拿扣油后的库存重算或画亮三街');
  const report = batch();
  assert.equal(state.phase, 'emergency'); assert.equal(state.batch, 1);
  assert.deepEqual(report.effectiveLamps, [false, true, false]);
  const frozen = freeze();
  assert.deepEqual(frozen.layout.lamps, report.effectiveLamps, '营业暂停冻结当批真实照明');
  assert.notStrictEqual(frozen.layout.lamps, state.effectiveLamps);
  assert.deepEqual(copyMarketMemory(frozen), frozen);
  const saved = snapshot([note({ siteId: entry.id, marketContext: frozen })]);
  const roundTrip = parseSnapshot(JSON.stringify(copySnapshot(saved)));
  assert.deepEqual(roundTrip, saved);
  assert.deepEqual(roundTrip.records[0].marketContext.layout.lamps, [false, true, false]);
  batch(); batch();
  assert.equal(state.phase, 'settling');
  assert.deepEqual(freeze().layout.lamps, [false, true, false], '待收段仍是当段真实照明');
  end(); begin(); batch(); batch(); batch(); end();
  assert.equal(state.phase, 'closed'); assert.deepEqual(state.effectiveLamps, [false, false, false]);
  assert.deepEqual(freeze().layout.lamps, [true, true, true], '收市冻结布置，不能把清空的批次灯态当成关灯安排');
  assert.deepEqual(frozen.layout.lamps, [false, true, false], '后续经营不改写已保存的暂停图景');
});

test('market memory: copy/parse/备份JSON完整保留冻结来源，旧note不补字段或改stable ID', () => {
  const ordinary = note({ id: 'note:old', marketContext: undefined, quotedPoemOrFact: '旧摘录' });
  delete ordinary.marketContext;
  const saved = snapshot([ordinary, note()]);
  const parsed = parseSnapshot(JSON.stringify(saved));
  assert.deepEqual(parsed, saved);
  assert.equal(Object.hasOwn(parsed.records[0], 'marketContext'), false);
  const copied = copySnapshot(parsed);
  assert.deepEqual(copied, saved);
  copied.records[1].marketContext.layout.stalls[2].workers = 0;
  copied.records[1].marketContext.layout.lamps[1] = false;
  copied.records[1].marketContext.summary.cash = 1;
  copied.records[1].marketContext.sources[0].quote = '改变副本';
  assert.equal(saved.records[1].marketContext.layout.stalls[2].workers, 2);
  assert.equal(saved.records[1].marketContext.layout.lamps[1], true);
  assert.equal(saved.records[1].marketContext.summary.cash, 70);
  assert.equal(saved.records[1].marketContext.sources[0].quote, MARKET_CULTURES[1].quote);
  assert.equal(copied.records[0].id, ordinary.id); assert.equal(copied.records[0].updatedAt, ordinary.updatedAt);
});

test('market memory: 冻结元数据参与确定性LWW与确认，正文相同不抹掉布局/来源差异', () => {
  const original = note(); const changed = note(); changed.marketContext.summary.cash += 1;
  assert.notEqual(compareVersions(original, changed), 0);
  assert.equal(recordVersionConfirmed(original, [changed]), false);
  assert.deepEqual(mergeRecords([original], [changed]), mergeRecords([changed], [original]));
  const reordered = note();
  reordered.marketContext = Object.fromEntries(Object.entries(reordered.marketContext).reverse());
  reordered.marketContext.summary = Object.fromEntries(Object.entries(reordered.marketContext.summary).reverse());
  reordered.marketContext.layout = Object.fromEntries(Object.entries(reordered.marketContext.layout).reverse());
  assert.equal(canonicalMarketMemory(reordered.marketContext), canonicalMarketMemory(original.marketContext));
  assert.equal(compareVersions(original, reordered), 0);
  const sourceRevision = note(); sourceRevision.marketContext.sources[0].accessedAt = '2026-10-27';
  assert.notEqual(compareVersions(original, sourceRevision), 0);
});

test('market memory: 只改body/tags保留context，墓碑合并不复活记忆或丢出处', () => {
  const original = note(); const edited = copySnapshot(snapshot([original])).records[0];
  edited.body = '补写夜归时的感受'; edited.tags = ['茶']; edited.updatedAt++;
  assert.deepEqual(edited.marketContext, original.marketContext);
  const tombstone = { ...edited, deleted: true, updatedAt: edited.updatedAt + 1, deviceId: 'device-b' };
  const merged = mergeRecords([tombstone], [original]).records[0];
  assert.equal(merged.deleted, true); assert.deepEqual(merged.marketContext, original.marketContext);
  assert.deepEqual(parseSnapshot(JSON.stringify(snapshot([merged]))).records[0], tombstone);
});

test('market memory: 损坏扩展拒绝读取，不静默删除上下文后覆盖旧记录', () => {
  const original = context();
  const invalid = [
    { ...original, version: 2 }, { ...original, nightId: 'night-9' }, { ...original, routeId: 'secret' },
    { ...original, contentRevision: 0 }, { ...original, batch: 4 },
    { ...original, layout: { ...original.layout, lamps: [true] } },
    { ...original, layout: { ...original.layout, stalls: original.layout.stalls.slice(1) } },
    { ...original, layout: { ...original.layout, tourZone: 4 } },
    { ...original, summary: { ...original.summary, served: 1, arrivals: 0 } },
    { ...original, sources: [{ ...original.sources[0], quote: '' }] }
  ];
  for (const damaged of invalid) {
    assert.equal(validMarketMemory(damaged), false);
    const raw = JSON.stringify(snapshot([note({ marketContext: damaged })]));
    assert.throws(() => parseSnapshot(raw), /ARCHIVE_INVALID_RECORD/);
  }
  assert.equal(validMarketMemory({ ...original, sceneRevision: 2 }), true, '较新图景可归档，界面选择是否支持回放');
});

test('market culture: 三篇独立稳定ID、卷次短引和年代可追溯，遗址目录仍是22处', async () => {
  assert.deepEqual(MARKET_CULTURES.map(entry => entry.id),
    ['culture-kf-night-market', 'culture-kf-bottle-tea', 'culture-kf-lantern-festival']);
  assert.equal(MARKET_CULTURE_ENTRIES.length, 3);
  for (const entry of MARKET_CULTURES) {
    assert.equal(entry.revision, 1); assert.equal(entry.source.accessedAt, '2026-10-26');
    assert.match(entry.era, /南宋追记北宋/); assert.match(entry.source.url, /^https:\/\/zh\.wikisource\.org\//);
    assert.ok(entry.source.quote.includes(entry.quote.split('\n')[0]));
    assert.equal(cultureIdForNight(entry.nightId), entry.id); assert.equal(marketCultureForId(entry.id), entry);
    assert.match(entry.gameConnection, /原创/);
  }
  assert.match(MARKET_CULTURE_BOUNDARY, /初稿待校审/);
  const heritageSource = stripTypeScriptTypes(readFileSync(new URL('../entry/src/main/ets/data/HeritageCatalog.ts', import.meta.url), 'utf8'));
  const { HERITAGE_SITES } = await import(dataUrl(heritageSource));
  assert.equal(HERITAGE_SITES.length, 22);
  assert.ok(HERITAGE_SITES.every(site => !site.id.startsWith('culture-kf-')));
});

test('market culture: 推荐只取真实阅读、收藏、note标签，经营progress不伪装阅读', () => {
  const game = { id: 'progress:river-market:v2:kaifeng:night-2', kind: 'progress', siteId: MARKET_CULTURES[1].id,
    body: JSON.stringify(createMarketNight('night-2', 'balanced', 100)), tags: ['茶'], updatedAt: 100, deviceId: 'device-a', deleted: false };
  assert.deepEqual(recommendMarketCultures([game]), recommendMarketCultures([]));
  const opened = { ...game, id: `progress:${MARKET_CULTURES[0].id}`, siteId: MARKET_CULTURES[0].id, body: 'opened' };
  assert.ok(recommendMarketCultures([opened]).some(item => item.reason.includes('读过')));
  const favorite = { ...opened, id: `favorite:${MARKET_CULTURES[0].id}`, kind: 'favorite', body: '', tags: ['研究资料'] };
  assert.ok(recommendMarketCultures([favorite]).some(item => item.reason.includes('收藏')));
  assert.ok(recommendMarketCultures([note()]).some(item => item.reason.includes('标签')));
  assert.deepEqual(recommendMarketCultures([{ ...favorite, deleted: true }]), recommendMarketCultures([]));
});
