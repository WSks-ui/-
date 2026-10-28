// 开封三夜：原创经营规则。三夜共享六铺地图，库存、接待次数与通行在同一段的三批之间连续。
// 这些数值用于比赛演示，不是宋代物价、时制或城市容量的复原；后续调平衡只改集中配置。
export type MarketNightId = 'night-1' | 'night-2' | 'night-3';
export type MarketRouteId = 'balanced' | 'west' | 'east';
export type MarketNightStallType = 'rice' | 'meat' | 'tea' | 'lantern';
export type MarketNightPreference = 'rice' | 'meat' | 'tea';
export type MarketNightResource = 'rice' | 'meat' | 'tea' | 'oil';
export type MarketNightPhase = 'prepare' | 'running' | 'emergency' | 'settling' | 'closed';
export type MarketNightReason = 'served' | 'stock' | 'workers' | 'crowd' | 'dark' | 'missing' | 'festival';
export interface MarketNightStock { rice: number; meat: number; tea: number; oil: number; }
export interface MarketNightStall { lotId: number; type: MarketNightStallType | ''; workers: number; }
export interface MarketNightLot { id: number; zone: number; label: string; }
export interface MarketNightStallConfig { type: MarketNightStallType; name: string; buildCost: number; refund: number; price: number; }
export interface MarketNightTarget { served: number; cash: number; teaServed: number; festivalServed: number; }
export interface MarketNightConfig {
  id: MarketNightId; title: string; subtitle: string; contentId: string; budget: number;
  initialStock: MarketNightStock; target: MarketNightTarget; arrivals: number[]; preferences: number[][]; festival: number[];
}
export interface MarketNightRoute { id: MarketRouteId; title: string; detail: string; }
export interface MarketNightLayout { stalls: MarketNightStall[]; lamps: boolean[]; tourZone: number; }
// 逐客事件只返回当批，永久账本仅保留以下有界摘要；恢复时不会重播或重算已经接待的批次。
export interface MarketNightBatchSummary {
  batch: number; arrivals: number; served: number; teaServed: number; festivalServed: number; income: number; reasons: number[];
}
export interface MarketNightRoundSummary {
  round: number; batches: MarketNightBatchSummary[]; arrivals: number; served: number; teaServed: number;
  festivalServed: number; income: number; wages: number; expenses: number; cashAfter: number; oilUsed: number; reasons: number[];
}
export interface RiverMarketV2 {
  version: number; nightId: MarketNightId; configRevision: number; routeId: MarketRouteId;
  round: number; batch: number; phase: MarketNightPhase; cash: number; stock: MarketNightStock;
  stalls: MarketNightStall[]; lamps: boolean[]; workers: number; tourZone: number;
  served: number; arrivals: number; teaServed: number; festivalServed: number; supplyTrips: number; emergencyUsed: number;
  usedCapacity: number[]; flow: number[]; effectiveLamps: boolean[]; tourServed: number;
  reports: MarketNightRoundSummary[]; updatedAt: number;
}
export type MarketNightAction = { kind: 'build'; lotId: number; stallType: MarketNightStallType } |
  { kind: 'demolish'; lotId: number } | { kind: 'staff'; lotId: number; delta: number } |
  { kind: 'lamp'; zone: number; on: boolean } | { kind: 'buy'; resource: MarketNightResource } |
  { kind: 'tour'; zone: number } |
  { kind: 'emergency-tour'; zone: number } |
  { kind: 'emergency-staff'; fromLot: number; toLot: number } |
  { kind: 'emergency-buy'; resource: MarketNightResource } |
  { kind: 'emergency-lamp'; fromZone: number; toZone: number };
export interface MarketNightActionResult { state: RiverMarketV2; changed: boolean; message: string; }
export interface MarketNightVisit {
  guestId: number; origin: number; preference: MarketNightPreference; targetLot: number; lotId: number;
  blockedZone: number; served: boolean; reason: MarketNightReason;
  festival: boolean; festivalViewed: boolean; festivalServed: boolean; festivalLot: number; tour: boolean;
}
export interface MarketNightReasonCount { reason: MarketNightReason; count: number; }
export interface MarketNightBatchReport extends MarketNightBatchSummary {
  round: number; visits: MarketNightVisit[]; events: MarketNightVisit[]; servedByLot: number[]; stockUsed: MarketNightStock;
  effectiveLamps: boolean[]; stallTypes: (MarketNightStallType | '')[]; reasonCounts: MarketNightReasonCount[];
  advice: string[]; cashAfter: number; flow: number[]; usedCapacity: number[];
}
export interface MarketNightAdvanceResult { state: RiverMarketV2; report: MarketNightBatchReport; }
export interface MarketNightForecast {
  round: number; batch: number; title: string; routeTitle: string; arrivals: number; batchArrivals: number;
  preferences: number[]; zoneArrivals: number[]; batchPreferences: number[]; batchZoneArrivals: number[];
  festivalArrivals: number; batchFestivalArrivals: number; night: 'early' | 'late'; laneCapacity: number[];
  oilNeeded: number; wages: number; rent: number; effectiveLamps: boolean[]; staffCapacity: number[];
  supplyTripsLeft: number; emergencyLeft: number; freeWorkers: number; detail: string;
}
export interface MarketNightSummary {
  closed: boolean; passed: boolean; served: number; arrivals: number; cash: number; teaServed: number; festivalServed: number;
  targetServed: number; targetCash: number; targetTeaServed: number; targetFestivalServed: number;
  freeWorkers: number; title: string; detail: string;
}

