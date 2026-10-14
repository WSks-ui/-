import { AccountView, guestAccountView } from '../domain/AccountSync';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';

@Component
export struct AccountPanel {
  @Prop view: AccountView = guestAccountView();
  onAuthenticate: (username: string, password: string, register: boolean) => Promise<boolean> = async () => false;
  onLogout: () => void = () => {};
  onSync: () => void = () => {};
  @State registering: boolean = false;
  @State username: string = '';
  @State password: string = '';
  private usernameController: TextInputController = new TextInputController();
  private passwordController: TextInputController = new TextInputController();

  private async submit(): Promise<void> {
    if (this.view.busy) return;
    this.usernameController.stopEditing();
    this.passwordController.stopEditing();
    if (await this.onAuthenticate(this.username.trim(), this.password, this.registering)) this.password = '';
  }

  build() {
    Column({ space: 16 }) {
      Row({ space: 14 }) {
        Stack() {
          Rect().width(54).height(54).radius(16).fill(T.rose).rotate({ angle: -6 })
          SymbolGlyph($r('sys.symbol.person')).fontSize(27).fontColor([T.accent])
        }.width(60).height(60)
        Column({ space: 5 }) {
          Text(this.view.signedIn ? this.view.username : '把记忆带在身边')
            .fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink).id('account-title')
          Text(this.view.signedIn ? '云河纪账号 · 同账号个人档案' : '登录同一账号，在另一台设备翻开记录。')
            .fontSize(F.caption).fontColor(T.muted)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%')
      if (!this.view.signedIn) {
        Row({ space: 10 }) {
          Button('登录', { type: ButtonType.Normal }).layoutWeight(1).fontSize(F.small).height(42).borderRadius(10)
            .backgroundColor(this.registering ? T.soft : T.accentSoft).fontColor(this.registering ? T.muted : T.accent)
            .enabled(!this.view.busy).id('account-mode-login').onClick(() => { this.registering = false; })
          Button('注册账号', { type: ButtonType.Normal }).layoutWeight(1).fontSize(F.small).height(42).borderRadius(10)
            .backgroundColor(this.registering ? T.accentSoft : T.soft).fontColor(this.registering ? T.accent : T.muted)
            .enabled(!this.view.busy).id('account-mode-register').onClick(() => { this.registering = true; })
        }.width('100%')
        TextInput({ text: this.username, placeholder: '账号 · 字母、数字或下划线', controller: this.usernameController })
          .fontSize(F.small).fontColor(T.ink).placeholderColor(T.muted).backgroundColor(T.soft)
          .height(48).borderRadius(10).maxLength(32).enabled(!this.view.busy).id('account-username')
          .onChange((value: string) => { this.username = value; })
        TextInput({ text: this.password, placeholder: '密码 · 至少 10 位', controller: this.passwordController })
          .type(InputType.Password).fontSize(F.small).fontColor(T.ink).placeholderColor(T.muted).backgroundColor(T.soft)
          .height(48).borderRadius(10).maxLength(128).enabled(!this.view.busy).id('account-password')
          .onChange((value: string) => { this.password = value; })
        Button(this.view.busy ? '正在连接' : (this.registering ? '注册并登录' : '登录云河纪'), { type: ButtonType.Normal })
          .width('100%').height(48).borderRadius(T.buttonRadius).fontSize(F.body)
          .backgroundColor(T.accent).fontColor(T.onAccent).enabled(!this.view.busy).id('account-submit')
          .onClick(() => { this.submit(); })
        Text('登录后使用账号档案；未登录时的记录继续保留在本机。')
          .fontSize(F.caption).fontColor(T.muted).lineHeight(20)
      } else {
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
        Text('收藏、分类、笔记、标签和浏览记录随账号同步。离线修改先保存在本机，恢复连接后自动重试。')
          .fontSize(F.caption).fontColor(T.muted).lineHeight(20)
        Button('退出登录', { type: ButtonType.Normal }).fontSize(F.small).height(40).borderRadius(10)
          .backgroundColor(T.soft).fontColor(T.muted).enabled(!this.view.busy && !this.view.syncing)
          .id('account-logout').onClick(this.onLogout)
      }
      if (this.view.message) {
        Text(this.view.message).fontSize(F.caption).fontColor(T.accent).lineHeight(20).id('account-message')
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding(18).backgroundColor(T.surface)
      .borderRadius(T.cardRadius).id('account-panel')
  }
}
