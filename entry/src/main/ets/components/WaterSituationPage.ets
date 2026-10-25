import { common } from '@kit.AbilityKit';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';
import { WATER_SITUATION } from '../data/WaterSituationCatalog';
import {
  latestSnapshot, liveFlowText, liveStation, WaterLiveReply, WaterLiveStation, WaterSnapshot
} from '../domain/WaterSituation';
import { WaterSituationClient } from '../sync/WaterSituationClient';

// 水情页以“河流仪表盘”呈现：深青水面、大数字、三站对照和少量解释。
// 数据优先来自服务端实时接口；失败时使用内置离线值，只显示“离线数据”，
// 不在界面堆来源清单或免责声明。工程侧仍保留数据源与回退说明。
const HERO_TOP = '#0F2F2B';
const HERO_BOTTOM = '#2A6557';
const CREAM = '#F7F0E6';
const CREAM_SOFT = '#B9CDC4';
const MINT_LIGHT = '#A8D5C2';
const CHIP_BG = '#1FFFFFFF';
const LIVE_STATIONS: string[] = ['花园口', '高村', '利津'];

interface StationMeta {
  name: string;
  section: string;
}

const STATION_META: StationMeta[] = [
  { name: '花园口', section: '黄河下游 · 郑州北郊' },
  { name: '高村', section: '黄河下游 · 山东东明' },
  { name: '利津', section: '黄河下游 · 山东利津' }
];

@Component
export struct WaterSituationPage {
  @State private live: WaterLiveReply | undefined = undefined;
  @State private liveState: string = 'loading';
  @State private selected: string = '花园口';

  aboutToAppear(): void {
    this.loadLive();
  }

  private async loadLive(): Promise<void> {
    try {
      const client = new WaterSituationClient(getContext(this) as common.Context);
      if (!(await client.configure())) { this.liveState = 'offline'; return; }
      const reply = await client.fetch();
      this.live = reply;
      this.liveState = reply.stale ? 'cached' : 'live';
      if (!liveStation(reply, this.selected)) this.selected = '花园口';
    } catch {
      // 刷新失败时保留上一次成功值，只把状态改为离线；首次失败才回到内置值。
      this.liveState = 'offline';
      if (!this.live) this.selected = '花园口';
    }
  }

  private latest(): WaterSnapshot | undefined {
    return latestSnapshot(WATER_SITUATION, 'huayuankou');
  }

  private selectedLive(): WaterLiveStation | undefined {
    return liveStation(this.live, this.selected);
  }

  private stationSection(): string {
    return STATION_META.find((item: StationMeta) => item.name === this.selected)?.section || '黄河下游';
  }

  private stationNames(): string[] {
    if (!this.live) return ['花园口'];
    return LIVE_STATIONS.filter((name: string) => Boolean(liveStation(this.live, name)));
  }

  private levelValue(): string {
    const live = this.selectedLive();
    if (live) return live.waterLevelM === null ? '—' : `${live.waterLevelM}`;
    const latest = this.latest();
    return latest?.waterLevelM !== undefined ? `${latest.waterLevelM}` : '—';
  }

  private flowValue(): string {
    const live = this.selectedLive();
    if (live) return live.flowM3s === null ? '—' : `${live.flowM3s}`;
    const latest = this.latest();
    return latest?.flowM3s !== undefined ? `${latest.flowM3s}` : '—';
  }

  private statusText(): string {
    if (this.liveState === 'live') {
      const time = (this.live?.observedAt || '').slice(11);
      return time ? `实时 · ${time}` : '实时';
    }
    if (this.liveState === 'cached') return '上次更新';
    if (this.liveState === 'loading') return '正在更新';
    return '离线数据';
  }

  private statusColor(): string {
    if (this.liveState === 'live') return MINT_LIGHT;
    if (this.liveState === 'cached') return '#E7C978';
    return '#D9C8B8';
  }

  private maxFlow(): number {
    let max = 1;
    LIVE_STATIONS.forEach((name: string) => {
      const flow = liveStation(this.live, name)?.flowM3s ?? 0;
      if (flow > max) max = flow;
    });
    return max;
  }

