// 汴京开市：四段开市的纯领域规则。灯起、人盛、夜深与五更是压缩经营节奏，并非连续等时四更。
// 店名取自文化材料，地图、客流、价格与人手均为原创游戏数值。
// 每次advance结算一整段，不依赖动画帧、联网或随机数；逐客事件只供回放，不写入永久历史。
export type MarketStallType = 'rice' | 'meat' | 'tea';
export type MarketResource = 'rice' | 'meat' | 'tea' | 'oil';
export type MarketVisitReason = 'served' | 'stock' | 'workers' | 'crowd' | 'dark' | 'missing';
export interface MarketStock { rice: number; meat: number; tea: number; oil: number; }
export interface MarketStall { lotId: number; type: MarketStallType | ''; workers: number; }
export interface MarketStallConfig { type: MarketStallType; name: string; buildCost: number; refund: number; price: number; }
export interface MarketLot { id: number; zone: number; label: string; }
export interface MarketReasonCount { reason: MarketVisitReason; count: number; }
export interface MarketVisit { guestId: number; origin: number; preference: MarketStallType; lotId: number; served: boolean; reason: MarketVisitReason; }
export interface MarketRoundSummary {
  round: number; arrivals: number; served: number; lost: number; income: number; wages: number;
  expenses: number; cashAfter: number; oilUsed: number; reasons: number[];
}
export interface RiverMarketV1 {
  version: number; round: number; cash: number; stock: MarketStock; stalls: MarketStall[];
  workers: number; lamps: boolean[]; served: number; arrivals: number; supplyTrips: number;
  reports: MarketRoundSummary[]; updatedAt: number;
}
export type RiverMarketState = RiverMarketV1;
export type MarketAction = { kind: 'build'; lotId: number; stallType: MarketStallType } |
  { kind: 'demolish'; lotId: number } | { kind: 'staff'; lotId: number; delta: number } |
  { kind: 'lamp'; zone: number; on: boolean } | { kind: 'buy'; resource: MarketResource };
export interface MarketActionResult { state: RiverMarketV1; changed: boolean; message: string; }
export interface MarketForecast {
  round: number; title: string; arrivals: number; preferences: number[]; zoneArrivals: number[];
  night: 'early' | 'late'; laneCapacity: number[]; oilNeeded: number; wages: number; rent: number;
  effectiveLamps: boolean[]; staffCapacity: number[]; supplyTripsLeft: number; detail: string;
}
export interface MarketRoundReport extends MarketRoundSummary {
  visits: MarketVisit[]; servedByLot: number[]; stockUsed: MarketStock; effectiveLamps: boolean[];
  reasonCounts: MarketReasonCount[]; advice: string[];
}
export interface MarketAdvanceResult { state: RiverMarketV1; report: MarketRoundReport; }
export interface MarketSummary {
  closed: boolean; passed: boolean; served: number; arrivals: number; cash: number;
  targetServed: number; targetCash: number; freeWorkers: number; title: string; detail: string;
}

