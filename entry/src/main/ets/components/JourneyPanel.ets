import { ArchiveRecord, HeritageSite } from '../domain/ArchiveDomain';
import { JOURNEY_ROUTES, JourneyProgress, JourneyRoute, journeyProgress } from '../domain/JourneyRoutes';
import { HERITAGE_SITES } from '../data/HeritageCatalog';
import { JourneyBadge } from './JourneyBadge';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';

@Component
export struct JourneyPanel {
  @Prop records: ArchiveRecord[] = [];
  @Prop compact: boolean = false;
  onOpenSite: (siteId: string) => void = () => {};
  onOpenGraph: (routeId: string) => void = () => {};

  private site(siteId: string): HeritageSite | undefined {
    return HERITAGE_SITES.find((item: HeritageSite) => item.id === siteId);
  }

  private siteName(siteId: string): string {
    return this.site(siteId)?.name || siteId;
  }

  private siteCaption(siteId: string): string {
    const site = this.site(siteId);
    return site ? `${site.city} · ${site.era}` : '离线文化档案';
  }

  private actionTitle(progress: JourneyProgress): string {
    if (progress.unlocked) return '再走一遍漫游';
    return progress.completedCount === 0 ? '开启这条漫游' : '继续探索';
  }

  private openNext(progress: JourneyProgress): void {
    if (progress.unlocked) this.onOpenSite(progress.route.siteIds[0]);
    else if (progress.nextSiteId) this.onOpenSite(progress.nextSiteId);
  }

  @Builder
  routeNode(progress: JourneyProgress, siteId: string, index: number) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 11 }) {
        Text(progress.completedSiteIds.includes(siteId) ? '✓' : `${index + 1}`)
          .fontSize(F.caption).fontWeight(FontWeight.Bold).width(27).height(27).textAlign(TextAlign.Center)
          .fontColor(progress.completedSiteIds.includes(siteId) ? T.onAccent : T.muted)
          .backgroundColor(progress.completedSiteIds.includes(siteId) ? progress.route.color : T.sunken)
          .borderRadius(10)
        Column({ space: 3 }) {
          Text(this.siteName(siteId)).fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.ink)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (!this.compact) { Text(this.siteCaption(siteId)).fontSize(F.caption).fontColor(T.muted) }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (progress.completedSiteIds.includes(siteId)) {
          Text('已点亮').fontSize(F.caption).fontColor(progress.route.color)
        } else {
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(11).fontColor([T.tertiary])
        }
      }.width('100%').padding({ left: 10, right: 10, top: this.compact ? 9 : 10, bottom: this.compact ? 9 : 10 })
    }.width('100%').padding(0).borderRadius(12)
      .backgroundColor(progress.completedSiteIds.includes(siteId) ? T.accentSoft : T.soft)
      .id(`journey-node-${progress.route.id}-${siteId}`).onClick(() => this.onOpenSite(siteId))
      .accessibilityText(`${index + 1}，${this.siteName(siteId)}，${progress.completedSiteIds.includes(siteId) ? '已点亮' : '待探索'}，打开文化档案`)
  }

  @Builder
  routeCard(progress: JourneyProgress) {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Column({ space: 8 }) {
          Row({ space: 6 }) {
            Text('主题路线').fontSize(F.caption).fontColor(progress.route.color)
            Text(`${progress.total} 处线索`).fontSize(F.caption).fontColor(T.muted)
          }
          Text(progress.route.title).fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink)
          Text(progress.route.subtitle).fontSize(F.small).fontColor(T.muted).lineHeight(21)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (!this.compact) {
          JourneyBadge({ title: progress.route.title, stamp: progress.route.stamp, unlocked: progress.unlocked })
        } else {
          Text(progress.route.stamp).fontSize(24).fontWeight(FontWeight.Bold).fontColor(progress.route.color)
            .width(50).height(56).textAlign(TextAlign.Center).backgroundColor(T.accentSoft).borderRadius(17)
        }
      }.width('100%').alignItems(VerticalAlign.Center)
      if (!this.compact) {
        Text(progress.route.caption).width('100%').fontSize(F.caption).fontColor(T.muted).lineHeight(21)
      }
      Column({ space: 8 }) {
        Row() {
          Text(progress.unlocked ? '整条路线已点亮' : '我的探索进度').fontSize(F.caption)
            .fontColor(progress.unlocked ? progress.route.color : T.muted).layoutWeight(1)
          Text(`${progress.completedCount} / ${progress.total}`).fontSize(F.small).fontWeight(FontWeight.Bold)
            .fontColor(progress.route.color).id(`journey-progress-${progress.route.id}`)
        }.width('100%')
        Progress({ value: progress.percent, total: 100, type: ProgressType.Linear }).width('100%')
          .color(progress.route.color).backgroundColor(T.sunken).style({ strokeWidth: 5 })
      }.width('100%')
      Column({ space: 6 }) {
        ForEach(progress.route.siteIds, (siteId: string, index: number) => {
          this.routeNode(progress, siteId, index)
        }, (siteId: string) => `${progress.route.id}:${siteId}`)
      }.width('100%')
      if (!progress.unlocked) {
        Text(`下一处 · ${this.siteName(progress.nextSiteId)}`).fontSize(F.caption).fontColor(T.muted)
          .width('100%').id(`journey-next-${progress.route.id}`)
      }
      Row({ space: 10 }) {
        Button(this.actionTitle(progress), { type: ButtonType.Normal }).fontSize(F.small).height(44)
          .layoutWeight(1).borderRadius(T.buttonRadius).backgroundColor(progress.route.color).fontColor(T.onAccent)
          .padding({ left: 10, right: 10 }).id(`journey-continue-${progress.route.id}`)
          .onClick(() => this.openNext(progress))
        Button('查看图谱', { type: ButtonType.Normal }).fontSize(F.small).height(44)
          .borderRadius(T.buttonRadius).backgroundColor(T.soft).fontColor(T.ink).padding({ left: 15, right: 15 })
          .id(`journey-graph-${progress.route.id}`).onClick(() => this.onOpenGraph(progress.route.id))
      }.width('100%')
    }.width('100%').padding(this.compact ? 15 : 18).backgroundColor(T.surface)
      .borderRadius(T.cardRadius).border({ width: 1, color: T.line }).alignItems(HorizontalAlign.Start)
      .id(`journey-route-${progress.route.id}`)
  }

  build() {
    Column({ space: 16 }) {
      Row({ space: 10 }) {
        Column({ space: 5 }) {
          Text('主题漫游').fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink)
          Text('把分散的文化线索，走成自己的记忆。').fontSize(F.caption).fontColor(T.muted).lineHeight(20)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text('3 条路线').fontSize(F.caption).fontColor(T.accent).padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(T.accentSoft).borderRadius(10)
      }.width('100%')
      ForEach(JOURNEY_ROUTES, (route: JourneyRoute) => {
        this.routeCard(journeyProgress(this.records, route))
      }, (route: JourneyRoute) => route.id)
      Column({ space: 6 }) {
        Text('探索达 75%，或留下一张有效拾遗手账，即可点亮一处。整条点亮后，纪念章随真实记录收入记忆。')
          .fontSize(F.caption).fontColor(T.muted).lineHeight(21)
        Text('路线只表示阅读编排，不是历史先后或交通线。')
          .fontSize(F.caption).fontColor(T.tertiary).lineHeight(21)
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 2, right: 2, bottom: 4 })
    }.width('100%').alignItems(HorizontalAlign.Start).id('journey-panel')
  }
}
