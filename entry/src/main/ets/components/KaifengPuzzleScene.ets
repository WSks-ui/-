import {
  KAIFENG_BOARD_HEIGHT, KAIFENG_BOARD_WIDTH, KAIFENG_BOAT_MOORING, KAIFENG_BRIDGE_ARCH,
  KAIFENG_BRIDGE_FLAT, KAIFENG_BRIDGE_HALF, KAIFENG_BRIDGE_WIDTH, KAIFENG_EVIDENCE,
  KAIFENG_FRAMES, KAIFENG_LIGHT_RADIUS, KAIFENG_MOTIF_PIECES, KAIFENG_PAPERS, KAIFENG_RIVER_BOTTOM,
  KAIFENG_RIVER_TOP, KAIFENG_STALLS, KAIFENG_STREET_HALF, KAIFENG_STREET_X,
  KaifengEvidence, KaifengLanternOption, KaifengLightPoint, KaifengMotifPiece,
  KaifengStall, kaifengCoverage
} from '../domain/KaifengPuzzle';
import { RoamingTheme as R } from './RoamingTheme';

// 开封三幕的整屏关卡场。原创纸页叙事，不是历史城市复原或真实交通模拟。
//
// 三幕共用一幅 1000×2000 的竖幅纸页：
//   幕一（stage 0）城景：州桥、汴河、高桅船、东岸泊位、四个角色；
//   幕二（stage 1）剖面：宋桥基 / 明桥体 / 明末淤埋三条层带，层位齐后展开石壁残纹；
//   幕三（stage 2）夜市：水饭、爊肉、干脯三摊与三盏灯。
//
// 所有可拖物件都在 Canvas 上层用透明区域接收手势，绘制与热区共用 unit()/px()/py()，
// 位置常量只写一份（层带、槽位、托盘），避免“画在一处、能拖的是另一处”。
// 判定全部来自 domain/KaifengPuzzle；本文件只负责画和把手指位置换成逻辑坐标。

const SECTION_LEFT: number = 96;
const SECTION_RIGHT: number = 904;
const SECTION_TOP: number = 420;
// 三条层带自上而下：明末淤埋（最晚）→ 明代桥体 → 宋代桥基（最早）。
// 整段剖面上移并加高：原来只占纸页中段，上下各留一大片空白，
// 而材料托盘又落在页面底部判读条后面，看不见也拖不到。
const BAND_UPPER_TOP: number = 440;
const BAND_UPPER_BOTTOM: number = 700;
const BAND_MIDDLE_BOTTOM: number = 960;
const BAND_LOWER_BOTTOM: number = 1220;

const MOTIF_LEFT: number = 560;
const MOTIF_TOP: number = 700;
const MOTIF_SIZE: number = 340;
const MOTIF_CENTER_X: number = MOTIF_LEFT + MOTIF_SIZE / 2;
const MOTIF_CENTER_Y: number = MOTIF_TOP + MOTIF_SIZE / 2;

// 纹样槽位的候选点：x/y 是逻辑坐标，slot 是领域层的槽位名。
// 单独定义而不是用 number[] 第四位，避免把数字当字符串做类型转换。
interface MotifTarget {
  x: number;
  y: number;
  slot: string;
}

@Component
export struct KaifengPuzzleScene {
  @Prop @Watch('draw') stage: number = 0;
  @Prop @Watch('draw') bridgeX: number = 742;
  @Prop @Watch('draw') bridgeY: number = 612;
  @Prop @Watch('draw') bridgeAngle: number = 20;
  @Prop @Watch('draw') bridgeKind: string = KAIFENG_BRIDGE_FLAT;
  @Prop @Watch('draw') boatX: number = 760;
  @Prop @Watch('draw') boatY: number = 1010;
  @Prop @Watch('draw') boatSpot: string = 'front';
  @Prop @Watch('draw') placed: string[] = [];
  @Prop @Watch('draw') layersComplete: boolean = false;
  @Prop @Watch('draw') motifCenter: string = '';
  @Prop @Watch('draw') motifLeft: string = '';
  @Prop @Watch('draw') motifRight: string = '';
  @Prop @Watch('draw') motifBottom: string = '';
  @Prop @Watch('draw') motifComplete: boolean = false;
  @Prop @Watch('draw') lights: KaifengLightPoint[] = [];
  @Prop @Watch('draw') hintHighlight: string = '';
  @Prop @Watch('draw') lanternFrame: string = 'round';
  @Prop @Watch('draw') lanternPaper: string = 'rice';
  @Prop @Watch('draw') lanternWish: string = '';
  @Prop @Watch('draw') lanternSpot: string = 'bridge';
  @Prop @Watch('draw') lit: boolean = false;
  @Prop @Watch('draw') reducedMotion: boolean = false;

  onBridgeMove: (x: number, y: number, angle: number) => void = () => {};
  onBridgeSettle: () => void = () => {};
  onBoatMove: (x: number, y: number) => void = () => {};
  onEvidenceDrop: (id: string, slot: string, distance: number) => void = () => {};
  onMotifDrop: (pieceId: string, slot: string) => void = () => {};
  onLightMove: (index: number, x: number, y: number) => void = () => {};
  onLanternPart: (kind: string, id: string) => void = () => {};

  @State private widthVp: number = 360;
  @State private heightVp: number = 700;
  // 同一时刻只拖一个物件：画面只跟这一只手，避免多点误触。
  @State private dragging: string = '';
  @State private dragDX: number = 0;
  @State private dragDY: number = 0;
  @State private roleBubble: string = '';
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private ready: boolean = false;
  private dragOriginX: number = 0;
  private dragOriginY: number = 0;
  private knobOriginX: number = 0;
  private knobOriginY: number = 0;

  // 等比缩放 + 居中：画布与热区必须共用同一个系数。
  private unit(): number {
    const byWidth = this.widthVp / KAIFENG_BOARD_WIDTH;
    const byHeight = this.heightVp / KAIFENG_BOARD_HEIGHT;
    return Math.max(0.01, Math.min(byWidth, byHeight));
  }
  private originX(): number { return (this.widthVp - KAIFENG_BOARD_WIDTH * this.unit()) / 2; }
  private originY(): number { return (this.heightVp - KAIFENG_BOARD_HEIGHT * this.unit()) / 2; }
  private len(value: number): number { return value * this.unit(); }
  private px(value: number): number { return this.originX() + this.len(value); }
  private py(value: number): number { return this.originY() + this.len(value); }
  private boardX(vp: number): number { return (vp - this.originX()) / this.unit(); }
  private boardY(vp: number): number { return (vp - this.originY()) / this.unit(); }

  private line(x: number, y: number, x2: number, y2: number, color: string, width: number = 2): void {
    const c = this.context;
    c.beginPath(); c.moveTo(x, y); c.lineTo(x2, y2); c.strokeStyle = color; c.lineWidth = width; c.stroke();
  }

  private ellipse(x: number, y: number, rx: number, ry: number, color: string): void {
    const c = this.context;
    c.save(); c.translate(x, y); c.scale(rx, ry);
    c.beginPath(); c.arc(0, 0, 1, 0, Math.PI * 2); c.fillStyle = color; c.fill(); c.restore();
  }

