import test from 'node:test';
import assert from 'node:assert/strict';
import { domainModuleUrl } from './load-domain-module.mjs';

const { createRiverMarket, copyRiverMarket, applyMarketAction, advanceMarketRound, marketForecast,
  marketSummary, parseRiverMarket, serializeRiverMarket, MARKET_STALL_TYPES, MARKET_LOTS, MARKET_LOSS_REASONS,
  MARKET_BODY_LIMIT, MARKET_TARGET_SERVED, MARKET_TARGET_CASH } = await import(domainModuleUrl('RiverMarket'));
const { RIVER_MARKET_RECORD_ID, riverMarketRecord, riverMarketFromRecords, riverMarketIsDeleted, riverMarketIsUnreadable } =
  await import(domainModuleUrl('RiverMarketRecords'));

const buy = resource => ({ kind: 'buy', resource });
const staff = (lotId, delta) => ({ kind: 'staff', lotId, delta });
const lamp = (zone, on) => ({ kind: 'lamp', zone, on });
const build = (lotId, stallType) => ({ kind: 'build', lotId, stallType });
function act(state, action) {
  const result = applyMarketAction(state, action, state.updatedAt + 10);
  assert.equal(result.changed, true, `${JSON.stringify(action)}：${result.message}`);
  return result.state;
}
function advance(state) { return advanceMarketRound(state, state.updatedAt + 20); }
function loss(report, reason) { return report.reasonCounts.find(item => item.reason === reason).count; }

// 两套方案直接走公开经营动作，不用改stock/served制造成功，也不使用隐藏重试种子。
function prepare(style) {
  let state = createRiverMarket(100);
  if (style === 'spread') {
    state = act(state, { kind: 'demolish', lotId: 3 });
    state = act(state, build(4, 'meat'));
    state = act(state, staff(4, 1)); state = act(state, staff(4, 1));
  }
  state = act(state, build(0, 'tea'));
  state = act(state, staff(0, 1)); state = act(state, staff(0, 1));
  return act(state, lamp(1, false));
}

function play(style) {
  let state = style === 'default' ? createRiverMarket(100) : prepare(style);
  const reports = [];
  for (let round = 0; round < 4; round++) {
    if (style !== 'default') {
      if (round === 1) {
        state = act(state, buy('meat')); state = act(state, buy(style === 'spread' ? 'tea' : 'rice'));
      }
      if (round === 2) {
        state = act(state, buy('oil')); state = act(state, buy('meat'));
        for (let zone = 0; zone < 3; zone++) state = act(state, lamp(zone, true));
      }
      if (round === 3) {
        if (style === 'spread') { state = act(state, staff(2, -1)); state = act(state, staff(0, 1)); }
        state = act(state, buy('meat')); state = act(state, buy(style === 'spread' ? 'rice' : 'tea'));
      }
    }
    const result = advance(state); state = result.state; reports.push(result.report);
    assert.deepEqual(parseRiverMarket(serializeRiverMarket(state)), state);
  }
  return { state, reports, summary: marketSummary(state) };
}

