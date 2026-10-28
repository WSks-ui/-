// API26编译器展开SelectionContainer链式属性时还会解析Attribute类型，须保留显式导入。
import { SelectionContainer, SelectionContainerAttribute, SelectionContainerController, SelectionContainerTextJoinStyle } from '@kit.ArkUI';
import { unifiedDataChannel } from '@kit.ArkData';
import { activeRecords, ArchiveRecord, COLLECTION_TAGS, MAX_NOTE_LENGTH, MAX_NOTE_TAGS,
  MAX_NOTE_TAG_LENGTH, MAX_NOTE_TAGS_TEXT_LENGTH } from '../domain/ArchiveDomain';
import type { RiverMarketV2 } from '../domain/RiverMarketV2';
import { copyMarketMemory, freezeMarketMemory, MarketMemoryContext } from '../domain/MarketMemory';
import { MARKET_CULTURES, MARKET_CULTURE_BOUNDARY, marketCultureForId, MarketCultureEntry,
  MarketCultureRecommendation, recommendMarketCultures } from '../data/MarketCultureCatalog';
import { MarketMemoryPreview } from './MarketMemoryPage';
import { setPaperWindowText } from '../platform/PaperWindowStyle';

interface MarketExcerptTransfer { version: number; contentId: string; excerpt: string; }

@Component
export struct MarketCulturePage {
  @Prop @Watch('prepareEntry') contentId: string = 'culture-kf-night-market';
  @Prop @Watch('receiveRecords') records: ArchiveRecord[] = [];
  @Prop saving: boolean = false;
  @Prop marketState: RiverMarketV2 | undefined = undefined;
  @Prop reducedMotion: boolean = false;
  onSave: (body: string, tags: string[], excerpt: string, context?: MarketMemoryContext) => Promise<boolean> = async () => false;
  onFavorite: (contentId: string, category: string) => Promise<boolean> = async () => false;
  onOpenContent: (id: string) => void = () => {};
  onBack: () => void = () => {};
  @State private containerWidth: number = 360;
  @State private draftOpen: boolean = false;
  @State private body: string = '';
  @State private tagsText: string = '开封，夜市';
  @State private selectedCategory: string = '研究资料';
  @State private selectedText: string = '';
  @State private excerptCard: string = '';
  @State private chosenExcerpt: string = '';
  @State private message: string = '';
  @State private localSaving: boolean = false;
  @State private favoriteSaving: boolean = false;
  @State private memorySaved: boolean = false;
  @State private frozenContext: MarketMemoryContext | undefined = undefined;
  private selectionController: SelectionContainerController = new SelectionContainerController();

  aboutToAppear(): void { this.prepareEntry(); }
  private entry(): MarketCultureEntry { return marketCultureForId(this.contentId) || MARKET_CULTURES[0]; }
  private wide(): boolean { return this.containerWidth >= 900; }
  private favorite(): ArchiveRecord | undefined {
    return activeRecords(this.records, 'favorite').find((record: ArchiveRecord): boolean => record.siteId === this.contentId);
  }
  private receiveRecords(): void {
    const favorite = this.favorite();
    if (favorite && favorite.tags.length > 0 && COLLECTION_TAGS.includes(favorite.tags[0])) this.selectedCategory = favorite.tags[0];
  }

  private prepareEntry(): void {
    this.body = ''; this.chosenExcerpt = ''; this.excerptCard = ''; this.selectedText = '';
    this.message = ''; this.memorySaved = false; this.frozenContext = undefined;
    this.tagsText = this.entry().tags.slice(0, 3).join('，'); this.receiveRecords();
    // 只把进入本篇时眼前的同一夜冻结下来；之后同步回包或另开一夜不会替换正在写的草稿。
    // 从文化库自由阅读没有经营context，仍能选摘、收藏与写note，不要求先通关。
    if (this.marketState && this.marketState.nightId === this.entry().nightId) {
      this.frozenContext = freezeMarketMemory(this.marketState, this.entry().title,
        this.entry().revision, [this.entry().source]);
    }
  }

