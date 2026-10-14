import { common } from '@kit.AbilityKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { HdsNavigation, HdsNavigationTitleMode, HdsTabs, HdsTabsController } from '@kit.UIDesignKit';
import {
  activeRecords, ArchiveRecord, ArchiveSnapshot, CITIES, COLLECTION_TAGS, copySnapshot,
  emptySnapshot, ERAS, filterSites, HeritageSite, nextTimestamp, putRecord,
  Recommendation, recommendSites, TYPES
} from '../domain/ArchiveDomain';
import { HERITAGE_SITES } from '../data/HeritageCatalog';
import { LocalArchiveRepository } from '../data/LocalArchiveRepository';
import { HarmonyEffects } from '../platform/HarmonyEffects';
import { SiteRow } from '../components/SiteRow';
import { SiteDetail } from '../components/SiteDetail';
import { SiteGrid } from '../components/SiteCard';
import { RiverBackdrop } from '../components/RiverBackdrop';
import { ArchiveTheme as T, ArchiveType as F } from '../components/ArchiveTheme';
import { ArchiveStat, ArchiveStatusRow, PaperSurface } from '../components/ArchiveInfo';
import { DEFAULT_ARCHIVE_STORE } from '../platform/ArchiveLaunch';
import { CultureAtlas } from '../components/CultureAtlas';
import { AccountPanel } from '../components/AccountPanel';
import { AccountSyncClient } from '../sync/AccountSyncClient';
import { AccountView, accountErrorMessage, accountStoreName, changedAccountView, guestAccountView } from '../domain/AccountSync';

interface SiteRoute { siteId: string; }

@Entry({ useSharedStorage: true })
@Component
struct Index {
  @LocalStorageProp('archiveStoreName') archiveStoreName: string = DEFAULT_ARCHIVE_STORE;
  @LocalStorageProp('appForeground') appForeground: boolean = true;
  @State accountView: AccountView = guestAccountView();
  @State snapshot: ArchiveSnapshot = emptySnapshot('');
  @State ready: boolean = false;
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State saving: boolean = false;
  @State keyword: string = '';
  @State city: string = CITIES[0];
  @State era: string = ERAS[0];
  @State type: string = TYPES[0];
  @State collectionTag: string = '全部标签';
  @State currentTab: number = 0;
  @State wide: boolean = false;
  @State featuredHeight: number = 242;
  @State memoryHeight: number = 115;
  @State deviceEntryHeight: number = 115;
  private paths: NavPathStack = new NavPathStack();
  private tabsController: HdsTabsController = new HdsTabsController();
  private exploreScroller: Scroller = new Scroller();
  private archiveScroller: Scroller = new Scroller();
  private deviceScroller: Scroller = new Scroller();
  private searchController: SearchController = new SearchController();
  private repository: LocalArchiveRepository | undefined = undefined;
  private accountClient: AccountSyncClient | undefined = undefined;
  private accountTimer: number = -1;
  private accountGeneration: number = 0;

  aboutToAppear(): void {
    this.loadArchive();
    this.configureAccount();
    // 前台每 5 秒交换已确认保存的数据；写锁 / 在途请求时跳过本次，不堆积轮询。
    // 后台只保留本机档案，避免无意义网络请求；返回前台后继续真实交换。
    this.accountTimer = setInterval(() => { if (this.appForeground) this.syncAccount(); }, 5000);
  }

  aboutToDisappear(): void {
    this.accountGeneration++;
    if (this.accountTimer >= 0) clearInterval(this.accountTimer);
    this.accountClient?.clearSession();
  }

  private async configureAccount(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.accountClient = new AccountSyncClient(context);
    this.accountView = changedAccountView(this.accountView, { serviceConfigured: await this.accountClient.configure() });
  }

  private async authenticateAccount(username: string, password: string, register: boolean): Promise<boolean> {
    if (this.saving || this.accountView.busy || !this.accountClient) return false;
    this.accountView = changedAccountView(this.accountView, { busy: true, message: '' });
    try {
      const session = await this.accountClient.authenticate(username, password, register);
      const testStore = this.archiveStoreName.startsWith('yunheji_test_ui_') ? this.archiveStoreName : '';
      const repository = new LocalArchiveRepository(this.getUIContext().getHostContext() as common.UIAbilityContext,
        accountStoreName(session.accountId, testStore));
      const snapshot = await repository.load();
      this.accountGeneration++;
      // 登录等待期间可能切到了别的页面。身份切换清理旧路由，避免仍打开游客笔记
      // 编辑器并把其草稿保存进新的账号档案；游客已确认记录依然留在原库。
      this.paths.clear();
      this.repository = repository;
      this.snapshot = snapshot;
      this.keyword = ''; this.city = CITIES[0]; this.era = ERAS[0]; this.type = TYPES[0];
      this.accountView = changedAccountView(guestAccountView(), { signedIn: true, username: session.username, serviceConfigured: true });
      await this.syncAccount();
      return true;
    } catch (error) {
      this.accountClient.clearSession();
      this.accountView = changedAccountView(this.accountView, { busy: false, message: accountErrorMessage((error as Error).message) });
      return false;
    }
  }

