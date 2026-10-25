// 开封“叠城寻路”的玩法规则。这里只放可判定的结构关系，不画图、不读存储、不依赖 @kit。
//
// 为什么单独成模块：旧篇章页把所有状态塞进一个 amount（0~100）阈值，
// “动过没有”被当成“关系成立”。本模块把“桥落在哪里、朝哪个方向”变成真实输入，
// 由两端落点、是否跨水、是否堵住航道分别判定，供关卡组件直接调用、可用 Node 直接回归。
//
// 边界：所有长度、容差、吸附阈值都是玩法参数，不是历史桥梁尺度或水工结论；
// 画面与判定都属原创叙事示意，不表示对州桥形制或汴河断面的复原。

// 画幅改为竖幅：开封这一关整屏铺满，画面本身就是操作台，不嵌在滚动页的一小块里。
// 1000×2000 在手机上按宽度铺开约 359×718vp，接近整屏，横向不再留空。
export const KAIFENG_BOARD_WIDTH: number = 1000;
export const KAIFENG_BOARD_HEIGHT: number = 2000;

// 汴河：横贯画面的水域，放在竖幅中部偏上，上下都留出街与城的余地。
export const KAIFENG_RIVER_TOP: number = 880;
export const KAIFENG_RIVER_BOTTOM: number = 1180;
export const KAIFENG_RIVER_MIDDLE: number = 1030;

// 御街：南北向的街道，被河切断。桥的作用是把这两段接起来。
export const KAIFENG_STREET_X: number = 500;
export const KAIFENG_STREET_HALF: number = 34;

// 桥片尺寸。固定长度让“跨不跨得过去”成为结构判断，而不是拉长缩短的数值调参。
export const KAIFENG_BRIDGE_HALF: number = 210;
// 桥面宽度只影响可读性与触控，不参与连接判定。
export const KAIFENG_BRIDGE_WIDTH: number = 64;

// 落岸判定：端点要落在街口这一小段岸线上，才算真正接上街路。
const LANDING_NORTH_MIN: number = 740;
const LANDING_NORTH_MAX: number = 878;
const LANDING_SOUTH_MIN: number = 1182;
const LANDING_SOUTH_MAX: number = 1320;
// 横向容差：桥端离街心多近算“对上了街口”。比街宽略宽，照顾单指拖动的抖动。
const LANDING_TOLERANCE: number = 34;

// 吸附与夹取：让单指能稳定摆正，又不至于自动替玩家解谜。
const ANGLE_SNAP_STEP: number = 15;
const ANGLE_SNAP_NEAR: number = 7;
const ANGLE_STRONG_SNAP: number = 12;
const POSITION_SNAP: number = 46;

export interface KaifengPoint {
  x: number;
  y: number;
}

export interface KaifengBridgeState {
  x: number;
  y: number;
  // 角度单位为度：0 表示顺河平放，90 表示横跨水面。只取 0~180。
  angle: number;
}

export interface KaifengJudge {
  northEnd: KaifengPoint;
  southEnd: KaifengPoint;
  // 两端分别落在北岸街口、南岸街口。
  northLanded: boolean;
  southLanded: boolean;
  // 桥身跨过水面（两端分处河两岸）。
  spansRiver: boolean;
  // 桥横躺在水里，挡住航道。
  lyingInWater: boolean;
  streetOpen: boolean;
  waterOpen: boolean;
  solved: boolean;
  // 具体断点，供画面把“人停在哪、船停在哪”画出来，而不是只弹一句红字。
  personStop: KaifengPoint | undefined;
  boatStop: KaifengPoint | undefined;
  verdict: string;
  message: string;
}

export interface KaifengHint {
  level: number;
  text: string;
  // 逐级提示要落在画面上：先指出街，再指出交会处，最后才演示。
  highlight: string;
  demo: boolean;
}

// 三段候选交会位置。pads 只是“可以停靠的地方”，不提前标出唯一答案。
// 只有街口那一处同时联系河道与街路，另一处只在水上。
export interface KaifengPad extends KaifengPoint {
  id: string;
  label: string;
  // 是否同时接上街路：只用于内部判定，界面不提前把答案画出来。
  connectsStreet: boolean;
}

export const KAIFENG_PADS: KaifengPad[] = [
  { id: 'pad-street', x: KAIFENG_STREET_X, y: KAIFENG_RIVER_MIDDLE, label: '街口', connectsStreet: true },
  { id: 'pad-water', x: 262, y: KAIFENG_RIVER_MIDDLE, label: '河上', connectsStreet: false }
];

export const KAIFENG_BRIDGE_START: KaifengBridgeState = { x: 742, y: 612, angle: 20 };

function clamp(value: number, min: number, max: number): number {
  return value < min ? min : value > max ? max : value;
}

function normalizeAngle(angle: number): number {
  let value = angle % 180;
  if (value < 0) value += 180;
  return value;
}

function radians(angle: number): number {
  return angle * Math.PI / 180;
}

export function kaifengEnds(state: KaifengBridgeState): KaifengPoint[] {
  const rad = radians(state.angle);
  const dx = Math.cos(rad) * KAIFENG_BRIDGE_HALF;
  const dy = Math.sin(rad) * KAIFENG_BRIDGE_HALF;
  return [{ x: state.x + dx, y: state.y + dy }, { x: state.x - dx, y: state.y - dy }];
}

function landable(point: KaifengPoint, isNorth: boolean): boolean {
  if (Math.abs(point.x - KAIFENG_STREET_X) > LANDING_TOLERANCE) return false;
  return isNorth
    ? point.y >= LANDING_NORTH_MIN && point.y <= LANDING_NORTH_MAX
    : point.y >= LANDING_SOUTH_MIN && point.y <= LANDING_SOUTH_MAX;
}

