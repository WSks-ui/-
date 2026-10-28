import type { ArchiveRecord, HeritageSite } from '../domain/ArchiveDomain';
import { CITIES, COLLECTION_TAGS, ERAS, TYPES, activeRecords } from '../domain/ArchiveDomain';
import type { RoamChapter, RoamClue } from '../domain/Roaming';
import { HERITAGE_SITES } from '../data/HeritageCatalog';
import { ROAM_CHAPTERS } from '../data/RoamingCatalog';
import { PAPER_CITIES } from '../data/PaperJourneyCatalog';
import { ROAM_LIBRARY_ERAS, ROAM_LIBRARY_TYPES, roamingContentType } from '../data/CulturalContentIndex';
import { MARKET_CULTURES, MARKET_CULTURE_ERA, MARKET_CULTURE_TYPE, MarketCultureEntry } from '../data/MarketCultureCatalog';
import { siteIllustration } from './SiteRow';
import { PaperJourneyTheme as P } from './PaperJourneyTheme';

interface PaperLibraryPair { first: HeritageSite; second?: HeritageSite; }

// 文化库是一册可自由翻阅的资料。检索只改变本页视图，不把浏览、收藏和真实到访混成一种进度。
@Component
export struct PaperLibrarySection {
  @Prop records: ArchiveRecord[] = [];
  @Prop topClearance: number = 76;
  @Prop bottomClearance: number = 90;
  @Prop @Watch('initialCityChanged') initialCity: string = '全部城市';
  @Prop @Watch('initialScopeChanged') initialScope: string = '全部';
  scroller: Scroller = new Scroller();
  onOpen: (siteId: string) => void = () => {};
  onLegacy: (chapterId: string) => void = () => {};
  onPaper: (cityId: string) => void = () => {};
  onToggleFavorite: (siteId: string) => void = () => {};

  @State private keyword: string = '';
  @State private city: string = '全部城市';
  @State private era: string = '全部年代';
  @State private type: string = '全部类型';
  @State private scope: string = '全部';
  @State private favoriteTag: string = '全部分类';
  @State private sort: string = '目录';
  @State private filtersOpen: boolean = false;
  @State private contentWidth: number = 360;
  private initialized: boolean = false;
  private searchController: SearchController = new SearchController();

  aboutToAppear(): void {
    if (this.initialized) return;
    this.initialized = true;
    this.initialCityChanged(); this.initialScopeChanged();
  }

  private initialCityChanged(): void {
    // 只有外部明确改变入口参数才更新对应维度；同步回包和切回页签都不清空用户检索。
    if (CITIES.includes(this.initialCity)) this.city = this.initialCity;
  }

  private initialScopeChanged(): void {
    if (COLLECTION_TAGS.includes(this.initialScope)) {
      this.scope = '已收藏'; this.favoriteTag = this.initialScope;
    } else if (['全部', '已收藏', '已浏览', '未浏览'].includes(this.initialScope)) {
      this.scope = this.initialScope;
      this.favoriteTag = '全部分类';
    }
  }

  private eras(): string[] {
    const values = ERAS.concat(ROAM_LIBRARY_ERAS.filter(value => !ERAS.includes(value)));
    if (!values.includes(MARKET_CULTURE_ERA)) values.push(MARKET_CULTURE_ERA);
    return values;
  }
  private types(): string[] {
    const values = TYPES.concat(ROAM_LIBRARY_TYPES.filter(value => !TYPES.includes(value)));
    if (!values.includes(MARKET_CULTURE_TYPE)) values.push(MARKET_CULTURE_TYPE);
    return values;
  }
  private categories(): string[] { return ['全部分类'].concat(COLLECTION_TAGS); }
  private words(): string[] { return this.keyword.trim().toLowerCase().split(/\s+/).filter(value => !!value); }
  private matchesText(text: string): boolean { return this.words().every(word => text.toLowerCase().includes(word)); }

  private favorite(id: string): ArchiveRecord | undefined {
    return activeRecords(this.records, 'favorite').find(record => record.siteId === id);
  }

  private lastOpened(id: string): number {
    return this.records.reduce((latest: number, record: ArchiveRecord): number =>
      record.kind === 'progress' && !record.deleted && record.siteId === id && record.body === 'opened' &&
        record.id === `progress:${id}` ? Math.max(latest, record.updatedAt) : latest, 0);
  }

