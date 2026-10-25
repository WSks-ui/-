import type { ArchiveRecord, HeritageSite } from '../domain/ArchiveDomain';
import { COLLECTION_TAGS, activeRecords } from '../domain/ArchiveDomain';
import { culturalEntryForId } from '../data/CulturalContentIndex';
import { PAPER_CITIES } from '../data/PaperJourneyCatalog';
import { PaperJourneyScene } from './PaperJourneyScene';
import { PaperJourneyTheme as P } from './PaperJourneyTheme';

@Component
export struct PaperMemoryShelf {
  @Prop @Watch('recordsChanged') records: ArchiveRecord[] = [];
  @Prop topClearance: number = 76;
  @Prop bottomClearance: number = 90;
  @Prop @Watch('initialSectionChanged') initialSection: string = '手账';
  @Prop @Watch('initialAiChanged') initialAiOnly: boolean = false;
  scroller: Scroller = new Scroller();
  onRead: (note: ArchiveRecord) => void = () => {};
  onWrite: () => void = () => {};
  onOpenCollection: (siteId: string) => void = () => {};
  onLegacyScroll: () => void = () => {};
  onContinue: (cityId: string) => void = () => {};
  onEdit: (note: ArchiveRecord) => void = () => {};
  onDelete: (note: ArchiveRecord) => void = () => {};

  @State private section: string = '手账';
  @State private keyword: string = '';
  @State private tag: string = '全部标签';
  @State private sort: string = '最近';
  @State private aiOnly: boolean = false;
  @State private collectionTag: string = '全部分类';
  @State private filtersOpen: boolean = false;
  @State private selectedPaperId: string = '';
  @State private contentWidth: number = 360;
  private initialized: boolean = false;
  private searchController: SearchController = new SearchController();

  aboutToAppear(): void {
    if (this.initialized) return;
    this.initialized = true;
    this.initialSectionChanged(); this.initialAiChanged();
  }

  private initialSectionChanged(): void {
    if (this.initialSection === '手账' || this.initialSection === '收藏') this.section = this.initialSection;
  }

  private initialAiChanged(): void { this.aiOnly = this.initialAiOnly; }
  private recordsChanged(): void {
    // 删除或同步移走当前作品后再选择真实存活的作品；普通回包不抢走正在看的那一篇。
    if (this.selectedPaperId && !this.notes().some(note => note.id === this.selectedPaperId && note.paperContext)) {
      this.selectedPaperId = '';
    }
  }

  private site(note: ArchiveRecord): HeritageSite | undefined { return culturalEntryForId(note.siteId); }
  private title(note: ArchiveRecord): string {
    return note.paperContext?.title || note.roamingContext?.title || this.site(note)?.name || '这一页文字记忆';
  }

  private city(note: ArchiveRecord): string {
    if (note.paperContext) return PAPER_CITIES.find(city => city.id === note.paperContext?.cityId)?.city || '纸上作品';
    return note.roamingContext?.city || this.site(note)?.city || '个人记录';
  }

  private date(time: number): string {
    if (!Number.isFinite(time) || time <= 0) return '时间未记录';
    const value = new Date(time);
    return `${value.getFullYear()}.${(value.getMonth() + 1).toString().padStart(2, '0')}.${value.getDate().toString().padStart(2, '0')}`;
  }

  private notes(): ArchiveRecord[] {
    const words = this.keyword.trim().toLowerCase().split(/\s+/).filter(value => !!value);
    const notes = activeRecords(this.records, 'note').filter((note: ArchiveRecord): boolean =>
      (!this.aiOnly || note.aiAssist !== undefined) && (this.tag === '全部标签' || note.tags.includes(this.tag)) &&
      words.every(word => (`${this.title(note)} ${this.city(note)} ${note.body} ${note.tags.join(' ')} ` +
        `${note.quotedPoemOrFact || ''} ${note.aiAssist?.question || ''}`).toLowerCase().includes(word)));
    // 纸景优先展示是排版选择；最近/最早顺序只按实际保存时间，不改任何记录或时间戳。
    if (this.sort === '最早') notes.sort((a, b) => a.updatedAt - b.updatedAt || (a.id < b.id ? -1 : 1));
    return notes;
  }