export const MARKET_STALL_TYPES: MarketStallConfig[] = [
  { type: 'rice', name: '水饭铺', buildCost: 18, refund: 9, price: 3 },
  { type: 'meat', name: '肉食铺', buildCost: 24, refund: 12, price: 5 },
  { type: 'tea', name: '茶饮铺', buildCost: 14, refund: 7, price: 4 }
];
export const MARKET_LOTS: MarketLot[] = [
  { id: 0, zone: 0, label: '西街上铺' }, { id: 1, zone: 0, label: '西街下铺' },
  { id: 2, zone: 1, label: '中街上铺' }, { id: 3, zone: 1, label: '中街下铺' },
  { id: 4, zone: 2, label: '东街上铺' }, { id: 5, zone: 2, label: '东街下铺' }
];
export const MARKET_SUPPLIES: MarketStock = { rice: 16, meat: 8, tea: 18, oil: 4 };
export const MARKET_SUPPLY_COSTS: MarketStock = { rice: 8, meat: 10, tea: 6, oil: 6 };
export const MARKET_ROUNDS: number = 4;
export const MARKET_TARGET_SERVED: number = 65;
export const MARKET_TARGET_CASH: number = 20;
export const MARKET_WORKER_CAPACITY: number = 5;
export const MARKET_WAGE: number = 2;
export const MARKET_RENT: number = 2;
export const MARKET_BODY_LIMIT: number = 4000;
export const MARKET_LOSS_REASONS: MarketVisitReason[] = ['stock', 'workers', 'crowd', 'dark', 'missing'];
const MARKET_ARRIVALS: number[] = [18, 26, 32, 24];
const MARKET_PREFERENCES: number[][] = [[10, 5, 3], [10, 10, 6], [8, 12, 12], [4, 7, 13]];
const MARKET_ORIGINS: number[][] = [[6, 8, 4], [9, 9, 8], [12, 8, 12], [7, 6, 11]];
const MARKET_LANES: number[] = [16, 14, 16];

export function createRiverMarket(now: number): RiverMarketV1 {
  if (!validInteger(now, 0, Number.MAX_SAFE_INTEGER)) throw new Error('MARKET_INVALID_TIME');
  return { version: 1, round: 0, cash: 60, stock: { rice: 24, meat: 10, tea: 16, oil: 3 },
    stalls: MARKET_LOTS.map((lot: MarketLot): MarketStall => ({ lotId: lot.id,
      type: lot.id === 2 ? 'rice' : lot.id === 3 ? 'meat' : '', workers: lot.id === 2 || lot.id === 3 ? 2 : 0 })),
    workers: 6, lamps: [false, true, false], served: 0, arrivals: 0, supplyTrips: 0, reports: [], updatedAt: now };
}

function validInteger(value: number, minimum: number, maximum: number): boolean {
  return Number.isSafeInteger(value) && value >= minimum && value <= maximum;
}

function changedTime(state: RiverMarketV1, now: number): number {
  if (!validInteger(now, 0, Number.MAX_SAFE_INTEGER)) throw new Error('MARKET_INVALID_TIME');
  return Math.max(now, state.updatedAt + 1);
}

function stallConfig(type: string): MarketStallConfig | undefined {
  return MARKET_STALL_TYPES.find((item: MarketStallConfig) => item.type === type);
}

function unchanged(state: RiverMarketV1, message: string): MarketActionResult {
  return { state, changed: false, message };
}

function effectiveLamps(state: RiverMarketV1): boolean[] {
  const lights: boolean[] = [false, false, false];
  let oil = state.stock.oil;
  // 油不足先点中街，再西街、东街；预告与真实结算共用这一公开顺序，不在动画中临时改灯。
  for (const zone of [1, 0, 2]) {
    if (state.lamps[zone] && oil > 0) { lights[zone] = true; oil--; }
  }
  return lights;
}

export function copyRiverMarket(state: RiverMarketV1): RiverMarketV1 {
  return { version: state.version, round: state.round, cash: state.cash,
    stock: { rice: state.stock.rice, meat: state.stock.meat, tea: state.stock.tea, oil: state.stock.oil },
    stalls: state.stalls.map((stall: MarketStall): MarketStall => ({ lotId: stall.lotId, type: stall.type, workers: stall.workers })),
    workers: state.workers, lamps: state.lamps.slice(), served: state.served, arrivals: state.arrivals,
    supplyTrips: state.supplyTrips, reports: state.reports.map((report: MarketRoundSummary): MarketRoundSummary => ({
      round: report.round, arrivals: report.arrivals, served: report.served, lost: report.lost, income: report.income,
      wages: report.wages, expenses: report.expenses, cashAfter: report.cashAfter, oilUsed: report.oilUsed, reasons: report.reasons.slice()
    })), updatedAt: state.updatedAt };
}