// 判定只读取当前摆放。任何动画、时长、提示次数都不参与，避免“看完动画就算成功”。
export function judgeKaifengBridge(state: KaifengBridgeState): KaifengJudge {
  const ends = kaifengEnds(state);
  const northEnd = ends[0].y <= ends[1].y ? ends[0] : ends[1];
  const southEnd = ends[0].y <= ends[1].y ? ends[1] : ends[0];
  const northLanded = landable(northEnd, true);
  const southLanded = landable(southEnd, false);
  const spansRiver = northEnd.y < KAIFENG_RIVER_TOP && southEnd.y > KAIFENG_RIVER_BOTTOM;
  // 顺河平放且压在河道上：桥身占住水面，船走不通。
  // 只有“接近水平”才算占住航道；竖直或斜放的桥即使桥心在河上，水仍从桥下过。
  const nearHorizontal = Math.abs(Math.sin(radians(state.angle))) < 0.5;
  const lyingInWater = !spansRiver && nearHorizontal &&
    state.y > KAIFENG_RIVER_TOP - 12 && state.y < KAIFENG_RIVER_BOTTOM + 12;
  const streetOpen = northLanded && southLanded;
  const waterOpen = !lyingInWater;
  const solved = spansRiver && streetOpen && waterOpen;

  let verdict = 'on-bank';
  let message = '桥还搁在岸上，两端都没有搭到街口与水面之间。';
  let personStop: KaifengPoint | undefined = { x: KAIFENG_STREET_X, y: KAIFENG_RIVER_TOP - 20 };
  let boatStop: KaifengPoint | undefined = undefined;

  if (solved) {
    verdict = 'solved';
    // 州桥这一段不能写“船从桥下过”：史料明确“低平不通舟船”。
    // 桥位成立只说明桥接上了街与对岸，船怎么走由幕一的桥型与船位另行判定。
    message = '桥跨过汴河，两端都落在御街口。';
    personStop = undefined;
  } else if (lyingInWater) {
    verdict = 'along-river';
    message = '桥顺着河躺在水里，桥身占住了航道——船到这里就过不去。';
    personStop = { x: KAIFENG_STREET_X, y: KAIFENG_RIVER_TOP - 20 };
    boatStop = { x: Math.max(120, state.x - KAIFENG_BRIDGE_HALF - 46), y: KAIFENG_RIVER_MIDDLE + 8 };
  } else if (northLanded && !southLanded) {
    verdict = 'north-only';
    message = '北岸接上了，南端还悬在水上：行人走到桥南头就停下。';
    personStop = { x: southEnd.x, y: southEnd.y };
  } else if (southLanded && !northLanded) {
    verdict = 'south-only';
    message = '南岸接上了，北端没有搭上岸：街上的人走不到桥头。';
    personStop = { x: KAIFENG_STREET_X, y: KAIFENG_RIVER_TOP - 14 };
  } else if (spansRiver) {
    verdict = 'offset';
    message = '桥跨过了河，却没对准街口：车驾还得绕到桥头。';
    boatStop = undefined;
    personStop = { x: KAIFENG_STREET_X, y: KAIFENG_RIVER_TOP - 14 };
  }

  return {
    northEnd, southEnd, northLanded, southLanded, spansRiver, lyingInWater,
    streetOpen, waterOpen, solved, personStop, boatStop, verdict, message
  };
}

// 单指拖动后的整理：先夹进画面，再吸附角度，最后在接近候选点时停靠。
// 吸附只在“已经很接近”时生效，避免自动把桥吸到答案上。
export function settleKaifengBridge(state: KaifengBridgeState): KaifengBridgeState {
  const x = clamp(state.x, 90, KAIFENG_BOARD_WIDTH - 90);
  const y = clamp(state.y, 120, KAIFENG_BOARD_HEIGHT - 120);
  let angle = normalizeAngle(state.angle);
  if (Math.abs(angle - 90) <= ANGLE_STRONG_SNAP) {
    angle = 90;
  } else {
    const snapped = Math.round(angle / ANGLE_SNAP_STEP) * ANGLE_SNAP_STEP;
    if (Math.abs(angle - snapped) <= ANGLE_SNAP_NEAR) angle = normalizeAngle(snapped);
  }
  let outX = x;
  let outY = y;
  for (const pad of KAIFENG_PADS) {
    if (Math.abs(x - pad.x) <= POSITION_SNAP && Math.abs(y - pad.y) <= POSITION_SNAP) {
      outX = pad.x; outY = pad.y; break;
    }
  }
  return { x: outX, y: outY, angle };
}

// 拖动过程中的角度计算：以桥心为原点，把手柄拖到哪就转到哪，
export function kaifengAngleTo(state: KaifengBridgeState, point: KaifengPoint): number {
  const dx = point.x - state.x;
  const dy = point.y - state.y;
  if (Math.abs(dx) < 0.001 && Math.abs(dy) < 0.001) return state.angle;
  return normalizeAngle(Math.atan2(dy, dx) * 180 / Math.PI);
}

export function kaifengHints(level: number): KaifengHint {
  if (level >= 3) {
    return { level: 3, text: '演示一次：桥心落在街口，桥身横跨水面。这是演示，不算你独立解出。',
      highlight: 'demo', demo: true };
  }
  if (level === 2) {
    return { level: 2, text: '街与河只在一处相交：把那一段岸线找出来，桥心就放在那里。',
      highlight: 'pad', demo: false };
  }
  if (level === 1) {
    return { level: 1, text: '先看街：御街从北边一直通到水边，桥要把这条街接到对岸。',
      highlight: 'street', demo: false };
  }
  return { level: 0, text: '', highlight: '', demo: false };
}

// —— 第二段：同一桥位的不同时期 ——

export interface KaifengEvidence {
  id: string;
  era: string;
  title: string;
  // 是否解释“同一处的不同时期”。不相关的那片在拖上去时会被拒绝，并说明为什么。
  relevant: boolean;
  reject: string;
  detail: string;
  sourceId: string;
  // 层位槽：'lower' 最早、'middle' 中间、'upper' 最晚；空串表示不属于地层。
  // 由领域层给出，组件不再自己维护一份层位映射，避免画面与判定漂移。
  slot: string;
}

