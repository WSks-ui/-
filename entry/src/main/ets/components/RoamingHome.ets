import { ArchiveRecord } from '../domain/ArchiveDomain';
import { RoamChapter, RoamClue, roamProgress } from '../domain/Roaming';
import { KaifengCityGrade, kaifengCityGrade } from '../domain/KaifengPuzzle';
import { kaifengCityFromRecords } from '../domain/KaifengRecords';
import { kaifengDigFromRecords } from '../domain/KaifengDigRecords';
import { ROAM_CHAPTERS } from '../data/RoamingCatalog';
import { RoamingTheme as R } from './RoamingTheme';

interface RiverCityPoint { x: number; y: number; }

// 首页长卷保留原生横向滚动，城市题签是可访问的原生按钮。
// 图景不是导航地图；距离、山势与地标都为编辑叙事，不代表真实比例或历史复原。
//
// 2026-10-23 设计样板：河卷从“画五个小景”改为“一河五记”。
// 上方留白挂竖向题签，岸边用 22px 墨线图记区分五城（坑院、双峰、水门、虹桥、蚌纹），
// 下方是一条完整水面。图记只承担索引，不做建筑复原；具体场景在篇章页里展开。
// 这样五城在首页就能被区分，又不会因为缩小绘制而变成模糊色块。
@Component
export struct RoamingHome {
  @Prop records: ArchiveRecord[] = [];
  @Prop reducedMotion: boolean = false;
  @Prop topClearance: number = 112;
  @Prop bottomClearance: number = 104;
  onOpen: (chapterId: string) => void = () => {};
  onOpenDig: (chapterId: string) => void = () => {};
  onLibrary: () => void = () => {};
  onMemory: () => void = () => {};
  scroller: Scroller = new Scroller();
  @State private selectedIndex: number = 0;
  @State private containerWidth: number = 360;
  private riverScroller: Scroller = new Scroller();
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private canvasReady: boolean = false;
  // 河卷逻辑画幅 1120×300：横向按 vp 1:1 摆放，纵向按 riverHeight 压缩。
  // 题签是原生节点，不随画布缩放，因此纵向位置要显式乘缩放比。
  private readonly ART_W: number = 1120;
  private readonly ART_H: number = 250;
  private readonly TAG_BOTTOM: number = 148;
  private readonly SHORE: number = 158;
  private points: RiverCityPoint[] = [
    { x: 118, y: 158 }, { x: 332, y: 158 }, { x: 556, y: 158 }, { x: 786, y: 158 }, { x: 1006, y: 158 }
  ];

  aboutToAppear(): void {
    const recent = this.records.filter((record: ArchiveRecord) => !record.deleted && record.kind === 'progress' &&
      ROAM_CHAPTERS.some((chapter: RoamChapter) => chapter.id === record.siteId))
      .sort((a: ArchiveRecord, b: ArchiveRecord) => b.updatedAt - a.updatedAt)[0];
    if (recent) {
      const index = ROAM_CHAPTERS.findIndex((chapter: RoamChapter) => chapter.id === recent.siteId);
      if (index >= 0) this.selectedIndex = index;
    }
  }

  private chapter(): RoamChapter { return ROAM_CHAPTERS[this.selectedIndex] || ROAM_CHAPTERS[0]; }
  private wide(): boolean { return this.containerWidth >= 900; }
  private riverHeight(): number { return this.ART_H; }
  private vScale(): number { return this.riverHeight() / this.ART_H; }
  private progress() { return roamProgress(this.records, this.chapter()); }
  private currentGoal(): string {
    const progress = roamProgress(this.records, this.chapter());
    return this.chapter().clues.find((clue: RoamClue) => clue.id === progress.nextClueId)?.goal || '重看选过的片段，留下新的理解。';
  }
  private totalCompleted(): number {
    return ROAM_CHAPTERS.filter((chapter: RoamChapter) => roamProgress(this.records, chapter).completed).length;
  }