export function applyMarketAction(state: RiverMarketV1, action: MarketAction, now: number = Date.now()): MarketActionResult {
  if (state.round >= MARKET_ROUNDS) return unchanged(state, '四段已经收市，重开一夜才能再安排。');
  const next = copyRiverMarket(state);
  let message = '';
  if (action.kind === 'buy') {
    if (!['rice', 'meat', 'tea', 'oil'].includes(action.resource)) return unchanged(state, '这趟货不在补货单上。');
    if (state.supplyTrips >= 2) return unchanged(state, '本段两趟补货已经用完；下一段再进货。');
    const cost = MARKET_SUPPLY_COSTS[action.resource];
    if (state.cash < cost) return unchanged(state, `这趟要${cost}钱，现钱不足。`);
    next.cash -= cost; next.stock[action.resource] += MARKET_SUPPLIES[action.resource]; next.supplyTrips++;
    message = `补货已到，花${cost}钱；本段还可补${2 - next.supplyTrips}趟。`;
  } else if (action.kind === 'lamp') {
    if (!validInteger(action.zone, 0, 2) || typeof action.on !== 'boolean') return unchanged(state, '请选择西、中、东三街的灯。');
    if (state.lamps[action.zone] === action.on) return unchanged(state, '这一街的灯保持原样。');
    next.lamps[action.zone] = action.on;
    message = action.on ? '下一段为这一街留灯；每段耗1份灯油，油不足先保中街。' : '下一段这一街不点灯，省下灯油。';
  } else {
    if (!validInteger(action.lotId, 0, MARKET_LOTS.length - 1)) return unchanged(state, '这里没有可经营的地块。');
    const stall = next.stalls[action.lotId];
    if (action.kind === 'build') {
      const config = stallConfig(action.stallType);
      if (!config) return unchanged(state, '请选择水饭、肉食或茶饮。');
      if (stall.type !== '') return unchanged(state, '这块地已有铺子；先收铺再换一种。');
      if (state.cash < config.buildCost) return unchanged(state, `开这间铺要${config.buildCost}钱，现钱不足。`);
      next.cash -= config.buildCost; stall.type = config.type;
      message = `${config.name}开好了。还要拨伙计，这一段才能接待客人。`;
    } else if (action.kind === 'demolish') {
      const config = stallConfig(stall.type);
      if (!config) return unchanged(state, '这一块本来就是空地。');
      next.cash += config.refund; stall.type = ''; stall.workers = 0;
      message = `收铺退回${config.refund}钱，原伙计回到待分配。`;
    } else if (action.kind === 'staff') {
      if (stall.type === '') return unchanged(state, '先开铺，才能拨伙计。');
      if (action.delta !== 1 && action.delta !== -1) return unchanged(state, '每次调动1名伙计。');
      if (stall.workers + action.delta < 0) return unchanged(state, '这间铺已经没有伙计了。');
      const assigned = next.stalls.reduce((sum, item) => sum + item.workers, 0);
      if (action.delta > 0 && assigned >= state.workers) return unchanged(state, '6名伙计都已排上，先从别的铺调出一人。');
      stall.workers += action.delta;
      message = `这间铺现在有${stall.workers}名伙计；明亮时每人每段接待${MARKET_WORKER_CAPACITY}客。`;
    } else return unchanged(state, '这项安排还不能执行。');
  }
  next.updatedAt = changedTime(state, now);
  return { state: next, changed: true, message };
}
export function marketForecast(state: RiverMarketV1): MarketForecast {
  const round = Math.min(state.round, 3);
  const lights = effectiveLamps(state);
  const late = state.round >= 2;
  return { round: state.round, title: ['灯起开市', '人盛街巷', '夜深卖茶', '五更再开'][round], arrivals: state.round < 4 ? MARKET_ARRIVALS[round] : 0,
    preferences: state.round < 4 ? MARKET_PREFERENCES[round].slice() : [0, 0, 0], zoneArrivals: state.round < 4 ? MARKET_ORIGINS[round].slice() : [0, 0, 0],
    night: late ? 'late' : 'early', laneCapacity: MARKET_LANES.map((capacity, zone) => late && !lights[zone] ? 3 : capacity),
    oilNeeded: state.round < 4 ? state.lamps.filter(on => on).length : 0,
    wages: state.stalls.reduce((sum, stall) => sum + stall.workers * MARKET_WAGE, 0),
    rent: state.stalls.filter(stall => stall.type !== '').length * MARKET_RENT,
    effectiveLamps: lights, staffCapacity: state.stalls.map(stall => stall.workers * (late && !lights[MARKET_LOTS[stall.lotId].zone] ? 2 : MARKET_WORKER_CAPACITY)),
    supplyTripsLeft: state.round < 4 ? 2 - state.supplyTrips : 0,
    detail: state.round < 2 ? '前两段不点灯也不减通行；亮着的街仍每段耗1油。中街较窄，分散开铺能避开拥挤；这些是原创经营规则。' :
      '深夜未点灯的街区仅容3客通行，每伙计只能接待2客；途经的客人也受影响。油不足先保中街，再西街、东街。' };
}
export function marketSummary(state: RiverMarketV1): MarketSummary {
  const closed = state.round >= 4;
  const passed = closed && state.served >= MARKET_TARGET_SERVED && state.cash >= MARKET_TARGET_CASH;
  return { closed, passed, served: state.served, arrivals: state.arrivals, cash: state.cash,
    targetServed: MARKET_TARGET_SERVED, targetCash: MARKET_TARGET_CASH,
    freeWorkers: state.workers - state.stalls.reduce((sum, stall) => sum + stall.workers, 0),
    title: closed ? passed ? '今夜开市顺利' : '今夜还有客人没留住' : '下一段，由你安排',
    detail: !closed ? `四段开市接待至少${MARKET_TARGET_SERVED}客，收市余钱至少${MARKET_TARGET_CASH}。` : passed ?
      `今夜接待${state.served}客、收市余${state.cash}钱。还可以换一种店位和排班，看看能不能少流失几位客人。` :
      `${state.served < MARKET_TARGET_SERVED ? `还差${MARKET_TARGET_SERVED - state.served}客；` : ''}` +
      `${state.cash < MARKET_TARGET_CASH ? `余钱还差${MARKET_TARGET_CASH - state.cash}；` : ''}回看每段流失原因，再安排下一夜。` };
}
export function advanceMarketRound(state: RiverMarketV1, now: number = Date.now()): MarketAdvanceResult {
  if (state.round >= MARKET_ROUNDS) throw new Error('MARKET_ALREADY_CLOSED');
  const forecast = marketForecast(state);
  const next = copyRiverMarket(state);
  const servedByLot: number[] = [0, 0, 0, 0, 0, 0];
  const flow: number[] = [0, 0, 0];
  const reasons: number[] = [0, 0, 0, 0, 0];
  const visits: MarketVisit[] = [];
  const stockUsed: MarketStock = { rice: 0, meat: 0, tea: 0, oil: 0 };
  const preferences = quotaSequence(forecast.preferences, state.round);
  const origins = quotaSequence(forecast.zoneArrivals, (state.round + 1) % 3);
  let income = 0;
  for (let index = 0; index < forecast.arrivals; index++) {
    const preference = MARKET_STALL_TYPES[preferences[index]].type;
    const origin = origins[index];
    const candidates = state.stalls.filter(stall => stall.type === preference).sort((a, b) =>
      Math.abs(MARKET_LOTS[a.lotId].zone - origin) - Math.abs(MARKET_LOTS[b.lotId].zone - origin) || a.lotId - b.lotId);
    let lotId = -1;
    let reason: MarketVisitReason = 'missing';
    if (candidates.length > 0) {
      reason = next.stock[preference] <= 0 ? 'stock' : 'workers';
      if (next.stock[preference] > 0) {
        let firstRouteFailure: MarketVisitReason | undefined = undefined;
        let firstServiceFailure: MarketVisitReason | undefined = undefined;
        for (const stall of candidates) {
          const zone = MARKET_LOTS[stall.lotId].zone;
          if (stall.workers === 0 || servedByLot[stall.lotId] >= forecast.staffCapacity[stall.lotId]) {
            // 灯暗导致接待速度下降时，反馈应指出灯暗，不能把它误报成“再雇人”。
            if (!firstServiceFailure) firstServiceFailure = stall.workers > 0 && forecast.night === 'late' &&
              !forecast.effectiveLamps[zone] ? 'dark' : 'workers';
            continue;
          }
          let routeFailure: MarketVisitReason | undefined = undefined;
          for (let through = Math.min(zone, origin); through <= Math.max(zone, origin); through++) {
            if (flow[through] >= forecast.laneCapacity[through]) {
              routeFailure = forecast.night === 'late' && !forecast.effectiveLamps[through] ? 'dark' : 'crowd'; break;
            }
          }
          if (routeFailure) { if (!firstRouteFailure) firstRouteFailure = routeFailure; continue; }
          lotId = stall.lotId; reason = 'served';
          for (let through = Math.min(zone, origin); through <= Math.max(zone, origin); through++) flow[through]++;
          break;
        }
        if (lotId < 0) reason = firstRouteFailure || firstServiceFailure || 'workers';
      }
    }
    if (lotId >= 0) {
      servedByLot[lotId]++; next.stock[preference]--; stockUsed[preference]++;
      income += MARKET_STALL_TYPES[preferences[index]].price;
    } else reasons[MARKET_LOSS_REASONS.indexOf(reason)]++;
    visits.push({ guestId: state.arrivals + index + 1, origin, preference, lotId, served: lotId >= 0, reason });
  }
  const served = servedByLot.reduce((sum, value) => sum + value, 0);
  const oilUsed = forecast.effectiveLamps.filter(on => on).length;
  stockUsed.oil = oilUsed; next.stock.oil -= oilUsed;
  const expenses = forecast.wages + forecast.rent;
  next.cash += income - expenses;
  next.round++; next.served += served; next.arrivals += forecast.arrivals; next.supplyTrips = 0;
  next.updatedAt = changedTime(state, now);
  const summary: MarketRoundSummary = { round: next.round, arrivals: forecast.arrivals, served,
    lost: forecast.arrivals - served, income, wages: forecast.wages, expenses, cashAfter: next.cash, oilUsed, reasons };
  next.reports.push({ ...summary, reasons: reasons.slice() });
  const advice: string[] = [];
  if (reasons[0] > 0) advice.push(`${reasons[0]}客想吃的货已经卖空，下一段先看偏好再补货。`);
  if (reasons[1] > 0) advice.push(`${reasons[1]}客碰上伙计忙不过来；把闲人拨到有货的铺子。`);
  if (reasons[2] > 0) advice.push(`${reasons[2]}客被拥挤挡住；中街每段只能通行${MARKET_LANES[1]}客，试着在来客街区开铺。`);
  if (reasons[3] > 0) advice.push(`${reasons[3]}客因街暗没走到铺子；开灯还要有灯油，途经街区也要照顾。`);
  if (reasons[4] > 0) advice.push(`${reasons[4]}客没找到对应铺子；后两段茶饮偏好多，可以提前布置。`);
  if (advice.length === 0) advice.push('这一段来客都接住了，留意下一段的偏好和灯油。');
  return { state: next, report: { ...summary, visits, servedByLot, stockUsed,
    effectiveLamps: forecast.effectiveLamps.slice(), reasonCounts: MARKET_LOSS_REASONS.map((reason, index) => ({ reason, count: reasons[index] })), advice } };
}