  private paper(): void {
    const c = this.context;
    const sky = c.createLinearGradient(0, 0, 0, KAIFENG_BOARD_HEIGHT);
    sky.addColorStop(0, '#F8F1DF'); sky.addColorStop(0.36, '#F1ECDA'); sky.addColorStop(0.62, '#E8E7D2');
    sky.addColorStop(1, '#DEE1C9');
    c.fillStyle = sky; c.fillRect(0, 0, KAIFENG_BOARD_WIDTH, KAIFENG_BOARD_HEIGHT);
    c.strokeStyle = 'rgba(198,190,160,0.24)'; c.lineWidth = 1;
    for (let y = 16; y < KAIFENG_BOARD_HEIGHT; y += 24) {
      c.beginPath(); c.moveTo(0, y); c.lineTo(KAIFENG_BOARD_WIDTH, y + 4); c.stroke();
    }
  }

  // 远城：只作天际线剪影，交代“这是一座城”，不承担建筑形制复原。
  private skyline(): void {
    const c = this.context;
    c.fillStyle = '#CBD4B6';
    c.beginPath(); c.moveTo(-20, KAIFENG_RIVER_TOP);
    for (let index = 0; index < 9; index++) {
      const x = index * 118;
      c.lineTo(x, KAIFENG_RIVER_TOP - 54 - (index % 3) * 18);
      c.lineTo(x + 92, KAIFENG_RIVER_TOP - 54 - (index % 3) * 18);
    }
    c.lineTo(1040, KAIFENG_RIVER_TOP); c.closePath(); c.fill();
    for (let index = 0; index < 9; index++) {
      const x = index * 118 + 14;
      const h = 66 + (index % 4) * 22;
      c.fillStyle = '#B3C0A0';
      c.beginPath(); c.moveTo(x, KAIFENG_RIVER_TOP - 6); c.lineTo(x, KAIFENG_RIVER_TOP - h);
      c.lineTo(x + 62, KAIFENG_RIVER_TOP - h); c.lineTo(x + 62, KAIFENG_RIVER_TOP - 6); c.closePath(); c.fill();
      c.fillStyle = '#96A585';
      for (let row = 0; row < 2; row++) c.fillRect(x + 14, KAIFENG_RIVER_TOP - h + 18 + row * 24, 12, 14);
      c.fillRect(x + 38, KAIFENG_RIVER_TOP - h + 18, 12, 14);
    }
    const roofs: string[] = ['#7E8A63', '#8B9670', '#74805A'];
    for (let index = 0; index < 5; index++) {
      const x = 30 + index * 202;
      const base = KAIFENG_RIVER_TOP - 10;
      const height = 96 + (index % 2) * 26;
      c.fillStyle = '#D5C9A2'; c.fillRect(x, base - height, 122, height);
      c.fillStyle = roofs[index % 3];
      c.beginPath(); c.moveTo(x - 14, base - height);
      c.quadraticCurveTo(x + 61, base - height - 36, x + 136, base - height);
      c.closePath(); c.fill();
      c.fillStyle = '#6E6A4A'; c.fillRect(x + 22, base - height * 0.6, 24, height * 0.6);
      c.fillRect(x + 74, base - height * 0.6, 24, height * 0.6);
    }
  }

  private street(): void {
    const c = this.context;
    const left = KAIFENG_STREET_X - KAIFENG_STREET_HALF;
    const right = KAIFENG_STREET_X + KAIFENG_STREET_HALF;
    c.fillStyle = '#D8CDA8';
    c.fillRect(left, 0, right - left, KAIFENG_RIVER_TOP - 6);
    c.fillRect(left, KAIFENG_RIVER_BOTTOM + 6, right - left, KAIFENG_BOARD_HEIGHT - KAIFENG_RIVER_BOTTOM);
    this.line(left, 0, left, KAIFENG_RIVER_TOP - 6, '#B7A97E', 2.4);
    this.line(right, 0, right, KAIFENG_RIVER_TOP - 6, '#B7A97E', 2.4);
    this.line(left, KAIFENG_RIVER_BOTTOM + 6, left, KAIFENG_BOARD_HEIGHT, '#B7A97E', 2.4);
    this.line(right, KAIFENG_RIVER_BOTTOM + 6, right, KAIFENG_BOARD_HEIGHT, '#B7A97E', 2.4);
    c.fillStyle = '#C8B98E';
    c.fillRect(left - 18, KAIFENG_RIVER_TOP - 24, (right - left) + 36, 18);
    c.fillRect(left - 18, KAIFENG_RIVER_BOTTOM + 8, (right - left) + 36, 18);
  }

  private river(): void {
    const c = this.context;
    c.beginPath(); c.moveTo(0, KAIFENG_RIVER_TOP);
    c.bezierCurveTo(280, KAIFENG_RIVER_TOP - 16, 620, KAIFENG_RIVER_TOP + 18, 1000, KAIFENG_RIVER_TOP - 6);
    c.lineTo(1000, KAIFENG_RIVER_BOTTOM);
    c.bezierCurveTo(640, KAIFENG_RIVER_BOTTOM + 18, 320, KAIFENG_RIVER_BOTTOM - 16, 0, KAIFENG_RIVER_BOTTOM + 6);
    c.closePath();
    const water = c.createLinearGradient(0, KAIFENG_RIVER_TOP, 0, KAIFENG_RIVER_BOTTOM);
    water.addColorStop(0, '#66A089'); water.addColorStop(0.3, '#2C6E5E'); water.addColorStop(1, '#154439');
    c.fillStyle = water; c.fill();
    c.beginPath(); c.moveTo(0, KAIFENG_RIVER_TOP);
    c.bezierCurveTo(280, KAIFENG_RIVER_TOP - 16, 620, KAIFENG_RIVER_TOP + 18, 1000, KAIFENG_RIVER_TOP - 6);
    c.strokeStyle = '#DCCCA0'; c.lineWidth = 7; c.stroke();
    for (let index = 0; index < 26; index++) {
      const x = -20 + index * 42;
      const y = 930 + Math.sin(index * 0.7) * 12 + (index % 4) * 26;
      c.beginPath(); c.moveTo(x, y); c.quadraticCurveTo(x + 16, y - 4, x + 34, y + 1);
      c.strokeStyle = index % 5 === 0 ? '#CFE0BE' : '#8FB9A2';
      c.globalAlpha = index % 5 === 0 ? 0.55 : 0.22; c.lineWidth = index % 5 === 0 ? 2.2 : 1.3;
      c.stroke(); c.globalAlpha = 1;
    }
  }

