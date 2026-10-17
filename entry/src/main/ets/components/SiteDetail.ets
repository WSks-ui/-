import {
  activeRecords, ArchiveRecord, ArchiveSnapshot, COLLECTION_TAGS, copySnapshot,
  HeritageSite, MAX_NOTE_LENGTH, MAX_NOTE_TAGS, MAX_NOTE_TAG_LENGTH, MAX_NOTE_TAGS_TEXT_LENGTH,
  nextTimestamp, putRecord, recommendSites, Recommendation, MemoryPose, copyMemoryPose
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

interface MemoryPoseRequest extends MemoryPose { request: number; }

@Component
export struct SiteDetail {
  @Prop site: HeritageSite = HERITAGE_SITES[0];
  @Link snapshot: ArchiveSnapshot;
  @Prop initialPoseJson: string = '';
  onCommit: (next: ArchiveSnapshot) => Promise<boolean> = async () => false;
  onOpen: (site: HeritageSite) => void = () => {};
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
  @State private poseRequestJson: string = '';
  @State private replayRevision: number = 0;
  @State private replayMessage: string = '';
  @State private replayBlocked: boolean = false;
  private originalDecoration: string = '';
  private detailScroller: Scroller = new Scroller();
  private bodyController: TextAreaController = new TextAreaController();
  private tagsController: TextInputController = new TextInputController();

  aboutToAppear(): void {
    const observation = materialObservationForSite(this.site.id);
    if (observation) this.hotspot = observation.hotspots[0].id;
    if (this.initialPoseJson) {
      try { this.restoreMemoryPose(JSON.parse(this.initialPoseJson) as MemoryPose); }
      catch { this.replayMessage = '保存的观察参数暂不能读取，文字手账仍可查看'; this.replayBlocked = true; }
    }
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
    this.poseRequestJson = JSON.stringify(request);
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
    this.poseRequestJson = ''; this.replayMessage = ''; this.replayBlocked = false;
    this.hotspot = id;
  }

  private startObservation(mode: CulturalSceneType = 'relic_inspector'): void {
    this.replayRevision = 0; this.replayMessage = ''; this.replayBlocked = false; this.poseRequestJson = '';
    this.engineMode = mode;
    this.hotspot = materialObservationForSite(this.site.id)?.hotspots[0].id || 'form';
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

  private enginePayload(): string {
    const payload: CulturalEnginePayload = { version: 1, itemId: this.site.id, title: this.site.name,
      proceduralPreset: getCulturalSiteMetadata(this.site.id)?.proceduralPreset || 'yangshao_pottery',
      sceneRevision: this.sceneRevision(),
      selectedId: this.engineMode === 'stratum_slice' ? this.explorationSection : this.hotspot,
      exploredIds: decodeExplorationProgress(this.snapshot.records, this.site.id).completedSectionIds,
      layers: EXPLORATION_SECTIONS.map((section: CulturalLearningSection): CulturalEngineLayer => ({ id: section.id, label: section.title })) };
    return JSON.stringify(payload);
  }

  private selectedReading(): string {
    return this.explorationSection === 'overview' ? this.site.overview :
      this.explorationSection === 'archaeology' ? this.site.archaeology :
        this.explorationSection === 'history' ? this.site.history :
          [this.site.poetry, this.site.travel].filter((text: string) => text.length > 0).join('\n');
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
  culturalExperience() {
    Column({ space: 12 }) {
      Text('文化凝视').fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink).width('100%')
      if (this.observation()) {
        Text(materialStudyForId(this.site.id)?.question || '').fontSize(F.body).fontColor(T.ink)
          .fontWeight(FontWeight.Medium).lineHeight(27).width('100%')
      }
      Row({ space: 8 }) {
        Button('器物凝视').id('engine-mode-relic').onClick(() => this.startObservation('relic_inspector'))
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
        rememberEnabled: true, memoryPoseJson: this.poseRequestJson,
        onRememberView: (pose: MemoryPose) => this.editNote(undefined, pose),
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
          Button('观形制').id('hotspot-form').onClick(() => this.selectHotspot('form'))
            .layoutWeight(1).height(40).borderRadius(12).fontSize(F.small).fontColor(T.accent)
            .padding({ left: 4, right: 4 })
            .backgroundColor(this.hotspot === 'form' ? T.accentSoft : T.soft)
          Button('察纹样').id('hotspot-pattern').onClick(() => this.selectHotspot('pattern'))
            .layoutWeight(1).height(40).borderRadius(12).fontSize(F.small).fontColor(T.accent)
            .padding({ left: 4, right: 4 })
            .backgroundColor(this.hotspot === 'pattern' ? T.accentSoft : T.soft)
          Button('读线索').id('hotspot-story').onClick(() => this.selectHotspot('story'))
            .layoutWeight(1).height(40).borderRadius(12).fontSize(F.small).fontColor(T.accent)
            .padding({ left: 4, right: 4 })
            .backgroundColor(this.hotspot === 'story' ? T.accentSoft : T.soft)
        }.width('100%')
        }
        Text(this.observation() ? this.selectedObservationReading() :
          (this.hotspot === 'form' ? this.site.overview : this.hotspot === 'pattern' ? this.site.archaeology : this.site.history))
          .fontSize(F.small).fontColor(T.muted).lineHeight(24).width('100%').id('engine-hotspot-reading')
        Text(this.observation()?.notice || '按档案主题生成的几何与装饰示意，非文物或遗址复原。')
          .fontSize(F.caption).fontColor(T.muted).lineHeight(20).width('100%').id('site-object-notice')
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
    const record: ArchiveRecord = {
      id: `favorite:${this.site.id}`, kind: 'favorite', siteId: this.site.id, body: '',
      tags: tag ? [tag] : ['待实地探访'], updatedAt: nextTimestamp(next.records, Date.now()),
      deviceId: next.deviceId, deleted: !tag && previous !== undefined
    };
    next.records = putRecord(next.records, record);
    await this.onCommit(next);
    this.busy = false;
  }

  private editNote(note?: ArchiveRecord, pose?: MemoryPose): void {
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
    this.originalDecoration = this.decoration();
    this.validation = '';
    this.editorOpen = true;
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
    this.busy = true;
    const next = copySnapshot(this.snapshot);
    const time = nextTimestamp(next.records, Date.now());
    const record: ArchiveRecord = {
      id: this.editingId || `note:${next.deviceId}:${time}`, kind: 'note', siteId: this.site.id,
      body, tags, updatedAt: time, deviceId: next.deviceId, deleted: false
    };
    record.stampType = this.stampType;
    record.paperTheme = this.paperTheme;
    if (this.quoteEnabled && this.quotedText) record.quotedPoemOrFact = this.quotedText;
    if (this.draftPose) record.snapshot3DPose = this.draftPose;
    next.records = putRecord(next.records, record);
    if (await this.onCommit(next)) {
      this.editorOpen = false;
      this.draft = '';
      this.originalDraft = '';
      this.noteTags = '';
      this.originalTags = '';
    }
    this.busy = false;
  }

  private discardEditor(): void {
    if (this.busy) return;
    this.finishEditing();
    if (this.draft !== this.originalDraft || this.noteTags !== this.originalTags || this.decoration() !== this.originalDecoration) {
      this.getUIContext().showAlertDialog({
        title: '放弃尚未保存的修改？',
        message: '已保存的笔记不会被删除。',
        primaryButton: { value: '继续编辑', action: () => {} },
        secondaryButton: { value: '放弃修改', action: () => { this.editorOpen = false; } }
      });
    } else this.editorOpen = false;
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
      Text(content).fontSize(F.body).lineHeight(28).fontColor(T.ink)
        .copyOption(CopyOptions.LocalDevice)
    }.alignItems(HorizontalAlign.Start).width('100%').padding(20)
      .backgroundColor(T.surface).borderRadius(T.cardRadius).margin({ bottom: 12 })
  }

  @Builder
  noteEditor() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 6 }) {
          Text(this.site.name).fontSize(F.caption).fontColor(T.accent)
          Text(this.editingId ? '编辑拾遗手账' : '留一页，记住此刻').fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink)
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
                .borderRadius(18).accessibilityText('文化主题示意，非遗址实景')
              Row() {
                Text(this.site.type).fontSize(F.caption).fontColor(T.mintInk)
                  .padding({ left: 9, right: 9, top: 5, bottom: 5 }).backgroundColor(T.surface).borderRadius(6)
                Blank()
                Text('主题示意').fontSize(F.caption).fontColor(T.muted)
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
          this.section('档案概览', this.site.overview)
          this.section('考古与遗存', this.site.archaeology)
          this.section('历史线索', this.site.history)
          // 没有核实诗文时不制造一段“以后补充”的正文；旧档案有内容时仍正常展示。
          if (this.site.poetry) {
            this.section('诗文索引', this.site.poetry)
          }
          this.section('探访信息', this.site.travel)
          Column({ space: 10 }) {
            Text(this.site.reviewStatus).fontSize(F.caption).fontColor(T.accent)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 }).backgroundColor(T.accentSoft).borderRadius(6)
            Text(this.site.source.title).fontSize(F.caption).fontColor(T.muted)
            Text(this.site.source.url).fontSize(F.caption).fontColor(T.muted)
              .copyOption(CopyOptions.LocalDevice)
            Text('封面为主题示意图，非文物或遗址复原。').fontSize(F.caption).fontColor(T.muted).lineHeight(20)
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
              onOpen: (): void => { this.detailScroller.scrollTo({ xOffset: 0, yOffset: 0 }); },
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