// 用预告给出的配额轮流安排客人，偏好、来源与顺序完全确定；不靠重开赌一批“好客”。
// 每个配额的缺口最大的类别先入场，平局按本段公开固定顺序处理。
function quotaSequence(quotas: number[], offset: number): number[] {
  const total = quotas.reduce((sum, value) => sum + value, 0);
  const used: number[] = [0, 0, 0];
  const result: number[] = [];
  for (let step = 0; step < total; step++) {
    let best = -1; let deficit = -Infinity;
    for (let cursor = 0; cursor < quotas.length; cursor++) {
      const candidate = (cursor + offset) % quotas.length;
      if (used[candidate] >= quotas[candidate]) continue;
      const current = quotas[candidate] * (step + 1) - used[candidate] * total;
      if (current > deficit) { deficit = current; best = candidate; }
    }
    result.push(best); used[best]++;
  }
  return result;
}

export function serializeRiverMarket(state: RiverMarketV1): string {
  const body = JSON.stringify(state);
  if (body.length > MARKET_BODY_LIMIT) throw new Error('MARKET_RECORD_TOO_LARGE');
  if (!parseRiverMarket(body)) throw new Error('MARKET_INVALID_STATE');
  return body;
}

export function parseRiverMarket(text: string): RiverMarketV1 | undefined {
  if (typeof text !== 'string' || text.length > MARKET_BODY_LIMIT || !text.trim()) return undefined;
  let value: RiverMarketV1;
  try { value = JSON.parse(text) as RiverMarketV1; } catch (_error) { return undefined; }
  if (!value || value.version !== 1 || !validInteger(value.round, 0, 4) || !validInteger(value.cash, -200, 10000) ||
    !value.stock || !validInteger(value.stock.rice, 0, 200) || !validInteger(value.stock.meat, 0, 200) ||
    !validInteger(value.stock.tea, 0, 200) || !validInteger(value.stock.oil, 0, 200) ||
    !Array.isArray(value.stalls) || value.stalls.length !== 6 || value.workers !== 6 ||
    !Array.isArray(value.lamps) || value.lamps.length !== 3 || !value.lamps.every(on => typeof on === 'boolean') ||
    !validInteger(value.served, 0, 100) || !validInteger(value.arrivals, 0, 100) || value.served > value.arrivals ||
    !validInteger(value.supplyTrips, 0, 2) || (value.round === 4 && value.supplyTrips !== 0) ||
    !Array.isArray(value.reports) || value.reports.length !== value.round || !validInteger(value.updatedAt, 0, Number.MAX_SAFE_INTEGER)) return undefined;
  for (let index = 0; index < value.stalls.length; index++) {
    const stall = value.stalls[index];
    if (!stall || stall.lotId !== index || (stall.type !== '' && !stallConfig(stall.type)) ||
      !validInteger(stall.workers, 0, 6) || (stall.type === '' && stall.workers !== 0)) return undefined;
  }
  if (value.stalls.reduce((sum, stall) => sum + stall.workers, 0) > value.workers) return undefined;
  let arrivals = 0; let served = 0;
  for (let index = 0; index < value.reports.length; index++) {
    const report = value.reports[index];
    if (!report || report.round !== index + 1 || report.arrivals !== MARKET_ARRIVALS[index] ||
      !validInteger(report.served, 0, report.arrivals) || report.lost !== report.arrivals - report.served ||
      !validInteger(report.income, report.served * 3, report.served * 5) || !validInteger(report.wages, 0, 12) ||
      report.wages % 2 !== 0 || !validInteger(report.expenses, report.wages, report.wages + 12) ||
      !validInteger(report.cashAfter, -200, 10000) || !validInteger(report.oilUsed, 0, 3) ||
      !Array.isArray(report.reasons) || report.reasons.length !== 5 ||
      !report.reasons.every(count => validInteger(count, 0, report.lost)) ||
      report.reasons.reduce((sum, count) => sum + count, 0) !== report.lost) return undefined;
    arrivals += report.arrivals; served += report.served;
  }
  if (value.arrivals !== arrivals || value.served !== served ||
    (value.round === 4 && value.cash !== value.reports[3].cashAfter)) return undefined;
  return copyRiverMarket(value);
}