export const NIGHT_CONFIG_REVISION: number = 1;
export const NIGHT_BODY_LIMIT: number = 4000;
export const NIGHT_WORKERS: number = 6;
export const NIGHT_ROUNDS: number = 4;
export const NIGHT_BATCHES: number = 3;
export const NIGHT_WORKER_CAPACITY: number = 5;
export const NIGHT_LANTERN_CAPACITY: number = 10;
export const NIGHT_WAGE: number = 2;
export const NIGHT_RENT: number = 2;
export const NIGHT_LOSS_REASONS: MarketNightReason[] = ['stock', 'workers', 'crowd', 'dark', 'missing', 'festival'];
export const NIGHT_SUPPLIES: MarketNightStock = { rice: 16, meat: 8, tea: 18, oil: 4 };
export const NIGHT_SUPPLY_COSTS: MarketNightStock = { rice: 8, meat: 10, tea: 6, oil: 6 };
export function marketNightSupplyCost(resource: MarketNightResource, emergency: boolean = false): number {
  return emergency ? Math.ceil(NIGHT_SUPPLY_COSTS[resource] * 1.5) : NIGHT_SUPPLY_COSTS[resource];
}
export const NIGHT_STALL_CONFIGS: MarketNightStallConfig[] = [
  { type: 'rice', name: '水饭铺', buildCost: 18, refund: 9, price: 3 },
  { type: 'meat', name: '肉食铺', buildCost: 24, refund: 12, price: 5 },
  { type: 'tea', name: '茶饮铺', buildCost: 14, refund: 7, price: 4 },
  { type: 'lantern', name: '灯棚', buildCost: 16, refund: 8, price: 0 }
];
export const NIGHT_LOTS: MarketNightLot[] = [
  { id: 0, zone: 0, label: '西街上铺' }, { id: 1, zone: 0, label: '西街下铺' },
  { id: 2, zone: 1, label: '中街上铺' }, { id: 3, zone: 1, label: '中街下铺' },
  { id: 4, zone: 2, label: '东街上铺' }, { id: 5, zone: 2, label: '东街下铺' }
];
export const NIGHT_ROUTES: MarketNightRoute[] = [
  { id: 'balanced', title: '三街均来', detail: '西、中、东三街分散来客，中街是常用通路。' },
  { id: 'west', title: '西来客多', detail: '约六成客人从西街来，近处开铺可少挤中街。' },
  { id: 'east', title: '东来客多', detail: '约六成客人从东街来，近处开铺可少挤中街。' }
];
export const NIGHT_CONFIGS: MarketNightConfig[] = [
  { id: 'night-1', title: '第一夜 · 州桥初市', subtitle: '先让一条夜市运转起来', contentId: 'culture-kf-night-market', budget: 60,
    initialStock: { rice: 24, meat: 10, tea: 16, oil: 3 }, target: { served: 65, cash: 20, teaServed: 0, festivalServed: 0 },
    arrivals: [18, 26, 32, 24], preferences: [[10, 5, 3], [10, 10, 6], [8, 12, 12], [4, 7, 13]], festival: [0, 0, 0, 0] },
  { id: 'night-2', title: '第二夜 · 夜深归人', subtitle: '固定茶铺之外，派一人沿街巡茶', contentId: 'culture-kf-bottle-tea', budget: 70,
    initialStock: { rice: 22, meat: 12, tea: 24, oil: 4 }, target: { served: 65, cash: 20, teaServed: 30, festivalServed: 0 },
    arrivals: [20, 28, 32, 28], preferences: [[6, 6, 8], [8, 8, 12], [6, 8, 18], [4, 6, 18]], festival: [0, 0, 0, 0] },
  { id: 'night-3', title: '第三夜 · 元夜灯市', subtitle: '观灯之后，再留一份夜市滋味', contentId: 'culture-kf-lantern-festival', budget: 90,
    initialStock: { rice: 24, meat: 14, tea: 24, oil: 6 }, target: { served: 65, cash: 20, teaServed: 0, festivalServed: 24 },
    arrivals: [20, 28, 32, 28], preferences: [[8, 6, 6], [8, 10, 10], [8, 10, 14], [4, 10, 14]], festival: [6, 10, 14, 10] }
];

function validInteger(value: number, min: number, max: number): boolean { return Number.isSafeInteger(value) && value >= min && value <= max; }
function configFor(id: MarketNightId): MarketNightConfig { const config = NIGHT_CONFIGS.find(item => item.id === id); if (!config) throw new Error('MARKET_NIGHT_INVALID_ID'); return config; }
function stallConfig(type: string): MarketNightStallConfig | undefined { return NIGHT_STALL_CONFIGS.find(item => item.type === type); }
function changedTime(state: RiverMarketV2, now: number): number { if (!validInteger(now, 0, Number.MAX_SAFE_INTEGER)) throw new Error('MARKET_NIGHT_INVALID_TIME'); return Math.max(now, state.updatedAt + 1); }
function copyStock(stock: MarketNightStock): MarketNightStock { return { rice: stock.rice, meat: stock.meat, tea: stock.tea, oil: stock.oil }; }
function emptyStock(): MarketNightStock { return { rice: 0, meat: 0, tea: 0, oil: 0 }; }
function assignedWorkers(state: RiverMarketV2): number { return state.stalls.reduce((sum, stall) => sum + stall.workers, state.tourZone >= 0 ? 1 : 0); }
function unchanged(state: RiverMarketV2, message: string): MarketNightActionResult { return { state, changed: false, message }; }
function plannedLamps(state: RiverMarketV2): boolean[] { const lamps = [false, false, false]; let oil = state.stock.oil; for (const zone of [1, 0, 2]) if (state.lamps[zone] && oil > 0) { lamps[zone] = true; oil--; } return lamps; }