// 四片材料里只有三片能解释“同一处、不同时期”。多出的那一片是同城另一种材料（灯事），
// 它本身有出处，只是说不清桥的层位——被拖到桥位时会被明确拒绝，而不是静默失败。
export const KAIFENG_EVIDENCE: KaifengEvidence[] = [
  {
    id: 'song-base', era: '宋代', title: '桥基线索', relevant: true, reject: '',
    detail: '发掘所见更早的桥基，是这一位置在宋代已有桥梁的线索。',
    sourceId: 'roam-source-zhouqiao', slot: 'lower'
  },
  {
    id: 'ming-deck', era: '明代早期', title: '桥体关系', relevant: true, reject: '',
    detail: '现发现的桥体为明代早期建造，压在更早的桥基之上。',
    sourceId: 'roam-source-zhouqiao', slot: 'middle'
  },
  {
    // 原来的“今日考古观察”不是地层，放进层位会被误读成“今天的地层”。
    // 改为有明确记载的明末淤埋层：崇祯十五年黄河水患把州桥埋入地下。
    id: 'burial-silt', era: '明末', title: '淤埋层', relevant: true, reject: '',
    detail: '崇祯十五年黄河决口，州桥与汴河故道被泥沙淤埋；今天要在数米深的地下才见到它。',
    sourceId: 'roam-source-zhouqiao', slot: 'upper'
  },
  {
    id: 'lantern-record', era: '北宋 · 节俗', title: '灯事记载', relevant: false,
    reject: '这片材料讲的是灯事与节俗，说不清桥的层位。它属于另一段，不是这一处的时间证据。',
    detail: '《东京梦华录》所记的北宋灯事，属于节俗文献。',
    sourceId: 'roam-source-lantern-zhang', slot: ''
  }
];

export interface KaifengLayerState {
  // 已对齐并放下的材料 id，按放下顺序。
  placed: string[];
  // 最近一次尝试的距离，用于画面提示锚点差多少，而不是只有对/错两态。
  lastDistance: number;
  lastAligned: boolean;
}

// 材料片锚点容差。组件用它决定“没对上就把卡片退回托盘”，与判定共用同一数值。
export const KAIFENG_EVIDENCE_TOLERANCE: number = 64;

export interface KaifengPlaceResult {
  aligned: boolean;
  distance: number;
  placed: string[];
  message: string;
}

// 材料片的锚点必须对到桥位锚点。距离由调用方给出，规则层只给判定与说法。
export function placeKaifengEvidence(state: KaifengLayerState, evidenceId: string, distance: number): KaifengPlaceResult {
  const material = KAIFENG_EVIDENCE.find((item: KaifengEvidence) => item.id === evidenceId);
  if (!material) return { aligned: false, distance, placed: state.placed.slice(), message: '这份材料不属于州桥这一组。' };
  // 不属于这个问题的那一片，即使用户把它拖准了也不收：判断发生在选材，不在对位。
  if (!material.relevant) {
    return { aligned: false, distance, placed: state.placed.slice(), message: material.reject };
  }
  if (state.placed.indexOf(evidenceId) >= 0) {
    return { aligned: true, distance, placed: state.placed.slice(), message: '这份材料已经放在桥位上了。' };
  }
  // 容差 64 逻辑单位：单指拖动下能对准，又不至于放到画面任意处都算对。
  if (distance > KAIFENG_EVIDENCE_TOLERANCE) {
    return {
      aligned: false, distance, placed: state.placed.slice(),
      message: '锚点没有对上：这份材料说不出它在桥的哪一侧。把它拖回桥位再放。'
    };
  }
  const placed = state.placed.concat([evidenceId]);
  const needed = KAIFENG_EVIDENCE.filter((item: KaifengEvidence) => item.relevant).length;
  const message = placed.length < needed
    ? '锚点对上了，这一层留在桥位。还有材料没有放。'
    : '三份材料都叠在同一处了：它们在同一位置，却不是同一年。';
  return { aligned: true, distance, placed, message };
}

// —— 第三段：自己的灯 ——

export interface KaifengLantern {
  frame: string;
  paper: string;
  wish: string;
  spot: string;
}

export interface KaifengLanternOption {
  id: string;
  label: string;
  detail: string;
}

export const KAIFENG_FRAMES: KaifengLanternOption[] = [
  { id: 'round', label: '圆骨', detail: '弧形骨架，光从四面散开。' },
  { id: 'fold', label: '折骨', detail: '折面骨架，光沿棱线落下。' },
  { id: 'water', label: '水纹骨', detail: '起伏骨架，影子里带着水纹。' }
];

export const KAIFENG_PAPERS: KaifengLanternOption[] = [
  { id: 'rice', label: '素纸', detail: '本色纸面，光最柔和。' },
  { id: 'dye', label: '染纸', detail: '暖色纸面，光偏橘。' },
  { id: 'gold', label: '洒金', detail: '带金屑的纸面，亮点更碎。' }
];

// 愿签：与线索里的三个选项一一对应（id 保持一致），但在画面上是可拖的签，不是按钮列表。
export const KAIFENG_WISH: KaifengLanternOption[] = [
  { id: 'kf-river-safe', label: '愿河路安澜', detail: '把沿河行走的祝愿写进画面。' },
  { id: 'kf-home-warm', label: '愿灯火可亲', detail: '留住街巷里温暖的光。' },
  { id: 'kf-new-page', label: '愿此页常新', detail: '让这一夜成为下一段探索的起点。' }
];

export const KAIFENG_SPOTS: KaifengLanternOption[] = [
  { id: 'bridge', label: '挂在桥头', detail: '光照桥面与栏杆，人从光里过。' },
  { id: 'water', label: '放在水面', detail: '光落在水上，桥影被拉长。' },
  { id: 'street', label: '立在街口', detail: '光沿街铺开，照到店屋门前。' }
];

