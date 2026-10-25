// 五城漫游自己的叙事色板。青绿代表河流与阅读层次，朱砂只用于主动操作和印记；
// 这里的纸张、线条都是普通绘制，不承担系统沉浸材质或考古复原的含义。
//
// 2026-10-23 设计样板轮补充了“层次”令牌：河卷图景需要比页面更深的墨色才立得起来，
// 原先只有单一 paper/page 两个亮色，导致画面与背景同为浅黄绿、对比不足。
// 旧令牌名保持不变，避免 RoamingHome/RoamingChapterPage 之外的调用点一起失效；
// 新增令牌只服务于图景与笺纸，不改变旧档案页通过 ArchiveTheme 取色的规则。
export class RoamingTheme {
  // —— 纸与墨：页面暖纸、抬起的纸页、次级墨色 ——
  static paper: string = '#F5F0E4';
  static page: string = '#FCF8ED';
  static paperDeep: string = '#E8DFCB';
  static paperHigh: string = '#FFFCF3';
  static ink: string = '#20382F';
  static inkSoft: string = '#41594E';
  static muted: string = '#66735F';
  static faint: string = '#8A9382';
  // —— 河流与青绿：主行动色与图景水面 ——
  static river: string = '#1F5D50';
  static riverDeep: string = '#164A40';
  static jade: string = '#3C7E6B';
  static paleJade: string = '#DCE6D4';
  static washJade: string = '#E7EBD9';
  // —— 分隔与描边 ——
  static line: string = '#D3D3BB';
  static lineSoft: string = '#E3DFC8';
  // —— 朱砂、金色、夜色 ——
  static cinnabar: string = '#A64C37';
  static cinnabarDeep: string = '#8C3B29';
  static paleCinnabar: string = '#F3E2D1';
  static gold: string = '#B08B45';
  static goldPale: string = '#DCC58A';
  static midnight: string = '#12302E';
  static nightSky: string = '#173B39';
  static nightInk: string = '#0B2422';
  static lantern: string = '#D9A65A';
  // —— 图景专用的中间色，避免山脉与水面同值 ——
  static ridgeFar: string = '#C6D2B4';
  static ridgeMid: string = '#9DB394';
  static ridgeNear: string = '#6E8E74';
  static bankSand: string = '#D9CEA6';
  // —— 统一圆角与间距，减少各页面随手写的数值 ——
  static radiusPage: number = 6;
  static radiusPanel: number = 10;
  static radiusChip: number = 4;
  static gutter: number = 20;
  static sectionGap: number = 18;
}