  private async logoutAccount(): Promise<void> {
    if (this.saving || this.accountView.busy || this.accountView.syncing || !this.accountClient) return;
    this.accountView = changedAccountView(this.accountView, { busy: true });
    try {
      // 先确认游客档案可以读取，再切换身份，损坏时不以空记录覆盖。
      const guest = new LocalArchiveRepository(this.getUIContext().getHostContext() as common.UIAbilityContext, this.archiveStoreName);
      const snapshot = await guest.load();
      try { await this.accountClient.logout(); } catch { this.accountClient.clearSession(); }
      this.accountGeneration++;
      this.repository = guest;
      this.snapshot = snapshot;
      this.accountView = changedAccountView(guestAccountView(), { serviceConfigured: this.accountView.serviceConfigured });
    } catch {
      this.accountView = changedAccountView(this.accountView, { busy: false, message: '本机档案暂时无法读取，当前账号记录仍保留。' });
    }
  }

  private async syncAccount(): Promise<void> {
    if (!this.ready || this.saving || !this.accountClient || !this.accountView.signedIn ||
      this.accountView.busy || this.accountView.syncing) return;
    const generation = this.accountGeneration;
    this.accountView = changedAccountView(this.accountView, { syncing: true });
    try {
      const reply = await this.accountClient.exchange(copySnapshot(this.snapshot));
      if (generation !== this.accountGeneration) return;
      // 在途请求期间允许本机继续编辑，合并时必须使用当前快照，不回写发送时的旧值。
      // 若本机正在落盘，下一轮再合并；成功时间只在远端已响应且本机保存确认后发布。
      if (this.saving) return;
      const next = this.accountClient.mergedSnapshot(this.snapshot, reply);
      if (JSON.stringify(next.records) !== JSON.stringify(this.snapshot.records) && !await this.commit(next, false)) {
        throw new Error('ACCOUNT_LOCAL_SAVE_FAILED');
      }
      this.accountView = changedAccountView(this.accountView, { lastSync: Date.now(), otherDevices: reply.otherDevices,
        conflictCount: reply.conflictCount, message: '' });
    } catch (error) {
      if (generation === this.accountGeneration) {
        this.accountView = changedAccountView(this.accountView, { message: accountErrorMessage((error as Error).message) });
      }
    } finally {
      if (generation === this.accountGeneration) this.accountView = changedAccountView(this.accountView, { syncing: false });
    }
  }