  // 城格只从真实城市快照派生：没有建过城就是空卷，不用线索完成数冒充。
  // 探方是开封的主玩法：首页先报最佳评级，没有记录时不显示任何「零分」。
  private digGrade(): string {
    const dig = kaifengDigFromRecords(this.records, this.chapter().id);
    return dig && dig.bestGrade !== '' ? dig.bestGrade : '';
  }

  private cityGrade(): KaifengCityGrade {
    return kaifengCityGrade(kaifengCityFromRecords(this.records, this.chapter().id));
  }

  private cityLine(): string {
    const grade = this.cityGrade();
    return grade.grade > 0 ? `你的汴京 · ${grade.name}` : '';
  }

  private goalWithCity(): string {
    const grade = this.cityGrade();
    if (this.chapter().scene !== 'kf-night' || grade.grade === 0) return this.currentGoal();
    if (grade.grade === 1) return '桥成了。去剖面看同一处的宋、明与明末。';
    if (grade.grade === 2) return '三个年代叠好了。去州桥夜市把三处摊点亮。';
    if (grade.grade === 3) return '夜市开了，还有一处暗着。灯够时把它补亮。';
    if (grade.grade === 4) return '三处都亮了。写一页，把这一夜收成自己的城志。';
    return '你的汴京已成志。可以回城看看，或重走一遍换个版本。';
  }

  private fiveCityCount(): number {
    return ROAM_CHAPTERS.filter((chapter: RoamChapter) => roamProgress(this.records, chapter).completed).length;
  }
  private memoryCount(): number { return this.records.filter((record: ArchiveRecord) => !record.deleted && record.kind === 'note').length; }

  private select(index: number): void {
    this.selectedIndex = index;
    const point = this.points[index];
    this.riverScroller.scrollTo({ xOffset: Math.max(0, Math.min(this.ART_W - this.containerWidth,
      point.x - this.containerWidth * 0.5)), yOffset: 0,
      animation: this.reducedMotion ? false : { duration: 380, curve: Curve.EaseOut } });
    this.draw();
  }

  // —— 绘制基元 ——

  private stroke(x1: number, y1: number, x2: number, y2: number, color: string, width: number): void {
    const c = this.context;
    c.beginPath(); c.moveTo(x1, y1); c.lineTo(x2, y2); c.strokeStyle = color; c.lineWidth = width; c.stroke();
  }

  private disc(x: number, y: number, r: number, color: string): void {
    const c = this.context;
    c.beginPath(); c.arc(x, y, r, 0, Math.PI * 2); c.fillStyle = color; c.fill();
  }

  private sealSquare(x: number, y: number, size: number, color: string, filled: boolean): void {
    const c = this.context;
    c.beginPath(); c.rect(x - size / 2, y - size / 2, size, size);
    if (filled) { c.fillStyle = color; c.fill(); } else { c.strokeStyle = color; c.lineWidth = 1.4; c.stroke(); }
  }

  // 远山：两道低对比的水墨坡，只提供纵深；峰位固定，重绘结果完全一致。
  private mountain(y: number, height: number, color: string, phase: number): void {
    const c = this.context;
    c.beginPath(); c.moveTo(-30, y);
    c.bezierCurveTo(110 + phase, y - height * 0.55, 200 + phase, y - height * 0.28, 292 + phase, y - height * 0.5);
    c.bezierCurveTo(392 + phase, y - height * 0.82, 458 + phase, y - height, 548 + phase, y - height * 0.7);
    c.bezierCurveTo(660 + phase, y - height * 0.26, 748 + phase, y - height * 0.62, 858 + phase, y - height * 0.42);
    c.bezierCurveTo(980 + phase, y - height * 0.2, 1072 + phase, y - height * 0.48, 1150, y - height * 0.3);
    c.lineTo(1150, y + 70); c.lineTo(-30, y + 70); c.closePath(); c.fillStyle = color; c.fill();
  }

