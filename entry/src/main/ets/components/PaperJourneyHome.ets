import { ArchiveRecord } from '../domain/ArchiveDomain';
import { PaperWorkV1, createPaperWork } from '../domain/PaperJourney';
import { paperWorkFromRecords } from '../domain/PaperJourneyRecords';
import { PAPER_CITIES, PaperCity } from '../data/PaperJourneyCatalog';
import { PaperJourneyScene } from './PaperJourneyScene';
import { PaperJourneyTheme as P } from './PaperJourneyTheme';

// 首页只让一张纸成为主角：城市切换更换材料关系和原生纸景，不堆五张重复任务卡。
// 首页示意使用玩家真实 mask；无记录时就是尚未动剪的纸，插画不代表已完成作品。
@Component
export struct PaperJourneyHome {
  @Prop records: ArchiveRecord[] = [];
  @Prop reducedMotion: boolean = false;
  @Prop topClearance: number = 112;
  @Prop bottomClearance: number = 104;
  scroller: Scroller = new Scroller();
  onOpen: (cityId: string) => void = () => {};
  onLibrary: () => void = () => {};
  onMemory: () => void = () => {};
  onProfile: () => void = () => {};
  @State private selectedIndex: number = 0;
  @State private contentWidth: number = 360;

  aboutToAppear(): void {
    // 恢复最近真正编辑过的纸；旧漫游/探方进度不能替新作品预填完成状态。
    let latest = 0;
    PAPER_CITIES.forEach((city: PaperCity, index: number) => {
      const work = paperWorkFromRecords(this.records, city.id);
      if (work && work.updatedAt > latest) { latest = work.updatedAt; this.selectedIndex = index; }
    });
  }

  private city(): PaperCity { return PAPER_CITIES[this.selectedIndex] || PAPER_CITIES[0]; }
  private savedWork(): PaperWorkV1 | undefined { return paperWorkFromRecords(this.records, this.city().id); }
  private work(): PaperWorkV1 { return this.savedWork() || createPaperWork(this.city().id, 0); }
  private wide(): boolean { return this.contentWidth >= 820; }
  private heroHeight(): number {
    return this.wide() ? Math.max(420, Math.min(620, this.contentWidth * 0.53)) :
      Math.max(268, Math.min(326, this.contentWidth * 0.86));
  }
  private completed(): number {
    return PAPER_CITIES.filter((city: PaperCity) => {
      const work = paperWorkFromRecords(this.records, city.id); return work !== undefined && work.completedAt > 0;
    }).length;
  }
  private notes(): number { return this.records.filter((record: ArchiveRecord) => !record.deleted && record.kind === 'note').length; }
  private actionWord(): string { return this.savedWork() ? '继续这张纸' : '开始剪这一页'; }
  private status(): string {
    const work = this.savedWork();
    if (!work) return '一张新纸，留给这一城';
    if (work.completedAt > 0) return '空间目标已完成 · 可以继续创作';
    return work.mask.indexOf('0'.repeat(480)) === 0 ? '纸已经展开，等下一剪' : '上一次的剪口，都还在';
  }

  @Builder
  brand() {
    Row({ space: 9 }) {
      Text('纸上生城').fontSize(12).fontColor(P.amber).letterSpacing(2)
      Text('/').fontSize(11).fontColor(P.dim)
      Text('沿黄河的五张纸').fontSize(11).fontColor(P.muted).letterSpacing(0.7)
    }.width('100%').height(20)
  }

