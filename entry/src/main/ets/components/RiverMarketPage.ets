import type { ArchiveRecord } from '../domain/ArchiveDomain';
import { RiverMarketState, MarketAction, MarketResource, MarketRoundReport, MarketRoundSummary,
  MarketStall, MarketStallConfig, MarketVisitReason, MarketLot, MARKET_STALL_TYPES, MARKET_LOTS, MARKET_SUPPLIES,
  MARKET_SUPPLY_COSTS, MARKET_LOSS_REASONS, createRiverMarket, copyRiverMarket,
  applyMarketAction, advanceMarketRound, marketForecast, marketSummary } from '../domain/RiverMarket';
import { riverMarketFromRecords, riverMarketIsDeleted, riverMarketIsUnreadable } from '../domain/RiverMarketRecords';
import { MARKET_ZONE_NAMES, MARKET_SOURCES, MARKET_SOURCE_QUOTE, MARKET_CULTURE_BOUNDARY,
  RiverMarketSource, marketStallName, marketReasonName } from '../data/RiverMarketCatalog';
import { setPaperWindowText } from '../platform/PaperWindowStyle';
import { RiverMarketScene } from './RiverMarketScene';

const MARKET_NIGHT: string = '#102A31';
const MARKET_PANEL: string = '#203D40';
const MARKET_PAPER: string = '#F2E6C9';
const MARKET_GOLD: string = '#E5B879';
const MARKET_MUTED: string = '#A4B9AB';
interface MarketSupplyRow { resource: MarketResource; name: string; }

@Component
export struct RiverMarketPage {
  @Prop @Watch('receiveRecords') records: ArchiveRecord[] = [];
  @Prop reducedMotion: boolean = false;
  @Prop saving: boolean = false;
  onSaveState: (state: RiverMarketState, restart: boolean) => Promise<boolean> = async () => false;
  onSaveMemory: (body: string, quote: string, state: RiverMarketState) => Promise<boolean> = async () => false;
  onOpenContent: (id: string) => void = () => {};
  onBack: () => void = () => {};
  @State private state: RiverMarketState = createRiverMarket(0);
  @State private selectedLot: number = 2;
  @State private widthVp: number = 360;
  @State private visible: boolean = true;
  @State private unreadable: boolean = false;
  @State private progressDeleted: boolean = false;
  @State private localSaving: boolean = false;
  @State private roundSaving: boolean = false;
  @State private savedAt: number = 0;
  @State private playing: boolean = false;
  @State private playbackKey: number = 0;
  @State private playbackReport: MarketRoundReport | undefined = undefined;
  @State private message: string = '两间铺子已经备好。可以直接开第一段，也可以先点空地看看。';
  @State private sheetOpen: boolean = false;
  @State private sheetMode: string = 'supply';
  @State private memoryBody: string = '';
  @State private memorySaving: boolean = false;
  @State private memorySaved: boolean = false;
  @State private roundNeedsSave: boolean = false;
  @State private editRevision: number = 0;
  @State private confirmedRevision: number = 0;
  @State private incomingAvailable: boolean = false;
  private writeQueue: Promise<void> = Promise.resolve();
  private pendingWrites: number = 0;
  private pendingReport: MarketRoundReport | undefined = undefined;
  private incomingState: RiverMarketState | undefined = undefined;
  private supplyRows: MarketSupplyRow[] = [{ resource: 'rice', name: '米粮' }, { resource: 'meat', name: '肉料' },
    { resource: 'tea', name: '茶料' }, { resource: 'oil', name: '灯油' }];