  private async loadArchive(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.repository = new LocalArchiveRepository(context, this.archiveStoreName);
      this.snapshot = await this.repository.load();
      this.ready = true;
    } catch {
      this.errorMessage = '本地档案读取失败。原数据未被清空，请重试；持续失败时请保留应用数据并联系开发者。';
      this.ready = false;
    } finally { this.loading = false; }
  }

  private async commit(next: ArchiveSnapshot, syncAfter: boolean = true): Promise<boolean> {
    // 所有页面共用写锁；先完成落盘，再发布新状态，避免失败时界面误报“已保存”。
    if (this.saving || this.accountView.busy || !this.ready || !this.repository) return false;
    this.saving = true;
    try {
      await this.repository.save(next);
      this.snapshot = next;
      this.errorMessage = '';
      return true;
    } catch {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '保存失败，修改尚未落盘，请重试。' });
      } catch {
        this.errorMessage = '保存失败，修改尚未落盘，请重试。';
      }
      return false;
    } finally {
      this.saving = false;
      if (syncAfter) this.syncAccount();
    }
  }

  private async openSite(site: HeritageSite): Promise<void> {
    if (this.saving || this.accountView.busy) return;
    const next = copySnapshot(this.snapshot);
    const progress: ArchiveRecord = {
      id: `progress:${site.id}`, kind: 'progress', siteId: site.id, body: 'opened',
      tags: [], updatedAt: nextTimestamp(next.records, Date.now()), deviceId: next.deviceId, deleted: false
    };
    next.records = putRecord(next.records, progress);
    await this.commit(next);
    const route: SiteRoute = { siteId: site.id };
    this.paths.pushPathByName('site', route, !this.snapshot.reducedMotion);
  }

  private results(): HeritageSite[] {
    return filterSites(HERITAGE_SITES, { keyword: this.keyword, city: this.city, era: this.era, type: this.type });
  }

  private collections(): HeritageSite[] {
    const records = activeRecords(this.snapshot.records, 'favorite');
    return HERITAGE_SITES.filter((site: HeritageSite) => records.some((record: ArchiveRecord) =>
      record.siteId === site.id && (this.collectionTag === '全部标签' || record.tags.includes(this.collectionTag))));
  }

  private siteFor(id: string): HeritageSite | undefined {
    return HERITAGE_SITES.find((site: HeritageSite) => site.id === id);
  }

  @Builder
  destination(name: string, parameter: Object) {
    if (name === 'site') {
      SiteDetail({
        site: this.siteFor((parameter as SiteRoute).siteId) || HERITAGE_SITES[0],
        snapshot: $snapshot,
        onCommit: (next: ArchiveSnapshot): Promise<boolean> => this.commit(next),
        onOpen: (site: HeritageSite) => this.openSite(site)
      })
    } else if (name === 'culture') {
      CultureAtlas({ snapshot: $snapshot, onOpen: (site: HeritageSite) => this.openSite(site) })
    }
  }

  @Builder
  cultureEntry() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 14 }) {
        SymbolGlyph($r('sys.symbol.link')).fontSize(28).fontColor([T.accent])
        Column({ space: 5 }) {
          Text('文明连线').fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink)
          Text('五城图谱 · 我的专题 · 档案对照').fontSize(F.caption).fontColor(T.muted)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        SymbolGlyph($r('sys.symbol.arrow_right')).fontSize(19).fontColor([T.accent])
      }.width('100%').padding({ top: 18, bottom: 18 })
    }.width('100%').padding(0).backgroundColor(Color.Transparent).borderRadius(8)
      .id('culture-atlas-entry').accessibilityText('打开文明连线')
      .onClick(() => this.paths.pushPathByName('culture', 'atlas', !this.snapshot.reducedMotion))
  }

  @Builder
  heading(title: string, subtitle: string) {
    Column({ space: 7 }) {
      Text(title).fontSize(F.display).fontWeight(FontWeight.Bold).fontColor(T.ink)
      Text(subtitle).fontSize(F.small).fontColor(T.muted).lineHeight(22)
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 12, bottom: 24 })
  }

  @Builder
  emptyState(title: string, symbol: Resource, message: string = '') {
    Column({ space: 12 }) {
      Stack() {
        Rect().width(56).height(56).radius(16).fill(T.accentSoft).rotate({ angle: -6 })
        SymbolGlyph(symbol).fontSize(27).fontColor([T.accent])
      }.width(64).height(64)
      Text(title).fontSize(F.card).fontWeight(FontWeight.Medium).fontColor(T.ink).textAlign(TextAlign.Center)
      if (message) {
        Text(message).fontSize(F.caption).fontColor(T.muted).lineHeight(20).textAlign(TextAlign.Center)
      }
    }.width('100%').padding({ top: 28, bottom: 28, left: 16, right: 16 })
      .backgroundColor(T.surface).borderRadius(T.cardRadius).margin({ bottom: 12 })
  }

  @Builder
  header() {
    Row({ space: 10 }) {
      Text('云河纪').fontSize(F.title).fontWeight(FontWeight.Bold).fontColor(T.ink)
        .padding({ left: 16, right: 16, top: 10, bottom: 10 }).borderRadius(24)
        .backgroundColor(this.snapshot.lightEnabled && !this.snapshot.reducedMotion && HarmonyEffects.supported() ? Color.Transparent : T.surface)
        .systemMaterial(HarmonyEffects.titleCapsule(this.snapshot.lightEnabled, this.snapshot.reducedMotion)).id('top-brand')
      Text('初稿待校审').fontSize(F.caption).fontColor(T.accent)
        .padding({ left: 8, right: 8, top: 5, bottom: 5 }).backgroundColor(T.accentSoft).borderRadius(6)
      Blank()
      Button({ type: ButtonType.Normal }) {
        SymbolGlyph($r('sys.symbol.bookmark')).fontSize(23).fontColor([T.accent])
      }.width(44).height(44).borderRadius(22)
        .backgroundColor(this.snapshot.lightEnabled && !this.snapshot.reducedMotion && HarmonyEffects.supported() ? Color.Transparent : T.surface)
        .systemMaterial(HarmonyEffects.titleCapsule(this.snapshot.lightEnabled, this.snapshot.reducedMotion))
        .accessibilityText('打开我的收藏').id('top-collection').onClick(() => { this.currentTab = 1; })
    }.width('100%').padding({ left: 16, right: 16 }).id('top-navigation-content')
  }

  @Builder
  sectionTitle(title: string, caption: string = '') {
    Row({ space: 8 }) {
      Text(title).fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink).layoutWeight(1)
      if (caption) { Text(caption).fontSize(F.caption).fontColor(T.muted) }
    }.width('100%').padding({ top: 16, bottom: 14 })
  }

  @Builder
  sticker(icon: Resource, color: ResourceColor, ink: ResourceColor, angle: number) {
    Stack() {
      Rect().width(40).height(44).radius(12).fill(color).border({ width: 2, color: T.surface, radius: 12 })
      SymbolGlyph(icon).fontSize(24).fontColor([ink])
    }.width(44).height(48).rotate({ angle }).hitTestBehavior(HitTestMode.None)
  }

  @Builder
  entryBoard() {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.TopStart }) {
        PaperSurface({ contentHeight: this.featuredHeight, color: T.surface, surfaceId: 'featured-paper' })
        Column({ space: 6 }) {
          Text('从彩陶读起').fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink).width('78%')
          Text('仰韶村 · 文明的线索').fontSize(F.caption).fontColor(T.muted)
          Stack() {
            Image($r('app.media.motif_city')).width(72).height(92).objectFit(ImageFit.Cover)
              .border({ width: 4, color: T.surface }).borderRadius(8)
              .rotate({ angle: 11 }).translate({ x: 24, y: -2 })
            Image($r('app.media.motif_pottery')).width(82).height(102).objectFit(ImageFit.Cover)
              .border({ width: 4, color: T.surface }).borderRadius(8)
              .rotate({ angle: -9 }).translate({ x: -19, y: 3 })
          }.width('100%').height(114).accessibilityText('文化主题插画，非文物复原')
          Button({ type: ButtonType.Normal }) {
            Row({ space: 6 }) {
              Text('打开档案').fontSize(F.small).fontColor(T.onAccent)
              SymbolGlyph($r('sys.symbol.arrow_right')).fontSize(14).fontColor([T.onAccent])
            }.justifyContent(FlexAlign.Center)
          }.width('100%').height(44).borderRadius(8).backgroundColor(T.accent)
            .id('featured-site').onClick(() => this.openSite(HERITAGE_SITES[0]))
        }.width('100%').padding({ left: 14, right: 14, top: 17, bottom: 14 }).alignItems(HorizontalAlign.Start)
          // 以真实文字布局测量纸片，而不是从 Context 猜测字体倍率。应用内字体配置更新
          // 可能先于 Context.config，测量独立内容能覆盖换行与系统字号调整。
          .onAreaChange((_old: Area, area: Area) => { this.featuredHeight = Math.max(242, Math.ceil(Number(area.height))); })
          .id('featured-content')
        Row() { this.sticker($r('sys.symbol.bookmark'), T.rose, T.accent, 9) }
          .width('100%').justifyContent(FlexAlign.End).translate({ y: -10 }).hitTestBehavior(HitTestMode.None)
      }.layoutWeight(1)
      Column({ space: 12 }) {
        Stack({ alignContent: Alignment.TopStart }) {
          PaperSurface({ contentHeight: this.memoryHeight, color: T.surface, surfaceId: 'memory-paper' })
          Column({ space: 8 }) {
            Text('河流记忆').fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink).width('78%')
            Text(`${activeRecords(this.snapshot.records, 'favorite').length} 处收藏 · ${activeRecords(this.snapshot.records, 'note').length} 条笔记`)
              .fontSize(F.caption).fontColor(T.muted).maxLines(2)
            Row({ space: 5 }) {
              Text('翻开我的记录').fontSize(F.caption).fontColor(T.accent)
              SymbolGlyph($r('sys.symbol.arrow_right')).fontSize(13).fontColor([T.accent])
            }
          }.width('100%').padding({ top: 17, left: 14, right: 10, bottom: 18 }).alignItems(HorizontalAlign.Start)
            .onAreaChange((_old: Area, area: Area) => { this.memoryHeight = Math.max(115, Math.ceil(Number(area.height))); })
            .id('memory-content')
          Row() { this.sticker($r('sys.symbol.square_and_pencil'), T.blue, T.blueInk, 8) }
            .width('100%').justifyContent(FlexAlign.End).translate({ y: -10 }).hitTestBehavior(HitTestMode.None)
        }.width('100%').id('memory-entry').accessibilityText('翻开我的收藏和笔记')
          .onClick(() => { this.currentTab = 1; })
        Stack({ alignContent: Alignment.TopStart }) {
          PaperSurface({ contentHeight: this.deviceEntryHeight, color: T.mint, surfaceId: 'device-entry-paper' })
          Column({ space: 8 }) {
            Text('随身档案').fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink).width('78%')
            Text(`${HERITAGE_SITES.length} 份文化初稿 · 本地保存`).fontSize(F.caption).fontColor(T.muted).maxLines(2)
            Row({ space: 5 }) {
              Text('查看档案状态').fontSize(F.caption).fontColor(T.mintInk)
              SymbolGlyph($r('sys.symbol.arrow_right')).fontSize(13).fontColor([T.mintInk])
            }
          }.width('100%').padding({ top: 17, left: 14, right: 10, bottom: 18 }).alignItems(HorizontalAlign.Start)
            .onAreaChange((_old: Area, area: Area) => { this.deviceEntryHeight = Math.max(115, Math.ceil(Number(area.height))); })
            .id('device-entry-content')
          Row() { this.sticker($r('sys.symbol.folder'), T.yellow, T.yellowInk, -8) }
            .width('100%').justifyContent(FlexAlign.End).translate({ y: -10 }).hitTestBehavior(HitTestMode.None)
        }.width('100%').accessibilityText('查看本地档案与设备状态').onClick(() => { this.currentTab = 2; })
      }.layoutWeight(1)
    }.width('100%').alignItems(VerticalAlign.Top).margin({ top: 4, bottom: 20 })
  }

  @Builder
  cityIndex() {
    Row({ space: 4 }) {
      ForEach(CITIES.slice(1), (city: string, index: number) => {
        Button({ type: ButtonType.Normal }) {
          Column({ space: 8 }) {
            Stack() {
              Rect().width(40).height(42).radius(12)
                .fill([T.rose, T.blue, T.mint, T.yellow, T.blue][index]).rotate({ angle: index % 2 === 0 ? -6 : 6 })
              SymbolGlyph([$r('sys.symbol.map'), $r('sys.symbol.square_grid_2x2'), $r('sys.symbol.folder'),
                $r('sys.symbol.bookmark'), $r('sys.symbol.square_and_pencil')][index])
                .fontSize(22).fontColor([[T.accent], [T.blueInk], [T.mintInk], [T.yellowInk], [T.blueInk]][index])
            }.width(44).height(44)
            Text(city).fontSize(F.caption).fontWeight(this.city === city ? FontWeight.Bold : FontWeight.Regular)
              .fontColor(this.city === city ? T.accent : T.ink).maxLines(1)
            Row().width(14).height(3).borderRadius(2).backgroundColor(this.city === city ? T.accent : Color.Transparent)
          }.width('100%')
        }.layoutWeight(1).padding({ top: 6, bottom: 6 }).backgroundColor(Color.Transparent).borderRadius(8)
          .onClick(() => { this.city = this.city === city ? CITIES[0] : city; })
          .accessibilityText(`筛选${city}`).id(`city-${index}`)
      }, (city: string) => city)
    }.width('100%').margin({ bottom: 18 })
  }

  private tabStyle(index: number, title: string, icon: Resource): BottomTabBarStyle {
    // 原生 BottomTabBarStyle 才能由 HdsTabs 接管胶囊、选中镜片与触摸反馈。
    // id 绑定到官方页签，保留自动化与无障碍定位，不再返回自绘的三个白色按钮。
    return new BottomTabBarStyle({ normal: new SymbolGlyphModifier(icon).fontColor([T.muted]),
      selected: new SymbolGlyphModifier(icon).fontColor([T.accent]) }, title)
      .labelStyle({ selectedColor: T.accent, unselectedColor: T.muted }).id(`tab-${index}`);
  }

  private topClearance(): number { return Math.max(76, this.getUIContext().fp2px(64) / this.getUIContext().vp2px(1)); }

  private dockClearance(): number { return Math.max(96, this.getUIContext().fp2px(80) / this.getUIContext().vp2px(1)); }

  private statusBarInk(): string {
    // HDS 的系统状态栏只接受颜色字符串；从当前资源配置取 ARGB，外观切换时跟随语义色。
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try { return `#${context.resourceManager.getColorByNameSync('ink').toString(16).padStart(8, '0')}`; }
    catch { return '#FF2B2225'; }
  }

  @Builder
  explore() {
    Scroll(this.exploreScroller) {
      Column() {
        this.heading('沿河，遇见文明', '五座城，把黄河故事慢慢读完。')
        this.cultureEntry()
        this.entryBoard()
        this.cityIndex()
        Search({ value: this.keyword, controller: this.searchController, placeholder: '搜索遗址、城市或文化线索' })
          .searchButton('检索', { fontColor: T.accent })
          .height(48).backgroundColor(T.surface).fontColor(T.ink).placeholderColor(T.muted).borderRadius(T.inputRadius)
          .onChange((value: string) => { this.keyword = value; }).id('site-search')
          // 原生提交时结束编辑，释放键盘占用，让结果区重新获得可用高度。
          .onSubmit(() => this.searchController.stopEditing())
        Row({ space: 8 }) {
          Select(CITIES.map((value: string): SelectOption => ({ value }))).value(this.city === CITIES[0] ? '城市' : this.city)
            .selected(CITIES.indexOf(this.city)).font({ size: F.small }).fontColor(T.ink).backgroundColor(T.surface)
            .height(44).borderRadius(T.inputRadius).padding({ left: 10, right: 10 }).layoutWeight(1)
            .onSelect((_index: number, value: string) => { this.city = value; }).id('filter-city')
          Select(ERAS.map((value: string): SelectOption => ({ value }))).value(this.era === ERAS[0] ? '年代' : this.era)
            .selected(ERAS.indexOf(this.era)).font({ size: F.small }).fontColor(T.ink).backgroundColor(T.surface)
            .height(44).borderRadius(T.inputRadius).padding({ left: 10, right: 10 }).layoutWeight(1)
            .onSelect((_index: number, value: string) => { this.era = value; }).id('filter-era')
          Select(TYPES.map((value: string): SelectOption => ({ value }))).value(this.type === TYPES[0] ? '类型' : this.type)
            .selected(TYPES.indexOf(this.type)).font({ size: F.small }).fontColor(T.ink).backgroundColor(T.surface)
            .height(44).borderRadius(T.inputRadius).padding({ left: 10, right: 10 }).layoutWeight(1)
            .onSelect((_index: number, value: string) => { this.type = value; }).id('filter-type')
        }.width('100%').margin({ top: 10, bottom: 8 })
        Row() {
          Text(`${this.results().length} 处文化遗产`).fontSize(F.card).fontWeight(FontWeight.Bold)
            .fontColor(T.ink).layoutWeight(1).id('search-result-count')
          Button('重置', { type: ButtonType.Normal }).fontSize(13).height(40).borderRadius(8)
            .backgroundColor(Color.Transparent).fontColor(T.accent).id('reset-filters')
            .onClick(() => { this.keyword = ''; this.city = CITIES[0]; this.era = ERAS[0]; this.type = TYPES[0]; })
        }.width('100%')
        if (this.results().length === 0) {
          this.emptyState('没有符合条件的档案', $r('sys.symbol.magnifyingglass'))
        }
        SiteGrid({ sites: this.results(), gridId: 'explore-site-grid',
          collectedIds: activeRecords(this.snapshot.records, 'favorite').map((record: ArchiveRecord) => record.siteId),
          onOpen: (site: HeritageSite) => this.openSite(site) })
        this.sectionTitle('循迹而行', '关联档案')
        ForEach(recommendSites(HERITAGE_SITES, this.snapshot.records), (item: Recommendation) => {
          SiteRow({ site: item.site, reason: item.reason, onOpen: (site: HeritageSite) => this.openSite(site) })
        }, (item: Recommendation) => item.site.id)
        Text('图形为主题示意 · 文化内容初稿待校审').fontSize(F.caption).fontColor(T.muted)
          .padding({ top: 8, bottom: 12 })
      }.width('100%').constraintSize({ maxWidth: 760 })
        .padding({ left: 16, right: 16, top: this.topClearance(), bottom: this.dockClearance() })
    }.height('100%').width('100%').align(Alignment.Top).scrollBar(BarState.Auto).id('explore-scroll')
  }

  @Builder
  archive() {
    Scroll(this.archiveScroller) {
      Column() {
        this.heading('我的河流记忆', '走过的线索，写给以后的自己。')
        Row() {
          ArchiveStat({ value: `${activeRecords(this.snapshot.records, 'favorite').length}`, label: '收藏', valueId: 'collection-count' })
          ArchiveStat({ value: `${activeRecords(this.snapshot.records, 'note').length}`, label: '笔记', valueId: 'note-count' })
          ArchiveStat({ value: `${activeRecords(this.snapshot.records, 'progress').length}`, label: '已浏览', valueId: 'visited-count' })
        }.width('100%').padding({ top: 20, bottom: 20 }).backgroundColor(T.surface).borderRadius(T.cardRadius)
        Row() {
          Text('收藏档案').fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink).layoutWeight(1)
          Select(['全部标签'].concat(COLLECTION_TAGS).map((value: string): SelectOption => ({ value })))
            .value(this.collectionTag).font({ size: F.small }).fontColor(T.ink).backgroundColor(T.surface)
            .height(44).borderRadius(10)
            .onSelect((_index: number, value: string) => { this.collectionTag = value; }).id('collection-filter')
        }.width('100%').padding({ top: 22, bottom: 12 })
        if (this.collections().length === 0) {
          this.emptyState('这个分类还没有收藏', $r('sys.symbol.bookmark'), '遇到喜欢的文化档案，点一下收藏。')
        }
        SiteGrid({ sites: this.collections(), gridId: 'archive-site-grid',
          collectedIds: activeRecords(this.snapshot.records, 'favorite').map((record: ArchiveRecord) => record.siteId),
          onOpen: (site: HeritageSite) => this.openSite(site) })
        this.sectionTitle('最近笔记', '个人学习记录')
        if (activeRecords(this.snapshot.records, 'note').length === 0) {
          this.emptyState('还没有学习记录', $r('sys.symbol.square_and_pencil'), '在档案详情里，记下你的观察和思考。')
        }
        ForEach(activeRecords(this.snapshot.records, 'note'), (note: ArchiveRecord) => {
          Button({ type: ButtonType.Normal }) {
            Column({ space: 10 }) {
              Row({ space: 8 }) {
                SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(18).fontColor([T.yellowInk])
                Text(this.siteFor(note.siteId)?.name || '未收录档案').fontSize(F.small).fontWeight(FontWeight.Medium)
                  .fontColor(T.accent).layoutWeight(1)
                SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(13).fontColor([T.tertiary])
              }.width('100%')
              Text(note.body).fontSize(F.small).lineHeight(24).maxLines(3)
                .textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor(T.ink)
              Text(new Date(note.updatedAt).toLocaleString()).fontSize(F.caption).fontColor(T.muted)
            }.alignItems(HorizontalAlign.Start).width('100%').padding(16)
          }.width('100%').padding(0).borderRadius(T.cardRadius).backgroundColor(T.surface).margin({ bottom: 12 })
            .onClick(() => {
              const site = this.siteFor(note.siteId);
              if (site) this.openSite(site);
            })
        }, (note: ArchiveRecord) => `${note.id}:${note.updatedAt}`)
      }.width('100%').constraintSize({ maxWidth: 760 })
        .padding({ left: 16, right: 16, top: this.topClearance(), bottom: this.dockClearance() })
    }.height('100%').width('100%').align(Alignment.Top).id('archive-scroll')
  }

  @Builder
  device() {
    Scroll(this.deviceScroller) {
      Column() {
        this.heading('我的随身档案', this.accountView.signedIn ? '同一账号，让收藏与记忆相随。' : '本机记录，登录后使用账号档案。')
        AccountPanel({ view: this.accountView,
          onAuthenticate: (username: string, password: string, register: boolean): Promise<boolean> => this.authenticateAccount(username, password, register),
          onLogout: () => { this.logoutAccount(); }, onSync: () => { this.syncAccount(); } })
        Row({ space: 14 }) {
          Stack() {
            Rect().width(56).height(56).radius(16).fill(T.rose).rotate({ angle: -6 })
            SymbolGlyph($r('sys.symbol.folder')).fontSize(28).fontColor([T.accent])
          }.width(60).height(60)
          Column({ space: 6 }) {
            Text(this.saving ? '正在保存档案' : '档案保存在本机').fontSize(F.card).fontWeight(FontWeight.Bold).fontColor(T.ink)
            Text('收藏与笔记，随时翻阅。').fontSize(F.caption).fontColor(T.muted).lineHeight(20)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%').padding(18).backgroundColor(T.surface).borderRadius(T.cardRadius).margin({ top: 16 })
        this.sectionTitle('档案状态', '本地模式')
        Column() {
          ArchiveStatusRow({ label: '本地存储', value: this.saving ? '正在保存' : '已就绪' })
          Divider().color(T.line)
          ArchiveStatusRow({ label: '文化资源', value: `${HERITAGE_SITES.length} 份预置初稿` })
          Divider().color(T.line)
          ArchiveStatusRow({ label: '已浏览', value: `${activeRecords(this.snapshot.records, 'progress').length} 处` })
        }.width('100%').padding({ left: 18, right: 18 }).backgroundColor(T.surface).borderRadius(T.cardRadius)
        this.sectionTitle('跨端连接')
        Column() {
          // 在线数来自已认证服务端最近 45 秒的真实交换活动，不等于鸿蒙可信设备发现。
          ArchiveStatusRow({ label: '其他在线设备', value: this.accountView.signedIn && this.accountView.lastSync > 0
            ? `${this.accountView.otherDevices} 台` : '尚未接入', valueId: 'connected-devices-value' })
          Divider().color(T.line)
          ArchiveStatusRow({ label: '最近账号同步', value: this.accountView.signedIn && this.accountView.lastSync > 0
            ? new Date(this.accountView.lastSync).toLocaleTimeString() : '尚未接入', valueId: 'last-sync-value' })
          Divider().color(T.line)
          ArchiveStatusRow({ label: '保留冲突版本', value: this.accountView.signedIn && this.accountView.lastSync > 0
            ? `${this.accountView.conflictCount} 条` : '尚未检测' })
        }.width('100%').padding({ left: 18, right: 18 }).backgroundColor(T.surface).borderRadius(T.cardRadius)
        this.sectionTitle('阅读偏好', '跟随系统外观')
        Column() {
          Row({ space: 12 }) {
            Text('沉浸光感').fontSize(F.body).fontColor(T.ink).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.snapshot.lightEnabled }).enabled(!this.saving).id('light-enabled')
              .selectedColor(T.accent).onChange((enabled: boolean) => {
                const next = copySnapshot(this.snapshot);
                next.lightEnabled = enabled;
                this.commit(next);
              })
          }.width('100%').padding({ top: 16, bottom: 16 })
          Divider().color(T.line)
          ArchiveStatusRow({ label: '设备光感能力', value: HarmonyEffects.hdsSupported() ? '原生沉浸光感' : '系统自适应材质', valueId: 'native-material-capability' })
          Divider().color(T.line)
          Row({ space: 12 }) {
            Text('减少动态效果').fontSize(F.body).fontColor(T.ink).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.snapshot.reducedMotion }).enabled(!this.saving).id('reduced-motion')
              .selectedColor(T.accent).onChange((enabled: boolean) => {
                const next = copySnapshot(this.snapshot);
                next.reducedMotion = enabled;
                this.commit(next);
              })
          }.width('100%').padding({ top: 16, bottom: 16 })
        }.width('100%').padding({ left: 18, right: 18 }).backgroundColor(T.surface).borderRadius(T.cardRadius)
        this.sectionTitle('关于云河纪')
        Column() {
          ArchiveStatusRow({ label: '版本', value: '0.1.0 · 地基版' })
          Divider().color(T.line)
          ArchiveStatusRow({ label: '数据格式', value: `v${this.snapshot.schemaVersion}` })
          Divider().color(T.line)
          ArchiveStatusRow({ label: '内容状态', value: '五城种子内容待校审' })
        }.width('100%').padding({ left: 18, right: 18 }).backgroundColor(T.surface).borderRadius(T.cardRadius)
      }.width('100%').constraintSize({ maxWidth: 760 })
        .padding({ left: 16, right: 16, top: this.topClearance(), bottom: this.dockClearance() })
    }.height('100%').width('100%').align(Alignment.Top).id('device-scroll')
  }

  build() {
    Stack() {
      if (this.currentTab === 0) { RiverBackdrop() }
      HdsNavigation(this.paths) {
        if (this.loading) {
          Column({ space: 16 }) {
            LoadingProgress().width(40).height(40).color($r('app.color.accent'))
            Text('正在打开本地档案').fontColor($r('app.color.muted'))
          }.width('100%').height('100%').justifyContent(FlexAlign.Center)
        } else if (!this.ready) {
          Column({ space: 20 }) {
            Text(this.errorMessage).fontSize(15).lineHeight(24).fontColor($r('app.color.danger'))
            Button('重新读取').onClick(() => this.loadArchive()).backgroundColor($r('app.color.accent'))
          }.padding(24).width('100%').height('100%').justifyContent(FlexAlign.Center)
        } else {
          Column() {
            if (this.errorMessage) {
              Text(this.errorMessage).fontSize(13).fontColor($r('app.color.danger')).padding(12)
            }
            HdsTabs({ controller: this.tabsController, index: this.currentTab }) {
              TabContent() { this.explore() }.tabBar(this.tabStyle(0, '河迹', $r('sys.symbol.map')))
              TabContent() { this.archive() }.tabBar(this.tabStyle(1, '记忆', $r('sys.symbol.bookmark')))
              TabContent() { this.device() }.tabBar(this.tabStyle(2, '档案', $r('sys.symbol.folder')))
            }.width('100%').layoutWeight(1)
              .barPosition(BarPosition.End).barOverlap(true).barBackgroundColor(Color.Transparent)
              .barFloatingStyle(HarmonyEffects.dockStyle(this.snapshot.lightEnabled, this.snapshot.reducedMotion))
              .scrollable(false).animationDuration(this.snapshot.reducedMotion ? 0 : 220)
              .onChange((index: number) => { this.currentTab = index; }).id('native-dock')
          }.width('100%').height('100%')
        }
      }
      .hideTitleBar(!this.ready).hideBackButton(true).titleMode(HdsNavigationTitleMode.MINI)
      .titleBar({
        style: HarmonyEffects.titleBarStyle(this.snapshot.lightEnabled, this.snapshot.reducedMotion),
        content: { title: { mainTitle: '' }, stackBuilder: () => { this.header() } }
      })
      .systemBarStyle({ statusBarContentColor: this.statusBarInk() }, { statusBarContentColor: this.statusBarInk() })
      .bindToScrollable([this.exploreScroller, this.archiveScroller, this.deviceScroller])
      .mode(this.wide ? NavigationMode.Split : NavigationMode.Stack)
      .navBarWidth('42%').navDestination(this.destination)
      .backgroundColor(Color.Transparent).width('100%').height('100%').id('native-navigation')
      .onAreaChange((_old: Area, area: Area) => { this.wide = Number(area.width) >= 840; })
    }.width('100%').height('100%').backgroundColor(T.canvas)
  }
}