test('market: 新局从未营业，四段预告完整且无随机；逐客来源和偏好与预告相符', () => {
  const blank = createRiverMarket(100);
  assert.equal(blank.round, 0); assert.equal(blank.served, 0); assert.equal(blank.arrivals, 0);
  assert.equal(blank.reports.length, 0); assert.equal(marketSummary(blank).passed, false);
  assert.deepEqual(blank.stock, { rice: 24, meat: 10, tea: 16, oil: 3 });
  assert.equal(blank.stalls[2].type, 'rice'); assert.equal(blank.stalls[3].type, 'meat');
  assert.equal(marketSummary(blank).freeWorkers, 2);
  let state = blank;
  const arrivals = [];
  const titles = [];
  for (let round = 0; round < 4; round++) {
    const forecast = marketForecast(state);
    titles.push(forecast.title);
    const first = advance(state), second = advance(copyRiverMarket(state));
    assert.deepEqual(first, second);
    assert.equal(first.report.visits.length, forecast.arrivals);
    assert.ok(first.report.visits.length <= 32);
    assert.deepEqual(MARKET_STALL_TYPES.map(config => first.report.visits.filter(visit => visit.preference === config.type).length), forecast.preferences);
    assert.deepEqual([0, 1, 2].map(zone => first.report.visits.filter(visit => visit.origin === zone).length), forecast.zoneArrivals);
    arrivals.push(forecast.arrivals); state = first.state;
  }
  assert.deepEqual(arrivals, [18, 26, 32, 24]);
  assert.deepEqual(titles, ['灯起开市', '人盛街巷', '夜深卖茶', '五更再开']);
  assert.equal(state.arrivals, 100); assert.equal(marketForecast(state).arrivals, 0);
});

test('market: 默认不调布局、不补货、不排闲人会失败，流失原因对应缺货与缺铺', () => {
  const result = play('default');
  assert.equal(result.summary.closed, true); assert.equal(result.summary.passed, false);
  assert.equal(result.state.served, 34);
  assert.ok(result.reports.some(report => loss(report, 'stock') > 0));
  assert.ok(result.reports.some(report => loss(report, 'missing') > 0));
  assert.ok(result.reports.some(report => report.advice.some(text => text.includes('卖空'))));
  assert.ok(result.state.served < MARKET_TARGET_SERVED);
});

test('market: 加茶铺、适时补货并留灯的方案成立，静态布局也不是无脑必胜', () => {
  const result = play('balanced');
  assert.equal(result.summary.passed, true);
  assert.equal(result.state.served, 71);
  assert.equal(result.state.cash, 209);
  assert.ok(result.state.served >= MARKET_TARGET_SERVED && result.state.cash >= MARKET_TARGET_CASH);
  assert.ok(result.reports.some(report => loss(report, 'crowd') > 0), '中街仍有可解释的空间代价');
});

test('market: 东移肉铺、提前备茶、末段转班是另一条成立路径，并改善中街拥挤', () => {
  const balanced = play('balanced');
  const spread = play('spread');
  assert.equal(spread.summary.passed, true);
  assert.equal(spread.state.served, 82); assert.equal(spread.state.cash, 241);
  assert.equal(spread.state.stalls[3].type, ''); assert.equal(spread.state.stalls[4].type, 'meat');
  assert.equal(spread.state.stalls[0].workers, 3); assert.equal(spread.state.stalls[2].workers, 1);
  assert.ok(spread.reports.reduce((sum, report) => sum + loss(report, 'crowd'), 0) <
    balanced.reports.reduce((sum, report) => sum + loss(report, 'crowd'), 0));
  assert.notDeepEqual(spread.state.stock, balanced.state.stock);
});

test('market: 同一段只补肉会减少缺肉流失，经营动作在本段真实生效', () => {
  const first = advance(createRiverMarket(100)).state;
  const noSupply = advance(first).report;
  const supplied = advance(act(first, buy('meat'))).report;
  assert.ok(loss(noSupply, 'stock') > loss(supplied, 'stock'));
  assert.ok(supplied.visits.filter(visit => visit.served && visit.preference === 'meat').length >
    noSupply.visits.filter(visit => visit.served && visit.preference === 'meat').length);
});

test('market: 前两段不点灯不惩罚，深夜开灯确实减少暗路流失并消耗库存油', () => {
  const early = createRiverMarket(100);
  const darkEarly = act(early, lamp(1, false));
  assert.equal(advance(early).report.served, advance(darkEarly).report.served);
  assert.equal(advance(early).state.stock.oil + 1, advance(darkEarly).state.stock.oil);
  let late = prepare('spread');
  late = advance(late).state;
  late = act(late, buy('meat')); late = act(late, buy('tea')); late = advance(late).state;
  late = act(late, buy('oil')); late = act(late, buy('meat'));
  const dark = advance(late);
  let litState = late;
  for (let zone = 0; zone < 3; zone++) litState = act(litState, lamp(zone, true));
  const lit = advance(litState);
  assert.ok(loss(dark.report, 'dark') > loss(lit.report, 'dark'));
  assert.ok(lit.report.served > dark.report.served);
  assert.equal(lit.report.oilUsed, 3); assert.equal(lit.state.stock.oil, litState.stock.oil - 3);
});

