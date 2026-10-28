import type { ArchiveRecord } from '../domain/ArchiveDomain';
import { createMarketNight, marketNightLayout, marketNightSummary, MarketNightId, RiverMarketV2 } from '../domain/RiverMarketV2';
import { marketNightFromRecords, marketNightIsDeleted, marketNightIsUnreadable, marketNightUnlocked } from '../domain/RiverMarketV2Records';
import { MarketNightScene } from './MarketNightScene';

interface MarketNightHomeEntry { id: MarketNightId; numeral: string; name: string; hint: string; }

// 三夜共用同一条河岸。首页的场景始终取自用户所选夜次，不以装饰人群代替经营进度。
@Component
export struct MarketNightsHome {
  @Prop records: ArchiveRecord[] = [];
  @Prop topClearance: number = 76;
  @Prop bottomClearance: number = 104;
  @Prop reducedMotion: boolean = false;
  scroller: Scroller = new Scroller();
  onOpen: (nightId: string) => void = () => {};
  onLegacyMarket: () => void = () => {};
  onLegacyPaper: () => void = () => {};
  onLibrary: () => void = () => {};
  @State private containerWidth: number = 360;
  @State private selectedNight: MarketNightId = 'night-1';
  private nights: MarketNightHomeEntry[] = [
    { id: 'night-1', numeral: '壹', name: '州桥初市', hint: '先把一夜的生意安排明白' },
    { id: 'night-2', numeral: '贰', name: '夜深归人', hint: '让茶跟着夜归的人走' },
    { id: 'night-3', numeral: '叁', name: '元夜灯市', hint: '在人流与灯火间取舍' }
  ];

  private wide(): boolean { return this.containerWidth >= 820; }
  private saved(id: MarketNightId): RiverMarketV2 | undefined { return marketNightFromRecords(this.records, id); }
  private preview(): RiverMarketV2 {
    const saved = this.saved(this.selectedNight);
    if (saved) return saved;
    const previous = this.selectedNight === 'night-1' ? undefined : this.saved(this.selectedNight === 'night-2' ? 'night-1' : 'night-2');
    return createMarketNight(this.selectedNight, 'balanced', 0, previous ? marketNightLayout(previous) : undefined);
  }
  private unlocked(id: MarketNightId): boolean { return marketNightUnlocked(this.records, id); }
  private nightStatus(id: MarketNightId): string {
    if (marketNightIsDeleted(this.records, id)) return '进度已删除 · 记忆保留';
    if (marketNightIsUnreadable(this.records, id)) return '原存档保留 · 暂不可读';
    const saved = this.saved(id);
    if (!saved) return this.unlocked(id) ? '尚未开市' : '前夜达标后开启';
    if (saved.phase === 'closed') return marketNightSummary(saved).passed ? '已达成今夜目标' : '已收市 · 可重新安排';
    return `第${saved.round + 1}段 · 已迎${saved.batch}/3批 · 接待${saved.served}客`;
  }
  private actionWord(): string {
    if (marketNightIsUnreadable(this.records, this.selectedNight)) return '查看保留的存档';
    if (marketNightIsDeleted(this.records, this.selectedNight)) return '查看这夜，明确重开';
    const saved = this.saved(this.selectedNight);
    return !saved ? '从这一夜开始' : saved.phase === 'closed' ? '回看这一夜的收市账本' : '继续我的这一夜';
  }
  private heroHeight(): number { return this.wide() ? 470 : Math.max(258, Math.min(335, this.containerWidth * 0.8)); }
  private selectedEntry(): MarketNightHomeEntry { return this.nights.find(item => item.id === this.selectedNight) || this.nights[0]; }

