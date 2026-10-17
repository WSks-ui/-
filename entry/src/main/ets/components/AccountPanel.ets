import { AccountView, guestAccountView } from '../domain/AccountSync';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';

// “我的”只显示身份和真实交换状态，认证表单由独立 LoginPage 承载。
@Component
export struct AccountPanel {
  @Prop view: AccountView = guestAccountView();
  onLogin: () => void = () => {};
  onLogout: () => void = () => {};
  onSync: () => void = () => {};

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
          Text(this.view.signedIn ? '同一个账号，收藏与记忆相随。' : '登录后，在另一台设备翻开记忆。')
            .fontSize(F.caption).fontColor(T.muted).lineHeight(20)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%')
      if (this.view.signedIn) {
        Divider().color(T.line)
        Row({ space: 12 }) {
          Column({ space: 5 }) {
            Text(this.view.message ? '同步需要重试' : (this.view.syncing ? '正在交换记录'
              : (this.view.lastSync > 0 ? '上次同步已完成' : '等待连接')))
              .fontSize(F.card).fontWeight(FontWeight.Medium).fontColor(T.accent).id('account-sync-state')
            Text(this.view.lastSync > 0 ? `最近同步 ${new Date(this.view.lastSync).toLocaleTimeString()}` : '本机保存仍然可用')
              .fontSize(F.caption).fontColor(T.muted).id('account-last-sync')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Button('刷新', { type: ButtonType.Normal }).fontSize(F.small).height(42).borderRadius(10)
            .backgroundColor(T.accentSoft).fontColor(T.accent).enabled(!this.view.busy && !this.view.syncing)
            .id('account-refresh').onClick(this.onSync)
        }.width('100%')
        Text('收藏、分类、笔记、标签和浏览记录随账号同步。离线修改先保存在本机，恢复连接后重试。')
          .fontSize(F.caption).fontColor(T.muted).lineHeight(20)
        Button(this.view.busy ? '正在退出' : '退出登录', { type: ButtonType.Normal }).fontSize(F.small).height(40).borderRadius(10)
          .backgroundColor(T.soft).fontColor(T.muted).enabled(!this.view.busy && !this.view.syncing)
          .id('account-logout').onClick(this.onLogout)
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
