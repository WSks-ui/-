import type { ArchiveRecord, HeritageSite } from '../domain/ArchiveDomain';
import type { MarketMemorySource } from '../domain/MarketMemory';

export interface MarketCultureEntry {
  id: string;
  nightId: string;
  title: string;
  subtitle: string;
  city: string;
  era: string;
  type: string;
  tags: string[];
  revision: number;
  quote: string;
  body: string;
  question: string;
  gameConnection: string;
  relatedSiteId: string;
  source: MarketMemorySource;
}

export interface MarketCultureRecommendation {
  entry: MarketCultureEntry;
  reason: string;
  score: number;
}

export const MARKET_CULTURE_ERA: string = '孟元老南宋追记北宋';
export const MARKET_CULTURE_TYPE: string = '城市生活文献';
export const MARKET_CULTURE_BOUNDARY: string =
  '资料初稿待校审。《东京梦华录》由孟元老在南宋追记北宋都城生活，电子转录不等于考古证据。三夜的地图、客流、钱价、灯棚、人手与巡茶规则为原创游戏编排。';

// 2026-10-26 实际读取维基文库简体转录的卷二、三、六并逐句核对。稳定文化 ID
// 独立于原22处遗址，也独立于经营progress；将来校审只递增revision，不改已存记忆。
export const MARKET_CULTURES: MarketCultureEntry[] = [
  {
    id: 'culture-kf-night-market', nightId: 'night-1', title: '州桥南去，夜市初开',
    subtitle: '一条街上的水饭、肉食与往来人群', city: '开封', era: MARKET_CULTURE_ERA,
    type: MARKET_CULTURE_TYPE, tags: ['开封', '夜市', '饮食', '东京梦华录'], revision: 1,
    quote: '自州桥南去，当街水饭、爊肉、干脯。',
    body: '《东京梦华录》卷二“州桥夜市”用一连串食物名称勾勒街上饮食。“水饭”“爊肉”“干脯”并列，让人看到夜间街市服务的具体日常。这里保留原句，不把当代菜名、经营价格或单一摊位位置补成原文结论。',
    question: '同一条街上的人都想吃一样的东西吗？你会怎样安排几间铺子？',
    gameConnection: '第一夜把饮食种类转成铺位和人手的取舍。六处铺位、各类需求、价格与拥挤阈值均为原创数值，不是州桥街市复原。',
    relatedSiteId: 'kf-zhouqiao',
    source: { id: 'meng-v2-zhouqiao-night-market', title: '孟元老《东京梦华录》卷二·州桥夜市',
      url: 'https://zh.wikisource.org/zh-hans/東京夢華錄/卷二',
      quote: '自州桥南去，当街水饭、爊肉、干脯。', accessedAt: '2026-10-26', era: MARKET_CULTURE_ERA }
  },
  {
    id: 'culture-kf-bottle-tea', nightId: 'night-2', title: '三更以后，提瓶卖茶',
    subtitle: '夜深归来的人，和仍在路上的茶', city: '开封', era: MARKET_CULTURE_ERA,
    type: MARKET_CULTURE_TYPE, tags: ['开封', '夜市', '茶', '东京梦华录'], revision: 1,
    quote: '至三更方有提瓶卖茶者。盖都人公私荣干，夜深方归也。',
    body: '卷三“马行街北诸医铺”写到夜市与夜归人，随后提到三更卖茶。原文把卖茶与“夜深方归”的生活节奏相连，并没有给出一张固定茶摊地图。今天读这一句，可以把视线从铺面移向仍在行走的人。',
    question: '夜深的人从哪里来？固定茶铺和沿街送茶，会照顾到不同的人吗？',
    gameConnection: '第二夜的巡茶路线借“提瓶卖茶”启发移动服务的选择。巡茶区、伙计速度、茶量与批次均为原创游戏规则，不能据此推断北宋服务制度。',
    relatedSiteId: 'kf-zhouqiao',
    source: { id: 'meng-v3-bottle-tea', title: '孟元老《东京梦华录》卷三·马行街北诸医铺',
      url: 'https://zh.wikisource.org/zh-hans/東京夢華錄/卷三',
      quote: '至三更方有提瓶卖茶者。盖都人公私荣干，夜深方归也。', accessedAt: '2026-10-26', era: MARKET_CULTURE_ERA }
  },
  {
    id: 'culture-kf-lantern-festival', nightId: 'night-3', title: '御街灯起，游人已集',
    subtitle: '从御街两廊，到坊巷中的新奇灯烛', city: '开封', era: MARKET_CULTURE_ERA,
    type: MARKET_CULTURE_TYPE, tags: ['开封', '元宵', '灯火', '东京梦华录'], revision: 1,
    quote: '游人已集御街两廊下。\n诸坊巷、马行，诸香药铺席、茶坊酒肆，灯烛各出新奇。',
    body: '卷六“元宵”先写宣德楼前山棚与御街两廊的游人，又写坊巷、铺席、茶坊酒肆各出新奇的灯烛。两个片段展示节日活动在不同空间展开。这里合列两处短引，保留句间省略，不把它们拼成一段连续原文。',
    question: '人们会只聚在一处看灯吗？怎样让观灯和日常通行都能继续？',
    gameConnection: '第三夜将灯棚吸引与街区通行组织成取舍。灯棚位置、接待目标和资源消耗是原创编排，图景没有复原原文的山棚形制或宣德楼。',
    relatedSiteId: 'kf-zhouqiao',
    source: { id: 'meng-v6-lantern-festival', title: '孟元老《东京梦华录》卷六·元宵',
      url: 'https://zh.wikisource.org/zh-hans/東京夢華錄/卷六',
      quote: '游人已集御街两廊下。\n（另一处短引）诸坊巷、马行，诸香药铺席、茶坊酒肆，灯烛各出新奇。',
      accessedAt: '2026-10-26', era: MARKET_CULTURE_ERA }
  }
];