  private matchesScope(ids: string[]): boolean {
    const collected = ids.some(id => this.favorite(id) !== undefined);
    const opened = ids.some(id => this.lastOpened(id) > 0);
    if (this.scope === '已收藏' && !collected) return false;
    if (this.scope === '已浏览' && !opened) return false;
    if (this.scope === '未浏览' && opened) return false;
    return this.favoriteTag === '全部分类' || ids.some(id => this.favorite(id)?.tags.includes(this.favoriteTag));
  }

  private sites(): HeritageSite[] {
    const sites = HERITAGE_SITES.filter((site: HeritageSite): boolean =>
      (this.city === '全部城市' || site.city === this.city) &&
      (this.era === '全部年代' || site.era === this.era) &&
      (this.type === '全部类型' || site.type === this.type) && this.matchesScope([site.id]) &&
      this.matchesText(`${site.name} ${site.city} ${site.era} ${site.type} ${site.tags.join(' ')} ` +
        `${site.summary} ${site.overview} ${site.archaeology} ${site.history} ${site.poetry} ${site.travel}`));
    if (this.sort === '最近浏览') sites.sort((a, b) => this.lastOpened(b.id) - this.lastOpened(a.id));
    return sites;
  }

  private chapters(): RoamChapter[] {
    return ROAM_CHAPTERS.filter((chapter: RoamChapter): boolean => {
      if (this.city !== '全部城市' && chapter.city !== this.city) return false;
      const ids = [chapter.id].concat(chapter.clues.map(clue => clue.id));
      if (!this.matchesScope(ids)) return false;
      return chapter.clues.some((clue: RoamClue): boolean =>
        (this.era === '全部年代' || this.era === clue.era) &&
        (this.type === '全部类型' || this.type === roamingContentType(clue)) &&
        this.matchesText(`${chapter.city} ${chapter.title} ${chapter.opening} ${chapter.closing} ` +
          `${clue.title} ${clue.goal} ${clue.body} ${clue.era} ${roamingContentType(clue)}`));
    });
  }

  private marketEntries(): MarketCultureEntry[] {
    const entries = MARKET_CULTURES.filter((entry: MarketCultureEntry): boolean =>
      (this.city === '全部城市' || this.city === entry.city) &&
      (this.era === '全部年代' || this.era === entry.era) &&
      (this.type === '全部类型' || this.type === entry.type) && this.matchesScope([entry.id]) &&
      this.matchesText(`${entry.title} ${entry.subtitle} ${entry.city} ${entry.era} ${entry.type} ` +
        `${entry.tags.join(' ')} ${entry.quote} ${entry.body} ${entry.gameConnection} ${entry.source.title}`));
    if (this.sort === '最近浏览') entries.sort((a: MarketCultureEntry, b: MarketCultureEntry): number =>
      this.lastOpened(b.id) - this.lastOpened(a.id));
    return entries;
  }

  private featured(): HeritageSite | undefined {
    const sites = this.sites();
    if (!this.keyword && this.filterCount() === 0) {
      const longmen = sites.find(site => site.id === 'ly-longmen' && site.photos.length > 0);
      if (longmen) return longmen;
    }
    return sites.find(site => site.photos.length > 0);
  }

  private pairs(): PaperLibraryPair[] {
    const feature = this.featured();
    const sites = this.sites().filter(site => site.id !== feature?.id);
    const pairs: PaperLibraryPair[] = [];
    const step = this.contentWidth >= 760 ? 2 : 1;
    for (let index = 0; index < sites.length; index += step) {
      const pair: PaperLibraryPair = { first: sites[index] };
      if (step === 2 && index + 1 < sites.length) pair.second = sites[index + 1];
      pairs.push(pair);
    }
    return pairs;
  }

  private paperId(city: string): string { return PAPER_CITIES.find(item => item.city === city)?.id || ''; }
  private filterCount(): number {
    return (this.city !== '全部城市' ? 1 : 0) + (this.era !== '全部年代' ? 1 : 0) +
      (this.type !== '全部类型' ? 1 : 0) + (this.scope !== '全部' ? 1 : 0) +
      (this.favoriteTag !== '全部分类' ? 1 : 0) + (this.sort !== '目录' ? 1 : 0);
  }

