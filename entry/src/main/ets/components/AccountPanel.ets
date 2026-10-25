import { AccountView, guestAccountView } from '../domain/AccountSync';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';

// “我的”只显示身份和真实交换状态，认证表单由独立 LoginPage 承载。
@Component
export struct AccountPanel {
  @Prop view: AccountView = guestAccountView();
  @Prop compact: boolean = false;
  onLogin: () => void = () => {};
  onLogout: () => void = () => {};
  onSync: () => void = () => {};

  private syncTime(): string {
    if (!this.view.lastSync) return '';
    const value = new Date(this.view.lastSync);
    const hour = value.getHours().toString().padStart(2, '0');
    const minute = value.getMinutes().toString().padStart(2, '0');
    return `${hour}:${minute}`;
  }

  // 进度只统计“本机记录里已经被账号回复确认的条数”，没有远端确认时不画满格。
  private totalRecords(): number {
    return Math.max(this.view.recordCount, this.view.pendingCount, 1);
  }

  private confirmedRecords(): number {
    return Math.max(0, this.totalRecords() - this.view.pendingCount);
  }

  private directionLabel(): string {
    if (this.view.otherDevices > 0) return `本机 → 其他 ${this.view.otherDevices} 台设备`;
    if (this.view.otherDevices === 0) return '本机 → 尚未发现其他账号设备';
    return '本机 → 等待账号设备信息';
  }

  build() {
    Column({ space: 16 }) {
      Row({ space: 14 }) {
        Stack() {
          Rect().width(56).height(56).radius(18).fill(T.rose).rotate({ angle: -6 })
          SymbolGlyph($r('sys.symbol.person')).fontSize(27).fontColor([T.accent])
        }.width(60).height(60)
        Column({ space: 6 }) {
          Text(this.view.signedIn ? this.view.username : '本机探索者').fontSize(F.section)
            .fontWeight(FontWeight.Bold).fontColor(T.ink).id('account-title')
          Text(this.view.signedIn ? (this.view.sessionReady ? '同一个账号，收藏与记忆相随。' : '离线档案已打开，记录仍可继续。') : '登录后，在另一台设备翻开记忆。')
            .fontSize(F.caption).fontColor(T.muted).lineHeight(20)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%')
      if (this.view.signedIn) {
        Divider().color(T.line)
        Row({ space: 12 }) {
          Column({ space: 5 }) {
            Text(!this.view.sessionReady ? '离线档案' : (this.view.message ? '需要重试' : (this.view.syncing ? '正在同步'
              : (this.view.pendingCount > 0 ? '等待同步' : (this.view.lastSync > 0 ? '已同步' : '等待连接'))))
            )
              .fontSize(F.card).fontWeight(FontWeight.Medium).fontColor(T.accent).id('account-sync-state')
            Text(this.view.pendingCount > 0 ? `${this.view.pendingCount} 条记录等待确认` :
              (this.view.lastSync > 0 ? `最近交换 ${this.syncTime()}` : '本机保存仍然可用'))
              .fontSize(F.caption).fontColor(T.muted).id('account-last-sync')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          if (!this.compact) {
          Button(this.view.sessionReady ? '刷新' : '重新登录', { type: ButtonType.Normal }).fontSize(F.small).height(42).borderRadius(10)
            .backgroundColor(T.accentSoft).fontColor(T.accent).enabled(!this.view.busy && !this.view.syncing)
            .id('account-refresh').onClick(() => { if (this.view.sessionReady) this.onSync(); else this.onLogin(); })
          }
        }.width('100%')
        // 方向与进度是赛题要求的“手机→平板”可见性：只显示真实设备数与已确认条数，
        // 没有第二台设备时明确说“尚未发现”，不用动画冒充同步。
        Column({ space: 7 }) {
          Row() {
            Text(this.directionLabel()).fontSize(F.caption).fontColor(T.muted).layoutWeight(1)
            Text(`${this.confirmedRecords()}/${this.totalRecords()} 条已确认`).fontSize(F.caption)
              .fontColor(T.accent).id('account-sync-progress-label')
          }.width('100%')
          Progress({ value: this.confirmedRecords(), total: this.totalRecords(), type: ProgressType.Linear })
            .width('100%').height(8).color(T.accent).backgroundColor(T.soft)
            .id('account-sync-progress')
          if (this.view.mergeConflicts > 0) {
            Text(`本次合并冲突 ${this.view.mergeConflicts} 条：已按最新时间戳保留一方，落败版本留在账号历史中。`)
              .fontSize(F.caption).fontColor(T.rose).lineHeight(18).width('100%').id('account-merge-conflicts')
          }
        }.width('100%').alignItems(HorizontalAlign.Start)
        if (!this.compact) {
          Text('收藏与手账随账号同步；离线修改先保存在本机。')
            .fontSize(F.caption).fontColor(T.muted).lineHeight(20)
          Button(this.view.busy ? '正在退出' : '退出登录', { type: ButtonType.Normal }).fontSize(F.small).height(40).borderRadius(10)
            .backgroundColor(T.soft).fontColor(T.muted).enabled(!this.view.busy && !this.view.syncing)
            .id('account-logout').onClick(this.onLogout)
        }
      } else {
        Button('登录云河纪', { type: ButtonType.Normal }).width('100%').height(46).fontSize(F.body)
          .borderRadius(T.buttonRadius).backgroundColor(T.accent).fontColor(T.onAccent).id('profile-login').onClick(this.onLogin)
      }
      if (this.view.message) {
        Text(this.view.message).fontSize(F.caption).fontColor(T.accent).lineHeight(20).id('profile-account-message')
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding(18).backgroundColor(T.surface)
      .borderRadius(T.cardRadius).id('account-panel')
  }
}
