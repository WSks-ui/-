import {
  MATERIAL_COMPARISON, MaterialComparisonDimension, MaterialEvidenceSource, MaterialStudy, materialStudyForId
} from '../data/MaterialStudyCatalog';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';

// 固定比较两个已逐项核对的对象。维度正文、来源和推断边界只读取同一份内容数据，
// 不借用“同城 / 同标签”生成历史结论，也不将一号鼎或大河村其他彩陶替入本页。
@Component
export struct MaterialComparisonPanel {
  onClose: () => void = () => {};
  onOpenSite: (siteId: string) => void = () => {};
  @State private selectedDimensionId: string = MATERIAL_COMPARISON.dimensions[0].id;
  @State private leftSourcesOpen: boolean = false;
  @State private rightSourcesOpen: boolean = false;
  private scroller: Scroller = new Scroller();

  private dimension(): MaterialComparisonDimension {
    return MATERIAL_COMPARISON.dimensions.find((item: MaterialComparisonDimension) => item.id === this.selectedDimensionId) ||
      MATERIAL_COMPARISON.dimensions[0];
  }

  private dimensionLabel(id: string): string {
    if (id === 'body') return '口腹结构';
    if (id === 'surface') return '纹饰位置';
    return '出土记录';
  }

  private chooseDimension(id: string): void {
    this.selectedDimensionId = id; this.leftSourcesOpen = false; this.rightSourcesOpen = false;
    this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
  }

  private siteId(side: string): string {
    return side === 'left' ? MATERIAL_COMPARISON.leftSiteId : MATERIAL_COMPARISON.rightSiteId;
  }

  private objectName(side: string): string {
    return side === 'left' ? MATERIAL_COMPARISON.leftObject : MATERIAL_COMPARISON.rightObject;
  }

  private sources(side: string): MaterialEvidenceSource[] {
    const study = materialStudyForId(this.siteId(side));
    const sourceIds = side === 'left' ? this.dimension().leftSourceIds : this.dimension().rightSourceIds;
    return study ? study.sources.filter((source: MaterialEvidenceSource) => sourceIds.includes(source.id)) : [];
  }

  private sourcesOpen(side: string): boolean {
    return side === 'left' ? this.leftSourcesOpen : this.rightSourcesOpen;
  }

  private toggleSources(side: string): void {
    if (side === 'left') this.leftSourcesOpen = !this.leftSourcesOpen;
    else this.rightSourcesOpen = !this.rightSourcesOpen;
  }

  private sourceNames(side: string): string {
    return this.sources(side).map((source: MaterialEvidenceSource) => `${source.publisher}《${source.title}》`).join('；');
  }

  private studies(): MaterialStudy[] {
    const studies: MaterialStudy[] = [];
    [MATERIAL_COMPARISON.leftSiteId, MATERIAL_COMPARISON.rightSiteId].forEach((id: string) => {
      const study = materialStudyForId(id);
      if (study) studies.push(study);
    });
    return studies;
  }

  private studySide(study: MaterialStudy): string {
    return study.siteId === MATERIAL_COMPARISON.leftSiteId ? 'left' : 'right';
  }

  private illustration(study: MaterialStudy): Resource {
    return study.siteId === MATERIAL_COMPARISON.leftSiteId ?
      $r('app.media.study_dahecun_twin') : $r('app.media.study_duling_pattern');
  }

  @Builder
  evidence(side: string) {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(side === 'left' ? '01' : '02').fontSize(F.caption).fontWeight(FontWeight.Bold)
          .fontColor(side === 'left' ? T.accent : T.mintInk)
          .padding({ left: 7, right: 7, top: 4, bottom: 4 })
          .backgroundColor(side === 'left' ? T.accentSoft : T.mint).borderRadius(7)
        Text(this.objectName(side)).fontSize(F.card).fontWeight(FontWeight.Bold).fontColor(T.ink).layoutWeight(1)
      }.width('100%')
      Text(side === 'left' ? this.dimension().left : this.dimension().right)
        .fontSize(F.body).fontColor(T.ink).lineHeight(26).width('100%')
        .id(`material-comparison-fact-${side}-${this.dimension().id}`)
      Text(`依据：${this.sourceNames(side)}`).fontSize(F.caption).fontColor(T.muted).lineHeight(20).width('100%')
      Button(this.sourcesOpen(side) ? '收起本项依据' : `查看本项依据 · ${this.sources(side).length} 条`, { type: ButtonType.Normal })
        .height(36).padding({ left: 10, right: 10 }).fontSize(F.caption).fontColor(T.accent)
        .backgroundColor(T.accentSoft).borderRadius(10).id(`material-comparison-sources-${side}`)
        .onClick(() => this.toggleSources(side))
      if (this.sourcesOpen(side)) {
        Column({ space: 12 }) {
          ForEach(this.sources(side), (source: MaterialEvidenceSource) => {
            Column({ space: 5 }) {
              Text(`${source.publisher} · ${source.title}`).fontSize(F.caption).fontWeight(FontWeight.Medium)
                .fontColor(T.ink).width('100%').id(`material-comparison-source-${side}-${source.id}`)
              Text(`发布：${source.publishedAt} · 核对：${source.checkedAt}`)
                .fontSize(F.caption).fontColor(T.muted).lineHeight(20).width('100%')
              Text(source.url).fontSize(F.caption).fontColor(T.muted).lineHeight(19).width('100%')
                .copyOption(CopyOptions.LocalDevice)
            }.width('100%').alignItems(HorizontalAlign.Start)
          }, (source: MaterialEvidenceSource) => `${this.dimension().id}:${side}:${source.id}`)
        }.width('100%').alignItems(HorizontalAlign.Start).padding(12).backgroundColor(T.soft).borderRadius(12)
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding(15).backgroundColor(T.surface)
      .border({ width: 1, color: T.line, radius: 16 }).borderRadius(16).id(`material-comparison-${side}`)
  }