  // 州桥：北宋低平平桥，桥下密排石柱；拱桥是明代改建后的形制。
  // 两种画法不是换皮：平桥给出“车驾平过”的读法，拱桥给出“坡陡”的读法。
  private bridge(): void {
    const c = this.context;
    const rad = this.bridgeAngle * Math.PI / 180;
    const half = KAIFENG_BRIDGE_HALF;
    const width = KAIFENG_BRIDGE_WIDTH;
    const arched = this.bridgeKind === KAIFENG_BRIDGE_ARCH;
    const crown = arched ? 40 : 5;
    const edge = (x: number): number => crown * (1 - (x / half) * (x / half));
    c.save(); c.translate(this.bridgeX, this.bridgeY); c.rotate(rad);
    c.globalAlpha = 0.20; c.fillStyle = '#0F332C';
    c.fillRect(-half, width / 2 + 5, half * 2, 18);
    c.globalAlpha = 1;
    // 平桥桥下密排石柱；拱桥是单孔，不再画柱。
    if (!arched) {
      c.fillStyle = '#7E7358';
      for (let index = 0; index <= 8; index++) {
        const x = -half + 22 + index * (half * 2 - 44) / 8;
        c.fillRect(x - 6, -width / 2 + 8, 12, width - 2);
      }
    }
    c.fillStyle = '#8C8062';
    c.fillRect(-half - 9, -width / 2 - 5, 22, width + 10);
    c.fillRect(half - 13, -width / 2 - 5, 22, width + 10);
    c.beginPath(); c.moveTo(-half, -width / 2);
    for (let index = 0; index <= 24; index++) {
      const x = -half + index * (half * 2 / 24);
      c.lineTo(x, -width / 2 - edge(x));
    }
    for (let index = 24; index >= 0; index--) {
      const x = -half + index * (half * 2 / 24);
      c.lineTo(x, width / 2 + edge(x));
    }
    c.closePath(); c.fillStyle = arched ? '#A9895A' : '#9A7B4E'; c.fill();
    for (let index = 0; index < 15; index++) {
      const x = -half + 8 + index * (half * 2 - 16) / 14;
      this.line(x, -width / 2 - edge(x) + 3, x, width / 2 + edge(x) - 3, '#7C6039', 1.6);
    }
    for (let side = 0; side < 2; side++) {
      const sign = side === 0 ? -1 : 1;
      c.beginPath();
      for (let index = 0; index <= 24; index++) {
        const x = -half + index * (half * 2 / 24);
        const y = sign * (width / 2 + edge(x));
        if (index === 0) c.moveTo(x, y); else c.lineTo(x, y);
      }
      c.strokeStyle = '#E3D2A6'; c.lineWidth = 3.4; c.stroke();
    }
    this.ellipse(0, -edge(0) - 2, 7, 7, '#F0E2BC');
    c.restore();
  }

  private person(x: number, y: number, color: string, scale: number = 1): void {
    const c = this.context;
    c.save(); c.translate(x, y); c.scale(scale, scale);
    this.ellipse(0, -22, 7, 7, color);
    this.line(0, -15, 0, 4, color, 4.6);
    this.line(0, -9, -8, 2, color, 3.4);
    this.line(0, -9, 8, 2, color, 3.4);
    this.line(0, 4, -6, 14, color, 3.6);
    this.line(0, 4, 6, 14, color, 3.6);
    c.restore();
  }

  // 高桅船：桅杆是判定能不能过桥的可见依据，不能省。
  private boat(x: number, y: number, moored: boolean): void {
    const c = this.context;
    c.save(); c.translate(x, y);
    c.beginPath(); c.moveTo(-46, 0); c.bezierCurveTo(-28, 17, 28, 17, 46, -3);
    c.lineTo(37, -16); c.bezierCurveTo(16, 3, -16, 3, -37, -16); c.closePath();
    c.fillStyle = '#3B2F22'; c.fill();
    c.beginPath(); c.moveTo(-18, -12); c.bezierCurveTo(-15, -40, 17, -40, 20, -12); c.closePath();
    c.fillStyle = '#C9A870'; c.fill();
    // 桅杆：高于桥面，平桥时会被桥面截住。
    this.line(26, -8, 26, -104, '#8A6A3E', 4);
    this.line(26, -104, 8, -88, '#B08A52', 2);
    c.beginPath(); c.moveTo(26, -100); c.lineTo(26, -62); c.lineTo(8, -74); c.closePath();
    c.fillStyle = 'rgba(220,196,146,0.85)'; c.fill();
    if (moored) {
      c.fillStyle = '#8A6A3E';
      c.fillRect(-30, -22, 16, 14); c.fillRect(-10, -24, 18, 16);
      this.line(-40, 2, -40, -18, '#6E5634', 3);
    }
    c.globalAlpha = 0.4;
    c.beginPath(); c.moveTo(-50, 4); c.quadraticCurveTo(-74, 8, -98, 4);
    c.strokeStyle = '#CFE2C9'; c.lineWidth = 2; c.stroke();
    c.restore(); c.globalAlpha = 1;
  }

  private breakMark(x: number, y: number): void {
    const c = this.context;
    c.globalAlpha = 0.9;
    this.line(x - 15, y, x + 15, y, R.cinnabar, 3);
    this.line(x - 7, y - 7, x + 7, y + 7, R.cinnabar, 2.4);
    this.line(x - 7, y + 7, x + 7, y - 7, R.cinnabar, 2.4);
    c.globalAlpha = 1;
  }

  // 东岸泊位：船在这里卸货，西河换平船。位置与领域层常量一致。
  private mooringMark(): void {
    const c = this.context;
    c.save();
    c.setLineDash([10, 8]);
    c.strokeStyle = 'rgba(236,222,184,0.85)'; c.lineWidth = 3;
    c.beginPath();
    c.arc(KAIFENG_BOAT_MOORING.x, KAIFENG_BOAT_MOORING.y, 70, 0, Math.PI * 2);
    c.stroke(); c.setLineDash([]);
    c.restore();
  }

  // 车驾：平桥时在桥上，拱桥时停在坡下——这是“州桥为什么低平”的可见后果。
  private cart(arch: boolean): void {
    const baseX = KAIFENG_STREET_X - 8;
    const baseY = arch ? KAIFENG_RIVER_TOP - 74 : KAIFENG_RIVER_TOP - 150;
    const c = this.context;
    c.save(); c.translate(baseX, baseY);
    if (arch) c.rotate(-0.22);
    c.fillStyle = '#5B4A36';
    c.fillRect(-26, -26, 52, 20);
    this.ellipse(-18, 0, 11, 11, '#3F3326');
    this.ellipse(18, 0, 11, 11, '#3F3326');
    this.ellipse(-18, 0, 4, 4, '#C9B78F');
    this.ellipse(18, 0, 4, 4, '#C9B78F');
    this.line(-30, -30, 30, -30, '#8A6A3E', 3);
    c.restore();
    if (arch) this.breakMark(baseX + 40, baseY + 4);
  }

  // —— 幕二：剖面 ——

