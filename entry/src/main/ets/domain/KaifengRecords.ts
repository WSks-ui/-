import { ArchiveRecord } from './ArchiveDomain';
import {
  KaifengCityV1, kaifengCityRecordId, parseKaifengCity, serializeKaifengCity
} from './KaifengPuzzle';

// 城市快照作为一条普通 progress 记录保存：
//   id      progress:kaifeng-city:v1:<chapterId>
//   siteId  章节 id（首页“最近一城”按 siteId 识别）
//   body    KaifengCityV1 JSON（≤1800 字符）
// 这样不需要改 parseSnapshot 白名单、同步层或墓碑语义，跨端合并直接复用现有 LWW。
// 与 progress:roam:v1:<chapter>:<clue> 分开，roamProgress 的严格前缀不会被这条记录干扰。

export function kaifengCityFromRecords(records: ArchiveRecord[], chapterId: string): KaifengCityV1 | undefined {
  let recordId = '';
  try {
    recordId = kaifengCityRecordId(chapterId);
  } catch (_error) {
    return undefined;
  }
  const record = records.find((item: ArchiveRecord) => item.id === recordId && item.kind === 'progress' && !item.deleted);
  if (!record) return undefined;
  return parseKaifengCity(record.body);
}

export function kaifengCityRecord(city: KaifengCityV1, deviceId: string, updatedAt: number): ArchiveRecord {
  return {
    id: kaifengCityRecordId(city.chapterId),
    kind: 'progress',
    siteId: city.chapterId,
    body: serializeKaifengCity(city),
    tags: [],
    updatedAt,
    deviceId,
    deleted: false
  };
}
