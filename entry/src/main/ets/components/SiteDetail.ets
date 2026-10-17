import {
  activeRecords, ArchiveRecord, ArchiveSnapshot, COLLECTION_TAGS, copySnapshot,
  HeritageSite, MAX_NOTE_LENGTH, MAX_NOTE_TAGS, MAX_NOTE_TAG_LENGTH, MAX_NOTE_TAGS_TEXT_LENGTH,
  nextTimestamp, putRecord, recommendSites, Recommendation
} from '../domain/ArchiveDomain';
import { HERITAGE_SITES } from '../data/HeritageCatalog';
import { SiteRow, siteIllustration } from './SiteRow';
import { CulturalEngineViewport } from './CulturalEngineViewport';
import { CulturalEnginePayload, CulturalEngineLayer, CulturalSceneType } from '../domain/CulturalEngineContract';
import { getCulturalSiteMetadata, EXPLORATION_SECTIONS, ExplorationSectionId, CulturalLearningSection } from '../domain/CulturalContent';
import { decodeExplorationProgress, encodeExplorationProgressRecord } from '../domain/ExplorationProgress';
import { HarmonyEffects } from '../platform/HarmonyEffects';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';

@Component
export struct SiteDetail {
  @Prop site: HeritageSite = HERITAGE_SITES[0];
  @Link snapshot: ArchiveSnapshot;
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
  private bodyController: TextAreaController = new TextAreaController();
  private tagsController: TextInputController = new TextInputController();

  private favorite(): ArchiveRecord | undefined {
    return activeRecords(this.snapshot.records, 'favorite').find((record: ArchiveRecord) => record.siteId === this.site.id);
  }

  private notes(): ArchiveRecord[] {
    return activeRecords(this.snapshot.records, 'note').filter((record: ArchiveRecord) => record.siteId === this.site.id);
  }

  private enginePayload(): string {
    const payload: CulturalEnginePayload = { version: 1, itemId: this.site.id, title: this.site.name,
      proceduralPreset: getCulturalSiteMetadata(this.site.id)?.proceduralPreset || 'yangshao_pottery',
      selectedId: this.engineMode === 'stratum_slice' ? this.explorationSection : this.hotspot,
      exploredIds: decodeExplorationProgress(this.snapshot.records, this.site.id).completedSectionIds,
      layers: EXPLORATION_SECTIONS.map((section: CulturalLearningSection): CulturalEngineLayer => ({ id: section.id, label: section.title })) };
    return JSON.stringify(payload);
  }

