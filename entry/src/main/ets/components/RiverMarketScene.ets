import type { RiverMarketState, MarketRoundReport, MarketVisit } from '../domain/RiverMarket';
import { marketForecast } from '../domain/RiverMarket';
import { marketStallName, marketReasonName, MARKET_ZONE_NAMES } from '../data/RiverMarketCatalog';

interface MarketScenePoint { x: number; y: number; }
interface MarketSceneLot { id: number; x: number; y: number; }

// 双 Canvas：河岸、铺子、灯和选择框只在真实经营状态改变时重画；逐客回放只画动态层。
// 动画读领域已结算的 visits，不随机造排队人群；定时器没有任何经济/保存回调。
@Component
export struct RiverMarketScene {
  @Prop @Watch('stateChanged') state: RiverMarketState | undefined = undefined;
  @Prop @Watch('drawStatic') selectedLot: number = -1;
  @Prop @Watch('playChanged') report: MarketRoundReport | undefined = undefined;
  @Prop @Watch('playChanged') playbackKey: number = 0;
  @Prop @Watch('motion') active: boolean = true;
  @Prop @Watch('motion') reducedMotion: boolean = false;
  @Prop interactive: boolean = true;
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
  private readonly W: number = 1200;
  private readonly H: number = 900;
  private lots: MarketSceneLot[] = [ { id: 0, x: 235, y: 372 }, { id: 1, x: 300, y: 582 },
    { id: 2, x: 535, y: 312 }, { id: 3, x: 605, y: 522 },
    { id: 4, x: 835, y: 252 }, { id: 5, x: 912, y: 462 } ];