  private summary(): string {
    const filters: string[] = [this.city, this.era, this.type, this.scope, this.favoriteTag]
      .filter(value => !['全部城市', '全部年代', '全部类型', '全部', '全部分类'].includes(value));
    return filters.length > 0 ? filters.join(' · ') : '五城资料，随时自由阅读';
  }

  private resetFilters(): void {
    this.city = '全部城市'; this.era = '全部年代'; this.type = '全部类型';
    this.scope = '全部'; this.favoriteTag = '全部分类'; this.sort = '目录';
  }

  private showCredit(site: HeritageSite): void {
    this.getUIContext().showAlertDialog({ title: site.photos.length > 0 ? '图片与署名' : '原创示意',
      message: site.photos.length > 0 ? `${site.photoCaption || site.name}\n\n${site.photoCredit || '署名见原文化档案'}\n\n资料：${site.source.title}` :
        '这幅图为应用原创学习示意，不是遗址照片或考古复原。',
      primaryButton: { value: '知道了', action: () => {} } });
  }

  @Builder
  private heading() {
    Column({ space: 7 }) {
      Text('沿 河 读 物').fontSize(11).letterSpacing(4).fontColor(P.amber)
      Row({ space: 14 }) {
        Text('文化库').fontSize(34).fontWeight(FontWeight.Medium).fontColor(P.paper).layoutWeight(1)
        Text('五城 / 藏在细节里').fontSize(11).fontColor(P.muted)
      }.width('100%')
      Text('从一处遗址，读到一座城。').fontSize(14).fontColor(P.paperSoft).lineHeight(22)
    }.width('100%').alignItems(HorizontalAlign.Start).margin({ bottom: 22 })
  }

  @Builder
  private searchBar() {
    Row({ space: 10 }) {
      Search({ value: this.keyword, controller: this.searchController, placeholder: '搜遗址、器物，或正文里的一句话' })
        .height(46).textFont({ size: 13 }).fontColor(P.paper).placeholderColor(P.dim).backgroundColor(P.deep).borderRadius(6)
        .searchButton('查找', { fontColor: P.amber }).layoutWeight(1).id('library-search')
        .onChange((value: string) => { this.keyword = value; })
        .onSubmit(() => this.searchController.stopEditing())
      Button({ type: ButtonType.Normal }) {
        Row({ space: 5 }) {
          Text('≡').fontSize(18).fontColor(P.paper)
          Text(this.filterCount() > 0 ? `${this.filterCount()}` : '筛选').fontSize(12).fontColor(P.paper)
        }
      }.height(46).padding({ left: 13, right: 13 }).backgroundColor(P.deep).borderRadius(6).id('library-filter')
        .onClick(() => { this.searchController.stopEditing(); this.filtersOpen = true; })
    }.width('100%')
    Row({ space: 8 }) {
      Text(this.summary()).fontSize(11).fontColor(P.muted).layoutWeight(1).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(`${this.sites().length} 处档案 · ${this.marketEntries().length} 篇文献`).fontSize(11).fontColor(P.dim).id('library-result-count')
    }.width('100%').padding({ top: 10, bottom: 19 })
  }

  @Builder
  private marketReadings() {
    if (this.marketEntries().length > 0) {
      Row({ space: 10 }) {
        Text('开封三夜，读生活').fontSize(21).fontWeight(FontWeight.Medium).fontColor(P.paper).layoutWeight(1)
        Text(`${this.marketEntries().length} 篇文献`).fontSize(10).fontColor(P.dim).id('library-market-count')
      }.width('100%').margin({ top: 1, bottom: 5 })
      Text('不必开市，也能自由读、选摘和写一页。').fontSize(11).fontColor(P.muted).width('100%').margin({ bottom: 6 })
      ForEach(this.marketEntries(), (entry: MarketCultureEntry) => {
        Row({ space: 12 }) {
          Button({ type: ButtonType.Normal }) {
            Column({ space: 7 }) {
              Text(entry.title).fontSize(17).fontWeight(FontWeight.Medium).fontColor(P.paper).width('100%')
              Text(`「${entry.quote.replace(/\n/g, ' ')}」`).fontSize(12).lineHeight(20).fontColor(P.paperSoft)
                .width('100%').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(`${entry.source.title} · ${this.lastOpened(entry.id) > 0 ? '已读' : '自由阅读'}`)
                .fontSize(10).fontColor(P.dim).width('100%')
            }.width('100%').alignItems(HorizontalAlign.Start)
          }.layoutWeight(1).padding(0).backgroundColor(Color.Transparent).borderRadius(0)
            .onClick(() => this.onOpen(entry.id)).id(`site-row-${entry.id}`)
          Button({ type: ButtonType.Normal }) {
            SymbolGlyph(this.favorite(entry.id) ? $r('sys.symbol.bookmark_fill') : $r('sys.symbol.bookmark'))
              .fontSize(18).fontColor([this.favorite(entry.id) ? P.amber : P.muted])
          }.width(34).height(38).padding(0).backgroundColor(Color.Transparent)
            .onClick(() => this.onToggleFavorite(entry.id)).id(`library-favorite-${entry.id}`)
            .accessibilityText(this.favorite(entry.id) ? '取消收藏' : '收藏这篇文献')
        }.width('100%').alignItems(VerticalAlign.Top).padding({ top: 16, bottom: 16 })
          .border({ width: { bottom: 0.6 }, color: P.line }).id(`library-market-${entry.id}`)
      }, (entry: MarketCultureEntry) => entry.id)
      Text('生活文献与下方遗址档案分别计数。').fontSize(10).fontColor(P.dim).width('100%').margin({ top: 9, bottom: 26 })
    }
  }

