import type { ArchiveRecord } from '../domain/ArchiveDomain';
import { RiverMarketV2, MarketNightId, MarketRouteId, MarketNightAction, MarketNightResource,
  MarketNightStall, MarketNightStallConfig, MarketNightRoundSummary, MarketNightBatchSummary,
  MarketNightBatchReport, MarketNightReason, MarketNightRoute, MarketNightLot, MarketNightLayout,
  NIGHT_CONFIGS, NIGHT_STALL_CONFIGS, NIGHT_LOTS, NIGHT_ROUTES, NIGHT_LOSS_REASONS,
  NIGHT_SUPPLIES, NIGHT_SUPPLY_COSTS, createMarketNight, copyMarketNight, applyMarketNightAction,
  beginMarketNightRound, advanceMarketNightBatch, endMarketNightRound, marketNightForecast,
  marketNightSummary, marketNightLayout, marketNightSupplyCost } from '../domain/RiverMarketV2';
import { marketNightFromRecords, marketNightIsDeleted, marketNightIsUnreadable, marketNightUnlocked,
  nextMarketNight } from '../domain/RiverMarketV2Records';
import { MARKET_ZONE_NAMES, marketReasonName } from '../data/RiverMarketCatalog';
import { marketCultureForNight, MARKET_CULTURE_BOUNDARY } from '../data/MarketCultureCatalog';
import { setPaperWindowText } from '../platform/PaperWindowStyle';
import { MarketNightScene } from './MarketNightScene';

const TN_NIGHT: string = '#102B31';
const TN_PANEL: string = '#203F40';
const TN_PAPER: string = '#F2E6C9';
const TN_GOLD: string = '#E1B779';
const TN_MUTED: string = '#A0B8A6';
type NightCommitKind = 'none' | 'initial' | 'action' | 'begin' | 'batch' | 'end' | 'restart';
interface NightSupplyRow { resource: MarketNightResource; name: string; }
interface NightLampMove { from: number; to: number; }

function nightTypeName(type: string): string { return NIGHT_STALL_CONFIGS.find(item => item.type === type)?.name || '空地'; }
function nightLossName(reason: string): string { return reason === 'festival' ? '未完成观灯' : marketReasonName(reason); }

@Component
export struct MarketNightPage {
  @Prop nightId: string = 'night-1';
  @Prop @Watch('receiveRecords') records: ArchiveRecord[] = [];
  @Prop saving: boolean = false;
  @Prop reducedMotion: boolean = false;
  onSaveState: (state: RiverMarketV2, restart: boolean) => Promise<boolean> = async () => false;
  onOpenContent: (id: string) => void = () => {};
  onComposeMemory: (state: RiverMarketV2) => void = () => {};
  onNextNight: (nightId: string) => void = () => {};
  onBack: () => void = () => {};
  @State private state: RiverMarketV2 = createMarketNight('night-1', 'balanced', 0);
  @State private selectedLot: number = 2;
  @State private widthVp: number = 360;
  @State private visible: boolean = true;
  @State private unreadable: boolean = false;
  @State private progressDeleted: boolean = false;
  @State private locked: boolean = false;
  @State private localSaving: boolean = false;
  @State private playing: boolean = false;
  @State private playbackKey: number = 0;
  @State private playbackReport: MarketNightBatchReport | undefined = undefined;
  @State private message: string = '先看看这一段的需求，再安排铺子和伙计。';
  @State private sheetOpen: boolean = false;
  @State private sheetMode: string = 'arrange';
  @State private savedAt: number = 0;
  @State private editRevision: number = 0;
  @State private confirmedRevision: number = 0;
  @State private incomingAvailable: boolean = false;
  @State private restartPending: boolean = false;
  private writeQueue: Promise<void> = Promise.resolve();
  private pendingWrites: number = 0;
  private pendingKind: NightCommitKind = 'none';
  private pendingReport: MarketNightBatchReport | undefined = undefined;
  private incomingState: RiverMarketV2 | undefined = undefined;
  private acknowledgedState: RiverMarketV2 | undefined = undefined;
  private loaded: boolean = false;
  private supplies: NightSupplyRow[] = [{ resource: 'rice', name: '米粮' }, { resource: 'meat', name: '肉料' },
    { resource: 'tea', name: '茶料' }, { resource: 'oil', name: '灯油' }];