export function marketCultureForId(id: string): MarketCultureEntry | undefined {
  return MARKET_CULTURES.find((entry: MarketCultureEntry): boolean => entry.id === id);
}

export function marketCultureForNight(nightId: string): MarketCultureEntry | undefined {
  return MARKET_CULTURES.find((entry: MarketCultureEntry): boolean => entry.nightId === nightId);
}

export function cultureIdForNight(nightId: string): string {
  return marketCultureForNight(nightId)?.id || '';
}

// 供既有全文检索、收藏与写一页入口读取的适配表；不加入HERITAGE_SITES，
// 因而遗址统计继续保持22处，三条生活文献单独计数。
export const MARKET_CULTURE_ENTRIES: HeritageSite[] = MARKET_CULTURES.map((entry: MarketCultureEntry): HeritageSite => ({
  id: entry.id, name: entry.title, city: entry.city, era: entry.era, type: entry.type, tags: entry.tags.slice(),
  summary: entry.subtitle, overview: entry.body, archaeology: '', history: entry.gameConnection,
  poetry: entry.quote, travel: '', source: { title: entry.source.title, url: entry.source.url },
  reviewStatus: '初稿待校审', illustration: 'motif_city.svg', accent: '#BF9D5C', photos: []
}));

// 推荐只使用真实阅读opened、收藏和用户note标签。经营完成/客流/金币从不算读过资料，
// 没有个人锚点时按目录提供下一篇，不伪造“你喜欢”或阅读历史。
export function recommendMarketCultures(records: ArchiveRecord[], currentId: string = ''): MarketCultureRecommendation[] {
  const live = records.filter((record: ArchiveRecord): boolean => !record.deleted);
  const favorites = live.filter((record: ArchiveRecord): boolean => record.kind === 'favorite');
  const opened = live.filter((record: ArchiveRecord): boolean => record.kind === 'progress' &&
    record.body === 'opened' && record.id === `progress:${record.siteId}`);
  const notes = live.filter((record: ArchiveRecord): boolean => record.kind === 'note');
  const anchors = MARKET_CULTURES.filter((entry: MarketCultureEntry): boolean =>
    entry.id === currentId || favorites.some((record: ArchiveRecord): boolean => record.siteId === entry.id) ||
    opened.some((record: ArchiveRecord): boolean => record.siteId === entry.id));
  return MARKET_CULTURES.filter((entry: MarketCultureEntry): boolean => entry.id !== currentId)
    .map((entry: MarketCultureEntry): MarketCultureRecommendation => {
      let score = 0;
      let reason = '三夜文献，按目录接着读';
      if (notes.some((note: ArchiveRecord): boolean => note.tags.some((tag: string): boolean => entry.tags.includes(tag)))) {
        score = 3; reason = '与你手账中留下的标签相连';
      }
      const favorite = anchors.find((anchor: MarketCultureEntry): boolean =>
        favorites.some((record: ArchiveRecord): boolean => record.siteId === anchor.id) &&
        anchor.tags.some((tag: string): boolean => tag !== '开封' && tag !== '东京梦华录' && entry.tags.includes(tag)));
      if (favorite) { score = 5; reason = `与你收藏的《${favorite.title}》同有夜市线索`; }
      else if (anchors.some((anchor: MarketCultureEntry): boolean => opened.some((record: ArchiveRecord): boolean =>
        record.siteId === anchor.id))) { score = Math.max(score, 2); if (score === 2) reason = '从你读过的三夜材料继续'; }
      return { entry, reason, score };
    }).sort((a: MarketCultureRecommendation, b: MarketCultureRecommendation): number => b.score - a.score);
}
