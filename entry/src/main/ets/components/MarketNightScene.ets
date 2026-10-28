import { systemDateTime } from '@kit.BasicServicesKit';
import type { RiverMarketV2, MarketNightBatchReport, MarketNightVisit } from '../domain/RiverMarketV2';
import { marketNightForecast, NIGHT_STALL_CONFIGS } from '../domain/RiverMarketV2';
import { marketReasonName, MARKET_ZONE_NAMES } from '../data/RiverMarketCatalog';

interface MarketScenePoint { x: number; y: number; }
interface MarketSceneLot { id: number; x: number; y: number; }
interface MarketNightSceneTiming { count: number; total: number; p50: number; p95: number; max: number; }
type MarketNightPauseKind = '' | 'background' | 'inactive';
interface MarketNightScenePerfReport {
  nightId: string; round: number; batch: number; playbackKey: number; visits: number;
  widthVp: number; heightVp: number; reducedMotion: boolean; intervalMeaning: string;
  firstStaticIssueMs: MarketNightSceneTiming; staticIssueMs: MarketNightSceneTiming;
  frameIssueMs: MarketNightSceneTiming; callbackIntervalMs: MarketNightSceneTiming;
  firstCallbackWaitMs: MarketNightSceneTiming; backgroundPauseMs: MarketNightSceneTiming;
  inactivePauseMs: MarketNightSceneTiming; wallMs: number; activeWallMs: number;
}

function nightStallName(type: string): string {
  return NIGHT_STALL_CONFIGS.find(item => item.type === type)?.name || '空地';
}
function nightReasonName(reason: string): string {
  return reason === 'festival' ? '未能观灯' : marketReasonName(reason);
}

// 双 Canvas：河岸、铺子、灯和选择框只在真实经营状态改变时重画；逐客回放只画动态层。
// 每批 visits 都来自已经保存的领域结果；人数、偏好、去向与受阻原因不能由动画补造。
// 定时器只推进只读回放，不写 @State、不结算经济；隐藏或退到后台立即停帧。
@Component
export struct MarketNightScene {
  @Prop @Watch('stateChanged') state: RiverMarketV2 | undefined = undefined;
  @Prop @Watch('drawStatic') selectedLot: number = -1;
  @Prop @Watch('playChanged') report: MarketNightBatchReport | undefined = undefined;
  @Prop @Watch('playChanged') playbackKey: number = 0;
  @Prop @Watch('motion') active: boolean = true;
  @Prop @Watch('motion') reducedMotion: boolean = false;
  @Prop interactive: boolean = true;
  @Prop @Watch('drawStatic') nightId: string = 'night-1';
  @LocalStorageProp('appForeground') @Watch('motion') private foreground: boolean = true;
  onSelectLot: (lotId: number) => void = () => {};
  onPlaybackFinished: () => void = () => {};
  @State private widthVp: number = 360;
  @State private heightVp: number = 350;
  private base: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private flow: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private baseReady: boolean = false;
  private flowReady: boolean = false;
  private timer: number = -1;
  private elapsed: number = 0;
  private lastTick: number = 0;
  private finishedKey: number = -1;
  private readonly duration: number = 5200;
  private staticKey: string = '';
  // 沿用纸景的显式debug开关，EntryAbility仅为指定独立测试库与Want开启，正式默认关闭。
  // 下面全是绘制命令的CPU/回调计时，不代表GPU完成耗时、屏幕FPS或触摸端到端延迟。
  @StorageProp('paperScenePerfEnabled') private debugPerf: boolean = false;
  private staticPaintCount: number = 0;
  private perfFirstStatic: number[] = [];
  private perfStatic: number[] = [];
  private perfFrames: number[] = [];
  private perfIntervals: number[] = [];
  private perfFirstWait: number[] = [];
  private perfBackgroundPause: number[] = [];
  private perfInactivePause: number[] = [];
  private perfPlaybackKey: number = -1;
  private perfBatchOpen: boolean = false;
  private perfStartedAt: number = 0;
  private perfTimerArmedAt: number = 0;
  private perfLastCallbackAt: number = -1;
  private perfPauseKind: MarketNightPauseKind = '';
  private perfPauseStartedAt: number = 0;
  private readonly W: number = 1200;
  private readonly H: number = 900;
  private lots: MarketSceneLot[] = [ { id: 0, x: 235, y: 372 }, { id: 1, x: 300, y: 582 },
    { id: 2, x: 535, y: 312 }, { id: 3, x: 605, y: 522 },
    { id: 4, x: 835, y: 252 }, { id: 5, x: 912, y: 462 } ];