  @Builder
  heading() {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Text('云河纪').fontSize(11).fontColor('#B8A77F').letterSpacing(3)
        Text('开封 · 原创经营').fontSize(10).fontColor('#7F9D91').letterSpacing(1)
      }.width('100%')
      Text('开封三夜').fontSize(this.wide() ? 46 : 35).fontWeight(FontWeight.Medium)
        .fontColor('#F3E5C4').letterSpacing(6).width('100%')
      Text('州桥一线，夜夜不同。').fontSize(15).fontColor('#C8C7A4').letterSpacing(2).width('100%')
      Text('布铺、调人、看客流；在这一夜真正需要的时候，出手安排。')
        .fontSize(12).lineHeight(21).fontColor('#94AEA0').width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  panorama() {
    Stack({ alignContent: Alignment.BottomStart }) {
      MarketNightScene({ state: this.preview(), nightId: this.selectedNight, interactive: false,
        active: false, reducedMotion: this.reducedMotion }).width('100%').height('100%')
      Row() {
        Column({ space: 4 }) {
          Text(`${this.selectedEntry().numeral}  /  ${this.selectedEntry().name}`)
            .fontSize(14).fontColor('#E4D1A1').letterSpacing(2)
          Text(this.nightStatus(this.selectedNight)).fontSize(10).fontColor('#9FB7A3').id('tn-home-status')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Text('四段 · 三批').fontSize(10).fontColor('#BFB78E').letterSpacing(1)
      }.width('100%').padding({ left: 15, right: 15, top: 11, bottom: 11 }).backgroundColor('#122E33')
    }.width('100%').height(this.heroHeight()).borderRadius(8).clip(true).id('tn-home-scene')
  }

  @Builder
  nightChoice(entry: MarketNightHomeEntry, index: number) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        Text(entry.numeral).fontSize(22).fontColor(this.selectedNight === entry.id ? '#DDBA7B' : '#728E7F')
          .width(31).textAlign(TextAlign.Center)
        Column({ space: 4 }) {
          Row({ space: 9 }) {
            Text(entry.name).fontSize(15).fontWeight(FontWeight.Medium)
              .fontColor(this.selectedNight === entry.id ? '#EEE0BD' : '#A8B8A4')
            if (!this.unlocked(entry.id)) { Text('待开启').fontSize(9).fontColor('#7F998A') }
          }.width('100%')
          Text(this.saved(entry.id) || marketNightIsDeleted(this.records, entry.id) || marketNightIsUnreadable(this.records, entry.id) ?
            this.nightStatus(entry.id) : entry.hint).fontSize(10).fontColor('#8CA697').width('100%')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Text(this.selectedNight === entry.id ? '●' : '○').fontSize(13).fontColor('#C7AF74')
      }.width('100%')
    }.width('100%').height(68).backgroundColor(this.selectedNight === entry.id ? '#1C3A3C' : Color.Transparent)
      .border({ width: { bottom: 1 }, color: '#2D4845' }).borderRadius(4).padding({ left: 11, right: 12 })
      .enabled(this.unlocked(entry.id)).id(`tn-open-${entry.id}`).onClick(() => {
        this.selectedNight = entry.id; this.onOpen(entry.id);
      })
  }

  @Builder
  opening() {
    Column({ space: 8 }) {
      Button({ type: ButtonType.Normal }) {
        Row() {
          Text(this.actionWord()).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#173332').layoutWeight(1)
          Text('→').fontSize(25).fontColor('#173332')
        }.width('100%')
      }.width('100%').height(51).padding({ left: 18, right: 18 }).backgroundColor('#E1B779')
        .borderRadius(5).id('tn-home-primary').onClick(() => this.onOpen(this.selectedNight))
      Text('夜市为原创玩法，文献在手边；不必答题，也能读懂这一夜。')
        .fontSize(10).lineHeight(18).fontColor('#77978A').width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 0 }) {
        if (this.wide()) {
          Row({ space: 30 }) {
            Column({ space: 24 }) {
              this.heading()
              Column({ space: 0 }) {
                ForEach(this.nights, (entry: MarketNightHomeEntry, index: number) => { this.nightChoice(entry, index) },
                  (entry: MarketNightHomeEntry) => entry.id)
              }.width('100%')
              this.opening()
            }.layoutWeight(0.9).alignItems(HorizontalAlign.Start)
            Column() { this.panorama() }.layoutWeight(1.45)
          }.width('100%').alignItems(VerticalAlign.Center)
        } else {
          this.heading()
          Column() { this.panorama() }.width('100%').margin({ top: 14, bottom: 14 })
          this.opening()
          Column({ space: 0 }) {
            ForEach(this.nights, (entry: MarketNightHomeEntry, index: number) => { this.nightChoice(entry, index) },
              (entry: MarketNightHomeEntry) => entry.id)
          }.width('100%').margin({ top: 15 })
        }
        Row({ space: 20 }) {
          Button('文化档案 ↗', { type: ButtonType.Normal }).height(37).fontSize(11).fontColor('#C9CCAC')
            .backgroundColor(Color.Transparent).padding(0).id('tn-library').onClick(() => this.onLibrary())
          Button('原经营小样 ↗', { type: ButtonType.Normal }).height(37).fontSize(11).fontColor('#7D9C8D')
            .backgroundColor(Color.Transparent).padding(0).id('tn-legacy-market').onClick(() => this.onLegacyMarket())
          Button('以前的纸景 ↗', { type: ButtonType.Normal }).height(37).fontSize(11).fontColor('#7D9C8D')
            .backgroundColor(Color.Transparent).padding(0).id('tn-legacy-paper').onClick(() => this.onLegacyPaper())
        }.width('100%').margin({ top: 12 })
      }.width('100%').constraintSize({ maxWidth: 1320 }).alignItems(HorizontalAlign.Start)
        .padding({ left: this.wide() ? 38 : 21, right: this.wide() ? 38 : 21,
          top: this.topClearance + 12, bottom: this.bottomClearance + 12 })
    }.width('100%').height('100%').backgroundColor('#0B252C').align(Alignment.Top).scrollBar(BarState.Off)
      .id('tn-home').onAreaChange((_old: Area, area: Area) => { this.containerWidth = Number(area.width); })
  }
}