  private selectedReading(): string {
    return this.explorationSection === 'overview' ? this.site.overview :
      this.explorationSection === 'archaeology' ? this.site.archaeology :
        this.explorationSection === 'history' ? this.site.history : `${this.site.poetry}\n${this.site.travel}`;
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
      Row({ space: 8 }) {
        Button('器物凝视').id('engine-mode-relic').onClick(() => { this.engineMode = 'relic_inspector'; })
          .layoutWeight(1).fontSize(F.small).fontColor(T.accent).backgroundColor(this.engineMode === 'relic_inspector' ? T.accentSoft : T.soft)
        Button('地层切片').id('engine-mode-stratum').onClick(() => { this.engineMode = 'stratum_slice'; })
          .layoutWeight(1).fontSize(F.small).fontColor(T.accent).backgroundColor(this.engineMode === 'stratum_slice' ? T.accentSoft : T.soft)
      }.width('100%')
      CulturalEngineViewport({ sceneType: this.engineMode, payloadJson: this.enginePayload(), viewportHeight: 300,
        reducedMotion: this.snapshot.reducedMotion, active: this.objectActive && !this.editorOpen,
        onNodeSelected: (id: string, type: string) => {
          if (type === 'hotspot') this.hotspot = id;
          const section = EXPLORATION_SECTIONS.find(section => section.id === id);
          if (type === 'layer' && section) this.explorationSection = section.id;
        } })
      if (this.engineMode === 'relic_inspector') {
        // 三个热点等分一行，显式收紧内边距，让 1.5 倍字号仍完整显示三字标签。
        // 保留系统字体缩放；后续增加文案长度时应改换行布局，不能靠限制字号掩盖截断。
        Row({ space: 8 }) {
          Button('观形制').id('hotspot-form').onClick(() => { this.hotspot = 'form'; })
            .layoutWeight(1).height(40).borderRadius(12).fontSize(F.small).fontColor(T.accent)
            .padding({ left: 4, right: 4 })
            .backgroundColor(this.hotspot === 'form' ? T.accentSoft : T.soft)
          Button('察纹样').id('hotspot-pattern').onClick(() => { this.hotspot = 'pattern'; })
            .layoutWeight(1).height(40).borderRadius(12).fontSize(F.small).fontColor(T.accent)
            .padding({ left: 4, right: 4 })
            .backgroundColor(this.hotspot === 'pattern' ? T.accentSoft : T.soft)
          Button('听故事').id('hotspot-story').onClick(() => { this.hotspot = 'story'; })
            .layoutWeight(1).height(40).borderRadius(12).fontSize(F.small).fontColor(T.accent)
            .padding({ left: 4, right: 4 })
            .backgroundColor(this.hotspot === 'story' ? T.accentSoft : T.soft)
        }.width('100%')
        Text(this.hotspot === 'form' ? this.site.overview : this.hotspot === 'pattern' ? this.site.archaeology : this.site.history)
          .fontSize(F.small).fontColor(T.muted).lineHeight(24).width('100%').id('engine-hotspot-reading')
        Text('按档案主题生成的几何与装饰示意，非文物或遗址复原。')
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

  private editNote(note?: ArchiveRecord): void {
    this.editingId = note ? note.id : '';
    this.draft = note ? note.body : '';
    this.noteTags = note ? note.tags.join('，') : '';
    this.originalDraft = this.draft;
    this.originalTags = this.noteTags;
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
    if (this.draft !== this.originalDraft || this.noteTags !== this.originalTags) {
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
    const record: ArchiveRecord = {
      id: note.id, kind: note.kind, siteId: note.siteId, body: note.body, tags: note.tags.slice(),
      updatedAt: nextTimestamp(next.records, Date.now()), deviceId: next.deviceId, deleted: true
    };
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
          Text(this.editingId ? '编辑笔记' : '记录此刻').fontSize(F.display).fontWeight(FontWeight.Bold).fontColor(T.ink)
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
      Button(this.busy ? '正在保存' : '保存笔记', { type: ButtonType.Normal })
        .width('100%').height(48).fontSize(F.body).borderRadius(8).backgroundColor(T.accent)
        .fontColor(T.onAccent).enabled(!this.busy).id('save-note').onClick(() => this.saveNote())
    }.padding(20).width('100%').height('100%').backgroundColor(T.surface)
  }

  build() {
    NavDestination() {
      Scroll() {
        Column() {
          this.culturalExperience()
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
                Text('写笔记').fontSize(F.small).fontColor(T.accent)
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
          this.section('诗文索引', this.site.poetry)
          this.section('探访信息', this.site.travel)
          Column({ space: 10 }) {
            Text(this.site.reviewStatus).fontSize(F.caption).fontColor(T.accent)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 }).backgroundColor(T.accentSoft).borderRadius(6)
            Text(this.site.source.title).fontSize(F.caption).fontColor(T.muted)
            Text(this.site.source.url).fontSize(F.caption).fontColor(T.muted)
              .copyOption(CopyOptions.LocalDevice)
            Text('封面为主题示意图，非文物或遗址复原。').fontSize(F.caption).fontColor(T.muted).lineHeight(20)
          }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor(T.soft).borderRadius(12)
          Text(`我的笔记 · ${this.notes().length}`).fontSize(F.section).fontWeight(FontWeight.Bold)
            .fontColor(T.ink).width('100%').margin({ top: 24, bottom: 12 })
          if (this.notes().length === 0) {
            Column({ space: 12 }) {
              SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(28).fontColor([T.accent])
              Text('尚无笔记').fontSize(F.small).fontColor(T.muted)
              Text('一段观察，也是一份属于你的河流记忆。').fontSize(F.caption).fontColor(T.muted)
            }.width('100%').padding(24).backgroundColor(T.surface).borderRadius(T.cardRadius)
          }
          ForEach(this.notes(), (note: ArchiveRecord) => {
            Column({ space: 12 }) {
              // 操作放在笔记顶部；长正文默认摘要并可展开，避免 4000 字把编辑/删除
              // 推到数屏之后。只折叠显示，不修改正文或标签；编辑器仍加载完整记录。
              Row() {
                Text(new Date(note.updatedAt).toLocaleString()).fontSize(11).fontColor($r('app.color.muted'))
                  .layoutWeight(1)
                Button({ type: ButtonType.Circle }) {
                  SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(18).fontColor([$r('app.color.ink')])
                }.width(44).height(44).backgroundColor(Color.Transparent).accessibilityText('编辑笔记')
                  .enabled(!this.busy).id(`edit-${note.id}`).onClick(() => this.editNote(note))
                Button({ type: ButtonType.Circle }) {
                  SymbolGlyph($r('sys.symbol.trash')).fontSize(18).fontColor([$r('app.color.danger')])
                }.width(44).height(44).backgroundColor(Color.Transparent).accessibilityText('删除笔记')
                  .enabled(!this.busy).id(`delete-${note.id}`).onClick(() => this.confirmDelete(note))
              }.width('100%')
              Text(note.tags.join(' · ')).fontSize(12).fontColor($r('app.color.accent')).width('100%')
                .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              if (note.body.length > 200) {
                Button(this.expandedNoteId === note.id ? '收起全文' : '展开全文', { type: ButtonType.Normal })
                  .fontSize(13).height(40).backgroundColor(Color.Transparent).fontColor($r('app.color.accent'))
                  .onClick(() => { this.expandedNoteId = this.expandedNoteId === note.id ? '' : note.id; })
              }
              Text(note.body).fontSize(F.body).fontColor(T.ink).lineHeight(26)
                .copyOption(CopyOptions.LocalDevice).width('100%')
                .maxLines(this.expandedNoteId === note.id ? MAX_NOTE_LENGTH : 8)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }.padding(16).margin({ bottom: 12 }).borderRadius(T.cardRadius).backgroundColor(T.surface).width('100%')
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
