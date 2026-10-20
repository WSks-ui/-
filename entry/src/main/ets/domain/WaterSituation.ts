// 黄河水情观察的领域模型。这里只做“公开报道摘录”的字段与校验，
// 不在应用内抓取日报、不做洪水预测或防灾判断。
// 数据边界：每条数值必须绑定一个可打开的公开来源和观测日期；
// 缺测值保持 undefined，不用 0 或插值补齐，避免把“不知道”画成趋势。

export interface WaterSource {
  id: string;
  publisher: string;
  title: string;
  url: string;
  publishedAt: string;
  accessedAt: string;
}

export interface WaterSnapshot {
  stationId: string;
  stationName: string;
  river: string;
  observedAt: string;
  waterLevelM?: number;
  flowM3s?: number;
  sedimentKgM3?: number;
  sourceId: string;
  note: string;
}

export interface WaterStation {
  id: string;
  name: string;
  river: string;
  section: string;
  whySourceId: string;
  why: string[];
}

export interface WaterSituationCatalog {
  updatedAt: string;
  stations: WaterStation[];
  snapshots: WaterSnapshot[];
  sources: WaterSource[];
  disclaimer: string;
  readingNote: string;
}

export function snapshotsForStation(catalog: WaterSituationCatalog, stationId: string): WaterSnapshot[] {
  return catalog.snapshots
    .filter((snapshot: WaterSnapshot) => snapshot.stationId === stationId)
    .sort((a: WaterSnapshot, b: WaterSnapshot) => a.observedAt < b.observedAt ? -1 : (a.observedAt > b.observedAt ? 1 : 0));
}

export function latestSnapshot(catalog: WaterSituationCatalog, stationId: string): WaterSnapshot | undefined {
  const list = snapshotsForStation(catalog, stationId);
  return list.length > 0 ? list[list.length - 1] : undefined;
}

export function sourceFor(catalog: WaterSituationCatalog, sourceId: string): WaterSource | undefined {
  return catalog.sources.find((source: WaterSource) => source.id === sourceId);
}

export function formatWaterValue(value: number | undefined, unit: string): string {
  if (value === undefined || !Number.isFinite(value)) return `未给出${unit ? ' ' + unit : ''}`;
  return `${value} ${unit}`.trim();
}

export function validateWaterSituation(catalog: WaterSituationCatalog): string[] {
  const problems: string[] = [];
  if (!catalog.stations.length) problems.push('缺少代表站');
  if (!catalog.snapshots.length) problems.push('缺少公开报道摘录');
  if (!catalog.sources.length) problems.push('缺少来源');
  if (!catalog.disclaimer.includes('非实时')) problems.push('缺少“非实时”声明');
  if (!catalog.disclaimer.includes('不提供')) problems.push('缺少“不提供预测/指令”声明');
  const sourceIds = new Set<string>(catalog.sources.map((source: WaterSource) => source.id));
  const stationIds = new Set<string>(catalog.stations.map((station: WaterStation) => station.id));
  catalog.snapshots.forEach((snapshot: WaterSnapshot) => {
    if (!stationIds.has(snapshot.stationId)) problems.push(`未知站点 ${snapshot.stationId}`);
    if (!sourceIds.has(snapshot.sourceId)) problems.push(`未知来源 ${snapshot.sourceId}`);
    if (!/^\d{4}-\d{2}-\d{2}/.test(snapshot.observedAt)) problems.push(`日期格式 ${snapshot.observedAt}`);
    if (snapshot.waterLevelM !== undefined && !(snapshot.waterLevelM > 0)) problems.push(`水位异常 ${snapshot.observedAt}`);
    if (snapshot.flowM3s !== undefined && !(snapshot.flowM3s > 0)) problems.push(`流量异常 ${snapshot.observedAt}`);
    if (snapshot.sedimentKgM3 !== undefined && !(snapshot.sedimentKgM3 >= 0)) problems.push(`含沙量异常 ${snapshot.observedAt}`);
  });
  catalog.stations.forEach((station: WaterStation) => {
    if (!sourceIds.has(station.whySourceId)) problems.push(`站点说明缺少来源 ${station.id}`);
  });
  catalog.sources.forEach((source: WaterSource) => {
    if (!/^https?:\/\//.test(source.url)) problems.push(`来源链接 ${source.id}`);
  });
  return problems;
}

// 服务端 /water/situation 的实时返回。字段与日报页面一致：河名、站名、时间、水位、流量；
// 当前页面不提供含沙量，统一为 null，不用 0 代替。stale 表示“上次快照”或观测日期不是今天。
export interface WaterLiveStation {
  river: string;
  station: string;
  observedAt: string;
  waterLevelM: number | null;
  flowM3s: number | null;
  sedimentKgM3: number | null;
}

export interface WaterLiveReply {
  source: string;
  sourceUrl: string;
  fetchedAt: string;
  observedAt: string;
  stale: boolean;
  stations: WaterLiveStation[];
  error?: string | null;
}

export function validateWaterLiveReply(reply: WaterLiveReply): WaterLiveReply {
  if (!reply || typeof reply.source !== 'string' || typeof reply.observedAt !== 'string' ||
    !Array.isArray(reply.stations)) throw new Error('WATER_INVALID_REPLY');
  reply.stations.forEach((station: WaterLiveStation) => {
    if (typeof station.station !== 'string' || !station.station.trim() ||
      typeof station.observedAt !== 'string' || !station.observedAt.trim()) {
      throw new Error('WATER_INVALID_REPLY');
    }
  });
  return reply;
}

export function liveStation(reply: WaterLiveReply | undefined, name: string): WaterLiveStation | undefined {
  return reply?.stations.find((station: WaterLiveStation) => station.station === name);
}

export function liveLevelText(value: number | null | undefined): string {
  return value === null || value === undefined ? '未给出' : `${value} m`;
}

export function liveFlowText(value: number | null | undefined): string {
  return value === null || value === undefined ? '未给出' : `${value} m³/s`;
}