  private section(): void {
    const c = this.context;
    // 纸页压暗，让剖面成为主角。
    c.fillStyle = '#EDE8D6'; c.fillRect(0, 0, KAIFENG_BOARD_WIDTH, KAIFENG_BOARD_HEIGHT);
    // 天空与“今日发掘面”
    c.fillStyle = '#DCE3D2'; c.fillRect(0, 0, KAIFENG_BOARD_WIDTH, SECTION_TOP - 20);
    c.fillStyle = '#8A9472';
    c.fillRect(0, SECTION_TOP - 20, KAIFENG_BOARD_WIDTH, 6);
    // 土层主体
    c.fillStyle = '#C9B78C'; c.fillRect(SECTION_LEFT, BAND_UPPER_TOP, SECTION_RIGHT - SECTION_LEFT,
      BAND_LOWER_BOTTOM - BAND_UPPER_TOP);
    // 淤埋层：沙土点
    c.fillStyle = '#D8C79C'; c.fillRect(SECTION_LEFT, BAND_UPPER_TOP, SECTION_RIGHT - SECTION_LEFT,
      BAND_UPPER_BOTTOM - BAND_UPPER_TOP);
    for (let index = 0; index < 90; index++) {
      const x = SECTION_LEFT + 14 + (index * 73) % (SECTION_RIGHT - SECTION_LEFT - 28);
      const y = BAND_UPPER_TOP + 12 + (index * 47) % (BAND_UPPER_BOTTOM - BAND_UPPER_TOP - 24);
      this.ellipse(x, y, 3, 2, '#B9A67A');
    }
    // 明代桥体层：砖缝
    c.fillStyle = '#BFA77E'; c.fillRect(SECTION_LEFT, BAND_UPPER_BOTTOM, SECTION_RIGHT - SECTION_LEFT,
      BAND_MIDDLE_BOTTOM - BAND_UPPER_BOTTOM);
    c.strokeStyle = 'rgba(126,104,70,0.5)'; c.lineWidth = 1.4;
    for (let row = 0; row < 6; row++) {
      const y = BAND_UPPER_BOTTOM + 16 + row * 30;
      c.beginPath(); c.moveTo(SECTION_LEFT, y); c.lineTo(SECTION_RIGHT, y); c.stroke();
      for (let col = 0; col < 6; col++) {
        const x = SECTION_LEFT + 30 + col * 130 + (row % 2) * 60;
        c.beginPath(); c.moveTo(x, y); c.lineTo(x, y + 30); c.stroke();
      }
    }
    // 宋代桥基与石壁层
    c.fillStyle = '#B7A98A'; c.fillRect(SECTION_LEFT, BAND_MIDDLE_BOTTOM, SECTION_RIGHT - SECTION_LEFT,
      BAND_LOWER_BOTTOM - BAND_MIDDLE_BOTTOM);
    for (let row = 0; row < 7; row++) {
      const y = BAND_MIDDLE_BOTTOM + 18 + row * 26;
      this.line(SECTION_LEFT + 180, y, SECTION_RIGHT - 120, y, '#8E7F62', 1.6);
    }
    // 石壁：16 层石块
    c.fillStyle = '#A79878'; c.fillRect(SECTION_LEFT + 150, BAND_MIDDLE_BOTTOM + 22, 250, 172);
    for (let row = 0; row < 16; row++) {
      const y = BAND_MIDDLE_BOTTOM + 22 + row * 10.7;
      this.line(SECTION_LEFT + 150, y, SECTION_LEFT + 400, y, 'rgba(110,94,66,0.55)', 1);
    }
    // 层带边界
    this.line(SECTION_LEFT, BAND_UPPER_TOP, SECTION_RIGHT, BAND_UPPER_TOP, '#8E7F62', 3);
    this.line(SECTION_LEFT, BAND_UPPER_BOTTOM, SECTION_RIGHT, BAND_UPPER_BOTTOM, '#8E7F62', 3);
    this.line(SECTION_LEFT, BAND_MIDDLE_BOTTOM, SECTION_RIGHT, BAND_MIDDLE_BOTTOM, '#8E7F62', 3);
    this.line(SECTION_LEFT, BAND_LOWER_BOTTOM, SECTION_RIGHT, BAND_LOWER_BOTTOM, '#8E7F62', 3);
    // 宋代平桥与明代拱桥的轮廓：叠层齐了才出现。
    if (this.layersComplete) {
      c.strokeStyle = 'rgba(90,74,48,0.75)'; c.lineWidth = 5;
      c.beginPath();
      c.moveTo(220, BAND_MIDDLE_BOTTOM - 4);
      c.quadraticCurveTo(MOTIF_CENTER_X - 20, BAND_UPPER_BOTTOM - 24, 780, BAND_MIDDLE_BOTTOM - 4);
      c.stroke();
      c.lineWidth = 3; c.strokeStyle = 'rgba(120,100,68,0.8)';
      c.beginPath();
      c.moveTo(200, BAND_LOWER_BOTTOM - 18); c.lineTo(800, BAND_LOWER_BOTTOM - 18);
      c.stroke();
    }
    // 已放下的材料：在层带里压一枚朱色书签。原先画的是没有字的白条，
    // 在真机上看像两个加载失败的占位框。
    this.placedSlip('song-base', BAND_MIDDLE_BOTTOM, BAND_LOWER_BOTTOM);
    this.placedSlip('ming-deck', BAND_UPPER_BOTTOM, BAND_MIDDLE_BOTTOM);
    this.placedSlip('burial-silt', BAND_UPPER_TOP, BAND_UPPER_BOTTOM);
    if (this.layersComplete) this.motifPlate();
  }

  private placedSlip(id: string, top: number, bottom: number): void {
    if (this.placed.indexOf(id) < 0) return;
    const c = this.context;
    c.save();
    c.fillStyle = 'rgba(166,76,55,0.82)';
    c.fillRect(SECTION_RIGHT - 14, top + 12, 14, Math.max(30, bottom - top - 24));
    c.fillStyle = 'rgba(250,243,224,0.9)';
    c.fillRect(SECTION_RIGHT - 10, top + 26, 6, 6);
    c.restore();
  }

  // 石语：四片残纹的拓片盘。槽位与判定在领域层，这里只画位置。
  private motifPlate(): void {
    const c = this.context;
    c.save();
    // 拓片盘半透明：它是盖在剖面上的阅读卡，不该把桥的轮廓整块糊掉。
    c.fillStyle = 'rgba(246,238,218,0.55)';
    c.fillRect(MOTIF_LEFT, MOTIF_TOP, MOTIF_SIZE, MOTIF_SIZE);
    c.strokeStyle = 'rgba(140,116,78,0.8)'; c.lineWidth = 3;
    c.strokeRect(MOTIF_LEFT, MOTIF_TOP, MOTIF_SIZE, MOTIF_SIZE);
    c.restore();
    const slots: number[][] = [
      [MOTIF_CENTER_X, MOTIF_CENTER_Y - 40, 0],
      [MOTIF_CENTER_X - 96, MOTIF_CENTER_Y - 40, 1],
      [MOTIF_CENTER_X + 96, MOTIF_CENTER_Y - 40, 2],
      [MOTIF_CENTER_X, MOTIF_CENTER_Y + 96, 3]
    ];
    const filled: string[] = [this.motifCenter, this.motifLeft, this.motifRight, this.motifBottom];
    for (const slot of slots) {
      // 已放好的位置不再留虚线圈：拓片合拢后应该只剩画面，不该还插着四条“待填”。
      if (filled[slot[2]].length > 0) continue;
      const c2 = this.context;
      c2.save();
      c2.setLineDash([8, 6]);
      c2.strokeStyle = 'rgba(140,116,78,0.6)'; c2.lineWidth = 2;
      c2.beginPath(); c2.arc(slot[0], slot[1], 40, 0, Math.PI * 2); c2.stroke();
      c2.setLineDash([]); c2.restore();
    }
    if (this.motifComplete) {
      const c3 = this.context;
      c3.strokeStyle = 'rgba(166,76,55,0.75)'; c3.lineWidth = 4;
      c3.strokeRect(MOTIF_LEFT + 6, MOTIF_TOP + 6, MOTIF_SIZE - 12, MOTIF_SIZE - 12);
    }
    // 放好的残纹要真的画出来：原来合拢后只剩一圈红线，玩家摆完看不到任何东西。
    if (this.motifCenter.length > 0) this.horseGlyph(MOTIF_CENTER_X, MOTIF_CENTER_Y - 40);
    if (this.motifLeft.length > 0) this.craneGlyph(MOTIF_CENTER_X - 96, MOTIF_CENTER_Y - 40, false);
    if (this.motifRight.length > 0) this.craneGlyph(MOTIF_CENTER_X + 96, MOTIF_CENTER_Y - 40, true);
    if (this.motifBottom.length > 0) this.cloudGlyph(MOTIF_CENTER_X, MOTIF_CENTER_Y + 96);
  }