  aboutToAppear(): void {
    this.loaded = true; this.unreadable = marketNightIsUnreadable(this.records, this.currentNightId());
    this.progressDeleted = marketNightIsDeleted(this.records, this.currentNightId());
    const saved = marketNightFromRecords(this.records, this.currentNightId());
    this.locked = !saved && !marketNightUnlocked(this.records, this.currentNightId());
    this.state = saved || createMarketNight(this.currentNightId(), 'balanced', Date.now(),
      !this.progressDeleted && !this.unreadable ? this.firstLayout() : undefined);
    this.savedAt = saved?.updatedAt || 0; this.acknowledgedState = saved ? copyMarketNight(saved) : undefined;
    if (this.unreadable) this.message = '原存档暂不可读，已保留正文并暂停写入。请先恢复备份。';
    else if (this.progressDeleted) this.message = '这一夜的进度已删除，个人记忆仍保留。明确重开才会另起新局。';
    else if (this.locked) this.message = '前一夜达成目标后，才能开启这一夜。';
    else if (saved) this.message = this.resumeMessage();
    else {
      // 新夜只在首次创建时继承前夜已保存布局。后续进入、重开或同步都不反写前夜。
      // 初始状态也先flush，用户看到的开段按钮只有在该版本确实存好后才可执行。
      this.editRevision++; this.persistCurrent('initial');
    }
  }
  aboutToDisappear(): void { this.visible = false; this.loaded = false; }
  private currentNightId(): MarketNightId { return this.nightId === 'night-2' ? 'night-2' : this.nightId === 'night-3' ? 'night-3' : 'night-1'; }
  private wide(): boolean { return this.widthVp >= 900; }
  private configTitle(): string { return NIGHT_CONFIGS.find(item => item.id === this.currentNightId())?.title || '开封三夜'; }
  private firstLayout(): MarketNightLayout | undefined {
    if (this.currentNightId() === 'night-1') return undefined;
    const previous = marketNightFromRecords(this.records, this.currentNightId() === 'night-2' ? 'night-1' : 'night-2');
    return previous ? marketNightLayout(previous) : undefined;
  }
  private selected(): MarketNightStall { return this.state.stalls[this.selectedLot] || this.state.stalls[2]; }
  private zone(): number { return Math.floor(this.selectedLot / 2); }
  private dirty(): boolean { return this.editRevision > this.confirmedRevision; }
  private idle(): boolean { return !this.unreadable && !this.progressDeleted && !this.locked && !this.localSaving && !this.saving && !this.playing && !this.dirty(); }
  private preparing(): boolean { return this.idle() && this.state.phase === 'prepare'; }
  private emergency(): boolean { return this.idle() && this.state.phase === 'emergency'; }
  private phaseWord(): string {
    if (this.unreadable) return '暂停写入';
    if (this.progressDeleted && !this.restartPending) return '进度已删除';
    if (this.locked) return '待开启';
    if (this.playing) return '客人进街';
    if (this.state.phase === 'prepare') return '备市';
    if (this.state.phase === 'running') return '等待首批';
    if (this.state.phase === 'emergency') return '应急暂停';
    return this.state.phase === 'settling' ? '等待收段' : '已收市';
  }
  private resumeMessage(): string {
    if (this.state.phase === 'closed') return marketNightSummary(this.state).detail;
    if (this.state.phase === 'emergency') return `第${this.state.batch}批已经保存；可以调度，也可以继续下一批。`;
    if (this.state.phase === 'settling') return '三批结果已经保存，工钱与铺租尚未结。确认收段后再作安排。';
    if (this.state.phase === 'running') return '本段已经开市，灯油已扣；继续迎第一批，不会再扣一次。';
    return this.state.round === 0 ? '铺子与伙计已到位。先安排，或直接迎第一批客人。' : '上一段账已结清，现在可改建、调人并补货。';
  }
  private saveStatus(): string {
    if (this.unreadable) return '原存档保留 · 暂停写入';
    if (this.localSaving) return '正在保存这一版';
    if (this.dirty()) return '这一版尚未保存 · 请重试';
    if (this.progressDeleted) return '已删除 · 仅明确重开可另起新局';
    return this.savedAt > 0 ? '已保存在本机' : '尚未存档';
  }
  private sameContent(a: RiverMarketV2, b: RiverMarketV2): boolean {
    const left = copyMarketNight(a); const right = copyMarketNight(b); left.updatedAt = 0; right.updatedAt = 0;
    return JSON.stringify(left) === JSON.stringify(right);
  }
  private receiveRecords(): void {
    if (!this.loaded) return;
    const deleted = marketNightIsDeleted(this.records, this.currentNightId());
    if (deleted && !this.restartPending) {
      // 外端墓碑立即停止旧局；普通保存与迟到回放不能将墓碑复活。
      this.progressDeleted = true; this.incomingState = undefined; this.incomingAvailable = false; this.playing = false;
      // 被删除的旧局已不能再提交，取消其待重试动作；序号同时前移，迟到保存回执也不能
      // 使新的明确重开误判为“已经存过”。画面保留旧局供查看，重开基线仍只取ack。
      const revision = Math.max(this.editRevision, this.confirmedRevision) + 1;
      this.editRevision = revision; this.confirmedRevision = revision;
      this.pendingKind = 'none'; this.pendingReport = undefined;
      this.message = '另一端已删除这一夜。记忆保留；重新开局需要明确确认。'; return;
    }
    this.unreadable = marketNightIsUnreadable(this.records, this.currentNightId());
    if (this.unreadable && !this.restartPending) {
      this.playing = false; this.message = '收到的存档暂不可读，原正文已保留，暂停写入。'; return;
    }
    const incoming = marketNightFromRecords(this.records, this.currentNightId());
    if (!incoming || this.pendingWrites > 0) return;
    this.progressDeleted = false;
    // Root提交后会给记录赋真实逻辑时钟。用内容与editRevision识别回执，不能拿UI动作时间
    // 当作“保存完成”。同刻但内容不同的LWW胜出版本也必须留出主动采用入口。
    if (this.sameContent(incoming, this.state)) {
      if (!this.dirty()) { this.state = copyMarketNight(incoming); this.savedAt = incoming.updatedAt;
        this.acknowledgedState = copyMarketNight(incoming); }
      this.incomingState = undefined; this.incomingAvailable = false; return;
    }
    if (incoming.updatedAt >= this.savedAt) { this.incomingState = copyMarketNight(incoming); this.incomingAvailable = true; }
  }
  private adoptIncoming(): void {
    if (!this.incomingState || this.pendingWrites > 0 || this.dirty() || this.playing) return;
    this.state = copyMarketNight(this.incomingState); this.savedAt = this.state.updatedAt;
    this.acknowledgedState = copyMarketNight(this.state); this.incomingState = undefined; this.incomingAvailable = false;
    this.playbackReport = undefined; this.pendingReport = undefined; this.pendingKind = 'none';
    this.message = '已采用另一端保存的这一夜。' + this.resumeMessage();
  }
  private enqueue(restart: boolean): Promise<boolean> {
    const frozen = copyMarketNight(this.state); const revision = this.editRevision;
    this.pendingWrites++; this.localSaving = true;
    const task: Promise<boolean> = this.writeQueue.catch(() => {}).then(async (): Promise<boolean> => {
      try {
        const ok = await this.onSaveState(frozen, restart);
        if (ok) {
          this.savedAt = Math.max(this.savedAt, frozen.updatedAt);
          this.confirmedRevision = Math.max(this.confirmedRevision, revision);
          if (revision === this.editRevision) this.acknowledgedState = copyMarketNight(frozen);
        } else this.message = '这一版尚未存好，已经发生的计算保留在画面上。请重试同一版。';
        return ok;
      } catch (_error) { this.message = '这一版尚未存好，当前安排保留。请重试保存。'; return false; }
      finally {
        this.pendingWrites--; this.localSaving = this.pendingWrites > 0;
        if (this.pendingWrites === 0) this.receiveRecords();
      }
    });
    this.writeQueue = task.then(() => {}); return task;
  }
  private async persistCurrent(kind: NightCommitKind, report: MarketNightBatchReport | undefined = undefined): Promise<void> {
    this.pendingKind = kind; this.pendingReport = report;
    if (!await this.enqueue(kind === 'restart')) return;
    this.pendingKind = 'none'; this.pendingReport = undefined;
    if (kind === 'restart') { this.restartPending = false; this.progressDeleted = false; this.unreadable = false; }
    if (kind === 'begin') { await this.nextBatch(true); return; }
    if (kind === 'batch' && report) {
      // 先取得真实flush回执，再播放本批；保存失败时只重存上面的快照，不再调用advance。
      this.sheetOpen = false; this.playbackReport = report; this.playbackKey++; this.playing = true;
      this.message = `第${report.batch}批已保存：${report.served}/${report.arrivals}客被接住。`;
    } else this.message = this.resumeMessage();
  }
  private act(action: MarketNightAction): void {
    if (!this.idle()) return;
    const result = applyMarketNightAction(this.state, action); this.message = result.message;
    if (!result.changed) return;
    this.state = result.state; this.editRevision++; this.persistCurrent('action');
  }
  private async nextBatch(savedBegin: boolean = false): Promise<void> {
    // begin的flush已返回成功，Root的saving=false可能还未传播成子组件@Prop。
    // 只在这条已确认的内部续接上略过旧prop；本地写队列、墓碑、dirty与播放门禁照常检查。
    const ready = savedBegin ? !this.unreadable && !this.progressDeleted && !this.locked && !this.localSaving &&
      !this.playing && !this.dirty() : this.idle();
    if (!ready || (this.state.phase !== 'running' && this.state.phase !== 'emergency')) return;
    try {
      const result = advanceMarketNightBatch(this.state); this.state = result.state; this.editRevision++;
      await this.persistCurrent('batch', result.report);
    } catch (error) { this.message = `这一批尚未开始：${(error as Error).message}`; }
  }
  private async primary(): Promise<void> {
    if (this.unreadable || this.locked || this.localSaving || this.saving || this.playing) return;
    if (this.dirty()) { await this.persistCurrent(this.pendingKind === 'none' ? 'action' : this.pendingKind, this.pendingReport); return; }
    if (this.progressDeleted) { this.confirmRestart(this.state.routeId); return; }
    if (this.state.phase === 'closed') { this.openSheet('ledger'); return; }
    if (this.state.phase === 'running' || this.state.phase === 'emergency') { await this.nextBatch(); return; }
    const result = this.state.phase === 'prepare' ? beginMarketNightRound(this.state) : endMarketNightRound(this.state);
    this.message = result.message; if (!result.changed) return;
    const kind: NightCommitKind = this.state.phase === 'prepare' ? 'begin' : 'end';
    this.state = result.state; this.editRevision++; await this.persistCurrent(kind);
  }
  private primaryWord(): string {
    if (this.localSaving) return '正在保存这一版';
    if (this.dirty()) return '重试保存这一版';
    if (this.progressDeleted) return '明确重新开这一夜';
    if (this.playing) return '客人正在进街…';
    if (this.state.phase === 'closed') return '翻开收市账本';
    if (this.state.phase === 'settling') return `收第${this.state.round + 1}段 · 结工钱与铺租`;
    if (this.state.phase === 'prepare') return `开第${this.state.round + 1}段 · 迎首批${marketNightForecast(this.state).batchArrivals}客`;
    return `继续第${this.state.batch + 1}批 · ${marketNightForecast(this.state).batchArrivals}客将到`;
  }
  private playbackFinished(): void { this.playing = false; this.message = this.resumeMessage(); }
  private openSheet(mode: string): void { this.sheetMode = mode; this.sheetOpen = true; }
  private back(): void {
    if (this.localSaving) { this.message = '正在把这一版存好，请稍等。'; return; }
    if (this.dirty() && !this.unreadable && !this.progressDeleted) {
      this.message = '当前这一版尚未保存，请先重试保存，再离开这一夜。'; return;
    }
    this.onBack();
  }
  private confirmRestart(route: MarketRouteId): void {
    if (this.unreadable || this.locked || this.localSaving || this.playing || this.dirty()) return;
    const routeName = NIGHT_ROUTES.find(item => item.id === route)?.title || '';
    this.getUIContext().showAlertDialog({ title: '重新开这一夜？',
      message: `采用“${routeName}”，从第一段重新安排。沿用本夜已保存的铺位与人手，重置本夜账目。已写下的记忆保留。`,
      primaryButton: { value: '继续这一夜', action: () => {} },
      secondaryButton: { value: '确认重开', action: () => {
        // 重开只能沿用已确认保存的本夜布局，失败版本不能成为新局基线；
        // 同夜重开也不会再从上一夜取布局，更不会将新布局反写前夜。
        const layout = this.acknowledgedState ? marketNightLayout(this.acknowledgedState) : undefined;
        this.state = createMarketNight(this.currentNightId(), route, Math.max(Date.now(), this.state.updatedAt + 1), layout);
        this.editRevision++; this.restartPending = true; this.playing = false; this.playbackReport = undefined;
        this.sheetOpen = false; this.persistCurrent('restart');
      } } });
  }
  private composeMemory(): void {
    if (!this.idle()) return;
    this.sheetOpen = false; this.onComposeMemory(copyMarketNight(this.state));
  }
  private nextNight(): void {
    const next = nextMarketNight(this.currentNightId());
    if (next && this.idle() && marketNightSummary(this.state).passed) this.onNextNight(next);
  }
  private stock(resource: MarketNightResource): number {
    if (resource === 'rice') return this.state.stock.rice; if (resource === 'meat') return this.state.stock.meat;
    if (resource === 'tea') return this.state.stock.tea; return this.state.stock.oil;
  }
  private amount(resource: MarketNightResource): number { return NIGHT_SUPPLIES[resource]; }
  private cost(resource: MarketNightResource, emergency: boolean = false): number { return marketNightSupplyCost(resource, emergency); }
  private latestRound(): MarketNightRoundSummary | undefined { return this.state.reports[this.state.reports.length - 1]; }
  private latestBatch(): MarketNightBatchSummary | undefined {
    const batches = this.latestRound()?.batches; return batches && batches.length > 0 ? batches[batches.length - 1] : undefined;
  }
  private latestHint(): string {
    if (!this.latestBatch()) return this.message;
    const batch = this.latestBatch()!; let index = -1; let count = 0;
    batch.reasons.forEach((value: number, cursor: number) => { if (value > count) { index = cursor; count = value; } });
    return index < 0 ? `刚才${batch.arrivals}客全接住了；下一批仍共用已经消耗的库存与通行。` :
      `刚才主要流失：${nightLossName(NIGHT_LOSS_REASONS[index])} ${count}客。可查看去向，再决定是否应急。`;
  }
  private lampMoves(): NightLampMove[] {
    const result: NightLampMove[] = [];
    for (let from = 0; from < 3; from++) for (let to = 0; to < 3; to++)
      if (from !== to && this.state.effectiveLamps[from] && !this.state.effectiveLamps[to]) result.push({ from, to });
    return result;
  }
  private donorLots(): MarketNightStall[] { return this.state.stalls.filter(item => item.lotId !== this.selectedLot && item.workers > 0); }
  private targetLine(): string {
    const summary = marketNightSummary(this.state);
    return `目标 ${summary.targetServed}客 · 收市余${summary.targetCash}钱` +
      (summary.targetTeaServed > 0 ? ` · 茶客${this.state.teaServed}/${summary.targetTeaServed}` : '') +
      (summary.targetFestivalServed > 0 ? ` · 灯后消费${this.state.festivalServed}/${summary.targetFestivalServed}` : '');
  }
  private mechanicSourceVisible(): boolean {
    return this.currentNightId() !== 'night-1' && this.state.phase === 'prepare' && this.state.round === 0 && this.state.batch === 0;
  }
  private mechanicSourceTitle(): string {
    return this.currentNightId() === 'night-2' ? '「至三更方有提瓶卖茶者」' : '「游人已集御街两廊下」';
  }
  private mechanicConnection(): string {
    return this.currentNightId() === 'night-2' ? '借夜归卖茶的记述，原创巡茶规则让茶随人走。' :
      '借元宵灯下游人的记述，原创灯棚规则连接观灯与消费。';
  }

