import { common } from '@kit.AbilityKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { HdsNavigation, HdsNavigationTitleMode, HdsTabs, HdsTabsController } from '@kit.UIDesignKit';
import {
  activeRecords, ArchiveRecord, ArchiveSnapshot, CITIES, CITY_INTROS, COLLECTION_TAGS, copySnapshot,
  emptySnapshot, ERAS, filterSites, HeritageSite, nextTimestamp, putRecord, TYPES
} from '../domain/ArchiveDomain';
import { HERITAGE_SITES } from '../data/HeritageCatalog';
import { LocalArchiveRepository } from '../data/LocalArchiveRepository';
import { HarmonyEffects } from '../platform/HarmonyEffects';
import { CulturalEngineViewport } from '../components/CulturalEngineViewport';
import { CulturalEnginePayload, CulturalEngineNode } from '../domain/CulturalEngineContract';

import { SiteGrid } from '../components/SiteCard';
import { siteIllustration } from '../components/SiteRow';
import { SiteDetail } from '../components/SiteDetail';
import { RiverBackdrop } from '../components/RiverBackdrop';
import { ArchiveTheme as T, ArchiveType as F } from '../components/ArchiveTheme';
import { PaperSurface } from '../components/ArchiveInfo';
import { DEFAULT_ARCHIVE_STORE } from '../platform/ArchiveLaunch';
import { CultureAtlas } from '../components/CultureAtlas';
import { LoginPage } from '../components/LoginPage';
import { ProfilePage } from '../components/ProfilePage';
import { MemoryPostcardItem } from '../components/MemoryPostcardItem';
import { MemoryDetailPage } from '../components/MemoryDetailPage';
import { MemoryPosePreview } from '../components/MemoryPosePreview';
import { JOURNEY_ROUTES, JourneyProgress, JourneyRoute, journeyProgress } from '../domain/JourneyRoutes';
import { memorySeasonLabel } from '../domain/MemoryJournal';
import { AccountSyncClient } from '../sync/AccountSyncClient';
import { AccountView, accountErrorMessage, accountStoreName, changedAccountView, guestAccountView } from '../domain/AccountSync';
import type { AiObservationReply, AiObservationRequest } from '../domain/AiObservation';
import { AI_OBSERVATION_SITE_ID, aiAssistBadge } from '../domain/AiObservation';

interface SiteRoute { siteId: string; poseJson?: string; observe?: boolean; noteId?: string; question?: string; observation?: string; }
interface JourneyGraphRoute { journeyId: string; }
interface MemoryRoute { noteId: string; }

@Entry({ useSharedStorage: true })
@Component
struct Index {
  @LocalStorageProp('archiveStoreName') archiveStoreName: string = DEFAULT_ARCHIVE_STORE;
  @LocalStorageProp('appForeground') appForeground: boolean = true;
  @State accountView: AccountView = guestAccountView();
  @State entered: boolean = false;
  @State university: string = '';
  @State studentNumber: string = '';
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
  @State memoryGallery: boolean = false;
  @State memorySection: string = '手账';
  @State memoryKeyword: string = '';
  @State memoryAiOnly: boolean = false;
  @State libraryKeyword: string = '';
  @State libraryEra: string = ERAS[0];
  @State libraryType: string = TYPES[0];
  @State libraryAiOnly: boolean = false;
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
  private memorySearchController: SearchController = new SearchController();
  private librarySearchController: SearchController = new SearchController();
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

