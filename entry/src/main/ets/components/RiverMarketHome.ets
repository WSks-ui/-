import type { ArchiveRecord } from '../domain/ArchiveDomain';
import { createRiverMarket, marketSummary, RiverMarketState } from '../domain/RiverMarket';
import { riverMarketFromRecords, riverMarketIsUnreadable } from '../domain/RiverMarketRecords';
import { RiverMarketScene } from './RiverMarketScene';

@Component
export struct RiverMarketHome {
  @Prop records: ArchiveRecord[] = [];
  @Prop topClearance: number = 76;
  @Prop bottomClearance: number = 104;
  @Prop reducedMotion: boolean = false;
  scroller: Scroller = new Scroller();
  onOpen: () => void = () => {};
  onLegacyPaper: () => void = () => {};
  onLibrary: () => void = () => {};
  @State private containerWidth: number = 360;

  private state(): RiverMarketState { return riverMarketFromRecords(this.records) || createRiverMarket(0); }
  private hasSaved(): boolean { return riverMarketFromRecords(this.records) !== undefined; }
  private damaged(): boolean { return riverMarketIsUnreadable(this.records); }
  private wide(): boolean { return this.containerWidth >= 820; }
  private heroHeight(): number { return this.wide() ? 430 : Math.max(215, Math.min(248, this.containerWidth * 0.66)); }
  private actionWord(): string {
    if (this.damaged()) return '查看这座夜市的存档';
    if (!this.hasSaved()) return '今晚开市';
    return this.state().round >= 4 ? '看看收市账本，再开一夜' : '回到我的夜市';
  }

  @Builder
  heading() {
    Column({ space: 6 }) {
      Text('开封  /  经营小样').fontSize(11).fontColor('#C6A976').letterSpacing(2)
      Text('汴京开市').fontSize(this.wide() ? 43 : 35).fontWeight(FontWeight.Medium)
        .fontColor('#F2E6C9').letterSpacing(5).width('100%')
      Text('一条河，六处铺。让这一夜的人都吃上。').fontSize(13).lineHeight(22).fontColor('#B5C4B4').width('100%')
      if (this.hasSaved()) {
        Text(`余钱 ${this.state().cash}  ·  已接待 ${this.state().served} 客  ·  ${this.state().round}/4 段`)
          .fontSize(12).fontColor('#D8C99D').width('100%').id('market-home-saved')
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  panorama() {
    RiverMarketScene({ state: this.state(), interactive: false, active: false, reducedMotion: this.reducedMotion })
      .width('100%').height(this.heroHeight()).borderRadius(9).clip(true).id('market-home-panorama')
  }

  @Builder
  opening() {
    Column({ space: 8 }) {
      Text(this.damaged() ? '原存档暂不可读，先查看与备份；不会用新夜市覆盖。' : this.hasSaved() ?
        this.state().round >= 4 ? marketSummary(this.state()).detail : '铺子和伙计都在，接着安排下一段。' :
        '水饭、肉食两铺已备好，六名伙计，六十游戏钱起家。第一段可以马上开始。')
        .fontSize(11).lineHeight(19).fontColor('#A9BCAE').width('100%')
      Button({ type: ButtonType.Normal }) {
        Row() {
          Text(this.actionWord()).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#192F32').layoutWeight(1)
          Text('→').fontSize(23).fontColor('#192F32')
        }.width('100%')
      }.width('100%').height(52).padding({ left: 18, right: 18 }).backgroundColor('#E4B676')
        .borderRadius(5).id('market-home-open').onClick(() => this.onOpen())
      Text('四段共一百客 · 每段两趟补货 · 留住客人，也要留住本钱')
        .fontSize(10).fontColor('#7F9C92').lineHeight(18).width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 0 }) {
        if (this.wide()) {
          Row({ space: 32 }) {
            Column({ space: 26 }) { this.heading(); this.opening() }.layoutWeight(0.85)
            Column() { this.panorama() }.layoutWeight(1.35)
          }.width('100%').alignItems(VerticalAlign.Center)
        } else {
          this.heading()
          Column() { this.panorama() }.width('100%').margin({ top: 10, bottom: 10 })
          this.opening()
        }
        Row({ space: 23 }) {
          Button('读文化档案  ↗', { type: ButtonType.Normal }).height(36).fontSize(12)
            .fontColor('#D3D2B5').backgroundColor(Color.Transparent).padding(0)
            .id('market-home-library').onClick(() => this.onLibrary())
          Button('以前的纸景  ↗', { type: ButtonType.Normal }).height(36).fontSize(12)
            .fontColor('#8AA59A').backgroundColor(Color.Transparent).padding(0)
            .id('market-home-paper').onClick(() => this.onLegacyPaper())
        }.width('100%').margin({ top: 9 })
      }.width('100%').constraintSize({ maxWidth: 1260 }).alignItems(HorizontalAlign.Start)
        .padding({ left: this.wide() ? 36 : 22, right: this.wide() ? 36 : 22,
          top: this.topClearance + 12, bottom: this.bottomClearance + 12 })
    }.width('100%').height('100%').backgroundColor('#0B2028').align(Alignment.Top)
      .scrollBar(BarState.Off).id('river-market-home')
      .onAreaChange((_old: Area, area: Area) => { this.containerWidth = Number(area.width); })
  }
}