export function marketNightLayout(state: RiverMarketV2): MarketNightLayout {
  return { stalls: state.stalls.map(stall => ({ lotId: stall.lotId, type: stall.type, workers: stall.workers })), lamps: state.lamps.slice(), tourZone: state.tourZone };
}
export function createMarketNight(nightId: MarketNightId, routeId: MarketRouteId, now: number, layout?: MarketNightLayout): RiverMarketV2 {
  if (!validInteger(now, 0, Number.MAX_SAFE_INTEGER) || !NIGHT_ROUTES.some(item => item.id === routeId)) throw new Error('MARKET_NIGHT_INVALID_START');
  const config = configFor(nightId);
  const initial: MarketNightLayout = layout || { stalls: NIGHT_LOTS.map(lot => ({ lotId: lot.id, type: lot.id === 2 ? 'rice' : lot.id === 3 ? 'meat' : '', workers: lot.id === 2 || lot.id === 3 ? 2 : 0 })), lamps: [false, true, false], tourZone: -1 };
  const state: RiverMarketV2 = { version: 2, nightId, configRevision: NIGHT_CONFIG_REVISION, routeId, round: 0, batch: 0, phase: 'prepare',
    cash: config.budget, stock: copyStock(config.initialStock), stalls: initial.stalls.map(stall => ({ lotId: stall.lotId, type: stall.type, workers: stall.workers })),
    lamps: initial.lamps.slice(), workers: NIGHT_WORKERS, tourZone: nightId === 'night-1' ? -1 : initial.tourZone,
    served: 0, arrivals: 0, teaServed: 0, festivalServed: 0, supplyTrips: 0, emergencyUsed: 0,
    usedCapacity: [0, 0, 0, 0, 0, 0], flow: [0, 0, 0], effectiveLamps: [false, false, false], tourServed: 0, reports: [], updatedAt: now };
  if (!validLayout(state)) throw new Error('MARKET_NIGHT_INVALID_LAYOUT');
  return state;
}
export function copyMarketNight(state: RiverMarketV2): RiverMarketV2 {
  return { ...state, stock: copyStock(state.stock), ...marketNightLayout(state), usedCapacity: state.usedCapacity.slice(), flow: state.flow.slice(), effectiveLamps: state.effectiveLamps.slice(),
    reports: state.reports.map(report => ({ ...report, reasons: report.reasons.slice(), batches: report.batches.map(batch => ({ ...batch, reasons: batch.reasons.slice() })) })) };
}

