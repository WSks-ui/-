import test from 'node:test';
import assert from 'node:assert/strict';
import { domainModuleUrl } from './load-domain-module.mjs';

const m = await import(domainModuleUrl('RiverMarketV2'));
const records = await import(domainModuleUrl('RiverMarketV2Records'));
const { createMarketNight, copyMarketNight, applyMarketNightAction, beginMarketNightRound, advanceMarketNightBatch,
  endMarketNightRound, marketNightForecast, marketNightSummary, marketNightLayout, serializeMarketNight, parseMarketNight } = m;

function act(state, action) {
  const result = applyMarketNightAction(state, action, state.updatedAt + 1);
  assert.equal(result.changed, true, `${JSON.stringify(action)}: ${result.message}`);
  assert.deepEqual(parseMarketNight(serializeMarketNight(result.state)), result.state);
  return result.state;
}
function begin(state) { const result = beginMarketNightRound(state, state.updatedAt + 1); assert.equal(result.changed, true); return result.state; }
function end(state) { const result = endMarketNightRound(state, state.updatedAt + 1); assert.equal(result.changed, true); return result.state; }
function loss(report, reason) { return report.reasonCounts.find(item => item.reason === reason).count; }
function staffTo(state, targets) {
  for (let lot = 0; lot < 6; lot++) while (state.stalls[lot].workers > (targets[lot] || 0)) state = act(state, { kind: 'staff', lotId: lot, delta: -1 });
  for (let lot = 0; lot < 6; lot++) while (state.stalls[lot].workers < (targets[lot] || 0)) state = act(state, { kind: 'staff', lotId: lot, delta: 1 });
  return state;
}

// 两套经营方案都从新局经公开动作建铺、排班和补货，不直接改写库存或通关客数。
// 方案A把茶放近主来客，方案B把饭肉放近主来客；每夜三路线均以同样公开预告完成。
export function playNightStrategy(nightId, routeId, style = 0, inheritedLayout) {
  let state = createMarketNight(nightId, routeId, 100, inheritedLayout);
  const steps = [];
  const doAction = (current, action) => { steps.push(action); return act(current, action); };
  const main = routeId === 'west' ? 0 : routeId === 'east' ? 2 : 1;
  const side = routeId === 'west' ? 1 : routeId === 'east' ? 1 : style === 0 ? 0 : 2;
  const riceLot = style === 0 ? side * 2 : main * 2;
  const teaLot = style === 0 ? main * 2 : side * 2;
  const meatLot = main * 2 + 1;
  const lanternLot = side * 2 + 1;
  const desired = [[riceLot, 'rice'], [meatLot, 'meat'], [teaLot, 'tea']]; if (nightId === 'night-3') desired.push([lanternLot, 'lantern']);
  for (const stall of state.stalls) if (stall.type && !desired.some(([lot, type]) => lot === stall.lotId && type === stall.type)) state = doAction(state, { kind: 'demolish', lotId: stall.lotId });
  for (const [lotId, stallType] of desired) if (!state.stalls[lotId].type) state = doAction(state, { kind: 'build', lotId, stallType });
  if (nightId !== 'night-3') for (let zone = 0; zone < 3; zone++) if (state.lamps[zone]) state = doAction(state, { kind: 'lamp', zone, on: false });
  const allReports = []; const checkpoints = [];
  for (let round = 0; round < 4; round++) {
    const targets = [0, 0, 0, 0, 0, 0];
    if (nightId !== 'night-2' && state.tourZone >= 0) state = doAction(state, { kind: 'tour', zone: -1 });
    if (nightId === 'night-1') { targets[riceLot] = round < 2 ? 2 : 1; targets[meatLot] = 2; targets[teaLot] = round < 2 ? 2 : 3; }
    else if (nightId === 'night-2') { targets[riceLot] = 1; targets[meatLot] = 1; targets[teaLot] = 3; }
    else { targets[riceLot] = 1; targets[meatLot] = 2; targets[teaLot] = 2; targets[lanternLot] = 1; }
    for (let lot = 0; lot < 6; lot++) while (state.stalls[lot].workers > targets[lot]) state = doAction(state, { kind: 'staff', lotId: lot, delta: -1 });
    for (let lot = 0; lot < 6; lot++) while (state.stalls[lot].workers < targets[lot]) state = doAction(state, { kind: 'staff', lotId: lot, delta: 1 });
    if (nightId === 'night-2' && state.tourZone !== main) state = doAction(state, { kind: 'tour', zone: main });
    const forecast = marketNightForecast(state);
    // 只按已公开的下一段需求补货；两趟常规货不够时，暂停再用真实急送补足。
    const needed = ['rice', 'meat', 'tea'].filter((resource, index) => state.stock[resource] < forecast.preferences[index]);
    if (round === 2 && state.stock.oil < 6) needed.unshift('oil');
    for (const resource of needed.slice(0, 2)) state = doAction(state, { kind: 'buy', resource });
    if (round >= 2 || nightId === 'night-3') for (let zone = 0; zone < 3; zone++) if (!state.lamps[zone]) state = doAction(state, { kind: 'lamp', zone, on: true });
    if (nightId === 'night-3' && state.stock.oil < 3 && state.supplyTrips < 2) state = doAction(state, { kind: 'buy', resource: 'oil' });
    steps.push({ kind: 'begin' }); state = begin(state); checkpoints.push(copyMarketNight(state));
    for (let batch = 0; batch < 3; batch++) {
      steps.push({ kind: 'batch' }); const next = advanceMarketNightBatch(state, state.updatedAt + 1); state = next.state; allReports.push(next.report); checkpoints.push(copyMarketNight(state));
      assert.deepEqual(parseMarketNight(serializeMarketNight(state)), state);
      if (batch < 2) {
        const remaining = marketNightForecast(state);
        for (const [index, resource] of ['rice', 'meat', 'tea'].entries()) if (state.stock[resource] < remaining.batchPreferences[index] && state.emergencyUsed < 2) state = doAction(state, { kind: 'emergency-buy', resource });
        if (nightId === 'night-3' && round === 1 && state.stock.oil < 3 && state.emergencyUsed < 2) state = doAction(state, { kind: 'emergency-buy', resource: 'oil' });
      }
    }
    steps.push({ kind: 'end' }); state = end(state); checkpoints.push(copyMarketNight(state));
  }
  return { key: `${nightId}:${routeId}:${style}`, nightId, routeId, style, steps, state, reports: allReports, checkpoints, summary: marketNightSummary(state) };
}

