import { SegmentButton, SegmentButtonOptions } from '@ohos.arkui.advanced.SegmentButton';
import { activeRecords, ArchiveRecord, ArchiveSnapshot, HeritageSite } from '../domain/ArchiveDomain';
import { connectionReasons, cultureConnections, CultureConnection, cultureTopics, personalCultureSites } from '../domain/CultureConnections';
import { HERITAGE_SITES } from '../data/HeritageCatalog';
import { CulturalEngineViewport } from './CulturalEngineViewport';
import { CulturalEnginePayload, CulturalEngineNode, CulturalEngineEdge } from '../domain/CulturalEngineContract';
import { cultureGraphData, CultureGraphNode, CultureGraphEdge } from '../domain/CultureGraphData';
import { decodeExplorationProgress } from '../domain/ExplorationProgress';
import { siteIllustration } from './SiteRow';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';
import { HarmonyEffects } from '../platform/HarmonyEffects';

@Component
export struct CultureAtlas {
  @Link snapshot: ArchiveSnapshot;
  onOpen: (site: HeritageSite) => void = () => {};
  @State selectedId: string = 'ly-erlitou';
  @State comparisonId: string = 'zz-shang';
  @State comparing: boolean = false;
  @State mode: number[] = [0];
  @State topic: string = '';
  @State graphActive: boolean = true;
  @State modeOptions: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [{ text: '五城图谱' }, { text: '我的图谱' }],
    fontColor: T.muted, selectedFontColor: T.accent, backgroundColor: T.soft, selectedBackgroundColor: T.surface
  });
  private scroller: Scroller = new Scroller();

  private sites(): HeritageSite[] {
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

  private graphPayload(): string {
    const graph = cultureGraphData(this.sites(), this.selected().id, this.snapshot.records);
    const payload: CulturalEnginePayload = { version: 1, selectedId: graph.selectedId,
      nodes: graph.nodes.map((node: CultureGraphNode): CulturalEngineNode => ({ id: node.id, label: node.label, city: node.city, era: node.era,
        type: this.sites().find(site => site.id === node.id)?.type || '', accent: node.accent,
        explored: decodeExplorationProgress(this.snapshot.records, node.id).percent >= 75 ||
          this.snapshot.records.some(record => record.kind === 'note' && !record.deleted && record.siteId === node.id) })),
      edges: graph.edges.map((edge: CultureGraphEdge): CulturalEngineEdge => ({ source: edge.source, target: edge.target })) };
    return JSON.stringify(payload);
  }

  @Builder
  compareColumn(site: HeritageSite, prefix: string) {
    Column({ space: 12 }) {
      Image(siteIllustration(site)).width('100%').height(100).objectFit(ImageFit.Contain)
        .accessibilityText('文化主题示意图')
      Text(site.name).fontSize(F.card).fontWeight(FontWeight.Bold).fontColor(T.ink).id(`${prefix}-name`)
      Text(`${site.city} · ${site.era}`).fontSize(F.caption).fontColor(T.accent)
      Text(site.type).fontSize(F.small).fontColor(T.muted)
      Text(site.summary).fontSize(F.small).lineHeight(24).fontColor(T.ink)
      Text(site.tags.join(' · ')).fontSize(F.caption).fontColor(T.muted)
    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
  }

  @Builder
  comparison() {
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
          ForEach(connectionReasons(this.selected(), this.peer(), this.snapshot.records), (reason: string) => {
            Row({ space: 10 }) {
              SymbolGlyph($r('sys.symbol.link')).fontSize(16).fontColor([T.accent])
              Text(reason).fontSize(F.body).fontColor(T.ink).layoutWeight(1)
            }.width('100%')
          }, (reason: string) => reason)
        }.width('100%').alignItems(HorizontalAlign.Start).id('culture-common-reasons')
        Text('关联依据为档案年代、类型及标签；文化内容初稿待校审。').fontSize(F.caption).fontColor(T.muted).lineHeight(20)
      }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 28 })
    }.width('100%').height('100%').align(Alignment.Top).id('culture-comparison-scroll')
  }

  build() {
    NavDestination() {
      Scroll(this.scroller) {
        Column({ space: 16 }) {
          Column({ space: 6 }) {
            Text('一条河，许多种相遇').fontSize(F.display).fontWeight(FontWeight.Bold).fontColor(T.ink)
            Text(`${this.sites().length} 处档案 · ${cultureConnections(this.sites(), this.selected().id, this.snapshot.records).length} 条关联线索`)
              .fontSize(F.small).fontColor(T.muted).id('culture-atlas-count')
          }.width('100%').alignItems(HorizontalAlign.Start)
          SegmentButton({ options: this.modeOptions, selectedIndexes: $mode, enableStateAnimation: !this.snapshot.reducedMotion })
            .width('100%').id('culture-atlas-mode')
          if (this.mode[0] === 1 && cultureTopics(this.snapshot.records).length > 0) {
            Select(['全部专题'].concat(cultureTopics(this.snapshot.records)).map((value: string): SelectOption => ({ value })))
              .value(this.topic || '全部专题').font({ size: F.small }).fontColor(T.ink).backgroundColor(T.surface)
              .onSelect((_index: number, value: string) => { this.topic = value === '全部专题' ? '' : value; })
              .id('culture-topic-filter')
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
            Text('西东五城 × 档案类型 × 年代纵深 · 金色表示已探索或留有笔记')
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
            ForEach(cultureConnections(this.sites(), this.selected().id, this.snapshot.records), (connection: CultureConnection) => {
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
                .onClick(() => { this.comparisonId = connection.site.id; this.comparing = true; })
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
          Text('图形为关联示意 · 文化内容初稿待校审').fontSize(F.caption).fontColor(T.muted).padding({ top: 8, bottom: 12 })
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