  // 三组纹样用极简线描表示：这是“拓片示意”，不是文物纹样的复原。
  private horseGlyph(cx: number, cy: number): void {
    const c = this.context;
    c.save(); c.translate(cx, cy);
    c.strokeStyle = 'rgba(86,68,44,0.88)'; c.lineWidth = 3; c.lineCap = 'round';
    c.beginPath(); c.ellipse(0, 0, 22, 12, 0, 0, Math.PI * 2); c.stroke();
    c.beginPath(); c.moveTo(15, -7); c.quadraticCurveTo(24, -16, 26, -28); c.stroke();
    c.beginPath(); c.moveTo(26, -28); c.lineTo(34, -23); c.stroke();
    c.beginPath(); c.moveTo(26, -28); c.lineTo(24, -35); c.stroke();
    for (let leg = 0; leg < 2; leg++) {
      const x = -12 + leg * 22;
      c.beginPath(); c.moveTo(x, 9); c.lineTo(x - 3, 24); c.stroke();
    }
    c.beginPath(); c.moveTo(-21, -2); c.quadraticCurveTo(-32, 2, -34, 14); c.stroke();
    c.restore();
  }

  private craneGlyph(cx: number, cy: number, mirrored: boolean): void {
    const c = this.context;
    c.save(); c.translate(cx, cy); if (mirrored) c.scale(-1, 1);
    c.strokeStyle = 'rgba(86,68,44,0.88)'; c.lineWidth = 3; c.lineCap = 'round';
    c.beginPath(); c.ellipse(0, 0, 15, 8, -0.15, 0, Math.PI * 2); c.stroke();
    c.beginPath(); c.moveTo(9, -5); c.quadraticCurveTo(17, -18, 13, -30); c.stroke();
    c.beginPath(); c.arc(13, -32, 4, 0, Math.PI * 2); c.stroke();
    c.beginPath(); c.moveTo(17, -33); c.lineTo(24, -31); c.stroke();
    c.beginPath(); c.moveTo(-3, 6); c.lineTo(-5, 22); c.stroke();
    c.beginPath(); c.moveTo(4, 6); c.lineTo(7, 22); c.stroke();
    c.beginPath(); c.moveTo(-14, -1); c.lineTo(-23, -8); c.stroke();
    c.restore();
  }

  private cloudGlyph(cx: number, cy: number): void {
    const c = this.context;
    c.save(); c.translate(cx, cy);
    c.strokeStyle = 'rgba(86,68,44,0.88)'; c.lineWidth = 3;
    c.beginPath(); c.arc(-16, 0, 10, Math.PI * 0.5, Math.PI * 1.5); c.stroke();
    c.beginPath(); c.arc(0, -6, 13, Math.PI, Math.PI * 2); c.stroke();
    c.beginPath(); c.arc(16, 0, 10, Math.PI * 1.5, Math.PI * 0.5); c.stroke();
    c.beginPath(); c.moveTo(-16, 10); c.lineTo(16, 10); c.stroke();
    c.restore();
  }

  // —— 幕三：夜市 ——

  // 入夜：整幅压一层冷色，再在每盏灯处铺一圈暖光。
  // 不用 destination-out 打洞——那会把底下的城一起擦掉；暖光叠在夜色之上即可。
  private nightVeil(): void {
    const c = this.context;
    c.save();
    c.fillStyle = 'rgba(16,30,44,0.45)';
    c.fillRect(0, 0, KAIFENG_BOARD_WIDTH, KAIFENG_BOARD_HEIGHT);
    this.lights.forEach((light: KaifengLightPoint) => {
      const glow = c.createRadialGradient(light.x, light.y, 8, light.x, light.y, KAIFENG_LIGHT_RADIUS);
      glow.addColorStop(0, 'rgba(255,214,142,0.55)');
      glow.addColorStop(0.55, 'rgba(255,196,116,0.22)');
      glow.addColorStop(1, 'rgba(255,196,116,0)');
      c.fillStyle = glow;
      c.beginPath();
      c.arc(light.x, light.y, KAIFENG_LIGHT_RADIUS, 0, Math.PI * 2);
      c.fill();
    });
    c.restore();
  }

  private stalls(): void {
    const coverage = kaifengCoverage(this.lights);
    KAIFENG_STALLS.forEach((stall: KaifengStall) => {
      const lit = coverage.covered.indexOf(stall.id) >= 0;
      const c = this.context;
      c.save();
      // 没点亮的摊也要看得见：0.42 在夜色上几乎消失，玩家会以为场上只有三盏灯。
      c.globalAlpha = lit ? 1 : 0.72;
      // 摊棚
      // 摊棚：放大到看得清是“摊”而不是一个小方块。
      c.fillStyle = lit ? '#B98A4E' : '#8F8672';
      c.beginPath(); c.moveTo(stall.x - 84, stall.y); c.lineTo(stall.x + 84, stall.y);
      c.lineTo(stall.x + 68, stall.y - 50); c.lineTo(stall.x - 68, stall.y - 50); c.closePath(); c.fill();
      c.fillStyle = lit ? '#E9CD92' : '#C9BFA8';
      c.fillRect(stall.x - 64, stall.y, 128, 50);
      c.fillStyle = lit ? '#7A5A32' : '#6E6656';
      c.fillRect(stall.x - 52, stall.y + 10, 104, 8);
      // 摊前的人
      this.person(stall.x - 34, stall.y + 78, lit ? '#4B4536' : '#6F6A5A', 1.15);
      this.person(stall.x + 30, stall.y + 74, lit ? '#5B4A36' : '#6F6A5A', 1.05);
      c.restore();
    });
  }

  private drawLights(): void {
    this.lights.forEach((light: KaifengLightPoint) => {
      const c = this.context;
      const warm = this.lanternPaper === 'dye' ? 'rgba(228,164,96,' :
        this.lanternPaper === 'gold' ? 'rgba(238,206,132,' : 'rgba(232,206,150,';
      const glow = c.createRadialGradient(light.x, light.y, 8, light.x, light.y, KAIFENG_LIGHT_RADIUS);
      glow.addColorStop(0, `${warm}0.5)`); glow.addColorStop(0.45, `${warm}0.2)`); glow.addColorStop(1, `${warm}0)`);
      c.fillStyle = glow;
      c.fillRect(light.x - KAIFENG_LIGHT_RADIUS, light.y - KAIFENG_LIGHT_RADIUS,
        KAIFENG_LIGHT_RADIUS * 2, KAIFENG_LIGHT_RADIUS * 2);
      this.lanternShape(light.x, light.y, true);
    });
  }

