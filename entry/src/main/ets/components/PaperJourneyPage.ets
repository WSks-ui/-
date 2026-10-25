import { SelectionContainer, SelectionContainerAttribute, SelectionContainerController,
  SelectionContainerTextJoinStyle } from '@kit.ArkUI';
import { unifiedDataChannel } from '@kit.ArkData';
import type { ArchiveRecord } from '../domain/ArchiveDomain';
import { PaperAction, PaperFold, PaperJudgment, PaperPoint, PaperWorkV1, PAPER_PALETTE,
  copyPaperWork, createPaperWork, cutPaperStroke, judgePaper, setPaperColor, setPaperFold,
  togglePaperLight, undoPaper } from '../domain/PaperJourney';
import { paperWorkFromRecords, paperWorkIsUnreadable } from '../domain/PaperJourneyRecords';
import { PaperMemoryContext, PaperMemorySource } from '../domain/PaperMemory';
import { PAPER_CITIES, PaperCity, PaperSource } from '../data/PaperJourneyCatalog';
import { PaperJourneyScene } from './PaperJourneyScene';

const NIGHT: string = '#101F26';
const PANEL: string = '#1B3037';
const PAPER: string = '#F5EFDF';
const GOLD: string = '#E9B17D';
const MUTED: string = '#A6B9B7';
interface PaperExcerptTransfer { version: number; cityId: string; excerpt: string; }

@Component
export struct PaperJourneyPage {
  @Prop cityId: string = 'paper-smx';
  @Prop @Watch('receiveRecords') records: ArchiveRecord[] = [];
  @Prop reducedMotion: boolean = false;
  @Prop saving: boolean = false;
  onSaveWork: (work: PaperWorkV1) => Promise<boolean> = async () => false;
  onSaveMemory: (context: PaperMemoryContext, body: string) => Promise<boolean> = async () => false;
  onOpenContent: (siteId: string) => void = () => {};
  onBack: () => void = () => {};
  @State private work: PaperWorkV1 = createPaperWork('paper-smx', 0);
  @State private unfolded: boolean = true;
  @State private showGuide: boolean = true;
  // 只切换当前手势的观察方式，不写 work.light、progress 或已保存的记忆快照。
  @State private observationMode: boolean = false;
  @State private containerWidth: number = 360;
  @State private message: string = '沿纸面划一剪，看看光从哪里进来。';
  @State private localSaving: boolean = false;
  @State private unsaved: boolean = false;
  @State private unreadable: boolean = false;
  @State private savedAt: number = 0;
  @State private sheetOpen: boolean = false;
  @State private sheetMode: string = 'culture';
  @State private body: string = '';
  @State private memorySaved: boolean = false;
  @State private brush: number = 1.15;
  @State private hintOpen: boolean = false;
  @State private selectedText: string = '';
  @State private excerptCard: string = '';
  @State private chosenExcerpt: string = '';
  private selectionController: SelectionContainerController = new SelectionContainerController();
  private writeQueue: Promise<void> = Promise.resolve();
  private pendingWrites: number = 0;
  private writingMemory: boolean = false;
  private judgmentMask: string = '';
  private judgmentCity: string = '';
  private cachedJudgment: PaperJudgment | undefined = undefined;

  // 判断只由城市与展开 mask 决定；保存状态、Sheet/键盘、光位与文案变化不应反复遍历纸面。
  // 任何新剪口、撤销、换纸或接收新版本都会更换 mask，因此仍按真实作品失效。
  private judgment(): PaperJudgment {
    if (!this.cachedJudgment || this.judgmentMask !== this.work.mask || this.judgmentCity !== this.work.cityId) {
      this.cachedJudgment = judgePaper(this.work);
      this.judgmentMask = this.work.mask; this.judgmentCity = this.work.cityId;
    }
    return this.cachedJudgment;
  }

  aboutToAppear(): void {
    this.unreadable = paperWorkIsUnreadable(this.records, this.cityId);
    const saved = paperWorkFromRecords(this.records, this.cityId);
    this.work = saved || createPaperWork(this.cityId, Date.now());
    this.savedAt = saved?.updatedAt || 0;
    if (this.unreadable) this.message = '这张纸的存档暂时无法读取，原记录已保留。请先在数据与存储中备份并恢复可读版本。';
    else if (saved) this.message = '这张纸已回到上次的剪口。可以接着剪，也可以先展开。';
  }