export function applyMarketNightAction(state: RiverMarketV2, action: MarketNightAction, now: number = Date.now()): MarketNightActionResult {
  if (state.phase === 'closed') return unchanged(state, '今夜已经收市，选择重新开局或进入下一夜。');
  const emergency = action.kind === 'emergency-staff' || action.kind === 'emergency-buy' || action.kind === 'emergency-lamp' || action.kind === 'emergency-tour';
  if (emergency && state.phase !== 'emergency') return unchanged(state, '应急只在前两批之后的暂停中安排。');
  if (!emergency && state.phase !== 'prepare') return unchanged(state, '这一段已经开市；暂停时可用应急，常规安排留到下一段。');
  if (emergency && state.emergencyUsed >= 2) return unchanged(state, '本段两次应急已用完，继续看下一批。');
  const next = copyMarketNight(state); let message = '';
  if (action.kind === 'buy' || action.kind === 'emergency-buy') {
    if (!['rice', 'meat', 'tea', 'oil'].includes(action.resource)) return unchanged(state, '这项物资不在补货单上。');
    if (!emergency && state.supplyTrips >= 2) return unchanged(state, '本段两趟常规补货已用完。');
    const cost = marketNightSupplyCost(action.resource, emergency);
    if (state.cash < cost) return unchanged(state, `这包货要${cost}钱，现钱不足。`);
    next.cash -= cost; next.stock[action.resource] += NIGHT_SUPPLIES[action.resource];
    if (!emergency) next.supplyTrips++;
    message = `${emergency ? '急送' : '补货'}一包已到，花${cost}钱；已经卖出的货不会重算。`;
  } else if (action.kind === 'lamp') {
    if (!validInteger(action.zone, 0, 2) || typeof action.on !== 'boolean') return unchanged(state, '请选择西、中、东三街。');
    if (state.lamps[action.zone] === action.on) return unchanged(state, '这一街的灯保持原样。');
    next.lamps[action.zone] = action.on; message = action.on ? '本段将为这条街留灯，开市时耗1份油。' : '本段不点这一街的灯。';
  } else if (action.kind === 'tour' || action.kind === 'emergency-tour') {
    if (state.nightId === 'night-1') return unchanged(state, '巡茶从第二夜开放。');
    if (!validInteger(action.zone, -1, 2)) return unchanged(state, '指定一个巡茶街区，或收回巡茶人。');
    if (state.tourZone === action.zone) return unchanged(state, '巡茶安排保持原样。');
    if (emergency && state.tourZone < 0) return unchanged(state, '应急只能改派或收回已出发的巡茶人；首次派遣留到下一段。');
    if (action.zone >= 0 && state.tourZone < 0 && assignedWorkers(state) >= state.workers) return unchanged(state, '先留出1名伙计，才能巡茶。');
    next.tourZone = action.zone; message = action.zone < 0 ? '巡茶人回到待分配。' : '1名伙计带茶巡街；每批最多接待这条街的2位茶客。';
  } else if (action.kind === 'emergency-lamp') {
    if (!validInteger(action.fromZone, 0, 2) || !validInteger(action.toZone, 0, 2) || action.fromZone === action.toZone || !state.effectiveLamps[action.fromZone] || state.effectiveLamps[action.toZone]) return unchanged(state, '把一盏已经亮着的街灯移到尚未亮灯的另一街。');
    // 开段时已经扣油。移灯只交换实际亮灯位置，不增加灯数、不返还油，也不清空已发生通行。
    next.effectiveLamps[action.fromZone] = false; next.effectiveLamps[action.toZone] = true;
    next.lamps[action.fromZone] = false; next.lamps[action.toZone] = true; message = '街灯已移位；剩余接待按新照明计算，已用灯油与通行不退回。';
  } else if (action.kind === 'emergency-staff') {
    if (!validInteger(action.fromLot, -1, 5) || !validInteger(action.toLot, 0, 5) || action.fromLot === action.toLot || !next.stalls[action.toLot].type) return unchanged(state, '从一间铺或待分配处调1人，到另一间已有铺子。');
    if (action.fromLot < 0 ? assignedWorkers(state) >= state.workers : next.stalls[action.fromLot].workers < 1) return unchanged(state, '调出位置没有可用的伙计。');
    if (next.stalls[action.toLot].type === 'lantern' && next.stalls[action.toLot].workers >= 1) return unchanged(state, '灯棚只需1名伙计。');
    if (action.fromLot >= 0) next.stalls[action.fromLot].workers--; next.stalls[action.toLot].workers++;
    message = '已调1名伙计；两间铺已用的接待次数均保留。';
  } else {
    if (!validInteger(action.lotId, 0, 5)) return unchanged(state, '请选择六处铺位之一。');
    const stall = next.stalls[action.lotId];
    if (action.kind === 'build') {
      const config = stallConfig(action.stallType);
      if (!config || (config.type === 'lantern' && state.nightId !== 'night-3')) return unchanged(state, '灯棚从第三夜开放，其余可开水饭、肉食或茶饮。');
      if (config.type === 'lantern' && state.stalls.some(item => item.type === 'lantern')) return unchanged(state, '今夜只布置一座灯棚。');
      if (stall.type) return unchanged(state, '这里已有铺子，先收铺再改建。');
      if (state.cash < config.buildCost) return unchanged(state, `开铺要${config.buildCost}钱，现钱不足。`);
      next.cash -= config.buildCost; stall.type = config.type; message = `${config.name}已布置，还需要拨伙计。`;
    } else if (action.kind === 'demolish') {
      const config = stallConfig(stall.type); if (!config) return unchanged(state, '这里本来就是空地。');
      next.cash += config.refund; stall.type = ''; stall.workers = 0; message = `收铺退回${config.refund}钱，伙计回到待分配。`;
    } else if (action.kind === 'staff') {
      if (!stall.type || (action.delta !== 1 && action.delta !== -1)) return unchanged(state, '先开铺，每次增减1名伙计。');
      if (stall.workers + action.delta < 0 || (stall.type === 'lantern' && stall.workers + action.delta > 1)) return unchanged(state, '这间铺不能这样安排人手；灯棚最多1人。');
      if (action.delta > 0 && assignedWorkers(state) >= state.workers) return unchanged(state, '六名伙计都已排上，先从别处调出1人。');
      stall.workers += action.delta; message = `这间铺现在有${stall.workers}名伙计。`;
    } else return unchanged(state, '这项安排还不能执行。');
  }
  if (emergency) next.emergencyUsed++; next.updatedAt = changedTime(state, now);
  return { state: next, changed: true, message };
}

