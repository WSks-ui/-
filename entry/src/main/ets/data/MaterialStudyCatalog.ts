// 本阶段只精做三个观察对象，完整目录与漫游路线仍使用既有稳定 ID。
// “已核对”仅覆盖下列事实对应的官方网页正文，不替代整个档案的人工校审。
export interface MaterialEvidenceSource {
  id: string;
  title: string;
  publisher: string;
  url: string;
  publishedAt: string;
  checkedAt: string;
}

export interface MaterialStudyFact {
  id: string;
  title: string;
  body: string;
  sourceIds: string[];
}

export interface MaterialStudy {
  siteId: string;
  question: string;
  discovery: string;
  facts: MaterialStudyFact[];
  sources: MaterialEvidenceSource[];
  illustration: string;
  visualCaption: string;
  visualLegend: string[];
  evidenceLimit: string;
}

const CHECKED_AT: string = '2026-10-17';

export const MATERIAL_STUDIES: MaterialStudy[] = [
  {
    siteId: 'smx-miaodigou',
    question: '陶窑和居住遗存分别在哪里？',
    discovery: '西部既有居住遗存，也是陶窑集中的方位。',
    facts: [
      { id: 'miaodigou-living', title: '居住区：中部与西部',
        body: '国家文物局的遗址介绍记载，居住区主要分布在遗址中部和西部。这里的“主要”保留了分布概述的范围。',
        sourceIds: ['ncha-miaodigou-2022'] },
      { id: 'miaodigou-kilns', title: '陶窑：集中于西部',
        body: '制作陶器的陶窑集中分布在遗址西部。居住遗存与陶窑都涉及西部，不能把它们画成互不重叠的两个功能区。',
        sourceIds: ['ncha-miaodigou-2022'] },
      { id: 'miaodigou-ditches', title: '壕沟：东西两侧都有',
        body: '遗址的东西两面都有壕沟。现有概述支持两侧的方位关系，没有给出可用于本图的精确壕沟轮廓。',
        sourceIds: ['ncha-miaodigou-2022'] }
    ],
    sources: [
      { id: 'ncha-miaodigou-2022', title: '河南三门峡庙底沟遗址', publisher: '国家文物局',
        url: 'http://www.ncha.gov.cn/art/2022/3/19/art_2587_75.html', publishedAt: '2022-03-19', checkedAt: CHECKED_AT },
      { id: 'henan-miaodigou-2023', title: '走进庙底沟遗址 探寻“早期中国”', publisher: '河南省文物局',
        url: 'https://wwj.henan.gov.cn/2023/07-20/2781482.html', publishedAt: '2023-07-19', checkedAt: CHECKED_AT }
    ],
    illustration: 'study_miaodigou_space.svg',
    visualCaption: '依据官方概述绘制 · 方位关系示意 · 非实测平面',
    visualLegend: ['左为西，中为遗址中部，右为东', '淡绿带与玫瑰点：居住遗存的大致分布', '陶色圆环：陶窑；两侧虚线：壕沟'],
    evidenceLimit: '符号数量、距离和带状范围没有测绘含义。这些分布不能证明生产组织、人群迁徙或技术传播方向。'
  },
  {
    siteId: 'zz-dahecun',
    question: '两只并排的壶，怎样成为一件内部相通的器物？',
    discovery: '连接不只在外形上：腹部接合处有椭圆形通口。',
    facts: [
      { id: 'dahecun-object', title: '从遗址走到一件具体器物',
        body: '这件彩陶双连壶于1972年在郑州大河村遗址出土，现藏河南博物院。馆方将其定为新石器时代仰韶文化文物，记录高20.1厘米。',
        sourceIds: ['museum-dahecun-twin-2020', 'henan-dahecun-twin-2024'] },
      { id: 'dahecun-opening', title: '相通的地方在腹部',
        body: '两只陶壶并列连接，腹部接合处留有一个椭圆形通口，使两壶内部相通。示意中的浅绿色通道表达这一内部关系。',
        sourceIds: ['museum-dahecun-twin-2020'] },
      { id: 'dahecun-lines', title: '红衣之上，黑彩有变化',
        body: '器物为泥质红陶，采用红衣黑彩。腹部平行横线之间穿插竖向与斜向短线，重复的纹带中有不同方向的线条。',
        sourceIds: ['museum-dahecun-twin-2020', 'henan-dahecun-twin-2024'] }
    ],
    sources: [
      { id: 'museum-dahecun-twin-2020', title: '彩陶双连壶', publisher: '河南博物院',
        url: 'https://www.chnmus.net/sitesources/hnsbwy/page_pc/bwzl/yyhxzzjd/cpsx/article02dad096e98349b19ed9feaa402f6667.html',
        publishedAt: '2020-11-16', checkedAt: CHECKED_AT },
      { id: 'henan-dahecun-twin-2024', title: '豫博里的中国丨古代先民的“外交酒具”', publisher: '河南省人民政府（转刊河南日报）',
        url: 'https://www.henan.gov.cn/2024/11-06/3082451.html', publishedAt: '2024-11-06', checkedAt: CHECKED_AT }
    ],
    illustration: 'study_dahecun_twin.svg',
    visualCaption: '云河纪原创结构分析 · 红衣黑彩与腹部通口示意 · 非实物复原',
    visualLegend: ['两只壶并列，分别有自己的壶口', '浅绿色区域：腹部内部连通关系', '黑色横带与短线：纹线类型，非原纹样摹本'],
    evidenceLimit: '通口、纹线与比例均经简化。此件是红衣黑彩，不等于大河村全部彩陶；结构相通也不能证明某种礼仪或具体历史事件。'
  },
  {
    siteId: 'zz-duling-fangding',
    question: '四面方鼎，为什么有八组上腹兽面纹？',
    discovery: '四面正中各一组，四个折角处又各一组。',
    facts: [
      { id: 'duling-object', title: '先认清二号鼎',
        body: '杜岭二号方鼎是商代前期青铜礼器，1974年9月出土于郑州张寨南街青铜器窖藏坑，现藏河南博物院。',
        sourceIds: ['museum-duling-two'] },
      { id: 'duling-size', title: '同坑两件中的较小一件',
        body: '二号鼎通高87厘米，口沿边长61厘米，重约64.25千克。同坑出土的两件方鼎中，它是尺寸较小的一件。',
        sourceIds: ['museum-duling-two'] },
      { id: 'duling-eight', title: '四面正中，加上四个折角',
        body: '上腹兽面纹环绕一周：每壁正中一组，每个折角处再各一组，合计八组。两侧边与腹部近底端的乳钉纹带另成边框。',
        sourceIds: ['museum-duling-two'] }
    ],
    sources: [
      { id: 'museum-duling-two', title: '杜岭二号方鼎', publisher: '河南博物院',
        url: 'https://www.chnmus.net/ch/collection/appraise/details.html?id=512159052412506512',
        publishedAt: '未标日期', checkedAt: CHECKED_AT }
    ],
    illustration: 'study_duling_pattern.svg',
    visualCaption: '云河纪原创结构分析 · 八组纹饰位置关系 · 非测绘复原',
    visualLegend: ['左：方腹、双立耳与四柱足的简化轮廓', '右：玫瑰标记为四面正中，陶色折线为四个折角', '八组仅指上腹兽面纹，足部纹饰不计入'],
    evidenceLimit: '图中没有摹画真实兽面纹或精确乳钉数量。馆方页面还包含一号鼎的比较图，不能把一号鼎的形制数据移用于本件。'
  }
];

