import { AccountView, guestAccountView } from '../domain/AccountSync';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';

// 独立启动页：认证成功或明确选择离线浏览后才创建主导航。
// 学校 / 学号只是教育计划的界面预留，不进入认证、存储或同步请求。
@Component
export struct LoginPage {
  @Prop view: AccountView = guestAccountView();
  @Prop initializing: boolean = false;
  @Prop localAvailable: boolean = false;
  @Prop localError: string = '';
  onAuthenticate: (username: string, password: string, register: boolean, university: string, studentNumber: string) => Promise<boolean> = async () => false;
  onOffline: () => void = () => {};
  onRetryLocal: () => void = () => {};
  @State registering: boolean = false;
  @State educationOpen: boolean = false;
  @State username: string = '';
  @State password: string = '';
  @State university: string = '';
  @State studentNumber: string = '';
  private usernameController: TextInputController = new TextInputController();
  private passwordController: TextInputController = new TextInputController();
  private universityController: TextInputController = new TextInputController();
  private studentController: TextInputController = new TextInputController();

  private async submit(): Promise<void> {
    if (this.view.busy || this.initializing) return;
    this.usernameController.stopEditing(); this.passwordController.stopEditing();
    this.universityController.stopEditing(); this.studentController.stopEditing();
    if (await this.onAuthenticate(this.username.trim(), this.password, this.registering,
      this.university.trim(), this.studentNumber.trim())) this.password = '';
  }