  private paperNotes(): ArchiveRecord[] { return this.notes().filter(note => note.paperContext !== undefined); }
  private textNotes(): ArchiveRecord[] { return this.notes().filter(note => note.paperContext === undefined); }
  private selectedPaper(): ArchiveRecord | undefined {
    const papers = this.paperNotes();
    return papers.find(note => note.id === this.selectedPaperId) || papers[0];
  }

  private tags(): string[] {
    const tags: string[] = ['全部标签'];
    activeRecords(this.records, 'note').forEach(note => note.tags.forEach(tag => { if (!tags.includes(tag)) tags.push(tag); }));
    return tags;
  }

  private favorites(): ArchiveRecord[] {
    return activeRecords(this.records, 'favorite').filter(record => this.collectionTag === '全部分类' || record.tags.includes(this.collectionTag));
  }

  private favoriteTitle(record: ArchiveRecord): string { return culturalEntryForId(record.siteId)?.name || '原文化资料暂不可用'; }
  private favoriteSummary(record: ArchiveRecord): string {
    const entry = culturalEntryForId(record.siteId);
    return entry ? `${entry.city} · ${entry.type}` : `已保留原收藏 · ${record.siteId}`;
  }

  private hasFilters(): boolean { return !!this.keyword || this.tag !== '全部标签' || this.sort !== '最近' || this.aiOnly; }
  private resetFilters(): void { this.keyword = ''; this.tag = '全部标签'; this.sort = '最近'; this.aiOnly = false; }

  private confirmDelete(note: ArchiveRecord): void {
    // 回调携带确认时那一篇的真实身份，不能用精选作品的 ID 代替列表里点中的旧手账。
    this.getUIContext().showAlertDialog({ title: '收起这一页记忆？',
      message: '删除会随同一账号同步。其他手账和纸景继续保留。',
      primaryButton: { value: '留下', action: () => {} },
      secondaryButton: { value: '删除', action: () => this.onDelete(note) } });
  }

  @Builder
  private heading() {
    Column({ space: 7 }) {
      Text('我 留 下 的').fontSize(11).letterSpacing(4).fontColor(P.amber)
      Row({ space: 12 }) {
        Text('记忆').fontSize(34).fontWeight(FontWeight.Medium).fontColor(P.paper).layoutWeight(1)
        Button('写一页  ＋', { type: ButtonType.Normal }).height(34).fontSize(12).fontColor(P.paper)
          .backgroundColor(Color.Transparent).padding(0).onClick(() => this.onWrite()).id('memory-write')
      }.width('100%')
      Text('纸上的光，和当时想说的话。').fontSize(14).fontColor(P.paperSoft)
    }.width('100%').alignItems(HorizontalAlign.Start).margin({ bottom: 23 })
    Row({ space: 22 }) {
      Button(`手账 ${activeRecords(this.records, 'note').length}`, { type: ButtonType.Normal })
        .height(36).fontSize(15).fontWeight(this.section === '手账' ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.section === '手账' ? P.paper : P.dim).backgroundColor(Color.Transparent).padding(0)
        .border({ width: { bottom: this.section === '手账' ? 2 : 0 }, color: P.amber }).borderRadius(0)
        .onClick(() => { this.section = '手账'; }).id('memory-section-notes')
      Button(`收藏 ${activeRecords(this.records, 'favorite').length}`, { type: ButtonType.Normal })
        .height(36).fontSize(15).fontWeight(this.section === '收藏' ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.section === '收藏' ? P.paper : P.dim).backgroundColor(Color.Transparent).padding(0)
        .border({ width: { bottom: this.section === '收藏' ? 2 : 0 }, color: P.amber }).borderRadius(0)
        .onClick(() => { this.section = '收藏'; }).id('memory-section-favorites')
      Blank()
      if (this.section === '手账') {
        Button(this.hasFilters() ? '已筛选  ≡' : '找一页  ≡', { type: ButtonType.Normal }).height(34).fontSize(11)
          .fontColor(this.hasFilters() ? P.amber : P.muted).backgroundColor(Color.Transparent).padding(0)
          .onClick(() => { this.filtersOpen = true; }).id('memory-filters')
      }
    }.width('100%').border({ width: { bottom: 0.6 }, color: P.line }).margin({ bottom: 20 })
  }