  aboutToDisappear(): void { this.stop(); this.performancePause(this.foreground ? 'inactive' : 'background'); }
  private marketScale(): number { return Math.min(this.widthVp / this.W, this.heightVp / this.H); }
  private left(): number { return (this.widthVp - this.W * this.marketScale()) * 0.5; }
  private top(): number { return (this.heightVp - this.H * this.marketScale()) * 0.5; }
  private lotTitle(lot: MarketSceneLot): string {
    const stall = this.state?.stalls.find(item => item.lotId === lot.id);
    const name = stall?.type === 'rice' ? '水饭' : stall?.type === 'meat' ? '肉食' :
      stall?.type === 'tea' ? '茶饮' : '灯棚';
    return stall?.type ? `${name}·${stall.workers}人` : '+ 开铺';
  }
  private lotLabelWidth(): number { return Math.max(62, Math.min(88, this.widthVp / 5.6)); }
  private point(lot: MarketSceneLot): MarketScenePoint {
    return { x: this.left() + lot.x * this.marketScale(), y: this.top() + (lot.y - 30) * this.marketScale() };
  }
  private stateChanged(): void { this.drawStatic(); }
  private reportCaption(): string {
    if (!this.report) return '';
    const reason = this.report.reasonCounts.filter(item => item.count > 0)
      .sort((left, right) => right.count - left.count)[0];
    const blocked = [0, 1, 2].filter(zone => this.report!.visits.some(item => !item.served && item.blockedZone === zone));
    return `本批 ${this.report.served}/${this.report.arrivals}客被接住` +
      (reason ? ` · ${nightReasonName(reason.reason)}${reason.count}客` : ' · 全部吃上了') +
      (blocked.length > 0 ? ` · 受阻${blocked.map(zone => MARKET_ZONE_NAMES[zone]).join('、')}` : '');
  }
  private lamps(): boolean[] { return this.visibleLamps(); }
  private visibleLamps(): boolean[] {
    // 开段后库存已经扣油，播放应显示本段真实用过的灯，而不是拿扣油后库存再算一次。
    // 下一段安排时则读取forecast，没油的请求灯区不画成已点亮。
    if (this.report && this.playbackKey > 0 && this.active && this.finishedKey !== this.playbackKey) {
      return this.report.effectiveLamps;
    }
    return this.state ? marketNightForecast(this.state).effectiveLamps : [false, false, false];
  }
  private stop(): void { if (this.timer >= 0) clearInterval(this.timer); this.timer = -1; }
  private perfNow(): number {
    return this.debugPerf ? systemDateTime.getUptime(systemDateTime.TimeType.STARTUP, true) / 1000000 : 0;
  }
  private rounded(value: number): number { return Math.round(value * 1000) / 1000; }
  private timing(values: number[]): MarketNightSceneTiming {
    const sorted = values.slice().sort((left: number, right: number) => left - right);
    return { count: sorted.length, total: this.rounded(sorted.reduce((sum: number, value: number) => sum + value, 0)),
      p50: sorted.length > 0 ? this.rounded(sorted[Math.floor(sorted.length * 0.5)]) : 0,
      p95: sorted.length > 0 ? this.rounded(sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * 0.95))]) : 0,
      max: sorted.length > 0 ? this.rounded(sorted[sorted.length - 1]) : 0 };
  }
  private sample(values: number[], value: number): void {
    if (!this.debugPerf) return;
    values.push(Math.max(0, value));
    // 每批约百余回调，512足以保留整批；限制数组只防止debug场景被长期挂起时无界增长。
    if (values.length > 512) values.shift();
  }
  private beginPerformance(): void {
    if (!this.debugPerf || this.perfPlaybackKey === this.playbackKey) return;
    this.perfPlaybackKey = this.playbackKey; this.perfBatchOpen = true; this.perfStartedAt = this.perfNow();
    this.perfFrames = []; this.perfIntervals = []; this.perfFirstWait = [];
    this.perfBackgroundPause = []; this.perfInactivePause = [];
    this.perfLastCallbackAt = -1; this.perfPauseKind = ''; this.perfPauseStartedAt = 0;
    // 首屏第一笔静态绘制与两批之间的真实静态改变保留到本批汇总，不能在开始回放时清掉，
    // 否则只看得到热缓存的低耗时。firstStaticIssueMs后续批次为count0，避免重复累计首屏样本。
  }
  private performancePause(kind: MarketNightPauseKind): void {
    if (!this.debugPerf || !this.perfBatchOpen || kind === this.perfPauseKind) return;
    const now = this.perfNow();
    if (this.perfPauseKind === 'background') this.sample(this.perfBackgroundPause, now - this.perfPauseStartedAt);
    else if (this.perfPauseKind === 'inactive') this.sample(this.perfInactivePause, now - this.perfPauseStartedAt);
    this.perfPauseKind = kind; this.perfPauseStartedAt = kind ? now : 0;
    this.perfLastCallbackAt = -1;
  }
  private reportPerformance(): void {
    if (!this.debugPerf || !this.perfBatchOpen || !this.report) return;
    this.performancePause('');
    const background = this.timing(this.perfBackgroundPause); const inactive = this.timing(this.perfInactivePause);
    const wall = this.perfNow() - this.perfStartedAt;
    const report: MarketNightScenePerfReport = { nightId: this.nightId, round: this.report.round,
      batch: this.report.batch, playbackKey: this.playbackKey, visits: this.report.visits.length,
      widthVp: this.rounded(this.widthVp), heightVp: this.rounded(this.heightVp), reducedMotion: this.reducedMotion,
      intervalMeaning: 'timer-callback-not-display-fps', firstStaticIssueMs: this.timing(this.perfFirstStatic),
      staticIssueMs: this.timing(this.perfStatic), frameIssueMs: this.timing(this.perfFrames),
      callbackIntervalMs: this.timing(this.perfIntervals), firstCallbackWaitMs: this.timing(this.perfFirstWait),
      backgroundPauseMs: background, inactivePauseMs: inactive, wallMs: this.rounded(wall),
      activeWallMs: this.rounded(Math.max(0, wall - background.total - inactive.total)) };
    // 每批只写一条有界JSON，毫秒保留三位，避免逐帧日志与HiLog长浮点截断。
    // inactive是资料Sheet/页面隐藏的合计：Scene只收到active，不能冒称已分清这两种原因。
    console.info(`MARKET_NIGHTS_PERF:${JSON.stringify(report)}`);
    this.perfBatchOpen = false; this.perfFirstStatic = []; this.perfStatic = [];
  }
  private playChanged(): void {
    this.stop(); this.elapsed = 0; this.finishedKey = -1; this.drawStatic(); this.drawFlow(); this.motion();
  }
  private motion(): void {
    this.stop();
    this.drawStatic();
    if (!this.foreground) this.performancePause('background');
    else if (!this.active) this.performancePause('inactive');
    if (!this.flowReady || !this.active || !this.foreground || !this.report || this.playbackKey <= 0 ||
      this.finishedKey === this.playbackKey) return;
    this.beginPerformance(); this.performancePause('');
    if (this.reducedMotion) { this.elapsed = this.duration; this.finish(); return; }
    this.lastTick = Date.now();
    if (this.debugPerf) { this.perfTimerArmedAt = this.perfNow(); this.perfLastCallbackAt = -1; }
    this.timer = setInterval(() => {
      const now = Date.now(); this.elapsed += Math.min(100, now - this.lastTick); this.lastTick = now;
      const started = this.perfNow();
      if (this.debugPerf && this.perfBatchOpen) {
        // 恢复后的首回调只记等待，不把暂停窗口混进连续回调间隔。
        if (this.perfLastCallbackAt >= 0) this.sample(this.perfIntervals, started - this.perfLastCallbackAt);
        else this.sample(this.perfFirstWait, started - this.perfTimerArmedAt);
        this.perfLastCallbackAt = started;
      }
      const drawStarted = this.perfNow();
      this.drawFlow(); this.sample(this.perfFrames, this.perfNow() - drawStarted);
      if (this.elapsed >= this.duration) this.finish();
    }, 34);
  }
  private finish(): void {
    this.stop(); this.elapsed = this.duration; this.finishedKey = this.playbackKey; this.drawFlow();
    this.reportPerformance(); this.onPlaybackFinished();
  }

  private polygon(c: CanvasRenderingContext2D, points: MarketScenePoint[], color: string): void {
    if (points.length === 0) return;
    c.beginPath(); c.moveTo(points[0].x, points[0].y);
    for (let i = 1; i < points.length; i++) c.lineTo(points[i].x, points[i].y);
    c.closePath(); c.fillStyle = color; c.fill();
  }
  private line(c: CanvasRenderingContext2D, x: number, y: number, x2: number, y2: number,
    color: string, width: number = 2): void {
    c.beginPath(); c.moveTo(x, y); c.lineTo(x2, y2); c.lineWidth = width; c.strokeStyle = color; c.stroke();
  }
  private oval(c: CanvasRenderingContext2D, x: number, y: number, rx: number, ry: number, color: string): void {
    c.beginPath(); c.ellipse(x, y, rx, ry, 0, 0, Math.PI * 2); c.fillStyle = color; c.fill();
  }
  private glow(c: CanvasRenderingContext2D, x: number, y: number, radius: number, alpha: number): void {
    const gradient = c.createRadialGradient(x, y, 0, x, y, radius);
    gradient.addColorStop(0, `rgba(246,176,80,${alpha})`);
    gradient.addColorStop(1, 'rgba(240,154,65,0)');
    c.fillStyle = gradient; c.fillRect(x - radius, y - radius, radius * 2, radius * 2);
  }
  private roof(c: CanvasRenderingContext2D, x: number, y: number, width: number, color: string): void {
    this.polygon(c, [{ x: x - width * 0.61, y: y + 14 }, { x: x - width * 0.41, y: y - 8 },
      { x: x - 8, y: y - 49 }, { x: x + width * 0.44, y: y - 15 },
      { x: x + width * 0.64, y: y - 4 }, { x: x + width * 0.32, y: y + 6 },
      { x: x - width * 0.34, y: y + 24 }], color);
    this.line(c, x - width * 0.41, y - 8, x - 8, y - 49, '#C4B48D', 3);
    for (let i = 0; i < 6; i++) this.line(c, x - 67 + i * 26, y + 8 - i * 3,
      x - 27 + i * 21, y - 31 + i * 3, 'rgba(16,30,29,0.27)', 2);
  }
  private house(c: CanvasRenderingContext2D, x: number, y: number, width: number, height: number,
    roof: string): void {
    this.polygon(c, [{ x: x - width / 2, y: y - height }, { x: x + width / 2, y: y - height - 20 },
      { x: x + width / 2, y: y - 10 }, { x: x - width / 2, y: y + 10 }], '#82785A');
    this.polygon(c, [{ x: x + width / 2, y: y - height - 20 }, { x: x + width / 2 + 32, y: y - height - 2 },
      { x: x + width / 2 + 32, y: y + 8 }, { x: x + width / 2, y: y - 10 }], '#504F40');
    this.roof(c, x, y - height, width + 22, roof);
    for (let i = 0; i < 3; i++) {
      c.fillStyle = '#C99B5A'; c.fillRect(x - width * 0.33 + i * width * 0.25, y - height * 0.65, 13, height * 0.42);
      this.line(c, x - width * 0.33 + i * width * 0.25 + 6, y - height * 0.65,
        x - width * 0.33 + i * width * 0.25 + 6, y - height * 0.23, '#6A6647', 2);
    }
  }
  private lantern(c: CanvasRenderingContext2D, x: number, y: number, lit: boolean): void {
    this.line(c, x, y, x, y + 66, '#6E755C', 3);
    if (lit) this.glow(c, x, y + 75, 84, 0.33);
    this.oval(c, x, y + 76, 13, 18, lit ? '#F4BD70' : '#806A4D');
    this.line(c, x - 7, y + 60, x + 7, y + 60, '#CCA065', 3);
    this.line(c, x, y + 94, x, y + 107, lit ? '#DAB77C' : '#7F7658', 2);
  }
  private shop(c: CanvasRenderingContext2D, lot: MarketSceneLot): void {
    const stall = this.state?.stalls.find(item => item.lotId === lot.id); const type = stall?.type || '';
    const x = lot.x; const y = lot.y;
    this.oval(c, x + 12, y + 28, 110, 34, 'rgba(1,16,22,0.28)');
    if (!type) {
      this.polygon(c, [{ x: x - 93, y: y - 8 }, { x: x + 52, y: y - 34 },
        { x: x + 97, y: y + 14 }, { x: x - 49, y: y + 42 }], '#54654D');
      c.setLineDash([7, 7]); c.strokeStyle = '#A8B58B'; c.lineWidth = 2;
      c.stroke(); c.setLineDash([]);
      this.line(c, x - 12, y + 1, x + 15, y - 4, '#D4C394', 3);
      this.line(c, x + 1, y - 16, x + 2, y + 13, '#D4C394', 3);
      return;
    }
    if (type === 'lantern') {
      this.line(c, x - 76, y + 23, x - 76, y - 126, '#BA9D65', 7);
      this.line(c, x + 77, y - 4, x + 77, y - 155, '#BA9D65', 7);
      this.line(c, x - 89, y - 119, x + 90, y - 153, '#C7AF77', 8);
      this.polygon(c, [{ x: x - 97, y: y - 128 }, { x: x - 2, y: y - 183 },
        { x: x + 103, y: y - 162 }, { x: x + 84, y: y - 135 }, { x: x - 78, y: y - 104 }], '#A47B43');
      const lit = this.visibleLamps()[Math.floor(lot.id / 2)] && (stall?.workers || 0) > 0;
      if (lit) this.glow(c, x, y - 60, 132, 0.27);
      for (let i = 0; i < 5; i++) {
        const lx = x - 57 + i * 29; const ly = y - 95 - i * 5;
        this.line(c, lx, ly, lx, ly + 12, '#BEA268', 2);
        this.oval(c, lx, ly + 27, 12, 17, lit ? '#E6B96C' : '#9C7F50');
        this.line(c, lx, ly + 45, lx, ly + 54, '#C9A268', 2);
      }
      if ((stall?.workers || 0) > 0) this.person(c, x + 8, y + 8, '#C3A56C', 1.35, false);
      return;
    }
    const cloth = type === 'rice' ? '#D5BB80' : type === 'meat' ? '#B46950' : type === 'tea' ? '#5B8A79' : '#C19A4D';
    this.house(c, x, y + 8, 133, 112, '#425F50');
    this.polygon(c, [{ x: x - 90, y: y - 71 }, { x: x + 65, y: y - 98 },
      { x: x + 92, y: y - 27 }, { x: x - 75, y: y + 2 }], cloth);
    for (let i = 0; i < 5; i++) this.line(c, x - 72 + i * 31, y - 72 - i * 5,
      x - 55 + i * 31, y - 2 - i * 5, 'rgba(246,227,174,0.23)', 8);
    this.line(c, x - 75, y + 2, x - 75, y + 34, '#B9AA7D', 4);
    this.line(c, x + 92, y - 27, x + 92, y + 12, '#B9AA7D', 4);
    this.polygon(c, [{ x: x - 66, y: y + 10 }, { x: x + 70, y: y - 14 },
      { x: x + 70, y: y + 6 }, { x: x - 66, y: y + 30 }], '#A98351');
    for (let i = 0; i < 3; i++) {
      const bx = x - 39 + i * 37; const by = y + 6 - i * 6;
      this.oval(c, bx, by, type === 'tea' ? 10 : 14, 5, type === 'meat' ? '#9B6042' : '#ECE0B1');
      if (type === 'rice') this.line(c, bx - 3, by - 11, bx - 8, by - 24, 'rgba(230,237,210,0.6)', 2);
      if (type === 'tea') { this.oval(c, bx, by - 5, 8, 6, '#D9C589'); this.oval(c, bx, by - 10, 7, 2, '#8A7043'); }
    }
    if (type === 'tea') {
      // “提瓶卖茶”只启发瓶与茶摊的辨识，不画成州桥原址已被复原的某间茶坊。
      c.beginPath(); c.moveTo(x + 34, y - 38); c.lineTo(x + 46, y - 40); c.lineTo(x + 47, y - 29);
      c.bezierCurveTo(x + 61, y - 15, x + 59, y + 1, x + 40, y + 3);
      c.bezierCurveTo(x + 24, y + 4, x + 25, y - 14, x + 35, y - 27); c.closePath();
      c.fillStyle = '#9BB69A'; c.fill();
      this.line(c, x + 32, y - 22, x + 22, y - 15, '#C4C99F', 4);
      c.beginPath(); c.ellipse(x + 56, y - 15, 11, 12, 0, 0, Math.PI * 2);
      c.strokeStyle = '#B9C39D'; c.lineWidth = 4; c.stroke();
    }
    // 招牌文字由原生Text按vp绘制，不能再把21个逻辑像素缩成手机上的6vp。
    c.fillStyle = '#B89D69'; c.fillRect(x - 28, y - 143, 61, 20);
    for (let i = 0; i < (stall?.workers || 0); i++) {
      this.person(c, x - 35 + i * 34, y - 12 - i * 4, '#C1A875', 1.25, false);
    }
    this.lantern(c, x + 103, y - 117, this.visibleLamps()[Math.floor(lot.id / 2)] === true);
  }

  private drawStatic(): void {
    if (!this.baseReady) return;
    // Watch、前后台切换和Sheet开合可能重复请求同一底景；只有真实视觉输入改变才重绘。
    // 逐帧流动不触碰此key，避免把静态建筑/光晕每34ms重新烘焙一次。
    const key = `${this.widthVp}:${this.heightVp}:${this.nightId}:${this.selectedLot}:` +
      JSON.stringify(this.state?.stalls || []) + JSON.stringify(this.lamps());
    if (key === this.staticKey) return;
    this.staticKey = key;
    const started = this.perfNow(); const firstPaint = this.staticPaintCount === 0;
    this.staticPaintCount++;
    const c = this.base; c.clearRect(0, 0, this.widthVp, this.heightVp);
    // contain之外仍绘制同一夜市的天色与水面，避免主场景上下只剩纯色空条。
    const surround = c.createLinearGradient(0, 0, 0, this.heightVp);
    surround.addColorStop(0, '#16343C'); surround.addColorStop(0.42, '#1A363A');
    surround.addColorStop(0.73, '#163F42'); surround.addColorStop(1, '#0D303A');
    c.fillStyle = surround; c.fillRect(0, 0, this.widthVp, this.heightVp);
    const frameBottom = this.top() + this.H * this.marketScale();
    for (let i = 0; i < 7; i++) {
      const y = frameBottom + 12 + i * 12;
      if (y < this.heightVp - 10) this.line(c, 18 + i * 29, y,
        58 + i * 29, y - 3, i % 3 === 0 ? 'rgba(188,166,100,0.21)' : 'rgba(83,133,123,0.26)', 1);
    }
    c.save(); c.translate(this.left(), this.top()); c.scale(this.marketScale(), this.marketScale());
    const sky = c.createLinearGradient(0, 0, 1000, 900);
    sky.addColorStop(0, '#142F36'); sky.addColorStop(0.6, '#28443A'); sky.addColorStop(1, '#071C29');
    c.fillStyle = sky; c.fillRect(0, 0, 1200, 900);
    this.oval(c, 1045, 88, 34, 34, '#E7D5A1'); this.oval(c, 1034, 79, 34, 34, '#1B3638');
    for (let i = 0; i < 13; i++) this.house(c, 20 + i * 103, 206 - i * 8,
      64 + i % 3 * 15, 55 + i % 4 * 16, i % 2 === 0 ? '#294C43' : '#3B5748');
    // 屋檐与远岸仅作原创场景气氛，静态悬灯不能充当真实来客或已接待人数。
    this.line(c, 65, 116, 1170, 56, '#877D58', 2);
    for (let i = 0; i < 9; i++) {
      const x = 102 + i * 124; const y = 114 - i * 6.8;
      this.line(c, x, y, x, y + 22, '#8F8059', 2);
      this.oval(c, x, y + 29, 8, 12, this.nightId === 'night-3' ? '#D5AC5B' : '#986D46');
      this.line(c, x, y + 41, x, y + 48, '#A48959', 2);
    }
    this.polygon(c, [{ x: 0, y: 338 }, { x: 1200, y: 122 }, { x: 1200, y: 633 }, { x: 0, y: 865 }], '#536248');
    this.polygon(c, [{ x: 0, y: 478 }, { x: 1200, y: 260 }, { x: 1200, y: 390 }, { x: 0, y: 622 }], '#B4A274');
    this.polygon(c, [{ x: 0, y: 682 }, { x: 1200, y: 458 }, { x: 1200, y: 605 }, { x: 0, y: 843 }], '#9A9168');
    for (let i = 0; i < 20; i++) {
      const x = i * 70; const y = 492 - x * 0.18;
      this.line(c, x, y, x + 20, y + 112, 'rgba(83,82,56,0.17)', 2);
    }
    this.polygon(c, [{ x: 0, y: 847 }, { x: 1200, y: 609 }, { x: 1200, y: 900 }, { x: 0, y: 900 }], '#143F43');
    this.line(c, 0, 838, 1200, 600, '#C3AE7A', 8);
    this.line(c, 0, 850, 1200, 612, '#5D6D53', 5);
    for (let i = 0; i < 21; i++) {
      const x = i * 63; const y = 879 - x * 0.16 + (i % 3) * 16;
      this.line(c, x, y, x + 48 + i % 3 * 14, y - 8, i % 4 === 0 ? '#AD9B63' : '#356362', 2);
    }
    this.polygon(c, [{ x: 817, y: 762 }, { x: 958, y: 733 }, { x: 1010, y: 753 },
      { x: 864, y: 787 }], '#7C6747');
    this.line(c, 882, 753, 882, 665, '#B7A075', 3);
    this.polygon(c, [{ x: 884, y: 674 }, { x: 930, y: 719 }, { x: 884, y: 733 }], '#C0B18A');
    for (let zone = 0; zone < 3; zone++) {
      const lit = this.visibleLamps()[zone] === true;
      if (lit) this.glow(c, 260 + zone * 305, 555 - zone * 60, 218, 0.23);
      c.fillStyle = '#D7CBA3'; c.font = '19px sans-serif'; c.textAlign = 'center';
      c.fillText(MARKET_ZONE_NAMES[zone], 233 + zone * 305, 738 - zone * 60);
    }
    this.lots.forEach((lot: MarketSceneLot) => this.shop(c, lot));
    const selected = this.lots.find(lot => lot.id === this.selectedLot);
    if (selected) {
      c.beginPath(); c.ellipse(selected.x, selected.y + 15, 104, 43, -0.12, 0, Math.PI * 2);
      c.strokeStyle = '#FFE0A0'; c.lineWidth = 4; c.stroke();
    }
    c.restore();
    this.sample(firstPaint ? this.perfFirstStatic : this.perfStatic, this.perfNow() - started);
  }

  private person(c: CanvasRenderingContext2D, x: number, y: number, color: string,
    scale: number, served: boolean): void {
    this.oval(c, x + 3, y + 8, 10 * scale, 4 * scale, 'rgba(13,29,23,0.26)');
    this.oval(c, x, y - 17 * scale, 6 * scale, 7 * scale, '#DBBC85');
    this.polygon(c, [{ x: x - 7 * scale, y: y - 9 * scale }, { x: x + 7 * scale, y: y - 9 * scale },
      { x: x + 10 * scale, y: y + 8 * scale }, { x: x - 10 * scale, y: y + 8 * scale }], color);
    this.line(c, x - 4 * scale, y + 8 * scale, x - 5 * scale, y + 15 * scale, '#384C3D', 3 * scale);
    this.line(c, x + 4 * scale, y + 8 * scale, x + 6 * scale, y + 15 * scale, '#384C3D', 3 * scale);
    if (served) this.oval(c, x + 13 * scale, y - 10 * scale, 7 * scale, 3 * scale, '#F0DBA0');
  }

  private visitPoint(visit: MarketNightVisit, progress: number): MarketScenePoint {
    const origin = Math.max(0, Math.min(2, visit.origin));
    const start: MarketScenePoint = { x: 68 + origin * 390, y: 596 - origin * 72 };
    const lot = this.lots.find(item => item.id === (visit.lotId >= 0 ? visit.lotId : visit.targetLot));
    let target: MarketScenePoint = lot ? { x: lot.x + 12, y: lot.y + 56 } :
      { x: 118 + origin * 390, y: 570 - origin * 72 };
    // 受阻区由领域逐客事件直接给出；走不通的人停在真正受阻的街口，不能画成已到铺前。
    if (visit.blockedZone >= 0) target = { x: 195 + visit.blockedZone * 345, y: 578 - visit.blockedZone * 66 };
    if (visit.tour) target = { x: 126 + origin * 390, y: 558 - origin * 72 };
    if (visit.festival && !visit.festivalViewed && visit.festivalLot >= 0) {
      const lantern = this.lots.find(item => item.id === visit.festivalLot);
      if (lantern && visit.blockedZone < 0) target = { x: lantern.x + 10, y: lantern.y + 48 };
    }
    const t = Math.min(1, progress / 0.7);
    // 观灯客先走到已记录灯棚，再向消费铺移动。没有完成观灯的事件不会获得这段路径。
    if (visit.festivalViewed && visit.festivalLot >= 0 && visit.blockedZone < 0) {
      const lantern = this.lots.find(item => item.id === visit.festivalLot);
      if (lantern) {
        const middle: MarketScenePoint = { x: lantern.x + 10, y: lantern.y + 48 };
        if (t < 0.46) return { x: start.x + (middle.x - start.x) * t / 0.46, y: start.y + (middle.y - start.y) * t / 0.46 };
        return { x: middle.x + (target.x - middle.x) * (t - 0.46) / 0.54,
          y: middle.y + (target.y - middle.y) * (t - 0.46) / 0.54 };
      }
    }
    return { x: start.x + (target.x - start.x) * t,
      y: start.y + (target.y - start.y) * t - Math.sin(t * Math.PI) * 24 };
  }
  private drawFlow(): void {
    if (!this.flowReady) return;
    const c = this.flow; c.clearRect(0, 0, this.widthVp, this.heightVp);
    if (!this.report || this.playbackKey <= 0 || this.elapsed >= this.duration || this.reducedMotion) return;
    c.save(); c.translate(this.left(), this.top()); c.scale(this.marketScale(), this.marketScale());
    const visits = this.report.visits; const gap = 3300 / Math.max(1, visits.length);
    visits.forEach((visit: MarketNightVisit, index: number) => {
      const progress = (this.elapsed - index * gap) / 1700;
      if (progress < 0 || progress > 1) return;
      const point = this.visitPoint(visit, progress);
      c.globalAlpha = progress > 0.85 ? (1 - progress) / 0.15 : 1;
      this.person(c, point.x, point.y, visit.preference === 'rice' ? '#E0C795' :
        visit.preference === 'meat' ? '#BC8873' : '#86AEA1', 1.75, visit.served && progress > 0.68);
      // 需求气泡以固定vp绘制，手机上的字不能随1200逻辑画布缩成难读的小点。
      c.save(); c.translate(point.x, point.y - 50); c.scale(1 / this.marketScale(), 1 / this.marketScale());
      const demand = visit.preference === 'rice' ? '饭' : visit.preference === 'meat' ? '肉' : '茶';
      c.fillStyle = '#F2E7C7'; c.fillRect(-12, -12, 24, 17);
      c.fillStyle = '#375546'; c.font = '10px sans-serif'; c.textAlign = 'center';
      c.fillText(visit.festival && progress < 0.35 ? '灯' : demand, 0, 0); c.restore();
      if (progress > 0.42 && progress < 0.68 && visit.reason === 'workers') {
        c.save(); c.translate(point.x, point.y - 77); c.scale(1 / this.marketScale(), 1 / this.marketScale());
        c.font = '10px sans-serif'; c.fillStyle = '#EBC58A'; c.textAlign = 'center'; c.fillText('等位', 0, 0); c.restore();
      }
      if (progress > 0.68) {
        this.oval(c, point.x, point.y - 43, 15, 14, visit.served ? '#577D61' : '#AB6E58');
        c.fillStyle = '#FFF0CB'; c.textAlign = 'center'; c.font = '18px sans-serif';
        c.fillText(visit.served ? '+' : '×', point.x, point.y - 37);
        if (!visit.served) {
          // 回放原因使用固定vp字号；用逻辑字号再缩放会小到无法阅读。
          c.save(); c.translate(Math.max(92, Math.min(1080, point.x)), point.y - 80);
          c.scale(1 / this.marketScale(), 1 / this.marketScale());
          c.font = '11px sans-serif'; c.fillStyle = '#F1D3A8';
          c.fillText(`${visit.blockedZone >= 0 ? MARKET_ZONE_NAMES[visit.blockedZone] + ' · ' : ''}${nightReasonName(visit.reason)}`, 0, 0); c.restore();
        }
      }
    });
    c.globalAlpha = 1; c.restore();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Canvas(this.base).width('100%').height('100%').hitTestBehavior(HitTestMode.None)
        .onReady(() => { this.baseReady = true; this.drawStatic(); })
      Canvas(this.flow).width('100%').height('100%').hitTestBehavior(HitTestMode.None)
        .onReady(() => { this.flowReady = true; this.drawFlow(); this.motion(); })
      if (this.state && this.interactive && this.top() > 37) {
        Row({ space: 6 }) {
          ForEach([0, 1, 2], (zone: number) => {
            Column({ space: 3 }) {
              Text(`${MARKET_ZONE_NAMES[zone]} · ${marketNightForecast(this.state!).zoneArrivals[zone]}客`)
                .fontSize(11).fontColor('#D0D3AF')
              Text(`通行 ${marketNightForecast(this.state!).laneCapacity[zone]} · ${this.visibleLamps()[zone] ? '灯亮' : '未点灯'}`)
                .fontSize(9).fontColor('#8DAF9E')
            }.layoutWeight(1)
          }, (zone: number) => `${zone}`)
        }.width('100%').padding({ left: 12, right: 12 }).position({ x: 0, y: Math.max(38, this.top() - 38) })
          .hitTestBehavior(HitTestMode.None)
      }
      ForEach(this.lots, (lot: MarketSceneLot) => {
        Text(this.lotTitle(lot)).fontSize(11).minFontSize(10).maxFontSize(11).maxLines(1).fontWeight(FontWeight.Medium)
          .fontColor(this.state?.stalls[lot.id].type ? '#F4E5BE' : '#B5C8AC')
          .height(23).width(this.lotLabelWidth()).textAlign(TextAlign.Center)
          .backgroundColor(this.state?.stalls[lot.id].type ? '#38564A' : 'rgba(29,58,51,0.72)')
          .border({ width: 1, color: this.selectedLot === lot.id ? '#E8C386' : '#718568', radius: 4 }).borderRadius(4)
          .position({ x: this.point(lot).x - this.lotLabelWidth() * 0.5,
            y: this.top() + (lot.y - (this.state?.stalls[lot.id].type ? 162 : 48)) * this.marketScale() - 5 })
          .hitTestBehavior(HitTestMode.None)
      }, (lot: MarketSceneLot) => `label-${lot.id}`)
      ForEach(this.lots, (lot: MarketSceneLot) => {
        Button({ type: ButtonType.Normal }) { Column().width('100%').height('100%') }
          .width(Math.max(62, 205 * this.marketScale())).height(Math.max(56, 220 * this.marketScale()))
          .padding(0).backgroundColor(Color.Transparent)
          .position({ x: this.point(lot).x - Math.max(62, 205 * this.marketScale()) * 0.5,
            y: this.top() + (lot.y - 170) * this.marketScale() - 6 })
          .enabled(this.interactive).id(`tn-lot-${lot.id}`)
          .accessibilityText(`${MARKET_ZONE_NAMES[Math.floor(lot.id / 2)]}第${lot.id % 2 + 1}处，${
            nightStallName(this.state?.stalls.find(item => item.lotId === lot.id)?.type || '')}`)
          .onClick(() => this.onSelectLot(lot.id))
      }, (lot: MarketSceneLot) => `${lot.id}`)
      if (this.interactive && this.report && this.playbackKey > 0 && !this.active) {
        Text(this.reportCaption()).fontSize(10).fontColor('#D6C79B').width('100%').textAlign(TextAlign.Center)
          .position({ x: 0, y: Math.max(0, this.heightVp - 44) }).id('tn-batch-scene-result').hitTestBehavior(HitTestMode.None)
      }
      if (this.interactive && !this.active) {
        Text(this.state?.phase === 'prepare' ? '点铺位安排  ·  开市后分三批迎客' :
          this.state?.phase === 'emergency' ? '本批已保存  ·  调度后再继续下一批' :
          this.state?.phase === 'settling' ? '三批已走完  ·  收段才结工钱与铺租' : '点铺位看安排').fontSize(10).fontColor('#9BB8A4')
          .width('100%').textAlign(TextAlign.Center).position({ x: 0, y: Math.max(0, this.heightVp - 24) })
          .hitTestBehavior(HitTestMode.None)
      }
    }.width('100%').height('100%').backgroundColor('#0A1C26').id('tn-scene')
      .onAreaChange((_old: Area, area: Area) => {
        this.widthVp = Number(area.width); this.heightVp = Number(area.height); this.drawStatic(); this.drawFlow();
      })
  }
}