  aboutToAppear(): void {
    this.unreadable = riverMarketIsUnreadable(this.records);
    this.progressDeleted = riverMarketIsDeleted(this.records);
    const saved = riverMarketFromRecords(this.records);
    this.state = saved || createRiverMarket(Date.now()); this.savedAt = saved?.updatedAt || 0;
    if (this.progressDeleted) this.message = '这座夜市的进度已删除。已写下的记忆保留，可明确重新开市。';
    else if (this.unreadable) this.message = '这座夜市的存档暂不可读。原记录已保留，请先备份恢复。';
    else if (saved) this.message = saved.round >= 4 ? '这一夜的账已收好。看看客人为何离开，或再开一夜。' : '铺子已回到上次安排，接着开下一段。';
  }
  aboutToDisappear(): void { this.visible = false; }
  private wide(): boolean { return this.widthVp >= 880; }
  private selected(): MarketStall { return this.state.stalls[this.selectedLot] || this.state.stalls[2]; }
  private zone(): number { return Math.floor(this.selectedLot / 2); }
  private dirty(): boolean { return this.editRevision > this.confirmedRevision; }
  private editable(): boolean { return !this.progressDeleted && !this.unreadable && !this.playing && !this.roundSaving && !this.roundNeedsSave && this.state.round < 4; }
  private status(): string {
    if (this.progressDeleted) return '原进度已删除 · 记忆保留';
    if (this.unreadable) return '原存档保留 · 暂停经营';
    if (this.localSaving) return '正在保存安排';
    if (this.dirty()) return '本次安排尚未保存';
    return this.savedAt > 0 ? '已保存在本机' : '尚未开市';
  }
  private receiveRecords(): void {
    this.progressDeleted = riverMarketIsDeleted(this.records);
    if (this.progressDeleted) {
      // 外端墓碑不能因为旧页面仍显示铺子，就被一次普通调人/补货复活。
      // 停止旧局操作与回放，仅允许用户在原生确认框明确开始新的一夜。
      this.incomingState = undefined; this.incomingAvailable = false; this.playing = false;
      this.message = '另一端已删除这座夜市的进度。记忆保留，重新开市需要你的确认。'; return;
    }
    this.unreadable = riverMarketIsUnreadable(this.records);
    if (this.unreadable) { this.message = '收到的夜市存档暂不可读，保留原记录，不写入新局。'; return; }
    const incoming = riverMarketFromRecords(this.records);
    if (!incoming || this.pendingWrites > 0 || this.roundSaving) return;
    // Root提交时会改成真实逻辑时间，不能拿UI动作时间判断dirty。内容一致才把回执时间
    // 接回本页；若是不同内容的外端版本，只提示主动采用，不抢正在安排的夜市。
    if (this.sameArrangement(incoming, this.state)) {
      if (!this.dirty() && incoming.updatedAt >= this.state.updatedAt) {
        this.state = copyRiverMarket(incoming); this.savedAt = incoming.updatedAt;
      }
      this.incomingState = undefined; this.incomingAvailable = false; return;
    }
    if (incoming.updatedAt >= this.savedAt) {
      this.incomingState = copyRiverMarket(incoming); this.incomingAvailable = true;
    }
  }
  private sameArrangement(a: RiverMarketState, b: RiverMarketState): boolean {
    const left = copyRiverMarket(a); const right = copyRiverMarket(b);
    left.updatedAt = 0; right.updatedAt = 0;
    return JSON.stringify(left) === JSON.stringify(right);
  }
  private adoptIncoming(): void {
    if (!this.incomingState || this.pendingWrites > 0 || this.roundSaving || this.dirty() || this.playing) return;
    this.state = copyRiverMarket(this.incomingState); this.savedAt = this.state.updatedAt;
    this.incomingState = undefined; this.incomingAvailable = false;
    this.playbackReport = undefined; this.pendingReport = undefined; this.roundNeedsSave = false;
    this.message = '已采用另一端的夜市安排。';
  }
  private enqueue(state: RiverMarketState, restart: boolean = false): Promise<boolean> {
    const frozen = copyRiverMarket(state); const revision = this.editRevision;
    this.pendingWrites++; this.localSaving = true;
    const task: Promise<boolean> = this.writeQueue.catch(() => {}).then(async (): Promise<boolean> => {
      try {
        const saved = await this.onSaveState(frozen, restart);
        if (saved) {
          this.savedAt = Math.max(this.savedAt, frozen.updatedAt);
          this.confirmedRevision = Math.max(this.confirmedRevision, revision);
        }
        else this.message = '这一版还没存好，当前安排留在画面上。先重试保存。';
        return saved;
      } catch (_error) { this.message = '这一版还没存好，当前安排留在画面上。'; return false; }
      finally {
        this.pendingWrites--; this.localSaving = this.pendingWrites > 0;
        // records的Watch可能在await期间已发生；队列空了必须重看最后那份，
        // 不能永久错过root的逻辑时间回执。旧回执绝不替换后续editRevision的内容。
        if (this.pendingWrites === 0 && !this.roundSaving) this.receiveRecords();
      }
    });
    this.writeQueue = task.then(() => {}); return task;
  }
  private act(action: MarketAction): void {
    if (!this.editable()) return;
    const result = applyMarketAction(this.state, action);
    this.message = result.message;
    if (!result.changed) return;
    this.state = result.state; this.editRevision++; this.memorySaved = false; this.enqueue(result.state);
  }
  private async saveAndPlay(report: MarketRoundReport): Promise<void> {
    this.roundSaving = true;
    const saved = await this.enqueue(this.state); this.roundSaving = false;
    if (this.pendingWrites === 0) this.receiveRecords();
    if (!saved) {
      this.pendingReport = report; this.roundNeedsSave = true;
      this.message = '本段已在画面结算，但尚未保存。重试保存后再回放，不会再扣一次钱。'; return;
    }
    this.pendingReport = undefined; this.roundNeedsSave = false; this.sheetOpen = false;
    this.message = `第${report.round}段已保存：${report.served}客吃上，${report.lost}客离开。`;
    // 领域在上一步已一次结清。先确认整段摘要落盘，再把逐客事件交给只读动画。
    this.playing = !this.reducedMotion; this.playbackReport = report; this.playbackKey++;
  }
  private async openRound(): Promise<void> {
    if (this.progressDeleted) { this.retry(); return; }
    if (this.unreadable || this.playing || this.roundSaving || this.localSaving || this.saving) return;
    if (this.roundNeedsSave && this.pendingReport) { await this.saveAndPlay(this.pendingReport); return; }
    if (this.dirty()) { this.message = '先保存当前安排，再开下一段。'; await this.enqueue(this.state); return; }
    if (this.state.round >= 4) { this.openSheet('ledger'); return; }
    try {
      const next = advanceMarketRound(this.state);
      this.state = next.state; this.editRevision++; this.memorySaved = false; await this.saveAndPlay(next.report);
    } catch (error) { this.message = `本段还没有开始：${(error as Error).message}`; }
  }
  private openSheet(mode: string): void { this.sheetMode = mode; this.sheetOpen = true; }
  private back(): void {
    if (this.localSaving || this.roundSaving) { this.message = '正在把这一版存好，请稍等。'; return; }
    this.onBack();
  }
  private retry(): void {
    if (this.unreadable || this.localSaving || this.roundSaving) return;
    this.getUIContext().showAlertDialog({ title: '再开一夜？', message: '重新安排四段生意。已写进记忆的文字保留。',
      primaryButton: { value: '先看账本', action: () => {} },
      secondaryButton: { value: '重新开市', action: () => {
        this.state = createRiverMarket(Math.max(Date.now(), this.state.updatedAt + 1));
        this.editRevision++;
        this.playing = false; this.playbackReport = undefined; this.pendingReport = undefined;
        this.roundNeedsSave = false; this.memorySaved = false; this.sheetOpen = false;
        this.message = '新的一夜开始了。两铺备好，剩下两位伙计可以另作安排。'; this.enqueue(this.state, true);
      } } });
  }
  private async keepMemory(): Promise<void> {
    if (this.memorySaving || this.localSaving || this.roundSaving || this.roundNeedsSave || this.dirty() || !this.memoryBody.trim()) return;
    this.memorySaving = true;
    try {
      if (await this.onSaveMemory(this.memoryBody.trim(), MARKET_SOURCE_QUOTE, copyRiverMarket(this.state))) {
        this.memorySaved = true; this.sheetOpen = false; this.message = '你写下的这一夜，已收进记忆。';
      } else this.message = '这一页还没保存，文字留在这里。';
    } finally { this.memorySaving = false; }
  }
  private stock(resource: MarketResource): number {
    if (resource === 'rice') return this.state.stock.rice;
    if (resource === 'meat') return this.state.stock.meat;
    if (resource === 'tea') return this.state.stock.tea;
    return this.state.stock.oil;
  }
  private supplyAmount(resource: MarketResource): number {
    if (resource === 'rice') return MARKET_SUPPLIES.rice;
    if (resource === 'meat') return MARKET_SUPPLIES.meat;
    if (resource === 'tea') return MARKET_SUPPLIES.tea;
    return MARKET_SUPPLIES.oil;
  }
  private supplyCost(resource: MarketResource): number {
    if (resource === 'rice') return MARKET_SUPPLY_COSTS.rice;
    if (resource === 'meat') return MARKET_SUPPLY_COSTS.meat;
    if (resource === 'tea') return MARKET_SUPPLY_COSTS.tea;
    return MARKET_SUPPLY_COSTS.oil;
  }
  private latest(): MarketRoundSummary | undefined { return this.state.reports[this.state.reports.length - 1]; }
  private lossHint(): string {
    const last = this.latest();
    if (!last) return '';
    let largest = -1; let count = 0;
    last.reasons.forEach((number: number, index: number) => { if (number > count) { count = number; largest = index; } });
    if (largest < 0) return '上一段来客都吃上了。下一段的需求会变，再看一眼客流。';
    const reason = MARKET_LOSS_REASONS[largest];
    const advice = reason === 'missing' ? '在空地添对应品类' : reason === 'workers' ? '把待分伙计拨给忙铺' :
      reason === 'stock' ? '进缺少的食材' : reason === 'dark' ? '留灯并补足灯油' : '分散开铺，避开拥挤街口';
    return `主要流失：${marketReasonName(reason)} ${count}客。试试${advice}。`;
  }
  private roundButton(): string {
    if (this.progressDeleted) return '重新开市，另起一夜';
    if (this.roundSaving) return '正在保存本段';
    if (this.roundNeedsSave) return '重试保存本段';
    if (this.playing) return '客人正在进街…';
    if (this.dirty()) return '保存当前安排';
    return this.state.round >= 4 ? '翻开收市账本' : `开第${this.state.round + 1}段  ·  ${marketForecast(this.state).arrivals}客将到`;
  }