function quotaSequence(quotas: number[], offset: number): number[] {
  const total = quotas.reduce((sum, value) => sum + value, 0); const used = quotas.map(() => 0); const result: number[] = [];
  for (let step = 0; step < total; step++) { let best = -1; let deficit = -Infinity;
    for (let cursor = 0; cursor < quotas.length; cursor++) { const candidate = (cursor + offset) % quotas.length; if (used[candidate] >= quotas[candidate]) continue;
      const current = quotas[candidate] * (step + 1) - used[candidate] * total; if (current > deficit) { deficit = current; best = candidate; }
    } result.push(best); used[best]++;
  } return result;
}
function originsFor(state: RiverMarketV2, round: number): number[] {
  const total = configFor(state.nightId).arrivals[round];
  if (state.routeId !== 'balanced') { const large = Math.round(total * 0.6); const mid = Math.round(total * 0.25); return state.routeId === 'west' ? [large, mid, total - large - mid] : [total - large - mid, mid, large]; }
  const balanced = [[6, 8, 4], [9, 9, 8], [12, 8, 12], [7, 6, 11]][round];
  const west = Math.round(total * balanced[0] / [18, 26, 32, 24][round]); const mid = Math.round(total * balanced[1] / [18, 26, 32, 24][round]); return [west, mid, total - west - mid];
}
function batchRange(total: number, batch: number): number[] { return [Math.floor(total * batch / 3), Math.floor(total * (batch + 1) / 3)]; }
function roundSequence(state: RiverMarketV2, round: number): number[][] { const config = configFor(state.nightId); return [quotaSequence(config.preferences[round], round), quotaSequence(originsFor(state, round), (round + 1) % 3), quotaSequence([config.arrivals[round] - config.festival[round], config.festival[round]], round % 2)]; }
function capacities(state: RiverMarketV2, lights: boolean[]): number[] { return state.stalls.map(stall => stall.workers * (stall.type === 'lantern' ? NIGHT_LANTERN_CAPACITY : state.round >= 2 && !lights[NIGHT_LOTS[stall.lotId].zone] ? 2 : NIGHT_WORKER_CAPACITY)); }
export function marketNightForecast(state: RiverMarketV2): MarketNightForecast {
  const config = configFor(state.nightId); const round = Math.min(state.round, 3); const batch = Math.min(state.batch, 2); const open = state.phase !== 'closed';
  const lights = state.phase === 'prepare' || !open ? plannedLamps(state) : state.effectiveLamps.slice();
  const sequences = roundSequence(state, round); const range = batchRange(config.arrivals[round], batch); const pref = [0, 0, 0]; const zones = [0, 0, 0]; let festival = 0;
  for (let index = range[0]; index < range[1]; index++) { pref[sequences[0][index]]++; zones[sequences[1][index]]++; festival += sequences[2][index]; }
  const route = NIGHT_ROUTES.find(item => item.id === state.routeId) as MarketNightRoute;
  return { round: state.round, batch: state.batch, title: ['灯起开市', '人盛街巷', '夜深卖茶', '五更再开'][round], routeTitle: route.title,
    arrivals: open ? config.arrivals[round] : 0, batchArrivals: open ? range[1] - range[0] : 0,
    preferences: open ? config.preferences[round].slice() : [0, 0, 0], zoneArrivals: open ? originsFor(state, round) : [0, 0, 0],
    batchPreferences: open ? pref : [0, 0, 0], batchZoneArrivals: open ? zones : [0, 0, 0], festivalArrivals: open ? config.festival[round] : 0, batchFestivalArrivals: open ? festival : 0,
    night: state.round >= 2 ? 'late' : 'early', laneCapacity: [18, 16, 18].map((capacity, zone) => state.round >= 2 && !lights[zone] ? 3 : capacity),
    oilNeeded: open ? state.lamps.filter(on => on).length : 0, wages: assignedWorkers(state) * NIGHT_WAGE,
    rent: state.stalls.filter(stall => stall.type !== '').length * NIGHT_RENT, effectiveLamps: lights, staffCapacity: capacities(state, lights),
    supplyTripsLeft: open ? 2 - state.supplyTrips : 0, emergencyLeft: open ? 2 - state.emergencyUsed : 0, freeWorkers: state.workers - assignedWorkers(state),
    detail: '三批共用本段库存、伙计接待次数和街区通行；前两批后可暂停，本段最多两次应急。深夜暗街仅通3客、每伙计接待2客。灯棚须有1人和亮灯，观灯后再消费。' };
}
export function beginMarketNightRound(state: RiverMarketV2, now: number = Date.now()): MarketNightActionResult {
  if (state.phase !== 'prepare' || state.round >= 4) return unchanged(state, '只有备市时才能开新一段。');
  const next = copyMarketNight(state); next.effectiveLamps = plannedLamps(state); const oilUsed = next.effectiveLamps.filter(on => on).length;
  next.stock.oil -= oilUsed; next.batch = 0; next.phase = 'running'; next.emergencyUsed = 0; next.tourServed = 0; next.flow = [0, 0, 0]; next.usedCapacity = [0, 0, 0, 0, 0, 0];
  next.reports.push({ round: state.round + 1, batches: [], arrivals: 0, served: 0, teaServed: 0, festivalServed: 0, income: 0, wages: 0, expenses: 0, cashAfter: next.cash, oilUsed, reasons: [0, 0, 0, 0, 0, 0] });
  next.updatedAt = changedTime(state, now); return { state: next, changed: true, message: `第${state.round + 1}段已开，已用${oilUsed}份灯油；现在进入第一批。` };
}

