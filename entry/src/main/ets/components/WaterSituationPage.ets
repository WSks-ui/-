import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';
import { WATER_SITUATION } from '../data/WaterSituationCatalog';
import {
  latestSnapshot, sourceFor, snapshotsForStation, WaterSnapshot, WaterSource, WaterStation
} from '../domain/WaterSituation';

// 黄河水情观察 v1：只展示带来源、带日期的公开报道摘录。
// 页面不请求实时接口，也不把三条报道画成连续七日趋势；缺测显示“未给出”。
const MAX_CHART_FLOW = 2040;
interface GlossaryItem {
  term: string;
  body: string;
}

const GLOSSARY: GlossaryItem[] = [
  { term: '水位', body: '相对某一基面的读数。不同站、不同基面不能直接比较，也不能用一条水位线判断全河。' },
  { term: '流量', body: '单位时间内通过断面的水量，单位立方米每秒（m³/s）。同一断面不同时刻的流量才可以比较涨落。' },
  { term: '含沙量', body: '单位体积水中的泥沙质量，单位千克每立方米（kg/m³）。本次三条公开报道都没有给出含沙量。' }
];

@Component
export struct WaterSituationPage {
  private snapshots(): WaterSnapshot[] {
    return snapshotsForStation(WATER_SITUATION, 'huayuankou');
  }

  private latest(): WaterSnapshot | undefined {
    return latestSnapshot(WATER_SITUATION, 'huayuankou');
  }

  private station(): WaterStation | undefined {
    return WATER_SITUATION.stations.find((item: WaterStation) => item.id === 'huayuankou');
  }

  private sourceName(sourceId: string): string {
    return sourceFor(WATER_SITUATION, sourceId)?.publisher || '来源待核对';
  }

  private levelText(value: number | undefined): string {
    return value === undefined ? '未给出' : `${value} m`;
  }

  private flowText(value: number | undefined): string {
    return value === undefined ? '未给出' : `${value} m³/s`;
  }

  private barHeight(value: number | undefined): number {
    if (value === undefined || value <= 0) return 4;
    return Math.max(12, Math.round(112 * value / MAX_CHART_FLOW));
  }

