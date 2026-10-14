export interface SourceRef {
  title: string;
  url: string;
}

export interface HeritageSite {
  id: string;
  name: string;
  city: string;
  era: string;
  type: string;
  tags: string[];
  summary: string;
  overview: string;
  archaeology: string;
  history: string;
  poetry: string;
  travel: string;
  source: SourceRef;
  reviewStatus: string;
  illustration: string;
  accent: string;
}

export interface SiteFilter {
  keyword: string;
  city: string;
  era: string;
  type: string;
}

// 收藏、笔记、进度共用版本信封。删除保留墓碑，后续设备重连时不能把旧记录复活。
// updatedAt 由单设备逻辑时钟生成；跨设备时钟偏差仍需同步适配层处理，不能承诺物理时间绝对准确。
export interface ArchiveRecord {
  id: string;
  kind: string;
  siteId: string;
  body: string;
  tags: string[];
  updatedAt: number;
  deviceId: string;
  deleted: boolean;
}

export interface ArchiveSnapshot {
  schemaVersion: number;
  deviceId: string;
  records: ArchiveRecord[];
  lightEnabled: boolean;
  reducedMotion: boolean;
}

export interface Recommendation {
  site: HeritageSite;
  score: number;
  reason: string;
}

export interface MergeResult {
  records: ArchiveRecord[];
  conflicts: ArchiveRecord[];
}

export const CITIES: string[] = ['全部城市', '三门峡', '洛阳', '郑州', '开封', '濮阳'];
export const ERAS: string[] = ['全部年代', '仰韶', '龙山', '夏商', '周', '汉唐', '宋'];
export const TYPES: string[] = ['全部类型', '聚落遗址', '都城遗址', '城址', '墓葬群', '窑址', '古建筑'];
export const COLLECTION_TAGS: string[] = ['待实地探访', '已去过', '研究资料'];
export const MAX_NOTE_LENGTH: number = 4000;
export const MAX_NOTE_TAGS: number = 20;
export const MAX_NOTE_TAG_LENGTH: number = 40;
// 标签编辑框必须容纳全部合法标签及分隔符，不能在编辑既有记录时截断后面的标签。
export const MAX_NOTE_TAGS_TEXT_LENGTH: number = MAX_NOTE_TAGS * MAX_NOTE_TAG_LENGTH + MAX_NOTE_TAGS - 1;

export function emptySnapshot(deviceId: string): ArchiveSnapshot {
  return { schemaVersion: 1, deviceId, records: [], lightEnabled: true, reducedMotion: false };
}

export function copySnapshot(snapshot: ArchiveSnapshot): ArchiveSnapshot {
  return {
    schemaVersion: snapshot.schemaVersion,
    deviceId: snapshot.deviceId,
    records: snapshot.records.map((record: ArchiveRecord): ArchiveRecord => ({
      id: record.id, kind: record.kind, siteId: record.siteId, body: record.body,
      tags: record.tags.slice(), updatedAt: record.updatedAt, deviceId: record.deviceId, deleted: record.deleted
    })),
    lightEnabled: snapshot.lightEnabled,
    reducedMotion: snapshot.reducedMotion
  };
}

export function filterSites(sites: HeritageSite[], filter: SiteFilter): HeritageSite[] {
  const words = filter.keyword.trim().toLowerCase().split(/\s+/).filter((word: string) => word.length > 0);
  return sites.filter((site: HeritageSite) => {
    const text = `${site.name} ${site.city} ${site.era} ${site.type} ${site.summary} ${site.tags.join(' ')}`.toLowerCase();
    return (filter.city === CITIES[0] || filter.city === site.city) &&
      (filter.era === ERAS[0] || filter.era === site.era) &&
      (filter.type === TYPES[0] || filter.type === site.type) &&
      words.every((word: string) => text.includes(word));
  });
}

export function activeRecords(records: ArchiveRecord[], kind: string): ArchiveRecord[] {
  return records.filter((record: ArchiveRecord) => record.kind === kind && !record.deleted)
    .sort((a: ArchiveRecord, b: ArchiveRecord) => b.updatedAt - a.updatedAt || compareText(a.id, b.id));
}

export function nextTimestamp(records: ArchiveRecord[], now: number): number {
  return records.reduce((latest: number, record: ArchiveRecord) => Math.max(latest, record.updatedAt + 1), now);
}

export function putRecord(records: ArchiveRecord[], record: ArchiveRecord): ArchiveRecord[] {
  return records.filter((item: ArchiveRecord) => item.id !== record.id).concat([record]);
}

export function compareText(a: string, b: string): number {
  return a === b ? 0 : (a < b ? -1 : 1);
}