  // 垂柳：先有冠，再垂枝。枝条短而下垂，叶沿枝分布，避免变成一把扫帚。
  private willow(x: number, y: number, scale: number): void {
    const c = this.context;
    c.save(); c.translate(x, y); c.scale(scale, scale);
    c.beginPath(); c.moveTo(0, 2); c.bezierCurveTo(-2, -12, 2, -24, 0, -33);
    c.strokeStyle = '#6A7550'; c.lineWidth = 2.6; c.stroke();
    // 冠：三团叠加，给垂枝一个可见的落点
    this.disc(-7, -38, 8, '#8FA878'); this.disc(6, -40, 8.6, '#9AB482'); this.disc(0, -44, 7.6, '#A6BE8C');
    for (let index = 0; index < 6; index++) {
      const spread = (index - 2.5) * 5.4;
      c.beginPath(); c.moveTo(spread * 0.5, -42);
      c.quadraticCurveTo(spread * 1.2, -32, spread * 1.35, -22);
      c.strokeStyle = '#7E9A66'; c.lineWidth = 1.3; c.stroke();
      this.disc(spread * 1.35, -21, 1.5, '#8FA878');
    }
    c.restore();
  }

  // 岸边草：一丛细叶，向外斜生并带一点弯；不画顶端圆点，避免变成一排天线。
  private reed(x: number, y: number, scale: number): void {
    const c = this.context;
    for (let index = 0; index < 9; index++) {
      const lean = (index - 4) * 2.6;
      const height = (7 + (index * 3) % 11) * scale;
      c.beginPath(); c.moveTo(x + lean * 0.4, y);
      c.quadraticCurveTo(x + lean * 1.2, y - height * 0.55, x + lean * 2.0, y - height);
      c.strokeStyle = index % 3 === 0 ? '#7E9468' : '#95A87A';
      c.lineWidth = 1.3; c.stroke();
    }
  }

  // 水面：一条自西向东的长带。上缘石岸，下缘出画，视角停在“站在水边看对岸”。
  // 岸线用较明显的波幅，避免压缩后变成一条直线；水面分三层波纹，
  // 由密到疏表达由近及远，而不是铺一层均匀的纹理。
  private shorePath(): void {
    const c = this.context;
    c.beginPath(); c.moveTo(-20, 160);
    c.bezierCurveTo(196, 144, 372, 178, 560, 158);
    c.bezierCurveTo(742, 140, 930, 172, 1140, 150);
  }

  private drawRiver(): void {
    const c = this.context;
    this.shorePath(); c.lineTo(1140, 260); c.lineTo(-20, 260); c.closePath();
    const grad = c.createLinearGradient(0, 146, 0, 250);
    grad.addColorStop(0, '#63A08A'); grad.addColorStop(0.26, '#2E7060'); grad.addColorStop(1, '#13423A');
    c.fillStyle = grad; c.fill();
    // 岸线：暖石岸 + 一道很淡的水光边
    this.shorePath(); c.strokeStyle = '#DCCCA0'; c.lineWidth = 4.2; c.stroke();
    c.strokeStyle = 'rgba(255,252,240,0.30)'; c.lineWidth = 1.1; c.stroke();
    // 三层水纹：靠岸密、靠下疏，长短不一
    for (let index = 0; index < 26; index++) {
      const x = -10 + index * 44;
      const y = 176 + Math.sin(index * 0.72) * 8;
      c.beginPath(); c.moveTo(x, y); c.quadraticCurveTo(x + 12, y - 2, x + 26, y + 1);
      c.strokeStyle = '#A8C9B0'; c.globalAlpha = 0.26; c.lineWidth = 1.2; c.stroke(); c.globalAlpha = 1;
    }
    for (let index = 0; index < 14; index++) {
      const x = 10 + index * 82;
      const y = 202 + Math.sin(index * 1.1) * 9;
      c.beginPath(); c.moveTo(x, y); c.quadraticCurveTo(x + 16, y - 3, x + 34, y + 1);
      c.strokeStyle = index % 4 === 0 ? '#D8E7C6' : '#8FB9A2';
      c.globalAlpha = index % 4 === 0 ? 0.55 : 0.22; c.lineWidth = index % 4 === 0 ? 2 : 1.2;
      c.stroke(); c.globalAlpha = 1;
    }
    for (let index = 0; index < 7; index++) {
      const x = 40 + index * 168;
      const y = 232 + (index % 2) * 8;
      c.beginPath(); c.moveTo(x, y); c.lineTo(x + 44, y - 2);
      c.strokeStyle = '#7FA992'; c.globalAlpha = 0.18; c.lineWidth = 1.4; c.stroke(); c.globalAlpha = 1;
    }
    // 流带：靠岸一道更浅的水，说明水在动
    this.shorePath(); c.translate(0, 9);
    c.strokeStyle = 'rgba(206,226,196,0.35)'; c.lineWidth = 7; c.stroke(); c.translate(0, -9);
    // 日影：暖色横线，靠近右岸
    for (let index = 0; index < 7; index++) {
      const y = 170 + index * 5;
      this.stroke(1014 - index * 11, y, 1050 + index * 5, y, '#E2C88E', 1.3);
    }
  }