  @Builder
  sectionTitle(title: string, subtitle: string) {
    Column({ space: 3 }) {
      Text(title).fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink).width('100%')
      Text(subtitle).fontSize(F.caption).fontColor(T.muted).lineHeight(19).width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 18 }) {
          // 首屏：对象、最新公开报道、非实时边界。
          Column({ space: 12 }) {
            Row({ space: 8 }) {
              Text('公开报道摘录').fontSize(F.caption).fontColor(T.mintInk)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 }).backgroundColor(T.mint).borderRadius(7)
              Text('非实时').fontSize(F.caption).fontColor(T.yellowInk)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 }).backgroundColor(T.yellow).borderRadius(7)
              Blank()
              Text(`整理于 ${WATER_SITUATION.updatedAt}`).fontSize(F.caption).fontColor(T.muted)
            }.width('100%')
            Text(this.station()?.name || '花园口').fontSize(34).fontWeight(FontWeight.Bold).fontColor(T.ink)
              .width('100%')
            Text(`${this.station()?.river || '黄河'} · ${this.station()?.section || '下游'}`)
              .fontSize(F.small).fontColor(T.muted).width('100%')
            Row({ space: 12 }) {
              Column({ space: 3 }) {
                Text('水位').fontSize(F.caption).fontColor(T.muted)
                Text(this.levelText(this.latest()?.waterLevelM)).fontSize(26).fontWeight(FontWeight.Bold)
                  .fontColor(T.mintInk).id('water-latest-level')
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Column({ space: 3 }) {
                Text('流量').fontSize(F.caption).fontColor(T.muted)
                Text(this.flowText(this.latest()?.flowM3s)).fontSize(26).fontWeight(FontWeight.Bold)
                  .fontColor(T.mintInk).id('water-latest-flow')
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            }.width('100%')
            Text(`${this.latest()?.observedAt || ''} · ${this.sourceName(this.latest()?.sourceId || '')}`)
              .fontSize(F.caption).fontColor(T.tertiary).width('100%')
          }.width('100%').alignItems(HorizontalAlign.Start).padding(18).backgroundColor(T.soft)
            .borderRadius(20).border({ width: 1, color: T.line, radius: 20 }).id('water-page')

          // 为什么选花园口：三条事实均来自央广网报道，页面明确来源。
          Column({ space: 10 }) {
            this.sectionTitle('为什么先看花园口', '黄河下游的悬河断面，也是防洪与水文报汛的关键站。')
            ForEach(this.station()?.why || [], (item: string, index: number) => {
              Row({ space: 9 }) {
                Text(`0${index + 1}`).fontSize(F.caption).fontWeight(FontWeight.Medium).fontColor(T.accent).width(22)
                Text(item).fontSize(F.small).fontColor(T.ink).lineHeight(22).layoutWeight(1)
              }.width('100%').alignItems(VerticalAlign.Top)
            }, (item: string) => item)
            Text(`据 ${this.sourceName(this.station()?.whySourceId || '')} 2026-08-13 报道`)
              .fontSize(F.caption).fontColor(T.tertiary).width('100%')
          }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor(T.surface)
            .borderRadius(18).border({ width: 1, color: T.line, radius: 18 })

          // 三条报道：每条都有日期、来源和口径说明，不插值。
          Column({ space: 10 }) {
            this.sectionTitle('三次公开报道', '间隔不均，不是连续逐日序列；缺测值保持“未给出”。')
            ForEach(this.snapshots(), (snapshot: WaterSnapshot, index: number) => {
              Column({ space: 8 }) {
                Row({ space: 8 }) {
                  Text(snapshot.observedAt).fontSize(F.caption).fontWeight(FontWeight.Medium).fontColor(T.ink)
                  Blank()
                  Text(this.sourceName(snapshot.sourceId)).fontSize(F.caption).fontColor(T.mintInk)
                }.width('100%')
                Row({ space: 10 }) {
                  Text(`水位 ${this.levelText(snapshot.waterLevelM)}`).fontSize(F.small).fontColor(T.ink)
                  Text(`流量 ${this.flowText(snapshot.flowM3s)}`).fontSize(F.small).fontColor(T.ink)
                }.width('100%')
                Text(snapshot.note).fontSize(F.caption).fontColor(T.muted).lineHeight(19).width('100%')
              }.width('100%').alignItems(HorizontalAlign.Start).padding(13).backgroundColor(T.surface)
                .borderRadius(14).border({ width: 1, color: T.line, radius: 14 })
                .id(`water-snapshot-${index}`)
            }, (snapshot: WaterSnapshot) => snapshot.observedAt)
          }.width('100%').alignItems(HorizontalAlign.Start)

          // 只比较三次报道的流量；柱高按 2040 m³/s 归一，最大值用玫瑰色标出。
          Column({ space: 10 }) {
            this.sectionTitle('流量对照', '同一断面、三次报道；柱高只用于相对比较，不代表连续趋势。')
            Row({ space: 8 }) {
              ForEach(this.snapshots(), (snapshot: WaterSnapshot) => {
                Column({ space: 5 }) {
                  Text(this.flowText(snapshot.flowM3s)).fontSize(F.caption).fontColor(T.muted).maxLines(1)
                  Row().width('100%').height(this.barHeight(snapshot.flowM3s))
                    .backgroundColor(snapshot.flowM3s === MAX_CHART_FLOW ? T.accent : T.mintInk)
                    .borderRadius(6)
                  Text(snapshot.observedAt.slice(5, 10)).fontSize(F.caption).fontColor(T.muted)
                }.layoutWeight(1).height(158).justifyContent(FlexAlign.End).alignItems(HorizontalAlign.Center)
              }, (snapshot: WaterSnapshot) => snapshot.observedAt)
            }.width('100%').alignItems(VerticalAlign.Bottom).id('water-chart')
            Text('8 月 14 日为黄委通报的该轮洪水最大流量；同日水位未在通报中给出。')
              .fontSize(F.caption).fontColor(T.tertiary).lineHeight(18).width('100%')
          }.width('100%').alignItems(HorizontalAlign.Start).padding(14).backgroundColor(T.soft)
            .borderRadius(16)

          Column({ space: 10 }) {
            this.sectionTitle('读水情', '先把三个词分清，再看数字。')
            ForEach(GLOSSARY, (item: GlossaryItem) => {
              Row({ space: 10 }) {
                Text(item.term).fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.mintInk).width(52)
                Text(item.body).fontSize(F.small).fontColor(T.ink).lineHeight(22).layoutWeight(1)
              }.width('100%').alignItems(VerticalAlign.Top)
            }, (item: GlossaryItem) => item.term)
          }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor(T.surface)
            .borderRadius(18).border({ width: 1, color: T.line, radius: 18 })

          Column({ space: 10 }) {
            this.sectionTitle('来源', '每条数值都能回到原发布；复制链接可核对原文。')
            ForEach(WATER_SITUATION.sources, (source: WaterSource, index: number) => {
              Column({ space: 4 }) {
                Text(`${source.publisher} · ${source.publishedAt}`).fontSize(F.caption).fontColor(T.mintInk)
                Text(source.title).fontSize(F.small).fontColor(T.ink).lineHeight(21).width('100%')
                Text(source.url).fontSize(F.caption).fontColor(T.tertiary).maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis }).copyOption(CopyOptions.LocalDevice)
                  .width('100%')
              }.width('100%').alignItems(HorizontalAlign.Start).id(`water-source-${index}`)
            }, (source: WaterSource) => source.id)
          }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor(T.surface)
            .borderRadius(18).border({ width: 1, color: T.line, radius: 18 })

          Text(WATER_SITUATION.disclaimer).fontSize(F.caption).fontColor(T.muted).lineHeight(20)
            .width('100%').padding(14).backgroundColor(T.yellow).borderRadius(14).id('water-disclaimer')
          Text(WATER_SITUATION.readingNote).fontSize(F.caption).fontColor(T.muted).lineHeight(19)
            .width('100%').padding({ left: 2, right: 2 })
        }.width('100%').constraintSize({ maxWidth: 720 }).padding({ left: 16, right: 16, top: 12, bottom: 36 })
          .alignItems(HorizontalAlign.Start)
      }.width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Auto).id('water-scroll')
    }
    .title('黄河水情观察')
    .backgroundColor(T.canvas)
  }
}