  build() {
    Scroll() {
      Column({ space: 24 }) {
        Row({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.map')).fontSize(26).fontColor([T.accent])
          Text('云河纪').fontSize(F.title).fontWeight(FontWeight.Bold).fontColor(T.ink)
          Blank()
          Text('文化探索 · 个人记忆').fontSize(F.caption).fontColor(T.muted)
        }.width('100%').id('login-brand')
        Row({ space: 10 }) {
          Column({ space: 10 }) {
            Text('沿河而行，\n让记忆相随。').fontSize(29).fontWeight(FontWeight.Bold).fontColor(T.ink).lineHeight(40)
            Text('从一处文明，走进自己的故事。').fontSize(F.small).fontColor(T.muted).lineHeight(22)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Image($r('app.media.motif_pottery')).width(82).height(106).objectFit(ImageFit.Cover)
            .borderRadius(18).rotate({ angle: 7 }).accessibilityText('彩陶主题示意插画')
        }.width('100%').padding({ top: 10, bottom: 2 })
        Column({ space: 16 }) {
          Text(this.registering ? '开启你的河流记忆' : '登录云河纪').fontSize(F.section)
            .fontWeight(FontWeight.Bold).fontColor(T.ink).id('login-title')
          Row({ space: 8 }) {
            Button('登录', { type: ButtonType.Normal }).layoutWeight(1).height(40).borderRadius(10)
              .fontSize(F.small).backgroundColor(this.registering ? T.soft : T.accentSoft)
              .fontColor(this.registering ? T.muted : T.accent).enabled(!this.view.busy)
              .id('account-mode-login').onClick(() => { this.registering = false; })
            Button('注册账号', { type: ButtonType.Normal }).layoutWeight(1).height(40).borderRadius(10)
              .fontSize(F.small).backgroundColor(this.registering ? T.accentSoft : T.soft)
              .fontColor(this.registering ? T.accent : T.muted).enabled(!this.view.busy)
              .id('account-mode-register').onClick(() => { this.registering = true; })
          }.width('100%')
          Column({ space: 7 }) {
            Text('账号').fontSize(F.small).fontColor(T.ink)
            TextInput({ text: this.username, placeholder: '4—32 位字母、数字或下划线', controller: this.usernameController })
              .fontSize(F.small).fontColor(T.ink).placeholderColor(T.muted).backgroundColor(T.soft)
              .height(48).borderRadius(T.inputRadius).maxLength(32).enabled(!this.view.busy).id('account-username')
              .onChange((value: string) => { this.username = value; })
          }.width('100%').alignItems(HorizontalAlign.Start)
          Column({ space: 7 }) {
            Text('密码').fontSize(F.small).fontColor(T.ink)
            TextInput({ text: this.password, placeholder: '至少 10 位', controller: this.passwordController })
              .type(InputType.Password).fontSize(F.small).fontColor(T.ink).placeholderColor(T.muted).backgroundColor(T.soft)
              .height(48).borderRadius(T.inputRadius).maxLength(128).enabled(!this.view.busy).id('account-password')
              .onChange((value: string) => { this.password = value; })
          }.width('100%').alignItems(HorizontalAlign.Start)
          Button({ type: ButtonType.Normal }) {
            Row({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.book')).fontSize(18).fontColor([T.accent])
              Text('学习档案').fontSize(F.small).fontColor(T.ink).layoutWeight(1).textAlign(TextAlign.Start)
              Text('选填 · 预留').fontSize(F.caption).fontColor(T.muted)
              SymbolGlyph(this.educationOpen ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'))
                .fontSize(13).fontColor([T.muted])
            }.width('100%')
          }.width('100%').height(44).padding(0).backgroundColor(Color.Transparent).enabled(!this.view.busy)
            .id('education-toggle').onClick(() => { this.educationOpen = !this.educationOpen; })
          if (this.educationOpen) {
            Column({ space: 12 }) {
              Text('教育计划尚未开放。以下信息仅在本次登录后展示，不保存或上传，也不参与身份认证。')
                .fontSize(F.caption).fontColor(T.muted).lineHeight(20).id('education-placeholder-hint')
              TextInput({ text: this.university, placeholder: '大学 / 院校名称（选填）', controller: this.universityController })
                .height(48).fontSize(F.small).fontColor(T.ink).placeholderColor(T.muted).backgroundColor(T.soft)
                .borderRadius(T.inputRadius).maxLength(80).enabled(!this.view.busy).id('education-university')
                .onChange((value: string) => { this.university = value; })
              TextInput({ text: this.studentNumber, placeholder: '学号（选填）', controller: this.studentController })
                .height(48).fontSize(F.small).fontColor(T.ink).placeholderColor(T.muted).backgroundColor(T.soft)
                .borderRadius(T.inputRadius).maxLength(32).enabled(!this.view.busy).id('education-student-number')
                .onChange((value: string) => { this.studentNumber = value; })
            }.width('100%').alignItems(HorizontalAlign.Start)
          }
          if (this.view.message) {
            Text(this.view.message).fontSize(F.caption).fontColor(T.accent).lineHeight(20).id('account-message')
          }
          Button(this.initializing ? '正在准备' : (this.view.busy ? '正在连接' : (this.registering ? '注册并进入' : '登录并进入')),
            { type: ButtonType.Normal }).width('100%').height(48).borderRadius(T.buttonRadius)
            .fontSize(F.body).backgroundColor(T.accent).fontColor(T.onAccent).enabled(!this.view.busy && !this.initializing)
            .id('account-submit').onClick(() => { this.submit(); })
          Text('登录同一账号，让收藏、笔记和探索足迹随身。').fontSize(F.caption).fontColor(T.muted).lineHeight(20)
        }.width('100%').alignItems(HorizontalAlign.Start).padding(20).backgroundColor(T.surface).borderRadius(24)
        Column({ space: 6 }) {
          if (this.localError) {
            Text(this.localError).fontSize(F.caption).fontColor(T.accent).lineHeight(20).id('login-local-error')
            Button('重新读取本机档案', { type: ButtonType.Normal }).fontSize(F.small).fontColor(T.accent)
              .height(44).backgroundColor(Color.Transparent).enabled(!this.initializing && !this.view.busy)
              .id('login-local-retry').onClick(this.onRetryLocal)
          }
          Button('离线浏览本机档案', { type: ButtonType.Normal }).fontSize(F.small).fontColor(T.muted)
            .height(44).padding({ left: 16, right: 16 }).backgroundColor(Color.Transparent)
            .enabled(this.localAvailable && !this.view.busy && !this.initializing).id('login-offline').onClick(this.onOffline)
          Text('未登录记录保留在本机，登录后使用独立账号档案。')
            .fontSize(F.caption).fontColor(T.tertiary).textAlign(TextAlign.Center).lineHeight(20)
        }.width('100%')
      }.width('100%').constraintSize({ maxWidth: 480 }).padding({ left: 22, right: 22, top: 20, bottom: 28 })
        .alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%').align(Alignment.Top).backgroundColor(T.canvas).id('login-scroll')
  }
}