  // 舟：停在当前选中的河段前，说明“沿河”这件事发生在水面上，而不是卡片之间。
  private drawBoat(x: number, y: number, scale: number): void {
    const c = this.context;
    c.save(); c.translate(x, y); c.scale(scale, scale);
    // 船身
    c.beginPath(); c.moveTo(-15, 0); c.bezierCurveTo(-9, 6, 9, 6, 15, -1);
    c.lineTo(12, -5); c.bezierCurveTo(6, 1, -6, 1, -12, -5); c.closePath();
    c.fillStyle = '#3B2F22'; c.fill();
    // 篷
    c.beginPath(); c.moveTo(-6, -4); c.bezierCurveTo(-5, -13, 6, -13, 7, -4); c.closePath();
    c.fillStyle = '#C9A870'; c.fill();
    // 桡
    this.stroke(9, -3, 18, -13, '#C9A870', 1.2);
    // 尾迹：两道很短的弧，只暗示行进方向
    c.globalAlpha = 0.35;
    c.beginPath(); c.moveTo(-17, 1); c.quadraticCurveTo(-26, 3, -34, 1);
    c.strokeStyle = '#CFE2C9'; c.lineWidth = 1.2; c.stroke(); c.globalAlpha = 1;
    c.restore();
  }

  private draw(): void {
    if (!this.canvasReady) return;
    const c = this.context;
    const height = this.riverHeight();
    c.clearRect(0, 0, this.ART_W, height);
    c.save(); c.scale(1, this.vScale());
    // 天：近乎纸色，只向下极轻转青，让题签落在最干净的一片空处
    const sky = c.createLinearGradient(0, 0, 0, 158);
    sky.addColorStop(0, '#F9F5E8'); sky.addColorStop(0.55, '#F5F2E3'); sky.addColorStop(1, '#F0EFDC');
    c.fillStyle = sky; c.fillRect(0, 0, this.ART_W, 162);
    // 淡日
    const sun = c.createRadialGradient(1012, 52, 6, 1012, 52, 62);
    sun.addColorStop(0, 'rgba(228,203,150,0.38)'); sun.addColorStop(1, 'rgba(228,203,150,0)');
    c.fillStyle = sun; c.fillRect(950, 0, 170, 130);
    this.disc(1012, 52, 14, '#EBD8AA');

    // 两道贴着岸线的远山：只露一条脊，提供纵深而不与题签争位置
    this.mountain(166, 34, '#E2E8D0', 0);
    this.mountain(172, 24, '#D2DDB9', 210);

    // 归雁：右上留白里的三笔，给出季节与尺度
    this.stroke(866, 40, 874, 35, '#8A9A72', 1.3); this.stroke(874, 35, 882, 40, '#8A9A72', 1.3);
    this.stroke(902, 60, 909, 56, '#95A47C', 1.1); this.stroke(909, 56, 916, 60, '#95A47C', 1.1);
    this.stroke(842, 72, 848, 68, '#9DAC85', 1); this.stroke(848, 68, 854, 72, '#9DAC85', 1);

    // 岸边芦苇：前景只有这一层，避免小尺寸树冠变形
    this.reed(56, 164, 0.95); this.reed(268, 161, 0.8); this.reed(430, 163, 0.75);
    this.reed(640, 160, 0.85); this.reed(884, 158, 0.75); this.reed(1074, 157, 0.8);

    // 选中河段：一束很淡的暖光从题签落到水面，把“签—记号—水”连成一处
    const anchor = this.points[this.selectedIndex];
    const glow = c.createRadialGradient(anchor.x, 158, 8, anchor.x, 158, 104);
    glow.addColorStop(0, 'rgba(228,190,120,0.34)'); glow.addColorStop(1, 'rgba(228,190,120,0)');
    c.fillStyle = glow; c.fillRect(anchor.x - 110, 100, 220, 130);

    this.drawRiver();
    // 舟停在当前城市的河段前，随选择一起换位
    this.drawBoat(anchor.x + 62, this.SHORE + 26, 1.05);

    // 五城图记：挂在题签下方、落在岸线上，收成“一枚签 + 一个记号”的站点
    this.points.forEach((point: RiverCityPoint, index: number) => {
      const selected = index === this.selectedIndex;
      this.stroke(point.x, this.TAG_BOTTOM, point.x, point.y - 5, selected ? '#B47A62' : '#BBB090', 1);
      // 岸线上一枚小方印标出站点；选中时放大并换成朱砂，与水面的暖光同指一处
      this.sealSquare(point.x, point.y, selected ? 7 : 4, selected ? R.cinnabar : '#9E9A78', true);
      if (selected) {
        this.stroke(point.x - 14, this.SHORE + 5, point.x + 14, this.SHORE + 5, R.cinnabar, 2.2);
      }
      // 水面只用一小段暖色横线表示倒影，不画竖线（竖线会被读成一根杆子）
      if (selected) {
        c.globalAlpha = 0.5;
        this.stroke(point.x - 14, this.SHORE + 12, point.x + 14, this.SHORE + 12, '#F0D59A', 2);
        c.globalAlpha = 1;
      }
    });
    c.restore();
    // 河卷画到 250 就结束，直接接卡片会留一条硬切的水色边；用纸色渐隐收口。
    const fade = c.createLinearGradient(0, this.riverHeight() - 28, 0, this.riverHeight());
    fade.addColorStop(0, 'rgba(245,240,228,0)');
    fade.addColorStop(1, '#F5F0E4');
    c.fillStyle = fade;
    c.fillRect(0, this.riverHeight() - 28, this.ART_W, 28);
  }

