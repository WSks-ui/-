// SelectionContainerAttribute 无文本使用点，但编译器解析 SelectionContainer 的链式属性调用
// 时要求该类型名在本文件可解析；从导入移除会导致 1327 行附近的链式调用编译失败。
import { SelectionContainer, SelectionContainerAttribute, SelectionContainerController, SelectionContainerTextJoinStyle } from '@kit.ArkUI';
import { unifiedDataChannel } from '@kit.ArkData';
import { ArchiveRecord, AiMemoryAssist, HeritageSite } from '../domain/ArchiveDomain';
import { RoamChapter, RoamClue, RoamOption, RoamSource, RoamingMemoryContext, roamProgress, roamChoice,
  makeRoamingMemoryContext } from '../domain/Roaming';
import { ROAM_CHAPTERS, ROAM_CONTENT_REVISION, ROAM_REVIEW_STATUS, ROAM_SOURCES } from '../data/RoamingCatalog';
import { HERITAGE_SITES } from '../data/HeritageCatalog';
import { HarmonyEffects } from '../platform/HarmonyEffects';
import { RoamingScene } from './RoamingScene';
import { KaifengPuzzleScene } from './KaifengPuzzleScene';
import {
  KAIFENG_BOAT_MOORING, KAIFENG_BOAT_START, KAIFENG_BRIDGE_ARCH, KAIFENG_BRIDGE_FLAT, KAIFENG_BRIDGE_START,
  KAIFENG_LANTERN_DEFAULT, KaifengCityV1, KaifengCrossing, KaifengLantern, KaifengLayerSlots, KaifengLightPoint,
  KaifengMotifSlots, emptyKaifengLayerSlots, emptyKaifengMotifSlots, judgeKaifengCrossing,
  kaifengBoatSpotFor, kaifengCoverage, kaifengHints, kaifengLayersComplete, kaifengLight,
  kaifengMotifComplete, placeKaifengLayer, placeKaifengMotif, serializeKaifengCity, settleKaifengBridge
} from '../domain/KaifengPuzzle';
import { kaifengCityFromRecords } from '../domain/KaifengRecords';
import {
  KAIFENG_AI_SITE_ID, KaifengAiAnswer, KaifengAiColophonResult, KaifengAiConflict,
  KaifengAiRequest, KaifengAiSentence, buildKaifengAiAssist, kaifengAiAnchorLabel
} from '../domain/KaifengAi';
import { KAIFENG_AI_STARTERS, kaifengAiFactFor } from '../domain/KaifengAiFacts';
import type { KaifengAiFact, KaifengAiStarter } from '../domain/KaifengAiFacts';
import { RoamingTheme as R } from './RoamingTheme';

// 五城共用节奏和保存边界，互动方式按城市与线索分别编排。
// “操作达到目标”仅是当前画面状态；只有主页面成功写回 progress 后才显示已展开。
// 亲笔正文始终从空白开始，通关不会自动生成手账、到访或用户感想。
@Component
export struct RoamingChapterPage {
  @Prop @Watch('chapterChanged') chapterId: string = '';
  @Prop @Watch('initialClueChanged') initialClueId: string = '';
  @Prop @Watch('recordsChanged') records: ArchiveRecord[] = [];
  @Prop saving: boolean = false;
  @Prop reducedMotion: boolean = false;
  @Prop accountSignedIn: boolean = false;
  onComplete: (clueId: string, choiceId: string, cityJson: string) => void = () => {};
  onCityChange: (chapterId: string, cityJson: string) => void = () => {};
  // AI 校书与问这一夜：由 Index 转发到账号服务 /ai/kaifeng。
  // 默认实现直接失败，未接线时页面显示真实原因，不伪造回答。
  onKaifengAsk: (request: KaifengAiRequest) => Promise<KaifengAiAnswer> =
    async (_request: KaifengAiRequest): Promise<KaifengAiAnswer> => {
      throw new Error('AI_NOT_CONFIGURED');
    };
  onKaifengColophon: (request: KaifengAiRequest) => Promise<KaifengAiColophonResult> =
    async (_request: KaifengAiRequest): Promise<KaifengAiColophonResult> => {
      throw new Error('AI_NOT_CONFIGURED');
    };
  onSave: (context: RoamingMemoryContext, body: string, tags: string[],
    assist?: AiMemoryAssist) => Promise<boolean> = async () => false;
  onOpenSite: (siteId: string) => void = () => {};
  onOpenMemory: () => void = () => {};
  onLogin: () => void = () => {};
  onBack: () => void = () => {};
  onOpenDig: (chapterId: string) => void = () => {};
  onPositionChange: (clueId: string) => void = () => {};
  @State private currentIndex: number = 0;
  @State private selectedId: string = '';
  @State private amount: number = 0;
  @State private found: string[] = [];
  @State private observed: boolean = false;
  @State private illuminated: boolean = false;
  @State private contentWidth: number = 360;
  @State private sheetOpen: boolean = false;
  @State private sheetMode: string = 'reading';
  @State private sourcesOpen: boolean = false;
  @State private selectedText: string = '';
  @State private cardContext: RoamingMemoryContext | undefined = undefined;
  @State private draftContext: RoamingMemoryContext | undefined = undefined;
  @State private customExcerpt: boolean = false;
  @State private noteBody: string = '';
  @State private noteTags: string = '';
  @State private noteBusy: boolean = false;
  @State private saved: boolean = false;
  @State private message: string = '';
  @State private dropHover: boolean = false;
  // 开封“叠城寻路”的玩法状态。桥位与叠合跨三步共用同一幅纸页，不随步骤切换清空；
  // 只有换城或重进本城才回到初始摆放，避免把上一城的关系带进来。
  @State private kfX: number = KAIFENG_BRIDGE_START.x;
  @State private kfY: number = KAIFENG_BRIDGE_START.y;
  @State private kfAngle: number = KAIFENG_BRIDGE_START.angle;
  // 北宋州桥是低平平桥；拱桥是明代改建后的形制，作为可尝试的错误答案保留。
  @State private kfKind: string = KAIFENG_BRIDGE_FLAT;
  @State private kfBoatX: number = KAIFENG_BOAT_START.x;
  @State private kfBoatY: number = KAIFENG_BOAT_START.y;
  @State private kfBoatSpot: string = 'front';
  @State private kfLayers: KaifengLayerSlots = emptyKaifengLayerSlots();
  @State private kfLayerMessage: string = '';
  @State private kfMotif: KaifengMotifSlots = emptyKaifengMotifSlots();
  @State private kfMotifDone: boolean = false;
  // 三盏灯只是初始摆位；灯数由“灯火”决定（B4 接入真实幕完成状态后改为派生）。
  // 起始点放在街西空地上，且与三个摊都超过 250 的照亮半径——开场必须是“三处都暗着”，
  // 否则第一帧就已经亮了一处，玩家会以为已经过关。
  @State private kfLights: KaifengLightPoint[] = [
    { id: 'l1', x: 170, y: 700 }, { id: 'l2', x: 170, y: 900 }, { id: 'l3', x: 170, y: 1100 }
  ];
  @State private kfFrame: string = KAIFENG_LANTERN_DEFAULT.frame;
  @State private kfPaper: string = KAIFENG_LANTERN_DEFAULT.paper;
  @State private kfSpot: string = KAIFENG_LANTERN_DEFAULT.spot;
  @State private kfLit: boolean = false;
  @State private kfHint: number = 0;
  @State private kfDemoUsed: boolean = false;
  // 成志时间只在第一次收束时写；重走不会把已存的 closedAt 抹掉。
  @State private kfClosedAt: number = 0;
  @State private kfNoteWritten: boolean = false;
  // AI 半模态只保存界面状态；回答与题跋不写快照，除非用户把题跋放进正文并自己保存。
  @State private aiOpen: boolean = false;
  @State private aiMode: string = 'ask';
  @State private aiQuestion: string = '';
  @State private aiBusy: boolean = false;
  @State private aiError: string = '';
  @State private aiAnswer: string = '';
  @State private aiCites: string[] = [];
  @State private aiAnchor: string = '';
  @State private aiShowQuotes: boolean = false;
  @State private aiSentences: KaifengAiSentence[] = [];
  @State private aiConflicts: KaifengAiConflict[] = [];
  @State private aiSuggestion: string = '';
  @State private aiDropped: number = 0;
  // 采纳题跋时冻结当时的依据；只有用户确认保存，才随正文写入 aiAssist。
  @State private aiAssist: AiMemoryAssist | undefined = undefined;
  private loadedChapterId: string = '';
  private pendingAdvanceId: string = '';
  private selectionController: SelectionContainerController = new SelectionContainerController();
  private sceneScroller: Scroller = new Scroller();

  aboutToAppear(): void { this.chapterChanged(); }
  private chapter(): RoamChapter { return ROAM_CHAPTERS.find((item: RoamChapter) => item.id === this.chapterId) || ROAM_CHAPTERS[0]; }
  private clue(): RoamClue { return this.chapter().clues[this.currentIndex] || this.chapter().clues[0]; }
  private wide(): boolean { return this.contentWidth >= 900; }
  private threeColumns(): boolean { return this.contentWidth >= 1000; }
  private completed(): boolean { return roamProgress(this.records, this.chapter()).completedIds.includes(this.clue().id); }
  private unlocked(): boolean { return this.currentIndex <= roamProgress(this.records, this.chapter()).completedCount; }
  private choiceIndex(): number { return this.clue().options.findIndex((option: RoamOption) => option.id === this.selectedId); }
  private chosen(): RoamOption | undefined { return this.clue().options.find((option: RoamOption) => option.id === this.selectedId); }
  private sceneHeight(): number {
    // 按当前内容区分给场景的真实宽度安排画幅，不能把整台平板宽度当成场景宽度。
    // 手机加高到 0.86 倍宽度：目标条现在压在画面下缘，需要更多画面高度承载街河关系，
    // 但仍要保证“场景 + 水程刻尺”落在同一屏内，不把第一个可操作控件推到屏幕外。
    if (this.threeColumns()) return Math.max(300, Math.min(380, this.contentWidth * 1.25 / 3.25 * 0.82));
    return this.wide() ? 400 : Math.max(268, Math.min(340, this.contentWidth * 0.86));
  }