  @Builder
  private feature(site: HeritageSite) {
    Column() {
      Image($rawfile(site.photos[0])).width('100%').height(this.contentWidth >= 760 ? 245 : 190)
        .objectFit(ImageFit.Cover).accessibilityText(site.photoCaption || site.name)
        .onClick(() => this.onOpen(site.id))
      Column({ space: 9 }) {
        Row({ space: 9 }) {
          Text(`${site.city} · ${site.era}`).fontSize(11).fontColor(P.copper).layoutWeight(1)
          Button('图片署名 ↗', { type: ButtonType.Normal }).fontSize(10).height(26).fontColor(P.ink)
            .backgroundColor(Color.Transparent).padding(0).onClick(() => this.showCredit(site)).id(`library-credit-${site.id}`)
          Button({ type: ButtonType.Normal }) {
            SymbolGlyph(this.favorite(site.id) ? $r('sys.symbol.bookmark_fill') : $r('sys.symbol.bookmark'))
              .fontSize(17).fontColor([this.favorite(site.id) ? P.copper : P.ink])
          }.width(30).height(28).padding(0).backgroundColor(Color.Transparent)
            .onClick(() => this.onToggleFavorite(site.id)).id(`library-favorite-${site.id}`)
            .accessibilityText(this.favorite(site.id) ? '取消收藏' : '收藏这处资料')
        }.width('100%')
        Text(site.name).fontSize(23).fontWeight(FontWeight.Medium).fontColor(P.ink).width('100%')
        Text(site.summary).fontSize(13).fontColor(P.ink).lineHeight(22).width('100%')
        Row({ space: 10 }) {
          Button('读原文化档案  →', { type: ButtonType.Normal }).height(35).fontSize(12).fontColor(P.ink)
            .backgroundColor(Color.Transparent).padding(0).layoutWeight(1).onClick(() => this.onOpen(site.id))
            .id(`site-row-${site.id}`)
          if (this.paperId(site.city)) {
            Button('在纸上留一城', { type: ButtonType.Normal }).height(34).fontSize(11).fontColor(P.paper)
              .backgroundColor(P.moss).padding({ left: 12, right: 12 }).borderRadius(4)
              .onClick(() => this.onPaper(this.paperId(site.city)))
          }
        }.width('100%')
        Text(`${site.reviewStatus} · ${site.source.title}`).fontSize(10).fontColor(P.ink).opacity(0.62)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
      }.width('100%').padding(18).alignItems(HorizontalAlign.Start)
    }.width('100%').backgroundColor(P.paper).borderRadius(6).clip(true).margin({ bottom: 24 })
      .id('paper-library-feature')
  }

