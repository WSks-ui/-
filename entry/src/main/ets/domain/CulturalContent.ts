// 内容扩展元数据与 ArchiveDomain 的收藏/笔记信封分离，避免为了视口展示改动 schema v1。
// proceduralPreset 是程序化几何示意的选择键，不代表文物复原、实测形制或考古结论。
export type ProceduralPreset =
  | 'yangshao_pottery'
  | 'miaodigou_pottery'
  | 'guoguo_tomb'
  | 'erlitou_palace'
  | 'yanshi_city'
  | 'hanwei_city'
  | 'longmen_cliff'
  | 'zhengzhou_wall'
  | 'dahecun_pottery'
  | 'zhenghan_city'
  | 'duling_fangding'
  | 'kaifeng_pagoda'
  | 'fanta_pagoda'
  | 'zhouqiao_bridge'
  | 'kaifeng_city_wall'
  | 'qicheng_site'
  | 'xishuipo_site'
  | 'xipo_settlement'
  | 'cangjie_memorial'
  | 'dangui_memorial'
  | 'generic_site_study';

export type ExplorationSectionId = 'overview' | 'archaeology' | 'history' | 'poetry-travel';

export type CulturalSourceField = 'overview' | 'archaeology' | 'history' | 'poetry' | 'travel';

export interface CulturalLearningSection {
  id: ExplorationSectionId;
  title: string;
  sourceFields: CulturalSourceField[];
  percent: 25;
  // 仅说明该学习主题如何组成阅读进度；绝不能当成真实遗址地层或固定年代序列。
  isArchaeologicalStratum: false;
}

export interface CulturalSiteMetadata {
  siteId: string;
  proceduralPreset: ProceduralPreset;
  // 只供五城由西向东的展示排序使用，不是条目地理坐标或遗址事实。
  cityOrder: number;
  // 对应内容的学习切入点；不声明该处必有相同的遗存或考古分层。
  learningTheme: string;
}

export const CULTURAL_CITY_ORDER: string[] = ['三门峡', '洛阳', '郑州', '开封', '濮阳'];

// 四个主题映射到现有的五段文字。poetry 与 travel 合并成最后一段；每段 25% 是阅读完成度，
// 不是按打开详情或展示动画自动增加。这里的“切片”只是学习导航，不是对全体遗址叠压关系的断言。
export const EXPLORATION_SECTIONS: CulturalLearningSection[] = [
  { id: 'overview', title: '概览', sourceFields: ['overview'], percent: 25, isArchaeologicalStratum: false },
  { id: 'archaeology', title: '遗存观察', sourceFields: ['archaeology'], percent: 25, isArchaeologicalStratum: false },
  { id: 'history', title: '历史线索', sourceFields: ['history'], percent: 25, isArchaeologicalStratum: false },
  { id: 'poetry-travel', title: '诗词与今访', sourceFields: ['poetry', 'travel'], percent: 25, isArchaeologicalStratum: false }
];

// 每个稳定档案 ID 都有一个独立扩展项；新视口能力应先查此表，未知 ID 保持无预设，不猜默认模型。
export const CULTURAL_SITE_METADATA: Record<string, CulturalSiteMetadata> = {
  'smx-yangshao': { siteId: 'smx-yangshao', proceduralPreset: 'yangshao_pottery', cityOrder: 0, learningTheme: '聚落与陶器观察' },
  'ly-erlitou': { siteId: 'ly-erlitou', proceduralPreset: 'erlitou_palace', cityOrder: 1, learningTheme: '都城空间阅读' },
  'zz-shang': { siteId: 'zz-shang', proceduralPreset: 'zhengzhou_wall', cityOrder: 2, learningTheme: '城垣与城市空间' },
  'kf-iron-pagoda': { siteId: 'kf-iron-pagoda', proceduralPreset: 'kaifeng_pagoda', cityOrder: 3, learningTheme: '塔建筑形态观察' },
  'py-qicheng': { siteId: 'py-qicheng', proceduralPreset: 'qicheng_site', cityOrder: 4, learningTheme: '城址与地域记忆' },
  'smx-miaodigou': { siteId: 'smx-miaodigou', proceduralPreset: 'miaodigou_pottery', cityOrder: 0, learningTheme: '聚落与陶器观察' },
  'smx-guoguo': { siteId: 'smx-guoguo', proceduralPreset: 'guoguo_tomb', cityOrder: 0, learningTheme: '墓葬与器物观察' },
  'ly-yanshi-shang': { siteId: 'ly-yanshi-shang', proceduralPreset: 'yanshi_city', cityOrder: 1, learningTheme: '都城空间阅读' },
  'ly-hanwei': { siteId: 'ly-hanwei', proceduralPreset: 'hanwei_city', cityOrder: 1, learningTheme: '都城空间阅读' },
  'ly-longmen': { siteId: 'ly-longmen', proceduralPreset: 'longmen_cliff', cityOrder: 1, learningTheme: '石窟与保护观察' },
  'zz-dahecun': { siteId: 'zz-dahecun', proceduralPreset: 'dahecun_pottery', cityOrder: 2, learningTheme: '聚落与陶器观察' },
  'zz-zhenghan': { siteId: 'zz-zhenghan', proceduralPreset: 'zhenghan_city', cityOrder: 2, learningTheme: '城址与地域记忆' },
  'kf-fanta': { siteId: 'kf-fanta', proceduralPreset: 'fanta_pagoda', cityOrder: 3, learningTheme: '塔建筑形态观察' },
  'kf-zhouqiao': { siteId: 'kf-zhouqiao', proceduralPreset: 'zhouqiao_bridge', cityOrder: 3, learningTheme: '桥梁、水系与城市空间' },
  'py-xishuipo': { siteId: 'py-xishuipo', proceduralPreset: 'xishuipo_site', cityOrder: 4, learningTheme: '聚落与墓葬遗存观察' },
  'smx-xipo': { siteId: 'smx-xipo', proceduralPreset: 'xipo_settlement', cityOrder: 0, learningTheme: '聚落与空间观察' },
  'zz-duling-fangding': { siteId: 'zz-duling-fangding', proceduralPreset: 'duling_fangding', cityOrder: 2, learningTheme: '青铜器形制与纹饰观察' },
  'kf-city-wall': { siteId: 'kf-city-wall', proceduralPreset: 'kaifeng_city_wall', cityOrder: 3, learningTheme: '城墙与城市空间' },
  'py-cangjie': { siteId: 'py-cangjie', proceduralPreset: 'cangjie_memorial', cityOrder: 4, learningTheme: '地方传说与纪念空间' },
  'py-danguai': { siteId: 'py-danguai', proceduralPreset: 'dangui_memorial', cityOrder: 4, learningTheme: '近现代历史记忆' },
  // 两处暂共用抽象资料卡，不借用其他遗址形制。以后升级独立场景时须扩展回放解析，
  // 继续识别已保存的 generic_site_study / revision 1，不得用新模型覆盖旧手账画面。
  'zz-wangchenggang': { siteId: 'zz-wangchenggang', proceduralPreset: 'generic_site_study', cityOrder: 2, learningTheme: '龙山城址资料阅读' },
  'zz-huangye-kiln': { siteId: 'zz-huangye-kiln', proceduralPreset: 'generic_site_study', cityOrder: 2, learningTheme: '窑业遗存资料阅读' }
};

export function getCulturalSiteMetadata(siteId: string): CulturalSiteMetadata | undefined {
  return CULTURAL_SITE_METADATA[siteId];
}