  @Builder
  title() {
    Column({ space: this.wide() ? 17 : 7 }) {
      Row({ space: 9 }) {
        Text(`0${this.selectedIndex + 1}`).fontSize(11).fontColor(P.amber).letterSpacing(1)
        Row().width(19).height(1).backgroundColor('#8F805E')
        Text(this.city().city).fontSize(12).fontColor(P.paperSoft).letterSpacing(2)
      }.width('100%')
      Text(this.city().title).fontSize(this.wide() ? 38 : 25).fontWeight(FontWeight.Medium)
        .fontColor(P.paper).lineHeight(this.wide() ? 54 : 35).letterSpacing(this.wide() ? 2 : 1)
        .width('100%').id('paper-home-city-title')
      if (this.wide()) {
        Text(this.city().question).fontSize(17).lineHeight(29).fontColor(P.paperSoft).width('100%')
        Text(this.city().goal).fontSize(14).lineHeight(25).fontColor(P.muted).width('100%')
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  citySelection() {
    Row({ space: this.wide() ? 9 : 3 }) {
      ForEach(PAPER_CITIES, (city: PaperCity, index: number) => {
        Button({ type: ButtonType.Normal }) {
          Column({ space: 7 }) {
            Text(city.city).fontSize(this.wide() ? 13 : 12)
              .fontColor(this.selectedIndex === index ? P.paper : P.muted).letterSpacing(0.7)
            Row().width(this.selectedIndex === index ? 20 : 3).height(2)
              .backgroundColor(this.selectedIndex === index ? P.amber : '#4E6862')
          }.width('100%').height(38).justifyContent(FlexAlign.Center)
        }.layoutWeight(1).height(46).padding(0).backgroundColor(Color.Transparent)
          .id(`paper-home-city-${city.id}`)
          .accessibilityText(`${city.city}，${this.selectedIndex === index ? '当前选择' : '选择纸景'}`)
          .onClick(() => { this.selectedIndex = index; })
      }, (city: PaperCity) => `${city.id}:${this.selectedIndex}`)
    }.width('100%').padding({ left: 7, right: 7 })
      .backgroundColor('rgba(11,29,34,0.92)')
  }

  @Builder
  hero() {
    Stack({ alignContent: Alignment.TopStart }) {
      PaperJourneyScene({ work: this.work(), cityId: this.city().id, interactive: false,
        unfolded: true, reducedMotion: this.reducedMotion, showGuide: false })
        .width('100%').height('100%').hitTestBehavior(HitTestMode.None)
      if (!this.wide()) {
        Text(this.city().subtitle).fontSize(11).fontColor('#C6CAB5').letterSpacing(1.3)
          .width('100%').textAlign(TextAlign.Center).padding({ top: 7 })
          .hitTestBehavior(HitTestMode.None)
      }
      Column() {
        Blank()
        this.citySelection()
      }.width('100%').height('100%').hitTestBehavior(HitTestMode.Transparent)
    }.width('100%').height(this.heroHeight()).clip(true).borderRadius(6)
      .id('paper-home-hero')
  }

  @Builder
  primary() {
    Column({ space: 10 }) {
      if (!this.wide()) {
        Text(this.city().goal).fontSize(12).lineHeight(20).fontColor(P.muted).width('100%')
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      Button({ type: ButtonType.Normal }) {
        Row({ space: 15 }) {
          Text(this.actionWord()).fontSize(16).fontWeight(FontWeight.Medium).fontColor(P.night).layoutWeight(1)
          Text('↗').fontSize(22).fontColor(P.night)
        }.width('100%')
      }.width('100%').height(52).padding({ left: 20, right: 20 })
        .backgroundColor(P.amber).borderRadius(4)
        .id('paper-home-start').onClick(() => this.onOpen(this.city().id))
      if (this.savedWork()) {
        Text(this.status()).fontSize(11).fontColor(P.dim).letterSpacing(0.4).width('100%')
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  archiveEntries() {
    Column({ space: 13 }) {
      Row({ space: 16 }) {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 7 }) {
            Text('读文化档案').fontSize(12).fontColor(P.paperSoft)
            Text('↗').fontSize(13).fontColor(P.dim)
          }
        }.height(32).padding(0).backgroundColor(Color.Transparent).id('paper-home-library')
          .onClick(() => this.onLibrary())
        Row().width(1).height(13).backgroundColor(P.line)
        Button({ type: ButtonType.Normal }) {
          Row({ space: 7 }) {
            Text(this.notes() > 0 ? `我的记忆 · ${this.notes()}页` : '我的记忆').fontSize(12).fontColor(P.paperSoft)
            Text('↗').fontSize(13).fontColor(P.dim)
          }
        }.height(32).padding(0).backgroundColor(Color.Transparent).id('paper-home-memory')
          .onClick(() => this.onMemory())
        Blank()
        if (this.completed() > 0) { Text(`${this.completed()} / 5 城纸景已完成`).fontSize(11).fontColor(P.dim) }
      }.width('100%')
      Text('剪口由你创作 · 从真实文化材料读懂空间与形象').fontSize(10).fontColor(P.dim)
        .lineHeight(17).width('100%').letterSpacing(0.3)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 0 }) {
        this.brand()
        if (this.wide()) {
          Row({ space: 44 }) {
            Column({ space: 24 }) {
              this.title()
              this.primary()
            }.layoutWeight(0.85).alignItems(HorizontalAlign.Start)
            Column() { this.hero() }.layoutWeight(1.2)
          }.width('100%').alignItems(VerticalAlign.Center).margin({ top: 26, bottom: 26 })
        } else {
          Column() { this.title() }.margin({ top: 13, bottom: 8 }).width('100%')
          this.hero()
          Column() { this.primary() }.width('100%').margin({ top: 12, bottom: 16 })
        }
        this.archiveEntries()
      }.width('100%').alignItems(HorizontalAlign.Start)
        .constraintSize({ maxWidth: 1240 })
        .padding({ left: this.wide() ? 40 : 22, right: this.wide() ? 40 : 22,
          top: this.topClearance + (this.wide() ? 20 : 7), bottom: this.bottomClearance + 18 })
    }.width('100%').height('100%').backgroundColor(P.night).scrollBar(BarState.Off)
      .align(Alignment.Top).edgeEffect(EdgeEffect.Spring).id('paper-journey-home')
      .onAreaChange((_old: Area, area: Area) => { this.contentWidth = Number(area.width); })
  }
}
