import { activeRecords, AiFactSnapshot, ArchiveRecord, ArchiveSnapshot, copySnapshot, nextTimestamp } from '../domain/ArchiveDomain';
import { HERITAGE_SITES } from '../data/HeritageCatalog';
import { isAiObservationSite } from '../domain/AiObservation';
import { aiKnowledgeScope } from '../domain/AiObservationKnowledge';
import { HarmonyEffects } from '../platform/HarmonyEffects';
import { MemoryPosePreview } from './MemoryPosePreview';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';

// 手账使用记录 ID 独立导航，读取共享快照而非路由里的旧副本；
// 编辑返回或跨端更新后仍展示同一篇，删除只写墓碑，不移除视角和 AI 依据。
@Component
export struct MemoryDetailPage {
  @Link @Watch('refreshNote') snapshot: ArchiveSnapshot;
  @Prop noteId: string = '';
  @Prop saving: boolean = false;
  onResolve: (noteId: string) => ArchiveRecord | undefined = () => undefined;
  onCommit: (next: ArchiveSnapshot) => Promise<boolean> = async () => false;
  onEdit: (note: ArchiveRecord) => void = () => {};
  onReplay: (note: ArchiveRecord) => void = () => {};
  onAsk: (note: ArchiveRecord) => void = () => {};
  onArchive: (siteId: string) => void = () => {};
  onBack: () => void = () => {};
  @State private evidenceOpen: boolean = false;
  @State private visibleNote: ArchiveRecord | undefined = undefined;
  @State private noteResolved: boolean = false;

  private note(): ArchiveRecord | undefined {
    // Navigation 会保留被详情覆盖的页面；编辑页落盘时，后台页面可能仍持有进入时的 Link 值。
    // 回到前台及快照变化时，从顶层当前快照按 ID 取最新记录，让正文和删除状态立即与磁盘一致。
    return this.noteResolved ? this.visibleNote :
      activeRecords(this.snapshot.records, 'note').find((item: ArchiveRecord) => item.id === this.noteId);
  }

  private refreshNote(): void {
    this.visibleNote = this.onResolve(this.noteId);
    this.noteResolved = true;
  }

  private currentNoteList(): ArchiveRecord[] {
    const note = this.note();
    return note ? [note] : [];
  }

  private title(): string {
    return HERITAGE_SITES.find(item => item.id === this.note()?.siteId)?.name || '我的手账';
  }

  private sourceLabel(id: string): string {
    const source = aiKnowledgeScope(this.note()?.siteId || '')?.sources.find(item => item.id === id);
    return source ? `${source.publisher} · ${source.title}` : `来源编号：${id}`;
  }

  private confirmDelete(): void {
    if (this.saving) return;
    this.getUIContext().showAlertDialog({
      title: '删除这页手账？', message: '删除会随同一账号同步。',
      primaryButton: { value: '保留', action: () => {} },
      secondaryButton: { value: '删除', action: () => { this.deleteNote(); } }
    });
  }

  private async deleteNote(): Promise<void> {
    if (this.saving) return;
    const next = copySnapshot(this.snapshot);
    const note = next.records.find(item => item.id === this.noteId && item.kind === 'note' && !item.deleted);
    if (!note) return;
    note.deleted = true;
    note.updatedAt = nextTimestamp(next.records, Date.now());
    note.deviceId = next.deviceId;
    if (await this.onCommit(next)) this.onBack();
  }

