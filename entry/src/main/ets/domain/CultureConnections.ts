import type { ArchiveRecord, HeritageSite } from './ArchiveDomain';

export interface CultureConnection {
  site: HeritageSite;
  reasons: string[];
}

// 图谱只表达档案属性与个人记录中的关联，不将同标签解释为历史传承或因果关系。
// 直接使用已有收藏/笔记，所以用户的操作会改变图谱，不需要另建一套演示数据。
export function personalCultureSites(sites: HeritageSite[], records: ArchiveRecord[], topic: string = ''): HeritageSite[] {
  const personal = records.filter((record: ArchiveRecord) => !record.deleted && ['favorite', 'note'].includes(record.kind));
  return sites.filter((site: HeritageSite) => personal.some((record: ArchiveRecord) =>
    record.siteId === site.id && (!topic || record.tags.includes(topic))));
}

export function cultureTopics(records: ArchiveRecord[]): string[] {
  const topics: string[] = [];
  records.filter((record: ArchiveRecord) => record.kind === 'note' && !record.deleted).forEach((record: ArchiveRecord) => {
    record.tags.forEach((tag: string) => { if (!topics.includes(tag)) topics.push(tag); });
  });
  return topics.sort();
}

export function connectionReasons(left: HeritageSite, right: HeritageSite, records: ArchiveRecord[] = []): string[] {
  if (left.id === right.id) return [];
  const reasons: string[] = [];
  if (left.era === right.era) reasons.push(`同属${left.era}时期`);
  if (left.type === right.type) reasons.push(`同为${left.type}`);
  if (left.city === right.city) reasons.push(`同在${left.city}`);
  left.tags.filter((tag: string) => right.tags.includes(tag)).forEach((tag: string) => reasons.push(`文化线索：${tag}`));
  const notes = records.filter((record: ArchiveRecord) => record.kind === 'note' && !record.deleted);
  const leftTags: string[] = [];
  notes.filter((record: ArchiveRecord) => record.siteId === left.id).forEach((record: ArchiveRecord) => {
    record.tags.forEach((tag: string) => { if (!leftTags.includes(tag)) leftTags.push(tag); });
  });
  leftTags.forEach((tag: string) => {
    if (notes.some((record: ArchiveRecord) => record.siteId === right.id && record.tags.includes(tag))) {
      reasons.push(`我的专题：${tag}`);
    }
  });
  return reasons;
}

export function cultureConnections(sites: HeritageSite[], selectedId: string, records: ArchiveRecord[] = []): CultureConnection[] {
  const selected = sites.find((site: HeritageSite) => site.id === selectedId);
  if (!selected) return [];
  return sites.filter((site: HeritageSite) => site.id !== selectedId)
    .map((site: HeritageSite): CultureConnection => ({ site, reasons: connectionReasons(selected, site, records) }))
    .filter((connection: CultureConnection) => connection.reasons.length > 0)
    .sort((a: CultureConnection, b: CultureConnection) => b.reasons.length - a.reasons.length ||
      (a.site.id === b.site.id ? 0 : a.site.id < b.site.id ? -1 : 1));
}
