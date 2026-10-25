import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { HdsNavigation, HdsNavigationTitleMode, HdsTabs, HdsTabsController } from '@kit.UIDesignKit';
import {
  activeRecords, AiMemoryAssist, ArchiveRecord, ArchiveSnapshot, CITIES, COLLECTION_TAGS,
  compareVersions, copyAiMemoryAssist, copySnapshot, copyRoamingMemoryContext,
  emptySnapshot, ERAS, filterSites, HeritageSite, mergeRecords, nextTimestamp, pendingRecordCount, putRecord,
  recordVersionConfirmed, TYPES
} from '../domain/ArchiveDomain';
import { HERITAGE_SITES } from '../data/HeritageCatalog';
import { LocalArchiveRepository } from '../data/LocalArchiveRepository';
import { AccountWorkspaceStore } from '../data/AccountWorkspaceStore';
import { DistributedArchiveChannel } from '../sync/DistributedArchiveChannel';
import { DistributedArchiveStatus, initialDistributedStatus } from '../domain/DistributedArchive';
import { HarmonyEffects } from '../platform/HarmonyEffects';

import { SiteGrid } from '../components/SiteCard';
import { siteIllustration } from '../components/SiteRow';
import { SiteDetail } from '../components/SiteDetail';
import { ArchiveTheme as T, ArchiveType as F } from '../components/ArchiveTheme';
import { DEFAULT_ARCHIVE_STORE } from '../platform/ArchiveLaunch';
import { CultureAtlas } from '../components/CultureAtlas';
import { LoginPage } from '../components/LoginPage';
import { ProfilePage } from '../components/ProfilePage';
import { MemoryPostcardItem } from '../components/MemoryPostcardItem';
import { MemoryDetailPage } from '../components/MemoryDetailPage';
import { MemoryFilterPage } from '../components/MemoryFilterPage';
import { JourneyScrollPage } from '../components/JourneyScrollPage';
import { groupMemoryRecords, MemoryMonthGroup } from '../domain/MemoryJournal';
import { AccountSyncClient } from '../sync/AccountSyncClient';
import { AccountView, accountErrorMessage, accountStoreName, changedAccountView, guestAccountView } from '../domain/AccountSync';
import type { AiObservationReply, AiObservationRequest } from '../domain/AiObservation';
import { AI_OBSERVATION_SITE_ID, isAiObservationSite } from '../domain/AiObservation';
import { aiKnowledgeScope } from '../domain/AiObservationKnowledge';
import { WaterSituationPage } from '../components/WaterSituationPage';
import { RoamingHome } from '../components/RoamingHome';
import { PaperJourneyHome } from '../components/PaperJourneyHome';
import { RiverMarketHome } from '../components/RiverMarketHome';
import { RiverMarketPage } from '../components/RiverMarketPage';
import { copyRiverMarket, RiverMarketState } from '../domain/RiverMarket';
import { RIVER_MARKET_RECORD_ID, riverMarketFromRecords, riverMarketIsDeleted, riverMarketIsUnreadable,
  riverMarketRecord } from '../domain/RiverMarketRecords';
import { MARKET_SOURCES } from '../data/RiverMarketCatalog';
import { PaperJourneyPage } from '../components/PaperJourneyPage';
import { PaperMemoryPage } from '../components/PaperMemoryPage';
import { PaperLibrarySection } from '../components/PaperLibrarySection';
import { PaperMemoryShelf } from '../components/PaperMemoryShelf';
import { PaperProfileSection } from '../components/PaperProfileSection';
import { PAPER_CITIES, PaperCity } from '../data/PaperJourneyCatalog';
import { PaperWorkV1, copyPaperWork, mergePaperWork } from '../domain/PaperJourney';
import { paperWorkFromRecords, paperWorkIsUnreadable, paperWorkRecord } from '../domain/PaperJourneyRecords';
import { PaperMemoryContext, copyPaperMemory } from '../domain/PaperMemory';
import { RoamingChapterPage } from '../components/RoamingChapterPage';
import { RoamingMemoryDetail } from '../components/RoamingMemoryDetail';
import { RoamingScrollPage } from '../components/RoamingScrollPage';
import { RoamingLibrarySection } from '../components/RoamingLibrarySection';
import { RoamingFavoritesSection } from '../components/RoamingFavoritesSection';
import { RoamingSystemPage } from '../components/RoamingSystemPage';
import { ROAM_CHAPTERS } from '../data/RoamingCatalog';
import { culturalEntryForId, roamingChapterForId, ROAM_LIBRARY_ERAS, ROAM_LIBRARY_TYPES } from '../data/CulturalContentIndex';
import { RoamChapter, RoamingMemoryContext, completeRoamClue, roamProgress } from '../domain/Roaming';
import { KaifengCityV1, parseKaifengCity, serializeKaifengCity } from '../domain/KaifengPuzzle';
import { mergeKaifengCityProgress } from '../domain/GameProgressMerge';
import { kaifengCityFromRecords, kaifengCityRecord } from '../domain/KaifengRecords';
import { KaifengDigV1, mergeDig, parseDig } from '../domain/KaifengDig';
import { kaifengDigFromRecords, kaifengDigRecord } from '../domain/KaifengDigRecords';
import { KaifengDigPage } from '../components/KaifengDigPage';
import type { KaifengAiAnswer, KaifengAiColophonResult, KaifengAiRequest } from '../domain/KaifengAi';
import { publishRoamingCard, clearRoamingCard, shareRoamingMemory, RoamingCardState, RoamingLaunchRoute } from '../platform/RoamingSystem';

interface SiteRoute { siteId: string; poseJson?: string; observe?: boolean; noteId?: string; question?: string; observation?: string; newNote?: boolean; }
interface JourneyGraphRoute { journeyId: string; }
interface MemoryRoute { noteId: string; }
interface RoamingRoute { chapterId: string; clueId?: string; }
interface DigRoute { chapterId: string; }
interface PaperRoute { cityId: string; }
interface RoamingNoteRoute { noteId: string; edit?: boolean; }
interface RoamingPosition { version: number; chapterId: string; clueId: string; }

@Entry({ useSharedStorage: true })
@Component
struct Index {
  @LocalStorageProp('archiveStoreName') archiveStoreName: string = DEFAULT_ARCHIVE_STORE;
  @LocalStorageProp('appForeground') appForeground: boolean = true;
  @LocalStorageLink('roamingLaunchRoute') @Watch('consumeRoamingLaunch') roamingLaunchRoute: string = '';
  @State accountView: AccountView = guestAccountView();
  @State accountConfirmed: ArchiveRecord[] = [];
  @State nativeView: DistributedArchiveStatus = initialDistributedStatus();
  @State entered: boolean = true;
  @State university: string = '';
  @State studentNumber: string = '';
  @State snapshot: ArchiveSnapshot = emptySnapshot('');
  @State ready: boolean = false;
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State saving: boolean = false;
  @State collectionTag: string = '全部标签';
  @State memoryGallery: boolean = false;
  @State memorySection: string = '手账';
  @State memoryKeyword: string = '';
  @State memoryAiOnly: boolean = false;
  // 记忆页自己的检索状态：排序与标签只影响回顾视图，不写回记录，也不与检索条件共享。
  @State memorySort: string = '最近';
  @State memoryTag: string = '全部标签';
  @State memorySelectMode: boolean = false;
  @State memorySelectedIds: string[] = [];
  @State libraryKeyword: string = '';
  // 文化库检索条件独立成组：城市、年代、类型只属于文化库页，不与其他页面共享状态。
  @State libraryCity: string = CITIES[0];
  @State libraryEra: string = ERAS[0];
  @State libraryType: string = TYPES[0];
  @State libraryAiOnly: boolean = false;
  @State libraryScope: string = '全部';
  @State librarySort: string = '目录';
  @State libraryKind: string = '文化篇章';
  @State cultureEra: string = '全部年代';
  @State cultureType: string = '全部类型';
  @State incomingMemoryId: string = '';
  @State incomingChapterId: string = '';
  @State currentTab: number = 0;
  @State wide: boolean = false;
  @State private destinationVisible: boolean = false;
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
  private workspaceStore: AccountWorkspaceStore | undefined = undefined;
  private nativeChannel: DistributedArchiveChannel | undefined = undefined;
  private nativeBusy: boolean = false;
  private accountTimer: number = -1;
  private accountGeneration: number = 0;
  private loginReturnName: string = '';
  private loginReturnParameter: Object = '';
  private cardRefreshQueue: Promise<void> = Promise.resolve();
  private paperWriteQueue: Promise<void> = Promise.resolve();
  private marketWriteQueue: Promise<void> = Promise.resolve();

  aboutToAppear(): void {
    // 首页没有详情时使用完整画幅；打开篇章后才保留左侧目录。
    // 使用真实路由拦截回调跟随系统返回，不能仅靠点击按钮维护宽屏状态。
    this.paths.setInterception({
      willShow: (_from: NavDestinationContext | NavBar, to: NavDestinationContext | NavBar) => {
        this.destinationVisible = to !== 'navBar';
      }
    });
    this.loadArchive();
    // 前台每 5 秒交换已确认保存的数据；写锁 / 在途请求时跳过本次，不堆积轮询。
    // 后台只保留本机档案，避免无意义网络请求；返回前台后继续真实交换。
    this.accountTimer = setInterval(() => { if (this.appForeground) this.syncAccount(); }, 5000);
  }

