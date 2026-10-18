import { SegmentButton, SegmentButtonOptions } from '@ohos.arkui.advanced.SegmentButton';
import { activeRecords, ArchiveRecord, ArchiveSnapshot, HeritageSite, mergeRecords } from '../domain/ArchiveDomain';
import { connectionReasons, cultureConnections, CultureConnection, cultureTopics, personalCultureSites } from '../domain/CultureConnections';
import { HERITAGE_SITES } from '../data/HeritageCatalog';
import { MATERIAL_COMPARISON } from '../data/MaterialStudyCatalog';
import { CulturalEngineViewport } from './CulturalEngineViewport';
import { MaterialComparisonPanel } from './MaterialComparisonPanel';
import { CulturalEnginePayload, CulturalEngineNode, CulturalEngineEdge } from '../domain/CulturalEngineContract';
import { cultureGraphData, CultureGraphNode, CultureGraphEdge } from '../domain/CultureGraphData';
import { decodeExplorationProgress } from '../domain/ExplorationProgress';
import { isMemoryPostcard } from '../domain/MemoryJournal';
import { JOURNEY_ROUTES, JourneyProgress, JourneyRoute, journeyForId, journeyProgress, unlockedJourneySiteIds } from '../domain/JourneyRoutes';
import { JourneyBadge } from './JourneyBadge';
import { siteIllustration } from './SiteRow';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';
import { HarmonyEffects } from '../platform/HarmonyEffects';