test('market: 拨少一名伙计降低该铺接待能力，满员约束与工资由实际排班决定', () => {
  const staffed = prepare('balanced');
  const fewer = act(staffed, staff(2, -1));
  const a = advance(staffed).report, b = advance(fewer).report;
  assert.ok(a.servedByLot[2] > b.servedByLot[2]);
  assert.ok(loss(b, 'workers') > loss(a, 'workers'));
  assert.equal(a.wages - b.wages, 2);
  const rejected = applyMarketAction(staffed, staff(0, 1), 900);
  assert.equal(rejected.changed, false); assert.match(rejected.message, /6名/);
  assert.deepEqual(rejected.state, staffed);
});

test('market: 每段两趟补货、现钱、空地与人手均有真实约束；收铺退部分钱并释放人手', () => {
  let state = createRiverMarket(100);
  state = act(state, buy('meat')); state = act(state, buy('tea'));
  const third = applyMarketAction(state, buy('oil'), 200);
  assert.equal(third.changed, false); assert.match(third.message, /两趟/);
  assert.equal(third.state.stock.oil, 3);
  assert.equal(advance(state).state.supplyTrips, 0);
  let spent = act(createRiverMarket(100), build(0, 'meat'));
  spent = act(spent, build(1, 'meat'));
  assert.equal(applyMarketAction(spent, build(4, 'meat'), 300).changed, false);
  assert.equal(applyMarketAction(spent, build(2, 'tea'), 300).changed, false);
  assert.equal(applyMarketAction(spent, staff(4, 1), 300).changed, false);
  const before = createRiverMarket(100);
  const removed = act(before, { kind: 'demolish', lotId: 3 });
  assert.equal(removed.cash - before.cash, 12);
  assert.equal(removed.stalls[3].workers, 0); assert.equal(marketSummary(removed).freeWorkers, 4);
  assert.equal(applyMarketAction(removed, { kind: 'demolish', lotId: 3 }, 300).changed, false);
});

test('market: 一客一事件，收入库存和每铺接待可核账，回放对象不共享持久历史', () => {
  const before = prepare('balanced');
  const result = advance(before), report = result.report;
  assert.equal(new Set(report.visits.map(visit => visit.guestId)).size, report.arrivals);
  assert.equal(report.visits.filter(visit => visit.served).length, report.served);
  assert.equal(report.visits.filter(visit => !visit.served).length, report.lost);
  for (const visit of report.visits) {
    if (visit.served) assert.equal(before.stalls[visit.lotId].type, visit.preference);
    else { assert.equal(visit.lotId, -1); assert.ok(MARKET_LOSS_REASONS.includes(visit.reason)); }
  }
  assert.equal(report.income, report.visits.filter(visit => visit.served).reduce((sum, visit) =>
    sum + MARKET_STALL_TYPES.find(config => config.type === visit.preference).price, 0));
  for (const resource of ['rice', 'meat', 'tea']) assert.equal(before.stock[resource] - result.state.stock[resource], report.stockUsed[resource]);
  assert.equal(result.state.cash, before.cash + report.income - report.expenses);
  assert.equal(report.servedByLot.reduce((sum, value) => sum + value, 0), report.served);
  report.reasons[0] = 999;
  assert.notEqual(result.state.reports[0].reasons[0], 999);
  assert.deepEqual(before, prepare('balanced'));
});