  private city(): PaperCity { return PAPER_CITIES.find(city => city.id === this.cityId) || PAPER_CITIES[0]; }
  private wide(): boolean { return this.containerWidth >= 900; }

  private receiveRecords(): void {
    this.unreadable = paperWorkIsUnreadable(this.records, this.cityId);
    if (this.unreadable) {
      this.message = '这张纸的存档暂时无法读取，原记录已保留。请先备份并恢复可读版本。';
      return;
    }
    const incoming = paperWorkFromRecords(this.records, this.cityId);
    // 正在连续剪纸时不让早一笔的回包覆盖新一笔。跨端的新版本只在本机没有
    // 待落盘动作时更新；这里展示的“已保存”来自实际commit回执。
    if (!incoming || this.pendingWrites > 0 || incoming.updatedAt <= this.work.updatedAt) return;
    if (incoming.mask === this.work.mask && incoming.fold === this.work.fold && incoming.light === this.work.light &&
      incoming.paper === this.work.paper) {
      this.work = copyPaperWork(incoming);
      this.savedAt = incoming.updatedAt;
      return;
    }
    this.work = copyPaperWork(incoming);
    this.savedAt = incoming.updatedAt;
    this.message = '已收到这张纸的新版本，剪口与纸色一起恢复。';
  }

  private apply(action: PaperAction): void {
    // 已有损坏记录不能被“新空纸”的下一剪替换；Index提交处还会核对最新版本。
    if (this.unreadable) return;
    this.message = action.message;
    if (!action.changed) return;
    this.work = action.work;
    this.memorySaved = false;
    this.unsaved = true;
    const frozen = copyPaperWork(action.work);
    this.pendingWrites++;
    this.localSaving = true;
    // 手势结束只提交一次，按用户动作排队；真正写入时由Index读取最新共享快照，
    // 不保存旧整库副本，也不在每个Canvas帧写Preferences。
    this.writeQueue = this.writeQueue.catch(() => {}).then(async (): Promise<void> => {
      try {
        const saved = await this.onSaveWork(frozen);
        if (saved) { this.savedAt = frozen.updatedAt; this.unsaved = false; }
        else { this.unsaved = true; this.message = '这一剪还没有存好，先保留在画面上。可以稍后再试。'; }
      } catch (_error) {
        this.unsaved = true;
        this.message = '这一剪还没有存好，先保留在画面上。可以稍后再试。';
      } finally {
        this.pendingWrites--;
        this.localSaving = this.pendingWrites > 0;
        if (this.pendingWrites === 0 && !this.unsaved) this.receiveRecords();
      }
    });
  }

  private cut(points: PaperPoint[]): void {
    this.apply(cutPaperStroke(this.work, points, this.brush));
  }

  private fold(value: PaperFold): void {
    this.apply(setPaperFold(this.work, value));
    this.unfolded = value === 'none';
  }

  private freshPaper(): void {
    if (this.unreadable) return;
    this.getUIContext().showAlertDialog({ title: '换一张新纸？',
      message: '当前剪口会收起。已经存进记忆的纸景与文字会保留。',
      primaryButton: { value: '接着这一张', action: () => {} },
      secondaryButton: { value: '换新纸', action: () => {
        const next = createPaperWork(this.cityId, Math.max(this.work.updatedAt + 1, Date.now()));
        // 保留曾成立的作品状态，不把新空纸算已完成，也不改写任何已存note。
        next.completedAt = this.work.completedAt; next.completedMask = this.work.completedMask;
        next.completedPaper = this.work.completedPaper;
        this.apply({ work: next, changed: true, message: '新纸展开了。之前收进记忆的作品还在。' });
        this.unfolded = true;
      } } });
  }

  private openSheet(mode: string): void {
    this.sheetMode = mode;
    this.sheetOpen = true;
  }