@Component
export struct CultureAtlas {
  @Link snapshot: ArchiveSnapshot;
  @Prop @Watch('syncJourney') journeyId: string = '';
  onOpen: (site: HeritageSite) => void = () => {};
  @State selectedId: string = 'ly-erlitou';
  @State comparisonId: string = 'zz-shang';
  @State comparing: boolean = false;
  @State private materialComparing: boolean = false;
  @State mode: number[] = [0];
  @State topic: string = '';
  @State graphActive: boolean = true;
  @State modeOptions: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [{ text: '五城图谱' }, { text: '我的图谱' }],
    fontColor: T.muted, selectedFontColor: T.accent, backgroundColor: T.soft, selectedBackgroundColor: T.surface
  });
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void { this.syncJourney(); }

  private currentJourney(): JourneyRoute | undefined {
    return journeyForId(this.journeyId);
  }

  private completedJourneys(): JourneyRoute[] {
    return JOURNEY_ROUTES.filter((route: JourneyRoute) => journeyProgress(this.snapshot.records, route).unlocked);
  }

  private activeJourneyProgress(): JourneyProgress {
    return journeyProgress(this.snapshot.records, this.currentJourney() || JOURNEY_ROUTES[0]);
  }

  private syncJourney(): void {
    const route = this.currentJourney();
    if (!route) return;
    this.selectedId = journeyProgress(this.snapshot.records, route).nextSiteId || route.siteIds[0];
    this.comparing = false;
  }

  private chooseJourney(id: string): void {
    this.journeyId = id; this.syncJourney();
  }

  private openJourneyNext(progress: JourneyProgress): void {
    const site = HERITAGE_SITES.find((item: HeritageSite) => item.id === (progress.nextSiteId || progress.route.siteIds[0]));
    if (site) this.onOpen(site);
  }

  private sites(): HeritageSite[] {
    const route = this.currentJourney();
    if (route) {
      // 路线覆盖五城/个人模式的显示范围，退出后仍恢复原模式与专题；不改写个人档案。
      const sites: HeritageSite[] = [];
      route.siteIds.forEach((id: string) => {
        const site = HERITAGE_SITES.find((item: HeritageSite) => item.id === id);
        if (site) sites.push(site);
      });
      return sites;
    }
    return this.mode[0] === 1 ? personalCultureSites(HERITAGE_SITES, this.snapshot.records, this.topic) : HERITAGE_SITES;
  }

  private selected(): HeritageSite {
    const sites = this.sites();
    return sites.find((site: HeritageSite) => site.id === this.selectedId) || sites[0] || HERITAGE_SITES[1];
  }

  private peer(): HeritageSite {
    return HERITAGE_SITES.find((site: HeritageSite) => site.id === this.comparisonId) || HERITAGE_SITES[2];
  }

  private notes(): ArchiveRecord[] {
    return activeRecords(this.snapshot.records, 'note').filter((note: ArchiveRecord) => note.siteId === this.selected().id);
  }

  private visibleJourneys(): JourneyRoute[] {
    const route = this.currentJourney();
    return route ? [route] : this.completedJourneys();
  }

  private journeyPairReason(leftId: string, rightId: string): string {
    const route = this.visibleJourneys().find((item: JourneyRoute) => {
      const left = item.siteIds.indexOf(leftId); const right = item.siteIds.indexOf(rightId);
      return left >= 0 && right >= 0 && Math.abs(left - right) === 1;
    });
    return route ? `主题阅读路线：${route.title} · 非历史证据` : '';
  }

  private connections(): CultureConnection[] {
    const selected = this.selected();
    const connections = cultureConnections(this.sites(), selected.id, this.snapshot.records);
    // 有文化属性关联时仍展示原依据；主题路线补充相邻阅读节点，不虚构传承或因果。
    this.sites().forEach((site: HeritageSite) => {
      const reason = this.journeyPairReason(selected.id, site.id);
      if (!reason) return;
      const existing = connections.find((connection: CultureConnection) => connection.site.id === site.id);
      if (existing) existing.reasons.push(reason);
      else connections.push({ site, reasons: [reason] });
    });
    return connections;
  }

  private comparisonReasons(): string[] {
    const reasons = connectionReasons(this.selected(), this.peer(), this.snapshot.records);
    const routeReason = this.journeyPairReason(this.selected().id, this.peer().id);
    if (routeReason) reasons.push(routeReason);
    return reasons;
  }

  private isMaterialPair(leftId: string, rightId: string): boolean {
    return (leftId === MATERIAL_COMPARISON.leftSiteId && rightId === MATERIAL_COMPARISON.rightSiteId) ||
      (leftId === MATERIAL_COMPARISON.rightSiteId && rightId === MATERIAL_COMPARISON.leftSiteId);
  }

  private openComparison(site: HeritageSite): void {
    this.comparisonId = site.id; this.materialComparing = this.isMaterialPair(this.selected().id, site.id);
    this.comparing = true;
  }

  private openMaterialComparison(): void {
    // 直达入口不改图谱筛选或选中档案，个人模式没有收藏其中一件时也不会被 selected() 的回退替换对象。
    this.materialComparing = true; this.comparing = true;
  }

  private openComparisonSite(siteId: string): void {
    const site = HERITAGE_SITES.find((item: HeritageSite) => item.id === siteId);
    if (!site) return;
    this.comparing = false; this.materialComparing = false; this.onOpen(site);
  }

  private graphPayload(): string {
    const sites = this.sites();
    const records = mergeRecords([], this.snapshot.records).records;
    const graph = cultureGraphData(sites, this.selected().id, records);
    const currentRoute = this.currentJourney();
    const highlightedIds = currentRoute ? currentRoute.siteIds : unlockedJourneySiteIds(records);
    const edges: CulturalEngineEdge[] = [];
    // 先按路线的 siteIds 顺序建立主题边，再补原有文化属性边。相同端点只绘制一次，
    // routeId 与 highlighted 都是展示条件，不能写成独立完成记录或历史关系。
    this.visibleJourneys().forEach((route: JourneyRoute) => {
      for (let index = 1; index < route.siteIds.length; index++) {
        const source = route.siteIds[index - 1]; const target = route.siteIds[index];
        if (!sites.some((site: HeritageSite) => site.id === source) || !sites.some((site: HeritageSite) => site.id === target)) continue;
        if (!edges.some((edge: CulturalEngineEdge) => (edge.source === source && edge.target === target) ||
          (edge.source === target && edge.target === source))) edges.push({ source, target, highlighted: true });
      }
    });
    graph.edges.forEach((edge: CultureGraphEdge) => {
      if (!edges.some((item: CulturalEngineEdge) => (item.source === edge.source && item.target === edge.target) ||
        (item.source === edge.target && item.target === edge.source))) edges.push({ source: edge.source, target: edge.target });
    });
    const payload: CulturalEnginePayload = { version: 1, selectedId: graph.selectedId,
      nodes: graph.nodes.map((node: CultureGraphNode): CulturalEngineNode => ({ id: node.id, label: node.label, city: node.city, era: node.era,
        type: sites.find((site: HeritageSite) => site.id === node.id)?.type || '', accent: node.accent,
        explored: decodeExplorationProgress(records, node.id).percent >= 75 ||
          records.some((record: ArchiveRecord) => record.siteId === node.id && isMemoryPostcard(record)),
        highlighted: highlightedIds.includes(node.id) })), edges };
    return JSON.stringify(payload);
  }

  @Builder
  materialComparisonEntry() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        Column({ space: 6 }) {
          Text('双连壶与方鼎对照').fontSize(F.card).fontWeight(FontWeight.Bold).fontColor(T.ink)
          Text('三项差异 · 逐项证据').fontSize(F.caption).fontColor(T.muted).lineHeight(20)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        SymbolGlyph($r('sys.symbol.arrow_left_arrow_right')).fontSize(22).fontColor([T.accent])
      }.width('100%').padding(15)
    }.width('100%').padding(0).backgroundColor(T.surface).borderRadius(16)
      .border({ width: 1, color: T.line, radius: 16 }).id('culture-material-comparison-open')
      .accessibilityText('打开大河村彩陶双连壶与杜岭二号方鼎的三项事实对照')
      .onClick(() => this.openMaterialComparison())
  }

  @Builder
  journeyHeader(progress: JourneyProgress) {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Column({ space: 7 }) {
          Text(progress.unlocked ? '主题漫游 · 已集齐' : '主题漫游 · 进行中').fontSize(F.caption).fontColor(T.accent)
          Text(progress.route.title).fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink)
          Text(progress.route.subtitle).fontSize(F.small).fontColor(T.muted).lineHeight(21)
          Text(`${progress.completedCount} / ${progress.total} 处点亮`).fontSize(F.small).fontWeight(FontWeight.Bold)
            .fontColor(progress.route.color).id('culture-journey-progress')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        JourneyBadge({ title: progress.route.title, stamp: progress.route.stamp, unlocked: progress.unlocked })
      }.width('100%')
      Progress({ value: progress.percent, total: 100, type: ProgressType.Linear }).width('100%').color(progress.route.color)
      Text(progress.route.siteIds.map((id: string) => HERITAGE_SITES.find((site: HeritageSite) => site.id === id)?.name || id).join(' → '))
        .fontSize(F.caption).fontColor(T.muted).lineHeight(21).width('100%').id('culture-journey-order')
      Text('路线只表示阅读编排，不是历史先后或交通线。')
        .fontSize(F.caption).fontColor(T.muted).lineHeight(21).width('100%')
      if (progress.route.id === 'earth-and-fire') {
        this.materialComparisonEntry()
      }
      Row({ space: 10 }) {
        Button(progress.unlocked ? '重读起点' : '继续下一处', { type: ButtonType.Normal }).fontSize(F.small).height(42)
          .layoutWeight(1).backgroundColor(T.accent).fontColor(T.onAccent).borderRadius(T.buttonRadius)
          .id('culture-journey-continue').onClick(() => this.openJourneyNext(progress))
        Button('退出路线筛选', { type: ButtonType.Normal }).fontSize(F.small).height(42)
          .backgroundColor(T.soft).fontColor(T.ink).borderRadius(T.buttonRadius).padding({ left: 12, right: 12 })
          .id('culture-journey-exit').onClick(() => { this.journeyId = ''; this.comparing = false; })
      }.width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor(T.surface)
      .borderRadius(T.cardRadius).id('culture-journey-header')
  }

  @Builder
  journeyChoices() {
    Column({ space: 12 }) {
      if (this.currentJourney()) {
        this.journeyHeader(this.activeJourneyProgress())
      } else {
        Row() {
          Text('主题漫游').fontSize(F.card).fontWeight(FontWeight.Bold).fontColor(T.ink).layoutWeight(1)
          Text(`已解锁漫游 ${this.completedJourneys().length}`).fontSize(F.caption).fontColor(T.accent)
            .id('culture-journey-unlocked-count')
        }.width('100%')
        if (this.completedJourneys().length > 0) {
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(this.completedJourneys(), (route: JourneyRoute) => {
              Button({ type: ButtonType.Normal }) {
                JourneyBadge({ title: route.title, stamp: route.stamp, unlocked: true })
              }.padding(4).margin({ right: 5, bottom: 4 }).backgroundColor(T.surface).borderRadius(16)
                .id(`culture-journey-badge-${route.id}`).onClick(() => this.chooseJourney(route.id))
            }, (route: JourneyRoute) => route.id)
          }.width('100%')
        }
      }
      Select(JOURNEY_ROUTES.map((route: JourneyRoute): SelectOption => ({ value: route.title })))
        .value(this.currentJourney()?.title || '选择一条主题阅读路线').font({ size: F.small }).fontColor(T.ink)
        .backgroundColor(T.surface).width('100%').id('culture-journey-select')
        .onSelect((index: number) => { this.chooseJourney(JOURNEY_ROUTES[index].id); })
    }.width('100%').alignItems(HorizontalAlign.Start).id('culture-journey-controls')
  }

  @Builder
  compareColumn(site: HeritageSite, prefix: string) {
    Column({ space: 12 }) {
      Image(siteIllustration(site)).width('100%').height(100).objectFit(ImageFit.Contain)
        .accessibilityText('原创文化插画')
      Text(site.name).fontSize(F.card).fontWeight(FontWeight.Bold).fontColor(T.ink).id(`${prefix}-name`)
      Text(`${site.city} · ${site.era}`).fontSize(F.caption).fontColor(T.accent)
      Text(site.type).fontSize(F.small).fontColor(T.muted)
      Text(site.summary).fontSize(F.small).lineHeight(24).fontColor(T.ink)
      Text(site.tags.join(' · ')).fontSize(F.caption).fontColor(T.muted)
    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
  }

  @Builder
  comparison() {
    if (this.materialComparing) {
      MaterialComparisonPanel({
        onClose: () => { this.comparing = false; this.materialComparing = false; },
        onOpenSite: (siteId: string) => this.openComparisonSite(siteId)
      })
    } else {
      this.genericComparison()
    }
  }

  @Builder
  genericComparison() {
    Scroll() {
      Column({ space: 20 }) {
        Row() {
          Text('档案对照').fontSize(F.title).fontWeight(FontWeight.Bold).fontColor(T.ink).layoutWeight(1)
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.xmark')).fontSize(18).fontColor([T.ink])
          }.width(44).height(44).backgroundColor(T.soft).onClick(() => { this.comparing = false; })
            .accessibilityText('关闭对照').id('culture-comparison-close')
        }.width('100%')
        Row({ space: 20 }) {
          this.compareColumn(this.selected(), 'compare-left')
          this.compareColumn(this.peer(), 'compare-right')
        }.width('100%').alignItems(VerticalAlign.Top)
        Divider().color(T.line)
        Column({ space: 12 }) {
          Text('共同线索').fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink)
          ForEach(this.comparisonReasons(), (reason: string) => {
            Row({ space: 10 }) {
              SymbolGlyph($r('sys.symbol.link')).fontSize(16).fontColor([T.accent])
              Text(reason).fontSize(F.body).fontColor(T.ink).layoutWeight(1)
            }.width('100%')
          }, (reason: string) => reason)
        }.width('100%').alignItems(HorizontalAlign.Start).id('culture-common-reasons')
        Text('资料关联来自档案年代、类型与标签；路线只表示编排。')
          .fontSize(F.caption).fontColor(T.muted).lineHeight(20)
      }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 28 })
    }.width('100%').height('100%').align(Alignment.Top).id('culture-comparison-scroll')
  }

  build() {
    NavDestination() {
      Scroll(this.scroller) {
        Column({ space: 16 }) {
          Column({ space: 6 }) {
            Text('一条河，许多种相遇').fontSize(F.display).fontWeight(FontWeight.Bold).fontColor(T.ink)
            Text(`${this.sites().length} 处档案 · ${this.connections().length} 条阅读线索`)
              .fontSize(F.small).fontColor(T.muted).id('culture-atlas-count')
          }.width('100%').alignItems(HorizontalAlign.Start)
          if (!this.currentJourney() && this.mode[0] === 0) {
            this.materialComparisonEntry()
          }
          this.journeyChoices()
          if (!this.currentJourney()) {
            SegmentButton({ options: this.modeOptions, selectedIndexes: $mode, enableStateAnimation: !this.snapshot.reducedMotion })
              .width('100%').id('culture-atlas-mode')
            if (this.mode[0] === 1 && cultureTopics(this.snapshot.records).length > 0) {
              Select(['全部专题'].concat(cultureTopics(this.snapshot.records)).map((value: string): SelectOption => ({ value })))
                .value(this.topic || '全部专题').font({ size: F.small }).fontColor(T.ink).backgroundColor(T.surface)
                .onSelect((_index: number, value: string) => { this.topic = value === '全部专题' ? '' : value; })
                .id('culture-topic-filter')
            }
          }
          if (this.sites().length === 0) {
            Column({ space: 14 }) {
              SymbolGlyph($r('sys.symbol.bookmark')).fontSize(38).fontColor([T.accent])
              Text(this.topic ? '此专题暂无档案' : '尚无收藏与笔记').fontSize(F.card).fontColor(T.muted)
            }.width('100%').height(240).justifyContent(FlexAlign.Center)
          } else {
            CulturalEngineViewport({ sceneType: 'constellation_graph', payloadJson: this.graphPayload(), viewportHeight: 440,
              reducedMotion: this.snapshot.reducedMotion, active: this.graphActive && !this.comparing,
              onNodeSelected: (id: string, type: string) => {
                if (type === 'site' && this.sites().some(site => site.id === id)) this.selectedId = id;
              } })
            Text('金色粗线与外圈：当前主题路线或已解锁漫游。实心金点：探索达 75% 或有效手账；玫瑰路线点：待探索。')
              .fontSize(F.caption).fontColor(T.muted).lineHeight(20).width('100%')
            Select(this.sites().map((site: HeritageSite): SelectOption => ({ value: site.name }))).value(this.selected().name)
              .font({ size: F.small }).fontColor(T.ink).backgroundColor(T.surface).width('100%').id('culture-site-index')
              .onSelect((index: number) => { this.selectedId = this.sites()[index].id; })
            Row({ space: 12 }) {
              Column({ space: 6 }) {
                Text(this.selected().name).fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink).id('culture-selected-name')
                Text(`${this.selected().city} · ${this.selected().era} · ${this.selected().type}`)
                  .fontSize(F.caption).fontColor(T.muted)
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Button({ type: ButtonType.Circle }) {
                SymbolGlyph($r('sys.symbol.arrow_right')).fontSize(20).fontColor([T.onAccent])
              }.width(48).height(48).backgroundColor(T.accent).onClick(() => this.onOpen(this.selected()))
                .id('culture-open-site').accessibilityText(`打开${this.selected().name}档案`)
            }.width('100%')
            ForEach(this.connections(), (connection: CultureConnection) => {
              Button({ type: ButtonType.Normal }) {
                Row({ space: 12 }) {
                  Image(siteIllustration(connection.site)).width(48).height(48).objectFit(ImageFit.Contain).borderRadius(8)
                  Column({ space: 6 }) {
                    Text(connection.site.name).fontSize(F.card).fontWeight(FontWeight.Medium).fontColor(T.ink)
                    Text(connection.reasons.join(' · ')).fontSize(F.caption).fontColor(T.muted).lineHeight(20)
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                  SymbolGlyph($r('sys.symbol.arrow_left_arrow_right')).fontSize(18).fontColor([T.accent])
                }.width('100%').padding(14)
              }.width('100%').padding(0).backgroundColor(T.surface).borderRadius(T.cardRadius)
                .id(`culture-compare-${connection.site.id}`).accessibilityText(`与${connection.site.name}对照`)
                .onClick(() => this.openComparison(connection.site))
            }, (connection: CultureConnection) => `${this.selected().id}:${connection.site.id}:${connection.reasons.join('|')}`)
            if (this.notes().length > 0) {
              Text('我的观察').fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink).width('100%')
              ForEach(this.notes(), (note: ArchiveRecord) => {
                Column({ space: 8 }) {
                  Text(note.body).fontSize(F.body).lineHeight(24).maxLines(4).fontColor(T.ink)
                  Text(note.tags.join(' · ')).fontSize(F.caption).fontColor(T.accent)
                }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor(T.surface)
                  .borderRadius(T.cardRadius).id(`culture-note-${note.id}`)
              }, (note: ArchiveRecord) => `${note.id}:${note.updatedAt}`)
            }
          }
          Text('关联示意').fontSize(F.caption).fontColor(T.muted).padding({ top: 8, bottom: 12 })
        }.width('100%').constraintSize({ maxWidth: 760 }).padding({ left: 16, right: 16, top: 16, bottom: 24 })
      }.width('100%').height('100%').align(Alignment.Top).id('culture-atlas-scroll')
    }.title('文明连线', { systemMaterial: HarmonyEffects.material(this.snapshot.lightEnabled, this.snapshot.reducedMotion) })
      .backgroundColor(T.canvas)
      .onShown(() => { this.graphActive = true; })
      .onWillHide(() => { this.graphActive = false; })
      .bindSheet($$this.comparing, this.comparison(), {
        height: SheetSize.LARGE, showClose: false, dragBar: true, backgroundColor: T.canvas
      })
  }
}
