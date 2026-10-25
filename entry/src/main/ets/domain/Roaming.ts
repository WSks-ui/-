import type { ArchiveRecord } from './ArchiveDomain';
import { copySnapshot, emptySnapshot, mergeRecords } from './ArchiveDomain';

export interface RoamSource {
  id: string;
  title: string;
  url: string;
  accessedAt: string;
}

export interface RoamOption {
  id: string;
  label: string;
  detail: string;
}

export interface RoamClue {
  id: string;
  title: string;
  goal: string;
  instruction: string;
  body: string;
  era: string;
  sourceIds: string[];
  mode: string;
  options: RoamOption[];
}

export interface RoamChapter {
  id: string;
  city: string;
  title: string;
  kicker: string;
  subtitle: string;
  opening: string;
  closing: string;
  accent: string;
  scene: string;
  relatedSiteIds: string[];
  clues: RoamClue[];
  sourceIds: string[];
}

// 漫游拥有自己的图景恢复信息。不要把选择写入 snapshot3DPose，后者仍只表示旧器物观察镜头。
// 摘录、篇名及来源在用户保存那一刻复制；目录升级不能追改已经写下的个人依据。
export interface RoamingMemoryContext {
  version: number;
  chapterId: string;
  clueId: string;
  sceneRevision: number;
  // 资料正文与图景分别修订。旧上下文缺省时保持未知，不从当前目录倒填保存时的资料版本。
  contentRevision?: number;
  choiceId: string;
  excerpt: string;
  title: string;
  city: string;
  sources: RoamSource[];
}

export interface RoamProgress {
  completedIds: string[];
  nextClueId: string;
  completedCount: number;
  total: number;
  completed: boolean;
}

interface RoamProgressPayload {
  version: number;
  chapterId: string;
  clueId: string;
  choiceId: string;
  completed: boolean;
}

const ROAM_PROGRESS_PREFIX: string = 'progress:roam:v1:';

function validRoamId(value: string): boolean {
  return typeof value === 'string' && /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(value);
}

export function roamProgressRecordId(chapterId: string, clueId: string): string {
  if (!validRoamId(chapterId) || !validRoamId(clueId)) throw new Error('ROAM_INVALID_KEY');
  // 独立命名空间不与 progress:<旧遗址> 或 progress:<旧遗址>:<阅读主题> 相互解释。
  // 每条线索独立记录，使同账号两端完成不同线索时仍沿用既有 LWW / 墓碑规则。
  return `${ROAM_PROGRESS_PREFIX}${chapterId}:${clueId}`;
}

function liveRoamChoice(records: ArchiveRecord[], chapterId: string, clueId: string): string {
  const record = records.find((item: ArchiveRecord) => item.id === roamProgressRecordId(chapterId, clueId));
  if (!record || record.kind !== 'progress' || record.siteId !== chapterId || record.deleted) return '';
  try {
    const payload = JSON.parse(record.body) as RoamProgressPayload;
    return payload && payload.version === 1 && payload.chapterId === chapterId && payload.clueId === clueId &&
      payload.completed === true && validRoamId(payload.choiceId) ? payload.choiceId : '';
  } catch (_error) {
    // 不认识的正文不代表完成；原记录仍留给快照与合并层保存，不在读取时修补或覆盖。
    return '';
  }
}

export function roamChoice(records: ArchiveRecord[], chapterId: string, clueId: string): string {
  return liveRoamChoice(mergeRecords([], records).records, chapterId, clueId);
}