// 灯可以拖到任意一处；停稳后吸附到最近的一个位置，规则层与画面共用同一组锚点。
export function kaifengLanternAnchor(bridgeX: number, bridgeY: number, spot: string): KaifengPoint {
  if (spot === 'water') return { x: bridgeX + 170, y: KAIFENG_RIVER_BOTTOM - 60 };
  if (spot === 'street') return { x: KAIFENG_STREET_X + 130, y: KAIFENG_RIVER_TOP - 190 };
  return { x: bridgeX - 150, y: bridgeY - 60 };
}

export function kaifengSpotFor(bridgeX: number, bridgeY: number, x: number, y: number): string {
  const ids: string[] = ['bridge', 'water', 'street'];
  let best = 0;
  let bestDistance = Number.MAX_VALUE;
  for (let index = 0; index < ids.length; index++) {
    const anchor = kaifengLanternAnchor(bridgeX, bridgeY, ids[index]);
    const dx = anchor.x - x;
    const dy = anchor.y - y;
    const distance = dx * dx + dy * dy;
    if (distance < bestDistance) { bestDistance = distance; best = index; }
  }
  return ids[best];
}

export const KAIFENG_LANTERN_DEFAULT: KaifengLantern = {
  frame: 'round', paper: 'rice', wish: 'kf-home-warm', spot: 'bridge'
};

export function validKaifengLantern(value: KaifengLantern): boolean {
  return KAIFENG_FRAMES.some((item: KaifengLanternOption) => item.id === value.frame) &&
    KAIFENG_PAPERS.some((item: KaifengLanternOption) => item.id === value.paper) &&
    KAIFENG_SPOTS.some((item: KaifengLanternOption) => item.id === value.spot) &&
    typeof value.wish === 'string' && value.wish.length > 0;
}

// —— 作品的版本化快照 ——

// 与旧 progress:roam:v1 分开：旧键只记录“选了哪个片段”，
// 这份快照记录桥位、方向、叠合与灯形。首版只在本端内存与页面预览中使用，
// 尚未接入持久化；接入时必须按 version 解析，缺字段保持缺省，不猜测旧数据。
export interface KaifengWorkV1 {
  version: number;
  bridge: KaifengBridgeState;
  evidence: string[];
  lantern: KaifengLantern;
  // 是否由玩家独立解出（演示过则记 false），用于纪念页如实标注。
  independent: boolean;
}

export function createKaifengWork(bridge: KaifengBridgeState, evidence: string[], lantern: KaifengLantern,
  independent: boolean): KaifengWorkV1 {
  return {
    version: 1,
    bridge: { x: bridge.x, y: bridge.y, angle: bridge.angle },
    evidence: evidence.slice(),
    lantern: { frame: lantern.frame, paper: lantern.paper, wish: lantern.wish, spot: lantern.spot },
    independent
  };
}

function finiteNumber(value: number): boolean {
  return typeof value === 'number' && Number.isFinite(value);
}

// 防御式解析：只接受结构完整的 v1；不认识的内容原样当作“没有作品”，
// 不把残缺数据补成看似正常的桥位，也不回写旧记录。
export function parseKaifengWork(text: string): KaifengWorkV1 | undefined {
  if (typeof text !== 'string' || !text.trim()) return undefined;
  let value: KaifengWorkV1;
  try {
    value = JSON.parse(text) as KaifengWorkV1;
  } catch (_error) {
    return undefined;
  }
  if (!value || value.version !== 1 || !value.bridge) return undefined;
  if (!finiteNumber(value.bridge.x) || !finiteNumber(value.bridge.y) || !finiteNumber(value.bridge.angle)) return undefined;
  if (!Array.isArray(value.evidence)) return undefined;
  const evidence: string[] = [];
  value.evidence.forEach((id: string) => {
    if (KAIFENG_EVIDENCE.some((item: KaifengEvidence) => item.id === id) && evidence.indexOf(id) < 0) evidence.push(id);
  });
  if (!value.lantern || !validKaifengLantern(value.lantern)) return undefined;
  return {
    version: 1,
    bridge: { x: value.bridge.x, y: value.bridge.y, angle: value.bridge.angle },
    evidence,
    lantern: {
      frame: value.lantern.frame, paper: value.lantern.paper,
      wish: value.lantern.wish, spot: value.lantern.spot
    },
    independent: value.independent === true
  };
}

export function serializeKaifengWork(work: KaifengWorkV1): string {
  return JSON.stringify(createKaifengWork(work.bridge, work.evidence, work.lantern, work.independent));
}

// —— 幕一：州桥的桥型与船位 ——
//
// 史料依据（《东京梦华录》卷一「河道」）：
// 「州桥……其桥与相国寺桥皆低平不通舟船，唯西河平船可过……
//   桥下密排石柱，盖车驾御路也。」
// 因此北宋州桥只能是低平平桥；单孔拱桥是明代改建后的形制。
// 桥型不是审美选项，而是年代判断：选拱桥会让车驾上不去，
// 也等于把明代的桥提前到北宋。
//
// 船的走法同样按史料处理：州桥低平，高桅船不能从桥下过；
// 文献只说“唯西河平船可过”，本作按“东岸卸货、西河换平船”示意，
// 不把平船画成从州桥桥下穿过。

export const KAIFENG_BRIDGE_FLAT: string = 'flat';
export const KAIFENG_BRIDGE_ARCH: string = 'arch';

export function validKaifengBridgeKind(value: string): boolean {
  return value === KAIFENG_BRIDGE_FLAT || value === KAIFENG_BRIDGE_ARCH;
}

export const KAIFENG_BOAT_START: KaifengPoint = { x: 760, y: 1010 };
export const KAIFENG_BOAT_MOORING: KaifengPoint = { x: 720, y: 1150 };
export const KAIFENG_BOAT_MOORING_TOLERANCE: number = 100;
export const KAIFENG_BOAT_UNDER_TOLERANCE: number = 120;

export interface KaifengBoat {
  x: number;
  y: number;
  // 'front' 停在桥前、'under' 拖到桥下、'mooring' 东岸泊位、'adrift' 不在河道。
  spot: string;
}