test('market-v2: 新夜预算、三批预告与独立V2存档身份', () => {
  for (const [index, nightId] of ['night-1', 'night-2', 'night-3'].entries()) {
    const state = createMarketNight(nightId, 'balanced', 100);
    assert.equal(state.cash, [60, 70, 90][index]); assert.equal(state.version, 2); assert.equal(state.phase, 'prepare');
    assert.equal(marketNightForecast(state).batchArrivals, Math.floor(marketNightForecast(state).arrivals / 3));
    const record = records.marketNightRecord(state, 'test-device', 101);
    assert.equal(record.id, `progress:river-market:v2:kaifeng:${nightId}`); assert.equal(record.siteId, 'kf-zhouqiao');
    assert.equal(records.marketNightFromRecords([record], nightId).updatedAt, 101);
    assert.equal(parseMarketNight('{"version":1}'), undefined);
  }
});

test('market-v2: 三夜三路线各有两套真实动作成功，完整暂停存档低于4000字', () => {
  const results = [];
  let largest = 0;
  for (const nightId of ['night-1', 'night-2', 'night-3']) for (const routeId of ['balanced', 'west', 'east']) for (const style of [0, 1]) {
    const result = playNightStrategy(nightId, routeId, style);
    results.push([nightId, routeId, style, result.state.served, result.state.cash, result.state.teaServed, result.state.festivalServed]);
    assert.equal(result.summary.passed, true, JSON.stringify(results.at(-1)));
    for (const checkpoint of result.checkpoints) { largest = Math.max(largest, serializeMarketNight(checkpoint).length); assert.ok(serializeMarketNight(checkpoint).length < 4000); }
    assert.equal(result.reports.length, 12); assert.equal(result.state.reports.length, 4);
  }
  console.log('V2策略结果', JSON.stringify(results), '最大checkpoint', largest);
});

