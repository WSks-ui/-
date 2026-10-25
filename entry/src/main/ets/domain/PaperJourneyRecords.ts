import type { ArchiveRecord } from './ArchiveDomain';
import type { PaperWorkV1 } from './PaperJourney';
import { mergeRecords } from './ArchiveDomain';
import { copyPaperWork, isPaperCityId, parsePaperWork, serializePaperWork } from './PaperJourney';

// 一城一条 progress；旧漫游、城市与探方记录保留原身份，读取时互不冒充。
// 当前编辑、四步撤销与完成快照都封在同一 body。共用合并保持当前编辑整条LWW，
// 并保留实际完成快照；绝不按位合成两端剪口，也不伪造 note 的 roamingContext。
export function paperWorkRecordId(cityId: string): string {
  if (!isPaperCityId(cityId)) throw new Error('PAPER_INVALID_CITY');
  return `progress:paper-journey:v1:${cityId}`;
}

function currentPaperRecord(records: ArchiveRecord[], cityId: string): ArchiveRecord | undefined {
  if (!isPaperCityId(cityId)) return undefined;
  return mergeRecords([], records).records.find((item: ArchiveRecord) => item.id === paperWorkRecordId(cityId));
}

function workFromRecord(record: ArchiveRecord, cityId: string): PaperWorkV1 | undefined {
  if (record.kind !== 'progress' || record.siteId !== cityId) return undefined;
  const work = parsePaperWork(record.body);
  return work && work.cityId === cityId ? work : undefined;
}

export function paperWorkFromRecords(records: ArchiveRecord[], cityId: string): PaperWorkV1 | undefined {
  const record = currentPaperRecord(records, cityId);
  if (!record || record.deleted || record.kind !== 'progress' || record.siteId !== cityId) return undefined;
  return workFromRecord(record, cityId);
}

export function paperWorkIsUnreadable(records: ArchiveRecord[], cityId: string): boolean {
  const record = currentPaperRecord(records, cityId);
  // “没有可读作品”与“已经有记录但读坏了”必须分开：后者不能当空白纸让下一剪覆盖。
  // 与正常读取共用有效版本判定；缺记录和墓碑仍可按原语义开始，旧坏版本不复活。
  // 此处只报告状态，不删字段、不补空纸、不改原正文或版本，恢复由显式备份流程处理。
  return record !== undefined && !record.deleted && workFromRecord(record, cityId) === undefined;
}

export function paperWorkRecord(work: PaperWorkV1, deviceId: string, updatedAt: number): ArchiveRecord {
  const saved = copyPaperWork(work);
  saved.updatedAt = updatedAt;
  return { id: paperWorkRecordId(saved.cityId), kind: 'progress', siteId: saved.cityId,
    body: serializePaperWork(saved), tags: [], updatedAt, deviceId, deleted: false };
}
