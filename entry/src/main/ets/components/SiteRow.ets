import { HeritageSite } from '../domain/ArchiveDomain';
import { HERITAGE_SITES } from '../data/HeritageCatalog';
import { ArchiveTheme as T } from './ArchiveTheme';

export function siteIllustration(site: HeritageSite): Resource {
  if (site.illustration === 'study_miaodigou_space.svg') return $r('app.media.study_miaodigou_space');
  if (site.illustration === 'study_dahecun_twin.svg') return $r('app.media.study_dahecun_twin');
  if (site.illustration === 'study_duling_pattern.svg') return $r('app.media.study_duling_pattern');
  if (site.illustration === 'motif_pottery.svg') return $r('app.media.motif_pottery');
  if (site.illustration === 'motif_pagoda.svg') return $r('app.media.motif_pagoda');
  return $r('app.media.motif_city');
}

@Component
export struct SiteRow {
  @Prop site: HeritageSite = HERITAGE_SITES[0];
  @Prop reason: string = '';
  // 目录与收藏需要在这行上同时表达「已收藏」和「已读」，两个维度分开显示：
  // 书签只表示收藏，小圆点只表示读过，避免用同一个图标表达两件事。
  @Prop collected: boolean = false;
  @Prop visited: boolean = false;
  onOpen: (site: HeritageSite) => void = () => {};

  build() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        Image(siteIllustration(this.site))
          .width(64).height(64).objectFit(ImageFit.Cover).borderRadius(10)
          .accessibilityText('原创文化主题插画')
        Column({ space: 3 }) {
          Row({ space: 6 }) {
            Text(this.site.name).fontSize(16).fontWeight(FontWeight.Medium).fontColor(T.ink)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
            if (this.collected) {
              SymbolGlyph($r('sys.symbol.bookmark')).fontSize(14).fontColor([T.accent])
            }
          }.width('100%')
          Text(`${this.site.city} · ${this.site.type} · ${this.site.era}`)
            .fontSize(12).fontColor(T.muted).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.reason || this.site.summary).fontSize(12).fontColor(T.tertiary)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Row({ space: 6 }) {
          if (this.visited) {
            Row().width(6).height(6).borderRadius(3).backgroundColor(T.accent)
          }
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([T.tertiary])
        }.alignItems(VerticalAlign.Center)
      }.width('100%').padding({ left: 12, right: 10, top: 12, bottom: 12 })
    }
    .width('100%').padding(0).backgroundColor(T.surface).borderRadius(12)
    .stateStyles({ pressed: { .opacity(0.7) } })
    .accessibilityText(`${this.site.name}，${this.site.city}，${this.site.era}${this.visited ? '，已读' : ''}${this.collected ? '，已收藏' : ''}，查看档案`)
    .id(`site-row-${this.site.id}`)
    .onClick(() => this.onOpen(this.site))
  }
}