  @Builder
  header() {
    Row({ space: 9 }) {
      Button('‹', { type: ButtonType.Normal }).width(35).height(35).fontSize(29).fontColor(MARKET_PAPER)
        .backgroundColor(MARKET_PANEL).borderRadius(18).id('market-back').onClick(() => this.back())
      Text('汴京开市').fontSize(19).fontWeight(FontWeight.Medium).fontColor(MARKET_PAPER).letterSpacing(2).layoutWeight(1)
      Button('补货', { type: ButtonType.Normal }).height(32).fontSize(12).fontColor(MARKET_GOLD)
        .backgroundColor(MARKET_PANEL).padding({ left: 12, right: 12 }).borderRadius(16)
        .id('market-supply').onClick(() => this.openSheet('supply'))
      Button('来处', { type: ButtonType.Normal }).height(32).fontSize(12).fontColor(MARKET_MUTED)
        .backgroundColor(Color.Transparent).padding({ left: 5, right: 5 })
        .id('market-culture').onClick(() => this.openSheet('culture'))
    }.width('100%').padding({ left: 14, right: 15, top: 8, bottom: 5 })
  }
  @Builder
  numbers() {
    Column({ space: 5 }) {
      Row({ space: 0 }) {
      Text(`${this.state.cash} 钱`).fontSize(20).fontWeight(FontWeight.Medium).fontColor(MARKET_GOLD).layoutWeight(1).id('market-cash')
      Text(`已接待 ${this.state.served}`).fontSize(14).fontColor(MARKET_PAPER).layoutWeight(1).textAlign(TextAlign.Center).id('market-served')
      Text(`${Math.min(4, this.state.round + 1)} / 4 段`).fontSize(13).fontColor(MARKET_MUTED).layoutWeight(1).textAlign(TextAlign.End).id('market-round')
      }.width('100%')
      Row({ space: 8 }) {
        Text(`目标 ${marketSummary(this.state).targetServed}客 · 余 ${marketSummary(this.state).targetCash}钱`)
          .fontSize(10).fontColor('#C9BD8C').layoutWeight(1).id('market-target')
        Text(`米${this.state.stock.rice}  肉${this.state.stock.meat}  茶${this.state.stock.tea}  油${this.state.stock.oil}`)
          .fontSize(10).fontColor('#A8C2AC').id('market-stock-line')
          .onClick(() => this.openSheet('supply'))
      }.width('100%')
    }.width('100%').padding({ left: 19, right: 19, top: 5, bottom: 8 })
  }
  @Builder
  map() {
    Stack({ alignContent: Alignment.TopStart }) {
      RiverMarketScene({ state: this.state, selectedLot: this.selectedLot, report: this.playbackReport,
        playbackKey: this.playbackKey, active: this.visible && this.playing && !this.sheetOpen, interactive: this.editable(),
        reducedMotion: this.reducedMotion, onSelectLot: (id: number) => { this.selectedLot = id; },
        onPlaybackFinished: () => { this.playing = false; } }).width('100%').height('100%')
      Row() {
        Text(this.playing ? '客人进街了 · 先看本段' : this.state.round >= 4 ? '四段已尽，河岸收市' :
          `${marketForecast(this.state).title}  ·  水饭 ${marketForecast(this.state).preferences[0]}  肉食 ${marketForecast(this.state).preferences[1]}  茶饮 ${marketForecast(this.state).preferences[2]}`)
          .fontSize(10).fontColor('#D8D8B7').lineHeight(17)
      }.padding({ left: 12, right: 12, top: 5, bottom: 5 }).backgroundColor('rgba(15,39,42,0.88)')
        .borderRadius(12).position({ x: 14, y: 8 }).id('market-forecast')
        .onClick(() => this.openSheet('forecast'))
    }.width('100%').height('100%').id('market-scene-frame')
  }
  @Builder
  chip(label: string, id: string, action: () => void, highlighted: boolean = false) {
    Button(label, { type: ButtonType.Normal }).height(33).fontSize(12).fontColor(highlighted ? MARKET_NIGHT : MARKET_PAPER)
      .backgroundColor(highlighted ? MARKET_GOLD : MARKET_PANEL).padding({ left: 12, right: 12 }).borderRadius(9)
      .id(id).onClick(action)
  }
  @Builder
  selection() {
    Column({ space: 7 }) {
      Row({ space: 8 }) {
        Text(`${MARKET_LOTS[this.selectedLot].label} · ${marketStallName(this.selected().type)}`)
          .fontSize(14).fontColor(MARKET_PAPER).fontWeight(FontWeight.Medium).layoutWeight(1).id('market-selected')
        Button(this.state.lamps[this.zone()] ? '灯已留' : '为这街留灯', { type: ButtonType.Normal })
          .height(29).fontSize(11).fontColor(this.state.lamps[this.zone()] ? MARKET_GOLD : MARKET_MUTED)
          .backgroundColor(MARKET_PANEL).padding({ left: 9, right: 9 }).borderRadius(14)
          .enabled(this.editable()).id('market-lamp')
          .onClick(() => this.act({ kind: 'lamp', zone: this.zone(), on: !this.state.lamps[this.zone()] }))
      }.width('100%')
      if (this.selected().type === '') {
        Row({ space: 6 }) {
          ForEach(MARKET_STALL_TYPES, (config: MarketStallConfig) => {
            Button(`${config.name} ${config.buildCost}钱`, { type: ButtonType.Normal }).layoutWeight(1).height(35)
              .fontSize(11).fontColor(MARKET_PAPER).backgroundColor(MARKET_PANEL).borderRadius(8)
              .enabled(this.editable() && this.state.cash >= config.buildCost).id(`market-build-${config.type}`)
              .onClick(() => this.act({ kind: 'build', lotId: this.selectedLot, stallType: config.type }))
          }, (config: MarketStallConfig) => config.type)
        }.width('100%')
      } else {
        Row({ space: 9 }) {
          Button('−', { type: ButtonType.Normal }).width(34).height(33).fontSize(21).fontColor(MARKET_PAPER)
            .backgroundColor(MARKET_PANEL).padding(0).borderRadius(8).enabled(this.editable() && this.selected().workers > 0)
            .id('market-staff-minus').onClick(() => this.act({ kind: 'staff', lotId: this.selectedLot, delta: -1 }))
          Text(`${this.selected().workers} 伙计`).fontSize(14).fontColor(MARKET_PAPER).id('market-selected-workers')
          Button('+', { type: ButtonType.Normal }).width(34).height(33).fontSize(20).fontColor(MARKET_PAPER)
            .backgroundColor(MARKET_PANEL).padding(0).borderRadius(8).enabled(this.editable() && marketSummary(this.state).freeWorkers > 0)
            .id('market-staff-plus').onClick(() => this.act({ kind: 'staff', lotId: this.selectedLot, delta: 1 }))
          Text(`待分 ${marketSummary(this.state).freeWorkers} 人`).fontSize(10).fontColor(MARKET_MUTED).layoutWeight(1)
          Button('收铺', { type: ButtonType.Normal }).height(30).fontSize(11).fontColor('#C4967A')
            .backgroundColor(Color.Transparent).padding(0).enabled(this.editable()).id('market-demolish')
            .onClick(() => this.act({ kind: 'demolish', lotId: this.selectedLot }))
        }.width('100%')
      }
    }.width('100%').padding({ left: 17, right: 17, top: 10, bottom: 8 }).backgroundColor('#142F34')
  }
  @Builder
  controls() {
    Column({ space: 6 }) {
      if (this.state.round < 4) { this.selection() } else {
        Column({ space: 4 }) {
          Text(marketSummary(this.state).title).fontSize(18).fontColor(MARKET_GOLD).width('100%').id('market-closing-title')
          Text(`接待 ${this.state.served}/100 客，收市 ${this.state.cash} 钱。${marketSummary(this.state).detail}`)
            .fontSize(12).fontColor(MARKET_MUTED).lineHeight(19).width('100%')
        }.width('100%').padding({ left: 18, right: 18, top: 12, bottom: 8 })
      }
      if (this.latest()) {
        Button(`上一段 ${this.latest()!.served}/${this.latest()!.arrivals}客吃上  ·  ${this.latest()!.lost}客离开  查看去向 ›`,
          { type: ButtonType.Normal }).width('100%').height(27).fontSize(11).fontColor('#D8C99E')
          .backgroundColor(Color.Transparent).padding({ left: 18, right: 18 }).id('market-report-open')
          .onClick(() => this.openSheet('ledger'))
      }
      Text(this.latest() && !this.dirty() && !this.roundNeedsSave && !this.progressDeleted && !this.unreadable && !this.localSaving ?
        this.lossHint() : this.message).fontSize(11).fontColor(this.dirty() ? '#DEA284' : MARKET_MUTED).lineHeight(17)
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        .padding({ left: 18, right: 18 }).id('market-feedback')
      if (this.incomingAvailable) {
        Button(this.dirty() || this.localSaving ? '另一端有新安排，先保存本次修改' : '采用另一端的夜市安排',
          { type: ButtonType.Normal }).height(29).fontSize(11).fontColor(MARKET_GOLD)
          .backgroundColor(Color.Transparent).enabled(!this.dirty() && !this.localSaving && !this.roundSaving && !this.playing)
          .id('market-adopt-incoming').onClick(() => this.adoptIncoming())
      }
      Button(this.roundButton(), { type: ButtonType.Normal }).height(46).width('92%')
        .fontSize(16).fontWeight(FontWeight.Medium).fontColor(MARKET_NIGHT).backgroundColor(MARKET_GOLD).borderRadius(6)
        .enabled(!this.unreadable && !this.localSaving && !this.roundSaving && !this.playing && !this.saving)
        .id('market-open-round').onClick(() => { this.openRound(); })
      if (this.state.round >= 4) {
        Row({ space: 20 }) {
          this.chip('再开一夜', 'market-retry', () => this.retry())
          this.chip(this.memorySaved ? '已写进记忆' : '记下今夜', 'market-write', () => this.openSheet('memory'))
        }.width('100%').justifyContent(FlexAlign.Center).padding({ top: 2, bottom: 4 })
      }
      Text(this.status()).fontSize(9).fontColor('#78978D').width('100%').textAlign(TextAlign.Center).id('market-save-state')
    }.width('100%').padding({ bottom: 9 }).backgroundColor(MARKET_NIGHT)
  }

