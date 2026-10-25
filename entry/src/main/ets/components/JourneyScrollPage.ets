import { ArchiveRecord, ArchiveSnapshot, HeritageSite } from '../domain/ArchiveDomain';
import { HERITAGE_SITES } from '../data/HeritageCatalog';
import {
  buildJourneyScroll, JourneyScrollEntry, JourneyScrollGroup, JourneyScrollModel, JourneyScrollStep
} from '../domain/JourneyScroll';
import { HarmonyEffects } from '../platform/HarmonyEffects';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';
import { MemoryPosePreview } from './MemoryPosePreview';

// 长卷只是当前档案的阅读视图：收藏、手账与探索各自保留含义，展开状态不写入个人数据。
// 具体手账始终按原记录回调，不能从一个地点拼出一张默认镜头冒充用户保存的观察。
@Component
export struct JourneyScrollPage {
  @Link @Watch('snapshotChanged') snapshot: ArchiveSnapshot;
  onOpenSite: (site: HeritageSite) => void = () => {};
  onReadMemory: (note: ArchiveRecord) => void = () => {};
  onReplayMemory: (note: ArchiveRecord) => void = () => {};
  onOpenGraph: () => void = () => {};
  @State private expandedStepId: string = '';
  @State private expandedSourceId: string = '';
  private stepChosen: boolean = false;
  private personalOffset: number = 0;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.expandedStepId = this.model().progress.nextSiteId;
  }

  private model(): JourneyScrollModel {
    // 在 Builder 内读取 Link 的当前值；不能把首次进入时的派生结果留作普通成员缓存，
    // 否则编辑、删除或同账号同步回来后，页面会继续显示旧正文与旧专题。
    return buildJourneyScroll(HERITAGE_SITES, this.snapshot.records);
  }

  private snapshotChanged(): void {
    if (!this.stepChosen) this.expandedStepId = this.model().progress.nextSiteId;
  }

  private nextSite(): HeritageSite | undefined {
    const model = this.model();
    return model.steps.find((step: JourneyScrollStep) => step.site.id === model.progress.nextSiteId)?.site;
  }

  private continueReading(): void {
    const next = this.nextSite();
    if (next) this.onOpenSite(next);
    else this.openPersonal();
  }

  private openPersonal(): void {
    // 保存后可以从卷首直达个人记录，不必先滚过四步阅读路线；只滚动当前页，不改路由或档案。
    this.scroller.scrollTo({ xOffset: 0, yOffset: Math.max(0, this.personalOffset - 16) });
  }

  private toggleStep(siteId: string): void {
    this.stepChosen = true;
    this.expandedStepId = this.expandedStepId === siteId ? '' : siteId;
  }

  private stepKey(step: JourneyScrollStep): string {
    return `${step.site.id}:${step.completed}:${step.favorite}:${step.noteCount}:${step.exploredPercent}:` +
      `${this.model().progress.nextSiteId}:${this.expandedStepId === step.site.id}:${this.expandedSourceId === step.site.id}`;
  }

  private entryKey(entry: JourneyScrollEntry): string {
    return `${entry.site.id}:${entry.favorite}:${entry.exploredPercent}:${entry.reasons.join('|')}:` +
      entry.notes.map((note: ArchiveRecord) => `${note.id}:${note.updatedAt}`).join('|');
  }

  private groupKey(group: JourneyScrollGroup): string {
    return `${group.city}:${group.entries.map((entry: JourneyScrollEntry) => this.entryKey(entry)).join('|')}`;
  }

  private entryTopics(entry: JourneyScrollEntry): string {
    const tags: string[] = [];
    entry.notes.forEach((note: ArchiveRecord) => {
      note.tags.forEach((tag: string) => { if (!tags.includes(tag)) tags.push(tag); });
    });
    const lines = entry.reasons.slice();
    if (tags.length > 0) lines.push(`手账标签：${tags.map((tag: string) => `#${tag}`).join(' · ')}`);
    if (lines.length > 0) return lines.join('\n');
    return entry.notes.length > 0 ? '从这一页个人观察开始。' :
      (entry.favorite ? '已收藏，留待继续阅读。' : '这里留有你的主题阅读记录。');
  }

  private notePaper(note: ArchiveRecord): Resource {
    if (note.paperTheme === 'jade') return T.mint;
    if (note.paperTheme === 'ink') return T.sunken;
    if (note.paperTheme === 'ochre') return T.yellow;
    if (note.paperTheme === 'rose') return T.accentSoft;
    return T.soft;
  }

  @Builder
  hero() {
    Column({ space: 18 }) {
      Row({ space: 8 }) {
        Text('个人文化记忆').fontSize(F.caption).fontColor(T.yellowInk).letterSpacing(2)
        Blank()
        Text('卷 · 一').fontSize(F.caption).fontColor(T.yellowInk)
          .padding({ left: 9, right: 9, top: 5, bottom: 5 })
          .border({ width: 1, color: T.line, radius: 6 }).borderRadius(6)
      }.width('100%')
      Column({ space: 9 }) {
        Text(this.model().route.title).fontSize(34).fontWeight(FontWeight.Bold).fontColor(T.ink)
          .letterSpacing(3).width('100%')
        Text('沿着材料与形制，回看你留下的观察。').fontSize(F.small).fontColor(T.muted)
          .lineHeight(24).width('100%')
      }.width('100%').alignItems(HorizontalAlign.Start)
      Row({ space: 10 }) {
        Text(`${this.model().noteCount} 页手账`).fontSize(F.small).fontColor(T.ink)
        Text('·').fontSize(F.caption).fontColor(T.tertiary)
        Text(`${this.model().personalSiteCount} 处个人线索`).fontSize(F.small).fontColor(T.ink)
        Blank()
      }.width('100%')
      Column({ space: 8 }) {
        Row() {
          Text(this.model().progress.unlocked ? '四处线索，已经连成一卷' : '主题路线进度')
            .fontSize(F.caption).fontColor(T.muted).layoutWeight(1)
          Text(`${this.model().progress.completedCount} / ${this.model().progress.total} 已点亮`)
            .fontSize(F.caption).fontColor(T.yellowInk).id('journey-scroll-progress')
        }.width('100%')
        Progress({ value: this.model().progress.percent, total: 100, type: ProgressType.Linear })
          .width('100%').color(this.model().route.color).backgroundColor(T.sunken).style({ strokeWidth: 3 })
      }.width('100%')
      Button({ type: ButtonType.Normal }) {
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text(this.nextSite() ? '接着读 · 下一处' : '回顾 · 我的记录')
              .fontSize(F.caption).fontColor(T.onAccent).opacity(0.85)
            Text(this.nextSite()?.name || '展开已经留下的观察')
              .fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.onAccent)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          SymbolGlyph($r('sys.symbol.arrow_right')).fontSize(19).fontColor([T.onAccent])
        }.width('100%')
      }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
        .backgroundColor(this.model().route.color).borderRadius(15).id('journey-next-open')
        .accessibilityText(this.nextSite() ? `继续阅读${this.nextSite()?.name}` : '回顾这条长卷的个人记录')
        .onClick(() => this.continueReading())
      if (this.nextSite() && this.model().personalSiteCount > 0) {
        Button(this.model().noteCount > 0 ? `看我的 ${this.model().noteCount} 页手账` :
          `看我的 ${this.model().personalSiteCount} 处线索`, { type: ButtonType.Normal })
          .height(34).fontSize(F.caption).fontColor(T.yellowInk).backgroundColor(Color.Transparent)
          .padding({ left: 0, right: 0 }).id('journey-personal-open').onClick(() => this.openPersonal())
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding(22).backgroundColor(T.surface)
      .borderRadius(24).border({ width: 1, color: T.line, radius: 24 })
  }

  @Builder
  sourceDetails(step: JourneyScrollStep) {
    Column({ space: 8 }) {
      Text(step.site.source.title).fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.ink)
        .lineHeight(22).width('100%')
      Text(step.site.source.url).fontSize(F.caption).fontColor(T.muted).lineHeight(19).width('100%')
        .copyOption(CopyOptions.LocalDevice)
      if (step.site.source.url) {
        // 2026-10-21 核对本机 API 26：Hyperlink 是原生 ArkUI 基础组件，由系统浏览器打开现有来源链接。
        Hyperlink(step.site.source.url, '打开来源网页').color(T.mintInk)
          .padding({ top: 5, bottom: 5 }).accessibilityText(`打开资料来源：${step.site.source.title}`)
      }
      Text(step.site.reviewStatus).fontSize(F.caption).fontColor(T.tertiary).width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start).padding(12).backgroundColor(T.soft).borderRadius(12)
  }

  @Builder
  routeStep(step: JourneyScrollStep) {
    Row({ space: 12 }) {
      Column({ space: 8 }) {
        Text(step.completed ? '✓' : `0${step.index}`).fontSize(F.caption).fontWeight(FontWeight.Medium)
          .fontColor(step.completed ? T.onAccent : T.yellowInk).width(32).height(32)
          .textAlign(TextAlign.Center).backgroundColor(step.completed ? this.model().route.color : T.yellow)
          .borderRadius(12)
        if (step.index < this.model().steps.length) {
          // Scroll 子项的纵向约束无上限；装饰线只占明确的短高度，
          // 不能用 Stretch 与 layoutWeight 将整步撑成一屏空白。
          Blank().width(1).height(48).backgroundColor(T.line)
        }
      }.width(32).height(step.index < this.model().steps.length ? 88 : 32)
      Column({ space: 10 }) {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 10 }) {
            Column({ space: 6 }) {
              Text(step.site.name).fontSize(F.card).fontWeight(FontWeight.Medium).fontColor(T.ink).width('100%')
              Text(`${step.site.city} · ${step.site.era} · ${step.site.type}`)
                .fontSize(F.caption).fontColor(T.muted).width('100%')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(13).fontColor([T.yellowInk])
              .rotate({ angle: this.expandedStepId === step.site.id ? 90 : 0 })
          }.width('100%')
        }.width('100%').padding({ top: 3, bottom: 3 }).backgroundColor(Color.Transparent).borderRadius(10)
          .id(`journey-step-${step.site.id}`)
          .accessibilityText(`${step.index}，${step.site.name}，${this.expandedStepId === step.site.id ? '收起' : '展开'}阅读理由与出处`)
          .onClick(() => this.toggleStep(step.site.id))
        Row({ space: 9 }) {
          if (step.site.id === this.model().progress.nextSiteId) {
            Text('下一处').fontSize(F.caption).fontColor(T.yellowInk)
          }
          if (step.completed) { Text('已点亮').fontSize(F.caption).fontColor(T.yellowInk) }
          if (step.noteCount > 0) { Text(`${step.noteCount} 页手账`).fontSize(F.caption).fontColor(T.mintInk) }
          if (step.favorite) { Text('已收藏').fontSize(F.caption).fontColor(T.accent) }
          if (step.exploredPercent > 0 && step.noteCount === 0) {
            Text(`探索 ${step.exploredPercent}%`).fontSize(F.caption).fontColor(T.muted)
          }
        }.width('100%')
        if (this.expandedStepId === step.site.id) {
          Text(step.readingReason).fontSize(F.small).fontColor(T.muted).lineHeight(23).width('100%')
            .id(`journey-reason-${step.site.id}`)
          Row({ space: 8 }) {
            Button('打开档案', { type: ButtonType.Normal }).fontSize(F.caption).fontColor(T.yellowInk)
              .height(34).padding({ left: 10, right: 10 }).backgroundColor(T.yellow).borderRadius(9)
              .id(`journey-step-open-${step.site.id}`).onClick(() => this.onOpenSite(step.site))
            Button(this.expandedSourceId === step.site.id ? '收起出处' : '资料出处', { type: ButtonType.Normal })
              .fontSize(F.caption).fontColor(T.mintInk).height(34).padding({ left: 10, right: 10 })
              .backgroundColor(T.soft).borderRadius(9).id(`journey-source-${step.site.id}`)
              .onClick(() => { this.expandedSourceId = this.expandedSourceId === step.site.id ? '' : step.site.id; })
          }.width('100%')
          if (this.expandedSourceId === step.site.id) { this.sourceDetails(step) }
        }
      }.width('100%').layoutWeight(1).alignItems(HorizontalAlign.Start).padding({ bottom: 20 })
    }.width('100%').alignItems(VerticalAlign.Top)
  }

  @Builder
  readingRoute() {
    Column({ space: 18 }) {
      Row({ space: 10 }) {
        Text('沿线再读').fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink).layoutWeight(1)
        Text(`${this.model().steps.length} 处档案`).fontSize(F.caption).fontColor(T.yellowInk)
      }.width('100%')
      Text(this.model().route.caption).fontSize(F.small).fontColor(T.muted).lineHeight(23).width('100%')
      Column() {
        // Builder 的值参数会随旧子树保留；把进度和展开状态写入版本键，
        // 使“下一处”、理由与出处在记录变化或点击后确实重建。
        ForEach(this.model().steps, (step: JourneyScrollStep) => {
          this.routeStep(step)
        }, (step: JourneyScrollStep) => this.stepKey(step))
      }.width('100%')
      Text('顺序为主题阅读编排；每处出处可展开核对。').fontSize(F.caption).fontColor(T.tertiary)
        .lineHeight(20).width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 5, right: 5 })
  }

  @Builder
  noteCard(note: ArchiveRecord) {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text(new Date(note.updatedAt).toLocaleDateString()).fontSize(F.caption).fontColor(T.muted).layoutWeight(1)
        if (note.aiAssist) {
          Text('AI 辅助整理').fontSize(F.caption).fontColor(T.mintInk)
            .padding({ left: 7, right: 7, top: 4, bottom: 4 }).backgroundColor(T.surface).borderRadius(7)
        }
      }.width('100%')
      if (note.snapshot3DPose) {
        MemoryPosePreview({ siteId: note.siteId, poseJson: JSON.stringify(note.snapshot3DPose),
          previewHeight: 170, previewId: `journey-preview-${note.id}`, onOpen: () => this.onReplayMemory(note) })
      }
      Text(note.body).fontSize(F.small).fontColor(T.ink).lineHeight(25).width('100%')
        .maxLines(4).textOverflow({ overflow: TextOverflow.Ellipsis })
      Row({ space: 10 }) {
        Button('读手账全文', { type: ButtonType.Normal }).height(39).fontSize(F.caption)
          .fontColor(T.ink).backgroundColor(T.surface).borderRadius(10).layoutWeight(1)
          .id(`journey-read-${note.id}`).onClick(() => this.onReadMemory(note))
        if (note.snapshot3DPose) {
          Button('回到保存视角', { type: ButtonType.Normal }).height(39).fontSize(F.caption)
            .fontColor(T.onAccent).backgroundColor(T.accent).borderRadius(10).layoutWeight(1)
            .id(`journey-replay-${note.id}`).onClick(() => this.onReplayMemory(note))
        }
      }.width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start).padding(14).backgroundColor(this.notePaper(note))
      .borderRadius(17).id(`journey-note-${note.id}`)
  }

  @Builder
  personalEntry(entry: JourneyScrollEntry) {
    Column({ space: 14 }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 12 }) {
          Column({ space: 6 }) {
            Text(entry.site.name).fontSize(F.card).fontWeight(FontWeight.Bold).fontColor(T.ink).width('100%')
            Text(`${entry.site.era} · ${entry.site.type}`).fontSize(F.caption).fontColor(T.muted).width('100%')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([T.yellowInk])
        }.width('100%')
      }.width('100%').padding(0).backgroundColor(Color.Transparent).borderRadius(10)
        .id(`journey-entry-open-${entry.site.id}`).accessibilityText(`打开${entry.site.name}档案`)
        .onClick(() => this.onOpenSite(entry.site))
      Row({ space: 10 }) {
        if (entry.notes.length > 0) { Text(`${entry.notes.length} 页手账`).fontSize(F.caption).fontColor(T.mintInk) }
        if (entry.favorite) { Text('已收藏').fontSize(F.caption).fontColor(T.accent) }
        if (entry.exploredPercent > 0) {
          Text(`探索 ${entry.exploredPercent}%`).fontSize(F.caption).fontColor(T.yellowInk)
        }
      }.width('100%')
      Text(this.entryTopics(entry)).fontSize(F.caption).fontColor(T.mintInk).lineHeight(21).width('100%')
        .id(`journey-topic-${entry.site.id}`)
      if (entry.notes.length === 0) {
        Text('这处线索已收入长卷，下一段观察可以从档案开始。').fontSize(F.small).fontColor(T.muted)
          .lineHeight(24).width('100%')
      }
      ForEach(entry.notes, (note: ArchiveRecord) => {
        this.noteCard(note)
      }, (note: ArchiveRecord) => `${note.id}:${note.updatedAt}`)
    }.width('100%').alignItems(HorizontalAlign.Start).padding(17).backgroundColor(T.surface)
      .borderRadius(T.cardRadius).border({ width: 1, color: T.line, radius: T.cardRadius })
      .id(`journey-entry-${entry.site.id}`)
  }

  @Builder
  cityGroup(group: JourneyScrollGroup) {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Text(group.city).fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink)
        Divider().color(T.line).layoutWeight(1)
        Text(`${group.entries.length} 处线索`).fontSize(F.caption).fontColor(T.muted)
      }.width('100%').padding({ left: 4, right: 4 })
      ForEach(group.entries, (entry: JourneyScrollEntry) => {
        this.personalEntry(entry)
      }, (entry: JourneyScrollEntry) => this.entryKey(entry))
    }.width('100%').alignItems(HorizontalAlign.Start).id(`journey-city-${group.city}`)
  }

  @Builder
  emptyScroll() {
    Column({ space: 15 }) {
      SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(31).fontColor([T.yellowInk])
      Text('长卷，等你落下第一笔').fontSize(F.card).fontWeight(FontWeight.Medium).fontColor(T.ink)
      Text('收藏一处档案、留下一页手账，或完成一个阅读主题，线索就会在这里展开。')
        .fontSize(F.small).fontColor(T.muted).lineHeight(25).textAlign(TextAlign.Center).width('100%')
      Button('开始第一处观察', { type: ButtonType.Normal }).height(42).fontSize(F.small)
        .fontColor(T.yellowInk).backgroundColor(T.yellow).borderRadius(12).padding({ left: 18, right: 18 })
        .id('journey-empty-open').onClick(() => this.continueReading())
    }.width('100%').padding({ left: 24, right: 24, top: 30, bottom: 30 }).backgroundColor(T.surface)
      .borderRadius(T.cardRadius).id('journey-empty')
  }

  build() {
    NavDestination() {
      Scroll(this.scroller) {
        Column({ space: 26 }) {
          this.hero()
          this.readingRoute()
          Column({ space: 8 }) {
            Text('我的观察长卷').fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink).width('100%')
              .id('journey-personal-title')
            Text('按城市摊开，读回每一页保存的发现。').fontSize(F.small).fontColor(T.muted).lineHeight(23).width('100%')
          }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 4, right: 4 })
            .onAreaChange((_old: Area, area: Area) => { this.personalOffset = Number(area.position.y); })
          if (this.model().groups.length === 0) { this.emptyScroll() }
          ForEach(this.model().groups, (group: JourneyScrollGroup) => {
            this.cityGroup(group)
          }, (group: JourneyScrollGroup) => this.groupKey(group))
          Column({ space: 12 }) {
            Button('在文明连线中看这条路线', { type: ButtonType.Normal }).height(43).width('100%')
              .fontSize(F.small).fontColor(T.yellowInk).backgroundColor(T.surface).borderRadius(13)
              .id('journey-graph').onClick(this.onOpenGraph)
            Text('长卷来自你的收藏、手账与阅读记录，随保存和删除一起更新。')
              .fontSize(F.caption).fontColor(T.tertiary).lineHeight(21).textAlign(TextAlign.Center).width('100%')
          }.width('100%')
        }.width('100%').constraintSize({ maxWidth: 760 }).alignItems(HorizontalAlign.Start)
          .padding({ left: 20, right: 20, top: 24, bottom: 36 })
      }.width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Auto).id('journey-scroll')
    }.title('我的泥火长卷', { systemMaterial: HarmonyEffects.material(this.snapshot.lightEnabled, this.snapshot.reducedMotion) })
      .backgroundColor(T.canvas).id('journey-scroll-page')
  }
}
