import {
  activeRecords, ArchiveRecord, ArchiveSnapshot, COLLECTION_TAGS, copySnapshot,
  HeritageSite, MAX_NOTE_LENGTH, MAX_NOTE_TAGS, MAX_NOTE_TAG_LENGTH, MAX_NOTE_TAGS_TEXT_LENGTH,
  nextTimestamp, putRecord, recommendSites, Recommendation, MemoryPose, copyMemoryPose,
  AiMemoryAssist, AiFactSnapshot, copyAiMemoryAssist
} from '../domain/ArchiveDomain';
import { HERITAGE_SITES } from '../data/HeritageCatalog';
import { MATERIAL_STUDIES, materialStudyForId } from '../data/MaterialStudyCatalog';
import { MaterialStudyPanel } from './MaterialStudyPanel';
import { MaterialObservationDefinition, MaterialObservationHotspot, materialObservationForSite } from '../domain/MaterialObservation';
import { resolveMemoryReplay } from '../domain/MemoryReplay';
import { MemoryPosePreview } from './MemoryPosePreview';
import { SiteRow, siteIllustration } from './SiteRow';
import { CulturalEngineViewport } from './CulturalEngineViewport';
import { CulturalEnginePayload, CulturalEngineLayer, CulturalSceneType } from '../domain/CulturalEngineContract';
import { getCulturalSiteMetadata, EXPLORATION_SECTIONS, ExplorationSectionId, CulturalLearningSection } from '../domain/CulturalContent';
import { decodeExplorationProgress, encodeExplorationProgressRecord } from '../domain/ExplorationProgress';
import { HarmonyEffects } from '../platform/HarmonyEffects';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';
import { MemoryPostcardItem } from './MemoryPostcardItem';
import { defaultStampForSite, PAPER_THEMES, paperThemeLabel, STAMP_TYPES, memoryQuoteForSite } from '../domain/MemoryJournal';
import type { AiDraftAdoption, AiObservationReply, AiObservationRequest } from '../domain/AiObservation';
import { buildAiMemoryAssist, isAiObservationSite } from '../domain/AiObservation';
import { aiKnowledgeScope } from '../domain/AiObservationKnowledge';
import { AiObservationPanel } from './AiObservationPanel';
import { journeyForId } from '../domain/JourneyRoutes';

interface MemoryPoseRequest extends MemoryPose { request: number; }

@Component
export struct SiteDetail {
  onLogin: () => void = () => {};
  @Prop site: HeritageSite = HERITAGE_SITES[0];
  @Link snapshot: ArchiveSnapshot;
  @Prop initialPoseJson: string = '';
  @Prop aiSignedIn: boolean = false;
  @Prop aiServiceConfigured: boolean = false;
  @Prop startAiPanel: boolean = false;
  @Prop initialNoteId: string = '';
  @Prop startNewNote: boolean = false;
  @Prop initialAiQuestion: string = '';
  @Prop initialAiObservation: string = '';
  onReadMemory: (note: ArchiveRecord) => void = () => {};
  onOpenJourney: () => void = () => {};
  onCommit: (next: ArchiveSnapshot) => Promise<boolean> = async () => false;
  onOpen: (site: HeritageSite) => void = () => {};
  onAiRequest: (request: AiObservationRequest) => Promise<AiObservationReply> = async () => {
    throw new Error('AI_NOT_CONFIGURED');
  };
  onAiCancel: () => void = () => {};
  @State draft: string = '';
  @State originalDraft: string = '';
  @State editingId: string = '';
  @State noteTags: string = '';
  @State originalTags: string = '';
  @State busy: boolean = false;
  @State editorOpen: boolean = false;
  @State validation: string = '';
  @State expandedNoteId: string = '';
  @State private objectActive: boolean = true;
  @State private engineMode: CulturalSceneType = 'relic_inspector';
  @State private hotspot: string = 'form';
  @State private explorationSection: ExplorationSectionId = 'overview';
  @State private stampType: string = '';
  @State private paperTheme: string = 'rose';
  @State private quoteEnabled: boolean = true;
  @State private quotedText: string = '';
  @State private draftPose: MemoryPose | undefined = undefined;
  @State private memoryPoseRequestJson: string = '';
  @State private poseRequestJson: string = '';
  @State private focusRequestJson: string = '';
  @State private replayRevision: number = 0;
  @State private replayMessage: string = '';
  @State private replayBlocked: boolean = false;
  // AI 草稿采纳后先等待视口回传真实相机参数，再打开编辑器；保存时冻结资料事实供另一端解析。
  @State private pendingAiDraft: AiDraftAdoption | undefined = undefined;
  @State private aiDraft: AiDraftAdoption | undefined = undefined;
  @State private editingAiAssist: AiMemoryAssist | undefined = undefined;
  @State private aiNotice: string = '';
  @State private aiReturnVisible: boolean = false;
  @State private aiReturnText: string = '';
  @State private infoOpen: boolean = false;
  // 仅记录本页刚刚成功新建的手账 ID，接续卡不写入归档，也不替代真实路线进度。
  @State private savedJourneyNoteId: string = '';
  private aiPanelOffset: number = 0;
  private originalDecoration: string = '';
  private detailScroller: Scroller = new Scroller();
  private bodyController: TextAreaController = new TextAreaController();
  private tagsController: TextInputController = new TextInputController();
  private pageDisposed: boolean = false;

  aboutToAppear(): void {
    const observation = materialObservationForSite(this.site.id);
    if (observation) this.hotspot = observation.hotspots[0].id;
    if (this.initialPoseJson) {
      try { this.restoreMemoryPose(JSON.parse(this.initialPoseJson) as MemoryPose); }
      catch { this.replayMessage = '保存的观察参数暂不能读取，文字手账仍可查看'; this.replayBlocked = true; }
    }
    // 从首页“陪我观察”进入时，等详情布局完成后再把 AI 面板带入视野；
    // 仍保留上方方鼎和热点按钮，用户可随时上滑回到模型，不另建聊天页。
    if (this.startAiPanel || this.initialNoteId || this.startNewNote) {
      this.pageDisposed = false;
      setTimeout(() => {
        if (this.pageDisposed) return;
        if (this.initialNoteId) {
          const note = this.notes().find(item => item.id === this.initialNoteId);
          if (note) this.editNote(note);
        } else if (this.startNewNote) this.editNote();
        else this.detailScroller.scrollTo({ xOffset: 0, yOffset: Math.max(0, this.aiPanelOffset - 12) });
      }, 420);
    }
  }

