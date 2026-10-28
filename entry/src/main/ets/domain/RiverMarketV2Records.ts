import type { ArchiveRecord } from './ArchiveDomain';
import { mergeRecords } from './ArchiveDomain';
import type { MarketNightId, RiverMarketV2 } from './RiverMarketV2';
import { copyMarketNight, marketNightSummary, parseMarketNight, serializeMarketNight } from './RiverMarketV2';

export const MARKET_NIGHT_RECORD_PREFIX: string = 'progress:river-market:v2:kaifeng:';
export const MARKET_NIGHT_IDS: MarketNightId[] = ['night-1', 'night-2', 'night-3'];
export function marketNightRecordId(nightId: MarketNightId): string { return MARKET_NIGHT_RECORD_PREFIX + nightId; }
function currentRecord(records: ArchiveRecord[], nightId: MarketNightId): ArchiveRecord | undefined {
  // 同一夜取整个LWW胜出版本。金额、库存和客数都是一份经营账，不允许把两台设备的数量相加。
  return mergeRecords([], records).records.find(record => record.id === marketNightRecordId(nightId));
}
function recordState(record: ArchiveRecord, nightId: MarketNightId): RiverMarketV2 | undefined {
  if (record.kind !== 'progress' || record.siteId !== 'kf-zhouqiao') return undefined;
  const state = parseMarketNight(record.body); return state && state.nightId === nightId ? state : undefined;
}
export function marketNightFromRecords(records: ArchiveRecord[], nightId: MarketNightId): RiverMarketV2 | undefined {
  const record = currentRecord(records, nightId); return record && !record.deleted ? recordState(record, nightId) : undefined;
}
export function marketNightIsDeleted(records: ArchiveRecord[], nightId: MarketNightId): boolean {
  const record = currentRecord(records, nightId); return record !== undefined && record.deleted;
}
export function marketNightIsUnreadable(records: ArchiveRecord[], nightId: MarketNightId): boolean {
  const record = currentRecord(records, nightId); return record !== undefined && !record.deleted && recordState(record, nightId) === undefined;
}
export function marketNightRecord(state: RiverMarketV2, deviceId: string, updatedAt: number): ArchiveRecord {
  const saved = copyMarketNight(state); saved.updatedAt = updatedAt;
  return { id: marketNightRecordId(state.nightId), kind: 'progress', siteId: 'kf-zhouqiao', body: serializeMarketNight(saved), tags: [], updatedAt, deviceId, deleted: false };
}
export function nextMarketNight(nightId: MarketNightId): MarketNightId | undefined {
  return nightId === 'night-1' ? 'night-2' : nightId === 'night-2' ? 'night-3' : undefined;
}
export function marketNightUnlocked(records: ArchiveRecord[], nightId: MarketNightId): boolean {
  if (nightId === 'night-1') return true;
  // 解锁只约束首次进入：已合法保存的后夜可以独立继续，重玩前夜不能追改后夜资格。
  // 墓碑和损坏正文都不能作为“曾经开过”的凭证；它们仍走明确恢复或重开的页面流程。
  if (marketNightFromRecords(records, nightId) !== undefined) return true;
  const previous = marketNightFromRecords(records, nightId === 'night-2' ? 'night-1' : 'night-2');
  // 前夜损坏、删除或未达成时不伪造解锁；下一夜已经存在的进度也保留原记录，供明确恢复处理。
  return previous !== undefined && marketNightSummary(previous).passed;
}