test('market-v2: 三批只结当批，开段扣油一次、结段工资租金一次，顾客配额守恒', () => {
  let state = begin(createMarketNight('night-1', 'west', 100));
  assert.equal(state.stock.oil, 2); assert.equal(state.reports[0].oilUsed, 1);
  assert.equal(beginMarketNightRound(state).changed, false);
  const originalCash = state.cash; const visits = []; let income = 0;
  const forecast = marketNightForecast(state);
  for (let batch = 0; batch < 3; batch++) {
    const before = copyMarketNight(state); const result = advanceMarketNightBatch(state, state.updatedAt + 1);
    assert.deepEqual(advanceMarketNightBatch(parseMarketNight(serializeMarketNight(before)), before.updatedAt + 1), result);
    assert.deepEqual(state, before); assert.equal(result.report.batch, batch + 1);
    assert.equal(result.report.visits.length, forecast.arrivals / 3);
    visits.push(...result.report.visits); income += result.report.income; state = result.state;
    assert.equal(state.stock.oil, 2); assert.equal(state.phase, batch < 2 ? 'emergency' : 'settling');
    assert.equal(state.reports[0].batches.length, batch + 1);
  }
  assert.deepEqual([0, 1, 2].map(zone => visits.filter(item => item.origin === zone).length), forecast.zoneArrivals);
  assert.deepEqual(['rice', 'meat', 'tea'].map(type => visits.filter(item => item.preference === type).length), forecast.preferences);
  assert.deepEqual(visits.map(item => item.guestId), Array.from({ length: 18 }, (_, index) => index + 1));
  assert.equal(state.cash, originalCash + income); assert.equal(state.arrivals, 18);
  assert.throws(() => advanceMarketNightBatch(state), /BATCH_NOT_READY/);
  state = end(state); assert.equal(state.cash, originalCash + income - 12);
  assert.equal(state.round, 1); assert.equal(state.batch, 0); assert.equal(endMarketNightRound(state).changed, false);
  assert.deepEqual(state.flow, [0, 0, 0]); assert.deepEqual(state.usedCapacity, [0, 0, 0, 0, 0, 0]);
});

function shortagePause() {
  let state = createMarketNight('night-1', 'west', 100);
  state = act(state, { kind: 'demolish', lotId: 3 }); state = act(state, { kind: 'build', lotId: 4, stallType: 'meat' });
  state = act(state, { kind: 'staff', lotId: 4, delta: 1 }); state = act(state, { kind: 'staff', lotId: 4, delta: 1 });
  state = act(state, { kind: 'build', lotId: 0, stallType: 'tea' });
  state = act(state, { kind: 'staff', lotId: 0, delta: 1 }); state = act(state, { kind: 'staff', lotId: 0, delta: 1 });
  state = begin(state);
  for (let batch = 0; batch < 3; batch++) state = advanceMarketNightBatch(state, state.updatedAt + 1).state;
  state = begin(end(state));
  state = advanceMarketNightBatch(state, state.updatedAt + 1).state;
  state = advanceMarketNightBatch(state, state.updatedAt + 1).state;
  return state;
}