  @Builder
  content(note: ArchiveRecord) {
    Column({ space: 18 }) {
      Text(this.title()).fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink).width('100%')
      Text(new Date(note.updatedAt).toLocaleDateString()).fontSize(F.caption).fontColor(T.muted).width('100%')
      if (note.snapshot3DPose) {
        MemoryPosePreview({ siteId: note.siteId, poseJson: JSON.stringify(note.snapshot3DPose),
          previewHeight: 210, previewId: 'memory-detail-preview', onOpen: () => this.onReplay(note) })
        Button('重温当时视角', { type: ButtonType.Normal }).id('memory-detail-replay').height(44).width('100%')
          .fontColor(T.onAccent).backgroundColor(T.accent).onClick(() => this.onReplay(note))
      }
      Text(note.body).fontSize(F.body).fontColor(T.ink).lineHeight(28).width('100%')
        .copyOption(CopyOptions.LocalDevice).id('memory-detail-body')
      if (note.tags.length) {
        Text(note.tags.map((tag: string) => `#${tag}`).join('  ')).fontSize(F.small).fontColor(T.accent).width('100%')
      }
      if (note.quotedPoemOrFact) {
        Divider().color(T.line)
        Text('留下的资料摘录').fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.mintInk).width('100%')
        Text(note.quotedPoemOrFact).fontSize(F.small).fontColor(T.muted).lineHeight(24).width('100%')
      }
      if (note.aiAssist) {
        Divider().color(T.line)
        Column({ space: 10 }) {
          Row({ space: 8 }) {
            Text('AI 辅助记录').fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.mintInk).layoutWeight(1)
            Text(`资料 v${note.aiAssist.contentRevision}`).fontSize(F.caption).fontColor(T.tertiary)
          }.width('100%')
          Text('这次观察的问题').fontSize(F.caption).fontColor(T.muted).width('100%')
          Text(note.aiAssist.question).fontSize(F.body).fontColor(T.ink).lineHeight(26).width('100%')
            .id('memory-detail-question')
          Button(this.evidenceOpen ? '收起保存时的依据' : `保存时的依据 · ${note.aiAssist.facts.length} 条`,
            { type: ButtonType.Normal }).id('memory-detail-evidence').width('100%')
            .constraintSize({ minHeight: 40 }).fontSize(F.small).fontColor(T.mintInk).backgroundColor(T.mint)
            .borderRadius(11).onClick(() => { this.evidenceOpen = !this.evidenceOpen; })
          if (this.evidenceOpen) {
            Column({ space: 12 }) {
              ForEach(note.aiAssist.facts, (fact: AiFactSnapshot) => {
                Column({ space: 8 }) {
                  Text(fact.title).fontSize(F.small).fontWeight(FontWeight.Bold).fontColor(T.ink).width('100%')
                  Text(fact.body).fontSize(F.small).fontColor(T.muted).lineHeight(24).width('100%')
                  Text(fact.sourceIds.map((id: string) => this.sourceLabel(id)).join('\n'))
                    .fontSize(F.caption).fontColor(T.mintInk).lineHeight(20).width('100%')
                }.width('100%').alignItems(HorizontalAlign.Start).padding(12).backgroundColor(T.surface)
                  .borderRadius(11).border({ width: 1, color: T.line, radius: 11 })
                  .id(`memory-fact-${fact.id}`)
              }, (fact: AiFactSnapshot) => fact.id)
            }.width('100%')
          }
        }.width('100%').alignItems(HorizontalAlign.Start).padding(14).backgroundColor(T.soft).borderRadius(14)
          .id('memory-ai-block')
      }
      // 单一入口：有 AI 依据时用主色强调，普通手账用青色；不重复声明同一个控件 id。
      if (isAiObservationSite(note.siteId)) {
        Button('带着这页手账问 AI', { type: ButtonType.Normal }).id('memory-detail-ai').width('100%')
          .constraintSize({ minHeight: 44 }).fontSize(F.small)
          .fontColor(note.aiAssist ? T.onAccent : T.mintInk)
          .backgroundColor(note.aiAssist ? T.accent : T.mint).borderRadius(11)
          .accessibilityText('带着这页手账继续问 AI')
          .onClick(() => this.onAsk(note))
      }
      Row({ space: 12 }) {
        Button('编辑手账', { type: ButtonType.Normal }).id('memory-detail-edit').height(42).layoutWeight(1)
          .enabled(!this.saving && HERITAGE_SITES.some(item => item.id === note.siteId))
          .fontColor(T.accent).backgroundColor(T.accentSoft).onClick(() => this.onEdit(note))
        Button('原文化档案', { type: ButtonType.Normal }).id('memory-detail-archive').height(42).layoutWeight(1)
          .enabled(HERITAGE_SITES.some(item => item.id === note.siteId))
          .fontColor(T.ink).backgroundColor(T.soft).onClick(() => this.onArchive(note.siteId))
        Button({ type: ButtonType.Normal }) {
          SymbolGlyph($r('sys.symbol.trash')).fontSize(19).fontColor([T.muted])
        }.width(42).height(42).backgroundColor(T.soft).enabled(!this.saving)
          .accessibilityText('删除这页手账').id('memory-detail-delete').onClick(() => this.confirmDelete())
      }.width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination() {
      Scroll() {
        Column() {
          // ArkUI 会缓存从编辑页返回时的 Builder 子树；版本键变化后重建正文与依据区。
          ForEach(this.currentNoteList(), (note: ArchiveRecord) => {
            this.content(note)
          }, (note: ArchiveRecord) => `${note.id}:${note.updatedAt}`)
          if (this.currentNoteList().length === 0) {
            Text('这页手账已删除或暂不可用').fontSize(F.body).fontColor(T.muted)
            Button('返回记忆').onClick(this.onBack)
          }
        }.width('100%').constraintSize({ maxWidth: 720 }).padding(20)
      }.width('100%').height('100%').align(Alignment.Top).id('memory-detail-scroll')
    }.title('手账', { systemMaterial: HarmonyEffects.material(this.snapshot.lightEnabled, this.snapshot.reducedMotion) })
      .onShown(() => this.refreshNote())
      .backgroundColor(T.canvas).id('memory-detail-page')
  }
}
