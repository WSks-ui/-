import type { ArchiveRecord } from '../domain/ArchiveDomain';
import { activeRecords } from '../domain/ArchiveDomain';
import type { AccountView } from '../domain/AccountSync';
import { guestAccountView } from '../domain/AccountSync';
import type { DistributedArchiveStatus } from '../domain/DistributedArchive';
import { initialDistributedStatus } from '../domain/DistributedArchive';
import { PaperJourneyTheme as P } from './PaperJourneyTheme';

// 新“我的”留在统一页签里；账号、恢复与偏好仍进入已有原生功能页处理。
// 这里只派生真实档案和通道状态，不制造设备数、最近同步时间或完成奖励。
@Component
export struct PaperProfileSection {
  @Prop view: AccountView = guestAccountView();
  @Prop nativeView: DistributedArchiveStatus = initialDistributedStatus();
  @Prop records: ArchiveRecord[] = [];
  @Prop topClearance: number = 76;
  @Prop bottomClearance: number = 90;
  onAccount: () => void = () => {};
  onStorage: () => void = () => {};
  onPreferences: () => void = () => {};
  onSources: () => void = () => {};
  onSystems: () => void = () => {};
  onLegacy: () => void = () => {};

  private noteCount(): number { return activeRecords(this.records, 'note').length; }
  private favoriteCount(): number { return activeRecords(this.records, 'favorite').length; }
  private cityCount(): number {
    const ids: string[] = [];
    activeRecords(this.records, 'note').forEach(record => {
      if (record.paperContext && !ids.includes(record.paperContext.cityId)) ids.push(record.paperContext.cityId);
    });
    return ids.length;
  }

  private name(): string { return this.view.signedIn ? this.view.username : '沿河拾光的人'; }
  private journeyLine(): string {
    const cities = this.cityCount();
    return cities > 0 ? `已有 ${cities} 座城，留在自己的纸上。` :
      this.noteCount() > 0 ? '有些风景，已经写进你的记忆。' : '沿河慢行，把一城一刻留给自己。';
  }

  private accountLabel(): string {
    if (!this.view.signedIn) return '登录后，在自己的另一台设备翻开记忆';
    if (!this.view.sessionReady) return '原账号档案可离线阅读，重新登录后继续同步';
    if (this.view.syncing) return '正在与同一账号交换已保存的记录';
    if (this.view.message) return this.view.message;
    if (this.view.pendingCount > 0) return `${this.view.pendingCount} 条已存记录等待网络确认`;
    return this.view.lastSync > 0 ? '已收到账号服务对当前记录的确认' : '会话已恢复，等待首次记录确认';
  }

  private networkState(): string {
    if (!this.view.serviceConfigured) return '尚未配置服务';
    if (!this.view.signedIn) return '尚未登录';
    if (!this.view.sessionReady) return '离线身份';
    if (this.view.syncing) return '交换中';
    if (this.view.message) return '待处理';
    if (this.view.pendingCount > 0) return '等待确认';
    return this.view.lastSync > 0 ? '已确认' : '尚未交换';
  }

  private nativeState(): string {
    const phase = this.nativeView.phase;
    if (phase === 'synced' && this.nativeView.lastSuccessfulSync > 0) return '平台传输完成';
    if (phase === 'syncing') return '平台正在传输';
    if (phase === 'waiting') return '等待可信设备';
    if (phase === 'ready') return '本机通道已就绪';
    if (phase === 'permission') return '等待设备授权';
    if (phase === 'unsupported') return '当前环境不支持';
    if (phase === 'error') return '暂不可用';
    return '尚未启用';
  }

