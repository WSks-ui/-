import type { ArchiveRecord } from './ArchiveDomain';
import { mergeRecords } from './ArchiveDomain';
import { decodeExplorationProgress } from './ExplorationProgress';
import { isMemoryPostcard } from './MemoryJournal';

export interface JourneyRoute {
  id: string;
  title: string;
  subtitle: string;
  caption: string;
  stamp: string;
  color: string;
  siteIds: string[];
}

export interface JourneyProgress {
  route: JourneyRoute;
  completedSiteIds: string[];
  completedCount: number;
  total: number;
  percent: number;
  unlocked: boolean;
  nextSiteId: string;
}

// 路线仅引用当前离线目录的稳定 ID。顺序是主题阅读编排，不表示历史先后、
// 真实交通线或跨遗址的统一地层；后续增删节点时应同步核对文化目录与演示入口。
export const JOURNEY_ROUTES: JourneyRoute[] = [
  {
    id: 'seeking-xia', title: '寻夏记', subtitle: '聚落与早期都邑的文明线索',
    caption: '从彩陶聚落的日常读起，走向中原早期都邑。', stamp: '夏', color: '#B9697F',
    siteIds: ['smx-yangshao', 'smx-miaodigou', 'ly-erlitou', 'ly-yanshi-shang', 'zz-shang']
  },
  {
    id: 'earth-and-fire', title: '泥火成器', subtitle: '陶土、青铜与琉璃的材料记忆',
    caption: '把材料作为入口，观察器物与建筑里的手作智慧。', stamp: '器', color: '#B98752',
    siteIds: ['smx-miaodigou', 'zz-dahecun', 'zz-duling-fangding', 'kf-iron-pagoda']
  },
  {
    id: 'folded-capitals', title: '折叠的都城', subtitle: '城址、桥与城墙的城市切片',
    caption: '沿城市空间的线索，看见不同文化记忆的叠影。', stamp: '城', color: '#7C9995',
    siteIds: ['ly-hanwei', 'zz-zhenghan', 'kf-zhouqiao', 'kf-city-wall', 'py-qicheng']
  }
];

export function journeyForId(id: string): JourneyRoute | undefined {
  return JOURNEY_ROUTES.find((route: JourneyRoute) => route.id === id);
}

function hasExploredSite(records: ArchiveRecord[], siteId: string): boolean {
  // 75% 表示四个内容主题中已明确完成三个。旧版 opened、普通收藏、普通笔记
  // 都不能自动升级为路线完成；只有能被手账解码器确认的活跃卡片可替代此门槛。
  return decodeExplorationProgress(records, siteId).percent >= 75 ||
    records.some((record: ArchiveRecord) => record.siteId === siteId &&
      record.kind === 'note' && !record.deleted && isMemoryPostcard(record));
}

export function journeyProgress(records: ArchiveRecord[], route: JourneyRoute): JourneyProgress {
  // 通常快照已按逻辑 ID 合并。这里仍使用既有确定性规则归一一次，确保收到旧版本
  // 与删除墓碑的组合时不会短暂“复活”节点；徽章不另写记录，也没有永久解锁缓存。
  const current = mergeRecords([], records).records;
  const completedSiteIds = route.siteIds.filter((siteId: string) => hasExploredSite(current, siteId));
  const total = route.siteIds.length;
  const completedCount = completedSiteIds.length;
  return {
    route,
    completedSiteIds,
    completedCount,
    total,
    percent: total > 0 ? Math.round(completedCount * 100 / total) : 0,
    unlocked: total > 0 && completedCount === total,
    nextSiteId: route.siteIds.find((siteId: string) => !completedSiteIds.includes(siteId)) || ''
  };
}

// 个人图谱的纪念节点取已完整完成路线的节点并集，而非把某条路线的局部进度
// 误作整条已解锁。删除或同步替换任一记录后，调用方用最新快照重新派生即可。
export function unlockedJourneySiteIds(records: ArchiveRecord[]): string[] {
  const unlocked: string[] = [];
  JOURNEY_ROUTES.forEach((route: JourneyRoute) => {
    const progress = journeyProgress(records, route);
    if (!progress.unlocked) return;
    route.siteIds.forEach((siteId: string) => { if (!unlocked.includes(siteId)) unlocked.push(siteId); });
  });
  return unlocked;
}