  @Builder
  private noteActions(note: ArchiveRecord, dark: boolean) {
    Row({ space: 19 }) {
      Button('编辑', { type: ButtonType.Normal }).height(28).fontSize(11).fontColor(dark ? P.paperSoft : P.ink)
        .padding(0).backgroundColor(Color.Transparent).onClick(() => this.onEdit(note)).id(`edit-${note.id}`)
      Button('删除', { type: ButtonType.Normal }).height(28).fontSize(11).fontColor(dark ? P.dim : P.copper)
        .padding(0).backgroundColor(Color.Transparent).onClick(() => this.confirmDelete(note)).id(`delete-${note.id}`)
    }
  }

  @Builder
  private paperFeature(note: ArchiveRecord) {
    if (note.paperContext) {
      Column() {
        // 只读使用存下的 work；新一局或另一端继续剪纸都不能改写这张作品的预览。
        // ForEach 的键是 note.id，切换作品时不会复用另一条记录的 Canvas 身份。
        ForEach([note], (paper: ArchiveRecord) => {
          if (paper.paperContext) {
            PaperJourneyScene({ work: paper.paperContext.work, cityId: paper.paperContext.cityId,
              interactive: false, unfolded: true, reducedMotion: true, showGuide: false })
              .width('100%').height(this.contentWidth >= 760 ? 340 : 280)
              .onClick(() => this.onRead(paper)).id(`paper-memory-preview-${paper.id}`)
          }
        }, (paper: ArchiveRecord) => paper.id)
        Column({ space: 9 }) {
          Row({ space: 10 }) {
            Text(`${this.city(note)} / 纸景作品`).fontSize(11).fontColor(P.copper).layoutWeight(1)
            Text(this.date(note.updatedAt)).fontSize(10).fontColor(P.ink).opacity(0.6)
          }.width('100%')
          Text(note.paperContext.title).fontSize(22).fontWeight(FontWeight.Medium).fontColor(P.ink).width('100%')
          Text(note.body).fontSize(14).lineHeight(23).fontColor(P.ink).maxLines(4).width('100%')
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Row({ space: 12 }) {
            Button('翻开这一页  →', { type: ButtonType.Normal }).height(35).fontSize(12).fontColor(P.ink)
              .padding(0).backgroundColor(Color.Transparent).onClick(() => this.onRead(note)).layoutWeight(1)
              .id(`memory-open-${note.id}`)
            this.noteActions(note, false)
          }.width('100%')
        }.width('100%').padding({ left: 19, right: 19, top: 4, bottom: 17 }).alignItems(HorizontalAlign.Start)
      }.width('100%').backgroundColor(P.paper).borderRadius(6).clip(true).id(`paper-memory-feature-${note.id}`)
    }
  }

