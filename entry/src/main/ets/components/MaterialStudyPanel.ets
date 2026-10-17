import {
  MaterialEvidenceSource, MaterialStudy, MaterialStudyFact, MATERIAL_STUDIES
} from '../data/MaterialStudyCatalog';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';

// 此面板只显示已单独核验的三处内容，其他档案继续沿用原详情。
// 原创图是解释文字事实的示意；不将它替换成照片，也不让局部核验覆盖整个档案的初稿状态。
@Component
export struct MaterialStudyPanel {
  @Prop study: MaterialStudy = MATERIAL_STUDIES[0];
  @State private sourcesOpen: boolean = false;

  private illustration(): Resource {
    if (this.study.illustration === 'study_dahecun_twin.svg') return $r('app.media.study_dahecun_twin');
    if (this.study.illustration === 'study_duling_pattern.svg') return $r('app.media.study_duling_pattern');
    return $r('app.media.study_miaodigou_space');
  }

  private sourceNumbers(fact: MaterialStudyFact): string {
    return fact.sourceIds.map((id: string) => `〔${this.study.sources.findIndex((source: MaterialEvidenceSource) => source.id === id) + 1}〕`).join('');
  }

  build() {
    Column({ space: 14 }) {
      Row() {
        Text('泥火成器 · 细节阅读').fontSize(F.caption).fontColor(T.accent).layoutWeight(1)
        Text('原创分析图').fontSize(F.caption).fontColor(T.mintInk)
          .padding({ left: 8, right: 8, top: 5, bottom: 5 }).backgroundColor(T.mint).borderRadius(8)
      }.width('100%')
      Text(this.study.question).fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink)
        .lineHeight(30).width('100%').id('material-study-question')
      Image(this.illustration()).width('100%').aspectRatio(5 / 3).objectFit(ImageFit.Contain)
        .borderRadius(14).accessibilityText(this.study.visualCaption).id('material-study-visual')
      Text(this.study.visualCaption).fontSize(F.caption).fontColor(T.muted).lineHeight(20).width('100%')
        .id('material-study-caption')
      Column({ space: 5 }) {
        ForEach(this.study.visualLegend, (line: string) => {
          Text(line).fontSize(F.caption).fontColor(T.muted).lineHeight(20).width('100%')
        })
      }.width('100%').alignItems(HorizontalAlign.Start)
      Text(this.study.discovery).fontSize(F.body).fontColor(T.ink).fontWeight(FontWeight.Medium)
        .lineHeight(26).width('100%').padding(12).backgroundColor(T.accentSoft).borderRadius(12)
        .id('material-study-discovery')
      ForEach(this.study.facts, (fact: MaterialStudyFact, index: number) => {
        Column({ space: 7 }) {
          Text(`${index + 1}  ${fact.title}`).fontSize(F.small).fontWeight(FontWeight.Bold).fontColor(T.ink).width('100%')
          Text(fact.body).fontSize(F.small).fontColor(T.muted).lineHeight(24).width('100%')
            .id(`material-fact-${fact.id}`)
          Text(`资料依据 ${this.sourceNumbers(fact)}`).fontSize(F.caption).fontColor(T.accent).width('100%')
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 7, bottom: 7 })
      }, (fact: MaterialStudyFact) => fact.id)
      Text(this.study.evidenceLimit).fontSize(F.caption).fontColor(T.muted).lineHeight(21).width('100%')
      Button(this.sourcesOpen ? '收起资料依据' : '查看事实的资料依据', { type: ButtonType.Normal })
        .id('material-study-sources-toggle').fontSize(F.small).fontColor(T.accent).height(42).width('100%')
        .backgroundColor(T.accentSoft).borderRadius(12).onClick(() => { this.sourcesOpen = !this.sourcesOpen; })
      if (this.sourcesOpen) {
        Column({ space: 14 }) {
          Text('下列三条事实已核对官方正文；完整档案仍为初稿待校审。')
            .fontSize(F.caption).fontColor(T.muted).lineHeight(21).width('100%')
          ForEach(this.study.sources, (source: MaterialEvidenceSource, index: number) => {
            Column({ space: 5 }) {
              Text(`〔${index + 1}〕${source.publisher} · ${source.title}`)
                .fontSize(F.caption).fontWeight(FontWeight.Medium).fontColor(T.ink).width('100%')
                .id(`material-source-${source.id}`)
              Text(`发布：${source.publishedAt} · 核对：${source.checkedAt}`)
                .fontSize(F.caption).fontColor(T.muted).width('100%')
              Text(source.url).fontSize(F.caption).fontColor(T.muted).width('100%')
                .copyOption(CopyOptions.LocalDevice)
            }.width('100%').alignItems(HorizontalAlign.Start)
          }, (source: MaterialEvidenceSource) => source.id)
        }.width('100%').alignItems(HorizontalAlign.Start).padding(12).backgroundColor(T.soft).borderRadius(12)
          .id('material-study-sources')
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor(T.surface)
      .borderRadius(T.cardRadius).margin({ top: 12, bottom: 16 }).id(`material-study-${this.study.siteId}`)
  }
}