  private barWidth(name: string): string {
    const flow = liveStation(this.live, name)?.flowM3s ?? 0;
    const percent = flow > 0 ? Math.max(6, Math.round(100 * flow / this.maxFlow())) : 0;
    return `${percent}%`;
  }

  private barValue(name: string): string {
    const station = liveStation(this.live, name);
    if (station) return liveFlowText(station.flowM3s);
    if (name === '花园口') return liveFlowText(this.latest()?.flowM3s);
    return '—';
  }

  private selectStation(name: string): void {
    if (this.live && liveStation(this.live, name)) this.selected = name;
  }

  @Builder
  stationChip(name: string) {
    Button({ type: ButtonType.Normal }) {
      Text(name).fontSize(F.caption)
        .fontColor(this.selected === name ? HERO_TOP : CREAM)
        .fontWeight(this.selected === name ? FontWeight.Medium : FontWeight.Normal)
    }.height(30).padding({ left: 12, right: 12 })
      .backgroundColor(this.selected === name ? CREAM : CHIP_BG)
      .borderRadius(15).id(`water-station-${name}`)
      .accessibilityText(`查看${name}水情`)
      .onClick(() => this.selectStation(name))
  }

  @Builder
  stat(value: string, label: string) {
    Column({ space: 3 }) {
      Text(value).fontSize(20).fontWeight(FontWeight.Bold).fontColor(T.mintInk)
      Text(label).fontSize(F.caption).fontColor(T.muted).maxLines(1)
    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
  }

  @Builder
  glossaryRow(label: string, body: string, color: Resource) {
    Row({ space: 10 }) {
      Row().width(6).height(6).borderRadius(3).backgroundColor(color)
      Text(label).fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.ink).width(52)
      Text(body).fontSize(F.small).fontColor(T.muted).lineHeight(21).layoutWeight(1)
    }.width('100%').alignItems(VerticalAlign.Top)
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          // 水面主卡：深青渐变、低对比波纹、大数字；不放来源或免责声明。
          Stack({ alignContent: Alignment.BottomStart }) {
            Column({ space: 7 }) {
              Row().width('120%').height(12).backgroundColor('#12FFFFFF').borderRadius(20)
              Row().width('140%').height(12).backgroundColor('#0CFFFFFF').borderRadius(20)
            }.width('100%').alignItems(HorizontalAlign.Center).margin({ bottom: -4 })

            Column({ space: 14 }) {
              Row({ space: 8 }) {
                Text('黄河水情').fontSize(F.caption).fontColor(CREAM_SOFT).letterSpacing(1)
                Blank()
                Row({ space: 5 }) {
                  Row().width(6).height(6).borderRadius(3).backgroundColor(this.statusColor())
                  Text(this.statusText()).fontSize(10).fontColor(CREAM_SOFT).id('water-data-status')
                }
                Button({ type: ButtonType.Normal }) {
                  Text('↻').fontSize(15).fontColor(CREAM)
                }.width(28).height(28).backgroundColor(CHIP_BG).borderRadius(14)
                  .accessibilityText('刷新水情').onClick(() => {
                    this.liveState = 'loading';
                    this.loadLive();
                  })
              }.width('100%').alignItems(VerticalAlign.Center)

              Column({ space: 3 }) {
                Text(this.selected).fontSize(34).fontWeight(FontWeight.Bold).fontColor(CREAM)
                Text(this.stationSection()).fontSize(F.caption).fontColor(CREAM_SOFT)
              }.width('100%').alignItems(HorizontalAlign.Start)

              Row({ space: 30 }) {
                Column({ space: 2 }) {
                  Text('水位').fontSize(10).fontColor(CREAM_SOFT)
                  Row({ space: 4 }) {
                    Text(this.levelValue()).fontSize(30).fontWeight(FontWeight.Bold).fontColor(CREAM)
                      .id('water-latest-level')
                    Text('m').fontSize(11).fontColor(CREAM_SOFT)
                  }.alignItems(VerticalAlign.Bottom)
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Column({ space: 2 }) {
                  Text('流量').fontSize(10).fontColor(CREAM_SOFT)
                  Row({ space: 4 }) {
                    Text(this.flowValue()).fontSize(30).fontWeight(FontWeight.Bold).fontColor(MINT_LIGHT)
                      .id('water-latest-flow')
                    Text('m³/s').fontSize(11).fontColor(CREAM_SOFT)
                  }.alignItems(VerticalAlign.Bottom)
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              }.width('100%')

              Row({ space: 8 }) {
                ForEach(this.stationNames(), (name: string) => {
                  this.stationChip(name);
                }, (name: string) => name)
              }.width('100%')
            }.width('100%').padding({ left: 20, right: 20, top: 18, bottom: 20 })
          }.width('100%').borderRadius(26).clip(true)
            .linearGradient({ angle: 135, colors: [[HERO_TOP, 0.0], [HERO_BOTTOM, 1.0]] })
            .id('water-page')

          // 三站流量对照：横向条，选中站高亮；点击可切换上方主卡。
          Column({ space: 12 }) {
            Row({ space: 8 }) {
              Text('三站对照').fontSize(F.card).fontWeight(FontWeight.Bold).fontColor(T.ink)
              Blank()
              Text('流量 · m³/s').fontSize(F.caption).fontColor(T.tertiary)
            }.width('100%')
            ForEach(this.stationNames(), (name: string) => {
              Row({ space: 10 }) {
                Text(name).fontSize(F.caption)
                  .fontColor(this.selected === name ? T.ink : T.muted).width(52)
                Stack({ alignContent: Alignment.Start }) {
                  Row().width('100%').height(7).backgroundColor(T.soft).borderRadius(4)
                  Row().width(this.barWidth(name)).height(7)
                    .backgroundColor(this.selected === name ? T.accent : T.mintInk).borderRadius(4)
                }.layoutWeight(1).height(7)
                Text(this.barValue(name)).fontSize(F.caption)
                  .fontColor(this.selected === name ? T.ink : T.muted).width(72).textAlign(TextAlign.End)
              }.width('100%').height(28).alignItems(VerticalAlign.Center)
                .onClick(() => this.selectStation(name)).id(`water-chart-${name}`)
            }, (name: string) => name)
          }.width('100%').padding(16).backgroundColor(T.surface).borderRadius(18)
            .border({ width: 1, color: T.line, radius: 18 }).id('water-chart')

          // 读图：只解释三个词，不做术语长文。
          Column({ space: 12 }) {
            Text('看懂水情').fontSize(F.card).fontWeight(FontWeight.Bold).fontColor(T.ink).width('100%')
            Text('三个数字，读懂这条河。').fontSize(F.caption).fontColor(T.muted).width('100%')
            this.glossaryRow('水位', '以固定基面为参照，站点之间不宜直接比较。', T.accent)
            this.glossaryRow('流量', '每秒通过断面的水量，是河流的“脉搏”。', T.mintInk)
            this.glossaryRow('含沙量', '本期日报未发布，不以 0 代替。', T.yellow)
          }.width('100%').padding(16).backgroundColor(T.surface).borderRadius(18)
            .border({ width: 1, color: T.line, radius: 18 })

          // 花园口的故事：三个大数字 + 一句解释，替代来源清单。
          Column({ space: 12 }) {
            Text('为什么是花园口').fontSize(F.card).fontWeight(FontWeight.Bold).fontColor(T.ink).width('100%')
            Text('黄河下游的悬河断面，也是防洪与水文报汛的关键站。')
              .fontSize(F.small).fontColor(T.muted).lineHeight(22).width('100%')
            Row({ space: 8 }) {
              this.stat('73万', 'km² 控制流域')
              this.stat('1938', '水文站设立')
              this.stat('悬河', '下游标志断面')
            }.width('100%')
          }.width('100%').padding(16).backgroundColor(T.surface).borderRadius(18)
            .border({ width: 1, color: T.line, radius: 18 }).id('water-story')
        }.width('100%').constraintSize({ maxWidth: 720 })
          .padding({ left: 16, right: 16, top: 12, bottom: 28 }).alignItems(HorizontalAlign.Start)
      }.width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Auto).id('water-scroll')
    }
    .title('黄河水情')
    .backgroundColor(T.canvas)
  }
}