  @Builder
  private paperList() {
    if (this.paperNotes().length > 1) {
      Text('另一些光').fontSize(11).fontColor(P.dim).width('100%').margin({ top: 22, bottom: 7 })
      ForEach(this.paperNotes(), (note: ArchiveRecord) => {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 11 }) {
            Row().width(4).height(32).backgroundColor(note.paperContext?.work.paper || P.amber)
            Column({ space: 5 }) {
              Text(this.title(note)).fontSize(14).fontColor(P.paper).maxLines(1)
              Text(`${this.city(note)} · ${this.date(note.updatedAt)}`).fontSize(10).fontColor(P.dim)
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Text(this.selectedPaper()?.id === note.id ? '正在看' : '展开 →').fontSize(10)
              .fontColor(this.selectedPaper()?.id === note.id ? P.amber : P.muted)
          }.width('100%')
        }.width('100%').padding({ top: 13, bottom: 13 }).backgroundColor(Color.Transparent).borderRadius(0)
          .border({ width: { bottom: 0.6 }, color: P.line })
          .onClick(() => { this.selectedPaperId = note.id; }).id(`paper-memory-select-${note.id}`)
      }, (note: ArchiveRecord) => note.id)
    }
  }

  @Builder
  private textNote(note: ArchiveRecord) {
    Column({ space: 10 }) {
      Button({ type: ButtonType.Normal }) {
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            Text(`${this.city(note)} · ${this.date(note.updatedAt)}`).fontSize(10).fontColor(P.amber).layoutWeight(1)
            if (note.aiAssist) { Text('AI 参考').fontSize(10).fontColor(P.muted).id(`memory-ai-assist-${note.id}`) }
          }.width('100%')
          Text(this.title(note)).fontSize(17).fontWeight(FontWeight.Medium).fontColor(P.paper).width('100%')
          Text(note.body).fontSize(13).lineHeight(22).fontColor(P.paperSoft).maxLines(4).width('100%')
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (note.snapshot3DPose) {
            Text(`留有原观察视角 · ${note.snapshot3DPose.label || '保存时的镜头'}`).fontSize(10).fontColor(P.muted)
          } else if (note.roamingContext) {
            Text('留有当时的文化片段与出处').fontSize(10).fontColor(P.muted)
          }
          if (note.tags.length > 0) { Text(note.tags.map(value => `#${value}`).join('  ')).fontSize(10).fontColor(P.dim).maxLines(1) }
        }.width('100%').alignItems(HorizontalAlign.Start)
      }.width('100%').padding(0).backgroundColor(Color.Transparent).borderRadius(0)
        .onClick(() => this.onRead(note)).id(`memory-open-${note.id}`)
      Row() {
        Text('读手账 →').fontSize(11).fontColor(P.muted).layoutWeight(1).onClick(() => this.onRead(note))
        this.noteActions(note, true)
      }.width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 19, bottom: 17 })
      .border({ width: { bottom: 0.6 }, color: P.line }).id(`memory-note-${note.id}`)
  }

  @Builder
  private notesBody() {
    if (this.selectedPaper()) { this.paperFeature(this.selectedPaper()!) }
    this.paperList()
    if (this.textNotes().length > 0) {
      Row({ space: 10 }) {
        Text(this.paperNotes().length > 0 ? '字里行间' : '留下过的文字').fontSize(20).fontColor(P.paper).layoutWeight(1)
        Text(`${this.textNotes().length} 页`).fontSize(10).fontColor(P.dim)
      }.width('100%').margin({ top: this.paperNotes().length > 0 ? 30 : 3, bottom: 1 })
      ForEach(this.textNotes(), (note: ArchiveRecord) => { this.textNote(note) }, (note: ArchiveRecord) => note.id)
    }
    if (this.notes().length === 0) {
      Column({ space: 15 }) {
        Text(this.hasFilters() ? '还没找到那一页' : '先让一束光留下来').fontSize(24).fontColor(P.paper)
        Text(this.hasFilters() ? '试试另一个关键词或标签。' : '沿河选一城，展开自己的纸景，或者写下此刻的感受。')
          .fontSize(13).lineHeight(22).fontColor(P.muted).textAlign(TextAlign.Center)
        Button(this.hasFilters() ? '清除筛选' : '去纸上生城  →', { type: ButtonType.Normal }).height(43).fontSize(13)
          .fontColor(P.ink).backgroundColor(P.amber).borderRadius(4)
          .onClick(() => { if (this.hasFilters()) this.resetFilters(); else this.onContinue(PAPER_CITIES[0].id); })
      }.width('100%').padding({ top: 55, bottom: 55 })
    }
    Button('翻看以前的个人长卷  →', { type: ButtonType.Normal }).width('100%').height(46).fontSize(11)
      .fontColor(P.muted).backgroundColor(Color.Transparent).padding(0).margin({ top: 20 })
      .onClick(() => this.onLegacyScroll()).id('paper-memory-legacy')
  }

  @Builder
  private collectionBody() {
    Select(['全部分类'].concat(COLLECTION_TAGS).map((value: string): SelectOption => ({ value })))
      .value(this.collectionTag).height(36).font({ size: 12 }).fontColor(P.paper).backgroundColor(P.deep)
      .onSelect((_index: number, value: string) => { this.collectionTag = value; }).id('memory-collection-category')
    Text('收藏是想再读的一页；“已去过”由你亲自标记。').fontSize(11).fontColor(P.dim).lineHeight(18)
      .width('100%').margin({ top: 10, bottom: 11 })
    ForEach(this.favorites(), (record: ArchiveRecord) => {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 13 }) {
          SymbolGlyph($r('sys.symbol.bookmark_fill')).fontSize(17).fontColor([P.amber])
          Column({ space: 7 }) {
            Text(this.favoriteTitle(record)).fontSize(16).fontColor(P.paper).width('100%')
            Text(this.favoriteSummary(record)).fontSize(11).fontColor(P.muted)
            if (record.tags.length > 0) { Text(record.tags.join(' · ')).fontSize(10).fontColor(P.dim) }
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Text('→').fontSize(15).fontColor(P.muted)
        }.width('100%')
      }.width('100%').padding({ top: 19, bottom: 19 }).backgroundColor(Color.Transparent).borderRadius(0)
        .border({ width: { bottom: 0.6 }, color: P.line }).onClick(() => this.onOpenCollection(record.siteId))
        .id(`favorite-row-${record.siteId}`)
    }, (record: ArchiveRecord) => record.id)
    if (this.favorites().length === 0) {
      Column({ space: 12 }) {
        Text('把想再读的，留在这里').fontSize(21).fontColor(P.paper)
        Text('文化库里的一次收藏，会成为下次阅读的路标。').fontSize(13).fontColor(P.muted).lineHeight(22)
      }.width('100%').padding({ top: 50, bottom: 50 })
    }
  }

  @Builder
  private filterSheet() {
    Column({ space: 19 }) {
      Text('找到想再读的一页').fontSize(23).fontWeight(FontWeight.Medium).fontColor(P.ink).width('100%')
      Search({ value: this.keyword, controller: this.searchController, placeholder: '正文、标题、标签或保存时的问题' })
        .height(45).fontColor(P.ink).placeholderColor('#7A847D').backgroundColor('#E6DDCA').borderRadius(5)
        .onChange((value: string) => { this.keyword = value; }).id('memory-search')
      Text('标签').fontSize(12).fontColor(P.ink).width('100%')
      Select(this.tags().map((value: string): SelectOption => ({ value }))).value(this.tag).height(44).width('100%')
        .font({ size: 13 }).fontColor(P.ink).backgroundColor('#E6DDCA')
        .onSelect((_index: number, value: string) => { this.tag = value; }).id('memory-tag')
      Text('顺序').fontSize(12).fontColor(P.ink).width('100%')
      Select(['最近', '最早'].map((value: string): SelectOption => ({ value }))).value(this.sort).height(44).width('100%')
        .font({ size: 13 }).fontColor(P.ink).backgroundColor('#E6DDCA')
        .onSelect((_index: number, value: string) => { this.sort = value; }).id('memory-sort')
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text('只看 AI 参考手账').fontSize(14).fontColor(P.ink)
          Text('保留了采纳时的问题与资料依据').fontSize(11).fontColor('#6C796E')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.aiOnly }).selectedColor(P.moss)
          .onChange((value: boolean) => { this.aiOnly = value; }).id('memory-ai-filter')
      }.width('100%').padding({ top: 8, bottom: 8 })
      Blank()
      Row({ space: 12 }) {
        Button('重置', { type: ButtonType.Normal }).height(46).width(80).fontSize(13).fontColor(P.ink)
          .backgroundColor('#E6DDCA').borderRadius(5).onClick(() => this.resetFilters())
        Button(`翻看 ${this.notes().length} 页`, { type: ButtonType.Normal }).height(46).layoutWeight(1).fontSize(14)
          .fontColor(P.paper).backgroundColor(P.moss).borderRadius(5)
          .onClick(() => { this.searchController.stopEditing(); this.filtersOpen = false; }).id('memory-filter-done')
      }.width('100%')
    }.width('100%').height('100%').alignItems(HorizontalAlign.Start)
      .padding({ left: 24, right: 24, top: 26, bottom: 25 }).backgroundColor(P.paper)
  }

  build() {
    Scroll(this.scroller) {
      Column() {
        this.heading()
        if (this.section === '收藏') { this.collectionBody() } else { this.notesBody() }
      }.width('100%').constraintSize({ maxWidth: 960 }).alignItems(HorizontalAlign.Start)
        .padding({ left: 22, right: 22, top: this.topClearance, bottom: this.bottomClearance + 20 })
        .onAreaChange((_old: Area, area: Area) => { this.contentWidth = Number(area.width) - 44; })
    }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring).backgroundColor(P.night)
      .id('paper-memory').bindSheet($$this.filtersOpen, this.filterSheet(), {
        height: SheetSize.LARGE, showClose: false, dragBar: true, backgroundColor: P.paper
      })
  }
}