  private chapterChanged(): void {
    if (this.loadedChapterId === this.chapter().id) return;
    this.loadedChapterId = this.chapter().id;
    // 换城时回到初始摆放：上一城用过的桥位、桥型、船位、层位与灯不该带进这一城。
    this.kfX = KAIFENG_BRIDGE_START.x; this.kfY = KAIFENG_BRIDGE_START.y; this.kfAngle = KAIFENG_BRIDGE_START.angle;
    this.kfKind = KAIFENG_BRIDGE_FLAT;
    this.kfBoatX = KAIFENG_BOAT_START.x; this.kfBoatY = KAIFENG_BOAT_START.y; this.kfBoatSpot = 'front';
    this.kfLayers = emptyKaifengLayerSlots(); this.kfLayerMessage = '';
    this.kfMotif = emptyKaifengMotifSlots(); this.kfMotifDone = false;
    this.kfLights = [ { id: 'l1', x: 170, y: 700 }, { id: 'l2', x: 170, y: 900 },
      { id: 'l3', x: 170, y: 1100 } ];
    this.kfFrame = KAIFENG_LANTERN_DEFAULT.frame; this.kfPaper = KAIFENG_LANTERN_DEFAULT.paper;
    this.kfSpot = KAIFENG_LANTERN_DEFAULT.spot; this.kfLit = false; this.kfHint = 0; this.kfDemoUsed = false;
    this.kfClosedAt = 0; this.kfNoteWritten = false;
    // 从城市快照恢复“你的汴京”：桥、桥型、船位、三层、纹样、灯与成志时间。
    // 船位只存 spot，位置按 spot 还原，避免把画面坐标当成历史数据长期保存。
    const stored = kaifengCityFromRecords(this.records, this.chapter().id);
    if (stored) {
      this.kfX = stored.bridge.x; this.kfY = stored.bridge.y; this.kfAngle = stored.bridge.angle;
      this.kfKind = stored.bridgeKind;
      this.kfBoatSpot = stored.boatSpot;
      const moored = stored.boatSpot === 'mooring';
      const under = stored.boatSpot === 'under';
      this.kfBoatX = moored ? KAIFENG_BOAT_MOORING.x : under ? stored.bridge.x : KAIFENG_BOAT_START.x;
      this.kfBoatY = moored ? KAIFENG_BOAT_MOORING.y : under ? stored.bridge.y : KAIFENG_BOAT_START.y;
      this.kfLayers = { lower: stored.layers.lower, middle: stored.layers.middle, upper: stored.layers.upper };
      this.kfMotif = { center: stored.motif.center, left: stored.motif.left,
        right: stored.motif.right, bottom: stored.motif.bottom };
      this.kfMotifDone = kaifengMotifComplete(this.kfMotif);
      if (stored.lights.length > 0) this.kfLights = stored.lights;
      this.kfFrame = stored.lantern.frame; this.kfPaper = stored.lantern.paper; this.kfSpot = stored.lantern.spot;
      this.kfClosedAt = stored.closedAt !== undefined ? stored.closedAt : 0;
      this.kfNoteWritten = stored.acts.note;
      this.kfDemoUsed = stored.acts.bridge && !stored.acts.bridgeIndependent;
      this.kfLit = kaifengCoverage(this.kfLights).passed;
    }
    const progress = roamProgress(this.records, this.chapter());
    const requested = this.chapter().clues.findIndex((clue: RoamClue) => clue.id === this.initialClueId);
    this.changeClue(requested >= 0 ? requested : progress.completed ? 2 : progress.completedCount, true);
  }

  private initialClueChanged(): void {
    const index = this.chapter().clues.findIndex((clue: RoamClue) => clue.id === this.initialClueId);
    if (index >= 0) this.changeClue(index, true);
  }

  private recordsChanged(): void {
    // 同步收到新版本不抢走正在读或写的片段；只响应本页刚刚确认的推进。
    if (this.pendingAdvanceId && roamProgress(this.records, this.chapter()).completedIds.includes(this.pendingAdvanceId)) {
      const index = this.chapter().clues.findIndex((clue: RoamClue) => clue.id === this.pendingAdvanceId);
      this.pendingAdvanceId = '';
      if (index >= 0 && index < this.chapter().clues.length - 1) this.changeClue(index + 1);
      else this.message = '这一城的三条线索已展开。想留下感受时，再写一页。';
    }
  }

  private changeClue(index: number, allowReading: boolean = false): void {
    if (index < 0 || index >= this.chapter().clues.length) return;
    if (!allowReading && index > roamProgress(this.records, this.chapter()).completedCount) return;
    this.currentIndex = index;
    // 第三幕的灯数由“灯火”决定：完成一幕 + 独立解桥 + 写页，封顶 3，最少 2。
    // 用了提示演示就少一盏，但两盏仍可用中点覆盖三处中的两处，不会死锁。
    if (this.kfMode() && index === 2 && this.kfLights.length > this.kfLampCount()) {
      this.kfLights = this.kfLights.slice(0, this.kfLampCount());
      this.kfLit = kaifengCoverage(this.kfLights).passed;
    }
    const previous = roamChoice(this.records, this.chapter().id, this.clue().id);
    this.selectedId = this.clue().options.some((option: RoamOption) => option.id === previous) ? previous : '';
    this.amount = previous ? 100 : 0;
    this.found = previous ? ['kiln', 'home'] : [];
    this.observed = previous.length > 0;
    this.illuminated = previous.length > 0;
    this.selectedText = ''; this.cardContext = undefined; this.message = '';
    try { this.selectionController.clearTextSelection(); } catch (_error) {}
    this.sceneScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
  }

  private selectTrail(index: number): void {
    if (this.saving || this.noteBusy || index === this.currentIndex ||
      index > roamProgress(this.records, this.chapter()).completedCount) return;
    this.changeClue(index);
    // 只有明确选择目录才上报阅读位置。初始化、同步派生和确认后的自动展开不从 Watch 回调再写库。
    this.onPositionChange(this.clue().id);
  }

  private move(value: number): void {
    if (this.currentIndex > 1) return;
    this.amount = Math.max(0, Math.min(100, value));
    if (this.currentIndex === 0) {
      if (this.chapter().scene === 'kf-night' && value >= 53 && value <= 78) this.observed = true;
      if ((this.chapter().scene === 'ly-spring' || this.chapter().scene === 'py-memory') && value >= 68) this.observed = true;
    }
  }

  private find(spotId: string): void {
    if (!this.found.includes(spotId)) this.found = this.found.concat([spotId]);
  }

  private choose(optionId: string): void {
    this.selectedId = optionId;
    this.message = '';
  }

  private kfMode(): boolean { return this.chapter().scene === 'kf-night'; }

  private kfCrossing(): KaifengCrossing {
    return judgeKaifengCrossing({ x: this.kfX, y: this.kfY, angle: this.kfAngle }, this.kfKind,
      { x: this.kfBoatX, y: this.kfBoatY, spot: this.kfBoatSpot });
  }

  private kfLantern(): KaifengLantern {
    return { frame: this.kfFrame, paper: this.kfPaper, wish: this.selectedId, spot: this.kfSpot };
  }

  // 摆放只改坐标；是否成立由规则层每次重算，不缓存“已解”标记。
  private kfMove(x: number, y: number, angle: number): void {
    if (this.saving) return;
    this.kfX = x; this.kfY = y; this.kfAngle = angle;
  }

  private kfSettle(): void {
    const settled = settleKaifengBridge({ x: this.kfX, y: this.kfY, angle: this.kfAngle });
    this.kfX = settled.x; this.kfY = settled.y; this.kfAngle = settled.angle;
    // 桥心移动后，船相对桥的归属（桥下/桥前）可能变化，必须重算。
    this.kfBoatSpot = kaifengBoatSpotFor(this.kfBoatX, this.kfBoatY, this.kfX, this.kfY);
    this.kfPersist();
  }

  private kfSetKind(kind: string): void {
    if (this.saving) return;
    this.kfKind = kind;
    this.kfPersist();
  }

  private kfMoveBoat(x: number, y: number): void {
    if (this.saving) return;
    this.kfBoatX = Math.max(120, Math.min(880, x));
    this.kfBoatY = Math.max(900, Math.min(1300, y));
    this.kfBoatSpot = kaifengBoatSpotFor(this.kfBoatX, this.kfBoatY, this.kfX, this.kfY);
    this.kfPersist();
  }

  // 层位与纹样都以领域层的三个/四个槽为准；场景只负责把拖放目标翻译成槽位名。
  private kfPlacedIds(): string[] {
    const ids: string[] = [];
    if (this.kfLayers.lower) ids.push(this.kfLayers.lower);
    if (this.kfLayers.middle) ids.push(this.kfLayers.middle);
    if (this.kfLayers.upper) ids.push(this.kfLayers.upper);
    return ids;
  }

  private kfLayersDone(): boolean { return kaifengLayersComplete(this.kfLayers); }

  private kfLampCount(): number {
    const crossing = this.kfCrossing();
    return Math.max(2, kaifengLight({
      bridge: crossing.solved, layers: this.kfLayersDone(), lantern: false,
      bridgeIndependent: crossing.solved && !this.kfDemoUsed, note: this.kfNoteWritten
    }));
  }

  private kfDropLayer(id: string, slot: string, distance: number): void {
    const result = placeKaifengLayer(this.kfLayers, id, slot, distance);
    this.kfLayers = result.slots;
    this.kfLayerMessage = result.message;
    if (result.aligned) this.kfPersist();
  }

  private kfDropMotif(pieceId: string, slot: string): void {
    if (!this.kfLayersDone()) return;
    const result = placeKaifengMotif(this.kfMotif, pieceId, slot);
    this.kfMotif = result.slots;
    this.kfMotifDone = result.complete;
    this.kfLayerMessage = result.message;
    if (result.aligned) this.kfPersist();
  }

  private kfMoveLight(index: number, x: number, y: number): void {
    const next: KaifengLightPoint[] = [];
    this.kfLights.forEach((light: KaifengLightPoint, current: number) => {
      next.push({ id: light.id, x: current === index ? x : light.x, y: current === index ? y : light.y });
    });
    this.kfLights = next;
    this.kfLit = kaifengCoverage(next).passed;
    this.kfPersist();
  }

  // 只在里程碑写盘：桥停稳、材料落槽、灯落位。收束时把城市一起交给 onComplete，
  // 与线索进度合并成一次 commit，避免两次落盘互相被 saving 锁丢掉。
  // 拖动过程不写 Preferences，避免每帧 flush 整份快照导致发涩与写入失败。
  private kfCityJson(close: boolean): string {
    if (close && this.kfClosedAt === 0) this.kfClosedAt = Date.now();
    const crossing = this.kfCrossing();
    const lights: KaifengLightPoint[] = [];
    this.kfLights.forEach((light: KaifengLightPoint) => lights.push({ id: light.id, x: light.x, y: light.y }));
    const city: KaifengCityV1 = {
      version: 1,
      chapterId: this.chapter().id,
      acts: {
        bridge: crossing.solved,
        layers: this.kfLayersDone(),
        lantern: this.kfLit,
        bridgeIndependent: crossing.solved && !this.kfDemoUsed,
        note: this.kfNoteWritten
      },
      bridge: { x: this.kfX, y: this.kfY, angle: this.kfAngle },
      bridgeKind: this.kfKind,
      boatSpot: this.kfBoatSpot,
      layers: { lower: this.kfLayers.lower, middle: this.kfLayers.middle, upper: this.kfLayers.upper },
      motif: { center: this.kfMotif.center, left: this.kfMotif.left,
        right: this.kfMotif.right, bottom: this.kfMotif.bottom },
      lantern: { frame: this.kfFrame, paper: this.kfPaper,
        wish: this.selectedId || KAIFENG_LANTERN_DEFAULT.wish, spot: this.kfSpot },
      lights,
      updatedAt: Date.now()
    };
    if (this.kfClosedAt > 0) city.closedAt = this.kfClosedAt;
    return serializeKaifengCity(city);
  }

  private kfPersist(): void {
    if (!this.kfMode() || this.saving) return;
    try {
      this.onCityChange(this.chapter().id, this.kfCityJson(false));
    } catch (_error) {
      // 超长或序列化失败不打断当前玩法；下一次里程碑会再试。
    }
  }

  // 重走只清本页工作状态，不删已存的城市；下一次收束才会覆盖桥面与灯。
  // 这样演示时可以“回城看一眼”再“重走一遍”，已建的城仍在首页。
  private kfRestart(): void {
    this.kfX = KAIFENG_BRIDGE_START.x; this.kfY = KAIFENG_BRIDGE_START.y; this.kfAngle = KAIFENG_BRIDGE_START.angle;
    this.kfKind = KAIFENG_BRIDGE_FLAT;
    this.kfBoatX = KAIFENG_BOAT_START.x; this.kfBoatY = KAIFENG_BOAT_START.y; this.kfBoatSpot = 'front';
    this.kfLayers = emptyKaifengLayerSlots(); this.kfLayerMessage = '';
    this.kfMotif = emptyKaifengMotifSlots(); this.kfMotifDone = false;
    this.kfLights = [ { id: 'l1', x: 170, y: 700 }, { id: 'l2', x: 170, y: 900 },
      { id: 'l3', x: 170, y: 1100 } ];
    this.kfLit = false; this.kfHint = 0; this.kfDemoUsed = false; this.kfClosedAt = 0;
  }

