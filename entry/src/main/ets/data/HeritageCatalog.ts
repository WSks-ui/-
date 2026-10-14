import type { HeritageSite } from '../domain/ArchiveDomain';

// 首轮仅提供五城最小内容集，reviewStatus 不能在未经逐条校审时改为“已核验”。
// source 为官方机构入口，不冒充已核验的具体文章；正式交付前需替换为条目级出处和授权图片。
export const HERITAGE_SITES: HeritageSite[] = [
  {
    id: 'smx-yangshao', name: '仰韶村遗址', city: '三门峡', era: '仰韶', type: '聚落遗址',
    tags: ['彩陶', '聚落', '考古'],
    summary: '从彩陶与聚落遗存，认识黄河流域早期生活的印记。',
    overview: '仰韶村遗址位于河南渑池，是仰韶文化命名地。本档案以聚落、陶器与考古研究为线索，作为黄河文化探索的起点。',
    archaeology: '观察陶器的器形、纹饰与用途，可以提出有关生产和日常生活的问题。具体出土器物、发掘分期及图片将在内容校审后补充。',
    history: '仰韶村的考古发掘与中国现代考古学的发展密切相关。完整发掘年表尚待引用权威出版资料补齐。',
    poetry: '暂未收录能够明确对应本遗址的诗词，不以泛写黄河的作品替代遗址证据。',
    travel: '地点索引：三门峡市渑池县。开放时间、预约方式和现场通行信息尚未核验，请以管理机构当日公告为准。',
    source: { title: '河南省文物局（待补条目级来源）', url: 'https://wwj.henan.gov.cn/' },
    reviewStatus: '初稿待校审', illustration: 'motif_pottery.svg', accent: '#9B463E'
  },
  {
    id: 'ly-erlitou', name: '二里头遗址', city: '洛阳', era: '夏商', type: '都城遗址',
    tags: ['都城', '青铜', '考古'],
    summary: '沿着宫殿区、道路与手工业遗存，寻找早期城市的结构。',
    overview: '二里头遗址位于河南偃师，是研究早期国家与文明发展的重要考古遗址。档案将城市空间与器物研究并列呈现。',
    archaeology: '宫殿建筑基址、道路和手工业遗存构成重要观察线索。具体器物信息与分期结论需要逐项引用考古资料。',
    history: '“夏商”是本应用的检索分组，不表示将二里头遗址的王朝归属定为没有争议的结论。',
    poetry: '暂未收录可与本遗址直接对应的诗词。',
    travel: '地点索引：洛阳市偃师区。遗址与博物馆的参观安排应分别核验，预约及开放信息以官方公告为准。',
    source: { title: '河南省文物局（待补条目级来源）', url: 'https://wwj.henan.gov.cn/' },
    reviewStatus: '初稿待校审', illustration: 'motif_city.svg', accent: '#247568'
  },
  {
    id: 'zz-shang', name: '郑州商城遗址', city: '郑州', era: '夏商', type: '都城遗址',
    tags: ['都城', '青铜', '城墙'],
    summary: '在现代城市中，辨认商代城垣与都城生活留下的线索。',
    overview: '郑州商城遗址是研究商代城市的重要遗址。现存城垣和考古发现提供了理解城市布局的线索。',
    archaeology: '可从城垣、建筑遗存与手工业生产三个方向阅读。测量数据、出土器物和年代分期尚待引用正式资料。',
    history: '以“古城与现代城市共存”为观察主题，比较文物保护、城市空间和公众参观之间的关系。',
    poetry: '暂未收录可与本遗址直接对应的诗词。',
    travel: '地点索引：郑州市。遗址不同区域的开放与展陈情况应分别核验，勿将城市公园开放等同于考古区域可进入。',
    source: { title: '河南省文物局（待补条目级来源）', url: 'https://wwj.henan.gov.cn/' },
    reviewStatus: '初稿待校审', illustration: 'motif_city.svg', accent: '#426F93'
  },
  {
    id: 'kf-iron-pagoda', name: '开封铁塔', city: '开封', era: '宋', type: '古建筑',
    tags: ['建筑', '琉璃', '城市'],
    summary: '从琉璃构件与建筑轮廓，观察宋代建筑的材料与工艺。',
    overview: '开封铁塔是一处以琉璃砖构筑的古塔。“铁塔”是其通称，不表示塔身由铁铸成。',
    archaeology: '此条目属于古建筑观察，可关注琉璃构件、装饰题材与保护记录。构件细目和测绘数据尚待官方资料补充。',
    history: '档案将以宋代建筑与开封城市文化为研究线索，不把未经核验的传说当作历史事件。',
    poetry: '相关诗文将在确认作者、篇名、版本及对应对象后收录。',
    travel: '地点索引：开封市。门票、开放时间和可参观范围尚未核验，以景区及管理部门公告为准。',
    source: { title: '河南省文物局（待补条目级来源）', url: 'https://wwj.henan.gov.cn/' },
    reviewStatus: '初稿待校审', illustration: 'motif_pagoda.svg', accent: '#776293'
  },
  {
    id: 'py-qicheng', name: '戚城遗址', city: '濮阳', era: '周', type: '城址',
    tags: ['城墙', '城市', '考古'],
    summary: '由城址出发，理解春秋时期的地域交往与城市记忆。',
    overview: '戚城遗址位于河南濮阳。本条目以古城遗存与春秋历史为探索线索。',
    archaeology: '观察重点包括城址形态、遗存保护和考古资料。具体地层、年代跨度及出土器物需在第二轮逐项核验。',
    history: '“周”为初始检索分组，不代表遗址只有这一时期的遗存。古城遗址不应直接等同于王朝都城。',
    poetry: '暂未收录可与本遗址直接对应的诗词。',
    travel: '地点索引：濮阳市。公园、展陈和遗址本体的参观范围需要区分，开放信息以官方公告为准。',
    source: { title: '河南省文物局（待补条目级来源）', url: 'https://wwj.henan.gov.cn/' },
    reviewStatus: '初稿待校审', illustration: 'motif_city.svg', accent: '#677448'
  }
];