  aboutToDisappear(): void {
    this.accountGeneration++;
    if (this.accountTimer >= 0) clearInterval(this.accountTimer);
    this.accountClient?.clearSession();
    this.nativeChannel?.close();
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
      // 只在游客明确确认后复制本次漫游；原游客库及已有账号库都不清空。
      // 旧器物笔记不会因一次按需登录被批量带入另一个身份。
      if (!this.accountView.signedIn) {
        const roaming = this.snapshot.records.filter((record: ArchiveRecord) =>
          record.id.startsWith('progress:roam:') || record.id === 'progress:roaming-position:v1' ||
          // 城市快照也要随“复制漫游”进入账号库，否则登录后整座城会消失。
          record.id.startsWith('progress:kaifeng-city:') ||
          // 探方是开封主玩法，换账号后不该从零开始。
          record.id.startsWith('progress:kaifeng-dig:') ||
          record.id.startsWith('progress:paper-journey:') || record.id === 'progress:paper-position:v1' ||
          record.id === RIVER_MARKET_RECORD_ID ||
          record.paperContext !== undefined ||
          (record.kind === 'note' && record.siteId === 'kf-zhouqiao' && record.tags.includes('汴河探方')) ||
          (record.kind === 'note' && record.siteId === 'kf-zhouqiao' && record.tags.includes('汴京开市')) ||
          record.roamingContext !== undefined || (record.kind === 'favorite' && roamingChapterForId(record.siteId) !== undefined));
        if (roaming.length > 0) {
          const decision = await this.getUIContext().getPromptAction().showDialog({
            title: '把本机漫游带入这个账号？',
            message: '只复制漫游进度、新文化收藏和漫游手账；本机原副本保留，旧器物档案继续独立。',
            buttons: [{ text: '仅登录', color: '#556B61' }, { text: '复制漫游', color: '#15564A' }]
          });
          if (decision.index === 1) {
            snapshot.records = mergeRecords(snapshot.records, roaming).records;
            await repository.save(snapshot);
          }
        }
      }
      const persisted = await this.workspaceStore?.save(session);
      this.accountGeneration++;
      // 登录等待期间可能切到了别的页面。身份切换清理旧路由，避免仍打开游客笔记
      // 编辑器并把其草稿保存进新的账号档案；游客已确认记录依然留在原库。
      this.paths.clear();
      this.repository = repository;
      this.snapshot = snapshot;
      this.accountConfirmed = [];
      this.incomingMemoryId = ''; this.incomingChapterId = '';
      this.ready = true;
      this.errorMessage = '';
      this.currentTab = 0;
      this.collectionTag = '全部标签';
      this.memoryKeyword = ''; this.memoryAiOnly = false; this.memorySection = '手账';
      // 教育资料仅供本次会话的占位展示，既不认证也不持久化，切换身份时清除。
      this.university = university;
      this.studentNumber = studentNumber;
      this.accountView = changedAccountView(guestAccountView(), { signedIn: true, sessionReady: true,
        username: session.username, serviceConfigured: true, pendingCount: snapshot.records.length,
        message: persisted ? '' : '本机账号档案可离线继续；重启后如需同步，请重新登录。' });
      this.entered = true;
      await this.configureNative(session.accountId);
      await this.syncAccount();
      this.restoreLoginDestination();
      this.refreshRoamingCards();
      return true;
    } catch (error) {
      this.accountClient.clearSession();
      // 重新认证失败只失去网络会话，当前离线身份和档案仍可读；界面不能继续显示会话可用。
      this.accountView = changedAccountView(this.accountView, { busy: false, sessionReady: false,
        message: accountErrorMessage((error as Error).message) });
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
      await this.workspaceStore?.forget();
      try { await this.accountClient.logout(); } catch { this.accountClient.clearSession(); }
      this.accountGeneration++;
      await this.nativeChannel?.close();
      this.nativeChannel = undefined;
      this.nativeView = initialDistributedStatus();
      this.repository = guest;
      this.snapshot = snapshot;
      this.accountConfirmed = [];
      this.accountView = changedAccountView(guestAccountView(), { serviceConfigured: this.accountView.serviceConfigured });
      this.paths.clear(); this.currentTab = 0; this.entered = true;
      this.loginReturnName = ''; this.incomingMemoryId = ''; this.incomingChapterId = '';
      try {
        // 派生缓存按写入顺序串行处理，旧身份的在途刷新结束后再清理桌面内容。
        await this.cardRefreshQueue;
        await clearRoamingCard(this.getUIContext().getHostContext() as common.UIAbilityContext);
      }
      catch { /* 桌面宿主更新失败不回滚已经完成的身份退出。 */ }
      this.refreshRoamingCards();
    } catch {
      this.accountView = changedAccountView(this.accountView, { busy: false, message: '本机档案暂时无法读取，当前账号记录仍保留。' });
    }
  }

  private openLogin(): void {
    if (this.saving || this.accountView.busy) return;
    const names = this.paths.getAllPathName();
    const name = names.length > 0 ? names[names.length - 1] : '';
    if (['roaming', 'site', 'roam-memory', 'roam-scroll', 'profile', 'profile-section'].includes(name)) {
      this.loginReturnName = name;
      this.loginReturnParameter = this.paths.getParamByIndex(names.length - 1) as Object;
      if (name === 'roaming') {
        // 进入篇章时的路由参数可能已落后于当前线索；登录回来应恢复最后一次明确操作的位置。
        const position = this.snapshot.records.find(item => item.id === 'progress:roaming-position:v1' && !item.deleted);
        if (position) {
          try {
            const current = JSON.parse(position.body) as RoamingPosition;
            if (current.chapterId === (this.loginReturnParameter as RoamingRoute).chapterId) {
              this.loginReturnParameter = { chapterId: current.chapterId, clueId: current.clueId } as RoamingRoute;
            }
          } catch { /* 保留原路由，不把未知位置写回档案。 */ }
        }
      }
    } else this.loginReturnName = '';
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
    this.restoreLoginDestination();
  }

  private restoreLoginDestination(): void {
    if (!this.loginReturnName) return;
    const name = this.loginReturnName;
    const parameter = this.loginReturnParameter;
    this.loginReturnName = '';
    this.paths.pushPathByName(name, parameter, false);
  }

  private consumeRoamingLaunch(): void {
    if (!this.ready || !this.entered || !this.roamingLaunchRoute) return;
    try {
      const route = JSON.parse(this.roamingLaunchRoute) as RoamingLaunchRoute;
      // 窗口级启动意图只消费一次，不清空路由或切换身份，避免热启动打断当前账号。
      this.roamingLaunchRoute = '';
      if (route.action === 'chapter' && PAPER_CITIES.some(city => city.id === route.chapterId)) {
        this.openPaper(route.chapterId);
      } else if (route.action === 'chapter' && ROAM_CHAPTERS.some(chapter => chapter.id === route.chapterId)) {
        this.openRoaming(route.chapterId);
      } else if (route.action === 'memory') {
        const note = activeRecords(this.snapshot.records, 'note').find(item => item.id === route.noteId);
        if (note) this.openMemory(note, false);
        else { this.paths.clear(); this.showMemory(); }
      } else { this.paths.clear(); this.currentTab = 0; }
    } catch { this.roamingLaunchRoute = ''; }
  }

  private async refreshRoamingCards(): Promise<void> {
    if (!this.ready) return;
    const generation = this.accountGeneration;
    const snapshot = copySnapshot(this.snapshot);
    this.cardRefreshQueue = this.cardRefreshQueue.then(async (): Promise<void> => {
    if (generation !== this.accountGeneration) return;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const position = snapshot.records.find(record => record.id === 'progress:paper-position:v1' && !record.deleted);
    const city = PAPER_CITIES.find(item => item.id === position?.siteId) || PAPER_CITIES[0];
    const work = paperWorkFromRecords(snapshot.records, city.id);
    const state: RoamingCardState = { mode: 'chapter', chapterId: city.id,
      title: city.title, excerpt: work ? '上次的剪口还在，接着剪这一页。' : city.subtitle,
      completedClues: work?.completedAt ? 1 : 0, totalClues: 1 };
    if (/^yunheji_test_ui_[a-z0-9_]{1,80}$/.test(this.archiveStoreName)) state.testStoreName = this.archiveStoreName;
    try { await publishRoamingCard(context, state); }
    catch { /* 单张卡片的宿主失败不阻止另一类缓存刷新或清理。 */ }
    try {
      const note = activeRecords(snapshot.records, 'note')[0];
      if (note) {
        const memoryState: RoamingCardState = { mode: 'memory',
          chapterId: note.paperContext?.cityId || note.roamingContext?.chapterId || '',
          noteId: note.id, title: note.paperContext?.title || note.roamingContext?.title || this.memorySite(note).name,
          excerpt: note.body || (note.paperContext ? '我留下的一幅纸景，剪口与出处都在。' : ''), completedClues: 0, totalClues: 0 };
        if (/^yunheji_test_ui_[a-z0-9_]{1,80}$/.test(this.archiveStoreName)) memoryState.testStoreName = this.archiveStoreName;
        await publishRoamingCard(context, memoryState);
      } else await clearRoamingCard(context, 'memory');
    } catch { /* 卡片派生缓存失败不改变已落盘的档案；下次前台操作可重试。 */ }
    }).catch(() => {});
    return this.cardRefreshQueue;
  }

  private setRoamingPosition(next: ArchiveSnapshot, chapterId: string, clueId: string): void {
    const position: RoamingPosition = { version: 1, chapterId, clueId };
    next.records = putRecord(next.records, { id: 'progress:roaming-position:v1', kind: 'progress', siteId: chapterId,
      body: JSON.stringify(position), tags: [], updatedAt: nextTimestamp(next.records, Date.now()),
      deviceId: next.deviceId, deleted: false });
  }

  private async rememberRoamingPosition(chapterId: string, clueId: string): Promise<void> {
    if (this.saving || !ROAM_CHAPTERS.some(chapter => chapter.id === chapterId && chapter.clues.some(clue => clue.id === clueId))) return;
    const next = copySnapshot(this.snapshot);
    this.setRoamingPosition(next, chapterId, clueId);
    await this.commit(next);
  }

  private async openRoaming(chapterId: string, clueId: string = ''): Promise<void> {
    if (!this.ready || this.saving || !ROAM_CHAPTERS.some(chapter => chapter.id === chapterId)) return;
    const chapter = ROAM_CHAPTERS.find(item => item.id === chapterId)!;
    const next = copySnapshot(this.snapshot);
    let savedClue = '';
    const last = next.records.find(item => item.id === 'progress:roaming-position:v1' && !item.deleted);
    if (!clueId && last) {
      try {
        const value = JSON.parse(last.body) as RoamingPosition;
        if (value.chapterId === chapterId && chapter.clues.some(item => item.id === value.clueId)) savedClue = value.clueId;
      } catch { /* 未知位置记录保留，恢复时回到当前真实进度。 */ }
    }
    const selected = chapter.clues.some(item => item.id === clueId) ? clueId : savedClue || roamProgress(next.records, chapter).nextClueId;
    const position: RoamingPosition = { version: 1, chapterId, clueId: selected || chapter.clues[0].id };
    this.setRoamingPosition(next, chapterId, position.clueId);
    if (!await this.commit(next)) return;
    this.paths.pushPathByName('roaming', { chapterId, clueId: position.clueId } as RoamingRoute, !next.reducedMotion);
  }

  // 开封城市快照：一条独立 progress 记录，body 存 KaifengCityV1。
  // 写前先与旧记录合并，避免“另一端刚放好的层位/纹样被这一端较新的空状态整条覆盖”；
  // acts 只增不减，closedAt 取最早，桥面与灯取较新。
  // AI 校书：账号服务的 /ai/kaifeng 与观察导览共用会话，但客户端在拿到回复后
  // 还要过 KaifengAi 的引用/年份校验；未配置或未登录时直接抛出真实原因。
  private async askKaifeng(request: KaifengAiRequest): Promise<KaifengAiAnswer> {
    if (!this.accountClient) throw new Error('ACCOUNT_SERVICE_NOT_CONFIGURED');
    return this.accountClient.kaifengAsk(request);
  }

  private async writeKaifengColophon(request: KaifengAiRequest): Promise<KaifengAiColophonResult> {
    if (!this.accountClient) throw new Error('ACCOUNT_SERVICE_NOT_CONFIGURED');
    return this.accountClient.kaifengColophon(request);
  }

  private async saveKaifengCity(chapterId: string, cityJson: string): Promise<void> {
    if (this.saving) return;
    const incoming = parseKaifengCity(cityJson);
    if (!incoming || incoming.chapterId !== chapterId) return;
    const next = copySnapshot(this.snapshot);
    const existing = kaifengCityFromRecords(next.records, chapterId);
    // 与跨端同步共用同一套去重合并（两只仙鹤不按槽位并集复制），并在保存前用
    // 正式解析器校验：合不出可读正文时退回刚玩出的这一版，绝不落盘读不回的城市。
    const merged: KaifengCityV1 = mergeKaifengCityProgress(existing, incoming) || incoming;
    merged.updatedAt = nextTimestamp(next.records, Date.now());
    const verified = parseKaifengCity(serializeKaifengCity(merged));
    if (!verified) return;
    next.records = putRecord(next.records, kaifengCityRecord(verified, next.deviceId, merged.updatedAt));
    await this.commit(next);
  }

  private async saveKaifengDig(chapterId: string, digJson: string): Promise<void> {
    if (this.saving) return;
    const incoming = parseDig(digJson);
    if (!incoming || incoming.chapterId !== chapterId) return;
    const next = copySnapshot(this.snapshot);
    const existing = kaifengDigFromRecords(next.records, chapterId);
    const merged: KaifengDigV1 = mergeDig(existing, incoming) || incoming;
    const updatedAt = nextTimestamp(next.records, Date.now());
    merged.updatedAt = updatedAt;
    next.records = putRecord(next.records, kaifengDigRecord(merged, next.deviceId, updatedAt));
    await this.commit(next);
  }

  private openPaper(cityId: string): void {
    if (!this.ready || !PAPER_CITIES.some(city => city.id === cityId)) return;
    this.paths.pushPathByName('paper', { cityId } as PaperRoute, !this.snapshot.reducedMotion);
  }

  private openMarket(): void {
    if (this.ready) this.paths.pushPathByName('river-market', '', !this.snapshot.reducedMotion);
  }

  private saveMarketState(state: RiverMarketState, restart: boolean = false): Promise<boolean> {
    const frozen = copyRiverMarket(state);
    const generation = this.accountGeneration;
    let result = false;
    const operation = this.marketWriteQueue.catch(() => {}).then(async (): Promise<void> => {
      await this.waitForArchiveWrite();
      if (this.saving || generation !== this.accountGeneration) return;
      if (riverMarketIsDeleted(this.snapshot.records) && !restart) {
        this.errorMessage = '夜市进度已删除，原墓碑保留。请明确选择重新开市后再安排。'; return;
      }
      // 每一版经营是完整的库存与账目，不能把两端计数相加。沿用progress的整条版本合并，
      // 真正轮到此动作时才读取最新快照并赋逻辑时钟，保留其他笔记、pose和删除墓碑。
      // 坏正文必须保留原样；不能因页面显示初始场景，就把损坏存档覆盖成一局新游戏。
      if (riverMarketIsUnreadable(this.snapshot.records)) {
        this.errorMessage = '这座夜市的存档暂不可读，原记录已保留。请先备份并恢复可读版本。';
        return;
      }
      const next = copySnapshot(this.snapshot);
      const updatedAt = nextTimestamp(next.records, Date.now());
      frozen.updatedAt = updatedAt;
      next.records = putRecord(next.records, riverMarketRecord(frozen, next.deviceId, updatedAt));
      result = await this.commit(next);
    });
    this.marketWriteQueue = operation;
    return operation.then(() => result);
  }

  private async saveMarketMemory(body: string, quote: string, visibleState: RiverMarketState): Promise<boolean> {
    const market = copyRiverMarket(visibleState);
    if (market.round < 4) return false;
    const generation = this.accountGeneration;
    await this.marketWriteQueue;
    await this.waitForArchiveWrite();
    if (this.saving || generation !== this.accountGeneration || !body.trim()) return false;
    const next = copySnapshot(this.snapshot);
    const updatedAt = nextTimestamp(next.records, Date.now());
    // 只有用户亲自确认的文字成为note。经营结算属于游戏记录，不写到访、旧pose、
    // 纸景或AI上下文；短引、底本和当次成绩一起冻结，后续资料更新不改这页依据。
    // 成绩来自页面已确认保存且仍在眼前的收市版本，不能读等待期间收到的另一端新局，
    // 否则玩家写旧夜市时会被新局拒绝保存，或把另一夜的成绩错误冻进这篇记忆。
    const source = MARKET_SOURCES[0];
    const note: ArchiveRecord = { id: `note:${next.deviceId}:${updatedAt}`, kind: 'note',
      siteId: 'kf-zhouqiao', body: body.trim().slice(0, 4000), tags: ['开封', '汴京开市'],
      updatedAt, deviceId: next.deviceId, deleted: false, stampType: '开市记', paperTheme: 'jade',
      quotedPoemOrFact: `“${quote}”\n${source.title}，孟元老南宋追记北宋。\n${source.url}\n` +
        `经营小样记录：四段接待${market.served}/100客，收市余钱${market.cash}。地图与经营数值为原创游戏规则。` };
    next.records = putRecord(next.records, note);
    const saved = await this.commit(next);
    if (saved) this.lastSavedNoteId = note.id;
    return saved;
  }

  private async waitForArchiveWrite(): Promise<void> {
    // 等待本机已经开始的快照写入；不跳过快速连续的剪口，也不伪报保存成功。
    for (let attempt = 0; this.saving && attempt < 100; attempt++) {
      await new Promise<void>((resolve: () => void) => { setTimeout(resolve, 30); });
    }
  }

  private savePaperWork(work: PaperWorkV1): Promise<boolean> {
    const frozen = copyPaperWork(work);
    const generation = this.accountGeneration;
    let result = false;
    const operation = this.paperWriteQueue.catch(() => {}).then(async (): Promise<void> => {
      await this.waitForArchiveWrite();
      if (this.saving || generation !== this.accountGeneration) return;
      // 在实际排队写入前检查最新档案，防止等待期间收到的损坏正文被当作空纸覆盖。
      // 拒绝时不替换快照，也不写最近位置；原始记录继续保留供显式备份恢复。
      if (paperWorkIsUnreadable(this.snapshot.records, frozen.cityId)) {
        this.errorMessage = '这座城的纸景存档暂时无法读取，原记录已保留。请先备份并恢复可读版本，再继续创作。';
        return;
      }
      const next = copySnapshot(this.snapshot);
      const previous = paperWorkFromRecords(next.records, frozen.cityId);
      const updatedAt = nextTimestamp(next.records, Date.now());
      // 这是排队中的下一次明确本机动作，先赋提交时的逻辑时钟，避免快速第二剪
      // 仍带抬手前时钟，被第一剪落盘后的时间误判为旧版本而丢失。
      frozen.updatedAt = updatedAt;
      const merged = mergePaperWork(previous, frozen) || frozen;
      merged.updatedAt = updatedAt;
      next.records = putRecord(next.records, paperWorkRecord(merged, next.deviceId, updatedAt));
      next.records = putRecord(next.records, { id: 'progress:paper-position:v1', kind: 'progress',
        siteId: merged.cityId, body: merged.cityId, tags: [], updatedAt,
        deviceId: next.deviceId, deleted: false });
      result = await this.commit(next);
    });
    this.paperWriteQueue = operation;
    return operation.then(() => result);
  }

  private async savePaperMemory(context: PaperMemoryContext, body: string): Promise<boolean> {
    await this.paperWriteQueue;
    await this.waitForArchiveWrite();
    if (this.saving) return false;
    const city = PAPER_CITIES.find(item => item.id === context.cityId);
    if (!city) return false;
    const next = copySnapshot(this.snapshot);
    const updatedAt = nextTimestamp(next.records, Date.now());
    const note: ArchiveRecord = { id: `note:${next.deviceId}:${updatedAt}`, kind: 'note',
      siteId: city.relatedSiteId, body: body.trim().slice(0, 4000), tags: [city.city, '纸上生城'],
      updatedAt, deviceId: next.deviceId, deleted: false, stampType: '纸上生城', paperTheme: 'jade',
      paperContext: copyPaperMemory(context) };
    next.records = putRecord(next.records, note);
    return this.commit(next);
  }

  private confirmDeleteMemory(note: ArchiveRecord): void {
    this.getUIContext().showAlertDialog({ title: '删除这页记忆？', message: '删除会随同一账号同步。',
      primaryButton: { value: '保留', action: () => {} },
      secondaryButton: { value: '删除', action: () => { this.deleteMemory(note.id); } } });
  }

  private async deleteMemory(noteId: string): Promise<void> {
    if (this.saving) return;
    const next = copySnapshot(this.snapshot);
    const note = next.records.find(item => item.id === noteId && !item.deleted);
    if (!note) return;
    note.deleted = true; note.updatedAt = nextTimestamp(next.records, Date.now()); note.deviceId = next.deviceId;
    await this.commit(next);
  }

  // 探方结算写成一页普通手账：挂在州桥遗址下，进记忆页、可跨端同步，
  // 但不写 roamingContext —— 探方不是漫游篇章，伪造上下文会让「回到那一章」出错。
  private async saveDigNote(body: string): Promise<boolean> {
    if (this.saving || !body.trim()) return false;
    const next = copySnapshot(this.snapshot);
    const updatedAt = nextTimestamp(next.records, Date.now());
    const record: ArchiveRecord = {
      id: `note:${next.deviceId}:${updatedAt}`,
      kind: 'note',
      siteId: 'kf-zhouqiao',
      body: body.trim().slice(0, 4000),
      tags: ['汴河探方', '考古'],
      updatedAt,
      deviceId: next.deviceId,
      deleted: false,
      paperTheme: 'jade',
      stampType: '探方记'
    };
    next.records = putRecord(next.records, record);
    return this.commit(next);
  }

  private async completeRoaming(chapterId: string, clueId: string, choiceId: string,
    cityJson: string = ''): Promise<void> {
    const chapter = ROAM_CHAPTERS.find(item => item.id === chapterId);
    if (!chapter || this.saving) return;
    try {
      const next = copySnapshot(this.snapshot);
      const record = completeRoamClue(chapter, clueId, choiceId, next.records, next.deviceId,
        nextTimestamp(next.records, Date.now()));
      next.records = putRecord(next.records, record);
      // 开封第三幕收束时，城市快照与线索进度写进同一次快照、同一次 commit：
      // 分两次落盘会在 saving 锁上互相挤掉，导致“收好了但城没记住”。
      if (cityJson) {
        const city = parseKaifengCity(cityJson);
        if (city && city.chapterId === chapterId) {
          const existing = kaifengCityFromRecords(next.records, chapterId);
          const merged: KaifengCityV1 = mergeKaifengCityProgress(existing, city) || city;
          merged.updatedAt = nextTimestamp(next.records, Date.now());
          const verified = parseKaifengCity(serializeKaifengCity(merged));
          if (verified) {
            next.records = putRecord(next.records, kaifengCityRecord(verified, next.deviceId, merged.updatedAt));
          }
        }
      }
      const index = chapter.clues.findIndex(clue => clue.id === clueId);
      this.setRoamingPosition(next, chapterId, chapter.clues[Math.min(index + 1, chapter.clues.length - 1)].id);
      await this.commit(next);
    } catch {
      this.getUIContext().getPromptAction().showToast({ message: '先完成当前线索，之后的故事会逐步展开。' });
    }
  }

  // 记录本端刚写入的记忆 id：写作页的“读我刚留下的记忆”据此直接进入全文，
  // 不再先跳到长卷目录让用户自己再找一遍。仅本端内存态，不写盘、不同步。
  private lastSavedNoteId: string = '';

  private async saveRoaming(context: RoamingMemoryContext, body: string, tags: string[],
    assist?: AiMemoryAssist): Promise<boolean> {
    if (this.saving || !body.trim()) return false;
    const next = copySnapshot(this.snapshot);
    const updatedAt = nextTimestamp(next.records, Date.now());
    const record: ArchiveRecord = { id: `note:${next.deviceId}:${updatedAt}`, kind: 'note', siteId: context.clueId,
      body: body.trim().slice(0, 4000), tags: tags.map(tag => tag.trim().slice(0, 40)).filter(tag => !!tag).slice(0, 20),
      updatedAt, deviceId: next.deviceId, deleted: false, paperTheme: 'jade', stampType: '河洛拾遗',
      quotedPoemOrFact: context.excerpt, roamingContext: copyRoamingMemoryContext(context) };
    // AI 题跋的依据作为可选字段冻结进这条手账；只有玩家确认保存时才写入，
    // 冲突列表与模型原文不入库，避免把“参考”当成用户正文。
    if (assist) record.aiAssist = copyAiMemoryAssist(assist);
    next.records = putRecord(next.records, record);
    const saved = await this.commit(next);
    if (saved) this.lastSavedNoteId = record.id;
    return saved;
  }

  private openCulturalContent(id: string): void {
    const chapter = roamingChapterForId(id);
    if (chapter) { this.openRoaming(chapter.id, id); return; }
    const site = this.siteFor(id);
    if (site) this.openSite(site);
  }

  private async toggleCultureFavorite(id: string): Promise<void> {
    if (!culturalEntryForId(id) || this.saving) return;
    const next = copySnapshot(this.snapshot);
    const previous = next.records.find(item => item.id === `favorite:${id}`);
    next.records = putRecord(next.records, { id: `favorite:${id}`, kind: 'favorite', siteId: id, body: '',
      tags: previous?.tags || [], updatedAt: nextTimestamp(next.records, Date.now()), deviceId: next.deviceId,
      deleted: previous !== undefined && !previous.deleted });
    await this.commit(next);
  }

  private async tagCultureFavorite(id: string, tag: string): Promise<void> {
    if (this.saving) return;
    const next = copySnapshot(this.snapshot);
    const record = next.records.find((item: ArchiveRecord) => item.id === `favorite:${id}` && !item.deleted);
    if (!record) return;
    // 分类只替换约定的分类标签，保留已有自定义信息；“已去过”始终由用户自己选择。
    record.tags = record.tags.filter((value: string) => !COLLECTION_TAGS.includes(value));
    if (COLLECTION_TAGS.includes(tag)) record.tags.unshift(tag);
    record.updatedAt = nextTimestamp(next.records, Date.now()); record.deviceId = next.deviceId;
    await this.commit(next);
  }

  private async shareMemory(note: ArchiveRecord): Promise<void> {
    try {
      const source = note.paperContext?.sources.map(item => `${item.title} · ${item.era}\n${item.quote}\n${item.url}`).join('\n\n') ||
        note.roamingContext?.sources.map(item => `${item.title} ${item.url}`).join('\n') || '';
      await shareRoamingMemory(this.getUIContext().getHostContext() as common.UIAbilityContext,
        note.paperContext?.title || note.roamingContext?.title || this.memorySite(note).name, note.body,
        note.paperContext?.excerpt || note.paperContext?.culture || note.roamingContext?.excerpt || note.quotedPoemOrFact || '', source,
        note.paperContext ? 'paper-note-share' : 'roam-memory-share', note.paperContext?.work);
    } catch {
      this.getUIContext().getPromptAction().showToast({ message: '分享未完成，记忆仍然保存在本机。' });
    }
  }

  private openPersonalRiver(): void {
    this.paths.pushPathByName('roam-scroll', '', !this.snapshot.reducedMotion);
  }

  private async syncAccount(): Promise<void> {
    if (this.ready && this.accountView.signedIn && !this.saving) this.syncNative();
    if (!this.ready || this.saving || !this.accountClient || !this.accountView.signedIn || !this.accountView.sessionReady ||
      this.accountView.busy || this.accountView.syncing) return;
    const generation = this.accountGeneration;
    let exchangeAgain = false;
    this.accountView = changedAccountView(this.accountView, { syncing: true });
    try {
      const reply = await this.accountClient.exchange(copySnapshot(this.snapshot));
      if (generation !== this.accountGeneration) return;
      // 在途请求期间允许本机继续编辑，合并时必须使用当前快照，不回写发送时的旧值。
      // 若本机正在落盘，下一轮再合并；成功时间只在远端已响应且本机保存确认后发布。
      if (this.saving) return;
      const next = this.accountClient.mergedSnapshot(this.snapshot, reply);
      const received = activeRecords(next.records, 'note').find((note: ArchiveRecord) =>
        note.deviceId !== this.snapshot.deviceId && !this.snapshot.records.some((old: ArchiveRecord) =>
          old.id === note.id && compareVersions(old, note) >= 0));
      const receivedProgress = activeRecords(next.records, 'progress').find((record: ArchiveRecord) =>
        (record.id.startsWith('progress:roam:') ||
          (record.id === RIVER_MARKET_RECORD_ID && !!riverMarketFromRecords([record])) ||
          (record.id.startsWith('progress:paper-journey:v1:') && !!paperWorkFromRecords([record], record.siteId))) &&
        record.deviceId !== this.snapshot.deviceId &&
        !this.snapshot.records.some((old: ArchiveRecord) => old.id === record.id && compareVersions(old, record) >= 0));
      if (JSON.stringify(next.records) !== JSON.stringify(this.snapshot.records) && !await this.commit(next, false)) {
        throw new Error('ACCOUNT_LOCAL_SAVE_FAILED');
      }
      this.accountConfirmed = reply.records;
      if (received) this.incomingMemoryId = received.id;
      // 新纸景与旧篇章共享“收到后主动继续”入口；接收本身不导航，不打断另一篇的编辑。
      if (receivedProgress?.id === RIVER_MARKET_RECORD_ID) {
        this.incomingChapterId = 'river-market';
      } else if (receivedProgress && (PAPER_CITIES.some((city: PaperCity) => city.id === receivedProgress.siteId) ||
        ROAM_CHAPTERS.some((chapter: RoamChapter) => chapter.id === receivedProgress.siteId))) {
        this.incomingChapterId = receivedProgress.siteId;
      }
      const pendingCount = pendingRecordCount(this.snapshot.records, this.accountConfirmed);
      exchangeAgain = pendingCount > 0;
      // 进度条与“本次冲突”都取本机真实数量：总数来自当前快照，
      // 冲突数来自刚才那次 mergeRecords，服务端累计值只作为历史版本单独展示。
      const mergeConflicts = this.accountClient.mergeConflictCount();
      this.accountView = changedAccountView(this.accountView, { lastSync: Date.now(), otherDevices: reply.otherDevices,
        conflictCount: reply.conflictCount, pendingCount, message: '',
        recordCount: this.snapshot.records.length, mergeConflicts });
    } catch (error) {
      if (generation === this.accountGeneration) {
        const code = (error as Error).message;
        this.accountView = changedAccountView(this.accountView, { message: accountErrorMessage(code),
          sessionReady: code === 'ACCOUNT_SESSION_EXPIRED' ? false : this.accountView.sessionReady });
      }
    } finally {
      if (generation === this.accountGeneration) {
        this.accountView = changedAccountView(this.accountView, { syncing: false });
        // 本轮响应不能确认在途期间的新编辑；解除请求锁后立即补传，失败仍由前台轮询重试。
        if (exchangeAgain) this.syncAccount();
      }
    }
  }

  private async loadArchive(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await this.configureAccount();
      this.workspaceStore = new AccountWorkspaceStore(context, this.archiveStoreName);
      const restored = await this.workspaceStore.load();
      const testScope = this.archiveStoreName.startsWith('yunheji_test_ui_') ? this.archiveStoreName : '';
      this.repository = new LocalArchiveRepository(context, restored ? accountStoreName(restored.workspace.accountId, testScope) : this.archiveStoreName);
      this.snapshot = await this.repository.load();
      this.accountConfirmed = [];
      if (restored) {
        let sessionReady = false;
        if (restored.session && this.accountClient) {
          // 读取账号快照期间令牌也可能刚好到期。网络会话的再次校验失败只能
          // 降级为离线档案，不能让已校验可读的本机数据变成“本地读取失败”。
          try { this.accountClient.restoreSession(restored.session); sessionReady = true; }
          catch { this.accountClient.clearSession(); }
        }
        this.accountView = changedAccountView(this.accountView, { signedIn: true,
          sessionReady, username: restored.workspace.username,
          pendingCount: this.snapshot.records.length,
          recordCount: this.snapshot.records.length, mergeConflicts: 0,
          message: sessionReady ? '' : '已打开原账号的离线档案；重新登录后继续网络同步。' });
        this.entered = true;
        await this.configureNative(restored.workspace.accountId);
      }
      this.ready = true;
      this.entered = true;
    } catch {
      this.errorMessage = '本地档案读取失败。原数据未被清空，请重试；持续失败时请保留应用数据并联系开发者。';
      this.ready = false;
    } finally { this.loading = false; }
    if (this.ready && this.entered) this.syncAccount();
    if (this.ready) { this.consumeRoamingLaunch(); this.refreshRoamingCards(); }
  }

  private async configureNative(accountId: string): Promise<void> {
    await this.nativeChannel?.close();
    const generation = this.accountGeneration;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const channel = new DistributedArchiveChannel(context, (state: DistributedArchiveStatus) => {
      if (generation === this.accountGeneration) this.nativeView = state;
    });
    this.nativeChannel = channel;
    const scope = this.archiveStoreName.startsWith('yunheji_test_ui_') ? this.archiveStoreName : '';
    await channel.open(accountId, scope);
  }

  private async syncNative(authorize: boolean = false): Promise<void> {
    const channel = this.nativeChannel;
    if (!channel || this.nativeBusy || this.saving || !this.ready || this.accountView.busy) return;
    const generation = this.accountGeneration;
    this.nativeBusy = true;
    try {
      if (authorize && !await channel.requestPermission()) return;
      const records = await channel.exchange(copySnapshot(this.snapshot));
      if (generation !== this.accountGeneration || this.saving) return;
      // 平台读写等待期间本机仍可编辑；只将记录并回此刻快照，不能回写发起时的旧快照。
      const next = copySnapshot(this.snapshot);
      next.records = mergeRecords(this.snapshot.records, records).records;
      if (JSON.stringify(next.records) !== JSON.stringify(this.snapshot.records)) await this.commit(next, false);
    } catch { /* 通道已发布具体失败，Preferences 与账号 HTTPS 主路径继续保留。 */ }
    finally { this.nativeBusy = false; }
  }

  private async commit(next: ArchiveSnapshot, syncAfter: boolean = true): Promise<boolean> {
    // 所有页面共用写锁；先完成落盘，再发布新状态，避免失败时界面误报“已保存”。
    if (this.saving || this.accountView.busy || !this.ready || !this.repository) return false;
    this.saving = true;
    try {
      await this.repository.save(next);
      this.snapshot = next;
      this.refreshRoamingCards();
      if (this.accountView.signedIn) this.accountView = changedAccountView(this.accountView,
        { pendingCount: pendingRecordCount(next.records, this.accountConfirmed) });
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
    noteId: string = '', question: string = '', observation: string = '', newNote: boolean = false): Promise<void> {
    if (this.saving || this.accountView.busy) return;
    const next = copySnapshot(this.snapshot);
    const progress: ArchiveRecord = {
      id: `progress:${site.id}`, kind: 'progress', siteId: site.id, body: 'opened',
      tags: [], updatedAt: nextTimestamp(next.records, Date.now()), deviceId: next.deviceId, deleted: false
    };
    next.records = putRecord(next.records, progress);
    await this.commit(next);
    const route: SiteRoute = { siteId: site.id, poseJson, observe, noteId, question, observation, newNote };
    // 从“写一页”选好档案后替换选择页，保存并返回时直接回到记忆，
    // 不让用户再次经过已完成的选择步骤。普通浏览与编辑旧手账仍沿用原路由。
    if (newNote) {
      // 新的普通手账不能被进入前的 AI / 标签条件藏起来；选定档案时才回到最近全部，
      // 仅打开选择页或筛选页再返回仍保留原条件。
      this.memorySection = '手账'; this.resetMemoryFilters(); this.exitNoteSelection();
      this.paths.replacePathByName('site', route, !this.snapshot.reducedMotion);
    }
    else this.paths.pushPathByName('site', route, !this.snapshot.reducedMotion);
  }

  private async aiObserve(request: AiObservationRequest): Promise<AiObservationReply> {
    if (!this.accountClient) throw new Error('ACCOUNT_SERVICE_NOT_CONFIGURED');
    if (!this.accountView.signedIn) throw new Error('ACCOUNT_SESSION_EXPIRED');
    return await this.accountClient.aiObserve(request);
  }

  private cancelAi(): void {
    this.accountClient?.cancelAi();
  }

  private openAiSite(siteId: string): void {
    const site = this.siteFor(siteId);
    if (!site) {
      this.getUIContext().getPromptAction().showToast({ message: '这件档案暂不在当前目录中' });
      return;
    }
    // AI 入口直接打开对应对象并展开面板；模型、热点与手动操作仍在原详情内，不另建聊天首页。
    this.openSite(site, '', true);
  }

  private openDulingAi(): void {
    this.openAiSite(AI_OBSERVATION_SITE_ID);
  }

  private aiObjectName(siteId: string): string {
    return aiKnowledgeScope(siteId)?.objectName || this.siteFor(siteId)?.name || '这件器物';
  }

  private aiQuestionFor(siteId: string): string {
    return aiKnowledgeScope(siteId)?.question || '这件器物该从哪里看？';
  }

  private collections(): HeritageSite[] {
    const records = activeRecords(this.snapshot.records, 'favorite');
    return HERITAGE_SITES.filter((site: HeritageSite) => records.some((record: ArchiveRecord) =>
      record.siteId === site.id && (this.collectionTag === '全部标签' || record.tags.includes(this.collectionTag))) &&
      `${site.name} ${site.city} ${site.tags.join(' ')}`.toLowerCase().includes(this.memoryKeyword.trim().toLowerCase()));
  }

  private cultureCollectionCount(): number {
    return activeRecords(this.snapshot.records, 'favorite').filter((record: ArchiveRecord) => {
      const entry = culturalEntryForId(record.siteId);
      return roamingChapterForId(record.siteId) !== undefined && entry !== undefined &&
        (this.collectionTag === '全部标签' || record.tags.includes(this.collectionTag)) &&
        `${entry.name} ${entry.city} ${entry.overview} ${record.tags.join(' ')}`.toLowerCase()
          .includes(this.memoryKeyword.trim().toLowerCase());
    }).length;
  }

  private collectedSiteIds(): string[] {
    return activeRecords(this.snapshot.records, 'favorite').map((record: ArchiveRecord) => record.siteId);
  }

  private visitedSiteIds(): string[] {
    // 浏览记录与主题探索共用 progress kind；按 siteId 去重后供档案卡与筛选复用。
    return HERITAGE_SITES.filter((site: HeritageSite) => this.snapshot.records.some((record: ArchiveRecord) =>
      record.kind === 'progress' && !record.deleted && record.siteId === site.id))
      .map((site: HeritageSite) => site.id);
  }

  private memoryNotes(): ArchiveRecord[] {
    const keyword = this.memoryKeyword.trim().toLowerCase();
    const notes = activeRecords(this.snapshot.records, 'note').filter((note: ArchiveRecord) =>
      (!this.memoryAiOnly || note.aiAssist !== undefined) &&
      (this.memoryTag === '全部标签' || note.tags.includes(this.memoryTag)) &&
      `${this.memorySite(note).name} ${this.memorySite(note).city} ${note.body} ${note.tags.join(' ')} ${note.quotedPoemOrFact || ''} ${note.aiAssist?.question || ''}`
        .toLowerCase().includes(keyword));
    // activeRecords 默认按更新时间倒序；这里只在用户显式切换时重排副本。
    if (this.memorySort === '最早') {
      notes.sort((a: ArchiveRecord, b: ArchiveRecord) =>
        a.updatedAt - b.updatedAt || (a.id < b.id ? -1 : 1));
    } else if (this.memorySort === '按档案') {
      notes.sort((a: ArchiveRecord, b: ArchiveRecord) => {
        const left = this.memorySite(a).name;
        const right = this.memorySite(b).name;
        if (left !== right) return left < right ? -1 : 1;
        return b.updatedAt - a.updatedAt;
      });
    }
    return notes;
  }

  private memoryTags(): string[] {
    const tags: string[] = [];
    activeRecords(this.snapshot.records, 'note').forEach((note: ArchiveRecord) => {
      note.tags.forEach((tag: string) => {
        if (tag && !tags.includes(tag)) tags.push(tag);
      });
    });
    return tags;
  }

  private memoryGroups(): MemoryMonthGroup[] {
    // 按档案排序时月份不再连续，分组会反复断开；直接用单组平铺，避免出现重复月份标题。
    if (this.memorySort === '按档案') return [{ label: '', notes: this.memoryNotes() }];
    return groupMemoryRecords(this.memoryNotes());
  }

  private memoryConditions(): string {
    const labels: string[] = [this.memorySort];
    if (this.memoryAiOnly) labels.push('AI 辅助');
    if (this.memoryTag !== '全部标签') labels.push(`#${this.memoryTag}`);
    if (this.memoryGallery) labels.push('画廊');
    return labels.join(' · ');
  }

  private hasMemoryFilters(): boolean {
    return this.memoryKeyword.length > 0 || this.memoryAiOnly || this.memoryTag !== '全部标签' || this.memorySort !== '最近';
  }

  private resetMemoryFilters(): void {
    this.memoryKeyword = ''; this.memoryAiOnly = false; this.memoryTag = '全部标签';
    this.memorySort = '最近'; this.memoryGallery = false;
  }

  private openMemoryFilters(): void {
    this.memorySearchController.stopEditing();
    this.paths.pushPathByName('memory-filters', '', !this.snapshot.reducedMotion);
  }

  private writingSites(all: boolean = false): HeritageSite[] {
    // 全部目录仍属于写手账的选择步骤；不借用普通档案 Tab，避免丢失新建后的返回路径。
    if (all) return HERITAGE_SITES;
    const recent = HERITAGE_SITES.filter((site: HeritageSite) => this.lastOpenedAt(site.id) > 0)
      .sort((a: HeritageSite, b: HeritageSite) => this.lastOpenedAt(b.id) - this.lastOpenedAt(a.id));
    // 没有浏览历史时提供明确的开始地点，不把推荐档案伪装成“最近浏览”。
    if (recent.length > 0) return recent.slice(0, 4);
    return HERITAGE_SITES.filter((site: HeritageSite) =>
      [AI_OBSERVATION_SITE_ID, 'zz-dahecun', 'smx-miaodigou'].includes(site.id));
  }

  private lastOpenedAt(siteId: string): number {
    return this.snapshot.records.reduce((latest: number, record: ArchiveRecord) =>
      record.kind === 'progress' && !record.deleted && record.siteId === siteId
        ? Math.max(latest, record.updatedAt) : latest, 0);
  }

  private libraryResults(): HeritageSite[] {
    const collected = this.collectedSiteIds();
    const visited = this.visitedSiteIds();
    const results = filterSites(HERITAGE_SITES, { keyword: this.libraryKeyword, city: this.libraryCity,
      era: this.libraryEra, type: this.libraryType })
      .filter((site: HeritageSite) => {
        if (this.libraryAiOnly && !isAiObservationSite(site.id)) return false;
        if (this.libraryScope === '已收藏') return collected.includes(site.id);
        if (this.libraryScope === '已浏览') return visited.includes(site.id);
        if (this.libraryScope === '未浏览') return !visited.includes(site.id);
        return true;
      });
    if (this.librarySort === '最近浏览') {
      // 未读档案排在已读之后，已读内部按最近一次打开时间倒序；不改写任何记录。
      results.sort((a: HeritageSite, b: HeritageSite) =>
        this.lastOpenedAt(b.id) - this.lastOpenedAt(a.id) || (a.name < b.name ? -1 : 1));
    }
    return results;
  }

  private editMemory(note: ArchiveRecord): void {
    if (note.roamingContext) {
      this.paths.pushPathByName('roam-memory', { noteId: note.id, edit: true } as RoamingNoteRoute, !this.snapshot.reducedMotion);
      return;
    }
    const site = this.siteFor(note.siteId);
    if (site) this.openSite(site, '', false, note.id);
  }

  private toggleNoteSelection(noteId: string): void {
    const index = this.memorySelectedIds.indexOf(noteId);
    if (index >= 0) this.memorySelectedIds.splice(index, 1);
    else this.memorySelectedIds.push(noteId);
    this.memorySelectedIds = this.memorySelectedIds.slice();
  }

  private exitNoteSelection(): void {
    this.memorySelectMode = false;
    this.memorySelectedIds = [];
  }

  private selectedNotes(): ArchiveRecord[] {
    // 选中集合独立于当前筛选：切换标签或搜索后，已选记录仍应完整复制/删除。
    return activeRecords(this.snapshot.records, 'note')
      .filter((note: ArchiveRecord) => this.memorySelectedIds.includes(note.id));
  }

  private selectedMarkdown(): string {
    return this.selectedNotes().map((note: ArchiveRecord) => {
      const site = this.memorySite(note);
      const tags = note.tags.map((tag: string) => `#${tag}`).join(' ');
      const ai = note.aiAssist ? `\n\n> AI 问题：${note.aiAssist.question}` : '';
      return `## ${site.name}\n\n${new Date(note.updatedAt).toLocaleString()}\n\n${note.body}` +
        `${tags ? `\n\n${tags}` : ''}${ai}`;
    }).join('\n\n---\n\n');
  }

  private async copySelectedNotes(): Promise<void> {
    if (this.memorySelectedIds.length === 0) return;
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.selectedMarkdown());
      await pasteboard.getSystemPasteboard().setData(data);
      this.getUIContext().getPromptAction().showToast({ message: `已复制 ${this.memorySelectedIds.length} 篇手账` });
    } catch {
      this.getUIContext().getPromptAction().showToast({ message: '复制失败，请稍后重试' });
    }
  }

  private confirmDeleteSelected(): void {
    const count = this.memorySelectedIds.length;
    if (count === 0 || this.saving) return;
    this.getUIContext().showAlertDialog({
      title: `删除 ${count} 页手账？`, message: '删除会随同一账号同步。',
      primaryButton: { value: '保留', action: () => {} },
      secondaryButton: { value: '确认删除', action: () => { this.deleteSelectedNotes(); } }
    });
  }

  private async deleteSelectedNotes(): Promise<void> {
    if (this.saving || this.memorySelectedIds.length === 0) return;
    const ids = this.memorySelectedIds.slice();
    const next = copySnapshot(this.snapshot);
    let changed = 0;
    next.records.forEach((record: ArchiveRecord) => {
      if (record.kind === 'note' && !record.deleted && ids.includes(record.id)) {
        // 与单篇删除一致：只写墓碑，保留视角与 AI 依据，供另一端同步时正确合并。
        record.deleted = true;
        record.updatedAt = nextTimestamp(next.records, Date.now());
        record.deviceId = next.deviceId;
        changed += 1;
      }
    });
    if (changed === 0) return;
    if (await this.commit(next)) {
      this.getUIContext().getPromptAction().showToast({ message: `已删除 ${changed} 页手账` });
      this.exitNoteSelection();
    }
  }

  private confirmDeleteNote(note: ArchiveRecord): void {
    if (this.saving) return;
    this.getUIContext().showAlertDialog({
      title: '删除这页手账？', message: '删除会随同一账号同步。',
      primaryButton: { value: '保留', action: () => {} },
      secondaryButton: { value: '删除', action: () => { this.deleteNoteRecord(note.id); } }
    });
  }

  private async deleteNoteRecord(noteId: string): Promise<void> {
    if (this.saving) return;
    const next = copySnapshot(this.snapshot);
    const note = next.records.find((item: ArchiveRecord) =>
      item.id === noteId && item.kind === 'note' && !item.deleted);
    if (!note) return;
    // 与详情页一致：只写墓碑，保留视角和 AI 依据，避免另一端同步时把旧记录复活。
    note.deleted = true;
    note.updatedAt = nextTimestamp(next.records, Date.now());
    note.deviceId = next.deviceId;
    if (await this.commit(next)) {
      this.getUIContext().getPromptAction().showToast({ message: '手账已删除' });
    }
  }

  private askMemory(note: ArchiveRecord): void {
    const site = this.siteFor(note.siteId);
    if (!site || !isAiObservationSite(site.id)) return;
    // 只预填这一篇手账的问题与观察，用户点击后才请求模型，不上传整个记忆库。
    const pose = note.snapshot3DPose;
    const poseJson = pose?.sceneRevision === 2 && pose.sceneType === 'relic_inspector' ? JSON.stringify(pose) : '';
    this.openSite(site, poseJson, true, '',
      note.aiAssist?.question || '请结合我的观察，带我继续看这件器物。', note.body);
  }

  private showMemory(section: string = '手账', aiOnly: boolean = false): void {
    // 从外部入口进入时回到默认识图，避免上次的排序或标签把结果藏起来。
    this.memorySection = section; this.memoryAiOnly = aiOnly; this.memoryKeyword = '';
    this.memorySort = '最近'; this.memoryTag = '全部标签'; this.exitNoteSelection(); this.currentTab = 2;
  }

  private showLibrary(city: string = CITIES[0], scope: string = '全部'): void {
    // 显式入口只携带自己的条件；档案页城市独立于首页沙盘，不写 this.city。
    this.libraryCity = city; this.libraryKeyword = ''; this.libraryEra = ERAS[0]; this.libraryType = TYPES[0];
    this.libraryAiOnly = false; this.libraryScope = scope; this.librarySort = '目录'; this.currentTab = 1;
    this.cultureEra = '全部年代'; this.cultureType = '全部类型';
    if (scope !== '全部') this.libraryKind = '遗址档案';
  }

  private siteFor(id: string): HeritageSite | undefined {
    return HERITAGE_SITES.find((site: HeritageSite) => site.id === id);
  }

  private memorySite(note: ArchiveRecord): HeritageSite {
    const site = culturalEntryForId(note.siteId);
    if (site) return site;
    // 未知档案只保留记录自身的身份与文字，不能拿目录首条文化内容替代它。
    return { id: note.siteId, name: '原档案暂不可用', city: '文字记忆', era: '', type: '未找到档案', tags: [],
      summary: '', overview: '', archaeology: '', history: '', poetry: '', travel: '',
      source: { title: '原档案暂不在当前目录中', url: '' }, reviewStatus: '档案信息不可用',
      illustration: '', accent: '', photos: [] };
  }

  private openMemory(note: ArchiveRecord, replay: boolean): void {
    if (note.paperContext) {
      this.paths.pushPathByName('paper-memory', { noteId: note.id } as MemoryRoute, !this.snapshot.reducedMotion);
      return;
    }
    if (note.roamingContext) {
      if (replay) this.openRoaming(note.roamingContext.chapterId, note.roamingContext.clueId);
      else this.paths.pushPathByName('roam-memory', { noteId: note.id } as RoamingNoteRoute, !this.snapshot.reducedMotion);
      return;
    }
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

  private openJourneyScroll(): void {
    // 长卷读取当前共享快照，路由不携带记录副本；编辑、删除或同步返回后仍显示最新个人记录。
    this.paths.pushPathByName('journey-scroll', '', !this.snapshot.reducedMotion);
  }

  private visitedCount(): number {
    // 同一档案的 opened 和四个探索主题共用 progress kind，统计必须按 siteId 去重。
    return this.visitedSiteIds().length;
  }

  @Builder
  destination(name: string, parameter: Object) {
    if (name === 'roaming') {
      RoamingChapterPage({ chapterId: (parameter as RoamingRoute).chapterId,
        initialClueId: (parameter as RoamingRoute).clueId || '', records: this.snapshot.records,
        saving: this.saving, reducedMotion: this.snapshot.reducedMotion, accountSignedIn: this.accountView.signedIn,
        onComplete: (clueId: string, choiceId: string, cityJson: string) => {
          this.completeRoaming((parameter as RoamingRoute).chapterId, clueId, choiceId, cityJson);
        },
        onPositionChange: (clueId: string) => { this.rememberRoamingPosition((parameter as RoamingRoute).chapterId, clueId); },
        onSave: (context: RoamingMemoryContext, body: string, tags: string[],
          assist?: AiMemoryAssist): Promise<boolean> => this.saveRoaming(context, body, tags, assist),
        onCityChange: (chapterId: string, cityJson: string) => { this.saveKaifengCity(chapterId, cityJson); },
        onOpenDig: (id: string) => { this.paths.pushPathByName('dig', { chapterId: id } as DigRoute, !this.snapshot.reducedMotion); },
        onKaifengAsk: (request: KaifengAiRequest) => this.askKaifeng(request),
        onKaifengColophon: (request: KaifengAiRequest) => this.writeKaifengColophon(request),
        onOpenSite: (id: string) => this.openCulturalContent(id),
        onOpenMemory: () => {
          const saved = activeRecords(this.snapshot.records, 'note').find(item => item.id === this.lastSavedNoteId);
          if (saved) this.openMemory(saved, false); else this.openPersonalRiver();
        }, onBack: () => { this.paths.pop(); }, onLogin: () => {
          if (this.accountView.signedIn && this.accountView.sessionReady) {
            this.paths.pushPathByName('profile-section', 'account', !this.snapshot.reducedMotion);
          } else this.openLogin();
        } })
    } else if (name === 'river-market') {
      RiverMarketPage({ records: this.snapshot.records, saving: this.saving,
        reducedMotion: this.snapshot.reducedMotion,
        onSaveState: (state: RiverMarketState, restart: boolean): Promise<boolean> => this.saveMarketState(state, restart),
        onSaveMemory: (body: string, quote: string, state: RiverMarketState): Promise<boolean> => this.saveMarketMemory(body, quote, state),
        onOpenContent: (id: string) => this.openCulturalContent(id), onBack: () => { this.paths.pop(); } })
    } else if (name === 'paper-home') {
      NavDestination() {
        PaperJourneyHome({ records: this.snapshot.records, reducedMotion: this.snapshot.reducedMotion,
          topClearance: 14, bottomClearance: 28,
          onOpen: (id: string) => this.openPaper(id), onLibrary: () => { this.paths.pop(); this.showLibrary(); },
          onMemory: () => { this.paths.pop(); this.showMemory(); }, onProfile: () => { this.paths.pop(); this.currentTab = 3; } })
      }.title('五城纸景').backgroundColor('#0B1621')
    } else if (name === 'paper') {
      PaperJourneyPage({ cityId: (parameter as PaperRoute).cityId, records: this.snapshot.records,
        reducedMotion: this.snapshot.reducedMotion, saving: this.saving,
        onSaveWork: (work: PaperWorkV1): Promise<boolean> => this.savePaperWork(work),
        onSaveMemory: (context: PaperMemoryContext, body: string): Promise<boolean> => this.savePaperMemory(context, body),
        onOpenContent: (id: string) => this.openCulturalContent(id), onBack: () => { this.paths.pop(); } })
    } else if (name === 'paper-memory') {
      PaperMemoryPage({ noteId: (parameter as MemoryRoute).noteId, records: this.snapshot.records,
        saving: this.saving, reducedMotion: this.snapshot.reducedMotion,
        onCurrentSnapshot: (): ArchiveSnapshot => this.snapshot,
        onCommit: (next: ArchiveSnapshot): Promise<boolean> => this.commit(next),
        onContinue: (id: string) => this.openPaper(id), onArchive: (id: string) => this.openCulturalContent(id),
        onShare: (note: ArchiveRecord) => { this.shareMemory(note); }, onBack: () => { this.paths.pop(); } })
    } else if (name === 'dig') {
      KaifengDigPage({ chapterId: (parameter as DigRoute).chapterId, records: this.snapshot.records,
        saving: this.saving,
        onDigChange: (chapterId: string, digJson: string) => { this.saveKaifengDig(chapterId, digJson); },
        onArchive: (body: string) => this.saveDigNote(body),
        onBack: () => { this.paths.pop(); } })
    } else if (name === 'roam-memory') {
      RoamingMemoryDetail({ snapshot: $snapshot, noteId: (parameter as RoamingNoteRoute).noteId,
        startEditing: (parameter as RoamingNoteRoute).edit === true, saving: this.saving,
        onCommit: (next: ArchiveSnapshot): Promise<boolean> => this.commit(next),
        onResolve: (id: string): ArchiveRecord | undefined => activeRecords(this.snapshot.records, 'note').find(item => item.id === id),
        onSnapshot: (): ArchiveSnapshot => this.snapshot,
        onOpenChapter: (chapterId: string, clueId: string) => { this.openRoaming(chapterId, clueId); },
        onShare: (note: ArchiveRecord) => { this.shareMemory(note); }, onBack: () => { this.paths.pop(); } })
    } else if (name === 'roam-scroll') {
      RoamingScrollPage({ records: this.snapshot.records,
        onRead: (note: ArchiveRecord) => this.openMemory(note, false),
        onOpenChapter: (id: string) => { this.openRoaming(id); },
        onOpenContent: (id: string) => this.openCulturalContent(id), onLegacyJourney: () => this.openJourneyScroll(),
        onBack: () => { this.paths.pop(); } })
    } else if (name === 'roam-system') {
      RoamingSystemPage({ onBack: () => { this.paths.pop(); } })
    } else if (name === 'site') {
      if (this.siteFor((parameter as SiteRoute).siteId)) {
        SiteDetail({
        site: this.siteFor((parameter as SiteRoute).siteId)!,
        snapshot: $snapshot, initialPoseJson: (parameter as SiteRoute).poseJson || '',
        startAiPanel: (parameter as SiteRoute).observe === true,
        initialNoteId: (parameter as SiteRoute).noteId || '',
        startNewNote: (parameter as SiteRoute).newNote === true,
        initialAiQuestion: (parameter as SiteRoute).question || '',
        initialAiObservation: (parameter as SiteRoute).observation || '',
        aiSignedIn: this.accountView.sessionReady, aiServiceConfigured: this.accountView.serviceConfigured,
        onCommit: (next: ArchiveSnapshot): Promise<boolean> => this.commit(next),
        onOpen: (site: HeritageSite) => this.openSite(site),
        onAiRequest: (request: AiObservationRequest): Promise<AiObservationReply> => this.aiObserve(request),
        onAiCancel: (): void => this.cancelAi(),
        onLogin: () => this.openLogin(),
        onReadMemory: (note: ArchiveRecord) => this.openMemory(note, false),
        onOpenJourney: () => this.openJourneyScroll()
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
    } else if (name === 'water') {
      WaterSituationPage()
    } else if (name === 'culture') {
      CultureAtlas({ snapshot: $snapshot, journeyId: (parameter as JourneyGraphRoute)?.journeyId || '', onOpen: (site: HeritageSite) => this.openSite(site) })
    } else if (name === 'journey-scroll') {
      JourneyScrollPage({ snapshot: $snapshot,
        onOpenSite: (site: HeritageSite) => this.openSite(site),
        onReadMemory: (note: ArchiveRecord) => this.openMemory(note, false),
        onReplayMemory: (note: ArchiveRecord) => this.openMemory(note, true),
        onOpenGraph: () => this.paths.pushPathByName('culture', { journeyId: 'earth-and-fire' } as JourneyGraphRoute,
          !this.snapshot.reducedMotion) })
    } else if (name === 'memory-filters') {
      MemoryFilterPage({ sort: this.memorySort, aiOnly: this.memoryAiOnly, gallery: this.memoryGallery,
        tag: this.memoryTag, tags: this.memoryTags(), keyword: this.memoryKeyword, resultCount: this.memoryNotes().length,
        lightEnabled: this.snapshot.lightEnabled, reducedMotion: this.snapshot.reducedMotion,
        onSort: (value: string) => { this.memorySort = value; }, onAiOnly: (value: boolean) => { this.memoryAiOnly = value; },
        onGallery: (value: boolean) => { this.memoryGallery = value; }, onTag: (value: string) => { this.memoryTag = value; },
        onReset: () => this.resetMemoryFilters(), onDone: () => { this.paths.pop(); } })
    } else if (name === 'memory-new' || name === 'memory-write-all') {
      this.memoryWritingPage(name === 'memory-write-all')
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
      ProfilePage({ snapshot: $snapshot, view: this.accountView, nativeView: this.nativeView, saving: this.saving,
        onNativeSync: () => { this.syncNative(true); },
        section: name === 'profile-section' ? parameter as string : '',
        onOpenSection: (section: string) => this.paths.pushPathByName('profile-section', section, !this.snapshot.reducedMotion),
        onOpenAi: () => this.openDulingAi(),
        onOpenMemory: (aiOnly: boolean) => {
          this.paths.clear(); this.showMemory('手账', aiOnly);
        },
        onOpenCollection: () => {
          this.paths.clear(); this.showMemory('收藏');
        },
        onOpenLibrary: (scope: string) => {
          this.paths.clear(); this.showLibrary(CITIES[0], scope);
        },
        university: this.university, studentNumber: this.studentNumber,
        onOpenSite: (id: string) => { const site = this.siteFor(id); if (site) this.openSite(site); },
        onOpenJourneyGraph: (id: string) => this.paths.pushPathByName('culture', { journeyId: id } as JourneyGraphRoute,
          !this.snapshot.reducedMotion),
        onOpenSystem: () => this.paths.pushPathByName('roam-system', '', !this.snapshot.reducedMotion),
        onCommit: (next: ArchiveSnapshot): Promise<boolean> => this.commit(next),
        onLogin: () => this.openLogin(), onLogout: () => { this.logoutAccount(); },
        onSync: () => { this.syncAccount(); }, onBack: () => { this.paths.pop(); } })
    } else {
      // 兜底：任何没匹配到的路由名都要看得见，而不是给用户一个空白页。
      // 注意 navDestination 的根节点必须是 NavDestination，否则内容不会被挂载。
      NavDestination() {
        Column({ space: 8 }) {
          Text('这个页面还没有接上').fontSize(16).fontWeight(FontWeight.Medium).fontColor(T.ink)
          Text(`路由：${name}`).fontSize(12).fontColor(T.muted).id('route-unmatched')
          Button('返回', { type: ButtonType.Normal }).height(38).fontSize(13)
            .fontColor(T.onAccent).backgroundColor(T.accent).borderRadius(9)
            .onClick(() => { this.paths.pop(); })
        }.width('100%').height('100%').justifyContent(FlexAlign.Center).backgroundColor(T.canvas)
      }.hideTitleBar(true)
    }
  }

  @Builder
  profileEntry() {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 1 }) {
        // miniBar 是 60dp 的圆形，原先是 23vp 图标 + 12 号字，整体被挤出圆外。
        // 收到 20vp / 10 号并保持「我的」标签，设备用例仍按 profile-entry-label 取边界。
        SymbolGlyph($r('sys.symbol.person')).fontSize('20vp').fontColor([T.accent])
        Text('我的').fontSize(10).maxFontScale(1.1).fontColor(T.ink).id('profile-entry-label')
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    }.width('100%').height('100%').padding(0).backgroundColor(Color.Transparent)
      .borderRadius(30).accessibilityText('打开我的页面').id('profile-entry')
      .onClick(() => this.paths.pushPathByName('profile', '', !this.snapshot.reducedMotion))
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
    }.width('100%').padding({ top: 20, bottom: 20, left: 16, right: 16 })
      .backgroundColor(T.surface).borderRadius(12).margin({ bottom: 12 })
  }

  @Builder
  memoryEmptyState() {
    // 记忆空态在同一条“零结果”分支中也会切换 AI / 标签 / 搜索条件。
    // 在 Builder 内直接读取状态，避免把动态标题作为值参数传给静态空态后保留上一次文案。
    Column({ space: 12 }) {
      Stack() {
        Rect().width(44).height(44).radius(14).fill(T.accentSoft).rotate({ angle: -6 })
        SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(22).fontColor([T.accent])
      }.width(52).height(52)
      Text(this.memoryKeyword ? '没有找到这段记忆' :
        (this.memoryAiOnly ? '还没有 AI 辅助手账' :
          (this.memoryTag !== '全部标签' ? `#${this.memoryTag} 还没有手账` : '还没有留下手账')))
        .fontSize(15).fontWeight(FontWeight.Medium).fontColor(T.ink).textAlign(TextAlign.Center).id('memory-empty-title')
      Text(this.memoryKeyword ? '换一个档案名、问题或标签试试。' :
        (this.memoryTag !== '全部标签' ? '换一个标签，或清除筛选查看全部。' : '从一个好奇的问题开始。'))
        .fontSize(12).fontColor(T.muted).lineHeight(18).textAlign(TextAlign.Center).id('memory-empty-hint')
    }.width('100%').padding({ top: 20, bottom: 20, left: 16, right: 16 })
      .backgroundColor(T.surface).borderRadius(12).margin({ bottom: 12 })
  }

  @Builder
  filterChip(label: string, active: boolean, id: string, action: () => void) {
    Button(label, { type: ButtonType.Normal }).id(id).height(32).fontSize(F.caption)
      .padding({ left: 11, right: 11 }).fontColor(active ? T.onAccent : T.muted)
      .backgroundColor(active ? T.accent : T.surface).borderRadius(9)
      .border({ width: 1, color: active ? T.accent : T.line, radius: 9 })
      .margin({ right: 6, bottom: 4 })
      .accessibilityText(label).onClick(action)
  }

  @Builder
  header() {
    Row({ space: 4 }) {
      // 顶栏改成“当前页标题 + 两个动作”的应用栏：原来是品牌胶囊加一枚书签，
      // 既不说自己在哪一页，也像网页的 logo 区。
      Text(this.currentTab === 1 ? '文化库' : this.currentTab === 2 ? '记忆' : this.currentTab === 3 ? '我的' : '云河纪')
        .fontSize(22).fontWeight(FontWeight.Bold).fontColor('#F4ECDD').layoutWeight(1)
        .maxLines(1).id('top-title')
      Button({ type: ButtonType.Normal }) {
        SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(20).fontColor(['#F4ECDD'])
      }.width(40).height(40).borderRadius(20).backgroundColor(Color.Transparent)
        .accessibilityText('搜索文化档案').id('top-search')
        .onClick(() => { this.currentTab = 1; })
      Button({ type: ButtonType.Normal }) {
        SymbolGlyph($r('sys.symbol.bookmark')).fontSize(20).fontColor(['#F4ECDD'])
      }.width(40).height(40).borderRadius(20).backgroundColor(Color.Transparent)
        .accessibilityText('打开我的收藏').id('top-collection').onClick(() => this.showMemory('收藏'))
    }.width('100%').padding({ left: 16, right: 8 }).id('top-navigation-content')
  }

  private tabStyle(index: number, title: string, icon: Resource): BottomTabBarStyle {
    // 原生 BottomTabBarStyle 才能由 HdsTabs 接管胶囊、选中镜片与触摸反馈。
    // id 绑定到官方页签，保留自动化与无障碍定位，不再返回自绘的三个白色按钮。
    return new BottomTabBarStyle({ normal: new SymbolGlyphModifier(icon).fontColor(['#A2B4B4']),
      selected: new SymbolGlyphModifier(icon).fontColor(['#E9B17D']) }, title)
      .labelStyle({ selectedColor: '#E9B17D', unselectedColor: '#A2B4B4' }).id(`tab-${index}`);
  }

  private topClearance(): number { return Math.max(76, this.getUIContext().fp2px(64) / this.getUIContext().vp2px(1)); }
  private contentClearance(): number {
    return this.incomingMemoryId || this.incomingChapterId ? 12 : this.topClearance();
  }

  // 浮动栏是穿透式的：关掉 barOverlap 会连「我的」miniBar 一起消失（实测）。
  // 因此保留穿透，但把内容底部留足一整条浮动栏 + miniBar 的高度，静止时不被遮住。
  private dockClearance(): number { return 104; }

  private statusBarInk(): string {
    // 四个首页签的栏底都是夜色；HDS 的初始/滚动态只管理文字颜色，
    // 状态栏背景由根容器 expandSafeArea 与窗口兜底承接。
    return '#FFF4ECDD';
  }

  @Builder
  memoryWritingPage(all: boolean = false) {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          Text('这一页，留给哪一段？').fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink).width('100%')
          Text('从城市的一个片段开始，或为读过的档案补一页手账。').fontSize(F.small).fontColor(T.muted).lineHeight(23).width('100%')
          if (!all) {
            Text('从漫游片段开始').fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.mintInk).width('100%')
            ForEach(ROAM_CHAPTERS, (chapter: RoamChapter) => {
              Button({ type: ButtonType.Normal }) {
                Row({ space: 12 }) {
                  Text(chapter.city).fontSize(15).fontColor(T.mintInk).width(60)
                  Text(chapter.title).fontSize(14).fontColor(T.ink).layoutWeight(1)
                  Text('›').fontSize(20).fontColor(T.muted)
                }.width('100%').padding(15)
              }.width('100%').padding(0).backgroundColor(T.mint).borderRadius(12)
                .onClick(() => { this.openRoaming(chapter.id); }).id(`memory-write-roam-${chapter.id}`)
            }, (chapter: RoamChapter) => chapter.id)
          }
          Text(all ? `全部文化档案 · ${HERITAGE_SITES.length} 处` :
            (this.visitedCount() > 0 ? '最近浏览的档案' : '从一处好奇开始'))
            .fontSize(F.caption).fontColor(T.accent).width('100%').margin({ top: 8 }).id('memory-write-scope')
          ForEach(this.writingSites(all), (site: HeritageSite) => {
            Button({ type: ButtonType.Normal }) {
              Row({ space: 14 }) {
                Image(siteIllustration(site)).width(56).height(56).objectFit(ImageFit.Cover).borderRadius(12)
                Column({ space: 6 }) {
                  Text(site.name).fontSize(F.card).fontWeight(FontWeight.Medium).fontColor(T.ink).width('100%')
                  Text(`${site.city} · ${site.era} · ${site.type}`).fontSize(F.caption).fontColor(T.muted).width('100%')
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(19).fontColor([T.accent])
              }.width('100%').padding(16)
            }.width('100%').padding(0).backgroundColor(T.surface).borderRadius(17)
              .border({ width: 1, color: T.line, radius: 17 }).id(`memory-write-${site.id}`)
              .accessibilityText(`为${site.name}写一页手账`)
              .onClick(() => { this.openSite(site, '', false, '', '', '', true); })
          }, (site: HeritageSite) => site.id)
          if (!all) {
            Button('从全部档案选一处', { type: ButtonType.Normal }).width('100%').height(44)
              .fontSize(F.small).fontColor(T.accent).backgroundColor(T.accentSoft).borderRadius(12)
              .id('memory-write-browse').onClick(() => {
                // 只替换当前选择页：取消时直接回记忆并保留原筛选；
                // 真正选定档案后再由 openSite(newNote=true) 统一清理筛选并打开新编辑器。
                this.paths.replacePathByName('memory-write-all', '', !this.snapshot.reducedMotion);
              })
          }
        }.width('100%').constraintSize({ maxWidth: 720 }).alignItems(HorizontalAlign.Start).padding(20)
      }.width('100%').height('100%').align(Alignment.Top).id(all ? 'memory-write-all-scroll' : 'memory-write-scroll')
    }.title('写一页手账', { systemMaterial: HarmonyEffects.material(this.snapshot.lightEnabled, this.snapshot.reducedMotion) })
      .backgroundColor(T.canvas).id(all ? 'memory-write-all-page' : 'memory-write-page')
  }

  @Builder
  archive() {
    Scroll(this.archiveScroller) {
      Column({ space: 12 }) {
        Row({ space: 8 }) {
          Text('我的黄河记忆').fontSize(20).fontWeight(FontWeight.Bold).fontColor(T.ink).layoutWeight(1)
          if (this.memorySection === '手账' && (this.memoryNotes().length > 0 || this.memorySelectMode)) {
            Button(this.memorySelectMode ? '完成' : '管理', { type: ButtonType.Normal })
              .height(32).fontSize(12).padding({ left: 12, right: 12 })
              .fontColor(this.memorySelectMode ? T.onAccent : T.accent)
              .backgroundColor(this.memorySelectMode ? T.accent : T.accentSoft).borderRadius(9)
              .id('memory-manage')
              .onClick(() => {
                if (this.memorySelectMode) this.exitNoteSelection();
                else this.memorySelectMode = true;
              })
          }
          Button('写一页', { type: ButtonType.Normal }).height(34).fontSize(13)
            .padding({ left: 14, right: 14 }).backgroundColor(T.accent).fontColor(T.onAccent).borderRadius(10)
            .accessibilityText('选择文化档案，写一页手账').id('memory-new')
            .onClick(() => this.paths.pushPathByName('memory-new', '', !this.snapshot.reducedMotion))
        }.width('100%')
        Row({ space: 4 }) {
          ForEach(['手账', '收藏'], (section: string, index: number) => {
            Button({ type: ButtonType.Normal }) {
              Row({ space: 8 }) {
                Text(section).fontSize(F.small).fontColor(this.memorySection === section ? T.onAccent : T.muted)
                Text(`${activeRecords(this.snapshot.records, index === 0 ? 'note' : 'favorite').length}`)
                  .fontSize(F.caption).fontColor(this.memorySection === section ? T.onAccent : T.muted)
                  .id(index === 0 ? 'note-count' : 'collection-count')
              }.justifyContent(FlexAlign.Center).width('100%')
            }.layoutWeight(1).height(32).fontColor(this.memorySection === section ? T.onAccent : T.muted)
              .backgroundColor(this.memorySection === section ? T.accent : Color.Transparent).borderRadius(7)
              .id(`memory-section-${index}`).onClick(() => {
                this.memorySection = section; this.memoryKeyword = ''; this.exitNoteSelection();
              })
          })
        }.width('100%').padding(3).backgroundColor(T.soft).borderRadius(9)
        if (!this.memorySelectMode) {
          Button({ type: ButtonType.Normal }) {
            Row({ space: 8 }) {
              Text('我的黄河长卷').fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.mintInk)
              Text('五城 · 我留下的片刻').fontSize(F.caption).fontColor(T.muted).layoutWeight(1)
              Text('展开 ›').fontSize(F.caption).fontColor(T.yellowInk)
            }.width('100%')
          }.width('100%').height(44).padding({ left: 12, right: 12 }).backgroundColor(T.mint).borderRadius(10)
            .id('memory-journey-scroll').accessibilityText('展开我的黄河长卷')
            .onClick(() => this.openPersonalRiver())
        }
        if (this.memorySection === '手账' && this.memorySelectMode) {
          Row({ space: 8 }) {
            Text(`已选 ${this.memorySelectedIds.length} 篇`).fontSize(F.caption).fontWeight(FontWeight.Medium)
              .fontColor(T.ink).layoutWeight(1).id('memory-selected-count')
            Button('复制', { type: ButtonType.Normal }).id('memory-copy-selected')
              .height(34).fontSize(F.caption).padding({ left: 12, right: 12 })
              .fontColor(T.mintInk).backgroundColor(T.mint).borderRadius(9)
              .enabled(this.memorySelectedIds.length > 0 && !this.saving)
              .onClick(() => { this.copySelectedNotes(); })
            Button('删除', { type: ButtonType.Normal }).id('memory-delete-selected')
              .height(34).fontSize(F.caption).padding({ left: 12, right: 12 })
              .fontColor(T.accent).backgroundColor(T.accentSoft).borderRadius(9)
              .enabled(this.memorySelectedIds.length > 0 && !this.saving)
              .onClick(() => { this.confirmDeleteSelected(); })
          }.width('100%').padding({ left: 12, right: 8, top: 6, bottom: 6 })
            .backgroundColor(T.surface).borderRadius(11).border({ width: 1, color: T.line, radius: 11 })
            .id('memory-selection-bar')
        }
        Row({ space: 8 }) {
          Search({ value: this.memoryKeyword, controller: this.memorySearchController,
            placeholder: this.memorySection === '手账' ? '搜索手账、标签或问题' : '搜索收藏的档案' })
            .height(44).layoutWeight(1).fontColor(T.ink).placeholderColor(T.muted).backgroundColor(T.surface).borderRadius(12)
            .searchButton('查找', { fontColor: T.accent }).id('memory-search')
            .onChange((value: string) => { this.memoryKeyword = value; })
            .onSubmit(() => this.memorySearchController.stopEditing())
          if (this.memorySection === '手账') {
            Button('筛选', { type: ButtonType.Normal }).height(44).fontSize(F.small)
              .padding({ left: 15, right: 15 }).borderRadius(12).id('memory-filter-open')
              .fontColor(this.hasMemoryFilters() || this.memoryGallery ? T.accent : T.muted)
              .backgroundColor(this.hasMemoryFilters() || this.memoryGallery ? T.accentSoft : T.surface)
              .accessibilityText('筛选手账与切换视图').onClick(() => this.openMemoryFilters())
          }
        }.width('100%')
        if (this.memorySection === '手账') {
        Row({ space: 8 }) {
          Text(`${this.memoryNotes().length} 篇`).fontSize(F.caption).fontColor(T.muted).id('memory-result-count')
          Text(this.memoryConditions()).fontSize(F.caption).fontColor(T.muted).layoutWeight(1)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).id('memory-conditions')
          if (this.hasMemoryFilters()) {
            Button('清除', { type: ButtonType.Normal }).height(30).fontSize(F.caption)
              .padding({ left: 8, right: 8 }).fontColor(T.accent).backgroundColor(Color.Transparent)
              .id('memory-filter-clear').onClick(() => this.resetMemoryFilters())
          }
        }.width('100%')
        if (this.memoryNotes().length === 0) {
          this.memoryEmptyState()
          Button(this.memoryKeyword ? '清空搜索' :
            (this.memoryTag !== '全部标签' ? '清除标签筛选' : '沿河开始一段漫游'), { type: ButtonType.Normal })
            .width('100%').height(46).fontSize(14).fontColor(T.onAccent).backgroundColor(T.accent).borderRadius(10)
            .id('memory-empty-action')
            .onClick(() => {
              if (this.memoryKeyword) this.memoryKeyword = '';
              else if (this.memoryTag !== '全部标签') this.memoryTag = '全部标签';
              else this.currentTab = 0;
            })
        }
        if (this.memoryGallery) {
          ForEach(this.memoryNotes(), (note: ArchiveRecord) => {
            MemoryPostcardItem({ note, site: this.memorySite(note), compact: false,
              syncLabel: this.accountView.signedIn && recordVersionConfirmed(note, this.accountConfirmed) ? '已传至账号' : '已保存在本机',
              canAsk: isAiObservationSite(note.siteId), editable: true, busy: this.saving,
              selectMode: this.memorySelectMode, selected: this.memorySelectedIds.includes(note.id),
              onSelect: () => this.toggleNoteSelection(note.id),
              onEdit: () => this.editMemory(note), onDelete: () => this.confirmDeleteNote(note),
              onAsk: () => this.askMemory(note),
              onOpen: () => this.openMemory(note, false),
              onPose: () => this.openMemory(note, true) })
          }, (note: ArchiveRecord) => `${note.id}:${note.updatedAt}:gallery`)
        } else {
          ForEach(this.memoryGroups(), (group: MemoryMonthGroup) => {
            if (group.label) {
              Row({ space: 8 }) {
                Text(group.label).fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.ink)
                Text(`${group.notes.length} 篇`).fontSize(F.caption).fontColor(T.muted)
                Blank()
                Row().width(28).height(1).backgroundColor(T.line)
              }.width('100%').padding({ top: 8, bottom: 2 }).id(`memory-month-${group.label}`)
            }
            ForEach(group.notes, (note: ArchiveRecord) => {
              MemoryPostcardItem({ note, site: this.memorySite(note), compact: true,
                syncLabel: this.accountView.signedIn && recordVersionConfirmed(note, this.accountConfirmed) ? '已传至账号' : '已保存在本机',
                canAsk: isAiObservationSite(note.siteId), editable: true, busy: this.saving,
                selectMode: this.memorySelectMode, selected: this.memorySelectedIds.includes(note.id),
                onSelect: () => this.toggleNoteSelection(note.id),
                onEdit: () => this.editMemory(note), onDelete: () => this.confirmDeleteNote(note),
                onAsk: () => this.askMemory(note),
                onOpen: () => this.openMemory(note, false),
                onPose: () => this.openMemory(note, true) })
            }, (note: ArchiveRecord) => `${note.id}:${note.updatedAt}:list`)
          }, (group: MemoryMonthGroup) =>
            `${group.label}:${group.notes.length}:${group.notes[0]?.id || ''}:${group.notes[0]?.updatedAt || 0}`)
        }
        } else {
        Row() {
          Text('收藏档案').fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink).layoutWeight(1)
          Select(['全部标签'].concat(COLLECTION_TAGS).map((value: string): SelectOption => ({ value })))
            .value(this.collectionTag).font({ size: F.small }).fontColor(T.ink).backgroundColor(T.surface)
            .height(44).borderRadius(10)
            .onSelect((_index: number, value: string) => { this.collectionTag = value; }).id('collection-filter')
        }.width('100%').padding({ top: 2, bottom: 4 })
        if (this.collections().length + this.cultureCollectionCount() === 0) {
          this.emptyState('这个分类还没有收藏', $r('sys.symbol.bookmark'), '遇到喜欢的文化档案，点一下收藏。')
        }
        SiteGrid({ sites: this.collections(), gridId: 'archive-site-grid',
          collectedIds: this.collectedSiteIds(), visitedIds: this.visitedSiteIds(),
          onOpen: (site: HeritageSite) => this.openSite(site) })
        RoamingFavoritesSection({ records: this.snapshot.records, keyword: this.memoryKeyword,
          tag: this.collectionTag, saving: this.saving, onOpen: (id: string) => this.openCulturalContent(id),
          onTag: (id: string, tag: string) => { this.tagCultureFavorite(id, tag); },
          onRemove: (id: string) => { this.toggleCultureFavorite(id); } })
        if (this.collections().length + this.cultureCollectionCount() === 0) {
          Button('去档案看看', { type: ButtonType.Normal }).id('memory-browse-archives').width('100%').height(42)
            .fontColor(T.accent).backgroundColor(T.accentSoft).onClick(() => this.showLibrary())
        }
        }
      }.width('100%').constraintSize({ maxWidth: 760 })
        .padding({ left: 16, right: 16, top: this.contentClearance(), bottom: this.dockClearance() })
    }.height('100%').width('100%').align(Alignment.Top).id('archive-scroll')
  }

  // 文化库页尾部的 AI 观察入口行：标题与起始问题来自知识域，点击进入对应对象详情。
  @Builder
  archiveAiRow(siteId: string, entryId: string) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 10 }) {
        if (this.siteFor(siteId)) {
          Image(siteIllustration(this.siteFor(siteId)!)).width(42).height(48).objectFit(ImageFit.Contain)
        }
        Column({ space: 3 }) {
          Text(this.aiObjectName(siteId)).fontSize(F.small).fontWeight(FontWeight.Medium)
            .fontColor(T.mintInk).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.aiQuestionFor(siteId)).fontSize(F.caption).fontColor(T.ink).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(15).fontColor([T.mintInk])
      }.width('100%').padding(10)
    }.width('100%').padding(0).backgroundColor(T.surface).borderRadius(12).id(entryId)
      .accessibilityText(`和 AI 一起观察${this.aiObjectName(siteId)}`)
      .onClick(() => this.openAiSite(siteId))
  }

  @Builder
  device() {
    Scroll(this.deviceScroller) {
      Column({ space: 12 }) {
        // 顶栏已经写了「文化库」，页内不再重复大标题，只留结果数与轻量操作。
        Row({ space: 10 }) {
          Text(`${this.libraryResults().length} 处档案`).fontSize(12).fontColor(T.muted).layoutWeight(1)
            .id('library-result-count')
          ForEach(['目录', '最近浏览'], (label: string, index: number) => {
            Button(index === 0 ? '目录' : '最近', { type: ButtonType.Normal }).height(28).fontSize(11)
              .padding({ left: 8, right: 8 })
              .fontColor(this.librarySort === label ? T.accent : T.tertiary)
              .backgroundColor(this.librarySort === label ? T.accentSoft : Color.Transparent).borderRadius(7)
              .id(`library-sort-${index}`).onClick(() => { this.librarySort = label; })
          }, (label: string) => `library-sort-${label}-${this.librarySort === label}`)
          Button('重置', { type: ButtonType.Normal }).height(28).fontSize(11).padding({ left: 8, right: 8 })
            .fontColor(T.accent).backgroundColor(Color.Transparent).id('library-reset').onClick(() => {
              this.libraryKeyword = ''; this.libraryCity = CITIES[0]; this.libraryEra = ERAS[0]; this.libraryType = TYPES[0];
              this.libraryAiOnly = false; this.libraryScope = '全部'; this.librarySort = '目录';
            })
        }.width('100%').height(30)

        // 分段控件收成 32dp 的小胶囊：原来两条 40dp 整宽按钮像网页 Tab，占高也重。
        Row({ space: 4 }) {
          ForEach(['文化篇章', '遗址档案'], (label: string) => {
            Button(label, { type: ButtonType.Normal }).layoutWeight(1).height(32).fontSize(13)
              .fontColor(this.libraryKind === label ? T.onAccent : T.muted)
              .backgroundColor(this.libraryKind === label ? T.accent : Color.Transparent)
              .borderRadius(8)
              .onClick(() => { this.libraryKind = label; })
              .id(label === '文化篇章' ? 'library-roaming' : 'library-heritage')
          })
        }.width('100%').padding(3).backgroundColor(T.soft).borderRadius(10)

        Search({ value: this.libraryKeyword, controller: this.librarySearchController, placeholder: '搜索遗址、文物或文化线索' })
          .height(42).fontColor(T.ink).placeholderColor(T.muted).backgroundColor(T.surface).borderRadius(11)
          .searchButton('检索', { fontColor: T.accent }).id('library-search')
          .onChange((value: string) => { this.libraryKeyword = value; })
          .onSubmit(() => this.librarySearchController.stopEditing())

        // 城市/年代/类型三个维度并进一条可横滑控件行。原来是四条整宽下拉各占一行，
        // 首屏几乎全被筛选吃掉，看不到任何条目。
        Scroll() {
          Row({ space: 8 }) {
            if (this.libraryKind === '文化篇章') {
              Select(CITIES.map((value: string): SelectOption => ({ value }))).value(this.libraryCity)
                .selected(CITIES.indexOf(this.libraryCity)).width(100).height(34).font({ size: 12 })
                .fontColor(T.ink).backgroundColor(T.surface).borderRadius(10)
                .onSelect((_index: number, value: string) => { this.libraryCity = value; })
              Select(ROAM_LIBRARY_ERAS.map((value: string): SelectOption => ({ value }))).value(this.cultureEra)
                .width(100).height(34).font({ size: 12 }).fontColor(T.ink).backgroundColor(T.surface)
                .onSelect((_index: number, value: string) => { this.cultureEra = value; }).id('culture-era')
              Select(ROAM_LIBRARY_TYPES.map((value: string): SelectOption => ({ value }))).value(this.cultureType)
                .width(100).height(34).font({ size: 12 }).fontColor(T.ink).backgroundColor(T.surface)
                .onSelect((_index: number, value: string) => { this.cultureType = value; }).id('culture-type')
            } else {
              Select(CITIES.map((value: string): SelectOption => ({ value }))).value(this.libraryCity)
                .selected(CITIES.indexOf(this.libraryCity)).width(100).height(34).font({ size: 12 })
                .fontColor(T.ink).backgroundColor(T.surface).id('library-city')
                .onSelect((_index: number, value: string) => { this.libraryCity = value; })
              Select(ERAS.map((value: string): SelectOption => ({ value }))).value(this.libraryEra)
                .selected(ERAS.indexOf(this.libraryEra)).width(100).height(34).font({ size: 12 })
                .fontColor(T.ink).backgroundColor(T.surface).id('library-era')
                .onSelect((_index: number, value: string) => { this.libraryEra = value; })
              Select(TYPES.map((value: string): SelectOption => ({ value }))).value(this.libraryType)
                .selected(TYPES.indexOf(this.libraryType)).width(100).height(34).font({ size: 12 })
                .fontColor(T.ink).backgroundColor(T.surface).id('library-type')
                .onSelect((_index: number, value: string) => { this.libraryType = value; })
              Row({ space: 5 }) {
                Checkbox({ name: 'ai-library' }).select(this.libraryAiOnly).selectedColor(T.mintInk)
                  .width(16).height(16).id('library-ai-filter')
                  .onChange((value: boolean) => { this.libraryAiOnly = value; })
                Text('可观察').fontSize(12).fontColor(this.libraryAiOnly ? T.mintInk : T.muted)
              }.height(34).padding({ left: 8, right: 10 })
                .backgroundColor(this.libraryAiOnly ? T.mint : T.surface).borderRadius(10)
            }
          }.height(34)
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')

        // 范围与排序并成一行 28dp 芯片，不再各占一整段。
        Scroll() {
          Row({ space: 6 }) {
            ForEach(['全部', '已收藏', '已浏览', '未浏览'], (label: string, index: number) => {
              this.filterChip(label, this.libraryScope === label, `library-scope-${index}`,
                () => { this.libraryScope = label; })
            }, (label: string) => `scope-${label}-${this.libraryScope === label}`)
          }.height(30)
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')


        if (this.libraryResults().length === 0) {
          this.emptyState('没有符合条件的档案', $r('sys.symbol.magnifyingglass'), '可清空关键词或重置筛选。')
        }
        if (this.libraryKind === '文化篇章') {
          RoamingLibrarySection({ records: this.snapshot.records, keyword: this.libraryKeyword, city: this.libraryCity,
            era: this.cultureEra, type: this.cultureType,
            onExplore: (chapterId: string, clueId: string) => { this.openRoaming(chapterId, clueId); },
            onFavorite: (id: string) => { this.toggleCultureFavorite(id); } })
        } else {
          SiteGrid({ sites: this.libraryResults(),
            gridId: 'archive-library-grid',
            collectedIds: this.collectedSiteIds(), visitedIds: this.visitedSiteIds(),
            onOpen: (site: HeritageSite) => this.openSite(site) })
        }
        // AI 观察入口放在列表之后：它是延伸能力，不该压住目录第一屏。
        Column({ space: 6 }) {
          Row({ space: 8 }) {
            Text('和 AI 一起观察').fontSize(13).fontWeight(FontWeight.Medium).fontColor(T.mintInk)
            Blank()
            Text('2 件可问').fontSize(11).fontColor(T.mintInk)
          }.width('100%')
          this.archiveAiRow('zz-duling-fangding', 'library-ai-open')
          this.archiveAiRow('zz-dahecun', 'library-ai-open-dahecun')
        }.width('100%').padding(12).backgroundColor(T.mint).borderRadius(12).id('library-ai-card')
          .margin({ top: 4 })
        Text(this.saving ? '正在保存本机档案' : '收藏与浏览记录保存在本机，登录后随账号同步。')
          .fontSize(11).fontColor(T.tertiary).lineHeight(17).width('100%').padding({ top: 2, bottom: 6 })
      }.width('100%').constraintSize({ maxWidth: 640 })
        .padding({ left: 16, right: 16, top: this.contentClearance(), bottom: this.dockClearance() })
    }.height('100%').width('100%').align(Alignment.Top).id('device-scroll')
  }

  @Builder
  mainPage() {
    Stack() {
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
            if (this.incomingMemoryId || this.incomingChapterId) {
              Row({ space: 8 }) {
                Text(this.incomingMemoryId ? '另一端的记忆已收到' : '另一端的漫游进度已收到')
                  .fontSize(12).fontColor(T.mintInk).layoutWeight(1).id('roam-incoming-status')
                Button(this.incomingMemoryId ? '翻开' : '继续', { type: ButtonType.Normal }).fontSize(12).height(32)
                  .fontColor(T.mintInk).backgroundColor(T.surface).onClick(() => {
                    if (this.incomingMemoryId) {
                      const note = activeRecords(this.snapshot.records, 'note').find((item: ArchiveRecord) => item.id === this.incomingMemoryId);
                      this.incomingMemoryId = ''; if (note) this.openMemory(note, false);
                    } else {
                      const id = this.incomingChapterId; this.incomingChapterId = '';
                      if (id === 'river-market') this.openMarket();
                      else if (PAPER_CITIES.some((city: PaperCity) => city.id === id)) this.openPaper(id);
                      else this.openRoaming(id);
                    }
                  }).id('roam-incoming-open')
                Button('稍后', { type: ButtonType.Normal }).fontSize(11).height(32).fontColor(T.muted)
                  .backgroundColor(Color.Transparent).onClick(() => { this.incomingMemoryId = ''; this.incomingChapterId = ''; })
              }.width('100%').padding({ left: 16, right: 12, top: 6, bottom: 6 }).backgroundColor(T.mint)
                .margin({ top: this.topClearance() })
            }
            HdsTabs({ controller: this.tabsController, index: this.currentTab }) {
              TabContent() {
                RiverMarketHome({ records: this.snapshot.records, reducedMotion: this.snapshot.reducedMotion,
                  topClearance: this.contentClearance(), bottomClearance: this.dockClearance(), scroller: this.exploreScroller,
                  onOpen: () => this.openMarket(), onLibrary: () => this.showLibrary(),
                  onLegacyPaper: () => { this.paths.pushPathByName('paper-home', '', !this.snapshot.reducedMotion); } })
              }.tabBar(this.tabStyle(0, '漫游', $r('sys.symbol.map')))
              TabContent() {
                PaperLibrarySection({ records: this.snapshot.records, topClearance: this.contentClearance(),
                  bottomClearance: this.dockClearance(), scroller: this.deviceScroller,
                  initialCity: this.libraryCity, initialScope: this.libraryScope,
                  onOpen: (id: string) => this.openCulturalContent(id),
                  onLegacy: (id: string) => { this.openRoaming(id); }, onPaper: (id: string) => this.openPaper(id),
                  onToggleFavorite: (id: string) => { this.toggleCultureFavorite(id); } })
              }.tabBar(this.tabStyle(1, '文化库', $r('sys.symbol.folder')))
              TabContent() {
                PaperMemoryShelf({ records: this.snapshot.records, topClearance: this.contentClearance(),
                  bottomClearance: this.dockClearance(), scroller: this.archiveScroller,
                  initialSection: this.memorySection, initialAiOnly: this.memoryAiOnly,
                  onRead: (note: ArchiveRecord) => this.openMemory(note, false),
                  onWrite: () => this.paths.pushPathByName('memory-new', '', !this.snapshot.reducedMotion),
                  onOpenCollection: (id: string) => this.openCulturalContent(id), onLegacyScroll: () => this.openPersonalRiver(),
                  onContinue: (id: string) => this.openPaper(id), onEdit: (note: ArchiveRecord) => {
                    if (note.paperContext) this.openMemory(note, false); else this.editMemory(note);
                  },
                  onDelete: (note: ArchiveRecord) => this.confirmDeleteMemory(note) })
              }.tabBar(this.tabStyle(2, '记忆', $r('sys.symbol.bookmark')))
              TabContent() {
                PaperProfileSection({ view: this.accountView, nativeView: this.nativeView, records: this.snapshot.records,
                  topClearance: this.contentClearance(), bottomClearance: this.dockClearance(),
                  onAccount: () => this.paths.pushPathByName('profile-section', 'account', !this.snapshot.reducedMotion),
                  onStorage: () => this.paths.pushPathByName('profile-section', 'data', !this.snapshot.reducedMotion),
                  onPreferences: () => this.paths.pushPathByName('profile-section', 'preferences', !this.snapshot.reducedMotion),
                  onSources: () => this.paths.pushPathByName('profile-section', 'about', !this.snapshot.reducedMotion),
                  onSystems: () => this.paths.pushPathByName('roam-system', '', !this.snapshot.reducedMotion),
                  onLegacy: () => this.openPersonalRiver() })
              }.tabBar(this.tabStyle(3, '我的', $r('sys.symbol.person')))
            }.width('100%').layoutWeight(1)
              // HdsTabs 的 index 是受控属性：用户点击切页后必须把最新 index 写回 currentTab，
              // 否则任意状态重渲染（如 5 秒同步定时器）都会把内容弹回旧页，
              // 表现为“点了记忆 Tab，画面仍停在档案页”。只同步状态，不改任何视觉。
              .onChange((index: number) => { this.currentTab = index; })
              .barPosition(BarPosition.End).barOverlap(true).barBackgroundColor(Color.Transparent)
              .barFloatingStyle(HarmonyEffects.dockStyle(this.snapshot.lightEnabled, this.snapshot.reducedMotion))
              .scrollable(false).animationDuration(this.snapshot.reducedMotion ? 0 : 220).id('native-dock')
          }.width('100%').height('100%').backgroundColor('#0B1621')
        }
      }
      .hideTitleBar(!this.ready).hideBackButton(true).titleMode(HdsNavigationTitleMode.MINI)
      .titleBar({
        style: HarmonyEffects.titleBarStyle(this.snapshot.lightEnabled, this.snapshot.reducedMotion),
        content: { title: { mainTitle: '' }, stackBuilder: () => { this.header() } }
      })
      .systemBarStyle({ statusBarContentColor: this.statusBarInk() }, { statusBarContentColor: this.statusBarInk() })
      .bindToScrollable([this.exploreScroller, this.archiveScroller, this.deviceScroller])
      // 新业务页自己按实际容器宽度安排场景/资料；根层再保留首页会把平板切成
      // “首页+游戏+资料”三块，既重复主视觉又挤窄操作。根导航只负责进退。
      .mode(NavigationMode.Stack)
      .navBarWidth('32%').navBarWidthRange({ minWidth: 280, maxWidth: 360 }).minContentWidth(420).navDestination(this.destination)
      .backgroundColor('#0B1621').width('100%').height('100%').id('native-navigation')
      .onAreaChange((_old: Area, area: Area) => { this.wide = Number(area.width) >= 840; })
    }.width('100%').height('100%').backgroundColor('#0B1621')
      // 只扩展根背景的绘制，HDS 导航和页内控件保留系统避让；不引入固定状态栏高度。
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
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
    }.width('100%').height('100%').backgroundColor('#0B1621')
  }

}