  // —— AI 校书 / 问这一夜 ——
  //
  // 只把“城的摘要”和用户问题/草稿发给模型；不发送账号、设备号或整份档案。
  // AI 返回只当待校验文本：引用、年份、锚点由 KaifengAi 领域层再判一次；
  // 未配置、超时、引用不足都显示真实原因，并保留手写路径。

  private kfAiCity(): string {
    const coverage = kaifengCoverage(this.kfLights);
    const grade = this.kfClosedAt > 0 ? '成志' : coverage.covered.length >= 3 ? '长明' :
      this.kfLit ? '市声' : this.kfLayersDone() ? '叠城' : this.kfCrossing().solved ? '桥成' : '空卷';
    return `桥型:${this.kfKind === KAIFENG_BRIDGE_FLAT ? '平桥' : '拱桥'}；` +
      `层位:${this.kfLayersDone() ? '宋-明-淤埋' : '未齐'}；` +
      `纹样:${this.kfMotifDone ? '海马双鹤祥云' : '未合'}；灯:${this.kfLights.length}盏；` +
      `亮:${coverage.covered.length}/3；城格:${grade}`;
  }

  private kfAiRequest(mode: string, question: string, draft: string): KaifengAiRequest {
    return { siteId: KAIFENG_AI_SITE_ID, mode, question, draft, city: this.kfAiCity() };
  }

  private openAi(mode: string): void {
    if (!this.accountSignedIn) {
      // 整屏关卡里没有 message 的落点，只赋值等于点了没反应；这里给出可见提示。
      this.toast('AI 校书需要登录同一账号；未登录时仍可手写这一页。');
      return;
    }
    this.aiOpen = true;
    this.aiMode = mode;
    this.aiError = '';
    this.aiAnswer = '';
    this.aiCites = [];
    this.aiAnchor = '';
    this.aiShowQuotes = false;
    this.aiSentences = [];
    this.aiConflicts = [];
    this.aiSuggestion = '';
    this.aiDropped = 0;
  }

  private closeAi(): void {
    if (this.aiBusy) return;
    this.aiOpen = false;
  }

  // 整屏关卡不渲染 message（它只出现在写作弹层里），所以关键提示要走 toast，
  // 否则用户会遇到“点了按钮什么都没发生”。
  private toast(text: string): void {
    this.message = text;
    try {
      this.getUIContext().getPromptAction().showToast({ message: text, duration: 2600 });
    } catch (_error) {
      // 页面尚未挂载时没有 UI 上下文，忽略即可，message 仍留给下次渲染。
    }
  }

  private aiErrorText(code: string): string {
    if (code.indexOf('NOT_CONFIGURED') >= 0) return 'AI 未配置：服务端没有模型密钥。可以先自己写。';
    if (code.indexOf('TIMEOUT') >= 0) return '模型超时。稍后再试，或直接手写这一页。';
    if (code.indexOf('UNGrounded') >= 0 || code.indexOf('UNGROUNDED') >= 0) return '回答里出现了依据表以外的年份，已拒收。';
    if (code.indexOf('NEEDS_CITATION') >= 0) return '这次回答没有给出处，已拒收。';
    if (code.indexOf('UNKNOWN_FACT') >= 0) return '回答引用了不在事实表里的条目，已拒收。';
    if (code.indexOf('SESSION') >= 0) return '登录已过期，请重新登录后再问。';
    return `这次没有拿到可用回答：${code}`;
  }

  private async askAi(): Promise<void> {
    if (this.aiBusy || !this.aiQuestion.trim()) return;
    this.aiBusy = true; this.aiError = '';
    try {
      const answer = await this.onKaifengAsk(this.kfAiRequest('ask', this.aiQuestion.trim(), ''));
      this.aiAnswer = answer.answer;
      this.aiCites = answer.cites;
      this.aiAnchor = answer.anchor;
    } catch (error) {
      this.aiError = this.aiErrorText((error as Error).message);
    } finally {
      this.aiBusy = false;
    }
  }

  private async writeColophon(): Promise<void> {
    if (this.aiBusy) return;
    this.aiBusy = true; this.aiError = '';
    try {
      const result = await this.onKaifengColophon(this.kfAiRequest('colophon', '', this.noteBody.trim()));
      this.aiSentences = result.sentences;
      this.aiConflicts = result.conflicts;
      this.aiSuggestion = result.suggestion;
      this.aiDropped = result.dropped;
    } catch (error) {
      this.aiError = this.aiErrorText((error as Error).message);
    } finally {
      this.aiBusy = false;
    }
  }

  // 采纳后只把题跋放进正文草稿，是否保存仍由用户点“存”决定；
  // 题目要求个人文字与 AI 参考分开，这里不自动生成手账，也不自动写入 aiAssist。
  private adoptColophon(): void {
    if (this.aiSentences.length === 0) return;
    const text: string[] = [];
    this.aiSentences.forEach((sentence: KaifengAiSentence) => text.push(sentence.text));
    this.noteBody = text.join('');
    // 冻结这次采纳所依据的事实；只保存 id、标题、正文与来源，不保存模型原文。
    try {
      this.aiAssist = buildKaifengAiAssist('为我的汴京城写题跋', {
        sentences: this.aiSentences, dropped: this.aiDropped,
        conflicts: this.aiConflicts, suggestion: this.aiSuggestion
      });
    } catch (_error) {
      this.aiAssist = undefined;
    }
    this.aiOpen = false;
    if (!this.selectedId && !this.draftContext) {
      this.message = '题跋已放进草稿。先选一个这次想留下的祝愿，再保存。';
      return;
    }
    this.openWriting();
  }

  private kfPickHint(): void {
    if (this.kfCrossing().solved) return;
    this.kfHint = Math.min(3, this.kfHint + 1);
    const hint = kaifengHints(this.kfHint);
    if (hint.demo) {
      // 演示直接给出一次成立摆放，并如实记下“不是玩家独立解出”。
      this.kfDemoUsed = true;
      this.kfX = 500; this.kfY = 1030; this.kfAngle = 90;
      this.kfKind = KAIFENG_BRIDGE_FLAT;
      this.kfBoatX = KAIFENG_BOAT_MOORING.x; this.kfBoatY = KAIFENG_BOAT_MOORING.y;
      this.kfBoatSpot = 'mooring';
    }
  }

  private kfStatusWord(): string {
    const crossing = this.kfCrossing();
    if (crossing.solved) return '御街与船各有走法';
    if (crossing.verdict === 'arch-blocks-cart') return '拱桥：车驾上不去';
    if (crossing.verdict === 'boat-at-bridge' || crossing.verdict === 'boat-under') return '桥低平，船要改道';
    if (crossing.verdict === 'along-river') return '水路被堵';
    if (crossing.verdict === 'offset') return '跨河，未对准街口';
    if (crossing.verdict === 'north-only' || crossing.verdict === 'south-only') return '只接通一端';
    return '尚未接通';
  }

  // 按钮只说下一步该做什么：未成立时不假装“已展开”，也不继承旧记录的说法。
  private kfButtonWord(): string {
    if (this.saving) return '正在保存进度';
    if (this.interactionReady()) return this.currentIndex < 2 ? '确认这一段，继续' : '收好这一城的故事';
    if (this.currentIndex === 0) {
      return this.kfCrossing().bridgeFormOk ? '先把船移到东岸泊位' : '北宋州桥用平桥';
    }
    if (this.currentIndex === 1) return this.kfLayersDone() ? '把石壁残纹放好' : '先把三份材料叠上去';
    return '把灯拖到三处摊前';
  }

  // 幕二要求层位与纹样都成立：层位说清“同一处的三个年代”，纹样说清石壁的内容。
  private kfLayerReady(): boolean { return this.kfLayersDone() && this.kfMotifDone; }

  private kfApplyPart(kind: string, id: string): void {
    if (kind === 'frame') this.kfFrame = id;
    else if (kind === 'paper') this.kfPaper = id;
    else if (kind === 'wish') this.selectedId = id;
  }

  private kfStageName(): string {
    if (this.currentIndex === 0) return '让御街过得去，也给船找到走法';
    if (this.currentIndex === 1) return '同一处，三个年代';
    return '把灯放回州桥夜市';
  }

  private interactionReady(): boolean {
    if (this.kfMode()) {
      if (this.currentIndex === 0) return this.kfCrossing().solved;
      if (this.currentIndex === 1) return this.kfLayerReady();
      return this.kfLit;
    }
    if (this.currentIndex === 2) return true;
    if (this.currentIndex === 1) return this.amount >=
      (this.chapter().scene === 'ly-spring' || this.chapter().scene === 'zz-meeting' ? 98 : 72);
    if (this.chapter().scene === 'smx-home') return this.found.includes('kiln') && this.found.includes('home');
    if (this.chapter().scene === 'zz-meeting') return this.selectedId.length > 0 && this.amount >= 72;
    return this.observed;
  }

  private canConfirm(): boolean { return this.unlocked() && this.interactionReady() && this.selectedId.length > 0 && !this.saving; }

  private confirm(): void {
    if (!this.canConfirm()) return;
    if (this.completed() && roamChoice(this.records, this.chapter().id, this.clue().id) === this.selectedId) {
      if (this.currentIndex < 2) this.changeClue(this.currentIndex + 1);
      else this.toast('已经读过这一城。可以重看任一片段，也可以写下新的感受。');
      return;
    }
    this.pendingAdvanceId = this.clue().id;
    // 收束时把城市与线索进度一起提交；第三幕收束同时记下 closedAt（成志时间）。
    const cityJson = this.kfMode() ? this.kfCityJson(this.currentIndex === 2) : '';
    this.onComplete(this.clue().id, this.selectedId, cityJson);
  }

  private feedback(): string {
    if (!this.unlocked()) return '这一段可以自由阅读。先完成前面的线索，再确认探索进度。';
    if (this.kfMode()) {
      if (this.currentIndex === 0) {
        // 反馈说清“哪个关系没成立、断点在哪”，并直接引用史料，不只是“错误，再试一次”。
        return this.kfCrossing().message;
      }
      if (this.currentIndex === 1) {
        if (!this.kfLayersDone()) {
          return this.kfLayerMessage || '把宋、明、明末三片材料拖到下、中、上三条层带。';
        }
        if (!this.kfMotifDone) {
          return this.kfLayerMessage || '按「一匹海马、两只仙鹤环以祥云」把残纹放好。';
        }
        return '宋代桥基在下，明代桥体在上，明末淤埋盖住它们；石壁的海马与双鹤也合拢了。';
      }
      if (this.kfLit && !this.selectedId) return '三处摊都亮了。再选一个这次想留下的祝愿。';
      return kaifengCoverage(this.kfLights).message;
    }
    if (this.currentIndex === 0 && this.chapter().scene === 'smx-home' && !this.interactionReady()) {
      return `已找到 ${this.found.length} / 2 处生活线索 · 点画面里的“作”和“居”看看。`;
    }
    if (!this.interactionReady()) {
      if (this.currentIndex === 0 && this.chapter().scene === 'kf-night') return '让船沿水线行至桥下，看看水与街在哪里相接。';
      if (this.currentIndex === 2 && this.chapter().scene === 'kf-night') return '选好一个祝愿，再点亮这盏灯。';
      if (this.currentIndex === 1 && (this.chapter().scene === 'ly-spring' || this.chapter().scene === 'zz-meeting')) return '继续拨动，把这一句慢慢读完整。';
      return '拖动画面或下方滑条，让线索完整进入视野。';
    }
    return this.chosen()?.detail || '已经看见了关系。选一个这次最想记住的片段。';
  }