  private async saveMemory(): Promise<void> {
    if (this.unreadable || this.writingMemory || this.localSaving || this.saving) return;
    this.writingMemory = true;
    // 保留当次实际剪口；不是拿历史完成图替换当前作品，也不把目标文字写成用户感想。
    const work = copyPaperWork(this.work);
    work.history = [];
    const city = this.city();
    const context: PaperMemoryContext = { version: 1, cityId: city.id, title: city.title,
      culture: city.culture, work, sources: city.sources.map((source: PaperSource): PaperMemorySource => ({
        id: source.id, title: source.title, url: source.url, quote: source.quote,
        era: source.era, accessedAt: source.accessedAt
      })) };
    if (this.chosenExcerpt) context.excerpt = this.chosenExcerpt;
    const saved = await this.onSaveMemory(context, this.body.trim());
    this.writingMemory = false;
    if (saved) {
      this.memorySaved = true;
      this.sheetOpen = false;
      this.message = '这一剪和你的话已收进记忆，之后重剪不会改掉这一页。';
      this.getUIContext().getPromptAction().showToast({ message: '纸景已存入记忆' });
    } else this.message = '还没有存入记忆，文字和剪口都留在这里。';
  }

  private createExcerpt(): void {
    if (!this.selectedText.trim()) return;
    this.excerptCard = this.selectedText.trim().slice(0, 1800);
    try { this.selectionController.closeSelectionMenu(); } catch (_error) {}
  }

  private startExcerptDrag(event: DragEvent): DragItemInfo {
    const payload: PaperExcerptTransfer = { version: 1, cityId: this.cityId, excerpt: this.excerptCard };
    const text = new unifiedDataChannel.PlainText();
    text.textContent = JSON.stringify(payload); text.abstract = '云河纪 · 文化摘录';
    event.setData(new unifiedDataChannel.UnifiedData(text));
    return { extraInfo: 'paper-cultural-excerpt-v1' };
  }

  private dropExcerpt(event: DragEvent): void {
    try {
      for (const record of event.getData().getRecords()) {
        if (record.getType() !== 'general.plain-text') continue;
        const value = JSON.parse((record as unifiedDataChannel.PlainText).textContent) as PaperExcerptTransfer;
        // 仅把本篇本次生成的摘录卡标为带出处，外部任意文本不能冒充已核材料。
        if (value.version !== 1 || value.cityId !== this.cityId || typeof value.excerpt !== 'string' ||
          !value.excerpt || value.excerpt !== this.excerptCard) continue;
        this.chosenExcerpt = value.excerpt;
        this.message = '摘录已放进记忆草稿，还要由你确认保存。';
        event.setResult(DragResult.DRAG_SUCCESSFUL); return;
      }
    } catch (_error) {}
    event.setResult(DragResult.DRAG_FAILED);
  }