  aboutToDisappear(): void { this.stop(); }
  private marketScale(): number { return Math.min(this.widthVp / this.W, this.heightVp / this.H); }
  private left(): number { return (this.widthVp - this.W * this.marketScale()) * 0.5; }
  private top(): number { return (this.heightVp - this.H * this.marketScale()) * 0.5; }
  private lotTitle(lot: MarketSceneLot): string {
    const stall = this.state?.stalls.find(item => item.lotId === lot.id);
    return stall?.type ? `${marketStallName(stall.type)} · ${stall.workers}人` : '+ 开铺';
  }
  private lotLabelWidth(): number { return Math.max(62, Math.min(88, this.widthVp / 5.6)); }
  private point(lot: MarketSceneLot): MarketScenePoint {
    return { x: this.left() + lot.x * this.marketScale(), y: this.top() + (lot.y - 30) * this.marketScale() };
  }
  private stateChanged(): void { this.drawStatic(); }
  private visibleLamps(): boolean[] {
    // 开段后库存已经扣油，播放应显示本段真实用过的灯，而不是拿扣油后库存再算一次。
    // 下一段安排时则读取forecast，没油的请求灯区不画成已点亮。
    if (this.report && this.playbackKey > 0 && this.active && this.finishedKey !== this.playbackKey) {
      return this.report.effectiveLamps;
    }
    return this.state ? marketForecast(this.state).effectiveLamps : [false, false, false];
  }
  private stop(): void { if (this.timer >= 0) clearInterval(this.timer); this.timer = -1; }
  private playChanged(): void {
    this.stop(); this.elapsed = 0; this.finishedKey = -1; this.drawStatic(); this.drawFlow(); this.motion();
  }
  private motion(): void {
    this.stop();
    this.drawStatic();
    if (!this.flowReady || !this.active || !this.foreground || !this.report || this.playbackKey <= 0 ||
      this.finishedKey === this.playbackKey) return;
    if (this.reducedMotion) { this.elapsed = 4000; this.finish(); return; }
    this.lastTick = Date.now();
    this.timer = setInterval(() => {
      const now = Date.now(); this.elapsed += Math.min(100, now - this.lastTick); this.lastTick = now;
      this.drawFlow(); if (this.elapsed >= 4000) this.finish();
    }, 34);
  }
  private finish(): void {
    this.stop(); this.elapsed = 4000; this.finishedKey = this.playbackKey; this.drawFlow(); this.onPlaybackFinished();
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
    const cloth = type === 'rice' ? '#D5BB80' : type === 'meat' ? '#B46950' : '#5B8A79';
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

  private visitPoint(visit: MarketVisit, progress: number): MarketScenePoint {
    const origin = Math.max(0, Math.min(2, visit.origin));
    const start: MarketScenePoint = { x: 68 + origin * 390, y: 596 - origin * 72 };
    const lot = this.lots.find(item => item.id === visit.lotId);
    const target: MarketScenePoint = lot ? { x: lot.x + 12, y: lot.y + 56 } :
      { x: 1130, y: 391 };
    const t = Math.min(1, progress / 0.7);
    return { x: start.x + (target.x - start.x) * t,
      y: start.y + (target.y - start.y) * t - Math.sin(t * Math.PI) * 27 };
  }
  private drawFlow(): void {
    if (!this.flowReady) return;
    const c = this.flow; c.clearRect(0, 0, this.widthVp, this.heightVp);
    if (!this.report || this.playbackKey <= 0 || this.elapsed >= 4000 || this.reducedMotion) return;
    c.save(); c.translate(this.left(), this.top()); c.scale(this.marketScale(), this.marketScale());
    const visits = this.report.visits; const gap = 3000 / Math.max(1, visits.length);
    visits.forEach((visit: MarketVisit, index: number) => {
      const progress = (this.elapsed - index * gap) / 1000;
      if (progress < 0 || progress > 1) return;
      const point = this.visitPoint(visit, progress);
      c.globalAlpha = progress > 0.85 ? (1 - progress) / 0.15 : 1;
      this.person(c, point.x, point.y, visit.preference === 'rice' ? '#E0C795' :
        visit.preference === 'meat' ? '#BC8873' : '#86AEA1', 1.75, visit.served && progress > 0.68);
      if (progress > 0.68) {
        this.oval(c, point.x, point.y - 43, 15, 14, visit.served ? '#577D61' : '#AB6E58');
        c.fillStyle = '#FFF0CB'; c.textAlign = 'center'; c.font = '18px sans-serif';
        c.fillText(visit.served ? '+' : '×', point.x, point.y - 37);
        if (!visit.served) {
          // 回放原因使用固定vp字号；用逻辑字号再缩放会小到无法阅读。
          c.save(); c.translate(Math.min(1080, point.x), point.y - 69);
          c.scale(1 / this.marketScale(), 1 / this.marketScale());
          c.font = '11px sans-serif'; c.fillStyle = '#F1D3A8';
          c.fillText(marketReasonName(visit.reason), 0, 0); c.restore();
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
              Text(`${MARKET_ZONE_NAMES[zone]} · ${marketForecast(this.state!).zoneArrivals[zone]}客`)
                .fontSize(11).fontColor('#D0D3AF')
              Text(`通行 ${marketForecast(this.state!).laneCapacity[zone]} · ${this.visibleLamps()[zone] ? '灯亮' : '未点灯'}`)
                .fontSize(9).fontColor('#8DAF9E')
            }.layoutWeight(1)
          }, (zone: number) => `${zone}`)
        }.width('100%').padding({ left: 12, right: 12 }).position({ x: 0, y: Math.max(38, this.top() - 38) })
          .hitTestBehavior(HitTestMode.None)
      }
      ForEach(this.lots, (lot: MarketSceneLot) => {
        Text(this.lotTitle(lot)).fontSize(11).fontWeight(FontWeight.Medium)
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
          .enabled(this.interactive).id(`market-lot-${lot.id}`)
          .accessibilityText(`${MARKET_ZONE_NAMES[Math.floor(lot.id / 2)]}第${lot.id % 2 + 1}处，${
            marketStallName(this.state?.stalls.find(item => item.lotId === lot.id)?.type || '')}`)
          .onClick(() => this.onSelectLot(lot.id))
      }, (lot: MarketSceneLot) => `${lot.id}`)
      if (this.interactive && !this.active) {
        Text('点空地开铺  ·  点铺子调伙计  ·  下一段前都能调整').fontSize(10).fontColor('#9BB8A4')
          .width('100%').textAlign(TextAlign.Center).position({ x: 0, y: Math.max(0, this.heightVp - 24) })
          .hitTestBehavior(HitTestMode.None)
      }
    }.width('100%').height('100%').backgroundColor('#0A1C26').id('river-market-scene')
      .onAreaChange((_old: Area, area: Area) => {
        this.widthVp = Number(area.width); this.heightVp = Number(area.height); this.drawStatic(); this.drawFlow();
      })
  }
}