  private sliderTitle(): string {
    if (this.currentIndex === 0) {
      if (this.chapter().scene === 'kf-night') return '循着水线找州桥';
      if (this.chapter().scene === 'zz-meeting') return this.choiceIndex() === 1 ? '沿路走向陆门' : '沿水驶向水门';
      if (this.chapter().scene === 'py-memory') return '移动蚌纹观察窗';
      return '移动伊河景窗';
    }
    if (this.chapter().scene === 'smx-home') return '揭开地表';
    if (this.chapter().scene === 'kf-night') return '拨动时间观察窗';
    if (this.chapter().scene === 'py-memory') return '展开传说与纪念的纸页';
    return this.chapter().scene === 'ly-spring' ? '拨开花影，读出这一句' : '沿着字词，寻找水名';
  }

  private quote(): string {
    // 仅使用目录中已经标明作者与出处的两处短引；不从标题拼接或生成“古诗”。
    if (this.chapter().scene === 'ly-spring') return '洛阳之俗，大抵好花。';
    if (this.chapter().scene === 'zz-meeting') return '溱与洧，方涣涣兮。';
    return '';
  }

  private revealedQuote(): string {
    const text = this.quote(); const count = Math.max(0, Math.min(text.length, Math.floor(this.amount / 100 * text.length)));
    return `${text.slice(0, count)}${count < text.length ? ' · · ·' : ''}`;
  }

  private shortInstruction(): string {
    if (this.currentIndex === 0) {
      if (this.chapter().scene === 'smx-home') return '点画面里的“作”和“居”，再选一条观察。';
      if (this.chapter().scene === 'kf-night') return '拖动桥片与铜环；点桥型切换平桥/拱桥，再把船拖到东岸泊位。';
      if (this.chapter().scene === 'zz-meeting') return '先选水门或陆门，再向右拖动画面或滑条。';
      if (this.chapter().scene === 'py-memory') return '横向拖动观察窗，让蚌塑轮廓进入视野。';
      return '向右拖动景窗，观察两岸山水。';
    }
    if (this.currentIndex === 1) {
      if (this.chapter().scene === 'smx-home') return '向右拖开地表遮罩，看看院落怎样展开。';
      if (this.chapter().scene === 'kf-night') return '把宋、明、明末三片材料拖到下、中、上三条层带；再拼好石壁残纹。';
      if (this.chapter().scene === 'py-memory') return '向右展开纸页，区分传说与纪念空间。';
      return '拨动滑条读全短句，再选择喜欢的意思。';
    }
    if (this.chapter().scene === 'kf-night') return '拖动三盏灯，照到桥头水饭、水边爊肉、街口干脯三处摊。';
    if (this.chapter().scene === 'smx-home') return '试选图案，让原创窗花装点纸页。';
    if (this.chapter().scene === 'ly-spring') return '试选一片尾页，让汤羹与相聚改变画面。';
    if (this.chapter().scene === 'zz-meeting') return '试选片段，留下河边、城门或一句诗。';
    return '试选线索，看看龙乡的回声怎样展开。';
  }

  private sources(): RoamSource[] {
    const result: RoamSource[] = [];
    this.clue().sourceIds.forEach((id: string) => {
      const source = ROAM_SOURCES.find((item: RoamSource) => item.id === id);
      if (source) result.push(source);
    });
    return result;
  }

  private photoSite(): HeritageSite | undefined {
    // 只复用首条关联档案中已随包授权的对应照片。州桥没有匹配照片时直接留白，
    // 不拿铁塔、街景或网上未授权图片替代；也不让实物照片承担原创图景的复原身份。
    if (this.currentIndex !== 0) return undefined;
    const site = HERITAGE_SITES.find((item: HeritageSite) => item.id === this.chapter().relatedSiteIds[0]);
    return site && site.photos.length > 0 ? site : undefined;
  }

  private context(excerpt?: string): RoamingMemoryContext {
    // 默认冻结当前资料与用户明确选择的片段；它是资料依据，不写进亲笔正文。
    // 手动跨段选摘后只替换 excerpt，出处仍由当前线索给出。界面展示同一份将保存的上下文。
    const value = makeRoamingMemoryContext(this.chapter(), this.clue(), this.selectedId, ROAM_SOURCES, ROAM_CONTENT_REVISION);
    if (excerpt !== undefined) value.excerpt = excerpt;
    return value;
  }

  private visibleDraftContext(): RoamingMemoryContext | undefined {
    if (this.draftContext) return this.draftContext;
    if (!this.selectedId) return undefined;
    return this.context();
  }

  private createExcerpt(): void {
    if (!this.selectedId || !this.selectedText.trim()) return;
    this.cardContext = this.context(this.selectedText.trim().slice(0, 1800));
    this.message = '已做成摘录笺。可加入草稿，宽屏也可拖入右侧记忆笺。';
    try { this.selectionController.closeSelectionMenu(); } catch (_error) {}
  }

  private addExcerpt(context: RoamingMemoryContext): void {
    // 这里只加入本页草稿。正文与 excerpt 分别保存，不能把文化材料自动当成用户亲笔感想。
    const frozen: RoamingMemoryContext = { version: context.version, chapterId: context.chapterId, clueId: context.clueId,
      sceneRevision: context.sceneRevision, choiceId: context.choiceId, excerpt: context.excerpt,
      title: context.title, city: context.city,
      sources: context.sources.map((source: RoamSource): RoamSource => ({ id: source.id, title: source.title,
        url: source.url, accessedAt: source.accessedAt })) };
    if (context.contentRevision !== undefined) frozen.contentRevision = context.contentRevision;
    this.draftContext = frozen;
    this.customExcerpt = true;
    this.saved = false; this.message = '摘录已放入草稿，写下自己的感受后再保存。';
  }

  private startDrag(event: DragEvent): DragItemInfo {
    if (!this.cardContext) return { extraInfo: 'roaming-excerpt-empty' };
    // API 26 本机声明核验（2026-10-23）：SelectionContainer 选中的文本不能直接拖。
    // 因此先生成独立摘录卡，再由 UDMF PlainText 承载带来源的上下文，系统负责拖拽会话。
    const text = new unifiedDataChannel.PlainText();
    text.textContent = JSON.stringify(this.cardContext); text.abstract = '云河纪·有出处的摘录笺';
    event.setData(new unifiedDataChannel.UnifiedData(text));
    return { builder: () => { this.excerptDragPreview(); }, extraInfo: 'roaming-excerpt-v1' };
  }

  private dropExcerpt(event: DragEvent): void {
    this.dropHover = false;
    try {
      const records = event.getData().getRecords();
      for (const record of records) {
        if (record.getType() !== 'general.plain-text') continue;
        const value = JSON.parse((record as unifiedDataChannel.PlainText).textContent) as RoamingMemoryContext;
        // 只接收本篇由已知线索与选项生成的摘录卡，不把外部任意文字标成已有文化出处。
        const clue = this.chapter().clues.find((item: RoamClue) => item.id === value.clueId);
        if (value.version !== 1 || value.chapterId !== this.chapter().id || !clue ||
          !clue.options.some((option: RoamOption) => option.id === value.choiceId) ||
          typeof value.excerpt !== 'string' || !value.excerpt.trim() || value.excerpt.length > 1800) continue;
        const frozenSources: RoamSource[] = [];
        if (!Array.isArray(value.sources) || value.sceneRevision !== 1) continue;
        value.sources.forEach((source: RoamSource) => {
          if (clue.sourceIds.includes(source.id) && typeof source.title === 'string' && typeof source.url === 'string' &&
            typeof source.accessedAt === 'string' && !frozenSources.some((item: RoamSource) => item.id === source.id)) {
            frozenSources.push({ id: source.id, title: source.title, url: source.url, accessedAt: source.accessedAt });
          }
        });
        if (frozenSources.length !== clue.sourceIds.length) continue;
        const frozen: RoamingMemoryContext = { version: 1, chapterId: this.chapter().id, clueId: clue.id, sceneRevision: 1,
          choiceId: value.choiceId, excerpt: value.excerpt, title: value.title,
          city: this.chapter().city, sources: frozenSources };
        if (value.contentRevision !== undefined) frozen.contentRevision = value.contentRevision;
        this.addExcerpt(frozen);
        event.setResult(DragResult.DRAG_SUCCESSFUL); return;
      }
      this.message = '把本篇生成的摘录笺拖到这里。'; event.setResult(DragResult.DRAG_FAILED);
    } catch (_error) {
      this.message = '这次没有收到摘录，请重新拖入或点击“加入草稿”。'; event.setResult(DragResult.DRAG_FAILED);
    }
  }

  private openReading(showSources: boolean = false): void {
    if (showSources) this.sourcesOpen = true;
    this.sheetMode = 'reading'; if (!this.wide() || this.kfMode()) this.sheetOpen = true;
  }

  private openWriting(): void {
    // 打开写作半模态时清掉上一段的提示，避免“三条线索已展开”之类的话
    // 落到写作区里被误读成保存错误。
    this.message = '';
    if (!this.selectedId && !this.draftContext) {
      this.message = '先选择一个想留下的片段，再写这一页。'; return;
    }
    if (!this.draftContext) { this.draftContext = this.context(); this.customExcerpt = false; }
    this.sheetMode = 'writing'; if (!this.wide() || this.kfMode()) this.sheetOpen = true;
  }

  private async saveNote(): Promise<void> {
    if (this.noteBusy || this.saving) return;
    if (!this.noteBody.trim()) { this.message = '先写下自己的感受，再存入记忆。'; return; }
    if (!this.draftContext && !this.selectedId) { this.message = '先选一个这次想留下的文化片段。'; return; }
    const context = this.draftContext || this.context();
    const tags = this.noteTags.trim().split(/[，,、\s]+/).filter((tag: string) => tag.length > 0);
    this.noteBusy = true; this.message = '';
    try {
      const result = await this.onSave(context, this.noteBody.trim(), tags, this.aiAssist);
      // 保存成功的提示由按钮状态与“存”印承担，这里不再重复一行文字。
      if (result) {
        this.saved = true; this.message = '';
        // 依据只对这一次保存生效；再次编辑时不应把旧依据带到新一页。
        this.aiAssist = undefined;
        // 写下一页也算一次真实动作：记进城市快照，灯火与城格据此变化。
        if (this.kfMode()) { this.kfNoteWritten = true; this.kfPersist(); }
      } else this.message = '这一页还没有保存成功，草稿留在这里。';
    } catch (_error) { this.message = '这一页还没有保存成功，草稿留在这里。'; }
    finally { this.noteBusy = false; }
  }

  // 拨动位置的一句话读法：只在有明确空间含义的篇章给方位词，其余显示刻尺读数。
  private positionWord(): string {
    const value = Math.round(this.amount);
    if (this.chapter().scene === 'kf-night' && this.currentIndex === 0) {
      return value < 53 ? '桥西' : value <= 78 ? '桥下' : '桥东';
    }
    if (this.chapter().scene === 'kf-night' && this.currentIndex === 1) {
      return value < 34 ? '桥与街' : value < 68 ? '叠压层' : '今日地面';
    }
    return `${value}%`;
  }