  // —— 题签 ——

  // 题签做成“书名签”：序号、竖排城名、一字城徵。
  // 城徵用单字而不是缩小插画——在 28vp 宽的签上，字形比线条更能被准确辨认，
  // 也不承担“这城长什么样”的复原责任。
  private readonly EMBLEMS: string[] = ['院', '阙', '门', '桥', '蚌'];

  private tagHeight(index: number): number {
    return ROAM_CHAPTERS[index].city.length * 19 + 7 + 18 + 9;
  }

  @Builder
  cityLabel(index: number) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 0 }) {
        Column({ space: 0 }) {
          ForEach(ROAM_CHAPTERS[index].city.split(''), (char: string, charIndex: number) => {
            Text(char).fontSize(15).fontWeight(FontWeight.Medium)
              .fontColor(this.selectedIndex === index ? R.ink : R.inkSoft)
              .height(19).textAlign(TextAlign.Center).width('100%')
          }, (char: string, charIndex: number) => `${index}:${charIndex}:${char}`)
        }.width('100%').margin({ top: 7 })
        Text(this.EMBLEMS[index]).fontSize(12).letterSpacing(0)
          .fontColor(this.selectedIndex === index ? R.cinnabar : '#7C8874')
          .width(18).height(18).textAlign(TextAlign.Center)
          .border({ width: 1, color: this.selectedIndex === index ? 'rgba(166,76,55,0.6)' : '#CBC4AA', radius: 1 })
          .borderRadius(1).margin({ top: 6 })
      }.width('100%').justifyContent(FlexAlign.Center)
    }.width(30).height(this.tagHeight(index)).padding(0)
      .backgroundColor(this.selectedIndex === index ? '#FBF3E0' : '#F8F2DE')
      .border({ width: this.selectedIndex === index ? 1.4 : 1,
        color: this.selectedIndex === index ? R.cinnabar : '#D5CBA9', radius: 3 })
      .borderRadius(3)
      .shadow({ radius: 4, color: 'rgba(60,52,30,0.12)', offsetX: 0, offsetY: 1 })
      .position({ x: this.points[index].x - 15, y: this.TAG_BOTTOM - this.tagHeight(index) })
      .id(`roam-city-${ROAM_CHAPTERS[index].id}`)
      .sharedTransition(`roam-title-${ROAM_CHAPTERS[index].id}`, { duration: this.reducedMotion ? 0 : 360, curve: Curve.EaseOut })
      .accessibilityText(`${ROAM_CHAPTERS[index].city}，${ROAM_CHAPTERS[index].title}，选择这一城`)
      .onClick(() => this.select(index))
  }

  @Builder
  riverRoll() {
    Stack() {
      Scroll(this.riverScroller) {
        Stack({ alignContent: Alignment.TopStart }) {
          Canvas(this.context).width(this.ART_W).height(this.riverHeight()).onReady(() => {
            this.canvasReady = true;
            // 冷启动恢复城市后，长卷的可见河段也要一起恢复，避免题签与当前目标不对应。
            this.select(this.selectedIndex);
          })
            .onAreaChange(() => this.draw())
            .hitTestBehavior(HitTestMode.None)
          ForEach([0, 1, 2, 3, 4], (index: number) => { this.cityLabel(index) }, (index: number) => index.toString())

        }.width(this.ART_W).height(this.riverHeight())
      }.width('100%').height(this.riverHeight()).scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring).id('roam-river-scroll').clip(true)
        .onAreaChange((_old: Area, area: Area) => {
          const width = Number(area.width);
          const resized = Math.abs(this.containerWidth - width) > 1;
          this.containerWidth = width;
          // 纵向滚动也会触发位置变化；仅尺寸变化时重新居中，不抢走用户手动横拖的河段。
          if (this.canvasReady && resized) this.select(this.selectedIndex);
        })
      // 两端柔和过渡，避免题签在视口边缘被硬切一半。
      // 8 位色值是 #AARRGGBB，透明端必须写成 #00RRGGBB；写成 #RRGGBB00 会得到高不透明度的异色。
      Row().width(22).height('100%').position({ x: 0, y: 0 }).hitTestBehavior(HitTestMode.None)
        .linearGradient({ angle: 90, colors: [[R.paper, 0], ['#00F5F0E4', 1]] })
      Row().width(22).height('100%').position({ x: '100%', y: 0 }).translate({ x: -22 }).hitTestBehavior(HitTestMode.None)
        .linearGradient({ angle: 270, colors: [[R.paper, 0], ['#00F5F0E4', 1]] })
    }.width('100%').height(this.riverHeight())
  }

  // 卷目条：河卷一屏只能看到当前城（1120 逻辑宽，手机约 400dp），
  // 必须有一条始终可见的五城切换，否则用户不知道还有另外四城。
  // 选中态用墨色下划线，已建成的城用金点，和河卷题签是同一套语义。
  @Builder
  cityIndex() {
    Row({ space: 0 }) {
      ForEach(ROAM_CHAPTERS, (chapter: RoamChapter, index: number) => {
        Column({ space: 4 }) {
          Text(chapter.city).fontSize(13)
            .fontWeight(this.selectedIndex === index ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.selectedIndex === index ? R.ink : R.muted)
            .maxLines(1)
          Row().width(18).height(2).borderRadius(1)
            .backgroundColor(this.selectedIndex === index ? R.cinnabar : Color.Transparent)
          Row().width(4).height(4).borderRadius(2)
            .backgroundColor(roamProgress(this.records, chapter).completed ? R.gold : Color.Transparent)
        }.layoutWeight(1).height(44).justifyContent(FlexAlign.Center)
          .id(`roam-pick-${chapter.id}`)
          .accessibilityText(`${chapter.city}，${chapter.title}，选择这一城`)
          .onClick(() => this.select(index))
      }, (chapter: RoamChapter) => chapter.id)
    }.width('100%').padding({ left: 8, right: 8 })
  }

  // 开卷：把“这一城要做什么”写在一张册页上，而不是再叠一个圆角卡片
  @Builder
  openPanel() {
    Column({ space: 0 }) {
      Row({ space: 8 }) {
        Text(this.chapter().kicker).fontSize(12).fontColor(R.cinnabar).letterSpacing(1.2).layoutWeight(1)
        if (this.cityLine().length > 0) {
          Text(this.cityLine()).fontSize(12).fontColor(R.cinnabar).id('roam-home-city-grade')
        } else {
          Text(`${this.progress().completedCount} / 3 线索`).fontSize(12).fontColor(R.muted).id('roam-home-progress')
        }
      }.width('100%')
      Text(this.chapter().title).fontSize(this.chapter().title.length > 12 ? 21 : 24)
        .fontWeight(FontWeight.Bold).fontColor(R.ink).letterSpacing(0.5)
        .lineHeight(30).maxLines(2).width('100%').margin({ top: 8 })
        .id('roam-home-chapter-title')
      Row({ space: 11 }) {
        Row().width(2).height(38).backgroundColor(this.progress().completed ? R.gold : '#D9C6A6')
        Text(this.goalWithCity()).fontSize(14).lineHeight(22).fontColor(R.inkSoft).maxLines(2).layoutWeight(1)
          .id('roam-home-current-goal')
      }.width('100%').alignItems(VerticalAlign.Center).margin({ top: 12 })

      Button({ type: ButtonType.Normal }) {
        Row({ space: 10 }) {
          Text(this.cityGrade().grade > 0 ? '回城' : this.progress().completed ? '重走这一城' :
            this.progress().completedCount > 0 ? '接着这段漫游' : '走进这一城')
            .fontSize(16).fontWeight(FontWeight.Medium).fontColor(R.paperHigh).layoutWeight(1).letterSpacing(1)
          Text('→').fontSize(20).fontColor('#C9D6C0')
        }.width('100%')
      }.width('100%').height(48).padding({ left: 18, right: 18 }).backgroundColor(R.river)
        .borderRadius(10).margin({ top: 14 }).id('roam-start').onClick(() => this.onOpen(this.chapter().id))
        .accessibilityText(`走进${this.chapter().city}，${this.chapter().title}`)

      // 开封的主玩法不在三幕里。首页必须给出独立入口，否则玩家只会看到「档案导读」。
      if (this.chapter().id === 'roam-kf-night') {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 10 }) {
            Column({ space: 3 }) {
              Row({ space: 6 }) {
                Text('汴河探方').fontSize(14).fontWeight(FontWeight.Medium).fontColor(R.ink)
                Text('主玩法').fontSize(10).fontColor(R.cinnabar)
                  .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                  .border({ width: 1, color: R.cinnabar, radius: 3 })
              }
              Text(this.digGrade() !== '' ? `本机最佳 ${this.digGrade()} · 换局会换布局` :
                '8 个工日，靠证据定桥轴，不看答案')
                .fontSize(11).fontColor(R.muted).maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text('›').fontSize(18).fontColor(R.faint)
          }.width('100%')
        }.width('100%').height(52).padding({ left: 12, right: 12 }).margin({ top: 8 })
          .backgroundColor(R.washJade).borderRadius(9).id('roam-open-dig')
          .accessibilityText('进入汴河探方')
          .onClick(() => this.onOpenDig(this.chapter().id))
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
      .backgroundColor(R.page).borderRadius(12).margin({ top: 12 })
  }

  @Builder
  entryRow(glyph: string, glyphColor: string, title: string, detail: string, tail: string, id: string, action: () => void) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        Text(glyph).fontSize(15).fontColor(glyphColor).width(32).height(32).textAlign(TextAlign.Center)
          .backgroundColor(glyphColor === R.cinnabar ? R.paleCinnabar : R.paleJade).borderRadius(16)
        Column({ space: 4 }) {
          Text(title).fontSize(15).fontColor(R.ink)
          Text(detail).fontSize(12).fontColor(R.muted)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Text(tail).fontSize(15).fontColor(R.faint)
      }.width('100%')
    }.width('100%').height(58).padding(0).backgroundColor(Color.Transparent).id(id).onClick(action)
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 0 }) {
        // 顶栏已经写「漫游」，这里不再叠一个 30 号大标题：省下的高度正好让
        // 河卷、卷目与「回城」主按钮同屏出现，不用先滚一下才看到主操作。
        Row({ space: 8 }) {
          Row().width(16).height(2).borderRadius(1).backgroundColor(R.cinnabar)
          Text('黄河 · 五城漫游').fontSize(11).fontColor(R.cinnabar).letterSpacing(1)
          Text(this.totalCompleted() > 0 ? `已展开 ${this.totalCompleted()} 城` : '亲手发现一座城').fontSize(11).fontColor(R.muted)
        }.width('100%').padding({ left: 20, right: 20 }).margin({ top: 4, bottom: 2 })

        this.riverRoll()
        this.cityIndex()

        Column({ space: 0 }) {
          this.openPanel()
          Column({ space: 0 }) {
            this.entryRow('阅', R.river, '自由读文化库', '遗址、诗文与生活材料', '↗', 'roam-home-library', this.onLibrary)
            Divider().color(R.lineSoft)
            this.entryRow('笺', R.cinnabar, '我留下的记忆', `${this.memoryCount()} 页亲笔记录`, '›', 'roam-home-memory', this.onMemory)
          }.width('100%').margin({ top: 10 })
          // 五城志：只把真正走完三幕的城记作“成城”，其余四城如实写“档案可读”。
          Column({ space: 5 }) {
            Row({ space: 8 }) {
              Text('五城志').fontSize(12).fontColor(R.cinnabar).letterSpacing(1.5)
              Text(`${this.fiveCityCount()} / 5 成城`).fontSize(12).fontColor(R.muted).layoutWeight(1)
                .id('roam-home-five-cities')
            }.width('100%')
            Text('其余四城仍以已读档案点亮；只有亲手建过的那一城，才记成城。')
              .fontSize(11).fontColor(R.faint).lineHeight(17).width('100%')
          }.width('100%').alignItems(HorizontalAlign.Start).margin({ top: 16 })
        }.width('100%').padding({ left: 20, right: 20, bottom: this.bottomClearance })
      }.width('100%').constraintSize({ maxWidth: 1160 }).alignItems(HorizontalAlign.Start)
        .padding({ top: this.topClearance })
    }.width('100%').height('100%').align(Alignment.Top).backgroundColor(R.paper).scrollBar(BarState.Off).id('roaming-home')
  }
}
