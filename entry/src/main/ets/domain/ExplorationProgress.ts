import type { ArchiveRecord } from './ArchiveDomain';

const LEGACY_OPENED_BODY = 'opened';
const PROGRESS_RECORD_PREFIX = 'progress:';
// 与 CulturalContent 的四个学习主题 ID 保持一致；领域测试会比对两处，避免进度数据和内容入口漂移。
export type ExplorationSectionId = 'overview' | 'archaeology' | 'history' | 'poetry-travel';
const SECTION_IDS: ExplorationSectionId[] = ['overview', 'archaeology', 'history', 'poetry-travel'];

export interface ExplorationProgress {
  siteId: string;
  completedSectionIds: ExplorationSectionId[];
  percent: number;
  // 仅表示旧版曾打开过详情；不能当成任何 section 已读，更不能转成 100%。
  openedOnly: boolean;
}

function isSectionId(value: string): value is ExplorationSectionId {
  return SECTION_IDS.includes(value as ExplorationSectionId);
}

function isValidSiteId(siteId: string): boolean {
  return /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(siteId);
}

export function explorationProgressRecordId(siteId: string, sectionId: ExplorationSectionId): string {
  if (!isValidSiteId(siteId) || !isSectionId(sectionId)) throw new Error('EXPLORATION_PROGRESS_INVALID_KEY');
  // 每个主题有独立逻辑 ID，多端分别完成不同主题时可以按 ArchiveDomain 的既有规则合并。
  return `${PROGRESS_RECORD_PREFIX}${siteId}:${sectionId}`;
}

export function emptyExplorationProgress(siteId: string): ExplorationProgress {
  return { siteId, completedSectionIds: [], percent: 0, openedOnly: false };
}

export function decodeExplorationProgress(records: ArchiveRecord[], siteId: string): ExplorationProgress {
  if (!isValidSiteId(siteId)) throw new Error('EXPLORATION_PROGRESS_INVALID_SITE');
  const completed: ExplorationSectionId[] = [];
  let hasLegacyOpenMarker = false;

  records.forEach((record: ArchiveRecord) => {
    if (record.kind !== 'progress' || record.siteId !== siteId || record.deleted) return;

    // schema v1 旧版只记“打开详情”。保留此语义用于兼容提示，但不计入任何阅读比例。
    if (record.id === `${PROGRESS_RECORD_PREFIX}${siteId}` && record.body === LEGACY_OPENED_BODY) {
      hasLegacyOpenMarker = true;
      return;
    }

    const sectionId = SECTION_IDS.find((item) => record.id === explorationProgressRecordId(siteId, item));
    if (!sectionId || completed.includes(sectionId)) return;

    try {
      const payload = JSON.parse(record.body) as { version?: number; sectionId?: string; completed?: boolean };
      if (payload.version === 1 && payload.sectionId === sectionId && payload.completed === true) {
        completed.push(sectionId);
      }
    } catch (_error) {
      // 非法或未知版本的正文忽略，避免损坏记录被误当成已探索。
    }
  });

  const ordered = SECTION_IDS.filter((sectionId) => completed.includes(sectionId));
  return {
    siteId,
    completedSectionIds: ordered,
    percent: ordered.length * 25,
    openedOnly: hasLegacyOpenMarker && ordered.length === 0
  };
}

// 用户明确完成一个学习主题后才调用；该纯函数只计算状态，不写本机或云端数据。
export function markSectionExplored(
  progress: ExplorationProgress,
  sectionId: ExplorationSectionId
): ExplorationProgress {
  if (!isValidSiteId(progress.siteId) || !isSectionId(sectionId)) {
    throw new Error('EXPLORATION_PROGRESS_INVALID_SECTION');
  }
  if (progress.completedSectionIds.includes(sectionId)) return progress;

  const completed = SECTION_IDS.filter((id) => progress.completedSectionIds.includes(id) || id === sectionId);
  return {
    siteId: progress.siteId,
    completedSectionIds: completed,
    percent: completed.length * 25,
    openedOnly: false
  };
}

export function encodeExplorationProgressRecord(
  siteId: string,
  sectionId: ExplorationSectionId,
  updatedAt: number,
  deviceId: string
): ArchiveRecord {
  if (!Number.isSafeInteger(updatedAt) || updatedAt < 0 || !deviceId.trim()) {
    throw new Error('EXPLORATION_PROGRESS_INVALID_RECORD');
  }
  return {
    id: explorationProgressRecordId(siteId, sectionId),
    kind: 'progress',
    siteId,
    body: JSON.stringify({ version: 1, sectionId, completed: true }),
    // 保持归档信封 tags 字段语义，不用标签承载进度状态。
    tags: [],
    updatedAt,
    deviceId,
    deleted: false
  };
}
