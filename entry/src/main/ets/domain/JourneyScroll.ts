import type { ArchiveRecord, HeritageSite } from './ArchiveDomain';
import { activeRecords, mergeRecords } from './ArchiveDomain';
import { connectionReasons } from './CultureConnections';
import { decodeExplorationProgress } from './ExplorationProgress';
import type { JourneyProgress, JourneyRoute } from './JourneyRoutes';
import { journeyForId, journeyProgress } from './JourneyRoutes';

export interface JourneyScrollStep {
  site: HeritageSite;
  // 保留主题路线中的 1 起始序号，不能按个人记录出现的先后重新编号。
  index: number;
  readingReason: string;
  favorite: boolean;
  noteCount: number;
  exploredPercent: number;
  completed: boolean;
}

export interface JourneyScrollEntry {
  site: HeritageSite;
  // 保留完整活跃记录，普通笔记也可阅读；有画面时由既有 note 回放入口解释元数据。
  notes: ArchiveRecord[];
  favorite: boolean;
  exploredPercent: number;
  reasons: string[];
}

export interface JourneyScrollGroup {
  city: string;
  entries: JourneyScrollEntry[];
}

export interface JourneyScrollModel {
  route: JourneyRoute;
  progress: JourneyProgress;
  steps: JourneyScrollStep[];
  groups: JourneyScrollGroup[];
  noteCount: number;
  personalSiteCount: number;
}

// 本轮只编排“泥火成器”已有的四处阅读入口，不生成新史实或材料传播关系。
// 增减路线节点时应随目录核对阅读理由；出处始终读取 step.site.source，继承初稿校审状态。
const READING_REASONS: Record<string, string> = {
  'smx-miaodigou': '从陶窑、居住区与壕沟的位置入手，观察庙底沟的聚落布局。',
  'zz-dahecun': '沿腹部接合处的椭圆形通口，观察两只陶壶怎样内部相通。',
  'zz-duling-fangding': '分开观察四面正中与四个折角，辨认上腹八组兽面纹的位置。',
  'kf-iron-pagoda': '从琉璃面砖和外壁花纹入手，认识铁塔的构件与材料。'
};

export function buildJourneyScroll(sites: HeritageSite[], records: ArchiveRecord[]): JourneyScrollModel {
  const route = journeyForId('earth-and-fire');
  if (!route) throw new Error('JOURNEY_SCROLL_ROUTE_NOT_FOUND');
  // 先按既有版本规则归一，再派生显示。旧活跃版本与新墓碑同时到达时，不能短暂复活长卷。
  // 路线外记录不参与数量、专题或关联，避免其他页面的操作改变本主题的个人线索。
  const current = mergeRecords([], records).records
    .filter((record: ArchiveRecord) => route.siteIds.includes(record.siteId));
  const notes = activeRecords(current, 'note');
  const progress = journeyProgress(current, route);
  const steps: JourneyScrollStep[] = [];
  route.siteIds.forEach((siteId: string, index: number) => {
    const site = sites.find((item: HeritageSite) => item.id === siteId);
    if (!site) return;
    steps.push({
      site,
      index: index + 1,
      readingReason: READING_REASONS[siteId] || site.summary,
      favorite: current.some((record: ArchiveRecord) =>
        record.siteId === siteId && record.kind === 'favorite' && !record.deleted),
      noteCount: notes.filter((note: ArchiveRecord) => note.siteId === siteId).length,
      exploredPercent: decodeExplorationProgress(current, siteId).percent,
      completed: progress.completedSiteIds.includes(siteId)
    });
  });

  // 普通笔记、收藏或有效 section 都是个人线索；是否完成路线仍只由 journeyProgress 决定。
  // 不把旧 opened 标记计作学习，也不从任何记录推断到访经历。
  const entries: JourneyScrollEntry[] = steps
    .filter((step: JourneyScrollStep) => step.noteCount > 0 || step.favorite || step.exploredPercent > 0)
    .map((step: JourneyScrollStep): JourneyScrollEntry => ({
      site: step.site,
      notes: notes.filter((note: ArchiveRecord) => note.siteId === step.site.id),
      favorite: step.favorite,
      exploredPercent: step.exploredPercent,
      reasons: []
    }));
  entries.forEach((entry: JourneyScrollEntry) => {
    entries.forEach((other: JourneyScrollEntry) => {
      // 复用图谱的属性与“我的专题”理由，只比较本路线中真实存在的其他个人条目。
      // 多条记录或多个对象命中同一理由时仅显示一次，不把同标签说成历史传承或因果。
      connectionReasons(entry.site, other.site, current).forEach((reason: string) => {
        if (!entry.reasons.includes(reason)) entry.reasons.push(reason);
      });
    });
  });
  const groups: JourneyScrollGroup[] = [];
  entries.forEach((entry: JourneyScrollEntry) => {
    const group = groups.find((item: JourneyScrollGroup) => item.city === entry.site.city);
    if (group) group.entries.push(entry);
    else groups.push({ city: entry.site.city, entries: [entry] });
  });
  return {
    route,
    progress,
    steps,
    groups,
    noteCount: entries.reduce((count: number, entry: JourneyScrollEntry) => count + entry.notes.length, 0),
    personalSiteCount: entries.length
  };
}
