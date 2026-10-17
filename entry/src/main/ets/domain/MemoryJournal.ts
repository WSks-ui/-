import type { ArchiveRecord, HeritageSite, MemoryPose } from './ArchiveDomain';

export const STAMP_TYPES: string[] = ['河洛拾遗', '夏都寻踪', '商都吉金', '汴京梦华', '仰韶初光'];
export const PAPER_THEMES: string[] = ['rose', 'ochre', 'jade', 'ink'];

// 印章是用户可切换的手账装饰主题，不代替遗址的断代、王朝归属或器物出土结论。
export function defaultStampForSite(site: HeritageSite): string {
  if (site.era === '仰韶') return '仰韶初光';
  if (site.id === 'ly-erlitou') return '夏都寻踪';
  if (site.id === 'zz-shang' || site.id === 'ly-yanshi-shang' || site.id === 'zz-duling-fangding') return '商都吉金';
  if (site.city === '开封') return '汴京梦华';
  return '河洛拾遗';
}

export function paperThemeLabel(theme: string): string {
  if (theme === 'rose') return '玫瑰笺';
  if (theme === 'ochre') return '陶土笺';
  if (theme === 'jade') return '青玉笺';
  if (theme === 'ink') return '墨色笺';
  return '素纸';
}

interface SeasonalMarker {
  monthDay: number;
  label: string;
}

// 仅用于个人记忆的时令氛围，采用常见月日作近似分段，不冒充逐年天文节气计算。
// 标签自带“时令近似”提示；如以后接入权威历法，应保留记录时间戳，不批量改写历史笔记。
const SEASONAL_MARKERS: SeasonalMarker[] = [
  { monthDay: 105, label: '小寒' }, { monthDay: 120, label: '大寒' },
  { monthDay: 204, label: '立春' }, { monthDay: 219, label: '雨水' },
  { monthDay: 306, label: '惊蛰' }, { monthDay: 321, label: '春分' },
  { monthDay: 405, label: '清明' }, { monthDay: 420, label: '谷雨' },
  { monthDay: 506, label: '立夏' }, { monthDay: 521, label: '小满' },
  { monthDay: 606, label: '芒种' }, { monthDay: 621, label: '夏至' },
  { monthDay: 707, label: '小暑' }, { monthDay: 723, label: '大暑' },
  { monthDay: 808, label: '立秋' }, { monthDay: 823, label: '处暑' },
  { monthDay: 908, label: '白露' }, { monthDay: 923, label: '秋分' },
  { monthDay: 1008, label: '寒露' }, { monthDay: 1023, label: '霜降' },
  { monthDay: 1107, label: '立冬' }, { monthDay: 1122, label: '小雪' },
  { monthDay: 1207, label: '大雪' }, { monthDay: 1222, label: '冬至' }
];

export function memorySeasonLabel(timestamp: number): string {
  const date = new Date(timestamp);
  if (!Number.isFinite(date.getTime())) return '时令未记';
  const monthDay = (date.getMonth() + 1) * 100 + date.getDate();
  let label = '冬至';
  SEASONAL_MARKERS.forEach((marker: SeasonalMarker) => {
    if (monthDay >= marker.monthDay) label = marker.label;
  });
  return `${label} · 时令近似`;
}

export function memoryPoseLabel(pose?: MemoryPose): string {
  if (!pose) return '未记录视角';
  if (pose.label.trim()) return pose.label.trim();
  if (pose.sectionId === 'overview') return '概览';
  if (pose.sectionId === 'archaeology') return '遗存观察';
  if (pose.sectionId === 'history') return '历史线索';
  if (pose.sectionId === 'poetry-travel') return '诗词与今访';
  if (pose.proceduralPreset === 'dahecun_pottery' && pose.sceneRevision === 2) {
    if (pose.hotspotId === 'mouth') return '两只壶口';
    if (pose.hotspotId === 'opening') return '腹部通口';
    if (pose.hotspotId === 'paint') return '红衣黑彩';
  }
  // 正常保存会带选中部位的 label；这里只为缺少标签但仍有合法新视角的记录提供对应部位名称。
  if (pose.proceduralPreset === 'miaodigou_pottery' && pose.sceneRevision === 2) {
    if (pose.hotspotId === 'living') return '居住遗存';
    if (pose.hotspotId === 'kilns') return '西部陶窑';
    if (pose.hotspotId === 'ditches') return '东西壕沟';
  }
  if (pose.proceduralPreset === 'duling_fangding' && pose.sceneRevision === 2) {
    if (pose.hotspotId === 'centers') return '壁面正中';
    if (pose.hotspotId === 'corners') return '四个折角';
    if (pose.hotspotId === 'frame') return '乳钉边框';
  }
  if (pose.hotspotId === 'form') return '器形观察';
  if (pose.hotspotId === 'pattern') return '纹饰观察';
  if (pose.hotspotId === 'story') return '文化线索';
  if (pose.sceneType === 'relic_inspector') return '形态示意视角';
  if (pose.sceneType === 'stratum_slice') return '学习主题视角';
  if (pose.sceneType === 'river_sandbox') return '五城沙盘视角';
  if (pose.sceneType === 'constellation_graph') return '文明图谱视角';
  return '已记录视角';
}

export function isMemoryPostcard(note: ArchiveRecord): boolean {
  // 必须有用户显式保存的受支持手账元数据；仅打开遗址或旧普通 note 都不算手账打卡。
  return note.kind === 'note' && !note.deleted &&
    (STAMP_TYPES.includes(note.stampType || '') || PAPER_THEMES.includes(note.paperTheme || ''));
}

export function memoryQuoteForSite(site: HeritageSite): string {
  // 只摘录档案已有摘要，摘要空缺时才取概览；继承原文“初稿待校审”状态，不生成诗词或新事实。
  return (site.summary.trim() || site.overview.trim()).slice(0, 160);
}