test('market-v2: 正确急送、错误急送与不应急产生可解释差异，过去两批完全保留', () => {
  const checkpoint = shortagePause(); assert.equal(checkpoint.stock.meat, 0); assert.equal(checkpoint.batch, 2);
  const goodState = act(checkpoint, { kind: 'emergency-buy', resource: 'meat' });
  const wrongState = act(checkpoint, { kind: 'emergency-buy', resource: 'oil' });
  assert.equal(checkpoint.cash - goodState.cash, Math.ceil(m.NIGHT_SUPPLY_COSTS.meat * 1.5));
  assert.equal(checkpoint.cash - wrongState.cash, Math.ceil(m.NIGHT_SUPPLY_COSTS.oil * 1.5));
  assert.deepEqual(goodState.reports, checkpoint.reports); assert.deepEqual(goodState.usedCapacity, checkpoint.usedCapacity); assert.deepEqual(goodState.flow, checkpoint.flow);
  assert.equal(goodState.arrivals, checkpoint.arrivals); assert.equal(goodState.supplyTrips, checkpoint.supplyTrips);
  const good = advanceMarketNightBatch(goodState, 1000); const wrong = advanceMarketNightBatch(wrongState, 1000); const none = advanceMarketNightBatch(checkpoint, 1000);
  assert.ok(good.report.served > none.report.served); assert.equal(wrong.report.served, none.report.served);
  assert.ok(loss(none.report, 'stock') > loss(good.report, 'stock')); assert.equal(loss(wrong.report, 'stock'), loss(none.report, 'stock'));
  assert.equal(wrong.state.cash, none.state.cash - 9); assert.ok(none.report.advice.some(item => item.includes('急送')));
});

test('market-v2: 应急调人保留段内已用次数，两个暂停共享最多两次应急', () => {
  let state = shortagePause(); const oldCapacity = state.usedCapacity.slice(); const oldFlow = state.flow.slice();
  state = act(state, { kind: 'emergency-staff', fromLot: 0, toLot: 4 });
  assert.equal(state.stalls[0].workers, 1); assert.equal(state.stalls[4].workers, 3);
  assert.deepEqual(state.usedCapacity, oldCapacity); assert.deepEqual(state.flow, oldFlow);
  state = act(state, { kind: 'emergency-buy', resource: 'meat' });
  const denied = applyMarketNightAction(state, { kind: 'emergency-buy', resource: 'tea' });
  assert.equal(denied.changed, false); assert.match(denied.message, /两次/); assert.equal(denied.state, state);
  assert.equal(applyMarketNightAction(state, { kind: 'staff', lotId: 0, delta: 1 }).changed, false);
  assert.equal(applyMarketNightAction(createMarketNight('night-1', 'balanced', 1), { kind: 'emergency-buy', resource: 'meat' }).changed, false);
});

test('market-v2: 移灯交换实际照明位置，不添灯、不退油、不清通行', () => {
  let state = begin(createMarketNight('night-1', 'balanced', 100));
  state = advanceMarketNightBatch(state, 102).state;
  const oil = state.stock.oil; const flow = state.flow.slice(); const used = state.usedCapacity.slice();
  const after = act(state, { kind: 'emergency-lamp', fromZone: 1, toZone: 0 });
  assert.deepEqual(after.effectiveLamps, [true, false, false]); assert.equal(after.effectiveLamps.filter(Boolean).length, 1);
  assert.equal(after.stock.oil, oil); assert.deepEqual(after.flow, flow); assert.deepEqual(after.usedCapacity, used);
  assert.equal(after.reports[0].oilUsed, 1); assert.equal(applyMarketNightAction(after, { kind: 'emergency-lamp', fromZone: 1, toZone: 2 }).changed, false);
});

test('market-v2: 巡茶从第二夜开放、共享人手，每批上限2，改派占应急且不重算已接待', () => {
  assert.equal(applyMarketNightAction(createMarketNight('night-1', 'west', 1), { kind: 'tour', zone: 0 }).changed, false);
  let state = createMarketNight('night-2', 'west', 1); state = act(state, { kind: 'tour', zone: 0 });
  assert.equal(marketNightSummary(state).freeWorkers, 1); state = begin(state);
  let result = advanceMarketNightBatch(state, 3); state = result.state;
  assert.ok(result.report.visits.filter(item => item.tour).length <= 2);
  const tea = state.teaServed; const used = state.tourServed;
  state = act(state, { kind: 'emergency-tour', zone: 1 });
  assert.equal(state.emergencyUsed, 1); assert.equal(state.teaServed, tea); assert.equal(state.tourServed, used);
  result = advanceMarketNightBatch(state, state.updatedAt + 1); state = result.state;
  assert.ok(result.report.visits.filter(item => item.tour).length <= 2);
  assert.ok(result.report.visits.filter(item => item.tour).every(item => item.origin === 1));
  state = act(state, { kind: 'emergency-tour', zone: -1 });
  assert.equal(state.tourZone, -1); assert.equal(state.emergencyUsed, 2); assert.equal(marketNightSummary(state).freeWorkers, 2);
});