// 相同时间戳必须有稳定的次序，否则 A 合并 B 与 B 合并 A 会得出不同结果。
// 相同时间的删除优先，其次设备 ID，最后完整内容；禁止使用依赖语言环境的 localeCompare。
export function compareVersions(a: ArchiveRecord, b: ArchiveRecord): number {
  if (a.updatedAt !== b.updatedAt) return a.updatedAt - b.updatedAt;
  if (a.deleted !== b.deleted) return a.deleted ? 1 : -1;
  const deviceOrder = compareText(a.deviceId, b.deviceId);
  if (deviceOrder !== 0) return deviceOrder;
  return compareText(JSON.stringify([a.kind, a.siteId, a.body, a.tags]),
    JSON.stringify([b.kind, b.siteId, b.body, b.tags]));
}

export function mergeRecords(local: ArchiveRecord[], remote: ArchiveRecord[]): MergeResult {
  const records: ArchiveRecord[] = [];
  const conflicts: ArchiveRecord[] = [];
  local.concat(remote).forEach((candidate: ArchiveRecord) => {
    const index = records.findIndex((record: ArchiveRecord) => record.id === candidate.id);
    if (index < 0) {
      records.push(candidate);
    } else {
      const previous = records[index];
      const order = compareVersions(candidate, previous);
      if (order !== 0 && candidate.deviceId !== previous.deviceId &&
        (candidate.body !== previous.body || candidate.deleted !== previous.deleted ||
          candidate.tags.join('\u0000') !== previous.tags.join('\u0000'))) {
        conflicts.push(order > 0 ? previous : candidate);
      }
      if (order > 0) records[index] = candidate;
    }
  });
  records.sort((a: ArchiveRecord, b: ArchiveRecord) => compareText(a.id, b.id));
  return { records, conflicts };
}

export function recommendSites(sites: HeritageSite[], records: ArchiveRecord[], currentId: string = ''): Recommendation[] {
  const favorites = activeRecords(records, 'favorite');
  const viewed = activeRecords(records, 'progress');
  const anchors = sites.filter((site: HeritageSite) => site.id === currentId ||
    favorites.some((record: ArchiveRecord) => record.siteId === site.id) ||
    viewed.some((record: ArchiveRecord) => record.siteId === site.id));
  return sites.filter((site: HeritageSite) => site.id !== currentId &&
    !favorites.some((record: ArchiveRecord) => record.siteId === site.id) &&
    !viewed.some((record: ArchiveRecord) => record.siteId === site.id))
    .map((site: HeritageSite): Recommendation => {
      let score = 0;
      let reason = '从另一座城市开启探索';
      anchors.forEach((anchor: HeritageSite) => {
        let value = 0;
        const reasons: string[] = [];
        if (anchor.era === site.era) { value += 4; reasons.push(`同属${site.era}时期`); }
        if (anchor.city === site.city) { value += 3; reasons.push(`同在${site.city}`); }
        if (anchor.type === site.type) { value += 2; reasons.push(`同为${site.type}`); }
        const shared = anchor.tags.filter((tag: string) => site.tags.includes(tag));
        value += shared.length;
        if (shared.length > 0) reasons.push(`关联${shared[0]}`);
        if (value > score) { score = value; reason = reasons.join(' · '); }
      });
      return { site, score, reason };
    }).sort((a: Recommendation, b: Recommendation) => b.score - a.score || compareText(a.site.id, b.site.id)).slice(0, 3);
}

export function parseSnapshot(raw: string): ArchiveSnapshot {
  const value = JSON.parse(raw) as ArchiveSnapshot;
  if (!value || value.schemaVersion !== 1 || typeof value.deviceId !== 'string' || !value.deviceId ||
    !Array.isArray(value.records) || typeof value.lightEnabled !== 'boolean' ||
    typeof value.reducedMotion !== 'boolean' || value.records.length > 10000) {
    throw new Error('ARCHIVE_INVALID_SCHEMA');
  }
  const ids: string[] = [];
  value.records.forEach((record: ArchiveRecord) => {
    if (!record || typeof record.id !== 'string' || !record.id || ids.includes(record.id) ||
      !['favorite', 'note', 'progress'].includes(record.kind) || typeof record.siteId !== 'string' || !record.siteId ||
      typeof record.body !== 'string' || record.body.length > MAX_NOTE_LENGTH ||
      !Array.isArray(record.tags) || record.tags.length > MAX_NOTE_TAGS ||
      !record.tags.every((tag: string) => typeof tag === 'string' && tag.length <= MAX_NOTE_TAG_LENGTH) ||
      !Number.isSafeInteger(record.updatedAt) || record.updatedAt < 0 ||
      typeof record.deviceId !== 'string' || !record.deviceId || typeof record.deleted !== 'boolean') {
      throw new Error('ARCHIVE_INVALID_RECORD');
    }
    ids.push(record.id);
  });
  return value;
}