export function kaifengBoatSpotFor(x: number, y: number, bridgeX: number, bridgeY: number): string {
  const moorX = x - KAIFENG_BOAT_MOORING.x;
  const moorY = y - KAIFENG_BOAT_MOORING.y;
  if (Math.sqrt(moorX * moorX + moorY * moorY) <= KAIFENG_BOAT_MOORING_TOLERANCE) return 'mooring';
  const underX = x - bridgeX;
  const underY = y - bridgeY;
  if (Math.sqrt(underX * underX + underY * underY) <= KAIFENG_BOAT_UNDER_TOLERANCE) return 'under';
  if (y > KAIFENG_RIVER_TOP && y < KAIFENG_RIVER_BOTTOM) return 'front';
  return 'adrift';
}

export interface KaifengCrossing {
  bridgeFormOk: boolean;
  boatRouted: boolean;
  cartPass: boolean;
  // 拱桥净高够船通过，仅用于说明，不作为成立条件：北宋州桥不是拱桥。
  boatPassUnder: boolean;
  solved: boolean;
  verdict: string;
  message: string;
  cartStop: KaifengPoint | undefined;
  boatStop: KaifengPoint | undefined;
}

export function judgeKaifengCrossing(state: KaifengBridgeState, kind: string,
  boat: KaifengBoat): KaifengCrossing {
  const geometry = judgeKaifengBridge(state);
  const bridgeFormOk = kind === KAIFENG_BRIDGE_FLAT;
  const boatRouted = boat.spot === 'mooring';
  const cartPass = bridgeFormOk;
  const boatPassUnder = kind === KAIFENG_BRIDGE_ARCH;
  const cartStop: KaifengPoint | undefined = bridgeFormOk ? undefined :
    { x: KAIFENG_STREET_X, y: KAIFENG_RIVER_TOP - 70 };
  const boatStop: KaifengPoint | undefined = boatRouted ? undefined :
    { x: Math.max(120, Math.min(KAIFENG_BOARD_WIDTH - 120, boat.x)), y: Math.max(KAIFENG_RIVER_TOP + 20, boat.y) };

  let verdict = geometry.verdict;
  let message = geometry.message;
  if (geometry.solved) {
    if (!bridgeFormOk) {
      verdict = 'arch-blocks-cart';
      message = '拱桥能把船放过，但引桥坡陡，车驾上不去。《东京梦华录》记州桥「低平不通舟船」，' +
        '桥下密排石柱，是车驾御路——北宋的州桥只能是低平平桥。';
    } else if (boat.spot === 'under') {
      verdict = 'boat-under';
      message = '州桥不通舟船，船不能从这里过。';
    } else if (!boatRouted) {
      verdict = 'boat-at-bridge';
      message = '桥低平，船过不去——文献说「不通舟船，唯西河平船可过」。把船移到东岸泊位。';
    } else {
      verdict = 'crossing';
      message = '御街平直，车驾通行；船在东岸卸货，西河换平船继续走。州桥这一段，本来就不通舟船。';
    }
  }
  return {
    bridgeFormOk, boatRouted, cartPass, boatPassUnder,
    solved: geometry.solved && bridgeFormOk && boatRouted,
    verdict, message, cartStop, boatStop
  };
}

// —— 幕二：层位与石语纹样 ——

export interface KaifengLayerSlots {
  lower: string;
  middle: string;
  upper: string;
}

export function emptyKaifengLayerSlots(): KaifengLayerSlots {
  return { lower: '', middle: '', upper: '' };
}

export function kaifengSlotLabel(slot: string): string {
  if (slot === 'lower') return '下层（最早）';
  if (slot === 'middle') return '中层';
  if (slot === 'upper') return '上层（最晚）';
  return '未选层位';
}

function kaifengMaterialLabel(id: string): string {
  if (id === 'song-base') return '宋代桥基';
  if (id === 'ming-deck') return '明代桥体';
  if (id === 'burial-silt') return '明末淤埋';
  return '另一份材料';
}

export interface KaifengLayerPlaceResult {
  aligned: boolean;
  slots: KaifengLayerSlots;
  complete: boolean;
  message: string;
}

export function kaifengLayersComplete(slots: KaifengLayerSlots): boolean {
  return slots.lower === 'song-base' && slots.middle === 'ming-deck' && slots.upper === 'burial-silt';
}

export function placeKaifengLayer(slots: KaifengLayerSlots, evidenceId: string, slot: string,
  distance: number): KaifengLayerPlaceResult {
  const same = { lower: slots.lower, middle: slots.middle, upper: slots.upper };
  const material = KAIFENG_EVIDENCE.find((item: KaifengEvidence) => item.id === evidenceId);
  if (!material) return { aligned: false, slots: same, complete: false, message: '这份材料不属于州桥这一组。' };
  if (!material.relevant) return { aligned: false, slots: same, complete: false, message: material.reject };
  if (distance > KAIFENG_EVIDENCE_TOLERANCE) {
    return { aligned: false, slots: same, complete: false,
      message: '锚点没有对上：把材料拖到剖面的层带上再放。' };
  }
  if (slot !== 'lower' && slot !== 'middle' && slot !== 'upper') {
    return { aligned: false, slots: same, complete: false, message: '请把材料放到下、中、上三条层带之一。' };
  }
  if (same.lower === evidenceId || same.middle === evidenceId || same.upper === evidenceId) {
    return { aligned: true, slots: same, complete: kaifengLayersComplete(same), message: '这份材料已经放在层位上了。' };
  }
  const occupied: string = slot === 'lower' ? same.lower : slot === 'middle' ? same.middle : same.upper;
  if (occupied !== '') {
    return { aligned: false, slots: same, complete: false,
      message: `这个层位已经有材料了：${kaifengMaterialLabel(occupied)}。先取回再换。` };
  }
  if (material.slot !== slot) {
    let message = `这份材料应放在${kaifengSlotLabel(material.slot)}，不能放在${kaifengSlotLabel(slot)}。`;
    if (material.slot === 'upper' && slot === 'lower') {
      message = '淤埋是最后一层，不可能压在桥体之下。';
    } else if (material.slot === 'lower' && slot === 'upper') {
      message = '宋代桥基在最下面，不能压到淤埋层之上。';
    }
    return { aligned: false, slots: same, complete: false, message };
  }
  if (slot === 'lower') same.lower = evidenceId;
  else if (slot === 'middle') same.middle = evidenceId;
  else same.upper = evidenceId;
  const complete = kaifengLayersComplete(same);
  return {
    aligned: true, slots: same, complete,
    message: complete ? '三份材料叠在同一处：宋代桥基在下，明代桥体在上，明末淤埋盖住它们。'
      : '这一层放对了，剖面里多了一条时间线。'
  };
}