  @Builder
  visual(study: MaterialStudy) {
    Column({ space: 10 }) {
      Text(this.objectName(this.studySide(study))).fontSize(F.card).fontWeight(FontWeight.Bold).fontColor(T.ink).width('100%')
      // 手机端顺序展示两张完整原图，不并排压缩，也不裁掉方鼎右侧的八组位置关系。
      Image(this.illustration(study)).width('100%').aspectRatio(5 / 3).objectFit(ImageFit.Contain)
        .borderRadius(14).accessibilityText(study.visualCaption)
        .id(`material-comparison-visual-${this.studySide(study)}`)
      Text(study.visualCaption).fontSize(F.caption).fontColor(T.muted).lineHeight(20).width('100%')
      Column({ space: 4 }) {
        ForEach(study.visualLegend, (line: string) => {
          Text(line).fontSize(F.caption).fontColor(T.muted).lineHeight(20).width('100%')
        }, (line: string) => line)
      }.width('100%').alignItems(HorizontalAlign.Start)
      Button(this.studySide(study) === 'left' ? '打开双连壶观察' : '打开方鼎观察', { type: ButtonType.Normal })
        .width('100%').height(42).fontSize(F.small).fontColor(T.mintInk).backgroundColor(T.mint).borderRadius(12)
        .id(`material-comparison-observe-${this.studySide(study)}`)
        .onClick(() => this.onOpenSite(study.siteId))
    }.width('100%').alignItems(HorizontalAlign.Start).padding(15).backgroundColor(T.surface).borderRadius(16)
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Column({ space: 5 }) {
          Text('泥火成器 · 有依据的对照').fontSize(F.caption).fontColor(T.accent)
          Text('双连壶与方鼎').fontSize(F.title).fontWeight(FontWeight.Bold).fontColor(T.ink)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.xmark')).fontSize(18).fontColor([T.ink])
        }.width(42).height(42).backgroundColor(T.soft).id('material-comparison-close')
          .accessibilityText('关闭双连壶与方鼎对照').onClick(() => this.onClose())
      }.width('100%').padding({ left: 18, right: 18, top: 12 })
      Text(MATERIAL_COMPARISON.title).fontSize(F.small).fontColor(T.muted).lineHeight(22).width('100%')
        .padding({ left: 18, right: 18 })
      Row({ space: 7 }) {
        ForEach(MATERIAL_COMPARISON.dimensions, (dimension: MaterialComparisonDimension) => {
          Button(this.dimensionLabel(dimension.id), { type: ButtonType.Normal }).layoutWeight(1).height(40)
            .padding({ left: 4, right: 4 }).fontSize(F.small).fontWeight(FontWeight.Medium)
            .fontColor(this.selectedDimensionId === dimension.id ? T.accent : T.muted)
            .backgroundColor(this.selectedDimensionId === dimension.id ? T.accentSoft : T.soft).borderRadius(12)
            .id(`material-comparison-${dimension.id}`)
            .accessibilityText(`${dimension.title}${this.selectedDimensionId === dimension.id ? '，已选' : '，切换对照'}`)
            .onClick(() => this.chooseDimension(dimension.id))
        }, (dimension: MaterialComparisonDimension) => dimension.id)
      }.width('100%').padding({ left: 18, right: 18 })
      Scroll(this.scroller) {
        Column({ space: 14 }) {
          Text(this.dimension().title).fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink).width('100%')
            .id('material-comparison-dimension-title')
          this.evidence('left')
          this.evidence('right')
          Column({ space: 7 }) {
            Text('不能据此推断什么').fontSize(F.small).fontWeight(FontWeight.Bold).fontColor(T.accent).width('100%')
            Text(this.dimension().limit).fontSize(F.small).fontColor(T.muted).lineHeight(24).width('100%')
              .id(`material-comparison-limit-${this.dimension().id}`)
          }.width('100%').alignItems(HorizontalAlign.Start).padding(15).backgroundColor(T.soft).borderRadius(14)
          Row() {
            Text('回到器物细节').fontSize(F.card).fontWeight(FontWeight.Bold).fontColor(T.ink).layoutWeight(1)
            Text('原创分析图').fontSize(F.caption).fontColor(T.mintInk)
          }.width('100%').margin({ top: 4 })
          ForEach(this.studies(), (study: MaterialStudy) => {
            this.visual(study)
          }, (study: MaterialStudy) => study.siteId)
          Text('本页只比较上述已核对事实；完整档案仍为初稿待校审。图像为云河纪原创学习示意，比例、纹线与位置标记经简化。')
            .fontSize(F.caption).fontColor(T.muted).lineHeight(21).width('100%')
        }.width('100%').constraintSize({ maxWidth: 720 }).alignItems(HorizontalAlign.Start)
          .padding({ left: 18, right: 18, top: 4, bottom: 28 })
      }.width('100%').layoutWeight(1).align(Alignment.Top).id('material-comparison-scroll')
    }.width('100%').height('100%').backgroundColor(T.canvas).id('material-comparison-panel')
  }
}