export function materialStudyForId(siteId: string): MaterialStudy | undefined {
  return MATERIAL_STUDIES.find((study: MaterialStudy) => study.siteId === siteId);
}

export interface MaterialComparisonDimension {
  id: string;
  title: string;
  left: string;
  right: string;
  leftSourceIds: string[];
  rightSourceIds: string[];
  limit: string;
}

export interface MaterialComparison {
  id: string;
  title: string;
  leftSiteId: string;
  leftObject: string;
  rightSiteId: string;
  rightObject: string;
  dimensions: MaterialComparisonDimension[];
}

// 对照先锁定两个具体对象及逐维度依据，后续 T06 读取同一份内容，不从共同标签生成结论。
export const MATERIAL_COMPARISON: MaterialComparison = {
  id: 'twin-vessel-and-square-ding',
  title: '结构怎样参与器表的组织？',
  leftSiteId: 'zz-dahecun', leftObject: '大河村彩陶双连壶',
  rightSiteId: 'zz-duling-fangding', rightObject: '杜岭二号方鼎',
  dimensions: [
    { id: 'body', title: '口与腹的结构',
      left: '两个壶体并列，分别开口；腹部接合处有椭圆形通口，内部相通。',
      right: '口、腹截面基本为正方形，方腹上有立耳，下承四根柱形足。',
      leftSourceIds: ['museum-dahecun-twin-2020'], rightSourceIds: ['museum-duling-two'],
      limit: '可以比较连接和承托方式；不能仅凭容器外形断定两者用途相同。' },
    { id: 'surface', title: '纹饰位于哪里',
      left: '红衣上用黑彩绘出平行横线，并在其间安排竖向、斜向短线。',
      right: '上腹以凸起阳线构成兽面纹，四壁正中和四处折角各一组；乳钉纹带沿两侧与近底端分布。',
      leftSourceIds: ['museum-dahecun-twin-2020', 'henan-dahecun-twin-2024'], rightSourceIds: ['museum-duling-two'],
      limit: '可以比较绘彩与凸起纹饰的位置组织；纹样差异不能直接说明技术优劣、工艺演化或传播关系。' },
    { id: 'context', title: '各自的出土记录',
      left: '新石器时代仰韶文化彩陶，1972年出土于郑州大河村遗址，现藏河南博物院。',
      right: '商代前期青铜礼器，1974年9月出土于郑州张寨南街青铜器窖藏坑，现藏河南博物院。',
      leftSourceIds: ['museum-dahecun-twin-2020', 'henan-dahecun-twin-2024'], rightSourceIds: ['museum-duling-two'],
      limit: '发现年份不是器物制作年代；同属郑州出土文物，不足以证明同一人群、连续传承或文化传播方向。' }
  ]
};
