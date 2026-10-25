import type { ArchiveRecord } from './ArchiveDomain';
import type { KaifengDigV1 } from './KaifengDig';
import { digRecordId, parseDig, serializeDig } from './KaifengDig';

// 探方进度同样存成一条普通 progress 记录：
//   id      progress:kaifeng-dig:v1:<chapterId>
//   siteId  章节 id
//   body    KaifengDigV1 JSON（≤1800 字符）
// 与城市记录（progress:kaifeng-city:v1:*）分开：两者生命周期不同，
// 重开探方不应影响已建成的城，反过来也一样。
// v1 的种子、格位与记录 ID 不迁移；跨端、游客复制和备份通过 mergeRecords
// 的纯领域适配保留较大局号与历史最佳，不要求 UI/HTTPS 各写一套合并规则。

export function kaifengDigFromRecords(records: ArchiveRecord[], chapterId: string): KaifengDigV1 | undefined {
  let recordId = '';
  try {
    recordId = digRecordId(chapterId);
  } catch (_error) {
    return undefined;
  }
  const record = records.find((item: ArchiveRecord) => item.id === recordId && item.kind === 'progress' && !item.deleted);
  if (!record) return undefined;
  return parseDig(record.body);
}

export function kaifengDigRecord(dig: KaifengDigV1, deviceId: string, updatedAt: number): ArchiveRecord {
  return {
    id: digRecordId(dig.chapterId),
    kind: 'progress',
    siteId: dig.chapterId,
    body: serializeDig(dig),
    tags: [],
    updatedAt,
    deviceId,
    deleted: false
  };
}