export interface KaifengMotifPiece {
  id: string;
  label: string;
  // 允许放置的槽位；两只仙鹤可左右互换，海马只能居中，祥云只能在下。
  slots: string[];
  detail: string;
}

// 依据《东京梦华录》「雕镌海马水兽飞云之状」与州桥石壁考古描述
// 「一匹海马、两只仙鹤环以祥云」。四片残纹只做示意重组，不是原石拓片。
export const KAIFENG_MOTIF_PIECES: KaifengMotifPiece[] = [
  { id: 'horse', label: '海马', slots: ['center'], detail: '海马居中，四足踏云。' },
  { id: 'crane-a', label: '仙鹤', slots: ['left', 'right'], detail: '仙鹤分列左右，一匹海马配两只。' },
  { id: 'crane-b', label: '仙鹤', slots: ['left', 'right'], detail: '仙鹤分列左右，一匹海马配两只。' },
  { id: 'cloud', label: '祥云', slots: ['bottom'], detail: '祥云在下，托住海马与双鹤。' }
];

export interface KaifengMotifSlots {
  center: string;
  left: string;
  right: string;
  bottom: string;
}

export function emptyKaifengMotifSlots(): KaifengMotifSlots {
  return { center: '', left: '', right: '', bottom: '' };
}

export function kaifengMotifSlotLabel(slot: string): string {
  if (slot === 'center') return '中间';
  if (slot === 'left') return '左侧';
  if (slot === 'right') return '右侧';
  if (slot === 'bottom') return '下方';
  return '未选位置';
}

export interface KaifengMotifResult {
  aligned: boolean;
  slots: KaifengMotifSlots;
  complete: boolean;
  message: string;
}

export function kaifengMotifComplete(slots: KaifengMotifSlots): boolean {
  if (!slots.center || !slots.left || !slots.right || !slots.bottom) return false;
  return slots.center === 'horse' && slots.bottom === 'cloud' &&
    (slots.left === 'crane-a' || slots.left === 'crane-b') &&
    (slots.right === 'crane-a' || slots.right === 'crane-b');
}

export function placeKaifengMotif(slots: KaifengMotifSlots, pieceId: string, slot: string): KaifengMotifResult {
  const same = { center: slots.center, left: slots.left, right: slots.right, bottom: slots.bottom };
  const piece = KAIFENG_MOTIF_PIECES.find((item: KaifengMotifPiece) => item.id === pieceId);
  if (!piece) return { aligned: false, slots: same, complete: false, message: '这片残纹不属于石壁这一组。' };
  if (slot !== 'center' && slot !== 'left' && slot !== 'right' && slot !== 'bottom') {
    return { aligned: false, slots: same, complete: false, message: '把残纹放到中间、左侧、右侧或下方。' };
  }
  if (same.center === pieceId || same.left === pieceId || same.right === pieceId || same.bottom === pieceId) {
    return { aligned: true, slots: same, complete: kaifengMotifComplete(same), message: '这片残纹已经放好了。' };
  }
  const occupied: string = slot === 'center' ? same.center : slot === 'left' ? same.left :
    slot === 'right' ? same.right : same.bottom;
  if (occupied !== '') {
    return { aligned: false, slots: same, complete: false, message: '这个位置已经有残纹了，先取回再换。' };
  }
  if (piece.slots.indexOf(slot) < 0) {
    return { aligned: false, slots: same, complete: false,
      message: '顺序不对：《东京梦华录》记石壁「雕镌海马水兽飞云之状」，考古见「一匹海马、两只仙鹤环以祥云」——' +
        '海马居中，双鹤分列左右，祥云在下。' };
  }
  if (slot === 'center') same.center = pieceId;
  else if (slot === 'left') same.left = pieceId;
  else if (slot === 'right') same.right = pieceId;
  else same.bottom = pieceId;
  const complete = kaifengMotifComplete(same);
  return {
    aligned: true, slots: same, complete,
    message: complete ? '海马居中，双鹤左右，祥云在下——残纹合拢成一组。' : '位置对了，拓片还差几片。'
  };
}

// —— 幕三：州桥夜市的三处摊 ——

export interface KaifengStall {
  id: string;
  label: string;
  x: number;
  y: number;
  sourceId: string;
}

// 三样吃食均出自《东京梦华录》卷二「州桥夜市」条：水饭、爊肉、干脯。
// 坐标是玩法布局，不是夜市实际位置或摊位复原。
export const KAIFENG_STALLS: KaifengStall[] = [
  // 三摊纵向间距按“一屏可见”排：第三摊原在 1540，会被底部判读条整块盖住，
  // 玩家刚点亮就看不见。1200 对应屏幕 y≈1730，稳定露在面板与材质条之上。
  { id: 'stall-water-rice', label: '水饭', x: 430, y: 620, sourceId: 'roam-source-dongjing' },
  { id: 'stall-roast-meat', label: '爊肉', x: 570, y: 900, sourceId: 'roam-source-dongjing' },
  { id: 'stall-dried-meat', label: '干脯', x: 430, y: 1200, sourceId: 'roam-source-dongjing' }
];

export const KAIFENG_LIGHT_RADIUS: number = 250;

export interface KaifengLightPoint {
  id: string;
  x: number;
  y: number;
}