  private lanternShape(x: number, y: number, lit: boolean): void {
    const c = this.context;
    const body = lit ? '#EBC078' : '#9A8759';
    c.save(); c.translate(x, y); c.scale(1.15, 1.15);
    if (this.lanternFrame === 'fold') {
      c.beginPath(); c.moveTo(0, -20); c.lineTo(18, 0); c.lineTo(0, 20); c.lineTo(-18, 0); c.closePath();
      c.fillStyle = body; c.fill();
      this.line(0, -20, 0, 20, lit ? '#B98F4C' : '#8E7C50', 1.6);
      this.line(-18, 0, 18, 0, lit ? '#B98F4C' : '#8E7C50', 1.6);
    } else if (this.lanternFrame === 'water') {
      c.beginPath(); c.moveTo(0, -20);
      c.bezierCurveTo(16, -11, 16, 11, 0, 20);
      c.bezierCurveTo(-16, 11, -16, -11, 0, -20); c.closePath();
      c.fillStyle = body; c.fill();
      for (let index = -1; index <= 1; index++) {
        c.beginPath(); c.moveTo(index * 8, -16);
        c.quadraticCurveTo(index * 12, 0, index * 8, 16);
        c.strokeStyle = lit ? '#B98F4C' : '#8E7C50'; c.lineWidth = 1.4; c.stroke();
      }
    } else {
      this.ellipse(0, 0, 19, 21, body);
      this.line(0, -21, 0, 21, lit ? '#C08F4C' : '#8E7C50', 1.4);
    }
    this.line(-9, -22, 9, -22, '#8C6A3E', 2.4);
    this.line(0, 21, 0, 30, '#A64C37', 2);
    c.restore();
  }

  // —— 绘制入口 ——

  private draw(): void {
    if (!this.ready) return;
    const c = this.context;
    c.setTransform(1, 0, 0, 1, 0, 0);
    c.clearRect(0, 0, this.widthVp, this.heightVp);
    c.fillStyle = '#E4E3CE'; c.fillRect(0, 0, this.widthVp, this.heightVp);
    c.save();
    c.translate(this.originX(), this.originY());
    c.scale(this.unit(), this.unit());

    if (this.stage === 1) {
      this.section();
      c.restore();
      return;
    }

    this.paper();
    this.skyline();
    this.street();
    if (this.hintHighlight === 'street') {
      c.globalAlpha = 0.18; c.fillStyle = R.gold;
      c.fillRect(KAIFENG_STREET_X - KAIFENG_STREET_HALF - 10, 40, (KAIFENG_STREET_HALF + 10) * 2,
        KAIFENG_BOARD_HEIGHT - 80);
      c.globalAlpha = 1;
    }
    this.river();
    // 幕一先画泊位与船、再画桥：桥面压住船身，才读得出“从桥下过/过不去”。
    if (this.stage === 0) this.mooringMark();
    this.boat(this.boatX, this.boatY, this.boatSpot === 'mooring');
    this.bridge();

    if (this.stage === 0) {
      this.cart(this.bridgeKind === KAIFENG_BRIDGE_ARCH);
      // 四个角色：人不是装饰，状态随判定变化。
      const arch = this.bridgeKind === KAIFENG_BRIDGE_ARCH;
      this.person(KAIFENG_STREET_X + 44, arch ? KAIFENG_RIVER_TOP - 40 : KAIFENG_RIVER_TOP - 118, '#3E4A3C', 1.2);
      this.person(760, 1010 + 26, '#3A3A46', 0.95);
      // 东岸泊位旁再站一个船工：他的点击框在这里，画面也得有对应的人，
      // 否则会出现“点得到人、看不见人”。
      this.person(KAIFENG_BOAT_MOORING.x, 1214, '#3A3A46', 1.0);
      this.person(KAIFENG_STREET_X + 40, 1490, '#4B3F35', 1.15);
      this.person(560, 1320, '#5A4636', 1.05);
    } else {
      // 第三幕先落夜，再画摊与灯：不压暗的话“夜市长明”在白天城景里读不出来。
      this.nightVeil();
      this.stalls();
      this.drawLights();
    }
    c.restore();
  }

  // —— 热区与托盘 ——

  private knobX(): number {
    return this.bridgeX + Math.cos(this.bridgeAngle * Math.PI / 180) * (KAIFENG_BRIDGE_HALF + 34);
  }
  private knobY(): number {
    return this.bridgeY + Math.sin(this.bridgeAngle * Math.PI / 180) * (KAIFENG_BRIDGE_HALF + 34);
  }

  private isDragging(key: string): boolean { return this.dragging === key; }
  private tokenOffsetX(key: string): number { return this.isDragging(key) ? this.dragDX : 0; }
  private tokenOffsetY(key: string): number { return this.isDragging(key) ? this.dragDY : 0; }
  private startDrag(key: string): void { this.dragging = key; this.dragDX = 0; this.dragDY = 0; }
  private endDrag(): void { this.dragging = ''; this.dragDX = 0; this.dragDY = 0; }

  private evidenceSlot(index: number): number[] {
    const size = 78;
    const gap = 8;
    const total = size * 4 + gap * 3;
    // 托盘要抬到底部判读条之上：它原来贴在画布底边，整排落在判读条后面，
    // 既看不清也拖不出来。
    return [(this.widthVp - total) / 2 + index * (size + gap), this.heightVp - 196, size, 52];
  }

  private motifSlotRect(index: number): number[] {
    // 与材料托盘同一行：原先四片残纹竖着堆在左缘，卡片比剖面还大，
    // 把层带标签全压住了。
    const size = 78;
    const gap = 8;
    const total = size * 4 + gap * 3;
    return [(this.widthVp - total) / 2 + index * (size + gap), this.heightVp - 196, size, 52];
  }

  private partSlot(kind: string, index: number): number[] {
    // 六枚材质收成底部一行：原来左右各三枚竖排，把街两侧和灯全压住了。
    const size = 52;
    const gap = 4;
    const total = size * 6 + gap * 5;
    const slot = kind === 'frame' ? index : 3 + index;
    // 固定在章头下方那条空白带：底部面板会随“祝愿 + AI 校书”长高到 1928，
    // 任何贴近底部的托盘都会在不同阶段被吃掉；这里始终可见、也碰不到摊。
    return [(this.widthVp - total) / 2 + slot * (size + gap), 92, size, 52];
  }

  private dropEvidence(id: string, slot: number[]): void {
    const cx = this.boardX(slot[0] + slot[2] / 2 + this.dragDX);
    const cy = this.boardY(slot[1] + slot[3] / 2 + this.dragDY);
    let band = '';
    let distance = 0;
    if (cx < SECTION_LEFT || cx > SECTION_RIGHT) {
      distance = 999;
    } else if (cy >= BAND_UPPER_TOP && cy <= BAND_UPPER_BOTTOM) {
      band = 'upper';
    } else if (cy > BAND_UPPER_BOTTOM && cy <= BAND_MIDDLE_BOTTOM) {
      band = 'middle';
    } else if (cy > BAND_MIDDLE_BOTTOM && cy <= BAND_LOWER_BOTTOM) {
      band = 'lower';
    } else {
      distance = 999;
    }
    this.onEvidenceDrop(id, band, distance);
    this.endDrag();
  }

  private dropMotif(pieceId: string, slot: number[]): void {
    const cx = this.boardX(slot[0] + slot[2] / 2 + this.dragDX);
    const cy = this.boardY(slot[1] + slot[3] / 2 + this.dragDY);
    const candidates: MotifTarget[] = [
      { x: MOTIF_CENTER_X, y: MOTIF_CENTER_Y - 40, slot: 'center' },
      { x: MOTIF_CENTER_X - 96, y: MOTIF_CENTER_Y - 40, slot: 'left' },
      { x: MOTIF_CENTER_X + 96, y: MOTIF_CENTER_Y - 40, slot: 'right' },
      { x: MOTIF_CENTER_X, y: MOTIF_CENTER_Y + 96, slot: 'bottom' }
    ];
    let best = '';
    let bestDistance = 10000;
    for (const candidate of candidates) {
      const dx = cx - candidate.x;
      const dy = cy - candidate.y;
      const distance = Math.sqrt(dx * dx + dy * dy);
      if (distance < bestDistance) { bestDistance = distance; best = candidate.slot; }
    }
    this.onMotifDrop(pieceId, bestDistance <= 140 ? best : '');
    this.endDrag();
  }