  aboutToDisappear(): void {
    this.pageDisposed = true;
  }

  private restoreMemoryPose(pose: MemoryPose): void {
    const resolution = resolveMemoryReplay(this.site.id, pose);
    if (!resolution.canReplay) {
      this.replayMessage = resolution.message; this.replayBlocked = true; return;
    }
    this.engineMode = pose.sceneType as CulturalSceneType;
    this.replayRevision = resolution.sceneRevision;
    this.hotspot = pose.hotspotId;
    const section = EXPLORATION_SECTIONS.find(item => item.id === pose.sectionId);
    if (section) this.explorationSection = section.id;
    this.replayBlocked = false;
    this.replayMessage = resolution.state === 'ready' ? '正在重建保存的观察画面' : resolution.message;
    // 附加请求序号，使同一张卡在手动旋转后仍可再次恢复；序号不存入档案。
    const request = copyMemoryPose(pose) as MemoryPoseRequest;
    request.request = Date.now();
    this.memoryPoseRequestJson = JSON.stringify(request);
    this.focusRequestJson = '';
    this.detailScroller.scrollTo({ xOffset: 0, yOffset: 0 });
  }

  private sceneRevision(): number {
    return this.engineMode === 'stratum_slice' ? 1 :
      (this.replayRevision || materialObservationForSite(this.site.id)?.sceneRevision || 1);
  }

  private observation(): MaterialObservationDefinition | undefined {
    const observation = materialObservationForSite(this.site.id);
    return observation && this.sceneRevision() === observation.sceneRevision ? observation : undefined;
  }

  private selectedObservationLabel(): string {
    return this.observation()?.hotspots.find(item => item.id === this.hotspot)?.label || '';
  }

  private selectedObservationReading(): string {
    const id = this.observation()?.hotspots.find(item => item.id === this.hotspot)?.factId || '';
    return materialStudyForId(this.site.id)?.facts.find(fact => fact.id === id)?.body || '';
  }

  private selectHotspot(id: string): void {
    this.memoryPoseRequestJson = ''; this.poseRequestJson = '';
    this.replayMessage = ''; this.replayBlocked = false;
    this.focusRequestJson = '';
    this.aiReturnVisible = false;
    this.hotspot = id;
  }

  private startObservation(mode: CulturalSceneType = 'relic_inspector'): void {
    this.replayRevision = 0; this.replayMessage = ''; this.replayBlocked = false;
    this.memoryPoseRequestJson = ''; this.poseRequestJson = '';
    this.focusRequestJson = '';
    this.engineMode = mode;
    this.hotspot = materialObservationForSite(this.site.id)?.hotspots[0].id || 'form';
  }

