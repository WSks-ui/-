import type { RiverMarketV2 } from './RiverMarketV2';

// 三夜记忆是用户确认保存的一张静止图景。这里只存可解释的轻量布置与累计摘要，
// 不存经营 state、库存账本、逐客轨迹或动画时间；继续开市不能改写已经留下的这一页。
export interface MarketMemorySource {
  id: string;
  title: string;
  url: string;
  quote: string;
  accessedAt: string;
  era: string;
}

export interface MarketMemoryStall {
  lotId: number;
  type: string;
  workers: number;
}

export interface MarketMemoryLayout {
  stalls: MarketMemoryStall[];
  lamps: boolean[];
  tourZone: number;
}

export interface MarketMemorySummary {
  served: number;
  arrivals: number;
  teaServed: number;
  festivalServed: number;
  cash: number;
}

// schema v1 的可选扩展。没有 marketContext 的旧 note 保持缺省，读取时不能从
// 当前游戏反推或补写；来源正文和修订号随本页冻结，资料更新也不会替换旧出处。
export interface MarketMemoryContext {
  version: number;
  nightId: string;
  title: string;
  contentRevision: number;
  sceneRevision: number;
  routeId: string;
  round: number;
  batch: number;
  layout: MarketMemoryLayout;
  summary: MarketMemorySummary;
  excerpt: string;
  sources: MarketMemorySource[];
}

export function copyMarketMemory(context: MarketMemoryContext): MarketMemoryContext {
  return { version: context.version, nightId: context.nightId, title: context.title,
    contentRevision: context.contentRevision, sceneRevision: context.sceneRevision,
    routeId: context.routeId, round: context.round, batch: context.batch,
    layout: { stalls: context.layout.stalls.map((stall: MarketMemoryStall): MarketMemoryStall => ({
      lotId: stall.lotId, type: stall.type, workers: stall.workers })),
      lamps: context.layout.lamps.slice(), tourZone: context.layout.tourZone },
    summary: { served: context.summary.served, arrivals: context.summary.arrivals,
      teaServed: context.summary.teaServed, festivalServed: context.summary.festivalServed, cash: context.summary.cash },
    excerpt: context.excerpt,
    sources: context.sources.map((source: MarketMemorySource): MarketMemorySource => ({
      id: source.id, title: source.title, url: source.url, quote: source.quote,
      accessedAt: source.accessedAt, era: source.era })) };
}

function integer(value: number, minimum: number, maximum: number): boolean {
  return Number.isSafeInteger(value) && value >= minimum && value <= maximum;
}

export function validMarketMemorySource(source: MarketMemorySource): boolean {
  return !!source && typeof source.id === 'string' && /^[a-z0-9-]{1,100}$/.test(source.id) &&
    typeof source.title === 'string' && source.title.trim().length > 0 && source.title.length <= 240 &&
    typeof source.url === 'string' && /^https?:\/\/[^\s]+$/.test(source.url) && source.url.length <= 2048 &&
    typeof source.quote === 'string' && source.quote.trim().length > 0 && source.quote.length <= 2400 &&
    typeof source.accessedAt === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(source.accessedAt) &&
    typeof source.era === 'string' && source.era.trim().length > 0 && source.era.length <= 160;
}

export function validMarketMemory(context: MarketMemoryContext): boolean {
  if (!context || context.version !== 1 || typeof context.nightId !== 'string' ||
    !['night-1', 'night-2', 'night-3'].includes(context.nightId) ||
    typeof context.title !== 'string' || !context.title.trim() || context.title.length > 180 ||
    !integer(context.contentRevision, 1, 1000) || !integer(context.sceneRevision, 1, 1000) ||
    typeof context.routeId !== 'string' || !['balanced', 'west', 'east'].includes(context.routeId) ||
    !integer(context.round, 0, 4) || !integer(context.batch, 0, 3) ||
    typeof context.excerpt !== 'string' || context.excerpt.length > 2400 ||
    !context.layout || !Array.isArray(context.layout.stalls) || context.layout.stalls.length !== 6 ||
    !Array.isArray(context.layout.lamps) || context.layout.lamps.length !== 3 ||
    !context.layout.lamps.every((lamp: boolean): boolean => typeof lamp === 'boolean') ||
    !integer(context.layout.tourZone, -1, 2) ||
    !context.summary || !integer(context.summary.arrivals, 0, 10000) ||
    !integer(context.summary.served, 0, context.summary.arrivals) ||
    !integer(context.summary.teaServed, 0, context.summary.served) ||
    !integer(context.summary.festivalServed, 0, context.summary.served) ||
    !integer(context.summary.cash, -100000, 1000000) ||
    !Array.isArray(context.sources) || context.sources.length < 1 || context.sources.length > 8) return false;
  const lots: number[] = [];
  if (!context.layout.stalls.every((stall: MarketMemoryStall): boolean => {
    if (!stall || !integer(stall.lotId, 0, 5) || lots.includes(stall.lotId) ||
      !['', 'rice', 'meat', 'tea', 'lantern'].includes(stall.type) || !integer(stall.workers, 0, 6) ||
      (!stall.type && stall.workers !== 0)) return false;
    lots.push(stall.lotId); return true;
  })) return false;
  if (context.layout.stalls.reduce((sum: number, stall: MarketMemoryStall): number => sum + stall.workers,
    context.layout.tourZone >= 0 ? 1 : 0) > 6) return false;
  const sourceIds: string[] = [];
  return context.sources.every((source: MarketMemorySource): boolean => {
    if (!validMarketMemorySource(source) || sourceIds.includes(source.id)) return false;
    sourceIds.push(source.id); return true;
  });
}

// 用固定字段顺序参与确定性版本比较，不能依赖外部 JSON 的对象属性插入顺序。
export function canonicalMarketMemory(context: MarketMemoryContext): string {
  return JSON.stringify(copyMarketMemory(context));
}

export function freezeMarketMemory(state: RiverMarketV2, title: string, contentRevision: number,
  sources: MarketMemorySource[], excerpt: string = ''): MarketMemoryContext {
  // 开段后灯油已扣、应急还可能移灯，营业中的图景必须冻结当段effectiveLamps，
  // 不能从计划灯或剩余灯油重算，否则缺油时会把实际未点亮的街画亮。
  // 备市/收市没有活跃批次，保存的是用户布置灯位；收段已清空effectiveLamps，
  // 此时仍取计划灯，不能因此把收市布局误画成所有街灯都被用户关掉。
  const active = state.phase === 'running' || state.phase === 'emergency' || state.phase === 'settling';
  const lamps = active ? state.effectiveLamps : state.lamps;
  const context: MarketMemoryContext = { version: 1, nightId: state.nightId, title, contentRevision,
    sceneRevision: 1, routeId: state.routeId, round: state.round, batch: state.batch,
    layout: { stalls: state.stalls.map((stall: MarketMemoryStall): MarketMemoryStall => ({
      lotId: stall.lotId, type: stall.type, workers: stall.workers })), lamps: lamps.slice(), tourZone: state.tourZone },
    summary: { served: state.served, arrivals: state.arrivals, teaServed: state.teaServed,
      festivalServed: state.festivalServed, cash: state.cash }, excerpt,
    sources: sources.map((source: MarketMemorySource): MarketMemorySource => ({ id: source.id,
      title: source.title, url: source.url, quote: source.quote, accessedAt: source.accessedAt, era: source.era })) };
  if (!validMarketMemory(context)) throw new Error('MARKET_MEMORY_INVALID_CONTEXT');
  return context;
}
