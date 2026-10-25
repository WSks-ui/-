// 这里只给经营小样提供名称、资料与画面身份。价格、客流、库存、工资、通行与灯油
// 都由纯领域规则统一给出；不能在页面另造一套经营参数或把原创参数写成北宋史实。
export interface RiverMarketSource { title: string; url: string; quote: string; era: string; accessedAt: string; }

export const MARKET_ZONE_NAMES: string[] = ['西街', '中街', '东街'];
export const MARKET_STALL_NAMES: string[] = ['水饭铺', '肉食铺', '茶饮铺'];
export const MARKET_STALL_TYPES: string[] = ['rice', 'meat', 'tea'];
export const MARKET_RESOURCE_NAMES: string[] = ['米粮', '肉料', '茶料', '灯油'];
export const MARKET_RESOURCES: string[] = ['rice', 'meat', 'tea', 'oil'];
export const MARKET_SOURCE_QUOTE: string = '自州桥南去，当街水饭、爊肉、干脯。';
export const MARKET_SOURCES: RiverMarketSource[] = [
  { title: '《东京梦华录》卷二·州桥夜市',
    url: 'https://zh.wikisource.org/zh-hans/%E6%9D%B1%E4%BA%AC%E5%A4%A2%E8%8F%AF%E9%8C%84/%E5%8D%B7%E4%BA%8C',
    quote: MARKET_SOURCE_QUOTE, era: '孟元老南宋追记北宋东京生活', accessedAt: '2026-10-25' },
  { title: '《东京梦华录》卷三·马行街北诸医铺',
    url: 'https://zh.wikisource.org/zh-hans/%E6%9D%B1%E4%BA%AC%E5%A4%A2%E8%8F%AF%E9%8C%84/%E5%8D%B7%E4%B8%89',
    quote: '夜市直至三更尽，才五更又复开张。……至三更方有提瓶卖茶者。盖都人公私荣干，夜深方归也。',
    era: '北宋夜市、提瓶卖茶的文献记述', accessedAt: '2026-10-25' },
  { title: '《东京梦华录》卷三·天晓诸人入市',
    url: 'https://zh.wikisource.org/zh-hans/%E6%9D%B1%E4%BA%AC%E5%A4%A2%E8%8F%AF%E9%8C%84/%E5%8D%B7%E4%B8%89',
    quote: '酒店多点灯烛沽卖。', era: '北宋天晓入市的文献记述', accessedAt: '2026-10-25' },
  { title: '中国历史研究院·北宋东京城州桥重见天日',
    url: 'http://hrczh.cass.cn/ywdt/dt/202502/t20250228_5849988.shtml',
    quote: '资料摘要：州桥位于御街与汴河交叉处，考古揭露不同历史时期的桥、河道和两岸遗存。',
    era: '多期城市遗存的考古材料', accessedAt: '2026-10-25' }
];

export function marketStallName(type: string): string {
  const index = MARKET_STALL_TYPES.indexOf(type); return index >= 0 ? MARKET_STALL_NAMES[index] : '空地';
}

export function marketResourceName(resource: string): string {
  const index = MARKET_RESOURCES.indexOf(resource); return index >= 0 ? MARKET_RESOURCE_NAMES[index] : resource;
}

export function marketReasonName(reason: string): string {
  if (reason === 'served') return '吃上了';
  if (reason === 'stock') return '缺食材';
  if (reason === 'workers') return '缺伙计';
  if (reason === 'crowd') return '街口拥挤';
  if (reason === 'dark') return '街区未点灯';
  if (reason === 'missing') return '找不到想吃的铺子';
  return '离开';
}

export const MARKET_CULTURE_BOUNDARY: string =
  '州桥夜市与夜深提瓶卖茶的文献启发这段河岸生活。灯起、人盛、夜深、五更为四段压缩经营节奏，并非连续等时的四更。地图、客流、钱价、库存、伙计和灯油消耗是原创游戏参数；不是北宋街市、物价或时制的复原。';