test('market-v2: 观灯客先到有伙计和照明的灯棚，再消费才计双完成', () => {
  let noLantern = begin(createMarketNight('night-3', 'balanced', 1));
  let result = advanceMarketNightBatch(noLantern, 3);
  assert.ok(result.report.visits.some(item => item.festival));
  assert.ok(result.report.visits.filter(item => item.festival).every(item => !item.served && !item.festivalViewed && item.reason === 'festival'));
  let state = createMarketNight('night-3', 'balanced', 1);
  state = act(state, { kind: 'build', lotId: 0, stallType: 'lantern' }); state = act(state, { kind: 'staff', lotId: 0, delta: 1 });
  state = begin(state); result = advanceMarketNightBatch(state, 4);
  assert.ok(result.report.visits.filter(item => item.festival).every(item => !item.served && item.reason === 'dark' && item.blockedZone === 0));
  const lit = act(result.state, { kind: 'emergency-lamp', fromZone: 1, toZone: 0 });
  result = advanceMarketNightBatch(lit, lit.updatedAt + 1);
  assert.ok(result.report.visits.some(item => item.festivalViewed));
  assert.ok(result.report.visits.filter(item => item.festivalServed).every(item => item.festival && item.festivalViewed && item.served && item.festivalLot === 0));
  assert.equal(result.report.festivalServed, result.report.visits.filter(item => item.festivalServed).length);
  assert.equal(applyMarketNightAction(createMarketNight('night-2', 'balanced', 1), { kind: 'build', lotId: 0, stallType: 'lantern' }).changed, false);
});

test('market-v2: 下一夜仅继承布局，新预算和物资、客数、批次与账本均重新开始', () => {
  const previous = playNightStrategy('night-1', 'east', 0).state;
  const next = createMarketNight('night-2', 'west', 10000, marketNightLayout(previous));
  assert.deepEqual(marketNightLayout(next), marketNightLayout(previous)); assert.equal(next.cash, 70);
  assert.deepEqual(next.stock, m.NIGHT_CONFIGS[1].initialStock); assert.equal(next.served, 0); assert.equal(next.arrivals, 0);
  assert.equal(next.round, 0); assert.equal(next.batch, 0); assert.equal(next.reports.length, 0); assert.equal(next.routeId, 'west');
  assert.equal(records.nextMarketNight('night-1'), 'night-2'); assert.equal(records.nextMarketNight('night-3'), undefined);
});

test('market-v2: 三夜实际继承上一夜布局的连续演示同样能经公开动作达成', () => {
  for (const style of [0, 1]) {
    let layout;
    for (const nightId of ['night-1', 'night-2', 'night-3']) {
      const result = playNightStrategy(nightId, 'balanced', style, layout);
      assert.equal(result.summary.passed, true, `${nightId}/${style}`); layout = marketNightLayout(result.state);
    }
  }
});

test('market-v2: 每夜整条LWW、墓碑和损坏正文区分，不合并库存、不把损坏当新局', () => {
  const first = createMarketNight('night-1', 'balanced', 1);
  const good = records.marketNightRecord(first, 'a', 10);
  const other = records.marketNightRecord(act(first, { kind: 'buy', resource: 'tea' }), 'b', 11);
  const merged = records.marketNightFromRecords([good, other], 'night-1');
  assert.equal(merged.stock.tea, first.stock.tea + m.NIGHT_SUPPLIES.tea); assert.equal(merged.cash, 54);
  const tombstone = { ...good, deleted: true, updatedAt: 12 };
  assert.equal(records.marketNightIsDeleted([good, other, tombstone], 'night-1'), true);
  assert.equal(records.marketNightFromRecords([good, other, tombstone], 'night-1'), undefined);
  assert.equal(records.marketNightIsUnreadable([tombstone], 'night-1'), false);
  const damaged = { ...good, body: '{invalid', updatedAt: 13 };
  assert.equal(records.marketNightIsUnreadable([good, tombstone, damaged], 'night-1'), true);
  assert.equal(records.marketNightIsDeleted([good, tombstone, damaged], 'night-1'), false);
  assert.equal(records.marketNightFromRecords([damaged], 'night-1'), undefined); assert.equal(damaged.body, '{invalid');
  assert.equal(records.marketNightIsUnreadable([], 'night-1'), false);
  assert.equal(records.marketNightIsUnreadable([{ ...good, id: records.marketNightRecordId('night-2') }], 'night-2'), true);
});