  private async authenticateAccount(username: string, password: string, register: boolean,
    university: string, studentNumber: string): Promise<boolean> {
    // 初始游客库读取完成后才允许认证，避免其迟到响应覆盖已经切入的账号快照。
    if (this.loading || this.saving || this.accountView.busy || !this.accountClient) return false;
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
      this.ready = true;
      this.errorMessage = '';
      this.currentTab = 0;
      this.collectionTag = '全部标签';
      this.memoryKeyword = ''; this.memoryAiOnly = false; this.memorySection = '手账';
      // 教育资料仅供本次会话的占位展示，既不认证也不持久化，切换身份时清除。
      this.university = university;
      this.studentNumber = studentNumber;
      this.keyword = ''; this.city = CITIES[0]; this.era = ERAS[0]; this.type = TYPES[0];
      this.accountView = changedAccountView(guestAccountView(), { signedIn: true, username: session.username, serviceConfigured: true });
      this.entered = true;
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
      this.openLogin();
    } catch {
      this.accountView = changedAccountView(this.accountView, { busy: false, message: '本机档案暂时无法读取，当前账号记录仍保留。' });
    }
  }

  private openLogin(): void {
    if (this.saving || this.accountView.busy) return;
    this.paths.clear();
    this.currentTab = 0;
    this.university = ''; this.studentNumber = '';
    this.entered = false;
    this.accountView = changedAccountView(this.accountView, { message: '' });
  }

  private enterOffline(): void {
    if (!this.ready || this.loading || this.accountView.busy) return;
    this.paths.clear(); this.currentTab = 0;
    this.accountView = changedAccountView(this.accountView, { message: '' });
    this.entered = true;
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

  private async openSite(site: HeritageSite, poseJson: string = '', observe: boolean = false,
    noteId: string = '', question: string = '', observation: string = ''): Promise<void> {
    if (this.saving || this.accountView.busy) return;
    const next = copySnapshot(this.snapshot);
    const progress: ArchiveRecord = {
      id: `progress:${site.id}`, kind: 'progress', siteId: site.id, body: 'opened',
      tags: [], updatedAt: nextTimestamp(next.records, Date.now()), deviceId: next.deviceId, deleted: false
    };
    next.records = putRecord(next.records, progress);
    await this.commit(next);
    const route: SiteRoute = { siteId: site.id, poseJson, observe, noteId, question, observation };
    this.paths.pushPathByName('site', route, !this.snapshot.reducedMotion);
  }

  private async aiObserve(request: AiObservationRequest): Promise<AiObservationReply> {
    if (!this.accountClient) throw new Error('ACCOUNT_SERVICE_NOT_CONFIGURED');
    if (!this.accountView.signedIn) throw new Error('ACCOUNT_SESSION_EXPIRED');
    return await this.accountClient.aiObserve(request);
  }

  private cancelAi(): void {
    this.accountClient?.cancelAi();
  }

  private openDulingAi(): void {
    const site = this.siteFor(AI_OBSERVATION_SITE_ID);
    if (!site) {
      this.getUIContext().getPromptAction().showToast({ message: '方鼎档案暂不在当前目录中' });
      return;
    }
    // 首页入口直接打开方鼎并展开 AI 面板；模型、热点与手动操作仍在原详情内，不另建聊天首页。
    this.openSite(site, '', true);
  }

  private results(): HeritageSite[] {
    return filterSites(HERITAGE_SITES, { keyword: this.keyword, city: this.city, era: this.era, type: this.type });
  }

  private collections(): HeritageSite[] {
    const records = activeRecords(this.snapshot.records, 'favorite');
    return HERITAGE_SITES.filter((site: HeritageSite) => records.some((record: ArchiveRecord) =>
      record.siteId === site.id && (this.collectionTag === '全部标签' || record.tags.includes(this.collectionTag))) &&
      `${site.name} ${site.city} ${site.tags.join(' ')}`.toLowerCase().includes(this.memoryKeyword.trim().toLowerCase()));
  }

  private memoryNotes(): ArchiveRecord[] {
    const keyword = this.memoryKeyword.trim().toLowerCase();
    return activeRecords(this.snapshot.records, 'note').filter((note: ArchiveRecord) =>
      (!this.memoryAiOnly || note.aiAssist !== undefined) &&
      `${this.memorySite(note).name} ${note.body} ${note.tags.join(' ')} ${note.aiAssist?.question || ''}`
        .toLowerCase().includes(keyword));
  }

  private libraryResults(): HeritageSite[] {
    return filterSites(HERITAGE_SITES, { keyword: this.libraryKeyword, city: this.city,
      era: this.libraryEra, type: this.libraryType })
      .filter((site: HeritageSite) => !this.libraryAiOnly || site.id === AI_OBSERVATION_SITE_ID);
  }

  private editMemory(note: ArchiveRecord): void {
    const site = this.siteFor(note.siteId);
    if (site) this.openSite(site, '', false, note.id);
  }

  private askMemory(note: ArchiveRecord): void {
    const site = this.siteFor(note.siteId);
    if (!site || site.id !== AI_OBSERVATION_SITE_ID) return;
    // 只预填这一篇手账的问题与观察，用户点击后才请求模型，不上传整个记忆库。
    const pose = note.snapshot3DPose;
    const poseJson = pose?.sceneRevision === 2 && pose.sceneType === 'relic_inspector' ? JSON.stringify(pose) : '';
    this.openSite(site, poseJson, true, '',
      note.aiAssist?.question || '请结合我的观察，带我继续看这件方鼎。', note.body);
  }

  private showMemory(section: string = '手账', aiOnly: boolean = false): void {
    this.memorySection = section; this.memoryAiOnly = aiOnly; this.memoryKeyword = ''; this.currentTab = 1;
  }

  private showLibrary(city: string = CITIES[0]): void {
    // 显式入口只携带自己的城市条件，不被上一次空搜索或 AI 筛选悄悄限制。
    this.city = city; this.libraryKeyword = ''; this.libraryEra = ERAS[0]; this.libraryType = TYPES[0];
    this.libraryAiOnly = false; this.currentTab = 2;
  }

  private siteFor(id: string): HeritageSite | undefined {
    return HERITAGE_SITES.find((site: HeritageSite) => site.id === id);
  }

  private memorySite(note: ArchiveRecord): HeritageSite {
    const site = this.siteFor(note.siteId);
    if (site) return site;
    // 未知档案只保留记录自身的身份与文字，不能拿目录首条文化内容替代它。
    return { id: note.siteId, name: '原档案暂不可用', city: '文字记忆', era: '', type: '未找到档案', tags: [],
      summary: '', overview: '', archaeology: '', history: '', poetry: '', travel: '',
      source: { title: '原档案暂不在当前目录中', url: '' }, reviewStatus: '档案信息不可用',
      illustration: '', accent: '', photos: [] };
  }

  private openMemory(note: ArchiveRecord, replay: boolean): void {
    if (!replay) {
      this.paths.pushPathByName('memory-detail', { noteId: note.id } as MemoryRoute, !this.snapshot.reducedMotion);
      return;
    }
    const site = this.siteFor(note.siteId);
    if (!site) {
      this.getUIContext().getPromptAction().showToast({ message: '原档案暂不在当前目录中，这页文字记忆仍然保留' });
      return;
    }
    this.openSite(site, replay && note.snapshot3DPose ? JSON.stringify(note.snapshot3DPose) : '');
  }

  private homeJourney(records: ArchiveRecord[]): JourneyProgress | undefined {
    // 首页只精选一条主题，完整路线仍由个人页统一呈现。进度始终从当前快照派生，
    // 不缓存或另写“首页完成”状态，保存、删除及账号同步后都沿用领域层的点亮规则。
    const route = JOURNEY_ROUTES.find((item: JourneyRoute) => item.id === 'earth-and-fire');
    return route ? journeyProgress(records, route) : undefined;
  }

  private homeThemeAction(progress: JourneyProgress): string {
    const site = this.siteFor(progress.nextSiteId || progress.route.siteIds[0]);
    if (!site) return '主题档案暂不可用';
    if (progress.unlocked) return `重访 · ${site.name}`;
    return progress.completedCount === 0 ? `从${site.name}开始` : `下一处 · ${site.name}`;
  }

  private openHomeTheme(): void {
    const progress = this.homeJourney(this.snapshot.records);
    if (!progress) return;
    // 点击只打开下一处内容，不越过 75% 探索 / 有效手账门槛；全线完成后从首项重访。
    // 目录不匹配时不能代入无关档案，更不能用打开动作替用户标记完成。
    const site = this.siteFor(progress.nextSiteId || progress.route.siteIds[0]);
    if (site) this.openSite(site);
    else this.getUIContext().getPromptAction().showToast({ message: '这条主题对应的档案暂不在当前目录中' });
  }

  private visitedCount(): number {
    // 同一档案的 opened 和四个探索主题共用 progress kind，统计必须按 siteId 去重。
    return HERITAGE_SITES.filter((site: HeritageSite) => this.snapshot.records.some((record: ArchiveRecord) =>
      record.kind === 'progress' && !record.deleted && record.siteId === site.id)).length;
  }

  private riverPayload(): string {
    const payload: CulturalEnginePayload = { version: 1, selectedId: this.city === CITIES[0] ? '' : this.city,
      nodes: CITIES.slice(1).map((city: string): CulturalEngineNode => ({ id: city, label: city, city })) };
    return JSON.stringify(payload);
  }

  private citySites(city: string): number {
    return HERITAGE_SITES.filter((site: HeritageSite) => site.city === city).length;
  }

  private selectRiverCity(city: string): void {
    if (!CITIES.slice(1).includes(city)) return;
    this.city = this.city === city ? CITIES[0] : city;
    this.getUIContext().getPromptAction().showToast({
      message: this.city === CITIES[0] ? '已显示全部城市' : `已选择${this.city} · ${this.citySites(this.city)} 处档案`
    });
  }

  @Builder
  riverSandbox() {
    Column({ space: 10 }) {
      Row() {
        Text('五城河洛').fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink).layoutWeight(1)
        Text(this.city === CITIES[0] ? '点击城市开始' : this.city).fontSize(F.caption).fontColor(T.accent)
      }.width('100%')
      CulturalEngineViewport({ sceneType: 'river_sandbox', payloadJson: this.riverPayload(), viewportHeight: 230,
        reducedMotion: this.snapshot.reducedMotion, active: this.currentTab === 0 && this.paths.size() === 0,
        onNodeSelected: (id: string, kind: string) => {
          if (kind === 'city') this.selectRiverCity(id);
        } })
      Row({ space: 5 }) {
        ForEach(CITIES.slice(1), (city: string, index: number) => {
          Button(city, { type: ButtonType.Normal }).layoutWeight(1).height(32).fontSize(11)
            .padding({ left: 2, right: 2 })
            .fontColor(this.city === city ? T.accent : T.muted)
            .backgroundColor(this.city === city ? T.accentSoft : T.soft).borderRadius(9)
            .id(`river-city-${index}`).accessibilityText(`查看${city}档案`)
            .onClick(() => this.selectRiverCity(city))
        }, (city: string) => city)
      }.width('100%')
      if (this.city !== CITIES[0]) {
        Text(CITY_INTROS[this.city] || '').fontSize(F.caption).fontColor(T.muted)
          .lineHeight(20).width('100%').maxLines(3)
        Row({ space: 10 }) {
          Text(`${this.city} · ${this.citySites(this.city)} 处文化档案`).fontSize(F.caption).fontColor(T.muted).layoutWeight(1)
          Button('查看档案', { type: ButtonType.Normal }).id('river-city-open').height(32).fontSize(F.caption)
            .padding({ left: 10, right: 10 }).fontColor(T.accent).backgroundColor(T.accentSoft).borderRadius(9)
            .onClick(() => this.showLibrary(this.city))
        }.width('100%')
      }
    }.width('100%').padding(16).backgroundColor(T.surface).borderRadius(T.cardRadius)
      .border({ width: 1, color: T.line, radius: T.cardRadius }).margin({ bottom: 12 }).id('river-sandbox-card')
  }

  @Builder
  destination(name: string, parameter: Object) {
    if (name === 'site') {
      if (this.siteFor((parameter as SiteRoute).siteId)) {
        SiteDetail({
        site: this.siteFor((parameter as SiteRoute).siteId)!,
        snapshot: $snapshot, initialPoseJson: (parameter as SiteRoute).poseJson || '',
        startAiPanel: (parameter as SiteRoute).observe === true,
        initialNoteId: (parameter as SiteRoute).noteId || '',
        initialAiQuestion: (parameter as SiteRoute).question || '',
        initialAiObservation: (parameter as SiteRoute).observation || '',
        aiSignedIn: this.accountView.signedIn, aiServiceConfigured: this.accountView.serviceConfigured,
        onCommit: (next: ArchiveSnapshot): Promise<boolean> => this.commit(next),
        onOpen: (site: HeritageSite) => this.openSite(site),
        onAiRequest: (request: AiObservationRequest): Promise<AiObservationReply> => this.aiObserve(request),
        onAiCancel: (): void => this.cancelAi(),
        onReadMemory: (note: ArchiveRecord) => this.openMemory(note, false)
        })
      } else {
        NavDestination() {
          Column({ space: 16 }) {
            Text('原档案暂不在当前目录中').fontSize(F.section).fontColor(T.ink)
            Text('已保存的文字记忆仍然保留；此处无法重建对应观察。').fontSize(F.body).fontColor(T.muted)
            Button('返回记忆').fontColor(T.accent).backgroundColor(T.accentSoft).onClick(() => { this.paths.pop(); })
          }.width('100%').padding(24)
        }.title('档案暂不可用').backgroundColor(T.canvas)
      }
    } else if (name === 'culture') {
      CultureAtlas({ snapshot: $snapshot, journeyId: (parameter as JourneyGraphRoute)?.journeyId || '', onOpen: (site: HeritageSite) => this.openSite(site) })
    } else if (name === 'memory-detail') {
      MemoryDetailPage({ snapshot: $snapshot, noteId: (parameter as MemoryRoute).noteId, saving: this.saving,
        onResolve: (id: string): ArchiveRecord | undefined =>
          activeRecords(this.snapshot.records, 'note').find((note: ArchiveRecord) => note.id === id),
        onCommit: (next: ArchiveSnapshot): Promise<boolean> => this.commit(next),
        onEdit: (note: ArchiveRecord) => this.editMemory(note), onReplay: (note: ArchiveRecord) => this.openMemory(note, true),
        onAsk: (note: ArchiveRecord) => this.askMemory(note),
        onArchive: (id: string) => { const site = this.siteFor(id); if (site) this.openSite(site); },
        onBack: () => { this.paths.pop(); } })
    } else if (name === 'profile' || name === 'profile-section') {
      ProfilePage({ snapshot: $snapshot, view: this.accountView, saving: this.saving,
        section: name === 'profile-section' ? parameter as string : '',
        onOpenSection: (section: string) => this.paths.pushPathByName('profile-section', section, !this.snapshot.reducedMotion),
        onOpenAi: () => this.openDulingAi(),
        onOpenMemory: (aiOnly: boolean) => {
          this.paths.clear(); this.showMemory('手账', aiOnly);
        },
        university: this.university, studentNumber: this.studentNumber,
        onOpenSite: (id: string) => { const site = this.siteFor(id); if (site) this.openSite(site); },
        onOpenJourneyGraph: (id: string) => this.paths.pushPathByName('culture', { journeyId: id } as JourneyGraphRoute,
          !this.snapshot.reducedMotion),
        onCommit: (next: ArchiveSnapshot): Promise<boolean> => this.commit(next),
        onLogin: () => this.openLogin(), onLogout: () => { this.logoutAccount(); },
        onSync: () => { this.syncAccount(); } })
    }
  }

  @Builder
  profileEntry() {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 3 }) {
        // miniBar 高度固定：图标用 vp，文字限制导航区的放大上限，
        // 避免 1.5 倍字体把文字裁进圆形边缘，正文仍遵从完整系统倍率。
        SymbolGlyph($r('sys.symbol.person')).fontSize('23vp').fontColor([T.accent])
        Text('我的').fontSize(12).maxFontScale(1.2).fontColor(T.ink).id('profile-entry-label')
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    }.width('100%').height('100%').padding(0).backgroundColor(Color.Transparent)
      .borderRadius(30).accessibilityText('打开我的页面').id('profile-entry')
      .onClick(() => this.paths.pushPathByName('profile', '', !this.snapshot.reducedMotion))
  }

  @Builder
  cultureEntry() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        Column() {
          SymbolGlyph($r('sys.symbol.link')).fontSize(24).fontColor([T.accent])
        }.width(44).height(44).borderRadius(14).backgroundColor(T.rose)
          .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
        Column({ space: 5 }) {
          Text('文明连线').fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink)
          Text('五城图谱 · 我的专题 · 档案对照').fontSize(F.caption).fontColor(T.muted).lineHeight(19)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([T.accent])
      }.width('100%').padding(16)
    }.width('100%').padding(0).backgroundColor(T.surface).borderRadius(20)
      .border({ width: 1, color: T.line, radius: 20 }).margin({ bottom: 12 })
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
      Blank()
      Button({ type: ButtonType.Normal }) {
        SymbolGlyph($r('sys.symbol.bookmark')).fontSize(23).fontColor([T.accent])
      }.width(44).height(44).borderRadius(22)
        .backgroundColor(this.snapshot.lightEnabled && !this.snapshot.reducedMotion && HarmonyEffects.supported() ? Color.Transparent : T.surface)
        .systemMaterial(HarmonyEffects.titleCapsule(this.snapshot.lightEnabled, this.snapshot.reducedMotion))
        .accessibilityText('打开我的收藏').id('top-collection').onClick(() => this.showMemory('收藏'))
    }.width('100%').padding({ left: 16, right: 16 }).id('top-navigation-content')
  }

  @Builder
  sectionTitle(title: string, caption: string = '') {
    Row({ space: 9 }) {
      Row().width(3).height(16).borderRadius(2).backgroundColor(T.accent)
      Text(title).fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink)
      Blank()
      if (caption) { Text(caption).fontSize(F.caption).fontColor(T.muted) }
    }.width('100%').padding({ top: 20, bottom: 12 })
  }

  @Builder
  homeThemeCard() {
    // 不把初次派生的 JourneyProgress 作为普通 @Builder 值参数保留：同一 if 分支复用时，
    // 最新记忆虽然已刷新，旧 progress 仍可能停在保存前。每项可变属性显式读取 snapshot.records，
    // 让 ArkUI 将数字、进度条、下一处和无障碍说明一起绑定到落盘后发布的真实快照；不另写完成缓存。
    Column({ space: 9 }) {
      Row({ space: 9 }) {
        Text('此刻主题').fontSize(F.card).fontWeight(FontWeight.Bold).fontColor(T.ink).layoutWeight(1)
        Button('全部路线', { type: ButtonType.Normal }).height(32).fontSize(F.caption)
          .padding({ left: 8, right: 0 }).fontColor(T.muted).backgroundColor(Color.Transparent)
          .id('home-all-journeys').accessibilityText('查看全部主题路线与进度')
          .onClick(() => this.paths.pushPathByName('profile-section', 'journeys', !this.snapshot.reducedMotion))
      }.width('100%')
      Button({ type: ButtonType.Normal }) {
        Column({ space: 12 }) {
          Row({ space: 12 }) {
            Column({ space: 8 }) {
              Text(this.homeJourney(this.snapshot.records)!.route.title).fontSize(30).fontWeight(FontWeight.Bold)
                .fontColor(T.ink).maxLines(1)
              Text(this.homeJourney(this.snapshot.records)!.route.subtitle).fontSize(F.caption).fontColor(T.muted).lineHeight(19)
                .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              Row({ space: 9 }) {
                // 四个圆点对应“泥火成器”的四个节点，只表示真实路线进度，不做装饰性满格。
                Row({ space: 5 }) {
                  ForEach([0, 1, 2, 3], (index: number) => {
                    Row().width(8).height(8).borderRadius(4)
                      .backgroundColor(index < this.homeJourney(this.snapshot.records)!.completedCount ? T.accent : T.accentSoft)
                  }, (index: number) => `theme-dot-${index}`)
                }
                Text(`已探索 ${this.homeJourney(this.snapshot.records)!.completedCount} / ${this.homeJourney(this.snapshot.records)!.total} 处`)
                  .fontSize(F.caption).fontColor(T.accent).id('home-theme-progress')
              }.width('100%')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            // 插画纸片用两层实色纸叠出层次，不使用阴影或渐变冒充官方材质。
            Stack() {
              Rect().width(88).height(108).radius(18).fill(T.accentSoft).rotate({ angle: 6 })
              Image($r('app.media.motif_pottery')).width(82).height(102).objectFit(ImageFit.Cover)
                .border({ width: 4, color: T.surface }).borderRadius(14).rotate({ angle: -2 })
                .accessibilityText('材料主题原创插画，非文物复原')
            }.width(98).height(116)
          }.width('100%').alignItems(VerticalAlign.Center)
          Row({ space: 8 }) {
            Text(this.homeThemeAction(this.homeJourney(this.snapshot.records)!)).fontSize(F.small).fontWeight(FontWeight.Medium)
              .fontColor(T.accent).layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .id('home-theme-next-site')
            Text('去观察').fontSize(F.caption).fontColor(T.accent)
            SymbolGlyph($r('sys.symbol.arrow_right')).fontSize(15).fontColor([T.accent])
          }.width('100%').padding({ top: 11 }).border({ width: { top: 1 }, color: T.surface })
        }.width('100%').padding({ left: 18, right: 18, top: 18, bottom: 14 })
      }.width('100%').padding(0).backgroundColor(T.rose).borderRadius(22)
        .id('home-theme-entry').accessibilityText(`泥火成器，${this.homeThemeAction(this.homeJourney(this.snapshot.records)!)}，直接打开文化档案`)
        .onClick(() => this.openHomeTheme())
    }.width('100%').margin({ bottom: 8 }).id('home-theme-card')
  }

  @Builder
  homeRecentCard(note: ArchiveRecord) {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Column({ space: 4 }) {
          Text(this.memorySite(note).name).fontSize(F.card).fontWeight(FontWeight.Bold).fontColor(T.ink)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).id('home-recent-memory-site')
          Row({ space: 6 }) {
            Text(note.stampType || '河流手账').fontSize(F.caption).fontColor(T.accent)
              .padding({ left: 7, right: 7, top: 3, bottom: 3 }).backgroundColor(T.accentSoft).borderRadius(7)
            Text(memorySeasonLabel(note.updatedAt)).fontSize(F.caption).fontColor(T.muted)
            if (note.aiAssist) {
              Text('AI 辅助').fontSize(F.caption).fontColor(T.accent)
                .padding({ left: 7, right: 7, top: 3, bottom: 3 }).backgroundColor(T.accentSoft).borderRadius(7)
            }
          }.width('100%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([T.accent])
        }.width(34).height(34).backgroundColor(T.accentSoft).enabled(this.siteFor(note.siteId) !== undefined)
          .accessibilityText('打开最近一页手账').onClick(() => this.openMemory(note, false))
      }.width('100%')
      // 首页用缩略画面 + 右侧摘要，避免整张卡片被一张大图撑高。
      if (note.snapshot3DPose) {
        Row({ space: 12 }) {
          Column() {
            MemoryPosePreview({ siteId: note.siteId,
              poseJson: JSON.stringify(note.snapshot3DPose),
              previewHeight: 102, previewId: 'home-recent-memory-preview',
              onOpen: () => this.openMemory(note, true) })
          }.width(142)
          Column({ space: 5 }) {
            Text(note.body || '这页手记还没有写下文字。').fontSize(F.small).fontColor(T.ink).lineHeight(21)
              .maxLines(4).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
              .id('home-recent-memory-body')
            if (note.tags.length > 0) {
              Text(`# ${note.tags.slice(0, 3).join(' · ')}`).fontSize(F.caption).fontColor(T.tertiary)
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
            }
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%').alignItems(VerticalAlign.Top)
      } else {
        Text(note.body || '这页手记还没有写下文字。').fontSize(F.small).fontColor(T.ink).lineHeight(22)
          .maxLines(5).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
          .id('home-recent-memory-body')
        if (note.tags.length > 0) {
          Text(`# ${note.tags.slice(0, 3).join(' · ')}`).fontSize(F.caption).fontColor(T.tertiary)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        }
      }
      Button(note.snapshot3DPose ? '重温当时视角' : '阅读这页手记', { type: ButtonType.Normal })
        .height(38).fontSize(F.caption).fontColor(note.snapshot3DPose ? T.onAccent : T.accent)
        .backgroundColor(note.snapshot3DPose ? T.accent : T.accentSoft).borderRadius(11).width('100%')
        .id('home-recent-memory-open').enabled(this.siteFor(note.siteId) !== undefined)
        .onClick(() => this.openMemory(note, note.snapshot3DPose !== undefined))
    }.width('100%').padding(14).backgroundColor(T.surface).borderRadius(20)
      .border({ width: 1, color: T.line, radius: 20 }).alignItems(HorizontalAlign.Start).id('home-recent-memory')
  }

  @Builder
  homeAiQuestionCard() {
    // 首页只增加一个明确的方鼎问题入口；原“泥火成器”下一节点、最近记忆和路线点亮规则保持不变。
    Button({ type: ButtonType.Normal }) {
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          Text('本期观察 · AI 导览').fontSize(F.caption).fontWeight(FontWeight.Medium).fontColor(T.mintInk)
          Text('杜岭二号方鼎').fontSize(F.caption).fontColor(T.muted)
          Blank()
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([T.mintInk])
        }.width('100%')
        Text('四面方鼎，为什么有八组上腹兽面纹？').fontSize(F.card).fontWeight(FontWeight.Bold)
          .fontColor(T.ink).width('100%').maxLines(2)
        Text('把不懂的地方直接问出来：AI 依据已核事实，带你找壁面正中与四个折角，依据可原地核对。')
          .fontSize(F.caption).fontColor(T.muted).lineHeight(20).width('100%').maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 8 }) {
          Text('陪我观察').fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.mintInk).layoutWeight(1)
          Text('进入方鼎').fontSize(F.caption).fontColor(T.mintInk)
          SymbolGlyph($r('sys.symbol.arrow_right')).fontSize(15).fontColor([T.mintInk])
        }.width('100%')
      }.width('100%').padding(16)
    }.width('100%').padding(0).backgroundColor(T.mint).borderRadius(20).margin({ top: 4, bottom: 12 })
      .id('home-ai-observation').accessibilityText('打开杜岭二号方鼎 AI 观察导览')
      .onClick(() => this.openDulingAi())
  }

  @Builder
  homeMemory() {
    Column({ space: 9 }) {
      Row({ space: 9 }) {
        Text('最近记忆').fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink).layoutWeight(1)
        Button('全部手账', { type: ButtonType.Normal }).height(32).fontSize(F.caption)
          .padding({ left: 8, right: 0 }).fontColor(T.accent).backgroundColor(Color.Transparent)
          .id('home-memory-all').accessibilityText('翻开全部手账').onClick(() => this.showMemory())
      }.width('100%')
      if (activeRecords(this.snapshot.records, 'note').length === 0) {
        Row({ space: 12 }) {
          Stack() {
            Rect().width(44).height(46).radius(14).fill(T.rose).rotate({ angle: -6 })
            SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(22).fontColor([T.accent])
          }.width(50).height(50)
          Column({ space: 4 }) {
            Text('还没有留下记忆').fontSize(F.card).fontWeight(FontWeight.Medium).fontColor(T.ink)
            Text('从一处细节开始，观察后把画面与感受留在手账。').fontSize(F.caption).fontColor(T.muted).lineHeight(19)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Button('开始观察', { type: ButtonType.Normal }).height(38).fontSize(F.caption)
            .padding({ left: 12, right: 12 }).fontColor(T.accent).backgroundColor(T.accentSoft).borderRadius(11)
            .id('home-empty-memory-explore').onClick(() => this.openHomeTheme())
        }.width('100%').padding(14).backgroundColor(T.surface).borderRadius(20)
          .border({ width: 1, color: T.line, radius: 20 }).id('home-empty-memory')
      } else {
        // activeRecords 已按真实更新时间倒序且排除墓碑，首页与记忆页采用相同来源。
        // 记录版本参与 key，落盘发布 snapshot 后立即刷新预览，不沿用上一条记录的画面。
        ForEach(activeRecords(this.snapshot.records, 'note').slice(0, 1), (note: ArchiveRecord) => {
          this.homeRecentCard(note)
        }, (note: ArchiveRecord) => `${note.id}:${note.updatedAt}`)
      }
    }.width('100%').margin({ bottom: 6 }).alignItems(HorizontalAlign.Start)
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
          }.width('100%').height(114).accessibilityText('原创文化主题插画')
          Button({ type: ButtonType.Normal }) {
            Row({ space: 6 }) {
              Text('打开档案').fontSize(F.small).fontColor(T.onAccent)
              SymbolGlyph($r('sys.symbol.arrow_right')).fontSize(14).fontColor([T.onAccent])
            }.justifyContent(FlexAlign.Center)
          }.width('100%').height(44).borderRadius(8).backgroundColor(T.accent)
            .id('featured-site').onClick(() => this.openSite(HERITAGE_SITES[0]))
        }.width('100%').padding({ left: 14, right: 14, top: 17, bottom: 14 }).alignItems(HorizontalAlign.Start)
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
          .onClick(() => this.showMemory())
        Stack({ alignContent: Alignment.TopStart }) {
          PaperSurface({ contentHeight: this.deviceEntryHeight, color: T.mint, surfaceId: 'device-entry-paper' })
          Column({ space: 8 }) {
            Text('随身档案').fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink).width('78%')
            Text(`${HERITAGE_SITES.length} 处文化档案 · 离线可读`).fontSize(F.caption).fontColor(T.muted).maxLines(2)
            Row({ space: 5 }) {
              Text('查看档案状态').fontSize(F.caption).fontColor(T.mintInk)
              SymbolGlyph($r('sys.symbol.arrow_right')).fontSize(13).fontColor([T.mintInk])
            }
          }.width('100%').padding({ top: 17, left: 14, right: 10, bottom: 18 }).alignItems(HorizontalAlign.Start)
            .onAreaChange((_old: Area, area: Area) => { this.deviceEntryHeight = Math.max(115, Math.ceil(Number(area.height))); })
            .id('device-entry-content')
          Row() { this.sticker($r('sys.symbol.folder'), T.yellow, T.yellowInk, -8) }
            .width('100%').justifyContent(FlexAlign.End).translate({ y: -10 }).hitTestBehavior(HitTestMode.None)
        }.width('100%').id('device-entry').accessibilityText('打开文化档案库').onClick(() => this.showLibrary())
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
        Column({ space: 6 }) {
          Row({ space: 8 }) {
            Row().width(18).height(2).borderRadius(1).backgroundColor(T.accent)
            Text('河迹 · 黄河文化漫游').fontSize(F.caption).fontColor(T.accent)
          }
          Text('沿河，遇见文明').fontSize(F.display).fontWeight(FontWeight.Bold).fontColor(T.ink)
          Text('五座城，把黄河故事慢慢读完。').fontSize(F.small).fontColor(T.muted).lineHeight(22)
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 6, bottom: 16 })
        if (this.homeJourney(this.snapshot.records)) { this.homeThemeCard() }
        this.homeAiQuestionCard()
        this.homeMemory()
        this.sectionTitle('循河探索', '五城文化目录')
        this.riverSandbox()
        this.cultureEntry()
        this.sectionTitle('拾页入口', '收藏、手账与档案')
        this.entryBoard()
        this.sectionTitle('循城而入', '五座城市')
        this.cityIndex()
        Column({ space: 10 }) {
          Row({ space: 8 }) {
            Text('检索档案').fontSize(F.card).fontWeight(FontWeight.Bold).fontColor(T.ink).layoutWeight(1)
            Text(`${HERITAGE_SITES.length} 处文化档案`).fontSize(F.caption).fontColor(T.muted)
          }.width('100%')
          Search({ value: this.keyword, controller: this.searchController, placeholder: '搜索遗址、城市或线索' })
            .searchButton('检索', { fontColor: T.accent })
            .height(48).backgroundColor(T.soft).fontColor(T.ink).placeholderColor(T.muted).borderRadius(T.inputRadius)
            .onChange((value: string) => { this.keyword = value; }).id('site-search')
            // 原生提交时结束编辑，释放键盘占用，让结果区重新获得可用高度。
            .onSubmit(() => this.searchController.stopEditing())
          Row({ space: 8 }) {
            Select(CITIES.map((value: string): SelectOption => ({ value }))).value(this.city === CITIES[0] ? '城市' : this.city)
              .selected(CITIES.indexOf(this.city)).font({ size: F.small }).fontColor(T.ink).backgroundColor(T.soft)
              .height(44).borderRadius(T.inputRadius).padding({ left: 10, right: 10 }).layoutWeight(1)
              .onSelect((_index: number, value: string) => { this.city = value; }).id('filter-city')
            Select(ERAS.map((value: string): SelectOption => ({ value }))).value(this.era === ERAS[0] ? '年代' : this.era)
              .selected(ERAS.indexOf(this.era)).font({ size: F.small }).fontColor(T.ink).backgroundColor(T.soft)
              .height(44).borderRadius(T.inputRadius).padding({ left: 10, right: 10 }).layoutWeight(1)
              .onSelect((_index: number, value: string) => { this.era = value; }).id('filter-era')
            Select(TYPES.map((value: string): SelectOption => ({ value }))).value(this.type === TYPES[0] ? '类型' : this.type)
              .selected(TYPES.indexOf(this.type)).font({ size: F.small }).fontColor(T.ink).backgroundColor(T.soft)
              .height(44).borderRadius(T.inputRadius).padding({ left: 10, right: 10 }).layoutWeight(1)
              .onSelect((_index: number, value: string) => { this.type = value; }).id('filter-type')
          }.width('100%')
          Row() {
            Text(`${this.results().length} 处文化遗产`).fontSize(F.card).fontWeight(FontWeight.Bold)
              .fontColor(T.ink).layoutWeight(1).id('search-result-count')
            Button('重置', { type: ButtonType.Normal }).fontSize(13).height(38).borderRadius(8)
              .backgroundColor(Color.Transparent).fontColor(T.accent).id('reset-filters')
              .onClick(() => { this.keyword = ''; this.city = CITIES[0]; this.era = ERAS[0]; this.type = TYPES[0]; })
          }.width('100%')
        }.width('100%').padding(14).backgroundColor(T.surface).borderRadius(20)
          .border({ width: 1, color: T.line, radius: 20 }).margin({ top: 2, bottom: 12 })
        if (this.results().length === 0) {
          this.emptyState('没有符合条件的档案', $r('sys.symbol.magnifyingglass'))
        }
        SiteGrid({ sites: this.results(), gridId: 'explore-site-grid',
          collectedIds: activeRecords(this.snapshot.records, 'favorite').map((record: ArchiveRecord) => record.siteId),
          onOpen: (site: HeritageSite) => this.openSite(site) })
        Text('— 五城二十处 · 沿河而读 —').fontSize(F.caption).fontColor(T.tertiary)
          .width('100%').textAlign(TextAlign.Center).padding({ top: 10, bottom: 8 }).id('explore-tail')
      }.width('100%').constraintSize({ maxWidth: 760 })
        .padding({ left: 16, right: 16, top: this.topClearance(), bottom: this.dockClearance() })
    }.height('100%').width('100%').align(Alignment.Top).scrollBar(BarState.Auto).id('explore-scroll')
  }

  @Builder
  archive() {
    Scroll(this.archiveScroller) {
      Column({ space: 14 }) {
        Row() {
          Text('我的记忆').fontSize(F.title).fontWeight(FontWeight.Bold).fontColor(T.ink).layoutWeight(1)
          Button({ type: ButtonType.Normal }) {
            SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(22).fontColor([T.accent])
          }.width(42).height(42).backgroundColor(T.accentSoft).borderRadius(8)
            .accessibilityText('去档案开始新的观察').id('memory-new').onClick(() => this.showLibrary())
        }.width('100%')
        Row({ space: 10 }) {
          Text(`${activeRecords(this.snapshot.records, 'note').length}`).id('note-count').fontSize(F.small).fontColor(T.ink)
          Text('篇手账').fontSize(F.caption).fontColor(T.muted)
          Text(`${activeRecords(this.snapshot.records, 'favorite').length}`).id('collection-count').fontSize(F.small).fontColor(T.ink)
          Text('处收藏').fontSize(F.caption).fontColor(T.muted)
          Blank()
          Text(`${this.visitedCount()}`).id('visited-count').fontSize(F.caption).fontColor(T.muted)
          Text('处已浏览').fontSize(F.caption).fontColor(T.muted)
        }.width('100%')
        Row({ space: 4 }) {
          ForEach(['手账', '收藏'], (section: string, index: number) => {
            Button(section, { type: ButtonType.Normal }).layoutWeight(1).height(40).fontSize(F.small)
              .fontColor(this.memorySection === section ? T.onAccent : T.muted)
              .backgroundColor(this.memorySection === section ? T.accent : Color.Transparent).borderRadius(7)
              .id(`memory-section-${index}`).onClick(() => { this.memorySection = section; this.memoryKeyword = ''; })
          })
        }.width('100%').padding(4).backgroundColor(T.soft).borderRadius(8)
        Search({ value: this.memoryKeyword, controller: this.memorySearchController,
          placeholder: this.memorySection === '手账' ? '搜索手账、标签或曾经的问题' : '搜索收藏的档案' })
          .height(44).fontColor(T.ink).placeholderColor(T.muted).backgroundColor(T.surface).borderRadius(8)
          .searchButton('查找', { fontColor: T.accent }).id('memory-search')
          .onChange((value: string) => { this.memoryKeyword = value; })
          .onSubmit(() => this.memorySearchController.stopEditing())
        if (this.memorySection === '手账') {
        Row({ space: 8 }) {
          Checkbox({ name: 'ai-memory' }).select(this.memoryAiOnly).selectedColor(T.mintInk).id('memory-ai-filter')
            .onChange((value: boolean) => { this.memoryAiOnly = value; })
          Text('AI 辅助').fontSize(F.caption).fontColor(T.mintInk)
          Blank()
          Button('列表').id('memory-view-list').fontSize(F.caption).height(36).padding({ left: 10, right: 10 })
            .fontColor(this.memoryGallery ? T.muted : T.accent).backgroundColor(this.memoryGallery ? T.soft : T.accentSoft)
            .onClick(() => { this.memoryGallery = false; })
          Button('画廊').id('memory-view-gallery').fontSize(F.caption).height(36).padding({ left: 10, right: 10 })
            .fontColor(this.memoryGallery ? T.accent : T.muted).backgroundColor(this.memoryGallery ? T.accentSoft : T.soft)
            .onClick(() => { this.memoryGallery = true; })
        }.width('100%')
        if (this.memoryNotes().length === 0) {
          this.emptyState(this.memoryKeyword ? '没有找到这段记忆' : (this.memoryAiOnly ? '还没有 AI 辅助手账' : '还没有留下手账'),
            $r('sys.symbol.square_and_pencil'), this.memoryKeyword ? '换一个档案名、问题或标签试试。' : '从一个好奇的问题开始。')
          Button(this.memoryKeyword ? '清空搜索' : '与 AI 观察方鼎', { type: ButtonType.Normal })
            .width('100%').height(42).fontColor(T.mintInk).backgroundColor(T.mint).id('memory-empty-action')
            .onClick(() => { if (this.memoryKeyword) this.memoryKeyword = ''; else this.openDulingAi(); })
        }
        ForEach(this.memoryNotes(), (note: ArchiveRecord) => {
          MemoryPostcardItem({ note, site: this.memorySite(note), compact: !this.memoryGallery,
            syncLabel: this.accountView.signedIn && this.accountView.lastSync >= note.updatedAt ? '已完成账号同步' : '已保存在本机',
            canAsk: note.siteId === AI_OBSERVATION_SITE_ID, onAsk: () => this.askMemory(note),
            onOpen: () => this.openMemory(note, false),
            onPose: () => this.openMemory(note, true) })
        }, (note: ArchiveRecord) => `${note.id}:${note.updatedAt}:${this.memoryGallery}`)
        } else {
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
        if (this.collections().length === 0) {
          Button('去档案看看', { type: ButtonType.Normal }).id('memory-browse-archives').width('100%').height(42)
            .fontColor(T.accent).backgroundColor(T.accentSoft).onClick(() => this.showLibrary())
        }
        }
      }.width('100%').constraintSize({ maxWidth: 760 })
        .padding({ left: 16, right: 16, top: this.topClearance(), bottom: this.dockClearance() })
    }.height('100%').width('100%').align(Alignment.Top).id('archive-scroll')
  }

  @Builder
  device() {
    Scroll(this.deviceScroller) {
      Column({ space: 14 }) {
        Row() {
          Text('文化档案').fontSize(F.title).fontWeight(FontWeight.Bold).fontColor(T.ink).layoutWeight(1)
          Text(`${HERITAGE_SITES.length} 处 · 离线可读`).fontSize(F.caption).fontColor(T.mintInk)
        }.width('100%')
        Search({ value: this.libraryKeyword, controller: this.librarySearchController, placeholder: '搜索遗址、文物或文化线索' })
          .height(46).fontColor(T.ink).placeholderColor(T.muted).backgroundColor(T.surface).borderRadius(8)
          .searchButton('检索', { fontColor: T.accent }).id('library-search')
          .onChange((value: string) => { this.libraryKeyword = value; })
          .onSubmit(() => this.librarySearchController.stopEditing())
        Button({ type: ButtonType.Normal }) {
        Row({ space: 10 }) {
          if (this.siteFor(AI_OBSERVATION_SITE_ID)) {
            Image(siteIllustration(this.siteFor(AI_OBSERVATION_SITE_ID)!)).width(64).height(72).objectFit(ImageFit.Contain)
          }
          Column({ space: 5 }) {
            Text('和 AI 一起看方鼎').fontSize(F.card).fontWeight(FontWeight.Bold).fontColor(T.mintInk)
            Text('四面与八组，转到折角寻找答案').fontSize(F.caption).fontColor(T.ink).maxLines(2)
            Text('杜岭二号方鼎 · 可提问与查依据').fontSize(F.caption).fontColor(T.muted).maxLines(2)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([T.mintInk])
        }.width('100%').padding(12)
        }.width('100%').padding(0).backgroundColor(T.mint).borderRadius(8).id('library-ai-open')
          .onClick(() => this.openDulingAi())
        Row({ space: 6 }) {
          Select(CITIES.map((value: string): SelectOption => ({ value }))).value(this.city)
            .selected(CITIES.indexOf(this.city)).layoutWeight(1).font({ size: F.caption }).height(40)
            .fontColor(T.ink).backgroundColor(T.soft).id('library-city')
            .onSelect((_index: number, value: string) => { this.city = value; })
          Select(ERAS.map((value: string): SelectOption => ({ value }))).value(this.libraryEra)
            .selected(ERAS.indexOf(this.libraryEra)).layoutWeight(1).font({ size: F.caption }).height(40)
            .fontColor(T.ink).backgroundColor(T.soft).id('library-era')
            .onSelect((_index: number, value: string) => { this.libraryEra = value; })
          Select(TYPES.map((value: string): SelectOption => ({ value }))).value(this.libraryType)
            .selected(TYPES.indexOf(this.libraryType)).layoutWeight(1).font({ size: F.caption }).height(40)
            .fontColor(T.ink).backgroundColor(T.soft).id('library-type')
            .onSelect((_index: number, value: string) => { this.libraryType = value; })
        }.width('100%')
        Row({ space: 6 }) {
          Checkbox({ name: 'ai-library' }).select(this.libraryAiOnly).selectedColor(T.mintInk).id('library-ai-filter')
            .onChange((value: boolean) => { this.libraryAiOnly = value; })
          Text('可 AI 观察').fontSize(F.caption).fontColor(T.mintInk)
          Blank()
          Text(`${this.libraryResults().length} 处`).fontSize(F.caption).fontColor(T.muted).id('library-result-count')
          Button('重置', { type: ButtonType.Normal }).height(34).fontSize(F.caption).fontColor(T.accent)
            .backgroundColor(Color.Transparent).id('library-reset').onClick(() => {
              this.libraryKeyword = ''; this.city = CITIES[0]; this.libraryEra = ERAS[0]; this.libraryType = TYPES[0];
              this.libraryAiOnly = false;
            })
        }.width('100%')
        if (this.libraryResults().length === 0) {
          this.emptyState('没有符合条件的档案', $r('sys.symbol.magnifyingglass'), '可清空关键词或重置筛选。')
        }
        SiteGrid({ sites: this.libraryResults(),
          gridId: 'archive-library-grid',
          collectedIds: activeRecords(this.snapshot.records, 'favorite').map((record: ArchiveRecord) => record.siteId),
          onOpen: (site: HeritageSite) => this.openSite(site) })
        Text(this.saving ? '正在保存本机档案' : '收藏、手账与浏览记录保存在本机，登录后随账号同步。')
          .fontSize(F.caption).fontColor(T.muted).lineHeight(20).width('100%').padding({ top: 6, bottom: 10 })
      }.width('100%').constraintSize({ maxWidth: 760 })
        .padding({ left: 16, right: 16, top: this.topClearance(), bottom: this.dockClearance() })
    }.height('100%').width('100%').align(Alignment.Top).id('device-scroll')
  }

  @Builder
  mainPage() {
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
              .barFloatingStyle(HarmonyEffects.dockStyle(this.snapshot.lightEnabled, this.snapshot.reducedMotion, () => { this.profileEntry(); }))
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

  build() {
    Stack() {
      if (this.entered) {
        this.mainPage()
      } else {
        LoginPage({ view: this.accountView, initializing: this.loading, localAvailable: this.ready, localError: this.errorMessage,
          onAuthenticate: (username: string, password: string, register: boolean, university: string, studentNumber: string): Promise<boolean> =>
            this.authenticateAccount(username, password, register, university, studentNumber),
          onOffline: () => this.enterOffline(), onRetryLocal: () => { this.loadArchive(); } })
      }
    }.width('100%').height('100%').backgroundColor(T.canvas)
  }

}