  // 页头：城市、进度、标题、三段进度条。原来独立的“入景/读城/留意”步骤条
  // 合并成标题下的一条三段线，点哪一段就回到哪一步，省掉一行标签和一段高度。
  @Builder
  chapterHeader() {
    Column({ space: 0 }) {
      Row({ space: 10 }) {
        Text(this.chapter().kicker).fontSize(12).fontColor(R.cinnabar).letterSpacing(1.2).layoutWeight(1)
        Text(`${roamProgress(this.records, this.chapter()).completedCount} / 3`).fontSize(12).fontColor(R.muted)
          .letterSpacing(1).id('roam-chapter-progress')
      }.width('100%')
      Text(this.chapter().title).fontSize(this.threeColumns() ? 24 : this.wide() ? 30 : this.chapter().title.length > 12 ? 24 : 26)
        .lineHeight(this.wide() ? 40 : 36).fontWeight(FontWeight.Medium).fontColor(R.ink).letterSpacing(1)
        .width('100%').margin({ top: 8 }).id('roam-chapter-title')
      Row({ space: 6 }) {
        ForEach(this.chapter().clues, (clue: RoamClue, index: number) => {
          Column() {
            Row().width('100%').height(this.currentIndex === index ? 3 : 2).backgroundColor(
              this.currentIndex === index ? R.cinnabar :
                roamProgress(this.records, this.chapter()).completedIds.includes(clue.id) ? R.gold : R.lineSoft)
          }.layoutWeight(1).height(30).justifyContent(FlexAlign.Center)
            .enabled(index <= roamProgress(this.records, this.chapter()).completedCount && !this.saving && !this.noteBusy)
            .opacity(index > roamProgress(this.records, this.chapter()).completedCount ? 0.4 : 1)
            .id(`roam-step-${clue.id}`).onClick(() => this.selectTrail(index))
        }, (clue: RoamClue) => `${this.chapter().id}:${clue.id}:${this.currentIndex}:${roamProgress(this.records, this.chapter()).completedCount}`)
      }.width('100%').margin({ top: 10 })
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, top: this.wide() ? 16 : 10 })
      .sharedTransition(`roam-title-${this.chapter().id}`, { duration: this.reducedMotion ? 0 : 360, curve: Curve.EaseOut })
  }

  // 到达目标时盖一枚“已见”小印：动作产生的结果落在画面上，而不只写在下方说明里。
  @Builder
  sceneStamp() {
    if (this.interactionReady() && this.unlocked()) {
      Column() {
        Text('已').fontSize(13).fontColor('#FBF3E0')
        Text('见').fontSize(13).fontColor('#FBF3E0')
      }.width(28).height(36).justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(166,76,55,0.9)').borderRadius(2).rotate({ angle: -7 })
        .id('roam-scene-stamp')
        .transition(this.reducedMotion ? TransitionEffect.OPACITY :
          TransitionEffect.scale({ x: 1.6, y: 1.6 }).combine(TransitionEffect.opacity(0)).animation({ duration: 280, curve: Curve.EaseOut }))
    }
  }

  // 场景与“这一回要做什么”贴在一起：目标条压在画面下缘，用户不用来回滚动对照。
  @Builder
  sceneStage() {
    Stack({ alignContent: Alignment.TopStart }) {
      RoamingScene({ scene: this.chapter().scene, stage: this.currentIndex, amount: this.amount,
        choice: this.choiceIndex(), found: this.found, illuminated: this.illuminated,
        sceneHeight: this.sceneHeight(), interactive: true,
        onMove: (value: number) => this.move(value), onSpot: (id: string) => this.find(id) })
      Row() {
        Blank()
        this.sceneStamp()
      }.width('100%').padding({ right: 18, top: 14 }).hitTestBehavior(HitTestMode.None)
      Stack({ alignContent: Alignment.BottomStart }) {
        Column({ space: 6 }) {
          Row({ space: 9 }) {
            Text(this.clue().title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(R.ink).layoutWeight(1)
            if (this.completed()) { Text('已展开').fontSize(12).fontColor(R.gold) }
          }.width('100%')
          Text(this.clue().goal).fontSize(13).lineHeight(21).fontColor(R.inkSoft).width('100%')
            .id('roam-current-goal')
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, top: 26, bottom: 12 })
        // 8 位色值为 #AARRGGBB，透明端必须前置 00，否则会渲染成高不透明度异色。
        .linearGradient({ angle: 180, colors: [['#00F5F0E4', 0], ['#C8F5F0E4', 0.4],
          ['#F2F5F0E4', 0.72], ['#FFF5F0E4', 1]] })
        .hitTestBehavior(HitTestMode.None)
      }.width('100%').height('100%').hitTestBehavior(HitTestMode.None)
    }.width('100%').height(this.sceneHeight()).clip(true).id('roam-scene-stage')
  }

  // 片段选项：五城共用同一套“签”的读法，开封的玩法面板也复用它。
  @Builder
  clueOptions() {
    Column({ space: 0 }) {
      ForEach(this.clue().options, (option: RoamOption, index: number) => {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 12 }) {
            Row() {
              Text(`0${index + 1}`).fontSize(12).letterSpacing(0)
                .fontColor(this.selectedId === option.id ? '#FBF3E0' : '#8D947E')
            }.width(24).height(24).justifyContent(FlexAlign.Center)
              .backgroundColor(this.selectedId === option.id ? R.cinnabar : Color.Transparent)
              .border({ width: 1, color: this.selectedId === option.id ? R.cinnabar : '#CFC7AC', radius: 2 })
              .borderRadius(2)
            Text(option.label).fontSize(15).fontColor(this.selectedId === option.id ? R.ink : R.inkSoft)
              .layoutWeight(1).letterSpacing(0.5)
          }.width('100%')
        }.width('100%').height(54).padding({ left: 12, right: 14 })
          .backgroundColor(this.selectedId === option.id ? '#FAF1DE' : Color.Transparent)
          .border({ width: { bottom: 1 }, color: R.lineSoft })
          .borderRadius(0)
          .id(`roam-choice-${option.id}`).onClick(() => this.choose(option.id))
      }, (option: RoamOption) => `${this.clue().id}:${option.id}:${this.selectedId}`)
    }.width('100%')
  }

  // 开封的整屏关卡。画面铺满，界面只剩顶部一条进度和底部一条判读，
  // 都是压边而不是面板：可操作的物件全部在画面里，不再用列表和表单按钮控制。
  @Builder
  immersiveStage() {
    Stack({ alignContent: Alignment.TopStart }) {
      KaifengPuzzleScene({
        stage: this.currentIndex,
        bridgeX: this.kfX, bridgeY: this.kfY, bridgeAngle: this.kfAngle, bridgeKind: this.kfKind,
        boatX: this.kfBoatX, boatY: this.kfBoatY, boatSpot: this.kfBoatSpot,
        placed: this.kfPlacedIds(), layersComplete: this.kfLayersDone(),
        motifCenter: this.kfMotif.center, motifLeft: this.kfMotif.left,
        motifRight: this.kfMotif.right, motifBottom: this.kfMotif.bottom,
        motifComplete: this.kfMotifDone, lights: this.kfLights,
        hintHighlight: kaifengHints(this.kfHint).highlight,
        lanternFrame: this.kfFrame, lanternPaper: this.kfPaper, lanternWish: this.selectedId,
        lanternSpot: this.kfSpot, lit: this.kfLit, reducedMotion: this.reducedMotion,
        onBridgeMove: (x: number, y: number, angle: number) => this.kfMove(x, y, angle),
        onBridgeSettle: () => this.kfSettle(),
        onBoatMove: (x: number, y: number) => this.kfMoveBoat(x, y),
        onEvidenceDrop: (id: string, slot: string, distance: number) => this.kfDropLayer(id, slot, distance),
        onMotifDrop: (pieceId: string, slot: string) => this.kfDropMotif(pieceId, slot),
        onLightMove: (index: number, x: number, y: number) => this.kfMoveLight(index, x, y),
        onLanternPart: (kind: string, id: string) => this.kfApplyPart(kind, id)
      }).width('100%').height('100%')

      // 顶部压边：城市、这一段在做什么、三段进度（点哪段回哪段）。
      Column({ space: 9 }) {
        Row({ space: 10 }) {
          Text(this.chapter().city).fontSize(13).fontColor(R.cinnabar).letterSpacing(2)
          Text(this.kfStageName()).fontSize(14).fontColor(R.ink).layoutWeight(1)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.kfMode() && this.currentIndex === 0) {
            Button('重走', { type: ButtonType.Normal }).height(28).fontSize(12).padding({ left: 10, right: 10 })
              .fontColor(R.muted).backgroundColor('rgba(250,246,236,0.86)')
              .border({ width: 1, color: '#CFC5A6', radius: 14 }).borderRadius(14)
              .id('kf-restart').onClick(() => this.kfRestart())
          }
          if (this.kfMode()) {
            // 探方是主玩法，三幕只是导读；这里保留一个随时可切的入口。
            Button('探方', { type: ButtonType.Normal }).height(28).fontSize(12).padding({ left: 10, right: 10 })
              .fontColor(R.paperHigh).backgroundColor(R.river)
              .borderRadius(14).id('kf-open-dig')
              .accessibilityText('进入汴河探方')
              .onClick(() => this.onOpenDig(this.chapter().id))
            Button('问', { type: ButtonType.Normal }).height(28).fontSize(12).padding({ left: 10, right: 10 })
              .fontColor(R.river).backgroundColor('rgba(250,246,236,0.86)')
              .border({ width: 1, color: '#CFC5A6', radius: 14 }).borderRadius(14)
              .id('kf-ai-ask').onClick(() => this.openAi('ask'))
          }
          if (this.currentIndex === 0 && !this.kfCrossing().solved && this.kfHint < 3) {
            Button('提示', { type: ButtonType.Normal }).height(28).fontSize(12).padding({ left: 10, right: 10 })
              .fontColor(R.river).backgroundColor('rgba(250,246,236,0.86)')
              .border({ width: 1, color: '#CFC5A6', radius: 14 }).borderRadius(14)
              .id('kf-hint').onClick(() => this.kfPickHint())
          }
        }.width('100%')
        Row({ space: 6 }) {
          ForEach(this.chapter().clues, (clue: RoamClue, index: number) => {
            Column() {
              Row().width('100%').height(this.currentIndex === index ? 3 : 2)
                .backgroundColor(this.currentIndex === index ? R.cinnabar :
                  roamProgress(this.records, this.chapter()).completedIds.includes(clue.id) ? R.gold : '#BDB79C')
            }.layoutWeight(1).height(24).justifyContent(FlexAlign.Center)
              .enabled(index <= roamProgress(this.records, this.chapter()).completedCount && !this.saving && !this.noteBusy)
              .id(`roam-step-${clue.id}`).onClick(() => this.selectTrail(index))
          }, (clue: RoamClue) => `${this.chapter().id}:${clue.id}:${this.currentIndex}`)
        }.width('100%')
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, top: 12, bottom: 14 })
        .linearGradient({ angle: 180, colors: [['#F2F5F0E4', 0], ['#C8F5F0E4', 0.72], ['#00F5F0E4', 1]] })

      // 底部压边：一句判读、可选的签、以及关系成立后才出现的那一下确认。
      // 用一层满高 Column 推到最底部；Stack 默认 TopStart，直接放会盖住画面顶部。
      Column() {
        Blank()
      Column({ space: 8 }) {
        Text(this.feedback()).fontSize(13).lineHeight(20).width('100%')
          .fontColor(this.interactionReady() ? R.inkSoft : R.muted).id('roam-feedback')
        if (this.interactionReady()) { this.immersiveSeals() }
        if (this.kfMode() && this.currentIndex === 2 && this.interactionReady()) {
          Button('请 AI 校这一页', { type: ButtonType.Normal }).height(34).fontSize(13).padding({ left: 12, right: 12 })
            .fontColor(R.cinnabar).backgroundColor('rgba(250,246,236,0.9)')
            .border({ width: 1, color: '#D5CBA9', radius: 17 }).borderRadius(17)
            .id('kf-ai-colophon').onClick(() => this.openAi('colophon'))
        }
        if (this.kfDemoUsed && this.currentIndex === 0 && this.kfCrossing().solved) {
          Text('这一次是提示演示的摆放，不算你独立解出。').fontSize(12).fontColor(R.muted).width('100%')
            .id('kf-demo-note')
        }
        Row({ space: 16 }) {
          Button('读这段故事', { type: ButtonType.Normal }).height(32).fontSize(13).padding(0)
            .fontColor(R.river).backgroundColor(Color.Transparent).id('roam-read-story')
            .onClick(() => this.openReading())
          Button('留一页记忆', { type: ButtonType.Normal }).height(32).fontSize(13).padding(0)
            .fontColor(R.cinnabar).backgroundColor(Color.Transparent).id('roam-write-memory')
            .onClick(() => this.openWriting())
          // 桥型从画布移到这里：叠在画上会挡住桥、并与拖桥抢手势。
          // 只在这一城的幕一出现，避免换成别的城仍留一个无效开关。
          if (this.kfMode() && this.currentIndex === 0) {
            Blank()
            Button(this.kfKind === KAIFENG_BRIDGE_FLAT ? '桥型 · 平桥' : '桥型 · 拱桥',
              { type: ButtonType.Normal }).height(32).fontSize(12).padding({ left: 10, right: 10 })
              .fontColor(this.kfKind === KAIFENG_BRIDGE_FLAT ? R.river : R.cinnabar)
              .backgroundColor('rgba(251,243,224,0.94)')
              .border({ width: 1, color: '#CBBB96', radius: 16 }).borderRadius(16)
              .enabled(!this.saving)
              .id('kaifeng-bridge-kind')
              .accessibilityText('切换平桥或拱桥')
              .onClick(() => this.kfSetKind(this.kfKind === KAIFENG_BRIDGE_FLAT ?
                KAIFENG_BRIDGE_ARCH : KAIFENG_BRIDGE_FLAT))
          }
        }.width('100%').justifyContent(FlexAlign.Start)
        if (this.canConfirm()) {
          Button(this.kfButtonWord(), { type: ButtonType.Normal }).width('100%').height(50).fontSize(16)
            .fontWeight(FontWeight.Medium).fontColor('#FDF8EA').backgroundColor(R.river).borderRadius(4)
            .id('roam-complete').onClick(() => this.confirm())
        }
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, top: 12, bottom: 14 })
        .backgroundColor('rgba(247,242,230,0.94)')
        .border({ width: { top: 1 }, color: '#DBD2B8' })
      }.width('100%').height('100%').justifyContent(FlexAlign.End).hitTestBehavior(HitTestMode.Transparent)
      if (this.aiOpen) { this.aiSheet() }
    }.width('100%').height('100%').id('roam-immersive-stage')
  }

  // 关系成立后，才需要决定“这一段想留下什么”。两枚签直接压在画面上，不另起列表。
  @Builder
  immersiveSeals() {
    Row({ space: 8 }) {
      ForEach(this.clue().options, (option: RoamOption) => {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 6 }) {
            Text(this.selectedId === option.id ? '◉' : '○').fontSize(12)
              .fontColor(this.selectedId === option.id ? R.cinnabar : '#A9A48C')
            Text(option.label).fontSize(12).fontColor(this.selectedId === option.id ? R.ink : R.inkSoft)
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          }.width('100%')
        }.layoutWeight(1).height(44).padding({ left: 10, right: 10 })
          .backgroundColor(this.selectedId === option.id ? '#FBF3E0' : 'rgba(250,246,236,0.86)')
          .border({ width: 1, color: this.selectedId === option.id ? R.cinnabar : '#D5CBA9', radius: 3 })
          .borderRadius(3)
          .id(`roam-choice-${option.id}`).onClick(() => this.choose(option.id))
      }, (option: RoamOption) => `${this.clue().id}:${option.id}:${this.selectedId}`)
    }.width('100%')
  }

  private aiFactText(id: string): string {
    const fact: KaifengAiFact | undefined = kaifengAiFactFor(id);
    return fact ? `${fact.title}：${fact.quote}` : id;
  }

  // AI 半模态：压在整屏关卡之上，不跳页。答题与题跋都在这里完成，
  // 失败时保留手写入口；关闭按钮在等待模型时禁用，避免请求悬空。
  @Builder
  aiSheet() {
    Column() {
      Blank().layoutWeight(1).onClick(() => this.closeAi())
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          Text(this.aiMode === 'ask' ? '问这一夜' : '请 AI 校这一页')
            .fontSize(17).fontWeight(FontWeight.Medium).fontColor(R.ink).layoutWeight(1)
          Button('关闭', { type: ButtonType.Normal }).height(30).fontSize(12).padding({ left: 10, right: 10 })
            .fontColor(R.muted).backgroundColor('rgba(250,246,236,0.9)')
            .border({ width: 1, color: '#CFC5A6', radius: 15 }).borderRadius(15)
            .enabled(!this.aiBusy).id('kf-ai-close').onClick(() => this.closeAi())
        }.width('100%')
        Text(this.aiMode === 'ask' ? '只回答州桥、层位、石壁、夜市与灯事；每条回答带出处。' :
          'AI 会读你的城，写 2–4 句题跋，并指出与原文冲突的说法。')
          .fontSize(12).fontColor(R.muted).lineHeight(18).width('100%')
        if (this.aiMode === 'ask') {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(KAIFENG_AI_STARTERS, (item: KaifengAiStarter) => {
              Button(item.label, { type: ButtonType.Normal }).height(32).fontSize(12)
                .fontColor(R.river).backgroundColor('#F3EEDC')
                .border({ width: 1, color: '#D5CBA9', radius: 16 }).borderRadius(16)
                .margin({ right: 6, bottom: 6 }).id(`kf-ai-starter-${item.id}`)
                .onClick(() => { this.aiQuestion = item.question; })
            }, (item: KaifengAiStarter) => item.id)
          }.width('100%')
          TextArea({ text: this.aiQuestion, placeholder: '例如：州桥为什么低平，船从哪里过？' })
            .height(72).width('100%').fontSize(13).backgroundColor('#F7F2E3').borderRadius(8)
            .onChange((value: string) => { this.aiQuestion = value; })
            .id('kf-ai-question')
          Button(this.aiBusy ? '正在查依据' : '提问', { type: ButtonType.Normal }).width('100%').height(42)
            .fontSize(14).fontColor('#FDF8EA').backgroundColor(R.river).borderRadius(4)
            .enabled(!this.aiBusy && this.aiQuestion.trim().length > 0).id('kf-ai-send')
            .onClick(() => { this.askAi(); })
          if (this.aiAnswer.length > 0) {
            Text(this.aiAnswer).fontSize(13).lineHeight(21).fontColor(R.ink).width('100%')
              .id('kf-ai-answer')
          }
          if (this.aiCites.length > 0) {
            Row({ space: 8 }) {
              Text(`依据 · ${kaifengAiAnchorLabel(this.aiAnchor)}`).fontSize(11).fontColor(R.muted).layoutWeight(1)
              Text(this.aiShowQuotes ? '收起原文' : '看原文').fontSize(11).fontColor(R.cinnabar)
                .onClick(() => { this.aiShowQuotes = !this.aiShowQuotes; })
            }.width('100%')
            if (this.aiShowQuotes) {
              Column({ space: 4 }) {
                ForEach(this.aiCites, (id: string) => {
                  Text(this.aiFactText(id)).fontSize(11).lineHeight(17).fontColor(R.inkSoft).width('100%')
                }, (id: string) => id)
              }.width('100%')
            }
          }
        } else {
          Button(this.aiBusy ? '正在校这一页' : '开始校这一页', { type: ButtonType.Normal })
            .width('100%').height(42).fontSize(14).fontColor('#FDF8EA').backgroundColor(R.river).borderRadius(4)
            .enabled(!this.aiBusy).id('kf-ai-colophon-run').onClick(() => { this.writeColophon(); })
          if (this.aiSentences.length > 0) {
            Column({ space: 4 }) {
              ForEach(this.aiSentences, (sentence: KaifengAiSentence) => {
                Text(sentence.text).fontSize(14).lineHeight(24).fontColor(R.ink).width('100%')
              }, (sentence: KaifengAiSentence, index: number) => `${index}:${sentence.fact}`)
            }.width('100%')
            if (this.aiDropped > 0) {
              Text(`有一句没有出处，已略去（${this.aiDropped} 句）。`).fontSize(11).fontColor(R.muted)
                .width('100%').id('kf-ai-dropped')
            }
            if (this.aiConflicts.length > 0) {
              Column({ space: 4 }) {
                ForEach(this.aiConflicts, (conflict: KaifengAiConflict) => {
                  Text(`你写的「${conflict.quote}」与原文不合：${conflict.why}`)
                    .fontSize(11).lineHeight(17).fontColor(R.cinnabar).width('100%')
                }, (conflict: KaifengAiConflict, index: number) => `${index}:${conflict.fact}`)
              }.width('100%')
            }
            if (this.aiSuggestion.length > 0) {
              Text(this.aiSuggestion).fontSize(11).fontColor(R.muted).lineHeight(17).width('100%')
            }
            Button('放到草稿里', { type: ButtonType.Normal }).width('100%').height(40).fontSize(13)
              .fontColor(R.paperHigh).backgroundColor(R.river).borderRadius(4)
              .enabled(this.noteBusy === false).id('kf-ai-adopt').onClick(() => { this.adoptColophon(); })
          }
        }
        if (this.aiError.length > 0) {
          Text(this.aiError).fontSize(12).lineHeight(18).fontColor(R.cinnabar).width('100%')
            .id('kf-ai-error')
        }
      }.width('100%').padding(18).backgroundColor(R.page)
        .border({ width: { top: 1 }, color: '#D5CBA9' }).borderRadius(14)
    }.width('100%').height('100%').backgroundColor('rgba(40,36,26,0.38)')
  }

  // 操作区收成一张纸：刻尺、选项、点灯与观察记在同一张纸上，只用细分隔线分层，
  // 不再各自套一个色块，避免一屏出现四种“卡片”。
  @Builder
  controlPanel() {
    Column({ space: 0 }) {
      if (this.currentIndex < 2 && !(this.currentIndex === 0 && this.chapter().scene === 'smx-home')) {
        Column({ space: 6 }) {
          Row({ space: 8 }) {
            Text(this.sliderTitle()).fontSize(14).fontColor(R.ink).layoutWeight(1)
            Text(this.positionWord()).fontSize(13).letterSpacing(1)
              .fontColor(this.interactionReady() ? R.cinnabar : R.faint)
          }.width('100%')
          Slider({ value: this.amount, min: 0, max: 100, step: 1, style: SliderStyle.OutSet })
            .width('100%').height(36).blockColor(this.interactionReady() ? R.cinnabar : R.cinnabarDeep)
            .selectedColor(R.river).trackColor('#D8CFB4').blockSize({ width: 12, height: 12 })
            .trackThickness(2).showTips(false)
            .id('roam-slider').onChange((value: number) => this.move(value))
        }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 10 })
        Divider().color(R.lineSoft)
      }
      if (this.currentIndex === 1 && this.quote()) {
        Column({ space: 8 }) {
          Text(this.revealedQuote()).fontSize(22).fontColor(R.ink).letterSpacing(2).lineHeight(34).width('100%')
            .id('roam-revealed-quote')
          Row({ space: 8 }) {
            Row().width(16).height(1).backgroundColor('#C9B78F')
            Text(this.chapter().scene === 'ly-spring' ? '欧阳修《洛阳牡丹记》· 北宋' : '《诗经·郑风·溱洧》')
              .fontSize(12).fontColor(R.muted)
          }.width('100%').alignItems(VerticalAlign.Center)
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, top: 14, bottom: 14 })
        Divider().color(R.lineSoft)
      }
      this.clueOptions()
      // 观察记：只保留系统反馈本身，左侧一条朱砂线承担“这是对你所选片段的解释”
      Row() {
        Text(this.feedback()).fontSize(13).lineHeight(21).layoutWeight(1)
          .fontColor(this.interactionReady() ? R.inkSoft : R.muted)
          .id('roam-feedback')
      }.width('100%').alignItems(VerticalAlign.Center)
        .padding({ left: 13, right: 16, top: 11, bottom: 11 })
        .border({ width: { left: 2 }, color: this.interactionReady() ? R.cinnabar : '#D9D2B8' })
        .backgroundColor(this.interactionReady() ? '#F8F0DD' : Color.Transparent)
    }.width('100%').alignItems(HorizontalAlign.Start)
      .backgroundColor(R.page).border({ width: 1, color: '#E1D8BF', radius: R.radiusPage })
      .borderRadius(R.radiusPage).clip(true)
  }

  @Builder
  goalPanel() {
    Column({ space: 14 }) {
      this.controlPanel()
      Button(this.kfMode() ? this.kfButtonWord() : this.saving ? '正在保存进度' :
        this.completed() ? this.currentIndex < 2 ? '继续下一条线索' : '这一城，已展开' :
        this.currentIndex < 2 ? '确认发现，继续展开' : '收好这一城的故事', { type: ButtonType.Normal })
        .width('100%').height(52).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#FDF8EA')
        .backgroundColor(this.canConfirm() ? R.river : '#AFB9A6').borderRadius(3)
        .enabled(this.canConfirm())
        .id('roam-complete').onClick(() => this.confirm())
      Row({ space: 0 }) {
        Button('读这段故事', { type: ButtonType.Normal }).layoutWeight(1).height(40).fontSize(14)
          .fontColor(R.river).backgroundColor(Color.Transparent).padding(0).id('roam-read-story')
          .onClick(() => this.openReading())
        Divider().vertical(true).height(14).color(R.line)
        Button('留一页记忆', { type: ButtonType.Normal }).layoutWeight(1).height(40).fontSize(14)
          .fontColor(R.cinnabar).backgroundColor(Color.Transparent).padding(0).id('roam-write-memory')
          .onClick(() => this.openWriting())
      }.width('100%')
      if (roamProgress(this.records, this.chapter()).completed && this.currentIndex === 2) {
        Column({ space: 9 }) {
          Text('这一城，留在你的阅读里').fontSize(16).fontWeight(FontWeight.Medium).fontColor(R.ink).width('100%')
          Text(this.chapter().closing).fontSize(14).lineHeight(25).fontColor(R.muted).width('100%')
          Text('探索进度已记录 · 个人感想由你确认保存').fontSize(12).fontColor(R.faint).width('100%')
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, top: 14, bottom: 14 })
          .backgroundColor('#F4EDD9').border({ width: { top: 2 }, color: R.gold }).borderRadius(0)
          .id('roam-chapter-closing')
      }
      if (this.message) { Text(this.message).fontSize(13).fontColor(R.cinnabar).lineHeight(22).width('100%').id('roam-message') }
      Row({ space: 8 }) {
        Row().width(18).height(1).backgroundColor(R.line)
        Button(this.accountSignedIn ? '同账号，继续我的漫游' : '登录，在另一端继续', { type: ButtonType.Normal })
          .height(36).fontSize(13).fontColor(R.river).backgroundColor(Color.Transparent).padding(0)
          .enabled(!this.noteBody.trim() || this.saved).id('roam-account-continue').onClick(() => this.onLogin())
      }.width('100%').justifyContent(FlexAlign.Center)
      if (this.noteBody.trim() && !this.saved) {
        Text('先确认保存这一页，再到另一端继续。').fontSize(12).fontColor(R.muted).width('100%').textAlign(TextAlign.Center)
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, top: 14, bottom: 22 })
  }


  @Builder
  sourcesPanel() {
    Column({ space: 10 }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 8 }) {
          Text('资料出处').fontSize(12).fontColor(R.river).layoutWeight(1)
          Text(this.sourcesOpen ? '收起 −' : '展开 ＋').fontSize(12).fontColor(R.muted)
        }.width('100%')
      }.width('100%').height(36).padding(0).backgroundColor(Color.Transparent).id('roam-sources')
        .onClick(() => { this.sourcesOpen = !this.sourcesOpen; })
      if (this.sourcesOpen) {
        ForEach(this.sources(), (source: RoamSource) => {
          Column({ space: 7 }) {
            Text(source.title).fontSize(12).fontWeight(FontWeight.Medium).fontColor(R.ink).lineHeight(21).width('100%')
            Text(source.url).fontSize(12).fontColor(R.muted).lineHeight(17).width('100%').copyOption(CopyOptions.LocalDevice)
            Hyperlink(source.url, '打开来源网页 ↗').color(R.river)
            Text(`访问日期 ${source.accessedAt}`).fontSize(12).fontColor(R.faint).width('100%')
          }.width('100%').alignItems(HorizontalAlign.Start).padding(12).backgroundColor('#F0EDDE').borderRadius(8)
        }, (source: RoamSource) => source.id)
        Text(`${ROAM_REVIEW_STATUS} · 原创图景用于阅读关系，不作为测绘或历史复原。`)
          .fontSize(12).fontColor(R.cinnabar).lineHeight(19).width('100%').id('roam-review-status')
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  selectionMenu() {
    Button('做成摘录笺', { type: ButtonType.Normal }).fontSize(13).height(43).padding({ left: 17, right: 17 })
      .fontColor(R.page).backgroundColor(R.river).borderRadius(10)
      .enabled(this.selectedText.trim().length > 0 && this.selectedId.length > 0)
      .onClick(() => this.createExcerpt())
  }

  @Builder
  excerptDragPreview() {
    Column({ space: 7 }) {
      Text('云河纪 · 摘录笺').fontSize(12).fontColor(R.cinnabar).width('100%')
      Text(this.cardContext?.excerpt || '').fontSize(13).fontColor(R.ink).lineHeight(23).maxLines(4).width('100%')
    }.width(260).alignItems(HorizontalAlign.Start).padding(17).backgroundColor(R.page).borderRadius(10)
      .border({ width: 1, color: R.line, radius: 10 })
  }

  @Builder
  excerptCard() {
    if (this.cardContext) {
      Column({ space: 11 }) {
        Row({ space: 8 }) {
          Text('摘录笺').fontSize(12).fontColor(R.cinnabar).letterSpacing(2).layoutWeight(1)
          Text('⠿').fontSize(19).fontColor(R.muted)
        }.width('100%')
        Text(this.cardContext.excerpt).fontSize(13).fontColor(R.ink).lineHeight(23).width('100%')
        Text(this.cardContext.title).fontSize(12).fontColor(R.faint).lineHeight(18).width('100%')
        Button('加入记忆草稿 ＋', { type: ButtonType.Normal }).height(36).width('100%').fontSize(12)
          .fontColor(R.river).backgroundColor('#E0E6D2').borderRadius(7).id('roam-add-excerpt')
          .onClick(() => { if (this.cardContext) this.addExcerpt(this.cardContext); })
        Text(this.wide() ? '也可长按卡片，拖入记忆草稿' : '先生成摘录笺，再加入草稿').fontSize(12).fontColor(R.faint)
      }.width('100%').alignItems(HorizontalAlign.Start).padding(15).backgroundColor('#F0E5CB').borderRadius(10)
        .border({ width: 1, color: '#D9CAAA', radius: 10 }).draggable(true).id('roam-excerpt-card')
        .onDragStart((event: DragEvent): DragItemInfo => this.startDrag(event))
    }
  }

  @Builder
  photoEvidence() {
    if (this.photoSite()) {
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Text('对照一张真实照片').fontSize(12).fontColor(R.river).layoutWeight(1)
          Text('已授权随包').fontSize(12).fontColor(R.faint)
        }.width('100%')
        Image($rawfile(this.photoSite()?.photos[0] || '')).width('100%').height(205).objectFit(ImageFit.Contain)
          .backgroundColor('#DEDCCB').borderRadius(8).accessibilityText(this.photoSite()?.photoCaption || '对应档案的资料照片')
          .id('roam-evidence-photo')
        Text(this.photoSite()?.photoCaption || '').fontSize(12).fontColor(R.ink).lineHeight(20).width('100%')
        Text(this.photoSite()?.photoCredit || '').fontSize(12).fontColor(R.faint).lineHeight(17).width('100%')
        Text('照片用于对照资料；场景中的位置、比例与线条仍是原创叙事示意。')
          .fontSize(12).fontColor(R.faint).lineHeight(17).width('100%')
      }.width('100%').alignItems(HorizontalAlign.Start).padding(12).backgroundColor('#ECEADB').borderRadius(10)
        .id('roam-photo-evidence')
    }
  }

  @Builder
  readingContent() {
    Column({ space: 16 }) {
      Row({ space: 10 }) {
        Text('读城小笺').fontSize(12).fontColor(R.cinnabar).letterSpacing(2).layoutWeight(1)
        Text(ROAM_REVIEW_STATUS).fontSize(12).fontColor(R.faint)
      }.width('100%')
      Text(this.clue().title).fontSize(22).fontWeight(FontWeight.Medium).fontColor(R.ink).lineHeight(31).width('100%')
      if (this.currentIndex === 0) {
        Text(this.chapter().opening).fontSize(12).fontColor(R.muted).lineHeight(23).width('100%')
      }
      Text(this.clue().era).fontSize(13).fontColor(R.muted).lineHeight(22).width('100%')
      this.photoEvidence()
      // API 26 SelectionContainer 聚合多个 Text 节点，支持跨段选摘。
      // 后续排版可拆分段落，但不要退回把整篇塞进一个不可连续选摘的普通 Text。
      SelectionContainer({ controller: this.selectionController }) {
        Column({ space: 14 }) {
          ForEach(this.clue().body.split('\n').filter((text: string) => text.trim().length > 0), (text: string, index: number) => {
            Text(text).fontSize(15).fontColor(R.ink).lineHeight(29).width('100%').id(`roam-reading-paragraph-${index}`)
          }, (text: string, index: number) => `${this.clue().id}:${index}:${text}`)
          if (this.chosen()) {
            Text(this.chosen()?.detail || '').fontSize(13).fontColor(R.muted).lineHeight(25).width('100%')
          }
        }.width('100%').alignItems(HorizontalAlign.Start)
      }.width('100%').copyOption(CopyOptions.InApp).textJoinStyle(SelectionContainerTextJoinStyle.NEWLINE)
        .caretColor(R.river).selectedBackgroundColor('#B5CAB0')
        .onTextSelectionChange((paragraphs: string[]) => { this.selectedText = paragraphs.filter((text: string) => text.length > 0).join('\n'); })
        // 保留系统“全选/复制”，再扩展摘录动作。完全替换菜单会藏掉跨段全选入口，
        // 平板只靠拖动窄小选区柄很难连续摘录；这里让系统维护真实选择范围。
        .editMenuOptions({
          onCreateMenu: (items: TextMenuItem[]): TextMenuItem[] => {
            const result = items.filter((item: TextMenuItem) => item.id.equals(TextMenuItemId.COPY) ||
              item.id.equals(TextMenuItemId.SELECT_ALL));
            if (this.selectedId) result.push({ content: '做成摘录笺', id: TextMenuItemId.of('roaming-excerpt') });
            return result;
          },
          onMenuItemClick: (item: TextMenuItem, text: string): boolean => {
            if (!item.id.equals(TextMenuItemId.of('roaming-excerpt'))) return false;
            this.selectedText = text; this.createExcerpt(); return true;
          }
        }).id('roam-reading-body')
      Text(this.selectedId ? '长按文字，可跨段选摘并保留出处。' : '先在场景中选一个片段，再为它做摘录笺。')
        .fontSize(12).fontColor(R.faint).lineHeight(18).width('100%')
      Button('将选中文字做成摘录笺', { type: ButtonType.Normal }).height(42).width('100%').fontSize(12)
        .fontColor(R.river).backgroundColor('#E1E7D4').borderRadius(8)
        .enabled(this.selectedText.trim().length > 0 && this.selectedId.length > 0).id('roam-create-excerpt')
        .onClick(() => this.createExcerpt())
      this.excerptCard()
      this.sourcesPanel()
      Divider().color(R.line)
      Text('沿着资料，再走一步').fontSize(13).fontWeight(FontWeight.Medium).fontColor(R.ink).width('100%')
      ForEach(this.chapter().relatedSiteIds, (id: string) => {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 8 }) {
            Text(HERITAGE_SITES.find((site: HeritageSite) => site.id === id)?.name || '延伸文化档案')
              .fontSize(12).fontColor(R.river).layoutWeight(1)
            Text('↗').fontSize(15).fontColor(R.faint)
          }.width('100%')
        }.height(36).width('100%').padding(0).backgroundColor(Color.Transparent).id(`roam-related-${id}`)
          .onClick(() => { this.sheetOpen = false; this.onOpenSite(id); })
      }, (id: string) => id)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  writingContent() {
    Column({ space: 0 }) {
      Row({ space: 8 }) {
        Text('记忆笺').fontSize(16).fontWeight(FontWeight.Medium).fontColor(R.ink).letterSpacing(1).layoutWeight(1)
        Text('亲笔').fontSize(12).fontColor(R.cinnabar).letterSpacing(1).padding({ left: 5, right: 5, top: 2, bottom: 2 })
          .border({ width: 1, color: '#DDBDA6', radius: 2 }).borderRadius(2)
      }.width('100%')
      Text(`${this.chapter().city} · ${this.clue().title}`).fontSize(12).fontColor(R.faint)
        .width('100%').margin({ top: 4 }).letterSpacing(0.5)
      Row().width('100%').height(1).backgroundColor('#DED2B4').margin({ top: 10, bottom: 12 })

      // 稿纸边线用左边框表示，不覆盖正文；输入框保持原生，中文输入法与键盘避让不受影响。
      TextArea({ text: this.noteBody, placeholder: '这次发现，让你想到什么？' }).height(150).width('100%')
        .fontSize(14).fontColor(R.ink).placeholderColor('#9AA089').backgroundColor('#FDF9EC')
        .border({ width: { left: 2, top: 1, right: 1, bottom: 1 }, color: { left: '#E0BEA6', top: '#E7DFC8',
          right: '#E7DFC8', bottom: '#E7DFC8' } })
        .borderRadius(2).padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .maxLength(4000).enabled(!this.noteBusy && !this.saving).id('roam-note-body')
        .onChange((text: string) => {
          if (!this.draftContext && this.selectedId) { this.draftContext = this.context(); this.customExcerpt = false; }
          this.noteBody = text; this.saved = false;
        })

      Column({ space: 7 }) {
        Row({ space: 7 }) {
          Row().width(3).height(3).backgroundColor(this.visibleDraftContext() ? R.cinnabar : '#C9C1A6')
          Text(this.visibleDraftContext() ? this.customExcerpt ? '本页摘录 · 出处随页保存' : '随页保存的资料依据' : '有出处的摘录，可以放在这里')
            .fontSize(12).fontColor(R.muted).layoutWeight(1).letterSpacing(0.5)
        }.width('100%')
        if (this.visibleDraftContext()) {
          Text(this.visibleDraftContext()?.excerpt || '').fontSize(12).fontColor(R.inkSoft).lineHeight(22)
            .width('100%').id('roam-draft-excerpt')
          Text(this.visibleDraftContext()?.title || '').fontSize(12).fontColor(R.faint).lineHeight(17).width('100%')
          if (this.customExcerpt) {
            Button('恢复完整资料依据', { type: ButtonType.Normal }).fontSize(12).fontColor(R.cinnabar).height(26)
              .backgroundColor(Color.Transparent).padding(0).onClick(() => {
                const original = this.draftContext;
                if (original) {
                  const clue = this.chapter().clues.find((item: RoamClue) => item.id === original.clueId);
                  if (clue) this.draftContext = makeRoamingMemoryContext(this.chapter(), clue, original.choiceId, ROAM_SOURCES, ROAM_CONTENT_REVISION);
                }
                this.customExcerpt = false; this.saved = false;
              })
          }
        } else {
          Text(this.wide() ? '将上方摘录笺长按拖入，或点卡片上的“加入草稿”。' : '去读城小笺选中文字，生成摘录后加入草稿。')
            .fontSize(12).fontColor(R.faint).lineHeight(19).width('100%')
        }
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .backgroundColor(this.dropHover ? '#E3EAD4' : '#F2ECD9')
        .border({ width: 1, color: this.dropHover ? R.river : '#DFD5B8', radius: 2, style: BorderStyle.Dashed })
        .borderRadius(2).margin({ top: 12 })
        .allowDrop(['general.plain-text']).id('roam-draft-drop')
        .onDragEnter(() => { this.dropHover = true; }).onDragLeave(() => { this.dropHover = false; })
        .onDrop((event: DragEvent) => this.dropExcerpt(event))

      TextInput({ text: this.noteTags, placeholder: '标签，用逗号分开（选填）' }).height(40).fontSize(12).fontColor(R.ink)
        .placeholderColor('#949B84').backgroundColor('#FDF9EC')
        .border({ width: 1, color: '#E7DFC8' }).borderRadius(2).maxLength(819).margin({ top: 10 })
        .enabled(!this.noteBusy && !this.saving).id('roam-note-tags')
        .onChange((text: string) => { this.noteTags = text; this.saved = false; })

      Text('保存的是这次选中的文化片段和你的文字；探索完成不表示真实到访。')
        .fontSize(12).fontColor(R.faint).lineHeight(17).width('100%').margin({ top: 10 })

      Button(this.noteBusy || this.saving ? '正在保存' : this.saved ? '这一页已保存' : '确认，存入我的记忆', { type: ButtonType.Normal })
        .width('100%').height(47).fontSize(13)
        .fontColor(this.saved ? '#F5EFDC' : '#FDF6E6')
        .backgroundColor(this.saved ? R.river : R.cinnabar)
        .borderRadius(3).margin({ top: 12 })
        .enabled(!this.noteBusy && !this.saving && !this.saved).id('roam-save-note').onClick(() => this.saveNote())

      if (this.saved) {
        Row({ space: 11 }) {
          Column() {
            Text('存').fontSize(12).fontColor('#FBF3E0')
          }.width(26).height(30).justifyContent(FlexAlign.Center).backgroundColor(R.cinnabar)
            .borderRadius(2).rotate({ angle: -6 })
          Column({ space: 3 }) {
            Text('这一页已在本机保存').fontSize(12).fontColor(R.ink).width('100%')
            Text('正文、摘录与出处一起存入记忆').fontSize(12).fontColor(R.muted).width('100%')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%').alignItems(VerticalAlign.Center).margin({ top: 12 })
        Button('读我刚留下的记忆 →', { type: ButtonType.Normal }).height(42).width('100%').fontSize(12)
          .fontColor(R.river).backgroundColor('#F1EBD8')
          .border({ width: 1, color: '#DED4B8' }).borderRadius(3).margin({ top: 10 })
          .id('roam-open-memory')
          .onClick(() => { this.sheetOpen = false; this.onOpenMemory(); })
      }
      if (this.message) { Text(this.message).fontSize(12).fontColor(R.cinnabar).lineHeight(21).width('100%').margin({ top: 8 }).id('roam-note-message') }
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 18, right: 18, top: 16, bottom: 18 })
      .backgroundColor('#FBF5E7')
      .border({ width: 1, color: '#E2D8BC' }).borderRadius(R.radiusPage)
      .id('roam-memory-draft')
  }

  @Builder
  sceneContent() {
    Column({ space: 0 }) {
      this.chapterHeader()
      // 图景上缘留 12vp，让横向河卷与页头之间有一道呼吸，
      // 同时不切掉画面顶部远景（城楼、远山都在这条带里）。
      Column().width('100%').height(12)
      this.sceneStage()
      this.goalPanel()
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  mobileSheet() {
    Column({ space: 0 }) {
      Row({ space: 8 }) {
        Button('读城小笺', { type: ButtonType.Normal }).height(36).layoutWeight(1).fontSize(12)
          .fontColor(this.sheetMode === 'reading' ? R.page : R.muted)
          .backgroundColor(this.sheetMode === 'reading' ? R.river : Color.Transparent).borderRadius(18)
          .id('roam-sheet-reading').onClick(() => { this.sheetMode = 'reading'; })
        Button('我的记忆笺', { type: ButtonType.Normal }).height(36).layoutWeight(1).fontSize(12)
          .fontColor(this.sheetMode === 'writing' ? R.page : R.muted)
          .backgroundColor(this.sheetMode === 'writing' ? R.river : Color.Transparent).borderRadius(18)
          .id('roam-sheet-writing').onClick(() => { this.sheetMode = 'writing'; })
        Button('×', { type: ButtonType.Normal }).width(34).height(34).fontSize(22).fontColor(R.muted)
          .backgroundColor('#E9E7D8').borderRadius(18).id('roam-sheet-close').onClick(() => { this.sheetOpen = false; })
      }.width('100%').padding({ left: 18, right: 18, top: 15, bottom: 13 })
      Scroll() {
        Column() {
          if (this.sheetMode === 'reading') { this.readingContent() } else { this.writingContent() }
        }.width('100%').padding({ left: 20, right: 20, top: 3, bottom: 30 })
      }.width('100%').layoutWeight(1).scrollBar(BarState.Off).align(Alignment.Top).id('roam-sheet-scroll')
    }.width('100%').height('100%').backgroundColor(R.paper)
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.kfMode()) {
          this.immersiveStage()
        } else {
        Column() {
        if (this.wide()) {
          Row({ space: 0 }) {
            Scroll(this.sceneScroller) { this.sceneContent() }
              .layoutWeight(this.threeColumns() ? 1.25 : 1.45).height('100%').align(Alignment.Top).scrollBar(BarState.Off).id('roam-chapter-wide-scroll')
            Divider().vertical(true).width(1).height('100%').color(R.line)
            Scroll() {
              Column({ space: 25 }) {
                this.readingContent()
                if (!this.threeColumns()) { this.writingContent() }
              }.width('100%').alignItems(HorizontalAlign.Start)
                .padding({ left: this.threeColumns() ? 18 : 25, right: this.threeColumns() ? 18 : 25, top: 24, bottom: 40 })
            }.layoutWeight(1).height('100%').align(Alignment.Top).scrollBar(BarState.Off).backgroundColor('#F8F4E7')
              .id('roam-reading-column')
            if (this.threeColumns()) {
              Divider().vertical(true).width(1).height('100%').color(R.line)
              Scroll() {
                Column() { this.writingContent() }.width('100%').padding({ left: 14, right: 14, top: 22, bottom: 40 })
              }.layoutWeight(1).height('100%').align(Alignment.Top).scrollBar(BarState.Off).backgroundColor('#F0EBDD')
                .id('roam-writing-column')
            }
          }.width('100%').height('100%').alignItems(VerticalAlign.Top)
        } else {
          Scroll(this.sceneScroller) { this.sceneContent() }
            .width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Off).id('roam-chapter-scroll')
        }
        }.width('100%').height('100%')
        }
      }.width('100%').height('100%')
        .onAreaChange((_old: Area, area: Area) => {
          const wasWide = this.wide(); this.contentWidth = Number(area.width);
          // 变宽后同一份草稿转到侧栏，关闭仍在的手机半模态；状态和已选片段都保留。
          if (!wasWide && this.wide()) this.sheetOpen = false;
        })
    }.title(`${this.chapter().city} · 漫游`, { systemMaterial: HarmonyEffects.material(true, this.reducedMotion) })
      .backgroundColor(R.paper).id('roaming-chapter-page')
      .bindSheet($$this.sheetOpen, this.mobileSheet(), { height: SheetSize.LARGE, showClose: false, dragBar: true,
        keyboardAvoidMode: SheetKeyboardAvoidMode.RESIZE_ONLY })
      .onBackPressed(() => {
        if (this.noteBusy) return true;
        if (this.sheetOpen) { this.sheetOpen = false; return true; }
        // 分栏中最后一层目的页交给同一份 NavPathStack 显式返回。
        // 不让系统在 Split→Stack 切换期间把返回解释成退出 Ability；半模态仍先关闭。
        this.onBack(); return true;
      })
  }
}