  private async setFavorite(category: string): Promise<void> {
    if (this.favoriteSaving || this.saving) return;
    this.favoriteSaving = true;
    try {
      const saved = await this.onFavorite(this.contentId, category);
      this.message = saved ? (category ? `已收藏到“${category}”。` : '已取消收藏。') : '收藏尚未保存，请稍后再试。';
    } catch (_error) { this.message = '收藏尚未保存，请稍后再试。'; }
    finally { this.favoriteSaving = false; }
  }

  private createExcerpt(): void {
    if (!this.selectedText.trim()) return;
    this.excerptCard = this.selectedText.trim().slice(0, 1800);
    try { this.selectionController.closeSelectionMenu(); } catch (_error) {}
  }

  private addExcerpt(): void {
    this.chosenExcerpt = this.excerptCard; this.memorySaved = false;
    this.message = '摘录已放进草稿，确认保存后才会成为记忆。';
  }

  private startExcerptDrag(event: DragEvent): DragItemInfo {
    const value: MarketExcerptTransfer = { version: 1, contentId: this.contentId, excerpt: this.excerptCard };
    const text = new unifiedDataChannel.PlainText(); text.textContent = JSON.stringify(value); text.abstract = '云河纪 · 三夜文化摘录';
    event.setData(new unifiedDataChannel.UnifiedData(text)); return { extraInfo: 'market-cultural-excerpt-v1' };
  }

  private dropExcerpt(event: DragEvent): void {
    try {
      for (const record of event.getData().getRecords()) {
        if (record.getType() !== 'general.plain-text') continue;
        const value = JSON.parse((record as unifiedDataChannel.PlainText).textContent) as MarketExcerptTransfer;
        // 只有本篇本次生成的卡片才自动携带此条出处，外来任意文本不能冒充已核文献。
        if (value.version !== 1 || value.contentId !== this.contentId || typeof value.excerpt !== 'string' ||
          !value.excerpt || value.excerpt !== this.excerptCard) continue;
        this.addExcerpt(); event.setResult(DragResult.DRAG_SUCCESSFUL); return;
      }
    } catch (_error) {}
    event.setResult(DragResult.DRAG_FAILED);
  }

  private async save(): Promise<void> {
    if (this.localSaving || this.saving || this.memorySaved) return;
    if (!this.body.trim() && !this.chosenExcerpt.trim()) { this.message = '写一点自己的话，或选一段摘录。'; return; }
    const tags = this.tagsText.split(/[,，]/).map((tag: string): string => tag.trim()).filter((tag: string): boolean => !!tag);
    if (tags.length > MAX_NOTE_TAGS || tags.some((tag: string): boolean => tag.length > MAX_NOTE_TAG_LENGTH)) {
      this.message = `最多${MAX_NOTE_TAGS}个标签，每个不超过${MAX_NOTE_TAG_LENGTH}字。`; return;
    }
    const context = this.frozenContext ? copyMarketMemory(this.frozenContext) : undefined;
    if (context) context.excerpt = this.chosenExcerpt;
    this.localSaving = true;
    try {
      const saved = await this.onSave(this.body.trim(), tags, this.chosenExcerpt, context);
      if (saved) {
        this.memorySaved = true; this.message = '这一页已存入记忆，可以从“记忆”重新读到文字、摘录与出处。';
        this.getUIContext().getPromptAction().showToast({ message: '已存入个人记忆' });
      } else this.message = '还没有保存成功，文字和摘录都留在这里。';
    } catch (_error) { this.message = '还没有保存成功，文字和摘录都留在这里。'; }
    finally { this.localSaving = false; }
  }