  private focusFromAi(hotspotId: string): void {
    const observation = this.observation();
    if (!observation || !observation.hotspots.some((item: MaterialObservationHotspot) => item.id === hotspotId)) return;
    // 先落选中状态再发独立请求序号；同一热点连续请求也能再次聚焦，不复用回放成功文案。
    this.selectHotspot(hotspotId);
    this.focusRequestJson = JSON.stringify({ hotspotId, request: Date.now() });
    this.aiReturnText = `AI 已定位 · ${this.selectedObservationLabel()}`;
    this.aiReturnVisible = true;
    // 回答面板在页面下方；点观察动作后必须把真实模型带回可见区域，否则旋转发生在屏幕外。
    this.detailScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: { duration: 350 } });
  }

  private adoptAiDraft(draft: AiDraftAdoption): void {
    // 不直接用模型建议的默认镜头保存；先请视口回传用户此刻真实相机参数与原画幅。
    this.pendingAiDraft = draft;
    this.aiNotice = '正在读取当前观察视角…';
    this.poseRequestJson = JSON.stringify({ request: Date.now() });
  }

  private decoration(): string {
    return JSON.stringify([this.stampType, this.paperTheme, this.quoteEnabled, this.quotedText, this.draftPose]);
  }

  private favorite(): ArchiveRecord | undefined {
    return activeRecords(this.snapshot.records, 'favorite').find((record: ArchiveRecord) => record.siteId === this.site.id);
  }

  private notes(): ArchiveRecord[] {
    return activeRecords(this.snapshot.records, 'note').filter((record: ArchiveRecord) => record.siteId === this.site.id);
  }

  private isGenericStudy(): boolean {
    return getCulturalSiteMetadata(this.site.id)?.proceduralPreset === 'generic_site_study';
  }

  private enginePayload(): string {
    const payload: CulturalEnginePayload = { version: 1, itemId: this.site.id, title: this.site.name,
      proceduralPreset: getCulturalSiteMetadata(this.site.id)?.proceduralPreset || 'generic_site_study',
      sceneRevision: this.sceneRevision(),
      selectedId: this.engineMode === 'stratum_slice' ? this.explorationSection : this.hotspot,
      exploredIds: decodeExplorationProgress(this.snapshot.records, this.site.id).completedSectionIds,
      layers: EXPLORATION_SECTIONS.map((section: CulturalLearningSection): CulturalEngineLayer => ({ id: section.id, label: section.title })) };
    return JSON.stringify(payload);
  }

  private hasPoetry(): boolean {
    const poetry = this.site.poetry.trim();
    // “暂未收录”本身不是诗文，不再单独占一张空白卡片；资料状态仍由详情页的校审标识说明。
    return poetry.length > 0 && !poetry.startsWith('暂未收录') && !poetry.startsWith('相关诗文将在');
  }

  private selectedReading(): string {
    return this.explorationSection === 'overview' ? this.site.overview :
      this.explorationSection === 'archaeology' ? this.site.archaeology :
        this.explorationSection === 'history' ? this.site.history :
          [this.hasPoetry() ? this.site.poetry : '', this.site.travel]
            .filter((text: string) => text.length > 0).join('\n');
  }

  private async completeSection(): Promise<void> {
    if (this.busy || decodeExplorationProgress(this.snapshot.records, this.site.id).completedSectionIds.includes(this.explorationSection)) return;
    this.busy = true;
    try {
      const next = copySnapshot(this.snapshot);
      next.records = putRecord(next.records, encodeExplorationProgressRecord(this.site.id, this.explorationSection,
        nextTimestamp(next.records, Date.now()), next.deviceId));
      // 先落盘才发布完成状态；每个主题独立版本信封，离线探索不同主题不会覆盖彼此。
      await this.onCommit(next);
    } finally { this.busy = false; }
  }

  @Builder
  photoCard() {
    if (this.site.photos.length > 0) {
      Column({ space: 7 }) {
        Image($rawfile(this.site.photos[0])).width('100%').height(210)
          .objectFit(ImageFit.Cover).borderRadius(16)
          .accessibilityText(this.site.photoCaption || `${this.site.name}实景照片`)
        Column({ space: 3 }) {
          Text(this.site.photoCaption || `${this.site.name}实景`)
            .fontSize(F.caption).fontColor(T.ink).width('100%').maxLines(2)
          Text(this.site.photoCredit || '图片来源见资料说明')
            .fontSize(F.caption).fontColor(T.tertiary).width('100%').maxLines(2)
        }.width('100%').alignItems(HorizontalAlign.Start)
      }.width('100%').padding(12).backgroundColor(T.soft).borderRadius(T.cardRadius)
        .margin({ bottom: 16 }).id('site-photo-card')
    }
  }

  @Builder
  infoSheet() {
    Column({ space: 12 }) {
      Text('资料说明').fontSize(F.card).fontWeight(FontWeight.Bold).fontColor(T.ink).width('100%')
      Text(this.observation()?.notice || '插画与几何为原创学习示意。')
        .fontSize(F.caption).fontColor(T.ink).lineHeight(21).width('100%')
      Text(materialStudyForId(this.site.id)?.visualCaption || '封面插画为主题示意。')
        .fontSize(F.caption).fontColor(T.muted).lineHeight(20).width('100%')
      Text(materialStudyForId(this.site.id)?.evidenceLimit || '图像比例与细节经过简化。')
        .fontSize(F.caption).fontColor(T.muted).lineHeight(20).width('100%')
      Text(`文化内容：${this.site.reviewStatus}；事实与来源以详情中的官方页面为准，插画与程序化几何不是文物照片、测绘或考古复原。`)
        .fontSize(F.caption).fontColor(T.muted).lineHeight(20).width('100%')
      Text('AI 参考解读只依据本对象已核事实；资料不足时会明确说明，不替代馆方原文或人工校审。')
        .fontSize(F.caption).fontColor(T.muted).lineHeight(20).width('100%')
    }.width('100%').padding(14).backgroundColor(T.soft).borderRadius(12)
      .id('detail-info-sheet')
  }

  @Builder
  culturalExperience() {
    Column({ space: 12 }) {
      Text(this.isGenericStudy() ? '文化资料' : '文化凝视').fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink).width('100%')
      if (this.observation()) {
        Text(materialStudyForId(this.site.id)?.question || '').fontSize(F.body).fontColor(T.ink)
          .fontWeight(FontWeight.Medium).lineHeight(27).width('100%')
      }
      Row({ space: 8 }) {
        Button(this.isGenericStudy() ? '资料观察' :
          (this.site.id === 'smx-miaodigou' && this.observation() ? '空间观察' : '器物凝视'))
          .id('engine-mode-relic').onClick(() => this.startObservation('relic_inspector'))
          .layoutWeight(1).fontSize(F.small).fontColor(T.accent).backgroundColor(this.engineMode === 'relic_inspector' ? T.accentSoft : T.soft)
        Button('文化切片').id('engine-mode-stratum').onClick(() => this.startObservation('stratum_slice'))
          .layoutWeight(1).fontSize(F.small).fontColor(T.accent).backgroundColor(this.engineMode === 'stratum_slice' ? T.accentSoft : T.soft)
      }.width('100%')
      if (this.replayMessage) {
        Text(this.replayMessage).fontSize(F.small).fontColor(T.mintInk).lineHeight(23).width('100%')
          .padding(12).backgroundColor(T.mint).borderRadius(12).id('memory-replay-message')
      }
      if (this.replayBlocked) {
        Button('开始新的观察').id('memory-start-new-observation').width('100%').height(44)
          .fontColor(T.accent).backgroundColor(T.accentSoft).onClick(() => this.startObservation())
      } else {
        CulturalEngineViewport({ sceneType: this.engineMode, payloadJson: this.enginePayload(), viewportHeight: 300,
        rememberEnabled: true, memoryPoseJson: this.memoryPoseRequestJson,
        focusRequestJson: this.focusRequestJson, poseRequestJson: this.poseRequestJson,
        onRememberView: (pose: MemoryPose) => {
          const pending = this.pendingAiDraft;
          if (pending) {
            // 只有视口回传真实相机参数后才打开 AI 草稿编辑器，不能保存默认镜头冒充用户取景。
            this.pendingAiDraft = undefined;
            this.aiNotice = '';
            this.editNote(undefined, pose, pending);
          } else this.editNote(undefined, pose);
        },
        onRememberFailure: (message: string) => {
          if (this.pendingAiDraft) {
            this.pendingAiDraft = undefined;
            this.poseRequestJson = '';
            this.aiNotice = message;
            this.getUIContext().getPromptAction().showToast({ message });
          }
        },
        onReplayResult: (success: boolean, message: string) => {
          this.replayMessage = message;
          if (!success) this.replayBlocked = true;
        },
        reducedMotion: this.snapshot.reducedMotion, active: this.objectActive && !this.editorOpen,
        onNodeSelected: (id: string, type: string) => {
          if (type === 'hotspot') this.selectHotspot(id);
          const section = EXPLORATION_SECTIONS.find(section => section.id === id);
          if (type === 'layer' && section) this.explorationSection = section.id;
        } })
      }
      if (this.aiReturnVisible) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.map')).fontSize(15).fontColor([T.mintInk])
          Text(this.aiReturnText).fontSize(F.caption).fontColor(T.mintInk).layoutWeight(1).maxLines(1).id('ai-focus-visible')
          Button('继续追问', { type: ButtonType.Normal }).id('ai-continue').constraintSize({ minHeight: 34 })
            .fontSize(F.caption)
            .padding({ left: 10, right: 10 }).fontColor(T.mintInk).backgroundColor(T.surface).borderRadius(8)
            .onClick(() => {
              this.aiReturnVisible = false;
              // 回到当前布局中面板的位置，保留问答；资料展开后也不依赖固定偏移。
              this.detailScroller.scrollTo({ xOffset: 0, yOffset: Math.max(0, this.aiPanelOffset - 12), animation: { duration: 400 } });
              // 再聚焦原输入框，键盘和回答一起回来；不清空已输入的追问草稿。
              setTimeout(() => {
                if (this.pageDisposed) return;
                // 快速返回或面板尚在滚动时，输入框可能暂时不可聚焦；聚焦只是便捷操作，
                // 不能让一次失败的焦点请求变成应用进程崩溃，用户仍可手动点击输入框。
                try { this.getUIContext().getFocusController().requestFocus('ai-question-input'); }
                catch { /* 页面已离开或控件暂不可聚焦时保留当前滚动位置。 */ }
              }, 420);
            })
        }.width('100%').padding({ left: 10, right: 8, top: 6, bottom: 6 })
          .backgroundColor(T.mint).borderRadius(10).margin({ top: 8 })
      }
      if (this.engineMode === 'relic_inspector') {
        if (this.observation()) {
          Row({ space: 8 }) {
            ForEach(this.observation()?.hotspots || [], (detail: MaterialObservationHotspot) => {
              Button(detail.label).id(`observation-hotspot-${detail.id}`).layoutWeight(1).height(42)
                .fontSize(F.small).fontColor(T.accent).borderRadius(12).padding({ left: 4, right: 4 })
                .backgroundColor(this.hotspot === detail.id ? T.accentSoft : T.soft)
                .onClick(() => this.selectHotspot(detail.id))
            }, (detail: MaterialObservationHotspot) => detail.id)
          }.width('100%')
          Text(`正在观察 · ${this.selectedObservationLabel()}`).fontSize(F.body).fontColor(T.ink)
            .fontWeight(FontWeight.Medium).width('100%').id('observation-selected-detail')
          Text(this.observation()?.hotspots.find(item => item.id === this.hotspot)?.visibleDetail || '')
            .fontSize(F.small).fontColor(T.ink).lineHeight(24).width('100%').id('observation-visible-detail')
        } else {
        // 三个热点等分一行，显式收紧内边距，让 1.5 倍字号仍完整显示三字标签。
        // 保留系统字体缩放；后续增加文案长度时应改换行布局，不能靠限制字号掩盖截断。
        Row({ space: 8 }) {
          Button(this.isGenericStudy() ? '看概览' : '观形制').id('hotspot-form').onClick(() => this.selectHotspot('form'))
            .layoutWeight(1).height(40).borderRadius(12).fontSize(F.small).fontColor(T.accent)
            .padding({ left: 4, right: 4 })
            .backgroundColor(this.hotspot === 'form' ? T.accentSoft : T.soft)
          Button(this.isGenericStudy() ? '读遗存' : '察纹样').id('hotspot-pattern').onClick(() => this.selectHotspot('pattern'))
            .layoutWeight(1).height(40).borderRadius(12).fontSize(F.small).fontColor(T.accent)
            .padding({ left: 4, right: 4 })
            .backgroundColor(this.hotspot === 'pattern' ? T.accentSoft : T.soft)
          Button(this.isGenericStudy() ? '寻线索' : '读线索').id('hotspot-story').onClick(() => this.selectHotspot('story'))
            .layoutWeight(1).height(40).borderRadius(12).fontSize(F.small).fontColor(T.accent)
            .padding({ left: 4, right: 4 })
            .backgroundColor(this.hotspot === 'story' ? T.accentSoft : T.soft)
        }.width('100%')
        }
        // AI 入口放在热点按钮之后、长正文之前：折叠态只占一条问题卡，首屏即可发现；
        // 入口仍跟随白名单，没有 revision 2 场景或不在清单内的档案只保留手动观察。
        if (this.observation() && isAiObservationSite(this.site.id)) {
          Column() {
          AiObservationPanel({
            onLogin: this.onLogin,
            siteId: this.site.id, sceneRevision: this.sceneRevision(), hotspotId: this.hotspot,
            signedIn: this.aiSignedIn, serviceConfigured: this.aiServiceConfigured,
            startExpanded: this.startAiPanel, reducedMotion: this.snapshot.reducedMotion,
            initialQuestion: this.initialAiQuestion, initialObservation: this.initialAiObservation,
            onFocusHotspot: (id: string) => this.focusFromAi(id),
            onAdoptDraft: (draft: AiDraftAdoption) => this.adoptAiDraft(draft),
            onAiRequest: this.onAiRequest, onAiCancel: this.onAiCancel
          })
          }.width('100%').onAreaChange((_old: Area, area: Area) => {
            // 位置来自实际布局坐标，不硬编码滚动距离；面板上移后继续用于“继续追问”。
            this.aiPanelOffset = Number(area.position.y);
          })
          if (this.aiNotice) {
            Text(this.aiNotice).fontSize(F.caption).fontColor(T.mintInk).lineHeight(19).width('100%')
              .padding(10).backgroundColor(T.mint).borderRadius(10).id('ai-view-notice')
          }
        }
        Text(this.observation() ? this.selectedObservationReading() :
          (this.hotspot === 'form' ? this.site.overview : this.hotspot === 'pattern' ? this.site.archaeology : this.site.history))
          .fontSize(F.small).fontColor(T.muted).lineHeight(24).width('100%').id('engine-hotspot-reading')
          .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.isGenericStudy() ? '通用资料学习示意，不表示本遗址平面、窑炉结构或出土器物。' :
          (this.observation()?.notice || '按档案主题生成的几何与装饰示意，非文物或遗址复原。'))
          .fontSize(F.caption).fontColor(T.muted).lineHeight(20).width('100%').id('site-object-notice')
          .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
        Row() {
          Blank()
          Button(this.infoOpen ? '收起说明' : '资料说明', { type: ButtonType.Normal }).id('detail-info').height(30).fontSize(F.caption)
            .padding({ left: 10, right: 10 }).fontColor(T.accent).backgroundColor(T.accentSoft).borderRadius(8)
            .onClick(() => { this.infoOpen = !this.infoOpen; })
        }.width('100%')
        if (this.infoOpen) { this.infoSheet() }
      } else {
        Text('四层表示阅读主题，未核实为该遗址的真实考古层序。')
          .fontSize(F.caption).fontColor(T.accent).lineHeight(20).width('100%')
        ForEach(EXPLORATION_SECTIONS, (section: CulturalLearningSection) => {
          Button(`${decodeExplorationProgress(this.snapshot.records, this.site.id).completedSectionIds.includes(section.id) ? '✓ ' : ''}${section.title}`)
            .id(`exploration-${section.id}`).fontSize(F.small).width('100%').borderRadius(12)
            .fontColor(T.ink).backgroundColor(this.explorationSection === section.id ? T.accentSoft : T.soft)
            .onClick(() => { this.explorationSection = section.id; })
        }, (section: CulturalLearningSection) => section.id)
        Text(this.selectedReading()).fontSize(F.body).fontColor(T.ink).lineHeight(26).width('100%').id('exploration-reading')
        Text(`探索进度 ${decodeExplorationProgress(this.snapshot.records, this.site.id).percent}%`)
          .fontSize(F.small).fontColor(T.accent).width('100%').id('exploration-progress')
        Progress({ value: decodeExplorationProgress(this.snapshot.records, this.site.id).percent, total: 100, type: ProgressType.Linear })
          .width('100%').color(T.accent)
        Button(this.busy ? '正在保存' : '标记此主题已探索').id('exploration-complete').fontSize(F.small)
          .width('100%').enabled(!this.busy && !decodeExplorationProgress(this.snapshot.records, this.site.id).completedSectionIds.includes(this.explorationSection))
          .backgroundColor(T.accent).fontColor(T.onAccent).onClick(() => this.completeSection())
      }
    }.width('100%').padding(16).backgroundColor(T.surface).borderRadius(20).margin({ top: 12, bottom: 12 })
  }

  private async saveFavorite(tag: string = ''): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    const next = copySnapshot(this.snapshot);
    const previous = this.favorite();
    // 分类标签与自定义标签分开处理：切换“待实地探访 / 已去过 / 研究资料”时
    // 只替换分类位，保留用户自己写的标签，避免一次改分类把研究关键词整组清空。
    const previousTags: string[] = previous ? previous.tags : [];
    const customTags: string[] = previousTags.filter((item: string) => !COLLECTION_TAGS.includes(item));
    const nextTags: string[] = tag ? customTags.concat([tag]) : customTags;
    const record: ArchiveRecord = {
      id: `favorite:${this.site.id}`, kind: 'favorite', siteId: this.site.id, body: '',
      tags: nextTags.length > 0 ? nextTags : ['待实地探访'],
      updatedAt: nextTimestamp(next.records, Date.now()),
      deviceId: next.deviceId, deleted: !tag && previous !== undefined
    };
    next.records = putRecord(next.records, record);
    await this.onCommit(next);
    this.busy = false;
  }

  private editNote(note?: ArchiveRecord, pose?: MemoryPose, aiDraft?: AiDraftAdoption): void {
    this.editingId = note ? note.id : '';
    this.draft = note ? note.body : '';
    this.noteTags = note ? note.tags.join('，') : '';
    this.originalDraft = this.draft;
    this.originalTags = this.noteTags;
    this.stampType = note?.stampType || defaultStampForSite(this.site);
    this.paperTheme = note?.paperTheme || 'rose';
    this.quoteEnabled = note ? !!note.quotedPoemOrFact : true;
    this.quotedText = note?.quotedPoemOrFact || memoryQuoteForSite(this.site);
    if (!note && pose && this.selectedObservationReading()) this.quotedText = this.selectedObservationReading();
    this.draftPose = pose || note?.snapshot3DPose;
    this.aiDraft = aiDraft;
    this.editingAiAssist = note?.aiAssist;
    this.pendingAiDraft = undefined;
    this.aiNotice = aiDraft ? 'AI 草稿只整理你的观察；事实摘录取自原始资料。' : '';
    if (aiDraft) {
      // 草稿正文和标签进入可编辑字段，保存前由用户确认或修改；引用事实另存，不混进正文。
      this.draft = aiDraft.body;
      this.noteTags = aiDraft.tags.join('，');
      this.quoteEnabled = true;
      this.quotedText = aiDraft.facts.length > 0 ? aiDraft.facts[0].body : memoryQuoteForSite(this.site);
    }
    this.originalDecoration = this.decoration();
    this.validation = '';
    this.editorOpen = true;
  }

  private clearAiDraftState(): void {
    this.pendingAiDraft = undefined;
    this.aiDraft = undefined;
    this.editingAiAssist = undefined;
    this.aiNotice = '';
  }

  private async saveNote(): Promise<void> {
    if (this.busy) return;
    this.finishEditing();
    const body = this.draft.trim();
    const tags = this.noteTags.split(/[,，]/).map((tag: string) => tag.trim()).filter((tag: string) => tag.length > 0);
    if (!body) { this.validation = '笔记内容不能为空'; return; }
    if (body.length > MAX_NOTE_LENGTH || tags.length > MAX_NOTE_TAGS || tags.some((tag: string) => tag.length > MAX_NOTE_TAG_LENGTH)) {
      this.validation = '笔记最多 4000 字；最多 20 个标签，每个标签不超过 40 字';
      return;
    }
    // AI 参考元数据只在用户采纳或修改草稿后确认保存时写入；编辑旧 AI 手账则原样继承。
    let aiAssist: AiMemoryAssist | undefined = undefined;
    if (this.aiDraft) {
      const scope = aiKnowledgeScope(this.site.id);
      if (!scope) { this.validation = '当前资料范围不可用，暂不能保存 AI 参考信息'; return; }
      try { aiAssist = buildAiMemoryAssist(this.aiDraft, scope); }
      catch { this.validation = 'AI 草稿引用的资料版本不可用，请重新生成草稿后再保存'; return; }
    } else if (this.editingAiAssist) {
      aiAssist = copyAiMemoryAssist(this.editingAiAssist);
    }
    this.busy = true;
    const next = copySnapshot(this.snapshot);
    const time = nextTimestamp(next.records, Date.now());
    const existing = this.editingId ? next.records.find(item => item.id === this.editingId && !item.deleted) : undefined;
    const record: ArchiveRecord = {
      id: this.editingId || `note:${next.deviceId}:${time}`, kind: 'note', siteId: this.site.id,
      body, tags, updatedAt: time, deviceId: next.deviceId, deleted: false
    };
    record.stampType = this.stampType;
    record.paperTheme = this.paperTheme;
    if (this.quoteEnabled && this.quotedText) record.quotedPoemOrFact = this.quotedText;
    if (this.draftPose) record.snapshot3DPose = this.draftPose;
    if (aiAssist) record.aiAssist = aiAssist;
    if (existing) {
      // 这个表单只管理正文、标签与上方装饰字段；纸景/漫游的冻结上下文（剪口、
      // 出处、篇章选择）不在编辑器里。用原 ID 重建记录时必须原样带回，
      // 否则从档案页补写一段文字就会抹掉整份冻结作品。
      record.paperContext = existing.paperContext;
      record.roamingContext = existing.roamingContext;
      // 原档案的旧编辑入口也可补写三夜记忆；冻结布局和出处不属于此表单的编辑范围。
      record.marketContext = existing.marketContext;
    }
    next.records = putRecord(next.records, record);
    if (await this.onCommit(next)) {
      this.editorOpen = false;
      if (!this.editingId && journeyForId('earth-and-fire')?.siteIds.includes(this.site.id)) {
        this.savedJourneyNoteId = record.id;
        // 表单可能从详情下方打开。确认落盘后回到真实页首的轻量接续入口，
        // 不自动打开新页面；重温镜头仍使用保存时已取得的 pose，不受接续卡布局影响。
        setTimeout(() => {
          if (!this.pageDisposed && !this.editorOpen) this.detailScroller.scrollTo({ xOffset: 0, yOffset: 0,
            animation: this.snapshot.reducedMotion ? undefined : { duration: 240 } });
        }, 240);
      }
      this.draft = '';
      this.originalDraft = '';
      this.noteTags = '';
      this.originalTags = '';
      this.clearAiDraftState();
    }
    this.busy = false;
  }

  private discardEditor(): void {
    if (this.busy) return;
    this.finishEditing();
    if (this.draft !== this.originalDraft || this.noteTags !== this.originalTags || this.decoration() !== this.originalDecoration) {
      this.getUIContext().showAlertDialog({
        title: '放弃尚未保存的修改？',
        message: '已保存的笔记不会被删除；本次 AI 草稿也不会写入记录。',
        primaryButton: { value: '继续编辑', action: () => {} },
        secondaryButton: { value: '放弃修改', action: () => { this.clearAiDraftState(); this.editorOpen = false; } }
      });
    } else {
      this.clearAiDraftState();
      this.editorOpen = false;
    }
  }

  private finishEditing(): void {
    // 保存/退出时结束输入，避免确认弹窗后键盘仍占用可视区；正文和标签仍保存在草稿状态。
    this.bodyController.stopEditing();
    this.tagsController.stopEditing();
  }

  private confirmDelete(note: ArchiveRecord): void {
    this.getUIContext().showAlertDialog({
      title: '删除这条笔记？', message: '删除后不再显示，删除标记将为后续跨端同步保留。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '删除', action: () => { this.deleteNote(note); } }
    });
  }

  private async deleteNote(note: ArchiveRecord): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    const next = copySnapshot(this.snapshot);
    // 使用深拷贝后的同一记录落墓碑，手账装饰与视角随删除版本保留。
    const record = next.records.find(item => item.id === note.id);
    if (!record) { this.busy = false; return; }
    record.updatedAt = nextTimestamp(next.records, Date.now()); record.deviceId = next.deviceId; record.deleted = true;
    next.records = putRecord(next.records, record);
    await this.onCommit(next);
    this.busy = false;
  }

  @Builder
  section(title: string, content: string) {
    Column({ space: 12 }) {
      Row({ space: 9 }) {
        Row().width(3).height(18).borderRadius(2).backgroundColor(T.accent)
        Text(title).fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink)
      }
      Text(content).fontSize(15).lineHeight(24).fontColor(T.ink)
        .copyOption(CopyOptions.LocalDevice)
    }.alignItems(HorizontalAlign.Start).width('100%').padding(20)
      .backgroundColor(T.surface).borderRadius(T.cardRadius).margin({ bottom: 12 })
  }

  @Builder
  noteEditor() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 6 }) {
          Text(this.site.name).fontSize(F.caption).fontColor(T.accent).id('note-associated-site')
          Text(this.aiDraft ? '整理 AI 草稿' : this.editingId ? '编辑拾遗手账' : '留一页，记住此刻')
            .fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.xmark')).fontSize(18).fontColor([T.muted])
        }.width(44).height(44).backgroundColor(T.soft)
          .accessibilityText('关闭笔记编辑').id('close-note-editor').enabled(!this.busy).onClick(() => this.discardEditor())
      }.width('100%')
      // 键盘出现后只压缩可滚动的输入区，关闭、校验和保存仍保持可见。
      // 不再用 FIT_CONTENT 配合固定 Column，否则键盘会盖住标签和保存按钮。
      Scroll() {
        Column({ space: 14 }) {
          if (this.aiDraft) {
            Column({ space: 4 }) {
              Text('AI 辅助草稿 · 请确认或修改后保存').fontSize(F.small).fontWeight(FontWeight.Medium)
                .fontColor(T.accent).width('100%').id('note-ai-draft-badge')
              // 展示本次冻结事实的中文标题；稳定事实 ID 继续留在元数据中，不能直接变成用户文案。
              Text(`参考依据：${this.aiDraft.facts.map((fact: AiFactSnapshot) => fact.title).join(' · ')} · 资料 v${this.aiDraft.contentRevision}`)
                .fontSize(F.caption).fontColor(T.muted).lineHeight(19).width('100%').id('note-ai-draft-reference')
              Text(this.aiNotice).fontSize(F.caption).fontColor(T.muted).lineHeight(19).width('100%')
            }.width('100%').alignItems(HorizontalAlign.Start).padding(11).backgroundColor(T.accentSoft).borderRadius(10)
          } else if (this.editingAiAssist) {
            Text(`这页曾参考 AI 辅助整理 · 依据 ${this.editingAiAssist.facts.map((fact: AiFactSnapshot) => fact.title).join(' · ')} · 资料 v${this.editingAiAssist.contentRevision}`)
              .fontSize(F.caption).fontColor(T.mintInk).lineHeight(19).width('100%').padding(10)
              .backgroundColor(T.mint).borderRadius(10).id('note-ai-assist-badge')
          }
          if (this.draftPose) {
            MemoryPosePreview({ siteId: this.site.id, poseJson: JSON.stringify(this.draftPose),
              previewHeight: 180, previewId: 'memory-draft-preview' })
            Text(`留住的细节 · ${this.draftPose?.label || '当前视角'}`).fontSize(F.small).fontColor(T.mintInk)
              .width('100%').id('memory-draft-pose')
          }
          Row({ space: 10 }) {
            Text('落款印章').fontSize(F.small).fontColor(T.muted)
            Select(STAMP_TYPES.map((value: string): SelectOption => ({ value }))).value(this.stampType)
              .id('memory-stamp-index').layoutWeight(1).font({ size: F.small }).fontColor(T.accent).backgroundColor(T.accentSoft)
              .onSelect((_index: number, value: string) => { this.stampType = value; })
          }.width('100%')
          Row({ space: 6 }) {
            ForEach(PAPER_THEMES, (theme: string) => {
              Button(paperThemeLabel(theme)).id(`memory-paper-${theme}`).layoutWeight(1).height(38).fontSize(F.caption)
                .padding({ left: 4, right: 4 }).borderRadius(10).fontColor(this.paperTheme === theme ? T.onAccent : T.muted)
                .backgroundColor(this.paperTheme === theme ? T.accent : T.soft).onClick(() => { this.paperTheme = theme; })
            }, (theme: string) => theme)
          }.width('100%')
          Row({ space: 10 }) {
            Text('带上一句档案摘录').fontSize(F.small).fontColor(T.ink).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.quoteEnabled }).selectedColor(T.accent).id('memory-quote-toggle')
              .onChange((value: boolean) => { this.quoteEnabled = value; })
          }.width('100%')
          if (this.quoteEnabled) {
            Text(this.quotedText).fontSize(F.caption).fontColor(T.muted).lineHeight(20).width('100%')
              .padding(12).backgroundColor(T.accentSoft).borderRadius(10)
          }
          Text('我的观察与思考').fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.ink).width('100%')
          TextArea({ text: this.draft, controller: this.bodyController, placeholder: '记下器物、空间，或一个还想追问的问题…' })
            .height(200).maxLength(MAX_NOTE_LENGTH).fontSize(F.body).fontColor(T.ink).placeholderColor(T.muted)
            .backgroundColor(T.soft).borderRadius(12).padding(14).id('note-body').enabled(!this.busy)
            .onChange((text: string) => { this.draft = text; this.validation = ''; })
          Row() {
            Text('笔记标签').fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.ink).layoutWeight(1)
            Text(`${this.draft.length} / ${MAX_NOTE_LENGTH}`).fontSize(F.caption).fontColor(T.muted)
          }.width('100%')
          TextInput({ text: this.noteTags, controller: this.tagsController, placeholder: '例如：彩陶，研学（以逗号分隔）' })
            // 保存期间锁住输入，防止 flush 等待时的新草稿被成功回调清空。
            .height(48).fontSize(F.small).fontColor(T.ink).placeholderColor(T.muted)
            .backgroundColor(T.soft).borderRadius(10).maxLength(MAX_NOTE_TAGS_TEXT_LENGTH).id('note-tags').enabled(!this.busy)
            .onChange((text: string) => { this.noteTags = text; this.validation = ''; })
          Text('最多 20 个标签，每个不超过 40 字。').fontSize(F.caption).fontColor(T.muted).width('100%')
        }.width('100%')
      }.layoutWeight(1).width('100%').align(Alignment.Top).id('note-editor-scroll')
      if (this.validation) {
        Text(this.validation).fontSize(13).fontColor($r('app.color.danger'))
      }
      Button(this.busy ? '正在保存' : '盖章，存入我的手账', { type: ButtonType.Normal })
        .width('100%').height(48).fontSize(F.body).borderRadius(8).backgroundColor(T.accent)
        .fontColor(T.onAccent).enabled(!this.busy).id('save-note').onClick(() => this.saveNote())
    }.padding(20).width('100%').height('100%').backgroundColor(T.surface)
  }

  build() {
    NavDestination() {
      Scroll(this.detailScroller) {
        Column() {
          if (this.savedJourneyNoteId && this.notes().some((note: ArchiveRecord) => note.id === this.savedJourneyNoteId)) {
            Button({ type: ButtonType.Normal }) {
              Row({ space: 10 }) {
                SymbolGlyph($r('sys.symbol.bookmark')).fontSize(20).fontColor([T.yellowInk])
                Column({ space: 3 }) {
                  Text('这一页，已写入长卷').fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.ink)
                  Text('展开我的泥火长卷').fontSize(F.caption).fontColor(T.yellowInk)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Text('›').fontSize(24).fontColor(T.yellowInk)
              }.width('100%')
            }.width('100%').constraintSize({ minHeight: 60 }).padding(14).backgroundColor(T.yellow).borderRadius(16)
              .margin({ top: 8, bottom: 14 }).id('detail-journey-scroll').accessibilityText('展开我的泥火长卷')
              .onClick(this.onOpenJourney)
          }
          if (materialStudyForId(this.site.id) && !materialObservationForSite(this.site.id)) {
            MaterialStudyPanel({ study: materialStudyForId(this.site.id) || MATERIAL_STUDIES[0] })
          }
          this.culturalExperience()
          if (materialStudyForId(this.site.id) && materialObservationForSite(this.site.id)) {
            MaterialStudyPanel({ study: materialStudyForId(this.site.id) || MATERIAL_STUDIES[0] })
          }
          if (!materialStudyForId(this.site.id)) {
            Stack({ alignContent: Alignment.TopStart }) {
              Image(siteIllustration(this.site)).width('100%').height(210).objectFit(ImageFit.Cover)
                .borderRadius(18).accessibilityText('原创文化主题插画')
              Row() {
                Text(this.site.type).fontSize(F.caption).fontColor(T.mintInk)
                  .padding({ left: 9, right: 9, top: 5, bottom: 5 }).backgroundColor(T.surface).borderRadius(6)
              }.width('100%').padding(14).align(Alignment.TopStart)
            }.width('100%').margin({ top: 12, bottom: 18 })
          }
          Column({ space: 10 }) {
            Text(`${this.site.city} · ${this.site.era}`).fontSize(F.small).fontColor(T.accent)
            Text(this.site.name).fontSize(F.display).fontWeight(FontWeight.Bold).fontColor(T.ink)
            Text(this.site.summary).fontSize(F.small).fontColor(T.muted).lineHeight(24)
          }.width('100%').alignItems(HorizontalAlign.Start).margin({ bottom: 20 })
          Row({ space: 12 }) {
            Button({ type: ButtonType.Normal }) {
              Row({ space: 8 }) {
                SymbolGlyph($r('sys.symbol.bookmark')).fontSize(18)
                  .fontColor([this.favorite() ? $r('app.color.on_accent') : $r('app.color.accent')])
                Text(this.favorite() ? '已收藏' : '收藏档案').fontSize(14)
                  .fontColor(this.favorite() ? $r('app.color.on_accent') : $r('app.color.accent'))
              }
            }.height(48).layoutWeight(1).padding({ left: 12, right: 12 }).borderRadius(8)
              .backgroundColor(this.favorite() ? $r('app.color.accent') : $r('app.color.accent_soft'))
              .enabled(!this.busy).id('favorite-toggle').onClick(() => this.saveFavorite())
            Button({ type: ButtonType.Normal }) {
              Row({ space: 8 }) {
                SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(18).fontColor([T.accent])
                Text('写手账').fontSize(F.small).fontColor(T.accent)
              }.justifyContent(FlexAlign.Center)
            }.height(48).layoutWeight(1).borderRadius(8).backgroundColor(T.surface)
              .enabled(!this.busy).id('write-note').onClick(() => this.editNote())
          }.width('100%').margin({ bottom: 16 })
          if (this.favorite()) {
            Select(COLLECTION_TAGS.map((tag: string): SelectOption => ({ value: tag })))
              .value(this.favorite()?.tags[0] || COLLECTION_TAGS[0])
              .onSelect((_index: number, value: string) => this.saveFavorite(value))
              .font({ size: F.small }).fontColor(T.ink).backgroundColor(T.surface).borderRadius(10).height(44)
              .margin({ bottom: 16 }).enabled(!this.busy).id('favorite-category')
          }
          this.photoCard()
          this.section('档案概览', this.site.overview)
          this.section('考古与遗存', this.site.archaeology)
          this.section('历史线索', this.site.history)
          // 详情页要有“相关诗词”这一层：没有核实诗文时保留层级并说明缺口，
          // 而不是整段隐藏。隐藏会被读成功能缺失；空态是诚实的资料状态，也方便后续补录。
          this.section('诗文索引', this.hasPoetry() ? this.site.poetry :
            '本档案暂未收录相关诗文；已收录考古与探访信息，不作补白。')
          this.section('探访信息', this.site.travel)
          Column({ space: 10 }) {
            Text(this.site.reviewStatus).fontSize(F.caption).fontColor(T.accent)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 }).backgroundColor(T.accentSoft).borderRadius(6)
            Text(this.site.source.title).fontSize(F.caption).fontColor(T.muted)
            Text(this.site.source.url).fontSize(F.caption).fontColor(T.muted)
              .copyOption(CopyOptions.LocalDevice)
            if (this.site.source.title.endsWith('机构入口')) {
              Text('当前链接为机构入口，尚未对应到条目级出处。')
                .fontSize(F.caption).fontColor(T.tertiary).lineHeight(20)
            }
          }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor(T.soft).borderRadius(12)
          Text(`拾遗手账 · ${this.notes().length}`).fontSize(F.section).fontWeight(FontWeight.Bold)
            .fontColor(T.ink).width('100%').margin({ top: 24, bottom: 12 })
          if (this.notes().length === 0) {
            Column({ space: 12 }) {
              SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(28).fontColor([T.accent])
              Text('尚无笔记').fontSize(F.small).fontColor(T.muted)
              Text('一段观察，也是一份属于你的河流记忆。').fontSize(F.caption).fontColor(T.muted)
            }.width('100%').padding(24).backgroundColor(T.surface).borderRadius(T.cardRadius)
          }
          ForEach(this.notes(), (note: ArchiveRecord) => {
            MemoryPostcardItem({ note, site: this.site, editable: true, busy: this.busy,
              onOpen: (): void => this.onReadMemory(note),
              onPose: () => {
                if (note.snapshot3DPose) this.restoreMemoryPose(note.snapshot3DPose);
                else this.detailScroller.scrollTo({ xOffset: 0, yOffset: 0 });
              },
              onEdit: () => this.editNote(note), onDelete: () => this.confirmDelete(note) })
            if (note.body.length > 200) {
              Button(this.expandedNoteId === note.id ? '收起全文' : '展开全文').fontSize(F.caption)
                .fontColor(T.accent).backgroundColor(T.accentSoft)
                .onClick(() => { this.expandedNoteId = this.expandedNoteId === note.id ? '' : note.id; })
              if (this.expandedNoteId === note.id) {
                Text(note.body).fontSize(F.body).fontColor(T.ink).lineHeight(26).width('100%').padding(16)
                  .backgroundColor(T.surface).copyOption(CopyOptions.LocalDevice)
              }
            }
          }, (note: ArchiveRecord) => `${note.id}:${note.updatedAt}`)
          Text('继续探索').fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink)
            .width('100%').margin({ top: 24, bottom: 14 })
          ForEach(recommendSites(HERITAGE_SITES, this.snapshot.records, this.site.id), (item: Recommendation) => {
            SiteRow({ site: item.site, reason: item.reason, onOpen: this.onOpen })
          }, (item: Recommendation) => item.site.id)
        }.width('100%').constraintSize({ maxWidth: 720 }).padding({ left: 16, right: 16, bottom: 32 })
      }.width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Auto).id('detail-scroll')
    }
    .title(this.site.name, { systemMaterial: HarmonyEffects.material(this.snapshot.lightEnabled, this.snapshot.reducedMotion) })
    .backgroundColor($r('app.color.canvas'))
    .onShown(() => { this.objectActive = true; })
    .onHidden(() => { this.objectActive = false; })
    .bindSheet($$this.editorOpen, this.noteEditor(), {
      height: SheetSize.LARGE, showClose: false, dragBar: false,
      keyboardAvoidMode: SheetKeyboardAvoidMode.RESIZE_ONLY,
      onWillDismiss: () => this.discardEditor()
    })
    .onBackPressed(() => {
      if (this.editorOpen) { this.discardEditor(); return true; }
      return this.busy;
    })
  }
}