test('market-v2: 达成前一夜才解锁，V1、损坏和前夜墓碑不伪造解锁', () => {
  assert.equal(records.marketNightUnlocked([], 'night-1'), true); assert.equal(records.marketNightUnlocked([], 'night-2'), false);
  const done = playNightStrategy('night-1', 'balanced', 0).state;
  const record = records.marketNightRecord(done, 'a', done.updatedAt + 1);
  assert.equal(records.marketNightUnlocked([record], 'night-2'), true); assert.equal(records.marketNightUnlocked([record], 'night-3'), false);
  assert.equal(records.marketNightUnlocked([{ ...record, deleted: true }], 'night-2'), false);
  assert.equal(records.marketNightUnlocked([{ ...record, body: '{}' }], 'night-2'), false);
  assert.equal(records.marketNightUnlocked([{ ...record, id: 'progress:river-market:v1:kaifeng' }], 'night-2'), false);
  const second = records.marketNightRecord(createMarketNight('night-2', 'balanced', 100), 'a', 101);
  const replayFirst = records.marketNightRecord(createMarketNight('night-1', 'balanced', 200), 'a', 201);
  assert.equal(records.marketNightUnlocked([replayFirst, second], 'night-2'), true);
  assert.equal(records.marketNightUnlocked([replayFirst, { ...second, deleted: true }], 'night-2'), false);
  assert.equal(records.marketNightUnlocked([replayFirst, { ...second, body: '{}' }], 'night-2'), false);
});

test('market-v2: 不建铺、不调人、不补货的三夜三路线均不会自动通关', () => {
  for (const nightId of ['night-1', 'night-2', 'night-3']) for (const routeId of ['balanced', 'west', 'east']) {
    let state = createMarketNight(nightId, routeId, 1);
    for (let round = 0; round < 4; round++) {
      state = begin(state); for (let batch = 0; batch < 3; batch++) state = advanceMarketNightBatch(state, state.updatedAt + 1).state; state = end(state);
    }
    assert.equal(marketNightSummary(state).passed, false); assert.ok(state.served < 65);
  }
});

test('market-v2: 损坏的批次账本、阶段和累计客数不能被解析为有效经营进度', () => {
  const valid = playNightStrategy('night-3', 'balanced', 0).checkpoints.at(-2);
  for (const mutate of [state => { state.arrivals++; }, state => { state.phase = 'prepare'; }, state => { state.reports[0].served++; }, state => { state.reports[0].batches[0].reasons[0]++; }, state => { state.configRevision = 999; }]) {
    const state = copyMarketNight(valid); mutate(state); assert.equal(parseMarketNight(JSON.stringify(state)), undefined);
  }
});

test('market-v2: 恢复必须保留本段已用接待名额，独立改写收段和收市余额不可读', () => {
  const result = playNightStrategy('night-3', 'balanced', 1);
  const active = result.checkpoints.find(state => state.phase === 'emergency' && state.served > 0);
  assert.ok(active);
  const reset = copyMarketNight(active); reset.usedCapacity.fill(0);
  assert.equal(parseMarketNight(JSON.stringify(reset)), undefined);
  const extraTour = copyMarketNight(active); extraTour.tourServed++;
  assert.equal(parseMarketNight(JSON.stringify(extraTour)), undefined);
  for (const original of [result.checkpoints.find(state => state.phase === 'settling'), result.state]) {
    const changed = copyMarketNight(original); changed.cash++;
    assert.equal(parseMarketNight(JSON.stringify(changed)), undefined);
  }
  assert.deepEqual(parseMarketNight(serializeMarketNight(active)), active);
});
