import { HeritageSite } from '../domain/ArchiveDomain';
import { HERITAGE_SITES } from '../data/HeritageCatalog';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';

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
  onOpen: (site: HeritageSite) => void = () => {};

  build() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 14 }) {
        Image(siteIllustration(this.site))
          .width(80).height(88).objectFit(ImageFit.Cover).borderRadius(12)
          .accessibilityText('原创文化主题插画')
        Column({ space: 6 }) {
          Text(`${this.site.city} · ${this.site.era}`)
            .fontSize(F.caption).fontColor(T.muted)
          Text(this.site.name).fontSize(F.card).fontWeight(FontWeight.Bold)
            .fontColor(T.ink).maxLines(2)
          Text(this.reason || this.site.summary).fontSize(F.caption).fontColor(T.muted)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).lineHeight(20)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([T.tertiary])
      }.width('100%').padding(12)
    }
    .width('100%').padding(0).backgroundColor(T.surface).borderRadius(T.cardRadius).margin({ bottom: 12 })
    .stateStyles({ pressed: { .opacity(0.7) } })
    .accessibilityText(`${this.site.name}，${this.site.city}，${this.site.era}，查看档案`).id(`site-row-${this.site.id}`)
    .onClick(() => this.onOpen(this.site))
  }
}
