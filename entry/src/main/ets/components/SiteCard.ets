import { HeritageSite } from '../domain/ArchiveDomain';
import { HERITAGE_SITES } from '../data/HeritageCatalog';
import { SiteRow, siteIllustration } from './SiteRow';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';

// 双列目录与收藏共用同一张卡片。图形只是原创主题示意，保留可见标识；
// 不更改条目 ID、收藏记录或内容审核状态，视觉改版无需数据迁移。
@Component
export struct SiteCard {
  @Prop site: HeritageSite = HERITAGE_SITES[0];
  @Prop collected: boolean = false;
  @Prop visited: boolean = false;
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
              Text(this.site.era).fontSize(F.caption).fontColor(T.mintInk).maxLines(1)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor(T.surface).borderRadius(7)
              if (this.visited) {
                // 已读与收藏是两个维度：书签在右上，已读紧邻年代，避免用同一图标表达两件事。
                Text('已读').fontSize(F.caption).fontColor(T.mintInk).maxLines(1)
                  .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                  .backgroundColor(T.mint).borderRadius(6)
                  .margin({ left: 6 })
              }
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
      .accessibilityText(`${this.site.name}，${this.site.city}，${this.site.era}${this.visited ? '，已读' : ''}，查看档案`)
      .id(`site-row-${this.site.id}`).onClick(() => this.onOpen(this.site))
  }
}

@Component
export struct SiteGrid {
  @Prop sites: HeritageSite[] = [];
  @Prop collectedIds: string[] = [];
  @Prop visitedIds: string[] = [];
  @Prop gridId: string = 'site-grid';
  onOpen: (site: HeritageSite) => void = () => {};

  build() {
    Column({ space: 8 }) {
      // 目录与收藏统一走单列列表：双列海报卡在 1256px 手机上每张只有约 200dp 宽，
      // 标题、摘要、年代挤成三行居中块，读起来像网页长图册，不像手机列表。
      // 这里仍保留 archive-library-grid / archive-site-grid 容器 id 与
      // site-row-<id> 行 id，设备用例的定位路径不变。
      ForEach(this.sites, (site: HeritageSite) => {
        SiteRow({ site: site, collected: this.collectedIds.includes(site.id),
          visited: this.visitedIds.includes(site.id), onOpen: this.onOpen })
      }, (site: HeritageSite) => `${site.id}:${this.collectedIds.includes(site.id)}:${this.visitedIds.includes(site.id)}`)
    }.width('100%').id(this.gridId)
  }
}