  @Builder
  header() {
    Row({ space: 10 }) {
      Button('‹', { type: ButtonType.Normal }).width(42).height(42).fontSize(30)
        .fontColor(PAPER).backgroundColor(PANEL).borderRadius(21).id('paper-back')
        .accessibilityText('返回漫游').onClick(() => this.onBack())
      Column({ space: 2 }) {
        Text(`${this.city().city}  /  纸上生城`).fontSize(11).fontColor(GOLD).letterSpacing(1)
        Text(this.city().title).fontSize(18).fontWeight(FontWeight.Bold).fontColor(PAPER).maxLines(1)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Button('资料', { type: ButtonType.Normal }).height(38).fontSize(13).fontColor(PAPER)
        .backgroundColor(PANEL).borderRadius(19).padding({ left: 13, right: 13 })
        .id('paper-culture').onClick(() => this.openSheet('culture'))
    }.width('100%').padding({ left: 14, right: 14, top: 10, bottom: 8 })
  }

  @Builder
  challenge() {
    Column({ space: 5 }) {
      Row({ space: 7 }) {
        Text(this.judgment().passed ? '这一页成立了' : '试着这样剪')
          .fontSize(11).fontColor(GOLD).letterSpacing(1).layoutWeight(1).id('paper-goal-state')
        Text(this.unreadable ? '原存档受保护' : this.localSaving ? '正在保存' : this.unsaved ? '这一剪尚未保存' : this.savedAt > 0 ? '已保存在本机' : '自由尝试')
          .fontSize(10).fontColor(MUTED).id('paper-save-state')
      }.width('100%')
      Text(this.city().goal).fontSize(14).lineHeight(21).fontColor(PAPER).width('100%').id('paper-goal')
      if (this.hintOpen) {
        Text(this.city().hint).fontSize(12).lineHeight(19).fontColor(GOLD).width('100%').id('paper-hint-body')
      }
    }.width('100%').padding({ left: 18, right: 18, top: 6, bottom: 8 })
  }

  @Builder
  smallButton(label: string, active: boolean, id: string, action: () => void) {
    Button(label, { type: ButtonType.Normal }).height(38).layoutWeight(1).fontSize(12)
      .fontColor(active ? NIGHT : MUTED).backgroundColor(active ? GOLD : PANEL).borderRadius(11)
      .id(id).onClick(action)
  }

  @Builder
  tools() {
    Column({ space: 8 }) {
      Row({ space: 7 }) {
        this.smallButton('平纸', this.work.fold === 'none', 'paper-fold-none', () => this.fold('none'))
        this.smallButton('对折', this.work.fold === 'mirror', 'paper-fold-mirror', () => this.fold('mirror'))
        this.smallButton('四折', this.work.fold === 'quarter', 'paper-fold-quarter', () => this.fold('quarter'))
        Button('↶', { type: ButtonType.Normal }).width(42).height(38).fontSize(23).fontColor(PAPER)
          .backgroundColor(PANEL).borderRadius(11).id('paper-undo').enabled(this.work.history.length > 0)
          .accessibilityText('撤回上一剪').onClick(() => this.apply(undoPaper(this.work)))
      }.width('100%')
      Row({ space: 8 }) {
        Button(this.hintOpen ? '收起提示' : '不知道从哪剪？', { type: ButtonType.Normal }).height(28).fontSize(11)
          .fontColor(MUTED).backgroundColor(Color.Transparent).padding(0).id('paper-hint')
          .onClick(() => { this.hintOpen = !this.hintOpen; })
        Blank()
        Button('换张纸', { type: ButtonType.Normal }).height(28).fontSize(11).fontColor(MUTED)
          .backgroundColor(Color.Transparent).padding(0).id('paper-fresh').onClick(() => this.freshPaper())
        Button(this.showGuide ? '藏起剪法线索' : '看看剪法线索', { type: ButtonType.Normal }).height(28).fontSize(11)
          .fontColor(MUTED).backgroundColor(Color.Transparent).padding(0).id('paper-guide')
          .onClick(() => { this.showGuide = !this.showGuide; })
      }.width('100%')
      Row({ space: 9 }) {
        ForEach(PAPER_PALETTE, (color: string) => {
          Button({ type: ButtonType.Normal }) { Circle().width(20).height(20).fill(color) }
            .width(32).height(34).backgroundColor(Color.Transparent).borderRadius(10)
            .border({ width: this.work.paper === color ? 1 : 0, color: PAPER })
            .id(`paper-color-${PAPER_PALETTE.indexOf(color)}`)
            .accessibilityText(`纸色${PAPER_PALETTE.indexOf(color) + 1}`)
            .onClick(() => this.apply(setPaperColor(this.work, color)))
        }, (color: string) => color)
        Blank()
        Button(this.brush > 1.5 ? '宽剪' : '细剪', { type: ButtonType.Normal }).height(34).fontSize(11)
          .fontColor(MUTED).backgroundColor(PANEL).padding({ left: 10, right: 10 }).borderRadius(10)
          .id('paper-brush').onClick(() => { this.brush = this.brush > 1.5 ? 1.15 : 2.0; })
        Button(this.work.light ? '收光' : '透光', { type: ButtonType.Normal }).height(34).fontSize(12)
          .fontColor(this.work.light ? NIGHT : PAPER).backgroundColor(this.work.light ? GOLD : PANEL)
          .padding({ left: 11, right: 11 }).borderRadius(10).id('paper-light')
          .onClick(() => this.apply(togglePaperLight(this.work)))
      }.width('100%')
      Button(this.observationMode ? '回到剪纸' : '移光看纸景', { type: ButtonType.Normal })
        .height(32).width('100%').fontSize(12)
        .fontColor(this.observationMode ? NIGHT : GOLD).backgroundColor(this.observationMode ? GOLD : PANEL)
        .borderRadius(10).id('paper-observe-light')
        .accessibilityText(this.observationMode ? '回到剪纸，拖动恢复剪切' : '移光看纸景，拖动只改变光源位置')
        .onClick(() => { this.observationMode = !this.observationMode; })
    }.width('100%').padding({ left: 16, right: 16, top: 5, bottom: 7 })
  }

  @Builder
  feedback() {
    Column({ space: 5 }) {
      Text(this.observationMode ? this.judgment().cutRatio > 0 ?
        '拖动光点，看剪口投下的光斑与纸边阴影；回到剪纸后再继续剪。' :
        '这张纸还没有剪口。回到剪纸留下几剪，再移光看自己的光影。' : this.message)
        .fontSize(12).lineHeight(18).fontColor(PAPER).maxLines(2).width('100%').id('paper-feedback')
      if (this.judgment().cutRatio > 0) {
        Text(this.judgment().detail).fontSize(11).lineHeight(17).fontColor(MUTED).maxLines(2).width('100%')
          .id('paper-judgment')
      } else {
        Text('用指尖划剪 · 随时撤回 · 每个人都能留下不同的形状')
          .fontSize(11).fontColor(MUTED).width('100%')
      }
      if (this.judgment().passed) {
        Text(this.city().insight).fontSize(12).lineHeight(19).fontColor(GOLD).width('100%').maxLines(3).id('paper-insight')
      }
    }.width('100%').padding({ left: 18, right: 18, top: 4, bottom: 8 })
  }

  @Builder
  bottomActions() {
    Row({ space: 9 }) {
      Button(this.work.fold === 'none' ? '对折试一剪' : this.unfolded ? '折起来看' : '展开这一页',
        { type: ButtonType.Normal }).height(46).layoutWeight(1)
        .fontSize(14).fontColor(PAPER).backgroundColor(PANEL).borderRadius(14).id('paper-unfold')
        .onClick(() => { if (this.work.fold === 'none') this.fold('mirror'); else this.unfolded = !this.unfolded; })
      Button(this.memorySaved ? '已收进记忆' : '留下我的纸景', { type: ButtonType.Normal })
        .height(46).layoutWeight(1.2).fontSize(14).fontWeight(FontWeight.Medium)
        .fontColor(NIGHT).backgroundColor(GOLD).borderRadius(14).id('paper-keep')
        .enabled(this.judgment().cutRatio > 0 && !this.localSaving)
        .onClick(() => this.openSheet('memory'))
    }.width('100%').padding({ left: 16, right: 16, top: 4, bottom: 12 })
  }

  @Builder
  cultureContent() {
    Column({ space: 15 }) {
      Text('这一剪，从哪里来').fontSize(23).fontWeight(FontWeight.Bold).fontColor('#203A3D').width('100%')
      Text(this.city().culture).fontSize(14).lineHeight(23).fontColor('#51666A').width('100%')
      SelectionContainer({ controller: this.selectionController }) {
      Column({ space: 15 }) {
      ForEach(this.city().sources, (source: PaperSource) => {
        Column({ space: 6 }) {
          Text(source.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#203A3D').width('100%')
          Text(source.era).fontSize(11).fontColor('#9C654B').width('100%')
          Text(source.quote).fontSize(14).lineHeight(23).fontColor('#40575A').width('100%')
          Text(source.url).fontSize(10).fontColor('#78898A').lineHeight(16).width('100%')
            .copyOption(CopyOptions.LocalDevice)
        }.width('100%').padding(16).backgroundColor('#FFFCF3').borderRadius(14)
      }, (source: PaperSource) => source.id)
      }.width('100%')
      }.width('100%').copyOption(CopyOptions.InApp).textJoinStyle(SelectionContainerTextJoinStyle.NEWLINE)
        .onTextSelectionChange((paragraphs: string[]) => { this.selectedText = paragraphs.filter(text => !!text).join('\n'); })
        .editMenuOptions({
          onCreateMenu: (items: TextMenuItem[]): TextMenuItem[] => {
            const next = items.filter(item => item.id.equals(TextMenuItemId.COPY) || item.id.equals(TextMenuItemId.SELECT_ALL));
            next.push({ content: '做成摘录', id: TextMenuItemId.of('paper-excerpt') }); return next;
          },
          onMenuItemClick: (item: TextMenuItem, selected: string): boolean => {
            if (!item.id.equals(TextMenuItemId.of('paper-excerpt'))) return false;
            this.selectedText = selected; this.createExcerpt(); return true;
          }
        }).id('paper-selection-reading')
      Button('把选中的文字做成摘录', { type: ButtonType.Normal }).width('100%').height(38).fontSize(12)
        .fontColor('#315B56').backgroundColor('#E2EAE0').borderRadius(10).enabled(!!this.selectedText.trim())
        .id('paper-excerpt-create').onClick(() => this.createExcerpt())
      if (this.excerptCard) {
        Column({ space: 8 }) {
          Text(this.excerptCard).fontSize(13).lineHeight(22).fontColor('#3B625B').width('100%')
            .maxLines(5).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('长按拖到记忆草稿，或点击加入').fontSize(10).fontColor('#859187').width('100%')
          Button(this.chosenExcerpt === this.excerptCard ? '摘录已加入' : '加入记忆草稿', { type: ButtonType.Normal })
            .fontSize(12).fontColor('#315B56').backgroundColor('#DCE6D5').height(34).id('paper-excerpt-add')
            .onClick(() => { this.chosenExcerpt = this.excerptCard; })
        }.width('100%').padding(14).backgroundColor('#FFFCF3').borderRadius(12).draggable(true)
          .onDragStart((event: DragEvent): DragItemInfo => this.startExcerptDrag(event)).id('paper-excerpt-card')
        if (this.wide()) {
          Column({ space: 6 }) {
            Text('记忆草稿').fontSize(11).fontColor('#8C6D4C').width('100%')
            Text(this.chosenExcerpt || '把上面的摘录卡拖到这里').fontSize(13).lineHeight(21)
              .fontColor('#456B5D').width('100%').maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).id('paper-wide-excerpt-value')
          }.width('100%').padding(16).backgroundColor('#E1E9D8')
            .border({ width: 1, color: '#A5BBA4', style: BorderStyle.Dashed, radius: 12 }).borderRadius(12)
            .onDrop((event: DragEvent) => this.dropExcerpt(event)).id('paper-wide-excerpt-drop')
        }
      }
      Button('继续读原文化档案  →', { type: ButtonType.Normal }).height(44).width('100%')
        .fontColor('#234B4B').backgroundColor('#E0E9E0').borderRadius(12).id('paper-original-content')
        .onClick(() => { this.sheetOpen = false; this.onOpenContent(this.city().relatedSiteId); })
      Text('资料初稿待校审。这里的纸景、剪口和支撑规则为原创创作，不是遗址测绘、文物复原或传统技艺教学。')
        .fontSize(11).lineHeight(18).fontColor('#7B8580').width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  memoryContent() {
    Column({ space: 14 }) {
      Text('把这一剪，留给自己').fontSize(23).fontWeight(FontWeight.Bold).fontColor('#203A3D').width('100%')
      PaperJourneyScene({ work: this.work, cityId: this.cityId, interactive: false, unfolded: true,
        reducedMotion: this.reducedMotion, showGuide: false })
        .width('100%').height(this.wide() ? 160 : 230).borderRadius(18).clip(true)
      Column({ space: 8 }) {
        Text(this.chosenExcerpt || '资料中的一句话，也可以留在这一页。').fontSize(13).lineHeight(22)
          .fontColor('#628476').width('100%').maxLines(6).textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.chosenExcerpt) {
          Text('摘录会完整留下，可以在保存后的纸页里重读。').fontSize(10).fontColor('#7F8F83').width('100%')
        }
      }.width('100%').padding(12).backgroundColor('#E3EBDD').borderRadius(12)
        .onDrop((event: DragEvent) => this.dropExcerpt(event)).id('paper-excerpt-drop')
      TextArea({ text: this.body, placeholder: '这一页让你想到什么？也可以只保存作品。' })
        .height(110).fontSize(15).fontColor('#203A3D').backgroundColor('#FFFCF3').borderRadius(13)
        .maxLength(4000).onChange((text: string) => { this.body = text; }).id('paper-memory-body')
      Text('保存当前剪口、纸色和文化出处。这里的文字由你决定，完成目标不会自动写成你的感想。')
        .fontSize(12).lineHeight(19).fontColor('#6E7D79').width('100%')
      Button('确认，收进记忆', { type: ButtonType.Normal }).width('100%').height(47)
        .fontSize(15).fontColor('#FFFCF3').backgroundColor('#285A54').borderRadius(14)
        .enabled(!this.saving && !this.localSaving).id('paper-memory-save')
        .onClick(() => { this.saveMemory(); })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  sheet() {
    Column() {
      Row() {
        Text(this.sheetMode === 'culture' ? '文化资料' : '我的记忆').fontSize(14).fontColor('#6D7771').layoutWeight(1)
        Button('×', { type: ButtonType.Normal }).width(36).height(36).fontSize(24).fontColor('#344B4B')
          .backgroundColor('#E7E4D8').borderRadius(18).id('paper-sheet-close').onClick(() => { this.sheetOpen = false; })
      }.width('100%').padding({ left: 20, right: 14, top: 10, bottom: 10 })
      Scroll() {
        Column() {
          if (this.sheetMode === 'culture') { this.cultureContent() } else { this.memoryContent() }
        }.width('100%').padding({ left: 20, right: 20, bottom: 28 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off).id('paper-sheet-scroll')
    }.width('100%').height('100%').backgroundColor(PAPER)
  }

  @Builder
  workbench() {
    Column() {
      this.challenge()
      PaperJourneyScene({ work: this.work, cityId: this.cityId, interactive: !this.unreadable,
        unfolded: this.unfolded, reducedMotion: this.reducedMotion, showGuide: this.showGuide,
        brushRadius: this.brush, observationMode: this.observationMode,
        onStroke: (points: PaperPoint[]) => this.cut(points) })
        .width('100%').layoutWeight(1).constraintSize({ minHeight: 190 }).id('paper-play-scene')
      this.tools()
      this.feedback()
      this.bottomActions()
    }.width('100%').height('100%')
  }

  build() {
    NavDestination() {
      Column() {
        this.header()
        if (this.wide()) {
          Row({ space: 0 }) {
            Column() { this.workbench() }.layoutWeight(1.6).height('100%')
            Scroll() { this.cultureContent() }.layoutWeight(1).height('100%')
              .padding(22).backgroundColor(PAPER).scrollBar(BarState.Off).id('paper-culture-column')
          }.width('100%').layoutWeight(1).alignItems(VerticalAlign.Top)
        } else {
          Column() { this.workbench() }.width('100%').layoutWeight(1)
        }
      }.width('100%').height('100%').backgroundColor(NIGHT).id('paper-journey-page')
        .onAreaChange((_old: Area, area: Area) => { this.containerWidth = Number(area.width); })
    }.hideTitleBar(true).backgroundColor(NIGHT)
      // NavDestination 自己声明深色页面的栏文字，返回首页时由 HDS 恢复自己的样式。
      // 扩展背景绘制而非让按钮进入系统栏，手机/平板继续使用真实安全区。
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .systemBarStyle({ statusBarContentColor: '#FFF4ECDD' })
      // API26平板默认弹出窄幅居中Sheet，RESIZE_ONLY会在键盘出现后把正文挤出可见区。
      // 使用明确底部半模态与宽幅草稿；系统先抬升再滚动到输入处，不用固定键盘高度补位。
      .bindSheet($$this.sheetOpen, this.sheet(), { height: '90%', preferType: SheetType.BOTTOM,
        width: this.wide() ? 680 : '100%', showClose: false, dragBar: true,
        keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_SCROLL })
      .onBackPressed(() => { if (this.sheetOpen) { this.sheetOpen = false; return true; } return false; })
  }
}