function pathZones(from: number, to: number): number[] { const path: number[] = []; for (let zone = Math.min(from, to); zone <= Math.max(from, to); zone++) path.push(zone); return path; }
function routeBlock(flow: number[], capacities: number[], path: number[]): number { for (const zone of path) if (flow[zone] >= capacities[zone]) return zone; return -1; }
function adviceFor(reasons: number[]): string[] {
  const text = ['想要的货已卖空，可急送或在下一段补货。', '伙计接待名额已用完，可从闲处调1人。', '街区通行已满，可把铺子放近来客街区。', '暗街挡住客人，可移一盏已亮街灯。', '客人没找到对应铺子，下一段可改建。', '观灯客未完成观灯，需要有伙计和照明的灯棚。'];
  const advice: string[] = []; for (let index = 0; index < reasons.length; index++) if (reasons[index] > 0) advice.push(`${reasons[index]}客：${text[index]}`);
  return advice.length ? advice : ['这一批全部接住了，下一批仍沿用本段已经消耗的库存和通行。'];
}
export function advanceMarketNightBatch(state: RiverMarketV2, now: number = Date.now()): MarketNightAdvanceResult {
  if ((state.phase !== 'running' && state.phase !== 'emergency') || state.batch >= 3) throw new Error('MARKET_NIGHT_BATCH_NOT_READY');
  const next = copyMarketNight(state); const config = configFor(state.nightId); const forecast = marketNightForecast(state); const sequences = roundSequence(state, state.round);
  const range = batchRange(config.arrivals[state.round], state.batch); const visits: MarketNightVisit[] = []; const servedByLot = [0, 0, 0, 0, 0, 0]; const stockUsed = emptyStock();
  const reasons = [0, 0, 0, 0, 0, 0]; let income = 0; let teaServed = 0; let festivalServed = 0; let tourBatch = 0;
  const preferences: MarketNightPreference[] = ['rice', 'meat', 'tea'];
  for (let index = range[0]; index < range[1]; index++) {
    const preference = preferences[sequences[0][index]]; const origin = sequences[1][index]; const festival = sequences[2][index] === 1;
    const visit: MarketNightVisit = { guestId: state.arrivals + index - range[0] + 1, origin, preference, targetLot: -1, lotId: -1, blockedZone: -1, served: false, reason: 'missing', festival, festivalViewed: false, festivalServed: false, festivalLot: -1, tour: false };
    const touched: number[] = []; let start = origin;
    if (festival) {
      const lantern = next.stalls.find(stall => stall.type === 'lantern');
      if (!lantern || lantern.workers < 1) visit.reason = 'festival';
      else { const zone = NIGHT_LOTS[lantern.lotId].zone; visit.festivalLot = lantern.lotId; visit.targetLot = lantern.lotId;
        if (!next.effectiveLamps[zone]) { visit.reason = 'dark'; visit.blockedZone = zone; }
        else if (next.usedCapacity[lantern.lotId] >= forecast.staffCapacity[lantern.lotId]) visit.reason = 'festival';
        else { const path = pathZones(origin, zone); const blocked = routeBlock(next.flow, forecast.laneCapacity, path);
          if (blocked >= 0) { visit.reason = state.round >= 2 && !next.effectiveLamps[blocked] ? 'dark' : 'crowd'; visit.blockedZone = blocked; }
          else { visit.festivalViewed = true; next.usedCapacity[lantern.lotId]++; for (const part of path) { next.flow[part]++; touched.push(part); } start = zone; }
        }
      }
    }
    if (!festival || visit.festivalViewed) {
      const candidates = next.stalls.filter(stall => stall.type === preference).sort((a, b) => Math.abs(NIGHT_LOTS[a.lotId].zone - start) - Math.abs(NIGHT_LOTS[b.lotId].zone - start) || a.lotId - b.lotId);
      if (candidates.length > 0) visit.targetLot = candidates[0].lotId;
      let reason: MarketNightReason = next.stock[preference] <= 0 ? 'stock' : 'missing'; let blockedZone = -1;
      // 巡茶只接本街茶客，每批单独有2客上限；它用同一份茶库存并占六人池中的一人。
      if (preference === 'tea' && next.tourZone === start && tourBatch < 2 && next.stock.tea > 0) {
        const path = touched.includes(start) ? [] : [start]; const blocked = routeBlock(next.flow, forecast.laneCapacity, path);
        if (blocked < 0) { visit.served = true; visit.tour = true; for (const part of path) next.flow[part]++; tourBatch++; next.tourServed++; }
        else { reason = state.round >= 2 && !next.effectiveLamps[blocked] ? 'dark' : 'crowd'; blockedZone = blocked; }
      }
      if (!visit.served && next.stock[preference] > 0) {
        let firstFailure: MarketNightReason | undefined; let firstBlocked = -1;
        for (const stall of candidates) {
          const zone = NIGHT_LOTS[stall.lotId].zone; if (visit.targetLot < 0 || festival) visit.targetLot = stall.lotId;
          if (next.usedCapacity[stall.lotId] >= forecast.staffCapacity[stall.lotId]) { if (!firstFailure) firstFailure = stall.workers > 0 && state.round >= 2 && !next.effectiveLamps[zone] ? 'dark' : 'workers'; continue; }
          const path = pathZones(start, zone).filter(part => !touched.includes(part)); const blocked = routeBlock(next.flow, forecast.laneCapacity, path);
          if (blocked >= 0) { if (!firstFailure) { firstFailure = state.round >= 2 && !next.effectiveLamps[blocked] ? 'dark' : 'crowd'; firstBlocked = blocked; } continue; }
          visit.served = true; visit.lotId = stall.lotId; visit.targetLot = stall.lotId; next.usedCapacity[stall.lotId]++; servedByLot[stall.lotId]++; for (const part of path) next.flow[part]++; break;
        }
        if (!visit.served && firstFailure) { reason = firstFailure; blockedZone = firstBlocked; }
      }
      if (visit.served) { visit.reason = 'served'; next.stock[preference]--; stockUsed[preference]++; income += (stallConfig(preference) as MarketNightStallConfig).price;
        if (preference === 'tea') teaServed++; if (festival) { visit.festivalServed = true; festivalServed++; }
      } else { visit.reason = reason; visit.blockedZone = blockedZone; }
    }
    if (!visit.served) reasons[NIGHT_LOSS_REASONS.indexOf(visit.reason)]++; visits.push(visit);
  }
  const served = visits.filter(visit => visit.served).length; const arrivals = visits.length;
  const summary: MarketNightBatchSummary = { batch: state.batch + 1, arrivals, served, teaServed, festivalServed, income, reasons: reasons.slice() };
  const roundReport = next.reports[next.reports.length - 1]; roundReport.batches.push(summary); roundReport.arrivals += arrivals; roundReport.served += served; roundReport.teaServed += teaServed; roundReport.festivalServed += festivalServed; roundReport.income += income;
  for (let reason = 0; reason < reasons.length; reason++) roundReport.reasons[reason] += reasons[reason];
  next.cash += income; roundReport.cashAfter = next.cash; next.served += served; next.arrivals += arrivals; next.teaServed += teaServed; next.festivalServed += festivalServed; next.batch++;
  next.phase = next.batch < 3 ? 'emergency' : 'settling'; next.updatedAt = changedTime(state, now);
  const report: MarketNightBatchReport = { ...summary, round: state.round + 1, visits, events: visits, servedByLot, stockUsed, effectiveLamps: next.effectiveLamps.slice(), stallTypes: next.stalls.map(stall => stall.type), reasonCounts: NIGHT_LOSS_REASONS.map((reason, index) => ({ reason, count: reasons[index] })), advice: adviceFor(reasons), cashAfter: next.cash, flow: next.flow.slice(), usedCapacity: next.usedCapacity.slice() };
  return { state: next, report };
}
export function endMarketNightRound(state: RiverMarketV2, now: number = Date.now()): MarketNightActionResult {
  if (state.phase !== 'settling' || state.batch !== 3) return unchanged(state, '三批客流走完之后才能结这一段账。');
  const next = copyMarketNight(state); const forecast = marketNightForecast(state); const expenses = forecast.wages + forecast.rent;
  next.cash -= expenses; const report = next.reports[next.reports.length - 1]; report.wages = forecast.wages; report.expenses = expenses; report.cashAfter = next.cash;
  next.round++; next.batch = 0; next.phase = next.round === 4 ? 'closed' : 'prepare'; next.supplyTrips = 0; next.emergencyUsed = 0;
  next.usedCapacity = [0, 0, 0, 0, 0, 0]; next.flow = [0, 0, 0]; next.effectiveLamps = [false, false, false]; next.tourServed = 0; next.updatedAt = changedTime(state, now);
  return { state: next, changed: true, message: `第${state.round + 1}段结账，工钱与铺租共${expenses}钱。${next.phase === 'closed' ? '今夜收市。' : '现在可安排下一段。'}` };
}
export function marketNightSummary(state: RiverMarketV2): MarketNightSummary {
  const target = configFor(state.nightId).target; const closed = state.phase === 'closed'; const passed = closed && state.served >= target.served && state.cash >= target.cash && state.teaServed >= target.teaServed && state.festivalServed >= target.festivalServed;
  return { closed, passed, served: state.served, arrivals: state.arrivals, cash: state.cash, teaServed: state.teaServed, festivalServed: state.festivalServed,
    targetServed: target.served, targetCash: target.cash, targetTeaServed: target.teaServed, targetFestivalServed: target.festivalServed,
    freeWorkers: state.workers - assignedWorkers(state), title: closed ? passed ? '今夜开市顺利' : '今夜还有客人没留住' : '下一批，由你安排',
    detail: `接待${state.served}/${target.served}客，余钱${state.cash}/${target.cash}钱${target.teaServed ? `，茶客${state.teaServed}/${target.teaServed}` : ''}${target.festivalServed ? `，观灯后消费${state.festivalServed}/${target.festivalServed}` : ''}。` };
}