  private dropLight(index: number, slot: number[]): void {
    const cx = this.boardX(slot[0] + slot[2] / 2 + this.dragDX);
    const cy = this.boardY(slot[1] + slot[3] / 2 + this.dragDY);
    this.onLightMove(index, Math.max(60, Math.min(KAIFENG_BOARD_WIDTH - 60, cx)),
      Math.max(80, Math.min(KAIFENG_BOARD_HEIGHT - 80, cy)));
    this.endDrag();
  }

  @Builder
  tokenShell(kind: string, itemId: string, nodeId: string, slot: number[], label: string,
    badge: string, selected: boolean) {
    Column({ space: 1 }) {
      if (badge.length > 0) { Text(badge).fontSize(10).fontColor(R.cinnabar) }
      Text(label).fontSize(12).fontColor(selected ? R.cinnabar : R.ink).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(slot[2]).height(slot[3]).justifyContent(FlexAlign.Center)
    .backgroundColor(selected ? 'rgba(251,241,220,0.96)' : 'rgba(252,248,237,0.94)')
    .border({ width: 1, color: selected ? R.cinnabar : '#CBBB96', radius: 4 }).borderRadius(4)
    .shadow({ radius: 8, color: 'rgba(60,52,30,0.20)', offsetX: 0, offsetY: 3 })
    .position({ x: slot[0] + this.tokenOffsetX(nodeId), y: slot[1] + this.tokenOffsetY(nodeId) })
    .zIndex(this.isDragging(nodeId) ? 20 : 2)
    .id(nodeId)
    .accessibilityText(label)
    .onClick(() => {
      // 灯骨/灯纸是“点选”而不是拖动：点一下换材质，三盏灯一起变。
      if (kind === 'part') this.onLanternPart(kind, itemId);
    })
    .gesture(
      PanGesture({ fingers: 1, distance: 2 })
        .onActionStart(() => this.startDrag(nodeId))
        .onActionUpdate((event: GestureEvent) => { this.dragDX = event.offsetX; this.dragDY = event.offsetY; })
        .onActionEnd(() => {
          if (kind === 'evidence') this.dropEvidence(itemId, slot);
          else if (kind === 'motif') this.dropMotif(itemId, slot);
          else if (kind === 'light') this.dropLight(Number(itemId), slot);
          else this.endDrag();
        })
    )
  }

  @Builder
  roleToken(x: number, y: number, id: string, line: string) {
    Stack() {
      if (this.roleBubble === id) {
        Text(line).fontSize(12).lineHeight(17).fontColor(R.ink).width(190)
          .padding(9).backgroundColor('rgba(251,243,224,0.97)')
          .border({ width: 1, color: '#CBBB96', radius: 4 }).borderRadius(4)
          .position({ x: -95, y: -96 })
      }
      Column().width(48).height(48).backgroundColor(Color.Transparent)
        .onClick(() => { this.roleBubble = this.roleBubble === id ? '' : id; })
    }.width(48).height(48).position({ x: this.px(x) - 24, y: this.py(y) - 24 })
      .zIndex(8)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Canvas(this.context)
        .width('100%').height('100%')
        .onReady(() => { this.ready = true; this.draw(); })
        .hitTestBehavior(HitTestMode.None)
        .id('kaifeng-board')

      if (this.stage === 0) {
        // 桥片：整体平移。
        Column()
          .width(this.len(KAIFENG_BRIDGE_HALF * 2) + 12)
          .height(this.len(KAIFENG_BRIDGE_WIDTH) + 34)
          .backgroundColor(Color.Transparent)
          .position({
            x: this.px(this.bridgeX) - (this.len(KAIFENG_BRIDGE_HALF * 2) + 12) / 2,
            y: this.py(this.bridgeY) - (this.len(KAIFENG_BRIDGE_WIDTH) + 34) / 2
          })
          .rotate({ angle: this.bridgeAngle })
          .id('kaifeng-bridge')
          .zIndex(11)
          .accessibilityText('桥片，可拖动摆放')
          .gesture(
            PanGesture({ fingers: 1, distance: 3 })
              .onActionStart(() => { this.dragOriginX = this.bridgeX; this.dragOriginY = this.bridgeY; })
              .onActionUpdate((event: GestureEvent) => {
                // 桥片本身带 rotate(angle)，手势 offset 因此是“桥自身的坐标系”，
                // 不是纸页坐标。直接拿来加会沿着转过的轴漂移：实测把桥从街口往下拖，
                // 20° 时横向少走 2/3、纵向多走 1/8。这里先把手势位移转回纸页坐标。
                const rad = this.bridgeAngle * Math.PI / 180;
                const cos = Math.cos(rad);
                const sin = Math.sin(rad);
                const gx = event.offsetX * cos - event.offsetY * sin;
                const gy = event.offsetX * sin + event.offsetY * cos;
                this.onBridgeMove(
                  Math.max(90, Math.min(KAIFENG_BOARD_WIDTH - 90, this.dragOriginX + gx / this.unit())),
                  Math.max(120, Math.min(KAIFENG_BOARD_HEIGHT - 120, this.dragOriginY + gy / this.unit())),
                  this.bridgeAngle
                );
              })
              .onActionEnd(() => this.onBridgeSettle())
          )

        // 转向铜环：单指绕着桥心拖。
        Column()
          .width(56).height(56).backgroundColor(Color.Transparent)
          .position({ x: this.px(this.knobX()) - 28, y: this.py(this.knobY()) - 28 })
          .id('kaifeng-turn-knob')
          .zIndex(12)
          .accessibilityText('转向手柄，拖动改变桥的方向')
          .gesture(
            PanGesture({ fingers: 1, distance: 2 })
              .onActionStart(() => { this.knobOriginX = this.knobX(); this.knobOriginY = this.knobY(); })
              .onActionUpdate((event: GestureEvent) => {
                const px = this.knobOriginX + event.offsetX / this.unit();
                const py = this.knobOriginY + event.offsetY / this.unit();
                const dx = px - this.bridgeX;
                const dy = py - this.bridgeY;
                if (Math.abs(dx) < 0.001 && Math.abs(dy) < 0.001) return;
                let angle = Math.atan2(dy, dx) * 180 / Math.PI;
                if (angle < 0) angle += 180;
                this.onBridgeMove(this.bridgeX, this.bridgeY, angle);
              })
              .onActionEnd(() => this.onBridgeSettle())
          )
        Column()
          .width(26).height(26).borderRadius(13).backgroundColor('#C9A870')
          .border({ width: 2, color: '#8C6A3E', radius: 13 })
          .position({ x: this.px(this.knobX()) - 13, y: this.py(this.knobY()) - 13 })
          .hitTestBehavior(HitTestMode.None)

        // 桥型切换不放在画布上：实测 92×40vp 的按钮正压在桥的拖动热区上，
        // 点按会与拖桥抢手势，也遮住桥身。它移到页面底部的操作条里。

        // 船：拖到东岸泊位。拖到桥下会被领域层拒绝。
        // 热区只比船身略大：此前是 120vp 的透明方块，实测会盖住桥心，
        // 拖桥时手指落在船的热区里，结果是船被拖走、桥不动。
        Column()
          .width(48).height(48).backgroundColor(Color.Transparent)
          .position({ x: this.px(this.boatX) - 24, y: this.py(this.boatY) - 24 })
          .id('kaifeng-boat')
          .zIndex(10)
          .accessibilityText('高桅船，可拖到东岸泊位')
          .gesture(
            PanGesture({ fingers: 1, distance: 3 })
              .onActionStart(() => { this.dragOriginX = this.boatX; this.dragOriginY = this.boatY; })
              .onActionUpdate((event: GestureEvent) => {
                this.dragDX = event.offsetX; this.dragDY = event.offsetY;
                this.draw();
              })
              .onActionEnd(() => {
                const x = this.dragOriginX + this.dragDX / this.unit();
                const y = this.dragOriginY + this.dragDY / this.unit();
                this.onBoatMove(x, y);
                this.endDrag();
              })
          )

        this.roleToken(KAIFENG_STREET_X + 44, KAIFENG_RIVER_TOP - 118, 'cart',
          '车驾：桥面不能陡。州桥低平，车驾才过得去。')
        // 船工站在东岸泊位旁，而不是站在船上：他原先的点击框正好盖住船心，
        // 船上就没有能落手指的地方。人物仍是叙事角色，不是历史人物。
        this.roleToken(KAIFENG_BOAT_MOORING.x, 1214, 'boatman',
          '船工：州桥不通舟船。船要在东岸卸货，西河换平船。')
        this.roleToken(KAIFENG_STREET_X + 40, 1490, 'shop',
          '店家：灯照到摊前，我才敢开张。')
        this.roleToken(560, 1320, 'lantern',
          '灯匠：骨要撑得住纸，纸要透得出光。')
      }

      if (this.stage === 1) {
        // 层带标签不用 Canvas 画中文，交给原生 Text。
        Text('明末 · 淤埋').fontSize(12).fontColor('#6E5C3E')
          .position({ x: this.px(SECTION_LEFT + 14), y: this.py(BAND_UPPER_TOP + 10) })
          .hitTestBehavior(HitTestMode.None)
        Text('明代早期 · 单孔拱桥').fontSize(12).fontColor('#6E5C3E')
          .position({ x: this.px(SECTION_LEFT + 14), y: this.py(BAND_UPPER_BOTTOM + 10) })
          .hitTestBehavior(HitTestMode.None)
        Text('宋代 · 桥基与石壁').fontSize(12).fontColor('#6E5C3E')
          .position({ x: this.px(SECTION_LEFT + 14), y: this.py(BAND_MIDDLE_BOTTOM + 10) })
          .hitTestBehavior(HitTestMode.None)
        Text('今日发掘面').fontSize(11).fontColor('#6E7A5A')
          .position({ x: this.px(SECTION_LEFT), y: this.py(SECTION_TOP - 48) })
          .hitTestBehavior(HitTestMode.None)

        if (!this.layersComplete) {
          ForEach(KAIFENG_EVIDENCE, (item: KaifengEvidence, index: number) => {
            if (this.placed.indexOf(item.id) < 0) {
              this.tokenShell('evidence', item.id, `kaifeng-evidence-${item.id}`, this.evidenceSlot(index),
                item.title, item.era, false)
            }
          }, (item: KaifengEvidence) => `${item.id}:${this.placed.indexOf(item.id)}`)
        } else {
          ForEach(KAIFENG_MOTIF_PIECES, (item: KaifengMotifPiece, index: number) => {
            // UI 语法里不能写 const 语句，判断直接内联。
            if (!(this.motifCenter === item.id || this.motifLeft === item.id ||
              this.motifRight === item.id || this.motifBottom === item.id)) {
              this.tokenShell('motif', item.id, `kaifeng-motif-${item.id}`, this.motifSlotRect(index),
                item.label, '', false)
            }
          }, (item: KaifengMotifPiece) => `${item.id}:${this.motifCenter}:${this.motifLeft}:${this.motifRight}:${this.motifBottom}`)
        }
      }

      if (this.stage === 2) {
        // 摊名交给原生 Text：Canvas 画不了中文。未开张也写名字，
        // 玩家才知道“这三处是要照亮的摊”，而不是三块石头。
        ForEach(KAIFENG_STALLS, (stall: KaifengStall) => {
          Text(stall.label).fontSize(13)
            .fontWeight(kaifengCoverage(this.lights).covered.indexOf(stall.id) >= 0 ?
              FontWeight.Medium : FontWeight.Normal)
            .fontColor(kaifengCoverage(this.lights).covered.indexOf(stall.id) >= 0 ? '#F6E3B8' : '#C9C3B4')
            .position({ x: this.px(stall.x) - this.len(40), y: this.py(stall.y) - this.len(112) })
            .width(this.len(80)).textAlign(TextAlign.Center)
            .hitTestBehavior(HitTestMode.None)
        }, (stall: KaifengStall) => stall.id)
        // 三盏灯：每一盏都能拖；灯数由灯火决定，父层只传实际存在的灯。
        ForEach(this.lights, (light: KaifengLightPoint, index: number) => {
          Column()
            .width(this.len(96)).height(this.len(96)).backgroundColor(Color.Transparent)
            .position({ x: this.px(light.x) - this.len(48) + this.tokenOffsetX(`kaifeng-light-${index}`),
              y: this.py(light.y) - this.len(48) + this.tokenOffsetY(`kaifeng-light-${index}`) })
            .id(`kaifeng-light-${index}`)
            .accessibilityText(`第 ${index + 1} 盏灯，可拖到摊前`)
            .gesture(
              PanGesture({ fingers: 1, distance: 2 })
                .onActionStart(() => this.startDrag(`kaifeng-light-${index}`))
                .onActionUpdate((event: GestureEvent) => {
                  this.dragDX = event.offsetX; this.dragDY = event.offsetY; this.draw();
                })
                .onActionEnd(() => {
                  const slot: number[] = [this.px(light.x) - this.len(48), this.py(light.y) - this.len(48),
                    this.len(96), this.len(96)];
                  this.dropLight(index, slot);
                })
            )
          Text(`灯 ${index + 1}`).fontSize(10).fontColor(R.muted)
            .position({ x: this.px(light.x) - this.len(48), y: this.py(light.y) + this.len(52) })
            .hitTestBehavior(HitTestMode.None)
        }, (light: KaifengLightPoint) => `${light.id}:${light.x}:${light.y}`)

        // 灯骨与灯纸：点一下换，三盏一起换；愿签仍在页面下方选。
        ForEach(KAIFENG_FRAMES, (item: KaifengLanternOption, index: number) => {
          this.tokenShell('part', item.id, `kaifeng-part-frame-${item.id}`, this.partSlot('frame', index),
            item.label, '', this.lanternFrame === item.id)
        }, (item: KaifengLanternOption) => `frame:${item.id}:${this.lanternFrame}`)
        ForEach(KAIFENG_PAPERS, (item: KaifengLanternOption, index: number) => {
          this.tokenShell('part', item.id, `kaifeng-part-paper-${item.id}`, this.partSlot('paper', index),
            item.label, '', this.lanternPaper === item.id)
        }, (item: KaifengLanternOption) => `paper:${item.id}:${this.lanternPaper}`)
      }
    }
    .width('100%').height('100%')
    .clip(true)
    .onAreaChange((_old: Area, area: Area) => {
      this.widthVp = Number(area.width);
      this.heightVp = Number(area.height);
      this.draw();
    })
    .id('kaifeng-puzzle-scene')
  }
}