  @Builder
  private reading() {
    Column({ space: 18 }) {
      Text('开 封 三 夜  /  生 活 文 献').fontSize(11).letterSpacing(2).fontColor('#A6794D').width('100%')
      Text(this.entry().title).fontSize(this.wide() ? 32 : 29).fontWeight(FontWeight.Medium).fontColor('#233F40').lineHeight(42).width('100%')
      Text(this.entry().subtitle).fontSize(14).lineHeight(24).fontColor('#6C8078').width('100%')
      Row({ space: 12 }) {
        Button(this.favorite() ? '已收藏' : '收藏这篇', { type: ButtonType.Normal }).height(36).fontSize(12)
          .fontColor(this.favorite() ? '#8D673D' : '#315B54').backgroundColor('#E4E8D7').borderRadius(9)
          .enabled(!this.favoriteSaving && !this.saving).id('tn-culture-favorite')
          .onClick(() => { this.setFavorite(this.favorite() ? '' : this.selectedCategory); })
        Select(COLLECTION_TAGS.map((value: string): SelectOption => ({ value }))).value(this.selectedCategory)
          .selected(COLLECTION_TAGS.indexOf(this.selectedCategory)).height(36).layoutWeight(1).font({ size: 12 })
          .fontColor('#657867').backgroundColor('#ECEADA').id('tn-culture-category')
          .onSelect((_index: number, value: string) => {
            this.selectedCategory = value; if (this.favorite()) this.setFavorite(value);
          })
      }.width('100%')
      SelectionContainer({ controller: this.selectionController }) {
        Column({ space: 20 }) {
          Column({ space: 11 }) {
            Text(this.entry().quote).fontSize(21).lineHeight(36).fontColor('#3F6355').width('100%').id('tn-culture-quote')
            Text(this.entry().source.title).fontSize(11).fontColor('#9E7D52').width('100%')
          }.width('100%').padding(21).backgroundColor('#E8EBDD').borderRadius(12)
          Text(this.entry().body).fontSize(16).lineHeight(30).fontColor('#3F5854').width('100%')
          Text(this.entry().question).fontSize(15).lineHeight(27).fontColor('#7D785A').width('100%')
        }.width('100%')
      }.width('100%').copyOption(CopyOptions.InApp).textJoinStyle(SelectionContainerTextJoinStyle.NEWLINE)
        .onTextSelectionChange((paragraphs: string[]) => { this.selectedText = paragraphs.filter((text: string): boolean => !!text).join('\n'); })
        .editMenuOptions({
          onCreateMenu: (items: TextMenuItem[]): TextMenuItem[] => {
            const next = items.filter(item => item.id.equals(TextMenuItemId.COPY) || item.id.equals(TextMenuItemId.SELECT_ALL));
            next.push({ content: '做成摘录', id: TextMenuItemId.of('market-excerpt') }); return next;
          },
          onMenuItemClick: (item: TextMenuItem, selected: string): boolean => {
            if (!item.id.equals(TextMenuItemId.of('market-excerpt'))) return false;
            this.selectedText = selected; this.createExcerpt(); return true;
          }
        }).id('tn-culture-read')
      Button('把选中的文字做成摘录', { type: ButtonType.Normal }).width('100%').height(39).fontSize(12)
        .fontColor('#315B56').backgroundColor('#E2E8D8').borderRadius(9).enabled(!!this.selectedText.trim())
        .id('tn-culture-excerpt-create').onClick(() => this.createExcerpt())
      if (this.excerptCard) {
        Column({ space: 10 }) {
          Text(this.excerptCard).fontSize(14).lineHeight(24).fontColor('#3B625B').width('100%')
            .maxLines(6).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.wide() ? '长按这张卡，拖进右侧草稿。' : '长按可拖入草稿，也可以点击加入。').fontSize(11).fontColor('#87927F').width('100%')
          Button(this.chosenExcerpt === this.excerptCard ? '摘录已加入' : '加入记忆草稿', { type: ButtonType.Normal })
            .fontSize(12).fontColor('#315B56').backgroundColor('#DDE5D2').height(35).id('tn-culture-excerpt-add')
            .onClick(() => { this.addExcerpt(); if (!this.wide()) this.draftOpen = true; })
        }.width('100%').padding(17).backgroundColor('#FFFCF1').border({ width: 1, color: '#D6DCC9', radius: 11 })
          .borderRadius(11).draggable(true).onDragStart((event: DragEvent): DragItemInfo => this.startExcerptDrag(event))
          .id('tn-culture-excerpt-card')
      }
      Column({ space: 9 }) {
        Text('这段生活，怎样进入三夜').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#35584E').width('100%')
        Text(this.entry().gameConnection).fontSize(13).lineHeight(23).fontColor('#718173').width('100%')
      }.width('100%').padding({ top: 4, bottom: 3 })
      Divider().color('#D9DECE')
      Text(this.entry().source.era).fontSize(12).fontColor('#97754E').width('100%')
      Text(`${this.entry().source.title}\n${this.entry().source.url}\n查阅日期：${this.entry().source.accessedAt} · 内容修订 ${this.entry().revision}`)
        .fontSize(11).lineHeight(20).fontColor('#7F8B7D').width('100%').copyOption(CopyOptions.LocalDevice).id('tn-culture-source')
      Button('读州桥遗址档案  →', { type: ButtonType.Normal }).width('100%').height(41).fontSize(12)
        .fontColor('#4F7161').backgroundColor('#E5E8D9').borderRadius(9)
        .onClick(() => this.onOpenContent(this.entry().relatedSiteId)).id('tn-culture-related')
      Text('还想读一页').fontSize(18).fontColor('#35584E').width('100%').margin({ top: 5 })
      ForEach(recommendMarketCultures(this.records, this.contentId), (suggestion: MarketCultureRecommendation) => {
        Button({ type: ButtonType.Normal }) {
          Column({ space: 5 }) {
            Text(`${suggestion.entry.title}  →`).fontSize(14).fontColor('#3D6354').width('100%')
            Text(suggestion.reason).fontSize(10).fontColor('#87927D').width('100%')
          }.width('100%').alignItems(HorizontalAlign.Start)
        }.width('100%').padding({ top: 8, bottom: 8 }).backgroundColor(Color.Transparent).borderRadius(0)
          .onClick(() => this.onOpenContent(suggestion.entry.id)).id(`tn-culture-next-${suggestion.entry.id}`)
      }, (suggestion: MarketCultureRecommendation) => suggestion.entry.id)
      Text(MARKET_CULTURE_BOUNDARY).fontSize(10).lineHeight(18).fontColor('#929B89').width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start).padding(this.wide() ? 30 : 23)
  }

  @Builder
  private draft() {
    Column({ space: 16 }) {
      Text(this.frozenContext ? '把这一夜，留给自己' : '从这一句，写一页').fontSize(23).fontWeight(FontWeight.Medium)
        .fontColor('#294B45').width('100%')
      if (this.frozenContext) {
        MarketMemoryPreview({ context: this.frozenContext }).width('100%').height(this.wide() ? 195 : 165).borderRadius(11).clip(true)
        Text(`保存眼前这一夜：接待 ${this.frozenContext.summary.served} / ${this.frozenContext.summary.arrivals} 客，余 ${this.frozenContext.summary.cash} 钱。`)
          .fontSize(12).lineHeight(20).fontColor('#7B896F').width('100%')
      }
      Column({ space: 7 }) {
        Text(this.chosenExcerpt || '把左边的摘录卡拖到这里，或直接写下自己的感受。')
          .fontSize(14).lineHeight(24).fontColor('#557A61').width('100%').maxLines(7)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).id('tn-culture-excerpt-value')
        if (this.chosenExcerpt) {
          Button('移去这段摘录', { type: ButtonType.Normal }).height(29).fontSize(10).fontColor('#8C8D75')
            .backgroundColor(Color.Transparent).padding(0).onClick(() => { this.chosenExcerpt = ''; this.memorySaved = false; })
        }
      }.width('100%').padding(16).backgroundColor('#E2EAD8')
        .border({ width: 1, color: '#B2C2A5', style: BorderStyle.Dashed, radius: 11 }).borderRadius(11)
        .onDrop((event: DragEvent) => this.dropExcerpt(event)).id('tn-culture-excerpt-drop')
      TextArea({ text: this.body, placeholder: '这句文字，或这一夜，让你想到什么？' }).height(this.wide() ? 150 : 118)
        .fontSize(15).fontColor('#294B45').backgroundColor('#FFFCF2').borderRadius(11).maxLength(MAX_NOTE_LENGTH)
        .onChange((value: string) => { this.body = value; this.memorySaved = false; }).id('tn-culture-body')
      TextInput({ text: this.tagsText, placeholder: '标签，用逗号分隔' }).height(44).fontSize(12).fontColor('#45644F')
        .backgroundColor('#FFFCF2').borderRadius(10).maxLength(MAX_NOTE_TAGS_TEXT_LENGTH)
        .onChange((value: string) => { this.tagsText = value; this.memorySaved = false; }).id('tn-culture-tags')
      Text(this.frozenContext ? '确认后，图景、文字与此篇出处一起留下。' : '确认后，文字、摘录与此篇出处一起留下。')
        .fontSize(11).lineHeight(19).fontColor('#84917B').width('100%')
      Button(this.memorySaved ? '这一页已存入记忆' : '确认，收进记忆', { type: ButtonType.Normal }).width('100%').height(47)
        .fontSize(15).fontColor('#FFFCED').backgroundColor('#325E4E').borderRadius(11)
        .enabled(!this.saving && !this.localSaving && !this.memorySaved && (!!this.body.trim() || !!this.chosenExcerpt.trim()))
        .onClick(() => { this.save(); }).id('tn-culture-save')
      if (this.message) { Text(this.message).fontSize(12).lineHeight(20).fontColor('#74866B').width('100%').id('tn-culture-message') }
    }.width('100%').alignItems(HorizontalAlign.Start).padding(this.wide() ? 27 : 23)
  }

  @Builder
  private draftSheet() {
    Column() {
      Row() {
        Text('我的记忆草稿').fontSize(13).fontColor('#7B8976').layoutWeight(1)
        Button('×', { type: ButtonType.Normal }).width(37).height(37).fontSize(24).fontColor('#45634F')
          .backgroundColor('#E3E6D5').borderRadius(18).onClick(() => { this.draftOpen = false; }).id('tn-culture-draft-close')
      }.width('100%').padding({ left: 23, right: 17, top: 8, bottom: 1 })
      Scroll() { this.draft() }.width('100%').layoutWeight(1).align(Alignment.Top)
        .scrollBar(BarState.Off).id('tn-culture-draft-scroll')
    }.width('100%').height('100%').backgroundColor('#F0F0E3')
  }

  build() {
    NavDestination() {
      Column() {
        if (this.wide()) {
          Row({ space: 0 }) {
            Scroll() { this.reading() }.layoutWeight(1.4).height('100%').scrollBar(BarState.Off)
            Scroll() { this.draft() }.layoutWeight(1).height('100%').align(Alignment.Top)
              .scrollBar(BarState.Off).backgroundColor('#EBEDDF')
              .id('tn-culture-draft-column')
          }.width('100%').layoutWeight(1).alignItems(VerticalAlign.Top)
        } else {
          Scroll() { this.reading() }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
          Row({ space: 12 }) {
            Text(this.chosenExcerpt ? '一句话已放进草稿' : '读到的，也能写成自己的记忆').fontSize(11).fontColor('#8C987F').layoutWeight(1)
            Button('写一页  →', { type: ButtonType.Normal }).height(42).fontSize(13).fontColor('#FFFCED')
              .backgroundColor('#325E4E').borderRadius(10).onClick(() => { this.draftOpen = true; }).id('tn-culture-write')
          }.width('100%').padding({ left: 21, right: 21, top: 9, bottom: 12 }).backgroundColor('#F0F0E3')
        }
      }.width('100%').height('100%').backgroundColor('#F5F2E7').id('tn-culture-page')
        .onAreaChange((_old: Area, area: Area) => { this.containerWidth = Number(area.width); })
    }.title('开封三夜 · 文化').backgroundColor('#F5F2E7')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .systemBarStyle({ statusBarContentColor: '#FF203D43' })
      // API26手机实测：键盘弹出时TRANSLATE_AND_RESIZE只用原窗口高度平移并裁剪Sheet，
      // 内Scroll仍按整屏高度判断为不可滚动，确认按钮落在裁剪区外。RESIZE_ONLY让Sheet
      // 真正缩短内容约束，再由顶部对齐的内Scroll承担溢出滚动，不要求用户先收键盘。
      .bindSheet($$this.draftOpen, this.draftSheet(), { height: '90%', preferType: SheetType.BOTTOM,
        width: this.wide() ? 680 : '100%', showClose: false, dragBar: true,
        keyboardAvoidMode: SheetKeyboardAvoidMode.RESIZE_ONLY })
      .onBackPressed(() => { if (this.draftOpen) { this.draftOpen = false; return true; } return false; })
      .onShown(() => { setPaperWindowText(this.getUIContext(), '#203D43'); })
      .onHidden(() => { setPaperWindowText(this.getUIContext(), '#F4ECD9'); })
  }
}