  @Builder
  forecastContent() {
    Column({ space: 14 }) {
      Text(marketForecast(this.state).title).fontSize(24).fontWeight(FontWeight.Medium).fontColor('#263D39').width('100%')
      Text(`将来 ${marketForecast(this.state).arrivals} 客：水饭 ${marketForecast(this.state).preferences[0]}，肉食 ${marketForecast(this.state).preferences[1]}，茶饮 ${marketForecast(this.state).preferences[2]}。`)
        .fontSize(15).lineHeight(25).fontColor('#456053').width('100%')
      ForEach([0, 1, 2], (zone: number) => {
        Row() {
          Text(`${MARKET_ZONE_NAMES[zone]} · 来客 ${marketForecast(this.state).zoneArrivals[zone]} · 通行 ${marketForecast(this.state).laneCapacity[zone]}`)
            .fontSize(13).fontColor('#3E574A').layoutWeight(1)
          Button(this.state.lamps[zone] ? '留灯' : '未留灯', { type: ButtonType.Normal }).fontSize(12).height(34)
            .fontColor('#5D5939').backgroundColor(this.state.lamps[zone] ? '#E4C78B' : '#DCE1CE').borderRadius(12)
            .enabled(this.editable()).id(`market-zone-lamp-${zone}`)
            .onClick(() => this.act({ kind: 'lamp', zone, on: !this.state.lamps[zone] }))
        }.width('100%').padding({ top: 9, bottom: 9 }).border({ width: { bottom: 1 }, color: '#D4D3BD' })
        if (this.state.lamps[zone] && !marketForecast(this.state).effectiveLamps[zone]) {
          Text(`${MARKET_ZONE_NAMES[zone]}虽留了灯，但当前灯油不足，下一段实际不会点亮。`)
            .fontSize(11).fontColor('#A1764C').lineHeight(19).width('100%')
        }
      }, (zone: number) => `${zone}:${this.state.lamps[zone]}`)
      Text(marketForecast(this.state).detail).fontSize(13).fontColor('#697665').lineHeight(23).width('100%')
      Text(`本段预计工资 ${marketForecast(this.state).wages}，铺租 ${marketForecast(this.state).rent}，留灯需油 ${marketForecast(this.state).oilNeeded}。`)
        .fontSize(12).fontColor('#7E765C').lineHeight(21).width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder
  supplies() {
    Column({ space: 15 }) {
      Text('码头补货').fontSize(24).fontWeight(FontWeight.Medium).fontColor('#263D39').width('100%')
      Text(`每段只走两趟，本段还可 ${Math.max(0, 2 - this.state.supplyTrips)} 趟。余钱 ${this.state.cash}。`)
        .fontSize(13).fontColor('#657B67').lineHeight(22).width('100%').id('market-supply-trips')
      ForEach(this.supplyRows, (row: MarketSupplyRow) => {
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text(`${row.name}  ${this.stock(row.resource)}`).fontSize(17).fontColor('#304E41')
            Text(`一趟 +${this.supplyAmount(row.resource)} · 花 ${this.supplyCost(row.resource)}钱`)
              .fontSize(11).fontColor('#778168')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Button('进一趟', { type: ButtonType.Normal }).height(38).fontSize(13).fontColor('#294D42')
            .backgroundColor('#D9DAB8').borderRadius(12)
            .enabled(this.editable() && this.state.supplyTrips < 2 && this.state.cash >= this.supplyCost(row.resource))
            .id(`market-buy-${row.resource}`).onClick(() => this.act({ kind: 'buy', resource: row.resource }))
        }.width('100%').padding({ top: 14, bottom: 14 }).border({ width: { bottom: 1 }, color: '#D4D3BD' })
      }, (row: MarketSupplyRow) => row.resource)
      Text(this.message).fontSize(12).fontColor('#837451').lineHeight(21).width('100%')
      Button('看下一段客流与街灯 →', { type: ButtonType.Normal }).width('100%').height(42)
        .fontColor('#315848').backgroundColor('#E2E1C8').borderRadius(10).onClick(() => { this.sheetMode = 'forecast'; })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder
  ledger() {
    Column({ space: 15 }) {
      Text(this.state.round >= 4 ? '四段收市账本' : '这一段，客人去了哪里').fontSize(23).fontWeight(FontWeight.Medium)
        .fontColor('#263D39').width('100%')
      ForEach(this.state.reports, (report: MarketRoundSummary) => {
        Column({ space: 9 }) {
          Text(`第${report.round}段 · 接待 ${report.served}/${report.arrivals}`).fontSize(17).fontColor('#305243').width('100%')
          Text(`进账 ${report.income}，工资 ${report.wages}，支出 ${report.expenses}，余钱 ${report.cashAfter}`)
            .fontSize(12).fontColor('#778168').width('100%')
          ForEach(MARKET_LOSS_REASONS, (reason: MarketVisitReason, index: number) => {
            if (report.reasons[index] > 0) {
              Row() {
                Text(marketReasonName(reason)).fontSize(13).fontColor('#8B634B').layoutWeight(1)
                Text(`${report.reasons[index]} 客`).fontSize(13).fontColor('#8B634B')
              }.width('100%')
            }
          }, (reason: MarketVisitReason) => reason)
        }.width('100%').padding(15).backgroundColor('#FFFAE8').borderRadius(10)
      }, (report: MarketRoundSummary) => `${report.round}`)
      if (this.playbackReport) {
        Text('刚才的客人，进了这些铺子').fontSize(15).fontColor('#4D6752').width('100%')
        ForEach(MARKET_LOTS, (lot: MarketLot) => {
          if (this.playbackReport!.servedByLot[lot.id] > 0) {
            Row() {
              // 铺名取结算时的类型快照：收市后收铺或改建，不能让历史接待
              // 变成“空地接待 N 客”或挂到新铺子名下。
              Text(`${lot.label} · ${marketStallName(this.playbackReport!.stallTypes[lot.id])}`)
                .fontSize(13).fontColor('#5D715B').layoutWeight(1)
              Text(`${this.playbackReport!.servedByLot[lot.id]} 客`).fontSize(13).fontColor('#876740')
            }.width('100%')
          }
        }, (lot: MarketLot) => `${lot.id}`)
        ForEach(this.playbackReport!.advice, (advice: string) => {
          Text(advice).fontSize(13).lineHeight(23).fontColor('#62735C').width('100%')
        }, (advice: string) => advice)
      }
      if (this.state.round >= 4) {
        Text(marketSummary(this.state).title).fontSize(20).fontColor('#A0703E').width('100%')
        Text(marketSummary(this.state).detail).fontSize(13).fontColor('#6B775F').width('100%')
        Button('再开一夜', { type: ButtonType.Normal }).height(44).width('100%').fontColor('#294A3F')
          .backgroundColor('#D6DDBE').borderRadius(10).id('market-ledger-retry').onClick(() => this.retry())
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder
  culture() {
    Column({ space: 15 }) {
      Text('这条河岸，从哪里来').fontSize(24).fontWeight(FontWeight.Medium).fontColor('#263D39').width('100%')
      Text(`「${MARKET_SOURCE_QUOTE}」`).fontSize(20).fontColor('#94714B').lineHeight(33).width('100%')
      ForEach(MARKET_SOURCES, (source: RiverMarketSource) => {
        Column({ space: 7 }) {
          Text(source.title).fontSize(15).fontColor('#305243').width('100%')
          Text(source.era).fontSize(11).fontColor('#9B7751').width('100%')
          Text(source.quote).fontSize(13).lineHeight(22).fontColor('#5D715E').width('100%')
          Text(source.url).fontSize(10).fontColor('#88927A').width('100%').copyOption(CopyOptions.LocalDevice)
        }.width('100%').padding(14).backgroundColor('#FFFAE8').borderRadius(10)
      }, (source: RiverMarketSource) => source.title)
      Text(MARKET_CULTURE_BOUNDARY).fontSize(12).fontColor('#7A8069').lineHeight(22).width('100%')
      Text('孟元老于南宋追记北宋东京生活。材料初稿待校审；本页短引的卷次分别保留，不以游戏客流替代历史证据。')
        .fontSize(11).fontColor('#879076').lineHeight(20).width('100%')
      Button('读州桥文化档案 →', { type: ButtonType.Normal }).width('100%').height(43).fontColor('#315848')
        .backgroundColor('#DDE2C8').borderRadius(10).id('market-original-content')
        .onClick(() => { this.sheetOpen = false; this.onOpenContent('kf-zhouqiao'); })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder
  memory() {
    Column({ space: 16 }) {
      Text('记下这一夜').fontSize(24).fontWeight(FontWeight.Medium).fontColor('#263D39').width('100%')
      Text(`四段接待 ${this.state.served} 客，余钱 ${this.state.cash}。你会怎么形容这一夜？`)
        .fontSize(14).fontColor('#62735C').lineHeight(24).width('100%')
      TextArea({ text: this.memoryBody, placeholder: '写下自己作过的取舍，或下一夜想换一种安排。' })
        .height(145).fontColor('#305243').fontSize(15).backgroundColor('#FFFAE8').borderRadius(12)
        .maxLength(4000).id('market-memory-body').onChange((body: string) => { this.memoryBody = body; })
      Text(`出处短引：“${MARKET_SOURCE_QUOTE}”`).fontSize(12).lineHeight(21).fontColor('#8C7A55').width('100%')
      Button(this.memorySaving ? '正在收进记忆' : '确认保存我的文字', { type: ButtonType.Normal })
        .width('100%').height(44).fontColor('#FFF5D9').backgroundColor('#3D6654').borderRadius(11)
        .enabled(!this.memorySaving && !!this.memoryBody.trim()).id('market-memory-save')
        .onClick(() => { this.keepMemory(); })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder
  sheet() {
    Column() {
      Row() {
        Text('汴京开市').fontSize(12).fontColor('#72816A').layoutWeight(1)
        Button('关闭', { type: ButtonType.Normal }).height(32).fontSize(12).fontColor('#3D5A48')
          .backgroundColor('#E5E4CD').borderRadius(16).id('market-sheet-close').onClick(() => { this.sheetOpen = false; })
      }.width('100%').padding({ left: 20, right: 18, top: 12, bottom: 10 })
      Scroll() {
        Column() {
          if (this.sheetMode === 'supply') { this.supplies() }
          else if (this.sheetMode === 'forecast') { this.forecastContent() }
          else if (this.sheetMode === 'ledger') { this.ledger() }
          else if (this.sheetMode === 'memory') { this.memory() }
          else { this.culture() }
        }.width('100%').padding({ left: 20, right: 20, top: 4, bottom: 28 })
      }.width('100%').layoutWeight(1).align(Alignment.TopStart).scrollBar(BarState.Off).id('market-sheet-scroll')
    }.width('100%').height('100%').backgroundColor('#F2EEDB')
  }
  @Builder
  playArea() {
    Column() {
      this.numbers()
      Column() { this.map() }.width('100%').layoutWeight(1).constraintSize({ minHeight: 210 })
      this.controls()
    }.width('100%').height('100%')
  }

  build() {
    NavDestination() {
      Column() {
        this.header()
        if (this.wide()) {
          Row() {
            Column() { this.playArea() }.layoutWeight(1.8).height('100%')
            Scroll() {
              if (this.state.round >= 4) { this.ledger() } else { this.forecastContent() }
            }
              .layoutWeight(1).height('100%').padding(23).backgroundColor('#F2EEDB').scrollBar(BarState.Off)
              .id('market-wide-notes')
          }.width('100%').layoutWeight(1).alignItems(VerticalAlign.Top)
        } else {
          Column() { this.playArea() }.width('100%').layoutWeight(1)
        }
      }.width('100%').height('100%').backgroundColor(MARKET_NIGHT).id('river-market-page')
        .onAreaChange((_old: Area, area: Area) => { this.widthVp = Number(area.width); })
    }.hideTitleBar(true).backgroundColor(MARKET_NIGHT)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .systemBarStyle({ statusBarContentColor: '#FFF2E6C9' })
      .onShown(() => { this.visible = true; setPaperWindowText(this.getUIContext(), '#F2E6C9'); })
      .onHidden(() => { this.visible = false; })
      // API26平板默认居中Sheet，RESIZE_ONLY实测会把输入框留在键盘后而无法回读。
      // 让系统先平移再缩放，正文从Scroll顶部排起，键盘出现后仍可编辑与确认自己的文字。
      .bindSheet($$this.sheetOpen, this.sheet(), { height: SheetSize.LARGE, showClose: false, dragBar: true,
        keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_RESIZE })
      .onBackPressed(() => {
        if (this.sheetOpen) { this.sheetOpen = false; return true; }
        this.back(); return true;
      })
  }
}