  @Builder
  private siteRow(site: HeritageSite) {
    Row({ space: 10 }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 12 }) {
          if (site.photos.length > 0) {
            Image($rawfile(site.photos[0])).width(82).height(90).objectFit(ImageFit.Cover).borderRadius(3)
              .accessibilityText(site.photoCaption || site.name)
          } else {
            Image(siteIllustration(site)).width(82).height(90).objectFit(ImageFit.Contain).padding(9)
              .backgroundColor(P.paper).borderRadius(3).accessibilityText('原创文化主题示意')
          }
          Column({ space: 6 }) {
            Text(`${site.city} / ${site.type}`).fontSize(10).fontColor(P.amber)
            Text(site.name).fontSize(16).fontWeight(FontWeight.Medium).fontColor(P.paper).maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
            Text(site.summary).fontSize(11).lineHeight(17).fontColor(P.muted).maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
            Text(`${site.era}${this.lastOpened(site.id) > 0 ? ' · 已读' : ''}`).fontSize(10).fontColor(P.dim)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%').alignItems(VerticalAlign.Top)
      }.layoutWeight(1).padding(0).backgroundColor(Color.Transparent).borderRadius(0).id(`site-row-${site.id}`)
        .onClick(() => this.onOpen(site.id)).accessibilityText(`${site.name}，查看文化档案`)
      Column({ space: 13 }) {
        Button({ type: ButtonType.Normal }) {
          SymbolGlyph(this.favorite(site.id) ? $r('sys.symbol.bookmark_fill') : $r('sys.symbol.bookmark'))
            .fontSize(17).fontColor([this.favorite(site.id) ? P.amber : P.muted])
        }.width(30).height(30).padding(0).backgroundColor(Color.Transparent)
          .onClick(() => this.onToggleFavorite(site.id)).id(`library-favorite-${site.id}`)
          .accessibilityText(this.favorite(site.id) ? '取消收藏' : '收藏这处资料')
        Button(site.photos.length > 0 ? '署名' : '示意', { type: ButtonType.Normal })
          .height(25).fontSize(9).fontColor(P.dim).padding(0).backgroundColor(Color.Transparent)
          .onClick(() => this.showCredit(site)).id(`library-credit-${site.id}`)
      }.width(32)
    }.width('100%').alignItems(VerticalAlign.Top).padding({ top: 15, bottom: 15 })
      .border({ width: { bottom: 0.6 }, color: P.line })
  }

  @Builder
  private readingChapters() {
    if (this.chapters().length > 0) {
      Row({ space: 10 }) {
        Text('再读一城').fontSize(20).fontWeight(FontWeight.Medium).fontColor(P.paper).layoutWeight(1)
        Text('篇章导读').fontSize(10).fontColor(P.dim)
      }.width('100%').margin({ top: 30, bottom: 7 })
      ForEach(this.chapters(), (chapter: RoamChapter) => {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 13 }) {
            Text(chapter.city.slice(0, 1)).fontSize(21).fontColor(P.amber).width(31)
            Column({ space: 5 }) {
              Text(chapter.title).fontSize(14).fontColor(P.paper).maxLines(1)
              Text(chapter.subtitle).fontSize(11).lineHeight(17).fontColor(P.muted).maxLines(2)
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Text('读 →').fontSize(11).fontColor(P.paperSoft)
          }.width('100%')
        }.width('100%').padding({ top: 15, bottom: 15 }).backgroundColor(Color.Transparent).borderRadius(0)
          .border({ width: { bottom: 0.6 }, color: P.line }).onClick(() => this.onLegacy(chapter.id))
          .id(`paper-library-chapter-${chapter.id}`)
      }, (chapter: RoamChapter) => chapter.id)
    }
  }

  @Builder
  private filterSheet() {
    Column({ space: 18 }) {
      Row() {
        Text('找到想读的那一页').fontSize(22).fontWeight(FontWeight.Medium).fontColor(P.ink).layoutWeight(1)
        Button('重置', { type: ButtonType.Normal }).fontSize(12).fontColor(P.copper)
          .backgroundColor(Color.Transparent).onClick(() => this.resetFilters()).id('library-reset')
      }.width('100%')
      Scroll() {
        Column({ space: 18 }) {
          Text('城市').fontSize(12).fontColor(P.ink).width('100%')
          Select(CITIES.map((value: string): SelectOption => ({ value }))).value(this.city).selected(CITIES.indexOf(this.city))
            .width('100%').height(44).font({ size: 14 }).fontColor(P.ink).backgroundColor('#E6DDCA').borderRadius(5)
            .onSelect((_index: number, value: string) => { this.city = value; }).id('library-city-select')
          Text('年代与类型').fontSize(12).fontColor(P.ink).width('100%')
          Select(this.eras().map((value: string): SelectOption => ({ value }))).value(this.era)
            .selected(this.eras().indexOf(this.era)).width('100%').height(44).font({ size: 13 }).fontColor(P.ink)
            .backgroundColor('#E6DDCA').onSelect((_index: number, value: string) => { this.era = value; }).id('library-era')
          Select(this.types().map((value: string): SelectOption => ({ value }))).value(this.type)
            .selected(this.types().indexOf(this.type)).width('100%').height(44).font({ size: 13 }).fontColor(P.ink)
            .backgroundColor('#E6DDCA').onSelect((_index: number, value: string) => { this.type = value; }).id('library-type')
          Text('阅读范围').fontSize(12).fontColor(P.ink).width('100%')
          Select(['全部', '已收藏', '已浏览', '未浏览'].map((value: string): SelectOption => ({ value }))).value(this.scope)
            .width('100%').height(44).font({ size: 13 }).fontColor(P.ink).backgroundColor('#E6DDCA')
            .onSelect((_index: number, value: string) => { this.scope = value; }).id('library-scope')
          Select(this.categories().map((value: string): SelectOption => ({ value }))).value(this.favoriteTag)
            .width('100%').height(44).font({ size: 13 }).fontColor(P.ink).backgroundColor('#E6DDCA')
            .onSelect((_index: number, value: string) => { this.favoriteTag = value; }).id('library-category')
          Text('阅读顺序').fontSize(12).fontColor(P.ink).width('100%')
          Select(['目录', '最近浏览'].map((value: string): SelectOption => ({ value }))).value(this.sort)
            .width('100%').height(44).font({ size: 13 }).fontColor(P.ink).backgroundColor('#E6DDCA')
            .onSelect((_index: number, value: string) => { this.sort = value; }).id('library-sort')
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ bottom: 8 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
      Button(`翻开 ${this.sites().length} 处档案 · ${this.marketEntries().length} 篇文献 · ${this.chapters().length} 篇导读`, { type: ButtonType.Normal })
        .width('100%').height(46).fontSize(14).fontColor(P.paper).backgroundColor(P.moss).borderRadius(5)
        .onClick(() => { this.filtersOpen = false; }).id('library-filter-done')
    }.width('100%').height('100%').padding({ left: 24, right: 24, top: 24, bottom: 25 }).backgroundColor(P.paper)
  }

  build() {
    Scroll(this.scroller) {
      Column() {
        this.heading()
        this.searchBar()
        this.marketReadings()
        if (this.featured()) { this.feature(this.featured()!) }
        ForEach(this.pairs(), (pair: PaperLibraryPair) => {
          Row({ space: 28 }) {
            Column() { this.siteRow(pair.first) }.layoutWeight(1)
            if (this.contentWidth >= 760) {
              Column() { if (pair.second) { this.siteRow(pair.second) } }.layoutWeight(1)
            }
          }.width('100%').alignItems(VerticalAlign.Top)
        }, (pair: PaperLibraryPair) => `${pair.first.id}-${pair.second?.id || ''}`)
        if (this.sites().length === 0 && this.marketEntries().length === 0 && this.chapters().length === 0) {
          Column({ space: 12 }) {
            Text('这一页还没有找到').fontSize(21).fontColor(P.paper)
            Text('换一个关键词，或放宽筛选，再沿河读一读。').fontSize(13).fontColor(P.muted)
            Button('重置筛选', { type: ButtonType.Normal }).fontSize(12).fontColor(P.amber)
              .backgroundColor(P.deep).onClick(() => this.resetFilters())
          }.width('100%').padding({ top: 45, bottom: 45 })
        }
        this.readingChapters()
        Text('文化资料为初稿待校审。照片保留作者与许可署名；原创图景与考古复原分别表达。')
          .fontSize(10).lineHeight(18).fontColor(P.dim).width('100%').margin({ top: 25 })
      }.width('100%').constraintSize({ maxWidth: 1100 }).alignItems(HorizontalAlign.Start)
        .padding({ left: 22, right: 22, top: this.topClearance, bottom: this.bottomClearance + 20 })
        .onAreaChange((_old: Area, area: Area) => { this.contentWidth = Number(area.width) - 44; })
    }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring).backgroundColor(P.night)
      .id('paper-library').bindSheet($$this.filtersOpen, this.filterSheet(), {
        height: SheetSize.LARGE, showClose: false, dragBar: true, backgroundColor: P.paper
      })
  }
}