  @Builder
  private portrait() {
    Row({ space: 18 }) {
      Stack() {
        Rect().width(63).height(69).fill(P.paper).rotate({ angle: -5 }).borderRadius(3)
        Column({ space: 1 }) {
          Text('云').fontSize(23).fontWeight(FontWeight.Medium).fontColor(P.ink)
          Text('河').fontSize(23).fontWeight(FontWeight.Medium).fontColor(P.ink)
        }.width(59).height(65).justifyContent(FlexAlign.Center).backgroundColor('#E1B883')
          .borderRadius(3).rotate({ angle: 4 })
      }.width(72).height(78).accessibilityText('云河纪个人纸页标识')
      Column({ space: 8 }) {
        Text(this.name()).fontSize(23).fontWeight(FontWeight.Medium).fontColor(P.paper)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%').id('profile-user-name')
        Text(this.view.signedIn ? '自己的账号 · 自己的沿河记忆' : '未登录 · 记忆先留在本机')
          .fontSize(11).fontColor(P.muted).lineHeight(18)
        Text(this.journeyLine()).fontSize(12).fontColor(P.paperSoft).lineHeight(20)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').alignItems(VerticalAlign.Center).margin({ top: 23, bottom: 28 })
  }

  @Builder
  private personalNumbers() {
    Row({ space: 0 }) {
      Column({ space: 6 }) {
        Row({ space: 7 }) {
          Text(`${this.noteCount()}`).fontSize(35).fontWeight(300).fontColor(P.paper).id('profile-memories')
          Text('页').fontSize(11).fontColor(P.muted).margin({ top: 13 })
        }
        Text('亲手留下的记忆').fontSize(11).fontColor(P.muted)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Row().width(0.6).height(41).backgroundColor(P.line).margin({ left: 20, right: 32 })
      Column({ space: 6 }) {
        Row({ space: 7 }) {
          Text(`${this.favoriteCount()}`).fontSize(35).fontWeight(300).fontColor(P.paper).id('profile-collections')
          Text('处').fontSize(11).fontColor(P.muted).margin({ top: 13 })
        }
        Text('想再翻开的资料').fontSize(11).fontColor(P.muted)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').padding({ top: 22, bottom: 25 }).border({ width: { top: 0.6, bottom: 0.6 }, color: P.line })
  }

  @Builder
  private groupTitle(title: string) {
    Text(title).fontSize(11).letterSpacing(2).fontColor(P.dim).width('100%').margin({ top: 31, bottom: 6 })
  }

  @Builder
  private menuRow(title: string, detail: string, mark: string, id: string, action: () => void) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 14 }) {
        Text(mark).fontSize(17).fontColor(P.amber).width(25).textAlign(TextAlign.Center)
        Column({ space: 6 }) {
          Text(title).fontSize(15).fontColor(P.paper)
          Text(detail).fontSize(11).lineHeight(18).fontColor(P.muted).width('100%').maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text('›').fontSize(23).fontColor(P.dim)
      }.width('100%').alignItems(VerticalAlign.Center)
    }.width('100%').padding({ top: 18, bottom: 18 }).backgroundColor(Color.Transparent).borderRadius(0)
      .border({ width: { bottom: 0.6 }, color: P.line }).onClick(action).id(id)
  }

  @Builder
  private continuity() {
    Column({ space: 14 }) {
      Row({ space: 8 }) {
        Text('记忆在哪里').fontSize(13).fontWeight(FontWeight.Medium).fontColor(P.paper).layoutWeight(1)
      }.width('100%')
      Row({ space: 10 }) {
        Row().width(5).height(5).borderRadius(3).backgroundColor(P.amber)
        Text('本机收存').fontSize(11).fontColor(P.paperSoft).layoutWeight(1)
        Text(`${this.noteCount()} 页手账 · ${this.favoriteCount()} 处收藏`).fontSize(10).fontColor(P.muted)
      }.width('100%')
      Row({ space: 10 }) {
        Row().width(5).height(5).borderRadius(3).backgroundColor(this.view.lastSync > 0 ? P.muted : P.line)
        Text('同账号 HTTPS').fontSize(11).fontColor(P.paperSoft).layoutWeight(1)
        Text(this.networkState()).fontSize(10).fontColor(P.muted).id('paper-profile-https')
      }.width('100%')
      Row({ space: 10 }) {
        Row().width(5).height(5).borderRadius(3).backgroundColor(P.line)
        Text('鸿蒙可信设备').fontSize(11).fontColor(P.paperSoft).layoutWeight(1)
        Text(this.nativeState()).fontSize(10).fontColor(P.muted).id('paper-profile-native')
      }.width('100%')
    }.width('100%').padding(18).backgroundColor(P.deep).borderRadius(5).margin({ top: 25 })
  }

  build() {
    Scroll() {
      Column() {
        Text('我 的 云 河').fontSize(11).letterSpacing(4).fontColor(P.amber).width('100%')
        this.portrait()
        this.personalNumbers()
        this.groupTitle('把记忆带在身边')
        this.menuRow('账号与同步', this.accountLabel(), '↗', 'profile-account', this.onAccount)
        this.menuRow('数据与存储', '本机档案、备份与恢复', '▤', 'profile-data', this.onStorage)
        this.continuity()
        this.groupTitle('按自己的方式游历')
        this.menuRow('阅读偏好', '光感、动态与阅读方式', '◐', 'profile-preferences', this.onPreferences)
        this.menuRow('桌面与系统入口', '从桌面继续一段游历', '⌂', 'profile-system-cards', this.onSystems)
        this.menuRow('以前的个人长卷', '继续翻看主题路线与旧时记忆', '〰', 'profile-journeys', this.onLegacy)
        this.menuRow('资料与关于', '文化出处、图像署名与应用说明', '※', 'profile-info-top', this.onSources)
        Column({ space: 7 }) {
          Text('云河纪').fontSize(19).fontColor(P.paperSoft).letterSpacing(4)
          Text('沿河选城 · 亲手发现 · 留下自己的记忆').fontSize(10).fontColor(P.dim)
        }.width('100%').padding({ top: 37, bottom: 13 })
      }.width('100%').constraintSize({ maxWidth: 760 }).alignItems(HorizontalAlign.Start)
        .padding({ left: 25, right: 25, top: this.topClearance, bottom: this.bottomClearance + 20 })
    }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
      .backgroundColor(P.night).id('paper-profile')
  }
}