export interface KaifengCoverage {
  covered: string[];
  dark: string[];
  verdict: string;
  passed: boolean;
  message: string;
}

export function kaifengCoverage(lights: KaifengLightPoint[]): KaifengCoverage {
  const covered: string[] = [];
  const dark: string[] = [];
  KAIFENG_STALLS.forEach((stall: KaifengStall) => {
    const lit = lights.some((light: KaifengLightPoint) => {
      const dx = light.x - stall.x;
      const dy = light.y - stall.y;
      return Math.sqrt(dx * dx + dy * dy) <= KAIFENG_LIGHT_RADIUS;
    });
    if (lit) covered.push(stall.id); else dark.push(stall.id);
  });
  let verdict = 'dark';
  let message = '三处都暗着：把灯放到摊前，摊才开张。';
  if (covered.length >= KAIFENG_STALLS.length) {
    verdict = 'lit';
    message = '三处摊都亮了：桥头水饭、水边爊肉、街口干脯，州桥夜市开张。';
  } else if (covered.length === 2) {
    verdict = 'half';
    message = '两处亮了，还有一处暗着——灯数不够时，可以把一盏放到两处之间。';
  } else if (covered.length === 1) {
    verdict = 'single';
    message = '只亮了一处，夜市还开不起来。';
  }
  return { covered, dark, verdict, passed: covered.length >= 2, message };
}

// —— 养成：城格、灯火与城市快照 ——

export interface KaifengActs {
  bridge: boolean;
  layers: boolean;
  lantern: boolean;
  bridgeIndependent: boolean;
  note: boolean;
}

export function emptyKaifengActs(): KaifengActs {
  return { bridge: false, layers: false, lantern: false, bridgeIndependent: false, note: false };
}

// 灯火只由真实动作产生：完成一幕、未用演示独立解桥、写下一页。
// 它决定能点几盏灯，不消耗、不衰减、无每日重置；上限 3 与三处摊对应。
export function kaifengLight(acts: KaifengActs): number {
  let value = 0;
  if (acts.bridge) value += 1;
  if (acts.layers) value += 1;
  if (acts.bridgeIndependent) value += 1;
  if (acts.note) value += 1;
  return Math.min(3, value);
}

export interface KaifengCityV1 {
  version: number;
  chapterId: string;
  acts: KaifengActs;
  bridge: KaifengBridgeState;
  bridgeKind: string;
  boatSpot: string;
  layers: KaifengLayerSlots;
  motif: KaifengMotifSlots;
  lantern: KaifengLantern;
  lights: KaifengLightPoint[];
  closedAt?: number;
  updatedAt: number;
}

export function emptyKaifengCity(chapterId: string, updatedAt: number): KaifengCityV1 {
  return {
    version: 1,
    chapterId,
    acts: emptyKaifengActs(),
    bridge: { x: KAIFENG_BRIDGE_START.x, y: KAIFENG_BRIDGE_START.y, angle: KAIFENG_BRIDGE_START.angle },
    bridgeKind: KAIFENG_BRIDGE_FLAT,
    boatSpot: 'front',
    layers: emptyKaifengLayerSlots(),
    motif: emptyKaifengMotifSlots(),
    lantern: { frame: KAIFENG_LANTERN_DEFAULT.frame, paper: KAIFENG_LANTERN_DEFAULT.paper,
      wish: KAIFENG_LANTERN_DEFAULT.wish, spot: KAIFENG_LANTERN_DEFAULT.spot },
    lights: [],
    updatedAt
  };
}

export function kaifengCityRecordId(chapterId: string): string {
  if (typeof chapterId !== 'string' || !/^roam-[a-z0-9-]{2,60}$/.test(chapterId)) {
    throw new Error('KAIFENG_INVALID_CHAPTER');
  }
  return `progress:kaifeng-city:v1:${chapterId}`;
}

function validLayerSlots(value: KaifengLayerSlots): boolean {
  if (!value) return false;
  const ids = [value.lower, value.middle, value.upper];
  if (ids.some((id: string) => id !== '' && !KAIFENG_EVIDENCE.some((item: KaifengEvidence) => item.id === id))) {
    return false;
  }
  const used = ids.filter((id: string) => id !== '');
  if (new Set<string>(used).size !== used.length) return false;
  return (value.lower === '' || value.lower === 'song-base') &&
    (value.middle === '' || value.middle === 'ming-deck') &&
    (value.upper === '' || value.upper === 'burial-silt');
}

function validMotifSlots(value: KaifengMotifSlots): boolean {
  if (!value) return false;
  const ids = [value.center, value.left, value.right, value.bottom];
  const used = ids.filter((id: string) => id !== '');
  if (used.some((id: string) => !KAIFENG_MOTIF_PIECES.some((piece: KaifengMotifPiece) => piece.id === id))) return false;
  if (new Set<string>(used).size !== used.length) return false;
  if (value.center !== '' && value.center !== 'horse') return false;
  if (value.bottom !== '' && value.bottom !== 'cloud') return false;
  return true;
}

export function serializeKaifengCity(city: KaifengCityV1): string {
  const text = JSON.stringify(city);
  // 单条记录正文上限 4000；这里再设 1800 的自上限，防止未来加字段把整份快照撑坏。
  if (text.length > 1800) throw new Error('KAIFENG_CITY_TOO_LARGE');
  return text;
}