function validLayout(state: RiverMarketV2): boolean {
  if (!Array.isArray(state.stalls) || state.stalls.length !== 6 || !Array.isArray(state.lamps) || state.lamps.length !== 3 || !state.lamps.every(on => typeof on === 'boolean') || state.workers !== 6 || !validInteger(state.tourZone, -1, 2) || (state.nightId === 'night-1' && state.tourZone !== -1)) return false;
  for (let index = 0; index < 6; index++) { const stall = state.stalls[index]; if (!stall || stall.lotId !== index || (stall.type !== '' && !stallConfig(stall.type)) || !validInteger(stall.workers, 0, stall.type === 'lantern' ? 1 : 6) || (stall.type === '' && stall.workers !== 0) || (stall.type === 'lantern' && state.nightId !== 'night-3')) return false; }
  return assignedWorkers(state) <= 6 && state.stalls.filter(stall => stall.type === 'lantern').length <= 1;
}
export function serializeMarketNight(state: RiverMarketV2): string {
  // 批摘要压成固定顺序数列，避免12批重复键名挤占既有4000字正文限额；读取后仍恢复具名接口。
  const wire = { ...state, reports: state.reports.map(report => ({ ...report, batches: report.batches.map(batch => [batch.batch, batch.arrivals, batch.served, batch.teaServed, batch.festivalServed, batch.income, ...batch.reasons]) })) };
  const body = JSON.stringify(wire); if (body.length > NIGHT_BODY_LIMIT) throw new Error('MARKET_NIGHT_RECORD_TOO_LARGE');
  if (!parseMarketNight(body)) throw new Error('MARKET_NIGHT_INVALID_STATE'); return body;
}
export function parseMarketNight(text: string): RiverMarketV2 | undefined {
  if (typeof text !== 'string' || !text.trim() || text.length > NIGHT_BODY_LIMIT) return undefined;
  let value: RiverMarketV2; try { value = JSON.parse(text) as RiverMarketV2; } catch (_error) { return undefined; }
  if (!value || value.version !== 2 || value.configRevision !== NIGHT_CONFIG_REVISION || !NIGHT_CONFIGS.some(item => item.id === value.nightId) || !NIGHT_ROUTES.some(item => item.id === value.routeId) || !validInteger(value.round, 0, 4) || !validInteger(value.batch, 0, 3) || !['prepare', 'running', 'emergency', 'settling', 'closed'].includes(value.phase) || !validInteger(value.cash, -500, 10000) || !validInteger(value.updatedAt, 0, Number.MAX_SAFE_INTEGER) || !validLayout(value)) return undefined;
  if (!value.stock || ![value.stock.rice, value.stock.meat, value.stock.tea, value.stock.oil].every(count => validInteger(count, 0, 500)) || !validInteger(value.supplyTrips, 0, 2) || !validInteger(value.emergencyUsed, 0, 2) || !validInteger(value.tourServed, 0, 6) || !Array.isArray(value.usedCapacity) || value.usedCapacity.length !== 6 || !value.usedCapacity.every(count => validInteger(count, 0, 40)) || !Array.isArray(value.flow) || value.flow.length !== 3 || !value.flow.every(count => validInteger(count, 0, 100)) || !Array.isArray(value.effectiveLamps) || value.effectiveLamps.length !== 3 || !value.effectiveLamps.every(on => typeof on === 'boolean')) return undefined;
  const active = value.phase === 'running' || value.phase === 'emergency' || value.phase === 'settling';
  if ((value.phase === 'closed') !== (value.round === 4) || ((value.phase === 'prepare' || value.phase === 'closed' || value.phase === 'running') && value.batch !== 0) || (value.phase === 'emergency' && value.batch !== 1 && value.batch !== 2) || (value.phase === 'settling' && value.batch !== 3) || !Array.isArray(value.reports) || value.reports.length !== value.round + (active ? 1 : 0)) return undefined;
  const config = configFor(value.nightId); let arrivals = 0; let served = 0; let tea = 0; let festival = 0;
  for (let index = 0; index < value.reports.length; index++) {
    const report = value.reports[index]; const current = active && index === value.round; const expectedBatches = current ? value.batch : 3;
    if (!report || report.round !== index + 1 || !Array.isArray(report.batches) || report.batches.length !== expectedBatches || !validInteger(report.oilUsed, 0, 3) || !validInteger(report.wages, 0, 12) || report.wages % 2 !== 0 || !validInteger(report.expenses, report.wages, report.wages + 12) || !validInteger(report.cashAfter, -500, 10000) || !Array.isArray(report.reasons) || report.reasons.length !== 6) return undefined;
    const sums = [0, 0, 0, 0, 0]; const reasons = [0, 0, 0, 0, 0, 0];
    for (let batchIndex = 0; batchIndex < report.batches.length; batchIndex++) {
      const raw = report.batches[batchIndex];
      if (Array.isArray(raw)) { const data = raw as number[]; if (data.length !== 12) return undefined; report.batches[batchIndex] = { batch: data[0], arrivals: data[1], served: data[2], teaServed: data[3], festivalServed: data[4], income: data[5], reasons: data.slice(6) }; }
      const batch = report.batches[batchIndex]; const range = batchRange(config.arrivals[index], batchIndex);
      if (!batch || batch.batch !== batchIndex + 1 || batch.arrivals !== range[1] - range[0] || !validInteger(batch.served, 0, batch.arrivals) || !validInteger(batch.teaServed, 0, batch.served) || !validInteger(batch.festivalServed, 0, Math.min(batch.served, config.festival[index])) || !validInteger(batch.income, batch.served * 3, batch.served * 5) || !Array.isArray(batch.reasons) || batch.reasons.length !== 6 || !batch.reasons.every(count => validInteger(count, 0, batch.arrivals)) || batch.reasons.reduce((sum, count) => sum + count, 0) !== batch.arrivals - batch.served) return undefined;
      sums[0] += batch.arrivals; sums[1] += batch.served; sums[2] += batch.teaServed; sums[3] += batch.festivalServed; sums[4] += batch.income; for (let reason = 0; reason < 6; reason++) reasons[reason] += batch.reasons[reason];
    }
    if (report.arrivals !== sums[0] || report.served !== sums[1] || report.teaServed !== sums[2] || report.festivalServed !== sums[3] || report.income !== sums[4] || !report.reasons.every((count, reason) => count === reasons[reason]) || (current && (report.wages !== 0 || report.expenses !== 0))) return undefined;
    arrivals += report.arrivals; served += report.served; tea += report.teaServed; festival += report.festivalServed;
  }
  if (value.arrivals !== arrivals || value.served !== served || value.teaServed !== tea || value.festivalServed !== festival || !validInteger(value.served, 0, 108) || !validInteger(value.teaServed, 0, 108) || !validInteger(value.festivalServed, 0, 40)) return undefined;
  if (!active && (value.usedCapacity.some(count => count !== 0) || value.flow.some(count => count !== 0) || value.effectiveLamps.some(on => on) || value.tourServed !== 0 || value.emergencyUsed !== 0)) return undefined;
  if (active) {
    const current = value.reports[value.round]; let foodUsed = value.tourServed; let lanternUsed = 0;
    for (const stall of value.stalls) {
      const used = value.usedCapacity[stall.lotId];
      if (stall.type === '') { if (used !== 0) return undefined; }
      else if (stall.type === 'lantern') { lanternUsed += used; if (used > NIGHT_LANTERN_CAPACITY) return undefined; }
      else foodUsed += used;
    }
    // 清零段内接待名额会让恢复后重复接客。建拆只允许备市，因此当段铺型不会改变，
    // 可用“食铺已用+巡茶已接=当段成功消费”守恒；观灯未消费也要保留已用灯棚名额。
    if (foodUsed !== current.served || value.tourServed > current.teaServed || value.tourServed > value.batch * 2 ||
      lanternUsed < current.festivalServed || value.flow.some(count => count > current.arrivals) ||
      value.usedCapacity.some(count => count > current.arrivals)) return undefined;
    if (value.phase === 'running' && (value.flow.some(count => count !== 0) || value.emergencyUsed !== 0)) return undefined;
  }
  // 备市可以继续花钱，应急也可在批后花钱；只有收段前和收市后没有额外动作，
  // 这两个检查点必须与最后一条已确认账目余额一致，不能接收被单独改过的金额。
  if ((value.phase === 'settling' || value.phase === 'closed') && value.cash !== value.reports[value.reports.length - 1].cashAfter) return undefined;
  if (value.phase === 'closed' && value.supplyTrips !== 0) return undefined;
  return copyMarketNight(value);
}