export function roamProgress(records: ArchiveRecord[], chapter: RoamChapter): RoamProgress {
  const current = mergeRecords([], records).records;
  const completedIds: string[] = [];
  // 只展开连续完成的前缀。早期线索的墓碑获胜后，后续记录虽保留，也不能绕过重新展开的目标。
  // 五城彼此不设门槛；这里的顺序只约束传入的这一篇章，不把阅读或收藏算成探索动作。
  for (const clue of chapter.clues) {
    const choice = liveRoamChoice(current, chapter.id, clue.id);
    if (!clue.options.some((option: RoamOption) => option.id === choice)) break;
    completedIds.push(clue.id);
  }
  const total = chapter.clues.length;
  return {
    completedIds,
    nextClueId: completedIds.length < total ? chapter.clues[completedIds.length].id : '',
    completedCount: completedIds.length,
    total,
    completed: total > 0 && completedIds.length === total
  };
}

function copyProgressRecord(record: ArchiveRecord): ArchiveRecord {
  const snapshot = emptySnapshot(record.deviceId);
  snapshot.records = [record];
  return copySnapshot(snapshot).records[0];
}

export function completeRoamClue(
  chapter: RoamChapter,
  clueId: string,
  choice: string,
  records: ArchiveRecord[],
  deviceId: string,
  updatedAt: number
): ArchiveRecord {
  const clue = chapter.clues.find((item: RoamClue) => item.id === clueId);
  if (!clue || !clue.options.some((option: RoamOption) => option.id === choice)) {
    throw new Error('ROAM_INVALID_CHOICE');
  }
  if (!deviceId.trim() || !Number.isSafeInteger(updatedAt) || updatedAt < 0) {
    throw new Error('ROAM_INVALID_RECORD');
  }
  const current = mergeRecords([], records).records;
  const progress = roamProgress(current, chapter);
  if (!progress.completedIds.includes(clueId) && progress.nextClueId !== clueId) {
    throw new Error('ROAM_CLUE_LOCKED');
  }
  const id = roamProgressRecordId(chapter.id, clueId);
  const previous = current.find((item: ArchiveRecord) => item.id === id);
  // 重复确认同一个选择是幂等操作：沿用原版本，避免连续点击制造同步更新。
  if (previous && liveRoamChoice(current, chapter.id, clueId) === choice) return copyProgressRecord(previous);
  if (previous && updatedAt <= previous.updatedAt) throw new Error('ROAM_STALE_TIMESTAMP');
  return {
    id,
    kind: 'progress',
    siteId: chapter.id,
    body: JSON.stringify({ version: 1, chapterId: chapter.id, clueId, choiceId: choice, completed: true }),
    tags: [],
    updatedAt,
    deviceId,
    deleted: false
  };
}

export function makeRoamingMemoryContext(
  chapter: RoamChapter,
  clue: RoamClue,
  choice: string,
  sources: RoamSource[],
  contentRevision: number = 1
): RoamingMemoryContext {
  if (!Number.isSafeInteger(contentRevision) || contentRevision <= 0) throw new Error('ROAM_INVALID_CONTENT_REVISION');
  if (!chapter.clues.some((item: RoamClue) => item.id === clue.id)) throw new Error('ROAM_CLUE_NOT_FOUND');
  const option = clue.options.find((item: RoamOption) => item.id === choice);
  if (!option) throw new Error('ROAM_INVALID_CHOICE');
  const frozenSources: RoamSource[] = [];
  clue.sourceIds.forEach((id: string) => {
    const source = sources.find((item: RoamSource) => item.id === id);
    if (!source) throw new Error('ROAM_SOURCE_NOT_FOUND');
    frozenSources.push({ id: source.id, title: source.title, url: source.url, accessedAt: source.accessedAt });
  });
  return {
    version: 1,
    chapterId: chapter.id,
    clueId: clue.id,
    sceneRevision: 1,
    // 目录调用方传入 ROAM_CONTENT_REVISION；默认1兼容首发调用，不让领域层反向依赖数据目录。
    contentRevision,
    choiceId: choice,
    excerpt: `${clue.body}\n\n我选择：${option.label}。${option.detail}`,
    title: `${chapter.title} · ${clue.title}`,
    city: chapter.city,
    sources: frozenSources
  };
}