export function parseKaifengCity(text: string): KaifengCityV1 | undefined {
  if (typeof text !== 'string' || !text.trim()) return undefined;
  let value: KaifengCityV1;
  try {
    value = JSON.parse(text) as KaifengCityV1;
  } catch (_error) {
    return undefined;
  }
  if (!value || value.version !== 1 || typeof value.chapterId !== 'string' || !value.chapterId) return undefined;
  if (!value.acts || typeof value.acts.bridge !== 'boolean' || typeof value.acts.layers !== 'boolean' ||
    typeof value.acts.lantern !== 'boolean' || typeof value.acts.bridgeIndependent !== 'boolean' ||
    typeof value.acts.note !== 'boolean') return undefined;
  if (!value.bridge || !finiteNumber(value.bridge.x) || !finiteNumber(value.bridge.y) ||
    !finiteNumber(value.bridge.angle)) return undefined;
  if (!validKaifengBridgeKind(value.bridgeKind)) return undefined;
  if (['front', 'under', 'mooring', 'adrift'].indexOf(value.boatSpot) < 0) return undefined;
  if (!validLayerSlots(value.layers) || !validMotifSlots(value.motif)) return undefined;
  if (!value.lantern || !validKaifengLantern(value.lantern)) return undefined;
  if (!Array.isArray(value.lights) || value.lights.length > 3) return undefined;
  const lightIds: string[] = [];
  for (const light of value.lights) {
    if (!light || typeof light.id !== 'string' || !light.id || lightIds.indexOf(light.id) >= 0 ||
      !finiteNumber(light.x) || !finiteNumber(light.y)) return undefined;
    lightIds.push(light.id);
  }
  if (!Number.isSafeInteger(value.updatedAt) || value.updatedAt < 0) return undefined;
  if (value.closedAt !== undefined && (!Number.isSafeInteger(value.closedAt) || value.closedAt < 0)) return undefined;
  const out: KaifengCityV1 = {
    version: 1,
    chapterId: value.chapterId,
    acts: { bridge: value.acts.bridge, layers: value.acts.layers, lantern: value.acts.lantern,
      bridgeIndependent: value.acts.bridgeIndependent, note: value.acts.note },
    bridge: { x: value.bridge.x, y: value.bridge.y, angle: value.bridge.angle },
    bridgeKind: value.bridgeKind,
    boatSpot: value.boatSpot,
    layers: { lower: value.layers.lower, middle: value.layers.middle, upper: value.layers.upper },
    motif: { center: value.motif.center, left: value.motif.left, right: value.motif.right, bottom: value.motif.bottom },
    lantern: { frame: value.lantern.frame, paper: value.lantern.paper, wish: value.lantern.wish, spot: value.lantern.spot },
    lights: value.lights.map((light: KaifengLightPoint): KaifengLightPoint =>
      ({ id: light.id, x: light.x, y: light.y })),
    updatedAt: value.updatedAt
  };
  // 可选字段只在存在时写入，保证“未收束”的城市往返后不凭空多一个 closedAt: undefined。
  if (value.closedAt !== undefined) out.closedAt = value.closedAt;
  return out;
}

// 跨端合并：幕的完成状态只增不减；层位与纹样按槽位取“非空优先”，
// 避免另一端较早但更完整的摆放被较新的空状态覆盖。桥面与灯取较新一方。
export function mergeKaifengCity(local: KaifengCityV1 | undefined,
  incoming: KaifengCityV1 | undefined): KaifengCityV1 | undefined {
  if (!local) return incoming ? parseKaifengCity(serializeKaifengCity(incoming)) : undefined;
  if (!incoming) return parseKaifengCity(serializeKaifengCity(local));
  const newer = incoming.updatedAt >= local.updatedAt ? incoming : local;
  const older = incoming.updatedAt >= local.updatedAt ? local : incoming;
  const layer = (a: string, b: string): string => a !== '' ? a : b;
  const closedA = local.closedAt !== undefined && local.closedAt > 0 ? local.closedAt : 0;
  const closedB = incoming.closedAt !== undefined && incoming.closedAt > 0 ? incoming.closedAt : 0;
  let closedAt: number | undefined = undefined;
  if (closedA > 0 && closedB > 0) closedAt = Math.min(closedA, closedB);
  else if (closedA > 0) closedAt = closedA;
  else if (closedB > 0) closedAt = closedB;
  return {
    version: 1,
    chapterId: newer.chapterId,
    acts: {
      bridge: local.acts.bridge || incoming.acts.bridge,
      layers: local.acts.layers || incoming.acts.layers,
      lantern: local.acts.lantern || incoming.acts.lantern,
      bridgeIndependent: local.acts.bridgeIndependent || incoming.acts.bridgeIndependent,
      note: local.acts.note || incoming.acts.note
    },
    bridge: { x: newer.bridge.x, y: newer.bridge.y, angle: newer.bridge.angle },
    bridgeKind: newer.bridgeKind,
    boatSpot: newer.boatSpot,
    layers: {
      lower: layer(newer.layers.lower, older.layers.lower),
      middle: layer(newer.layers.middle, older.layers.middle),
      upper: layer(newer.layers.upper, older.layers.upper)
    },
    motif: {
      center: layer(newer.motif.center, older.motif.center),
      left: layer(newer.motif.left, older.motif.left),
      right: layer(newer.motif.right, older.motif.right),
      bottom: layer(newer.motif.bottom, older.motif.bottom)
    },
    lantern: { frame: newer.lantern.frame, paper: newer.lantern.paper, wish: newer.lantern.wish, spot: newer.lantern.spot },
    lights: newer.lights.map((light: KaifengLightPoint): KaifengLightPoint => ({ id: light.id, x: light.x, y: light.y })),
    closedAt,
    updatedAt: Math.max(local.updatedAt, incoming.updatedAt)
  };
}

export interface KaifengCityGrade {
  grade: number;
  name: string;
}

export function kaifengCityGrade(city: KaifengCityV1 | undefined): KaifengCityGrade {
  if (!city) return { grade: 0, name: '空卷' };
  const coverage = kaifengCoverage(city.lights);
  if (city.closedAt !== undefined && city.closedAt > 0) return { grade: 5, name: '成志' };
  if (city.acts.lantern && coverage.covered.length >= KAIFENG_STALLS.length) return { grade: 4, name: '长明' };
  if (city.acts.lantern) return { grade: 3, name: '市声' };
  if (city.acts.layers) return { grade: 2, name: '叠城' };
  if (city.acts.bridge) return { grade: 1, name: '桥成' };
  return { grade: 0, name: '空卷' };
}
