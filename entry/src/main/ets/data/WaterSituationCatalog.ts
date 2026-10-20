// 黄河水情观察 v1 的公开报道摘录。
//
// 为什么不是实时日报：
// 1. 黄委“黄河水情日报”页面在 2024 年改版后只能稳定取得当天表格，解析器会随页面变化；
//    把抓取放进 HAP 或答辩现场，网络与页面结构都可能让演示直接失败。
// 2. 本项目规定不得把未核实的数据写成实时，也不得伪造站点、数值或更新时间。
// 因此 v1 只收录三条可逐条打开、带日期与发布者的公开报道；缺测保持未给出，
// 不插值、不补 0、不画成连续七日趋势。服务端日报接口留到 v2，接口稳定后再接。
//
// 数值来源与边界：
// - 2026-08-12 09:42 花园口 89.65 m / 1960 m³/s：央广网报道引述站内大屏。
// - 2026-08-14 02:00 花园口 2040 m³/s：黄委通报该轮洪水最大流量，未给同日水位。
// - 2026-09-21 花园口 88.42 m / 607 m³/s：封面新闻报道引述站内数字系统，未给具体时刻。
// 三条报道的观测时刻与口径不完全一致，页面必须显示“非实时、非连续序列”。

import type { WaterSituationCatalog } from '../domain/WaterSituation';

export const WATER_SITUATION: WaterSituationCatalog = {
  updatedAt: '2026-10-20',
  stations: [
    {
      id: 'huayuankou',
      name: '花园口',
      river: '黄河',
      section: '下游 · 郑州北郊',
      whySourceId: 'cnr-20260813',
      why: [
        '黄河下游著名的“悬河”断面：大堤之内是河，堤外就是郑州。',
        '花园口水文站控制流域面积约 73 万平方公里。',
        '1938 年设立，是黄河下游防洪与水文报汛的关键站。'
      ]
    }
  ],
  snapshots: [
    {
      stationId: 'huayuankou',
      stationName: '花园口',
      river: '黄河',
      observedAt: '2026-08-12 09:42',
      waterLevelM: 89.65,
      flowM3s: 1960,
      sourceId: 'cnr-20260813',
      note: '台风“白海豚”外围降雨过程后，报道引述花园口水文站大屏。'
    },
    {
      stationId: 'huayuankou',
      stationName: '花园口',
      river: '黄河',
      observedAt: '2026-08-14 02:00',
      flowM3s: 2040,
      sourceId: 'yrcc-20260816',
      note: '黄委通报的该轮洪水花园口站最大流量；同日水位未在通报中给出。'
    },
    {
      stationId: 'huayuankou',
      stationName: '花园口',
      river: '黄河',
      observedAt: '2026-09-21',
      waterLevelM: 88.42,
      flowM3s: 607,
      sourceId: 'cover-20260921',
      note: '“人民治黄”80 年报道引述站内数字系统；报道未给出具体时刻。'
    }
  ],
  sources: [
    {
      id: 'cnr-20260813',
      publisher: '央广网',
      title: '守护花园口',
      url: 'https://www.cnr.cn/hnfw/gstjhn/20260813/t20260813_527760202.shtml',
      publishedAt: '2026-08-13',
      accessedAt: '2026-10-20'
    },
    {
      id: 'yrcc-20260816',
      publisher: '水利部黄河水利委员会',
      title: '黄河防总、黄委有力有效应对台风“白海豚”暴雨洪水',
      url: 'http://www.yrcc.gov.cn/xwdt/hhyw/202608/t20260816_453025.html',
      publishedAt: '2026-08-16',
      accessedAt: '2026-10-20'
    },
    {
      id: 'cover-20260921',
      publisher: '华西都市报·封面新闻',
      title: '“人民治黄”80年 如何解开黄河“水沙失衡”这道千古难题？',
      url: 'https://www.wccdaily.com.cn/shtml/hxdsb/20260921/252315.shtml',
      publishedAt: '2026-09-21',
      accessedAt: '2026-10-20'
    }
  ],
  disclaimer: '本页是公开报道摘录，非实时报汛，也不提供洪水预测或防灾指令；数值与表述以原发布为准。',
  readingNote: '水位是相对基面的读数，不同站、不同基面不可直接比较；流量是单位时间过水体积；含沙量表示单位体积水中的泥沙质量。本次三条报道均未给出含沙量。'
};