  @Builder
  header() {
    Row({ space: 9 }) {
      Button('‹', { type: ButtonType.Normal }).width(35).height(35).fontSize(29).fontColor(TN_PAPER)
        .backgroundColor(TN_PANEL).padding(0).borderRadius(18).id('tn-back').onClick(() => this.back())
      Column({ space: 2 }) {
        Text(this.configTitle()).fontSize(18).fontWeight(FontWeight.Medium).fontColor(TN_PAPER).letterSpacing(1)
        Text('开封三夜').fontSize(9).fontColor('#73968A').letterSpacing(3)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Button('路线', { type: ButtonType.Normal }).height(31).fontSize(11).fontColor(TN_MUTED)
        .backgroundColor(Color.Transparent).padding({ left: 7, right: 7 }).id('tn-route-open').onClick(() => this.openSheet('route'))
      Button('文献', { type: ButtonType.Normal }).height(31).fontSize(11).fontColor(TN_GOLD)
        .backgroundColor(TN_PANEL).padding({ left: 11, right: 11 }).borderRadius(16)
        .id('tn-culture').onClick(() => this.openSheet('culture'))
    }.width('100%').padding({ left: 13, right: 14, top: 8, bottom: 8 })
  }
  @Builder
  statusBand() {
    Column({ space: 7 }) {
      Row() {
        Text(`${this.state.cash} 钱`).fontSize(21).fontWeight(FontWeight.Medium).fontColor(TN_GOLD).layoutWeight(1).id('tn-cash')
        Text(`接待 ${this.state.served}`).fontSize(13).fontColor(TN_PAPER).layoutWeight(1).textAlign(TextAlign.Center).id('tn-served')
        Text(this.phaseWord()).fontSize(11).fontColor(this.state.phase === 'emergency' ? TN_GOLD : TN_MUTED)
          .textAlign(TextAlign.End).layoutWeight(1).id('tn-phase')
      }.width('100%')
      Row({ space: 7 }) {
        Text(`${Math.min(4, this.state.round + 1)}/4 段`).fontSize(10).fontColor('#8DAB98').id('tn-round')
        Text(this.state.phase === 'closed' ? '全夜 12/12 批' : `已迎 ${this.state.batch}/3 批`)
          .fontSize(10).fontColor('#8DAB98').id('tn-batch')
        Blank()
        Text(`米${this.state.stock.rice} 肉${this.state.stock.meat} 茶${this.state.stock.tea} 油${this.state.stock.oil}`)
          .fontSize(10).fontColor('#B1C3A3').id('tn-stock').onClick(() => this.openSheet('supply'))
      }.width('100%')
      Text(this.targetLine()).fontSize(9).fontColor('#B0AD80').width('100%').id('tn-target-line')
      if (this.mechanicSourceVisible()) {
        Button({ type: ButtonType.Normal }) {
          Column({ space: 3 }) {
            Row() {
              Text(this.mechanicSourceTitle()).fontSize(11).fontColor('#E1C38F').layoutWeight(1)
              Text('文献 ›').fontSize(10).fontColor('#AEBA91')
            }.width('100%')
            Text(this.mechanicConnection()).fontSize(10).fontColor('#97AF98').lineHeight(16).width('100%')
          }.width('100%').alignItems(HorizontalAlign.Start)
        }.width('100%').padding({ left: 10, right: 10, top: 7, bottom: 7 }).backgroundColor('#1B3B3C')
          .borderRadius(5).id('tn-mechanic-source').onClick(() => this.openSheet('culture'))
      }
    }.width('100%').padding({ left: 18, right: 18, top: 5, bottom: 9 })
  }
  @Builder
  map() {
    Stack({ alignContent: Alignment.TopStart }) {
      MarketNightScene({ state: this.state, nightId: this.currentNightId(), selectedLot: this.selectedLot, report: this.playbackReport,
        playbackKey: this.playbackKey, active: this.visible && this.playing && !this.sheetOpen,
        reducedMotion: this.reducedMotion, interactive: !this.playing && !this.unreadable && !this.progressDeleted,
        onSelectLot: (id: number) => { this.selectedLot = id; if (!this.wide()) this.openSheet(this.state.phase === 'emergency' ? 'emergency' : 'arrange'); },
        onPlaybackFinished: () => this.playbackFinished() }).width('100%').height('100%')
      Row({ space: 8 }) {
        Text(this.state.phase === 'closed' ? '河岸收市 · 这一夜已存好' : this.playing ?
          `第${this.playbackReport?.batch || this.state.batch}批 · 需求随人进街` :
          `${marketNightForecast(this.state).title} · 下一批 饭${marketNightForecast(this.state).batchPreferences[0]} 肉${marketNightForecast(this.state).batchPreferences[1]} 茶${marketNightForecast(this.state).batchPreferences[2]}`)
          .fontSize(10).fontColor('#D8D8B7').lineHeight(17)
        Text('›').fontSize(15).fontColor(TN_GOLD)
      }.padding({ left: 11, right: 11, top: 5, bottom: 5 }).backgroundColor('#17383B')
        .borderRadius(12).position({ x: 12, y: 9 }).id('tn-forecast-open').onClick(() => this.openSheet('forecast'))
    }.width('100%').height('100%').id('tn-scene-frame')
  }
  @Builder
  controls() {
    Column({ space: 6 }) {
      if (this.state.phase === 'closed') {
        Row() {
          Text(marketNightSummary(this.state).title).fontSize(16).fontColor(TN_GOLD).layoutWeight(1).id('tn-closing-title')
          Text(marketNightSummary(this.state).passed ? '目标已达成' : '还可再安排').fontSize(10).fontColor(TN_MUTED)
        }.width('100%').padding({ left: 17, right: 17, top: 9 })
      } else {
        Row({ space: 7 }) {
          Text(`${NIGHT_LOTS[this.selectedLot].label} · ${nightTypeName(this.selected().type)}`)
            .fontSize(12).fontColor(TN_PAPER).layoutWeight(1).id('tn-selected')
          Text(`应急还可 ${marketNightForecast(this.state).emergencyLeft} 次`).fontSize(10).fontColor(TN_GOLD).id('tn-emergency-left')
          Button(this.state.phase === 'emergency' ? '应急调度' : '安排', { type: ButtonType.Normal }).height(29)
            .fontSize(11).fontColor(TN_GOLD).backgroundColor(TN_PANEL).padding({ left: 10, right: 10 }).borderRadius(14)
            .enabled(!this.playing).id('tn-emergency-open').onClick(() => this.openSheet(this.state.phase === 'emergency' ? 'emergency' : 'arrange'))
        }.width('100%').padding({ left: 17, right: 17, top: 8 })
      }
      Text(this.dirty() || this.unreadable || this.progressDeleted || this.localSaving ? this.message :
        this.state.phase === 'emergency' && !this.playing ? this.latestHint() : this.message)
        .fontSize(10).fontColor(this.dirty() ? '#DFAD83' : TN_MUTED).lineHeight(17).maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%').padding({ left: 18, right: 18 }).id('tn-feedback')
      if (this.incomingAvailable) {
        Button(this.dirty() ? '另一端有新版本，先保存本次安排' : '采用另一端的这一夜', { type: ButtonType.Normal })
          .height(28).fontSize(11).fontColor(TN_GOLD).backgroundColor(Color.Transparent)
          .enabled(!this.dirty() && !this.localSaving && !this.playing).id('tn-adopt-incoming').onClick(() => this.adoptIncoming())
      }
      Button(this.primaryWord(), { type: ButtonType.Normal }).height(45).width('92%').fontSize(15)
        .fontWeight(FontWeight.Medium).fontColor('#163532').backgroundColor(TN_GOLD).borderRadius(5)
        .enabled(!this.unreadable && !this.locked && !this.localSaving && !this.saving && !this.playing)
        .id('tn-primary').onClick(() => { this.primary(); })
      Row({ space: 7 }) {
        if (this.state.phase === 'closed') {
          // 不把enabled布尔值作为@Builder的值参数传入：收市分支在保存途中首次创建，
          // 值参数可能保留当时的false，落盘回执不会重绑；播放期间也可能反向滞留true。
          // 直接由当前可观察状态求值，保留保存、dirty、墓碑与播放的完整门禁。
          Button('换路重玩', { type: ButtonType.Normal }).height(31).fontSize(11).fontColor(TN_PAPER).backgroundColor(TN_PANEL)
            .padding({ left: 11, right: 11 }).borderRadius(8).enabled(this.idle()).id('tn-retry').onClick(() => this.openSheet('route'))
          Button('写这一夜的记忆', { type: ButtonType.Normal }).height(31).fontSize(11).fontColor(TN_PAPER).backgroundColor(TN_PANEL)
            .padding({ left: 11, right: 11 }).borderRadius(8).enabled(this.idle()).id('tn-memory').onClick(() => this.composeMemory())
          if (marketNightSummary(this.state).passed && nextMarketNight(this.currentNightId())) {
            Button('走向下一夜 →', { type: ButtonType.Normal }).height(31).fontSize(11).fontColor(TN_PAPER).backgroundColor(TN_PANEL)
              .padding({ left: 11, right: 11 }).borderRadius(8).enabled(this.idle()).id('tn-next-night').onClick(() => this.nextNight())
          }
        } else {
          Button('码头补货', { type: ButtonType.Normal }).height(31).fontSize(11).fontColor(TN_PAPER).backgroundColor(TN_PANEL)
            .padding({ left: 11, right: 11 }).borderRadius(8).enabled(!this.playing).id('tn-supply-open').onClick(() => this.openSheet('supply'))
          Button('客流与灯', { type: ButtonType.Normal }).height(31).fontSize(11).fontColor(TN_PAPER).backgroundColor(TN_PANEL)
            .padding({ left: 11, right: 11 }).borderRadius(8).enabled(!this.playing).id('tn-forecast').onClick(() => this.openSheet('forecast'))
          Button('去向账本', { type: ButtonType.Normal }).height(31).fontSize(11).fontColor(TN_PAPER).backgroundColor(TN_PANEL)
            .padding({ left: 11, right: 11 }).borderRadius(8).enabled(!this.playing).id('tn-ledger-open').onClick(() => this.openSheet('ledger'))
        }
      }.width('100%').justifyContent(FlexAlign.Center).padding({ top: 1 })
      Text(this.saveStatus()).fontSize(9).fontColor('#73978A').width('100%').textAlign(TextAlign.Center).id('tn-save-state')
    }.width('100%').padding({ bottom: 9 }).backgroundColor(TN_NIGHT)
  }

  @Builder
  selectionContent() {
    Column({ space: 14 }) {
      Text(`${NIGHT_LOTS[this.selectedLot].label}`).fontSize(24).fontColor('#294B40').width('100%')
      Text(this.state.phase === 'prepare' ? '备市时可以改建、调人；开市之后等下一段再改铺子。' :
        '这一段已经开市。铺子保持原样，前两批后可以应急调度。').fontSize(12).fontColor('#7B8065').lineHeight(21).width('100%')
      Row({ space: 6 }) {
        ForEach(NIGHT_LOTS, (lot: MarketNightLot) => {
          Button(`${lot.id + 1}`, { type: ButtonType.Normal }).layoutWeight(1).height(34).fontSize(13)
            .fontColor('#3D5C46').backgroundColor(this.selectedLot === lot.id ? '#D7BA7E' : '#E1E3CB').borderRadius(8)
            .id(`tn-select-lot-${lot.id}`).onClick(() => { this.selectedLot = lot.id; })
        }, (lot: MarketNightLot) => `${lot.id}`)
      }.width('100%')
      if (this.selected().type === '') {
        ForEach(NIGHT_STALL_CONFIGS, (config: MarketNightStallConfig) => {
          Row() {
            Column({ space: 4 }) {
              Text(config.name).fontSize(17).fontColor('#365844')
              Text(config.type === 'lantern' ? '第三夜可建一座 · 需1人和所在街亮灯' : `开铺 ${config.buildCost}钱 · 收铺返 ${config.refund}钱`)
                .fontSize(11).fontColor('#818467')
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Button('开铺', { type: ButtonType.Normal }).height(36).fontSize(12).fontColor('#345344')
              .backgroundColor('#DCDDBA').borderRadius(10)
              .enabled(this.preparing() && this.state.cash >= config.buildCost && (config.type !== 'lantern' || this.currentNightId() === 'night-3'))
              .id(`tn-build-${config.type}`).onClick(() => this.act({ kind: 'build', lotId: this.selectedLot, stallType: config.type }))
          }.width('100%').padding({ top: 11, bottom: 11 }).border({ width: { bottom: 1 }, color: '#D4D6BE' })
        }, (config: MarketNightStallConfig) => config.type)
      } else {
        Text(nightTypeName(this.selected().type)).fontSize(20).fontColor('#486A4D').width('100%')
        Row({ space: 13 }) {
          Button('−', { type: ButtonType.Normal }).width(42).height(40).fontSize(23).fontColor('#365844')
            .backgroundColor('#DDE0C2').borderRadius(9).enabled(this.preparing() && this.selected().workers > 0)
            .id('tn-staff-minus').onClick(() => this.act({ kind: 'staff', lotId: this.selectedLot, delta: -1 }))
          Text(`${this.selected().workers} 伙计`).fontSize(18).fontColor('#365844').layoutWeight(1).id('tn-selected-workers')
          Button('+', { type: ButtonType.Normal }).width(42).height(40).fontSize(23).fontColor('#365844')
            .backgroundColor('#DDE0C2').borderRadius(9)
            .enabled(this.preparing() && marketNightSummary(this.state).freeWorkers > 0 && (this.selected().type !== 'lantern' || this.selected().workers < 1))
            .id('tn-staff-plus').onClick(() => this.act({ kind: 'staff', lotId: this.selectedLot, delta: 1 }))
        }.width('100%')
        Text(`待分配 ${marketNightSummary(this.state).freeWorkers} 人。${this.selected().type === 'lantern' ? '灯棚只需1人。' :
          `本段接待名额：${Math.max(0, marketNightForecast(this.state).staffCapacity[this.selectedLot] - this.state.usedCapacity[this.selectedLot])}。`}`)
          .fontSize(12).fontColor('#7E836A').lineHeight(21).width('100%')
        Button('收铺并退回部分开铺钱', { type: ButtonType.Normal }).height(39).fontSize(12).fontColor('#946F4E')
          .backgroundColor('#E8E1C8').borderRadius(9).width('100%').enabled(this.preparing()).id('tn-demolish')
          .onClick(() => this.act({ kind: 'demolish', lotId: this.selectedLot }))
      }
      Row() {
        Text(`${MARKET_ZONE_NAMES[this.zone()]}街灯`).fontSize(14).fontColor('#466447').layoutWeight(1)
        Button(this.state.lamps[this.zone()] ? '已留灯' : '为这一街留灯', { type: ButtonType.Normal }).height(35)
          .fontSize(12).fontColor('#5F5D39').backgroundColor(this.state.lamps[this.zone()] ? '#DFC486' : '#DEE2CA')
          .borderRadius(11).enabled(this.preparing()).id('tn-lamp')
          .onClick(() => this.act({ kind: 'lamp', zone: this.zone(), on: !this.state.lamps[this.zone()] }))
      }.width('100%').padding({ top: 9, bottom: 9 })
      if (this.currentNightId() !== 'night-1') { this.tourContent(false) }
      Text(this.message).fontSize(12).fontColor('#8D7954').lineHeight(21).width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder
  tourContent(emergency: boolean) {
    Column({ space: 8 }) {
      Text('提瓶巡茶').fontSize(16).fontColor('#3E664C').width('100%')
      Text(`当前：${this.state.tourZone < 0 ? '尚未派人' : MARKET_ZONE_NAMES[this.state.tourZone] + '巡茶'}。占1名伙计，每批最多接待该街2位茶客，实际消耗茶料。${emergency ? '改派或收回占1次应急。' : ''}`)
        .fontSize(11).fontColor('#7C8269').lineHeight(20).width('100%')
      Row({ space: 6 }) {
        ForEach([-1, 0, 1, 2], (zone: number) => {
          Button(zone < 0 ? '收回' : MARKET_ZONE_NAMES[zone], { type: ButtonType.Normal }).layoutWeight(1).height(34)
            .fontSize(11).fontColor('#3F5B43').backgroundColor(this.state.tourZone === zone ? '#CECEA1' : '#E2E4CD').borderRadius(8)
            .enabled(emergency ? this.emergency() && this.state.emergencyUsed < 2 && this.state.tourZone >= 0 : this.preparing())
            .id(`tn-${emergency ? 'emergency-' : ''}tour-${zone}`)
            .onClick(() => this.act(emergency ? { kind: 'emergency-tour', zone } : { kind: 'tour', zone }))
        }, (zone: number) => `${zone}`)
      }.width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 9, bottom: 9 })
  }
  @Builder
  supplyContent(emergency: boolean = false) {
    Column({ space: 12 }) {
      Text(emergency ? '码头急送' : '码头补货').fontSize(24).fontColor('#294B40').width('100%')
      Text(emergency ? `急送占1次应急，价格高于备市补货。本段还可应急 ${marketNightForecast(this.state).emergencyLeft} 次。` :
        `每段备市可走两趟，当前还可 ${marketNightForecast(this.state).supplyTripsLeft} 趟。余钱 ${this.state.cash}。`)
        .fontSize(12).fontColor('#798069').lineHeight(21).width('100%')
      ForEach(this.supplies, (row: NightSupplyRow) => {
        Row({ space: 12 }) {
          Column({ space: 5 }) {
            Text(`${row.name}  ${this.stock(row.resource)}`).fontSize(17).fontColor('#365844')
            Text(`一包 +${this.amount(row.resource)} · ${this.cost(row.resource, emergency)}钱`)
              .fontSize(11).fontColor('#818467')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Button(emergency ? '急送' : '进一包', { type: ButtonType.Normal }).height(38).fontSize(12).fontColor('#365844')
            .backgroundColor('#DADDBA').borderRadius(10)
            .enabled(emergency ? this.emergency() && this.state.emergencyUsed < 2 && this.state.cash >= this.cost(row.resource, true) : this.preparing() && this.state.supplyTrips < 2 && this.state.cash >= this.cost(row.resource))
            .id(`${emergency ? 'tn-emergency-buy' : 'tn-buy'}-${row.resource}`)
            .onClick(() => this.act(emergency ? { kind: 'emergency-buy', resource: row.resource } : { kind: 'buy', resource: row.resource }))
        }.width('100%').padding({ top: 13, bottom: 13 }).border({ width: { bottom: 1 }, color: '#D4D6BE' })
      }, (row: NightSupplyRow) => row.resource)
      Text(this.message).fontSize(12).fontColor('#8D7954').lineHeight(21).width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder
  emergencyContent() {
    Column({ space: 15 }) {
      Text('这一批后，你来决定').fontSize(24).fontColor('#294B40').width('100%')
      Text(`已迎第${this.state.batch}批，本段还可应急 ${marketNightForecast(this.state).emergencyLeft} 次。已发生的消费、人手名额和通行保持。`)
        .fontSize(12).fontColor('#7B8068').lineHeight(22).width('100%')
      Text(this.latestHint()).fontSize(13).fontColor('#9C744D').lineHeight(22).width('100%')
      Text('调1人，去正在缺手的铺子').fontSize(17).fontColor('#3D5E45').width('100%')
      Text('占1次应急，不花钱；已用接待名额不退回。').fontSize(11).fontColor('#8B8264').lineHeight(20).width('100%')
      Row({ space: 6 }) {
        ForEach(NIGHT_LOTS, (lot: MarketNightLot) => {
          Button(`${lot.id + 1}`, { type: ButtonType.Normal }).layoutWeight(1).height(34).fontSize(12)
            .fontColor('#3F5B43').backgroundColor(this.selectedLot === lot.id ? '#D7BA7E' : '#E2E4CD').borderRadius(8)
            .id(`tn-emergency-target-${lot.id}`).onClick(() => { this.selectedLot = lot.id; })
        }, (lot: MarketNightLot) => `${lot.id}`)
      }.width('100%')
      Text(`调入：${NIGHT_LOTS[this.selectedLot].label} · ${nightTypeName(this.selected().type)}（${this.selected().workers}人）`)
        .fontSize(12).fontColor('#697A5D').width('100%')
      if (marketNightSummary(this.state).freeWorkers > 0) {
        Button('从待分配处调1人来', { type: ButtonType.Normal }).width('100%').height(35).fontSize(12)
          .fontColor('#3F5B43').backgroundColor('#DDE0C0').borderRadius(8)
          .enabled(this.emergency() && this.state.emergencyUsed < 2 && this.selected().type !== '')
          .id('tn-emergency-staff-free').onClick(() => this.act({ kind: 'emergency-staff', fromLot: -1, toLot: this.selectedLot }))
      }
      ForEach(this.donorLots(), (stall: MarketNightStall) => {
        Button(`从${NIGHT_LOTS[stall.lotId].label} ${nightTypeName(stall.type)}调1人（现有${stall.workers}）`, { type: ButtonType.Normal })
          .width('100%').height(36).fontSize(12).fontColor('#3F5B43').backgroundColor('#E0E2C8').borderRadius(8)
          .enabled(this.emergency() && this.state.emergencyUsed < 2 && this.selected().type !== '')
          .id(`tn-emergency-staff-${stall.lotId}`).onClick(() => this.act({ kind: 'emergency-staff', fromLot: stall.lotId, toLot: this.selectedLot }))
      }, (stall: MarketNightStall) => `${stall.lotId}`)
      Text('移一盏灯，让剩下的人走得通').fontSize(17).fontColor('#3D5E45').width('100%').margin({ top: 5 })
      Text('占1次应急，不加灯数、不退已耗灯油。').fontSize(11).fontColor('#8B8264').lineHeight(20).width('100%')
      ForEach(this.lampMoves(), (move: NightLampMove) => {
        Button(`${MARKET_ZONE_NAMES[move.from]} → ${MARKET_ZONE_NAMES[move.to]}`, { type: ButtonType.Normal }).width('100%')
          .height(36).fontSize(12).fontColor('#665D37').backgroundColor('#E0D5AA').borderRadius(8)
          .enabled(this.emergency() && this.state.emergencyUsed < 2).id(`tn-emergency-lamp-${move.from}-${move.to}`)
          .onClick(() => this.act({ kind: 'emergency-lamp', fromZone: move.from, toZone: move.to }))
      }, (move: NightLampMove) => `${move.from}-${move.to}`)
      if (this.lampMoves().length === 0) { Text('没有可移的已亮街灯。').fontSize(12).fontColor('#8B846A').width('100%') }
      if (this.currentNightId() !== 'night-1') { this.tourContent(true) }
      this.supplyContent(true)
      Button('安排好了，回河岸看下一批 →', { type: ButtonType.Normal }).height(42).width('100%').fontColor('#315B48')
        .fontSize(13).backgroundColor('#D5DDBD').borderRadius(9).onClick(() => { this.sheetOpen = false; })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder
  forecastContent() {
    Column({ space: 14 }) {
      Text(this.state.phase === 'closed' ? '今夜已收市' : `${marketNightForecast(this.state).title}`).fontSize(24)
        .fontColor('#294B40').width('100%')
      Text(`路线 · ${marketNightForecast(this.state).routeTitle}`).fontSize(12).fontColor('#9A794E').width('100%')
      Text(this.state.phase === 'settling' ? '三批客流都已保存，点击收段才结工钱与铺租。' :
        `全段 ${marketNightForecast(this.state).arrivals}客，下一批 ${marketNightForecast(this.state).batchArrivals}客：水饭${marketNightForecast(this.state).batchPreferences[0]}、肉食${marketNightForecast(this.state).batchPreferences[1]}、茶饮${marketNightForecast(this.state).batchPreferences[2]}。`)
        .fontSize(14).fontColor('#4D6A50').lineHeight(24).width('100%')
      if (this.currentNightId() === 'night-3') {
        Text(`下一批有 ${marketNightForecast(this.state).batchFestivalArrivals} 位观灯客。先观灯，再消费，才计入本夜专项目标。`)
          .fontSize(12).fontColor('#99764B').lineHeight(22).width('100%')
      }
      ForEach([0, 1, 2], (zone: number) => {
        Column({ space: 5 }) {
          Row() {
            Text(`${MARKET_ZONE_NAMES[zone]} · 下批${marketNightForecast(this.state).batchZoneArrivals[zone]}客`).fontSize(14).fontColor('#3E6046').layoutWeight(1)
            Button(this.state.lamps[zone] ? '已留灯' : '未留灯', { type: ButtonType.Normal }).height(32).fontSize(11)
              .fontColor('#655E38').backgroundColor(this.state.lamps[zone] ? '#E1C58A' : '#DDE2CC').borderRadius(11)
              .enabled(this.preparing()).id(`tn-zone-lamp-${zone}`)
              .onClick(() => this.act({ kind: 'lamp', zone, on: !this.state.lamps[zone] }))
          }.width('100%')
          Text(`通行已用 ${this.state.flow[zone]}/${marketNightForecast(this.state).laneCapacity[zone]} · ${marketNightForecast(this.state).effectiveLamps[zone] ? '实际有灯' : '实际无灯'}`)
            .fontSize(11).fontColor('#7D856A').width('100%')
        }.width('100%').padding({ top: 9, bottom: 11 }).border({ width: { bottom: 1 }, color: '#D4D6BE' })
      }, (zone: number) => `${zone}`)
      Text(`收段支出：工钱 ${marketNightForecast(this.state).wages}，铺租 ${marketNightForecast(this.state).rent}。${this.state.phase === 'prepare' ? '开段留灯预计需油' + marketNightForecast(this.state).oilNeeded + '。' : '本段灯油已在开市时扣除。'}`)
        .fontSize(12).fontColor('#7E7C61').lineHeight(21).width('100%')
      Text(marketNightForecast(this.state).detail).fontSize(12).fontColor('#7A836A').lineHeight(22).width('100%')
      this.shortSource()
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder
  shortSource() {
    Column({ space: 8 }) {
      Text(`「${marketCultureForNight(this.currentNightId())?.quote || ''}」`).fontSize(16).fontColor('#99764A').lineHeight(27).width('100%')
      Text(marketCultureForNight(this.currentNightId())?.source.title || '').fontSize(10).fontColor('#8F9279').lineHeight(18).width('100%')
      Button('读这段文献与玩法来由 →', { type: ButtonType.Normal }).height(36).fontSize(12).fontColor('#486A50')
        .backgroundColor('#DFE2C8').borderRadius(9).width('100%').id('tn-night-culture-source')
        .onClick(() => { this.sheetOpen = false; this.onOpenContent(marketCultureForNight(this.currentNightId())?.id || 'kf-zhouqiao'); })
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 12, bottom: 8 })
  }
  @Builder
  goalContent() {
    Column({ space: 10 }) {
      Text('今夜要留住什么').fontSize(20).fontColor('#365843').width('100%')
      Text(`接待 ${this.state.served}/${marketNightSummary(this.state).targetServed}客 · 收市至少余${marketNightSummary(this.state).targetCash}钱`)
        .fontSize(14).fontColor('#8B734B').lineHeight(23).width('100%').id('tn-target')
      if (marketNightSummary(this.state).targetTeaServed > 0) {
        Text(`茶客 ${this.state.teaServed}/${marketNightSummary(this.state).targetTeaServed}`).fontSize(14).fontColor('#557B58').width('100%').id('tn-tea-target')
      }
      if (marketNightSummary(this.state).targetFestivalServed > 0) {
        Text(`观灯后消费 ${this.state.festivalServed}/${marketNightSummary(this.state).targetFestivalServed}`).fontSize(14).fontColor('#9C7B47').width('100%').id('tn-festival-target')
      }
      Text('每段三批，前两批后都能决定；两次应急额度由你取舍。')
        .fontSize(11).fontColor('#899177').lineHeight(20).width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder
  ledgerContent() {
    Column({ space: 15 }) {
      Text(this.state.phase === 'closed' ? '这一夜的收市账本' : '客人去了哪里').fontSize(24).fontColor('#294B40').width('100%')
      this.goalContent()
      ForEach(this.state.reports, (report: MarketNightRoundSummary) => {
        Column({ space: 10 }) {
          Text(`第${report.round}段 · 接待 ${report.served}/${report.arrivals}`).fontSize(17).fontColor('#365B44').width('100%')
          ForEach(report.batches, (batch: MarketNightBatchSummary) => {
            Row() {
              Text(`第${batch.batch}批 · ${batch.served}/${batch.arrivals}客`).fontSize(12).fontColor('#768067').layoutWeight(1)
              Text(`进账 ${batch.income}`).fontSize(12).fontColor('#90754C')
            }.width('100%')
          }, (batch: MarketNightBatchSummary) => `${batch.batch}`)
          Text(report.batches.length < 3 || (report.round === this.state.round + 1 && this.state.phase === 'settling') ?
            `当前进账 ${report.income} · 工钱与铺租尚未结` : `进账 ${report.income} · 工钱 ${report.wages} · 总支出 ${report.expenses} · 结段余 ${report.cashAfter}`)
            .fontSize(11).fontColor('#7D8268').lineHeight(20).width('100%')
          ForEach(NIGHT_LOSS_REASONS, (reason: MarketNightReason, index: number) => {
            if (report.reasons[index] > 0) {
              Row() {
                Text(nightLossName(reason)).fontSize(12).fontColor('#956C50').layoutWeight(1)
                Text(`${report.reasons[index]}客`).fontSize(12).fontColor('#956C50')
              }.width('100%')
            }
          }, (reason: MarketNightReason) => reason)
        }.width('100%').padding(14).backgroundColor('#FFFAE7').borderRadius(9)
      }, (report: MarketNightRoundSummary) => `${report.round}`)
      if (this.playbackReport) {
        Text('刚才这一批的去向').fontSize(17).fontColor('#46694B').width('100%')
        ForEach(NIGHT_LOTS, (lot: MarketNightLot) => {
          if (this.playbackReport!.servedByLot[lot.id] > 0) {
            Row() {
              Text(`${lot.label} · ${nightTypeName(this.playbackReport!.stallTypes[lot.id])}`).fontSize(12).fontColor('#718266').layoutWeight(1)
              Text(`${this.playbackReport!.servedByLot[lot.id]}客`).fontSize(12).fontColor('#967A4E')
            }.width('100%')
          }
        }, (lot: MarketNightLot) => `${lot.id}`)
        ForEach(this.playbackReport!.advice, (advice: string) => {
          Text(advice).fontSize(12).fontColor('#7D8569').lineHeight(22).width('100%')
        }, (advice: string) => advice)
      }
      if (this.state.phase === 'closed') {
        Text(marketNightSummary(this.state).title).fontSize(21).fontColor('#A07B47').width('100%')
        Text(marketNightSummary(this.state).detail).fontSize(13).fontColor('#7D8569').lineHeight(23).width('100%')
        Button('亲手写下这一夜 →', { type: ButtonType.Normal }).height(43).width('100%').fontSize(14)
          .fontColor('#365B44').backgroundColor('#D9DEBD').borderRadius(9).enabled(this.idle()).id('tn-ledger-memory')
          .onClick(() => this.composeMemory())
        Button('换一条来客路线，再开一夜', { type: ButtonType.Normal }).height(39).width('100%').fontSize(12)
          .fontColor('#8B754E').backgroundColor('#E8E0C5').borderRadius(9).enabled(this.idle()).id('tn-ledger-retry')
          .onClick(() => { this.sheetMode = 'route'; })
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder
  cultureContent() {
    Column({ space: 15 }) {
      Text(marketCultureForNight(this.currentNightId())?.title || '这一夜的文献').fontSize(24).fontColor('#294B40').width('100%')
      this.shortSource()
      Text(marketCultureForNight(this.currentNightId())?.body || '').fontSize(14).fontColor('#657A5E').lineHeight(25).width('100%')
      Text(marketCultureForNight(this.currentNightId())?.gameConnection || '').fontSize(13).fontColor('#7B8067').lineHeight(23).width('100%')
      Button('记下这一刻 →', { type: ButtonType.Normal }).height(43).width('100%').fontSize(14).fontColor('#365B44')
        .backgroundColor('#D8DEBD').borderRadius(9).enabled(this.idle()).id('tn-moment-memory').onClick(() => this.composeMemory())
      Text('亲手写下你的安排与感受，冻结眼前已保存的真实进度。开市与阅读都不会替你生成记忆。')
        .fontSize(11).fontColor('#8B8E74').lineHeight(20).width('100%')
      Text(MARKET_CULTURE_BOUNDARY).fontSize(11).fontColor('#8B8E74').lineHeight(21).width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder
  routeContent() {
    Column({ space: 16 }) {
      Text('换一条来客路线').fontSize(24).fontColor('#294B40').width('100%')
      Text('路线改变人从哪条街进来，也改变铺位与通行的取舍。选择后确认重开本夜；已写下的个人记忆保留。')
        .fontSize(13).fontColor('#7B8067').lineHeight(23).width('100%')
      ForEach(NIGHT_ROUTES, (route: MarketNightRoute) => {
        Button({ type: ButtonType.Normal }) {
          Column({ space: 8 }) {
            Row() {
              Text(route.title).fontSize(18).fontColor('#365C44').layoutWeight(1)
              Text(this.state.routeId === route.id ? '当前路线' : '选择重开').fontSize(11).fontColor('#9E7B4A')
            }.width('100%')
            Text(route.detail).fontSize(12).fontColor('#7B8468').lineHeight(21).width('100%')
          }.width('100%').alignItems(HorizontalAlign.Start)
        }.width('100%').padding(17).backgroundColor('#FFF9E5').borderRadius(10)
          .enabled(!this.unreadable && !this.locked && !this.localSaving && !this.dirty() && !this.playing)
          .id(`tn-route-${route.id}`).onClick(() => this.confirmRestart(route.id))
      }, (route: MarketNightRoute) => route.id)
      if (this.unreadable) { Text('原存档暂不可读，已停写。请先恢复备份。').fontSize(12).fontColor('#A47B58').width('100%') }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder
  sheet() {
    Column() {
      Row() {
        Text('开封三夜 · ' + this.phaseWord()).fontSize(12).fontColor('#879178').layoutWeight(1)
        Button('回河岸', { type: ButtonType.Normal }).height(33).fontSize(12).fontColor('#416249')
          .backgroundColor('#E0E2CB').borderRadius(17).id('tn-sheet-close').onClick(() => { this.sheetOpen = false; })
      }.width('100%').padding({ left: 20, right: 18, top: 12, bottom: 11 })
      Scroll() {
        Column() {
          if (this.sheetMode === 'arrange') { this.selectionContent() }
          else if (this.sheetMode === 'supply') { this.supplyContent() }
          else if (this.sheetMode === 'emergency') { this.emergencyContent() }
          else if (this.sheetMode === 'forecast') { this.forecastContent() }
          else if (this.sheetMode === 'ledger') { this.ledgerContent() }
          else if (this.sheetMode === 'route') { this.routeContent() }
          else { this.cultureContent() }
        }.width('100%').padding({ left: 20, right: 20, top: 3, bottom: 30 })
      }.width('100%').layoutWeight(1).align(Alignment.TopStart).scrollBar(BarState.Off).id('tn-sheet-scroll')
    }.width('100%').height('100%').backgroundColor('#F2EEDB')
  }
  @Builder
  playArea() {
    Column() {
      this.statusBand()
      Column() { this.map() }.width('100%').layoutWeight(1).constraintSize({ minHeight: 235 })
      this.controls()
    }.width('100%').height('100%')
  }
  @Builder
  wideNotes() {
    Scroll() {
      Column({ space: 24 }) {
        this.goalContent()
        if (this.state.phase === 'closed') { this.ledgerContent() }
        else {
          if (this.state.phase === 'emergency') {
            Text(this.latestHint()).fontSize(13).fontColor('#A17A4D').lineHeight(23).width('100%')
          }
          if (this.state.phase === 'prepare') { this.selectionContent() }
          this.forecastContent()
        }
      }.width('100%').alignItems(HorizontalAlign.Start).padding(24)
    }.width('100%').height('100%').scrollBar(BarState.Off).backgroundColor('#F2EEDB').id('tn-wide-notes')
  }
  build() {
    NavDestination() {
      Column() {
        this.header()
        if (this.wide()) {
          Row() {
            Column() { this.playArea() }.layoutWeight(1.8).height('100%')
            Column() {
              if (!this.sheetOpen) { this.wideNotes() }
            }.layoutWeight(1).height('100%').backgroundColor('#F2EEDB')
          }.width('100%').layoutWeight(1).alignItems(VerticalAlign.Top)
        } else { Column() { this.playArea() }.width('100%').layoutWeight(1) }
      }.width('100%').height('100%').backgroundColor(TN_NIGHT).id('tn-page')
        .onAreaChange((_old: Area, area: Area) => { this.widthVp = Number(area.width); })
    }.hideTitleBar(true).backgroundColor(TN_NIGHT)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .systemBarStyle({ statusBarContentColor: '#FFF2E6C9' })
      .onShown(() => { this.visible = true; setPaperWindowText(this.getUIContext(), '#F2E6C9'); })
      .onHidden(() => { this.visible = false; })
      // 平板居中Sheet继续交给系统先平移再缩放，资料/调度从Scroll顶部开始排。
      // 明确写记忆在独立原生页完成，本页不以收市动作替用户生成任何note。
      .bindSheet($$this.sheetOpen, this.sheet(), { height: SheetSize.LARGE, showClose: false, dragBar: true,
        keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_RESIZE })
      .onBackPressed(() => {
        if (this.sheetOpen) { this.sheetOpen = false; return true; }
        this.back(); return true;
      })
  }
}