test('market: 四段结束后不再营业或改账，codec紧凑往返且损坏不补成新局', () => {
  const closed = play('spread').state;
  assert.throws(() => advance(closed), /MARKET_ALREADY_CLOSED/);
  assert.equal(applyMarketAction(closed, buy('tea'), 500).changed, false);
  const body = serializeRiverMarket(closed);
  assert.ok(body.length < MARKET_BODY_LIMIT);
  assert.equal(JSON.parse(body).reports[0].visits, undefined);
  assert.deepEqual(parseRiverMarket(body), closed);
  const good = JSON.parse(body);
  const wrongStaff = copyRiverMarket(closed); wrongStaff.stalls[0].workers = 7;
  const wrongReports = copyRiverMarket(closed); wrongReports.reports[0].served++;
  const wrongTotal = copyRiverMarket(closed); wrongTotal.served--;
  const wrongResource = copyRiverMarket(closed); wrongResource.stock.rice = -1;
  const incomplete = { ...good }; delete incomplete.lamps;
  for (const damaged of [wrongStaff, wrongReports, wrongTotal, wrongResource, incomplete, { ...good, version: 2 }]) {
    assert.equal(parseRiverMarket(JSON.stringify(damaged)), undefined);
  }
  assert.equal(parseRiverMarket('not-json'), undefined);
  const copy = copyRiverMarket(closed); copy.reports[0].reasons[0] = 999; copy.stalls[0].workers = 0;
  assert.notDeepEqual(copy, closed);
});

test('market: 独立记录可读、旧格式不冒充开市，损坏原文保留，墓碑胜出不复活', () => {
  assert.equal(riverMarketFromRecords([]), undefined);
  assert.equal(riverMarketIsDeleted([]), false); assert.equal(riverMarketIsUnreadable([]), false);
  const state = play('balanced').state;
  const record = riverMarketRecord(state, 'device-a', state.updatedAt + 10);
  assert.equal(record.id, 'progress:river-market:v1:kaifeng'); assert.equal(record.id, RIVER_MARKET_RECORD_ID);
  assert.equal(record.kind, 'progress'); assert.equal(record.paperContext, undefined);
  assert.equal(riverMarketFromRecords([record]).served, 71);
  assert.equal(riverMarketIsDeleted([record]), false);
  const old = { ...record, id: 'progress:kaifeng-dig:v1:roam-kf-night', body: '{"version":1,"attempt":1}' };
  assert.equal(riverMarketFromRecords([old]), undefined); assert.equal(riverMarketIsUnreadable([old]), false);
  assert.equal(riverMarketIsDeleted([old]), false);
  const bad = { ...record, body: '{damaged market body', updatedAt: record.updatedAt + 1 };
  assert.equal(riverMarketFromRecords([record, bad]), undefined);
  assert.equal(riverMarketIsDeleted([record, bad]), false);
  assert.equal(riverMarketIsUnreadable([record, bad]), true); assert.equal(bad.body, '{damaged market body');
  const tombstone = { ...bad, deleted: true, updatedAt: bad.updatedAt + 1 };
  assert.equal(riverMarketFromRecords([record, tombstone]), undefined);
  assert.equal(riverMarketIsDeleted([record, tombstone]), true);
  assert.equal(riverMarketIsDeleted([tombstone, bad, record]), true);
  assert.equal(riverMarketIsUnreadable([record, tombstone]), false);
  const reopened = riverMarketRecord(createRiverMarket(tombstone.updatedAt + 1), 'device-a', tombstone.updatedAt + 1);
  assert.equal(riverMarketIsDeleted([reopened, tombstone, record]), false);
  assert.equal(riverMarketFromRecords([reopened, tombstone, record]).round, 0);
  assert.equal(riverMarketIsUnreadable([{ ...record, siteId: 'other-site' }]), true);
  assert.deepEqual(MARKET_LOTS.map(lot => lot.zone), [0, 0, 1, 1, 2, 2]);
});
