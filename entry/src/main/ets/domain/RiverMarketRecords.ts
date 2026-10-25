import type { ArchiveRecord } from './ArchiveDomain';
import { mergeRecords } from './ArchiveDomain';
import type { RiverMarketV1 } from './RiverMarket';
import { copyRiverMarket, parseRiverMarket, serializeRiverMarket } from './RiverMarket';

export const RIVER_MARKET_RECORD_ID: string = 'progress:river-market:v1:kaifeng';

function currentRecord(records: ArchiveRecord[]): ArchiveRecord | undefined {
  return mergeRecords([], records).records.find(record => record.id === RIVER_MARKET_RECORD_ID);
}

function recordState(record: ArchiveRecord): RiverMarketV1 | undefined {
  return record.kind === 'progress' && record.siteId === 'kf-zhouqiao' ? parseRiverMarket(record.body) : undefined;
}

export function riverMarketFromRecords(records: ArchiveRecord[]): RiverMarketV1 | undefined {
  const record = currentRecord(records);
  return record && !record.deleted ? recordState(record) : undefined;
}

export function riverMarketIsDeleted(records: ArchiveRecord[]): boolean {
  const record = currentRecord(records);
  // 墓碑按同一版本规则决出，正文损坏不改变已删除的含义；旧墓碑被更新的明确新局覆盖后返回false。
  // 与“从未开局”和“活记录不可读”分开，供调用方阻止旧页面的普通动作自动复活删除。
  return record !== undefined && record.deleted;
}

export function riverMarketIsUnreadable(records: ArchiveRecord[]): boolean {
  const record = currentRecord(records);
  // 损坏正文与“尚未开市”分开；只报告，不把坏记录补成新局，也不改原始body或版本。
  return record !== undefined && !record.deleted && recordState(record) === undefined;
}

export function riverMarketRecord(state: RiverMarketV1, deviceId: string, updatedAt: number): ArchiveRecord {
  const saved = copyRiverMarket(state); saved.updatedAt = updatedAt;
  return { id: RIVER_MARKET_RECORD_ID, kind: 'progress', siteId: 'kf-zhouqiao', body: serializeRiverMarket(saved),
    tags: [], updatedAt, deviceId, deleted: false };
}
