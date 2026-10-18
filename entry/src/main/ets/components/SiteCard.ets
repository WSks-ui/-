import { HeritageSite } from '../domain/ArchiveDomain';
import { HERITAGE_SITES } from '../data/HeritageCatalog';
import { siteIllustration } from './SiteRow';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';

// 双列目录与收藏共用同一张卡片。图形只是原创主题示意，保留可见标识；
// 不更改条目 ID、收藏记录或内容审核状态，视觉改版无需数据迁移。
@Component
export struct SiteCard {
  @Prop site: HeritageSite = HERITAGE_SITES[0];
  @Prop collected: boolean = false;
  onOpen: (site: HeritageSite) => void = () => {};

  build() {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 9 }) {
        Stack() {
          Image(siteIllustration(this.site)).width('100%').height('100%')
            .objectFit(ImageFit.Cover).borderRadius(12)
            .accessibilityText('原创文化主题插画')
          Column() {
            Row() {
              Text(this.site.era).fontSize(F.caption).fontColor(T.mintInk)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor(T.surface).borderRadius(7)
              Blank()
              if (this.collected) {
                SymbolGlyph($r('sys.symbol.bookmark')).fontSize(18).fontColor([T.accent])
              }
            }.width('100%')
          }.width('100%').height('100%').padding(8).hitTestBehavior(HitTestMode.None)
        }.width('100%').aspectRatio(1.18)
        Column({ space: 4 }) {
          Text(this.site.name).fontSize(F.card).fontWeight(FontWeight.Bold).fontColor(T.ink)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${this.site.city} · ${this.site.type}`).fontSize(F.caption).fontColor(T.muted).maxLines(1)
          Text(this.site.summary).fontSize(F.caption).fontColor(T.muted).lineHeight(18)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 2, right: 2, bottom: 2 })
      }.width('100%').padding(10).alignItems(HorizontalAlign.Start)
    }.width('100%').padding(0).borderRadius(T.cardRadius).backgroundColor(T.surface)
      .border({ width: 1, color: T.line, radius: T.cardRadius })
      .stateStyles({ pressed: { .opacity(0.72) } })
      .accessibilityText(`${this.site.name}，${this.site.city}，${this.site.era}，查看档案`)
      .id(`site-row-${this.site.id}`).onClick(() => this.onOpen(this.site))
  }
}

@Component
export struct SiteGrid {
  @Prop sites: HeritageSite[] = [];
  @Prop collectedIds: string[] = [];
  @Prop gridId: string = 'site-grid';
  onOpen: (site: HeritageSite) => void = () => {};

  build() {
    Column() {
      // 使用可观察的组件属性承接筛选结果。@Builder 的数组值会被 ForEach 闭包捕获，
      // 复用首条 ID 时可能留下旧配对；行 key 同时包含两个条目，右列变化必须重建。
      // 外层 Scroll 内用自然高度行，避免嵌套滚动和写死卡片总高度。
      ForEach(this.sites.filter((_site: HeritageSite, index: number) => index % 2 === 0), (site: HeritageSite, pair: number) => {
        Row({ space: 12 }) {
          Column() {
            SiteCard({ site, collected: this.collectedIds.includes(site.id), onOpen: this.onOpen })
          }.layoutWeight(1)
          Column() {
            if (this.sites[pair * 2 + 1]) {
              SiteCard({ site: this.sites[pair * 2 + 1],
                collected: this.collectedIds.includes(this.sites[pair * 2 + 1].id), onOpen: this.onOpen })
            }
          }.layoutWeight(1)
        }.width('100%').alignItems(VerticalAlign.Top).margin({ bottom: 12 })
      }, (site: HeritageSite, pair: number) => `${site.id}:${this.sites[pair * 2 + 1]?.id || 'empty'}`)
    }.width('100%').id(this.gridId)
  }
}
