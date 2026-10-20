import { activeRecords, ArchiveSnapshot, copySnapshot } from '../domain/ArchiveDomain';
import { AccountView, guestAccountView } from '../domain/AccountSync';
import { HarmonyEffects } from '../platform/HarmonyEffects';
import { AccountPanel } from './AccountPanel';
import { ArchiveStatusRow } from './ArchiveInfo';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';
import { JourneyPanel } from './JourneyPanel';

@Component
export struct ProfilePage {
  @Link snapshot: ArchiveSnapshot;
  @Prop view: AccountView = guestAccountView();
  @Prop saving: boolean = false;
  @Prop university: string = '';
  @Prop studentNumber: string = '';
  @Prop section: string = '';
  onOpenSection: (section: string) => void = () => {};
  onOpenMemory: (aiOnly: boolean) => void = () => {};
  onOpenAi: () => void = () => {};
  onCommit: (next: ArchiveSnapshot) => Promise<boolean> = async () => false;
  onLogin: () => void = () => {};
  onLogout: () => void = () => {};
  onSync: () => void = () => {};
  onOpenSite: (siteId: string) => void = () => {};
  onOpenJourneyGraph: (routeId: string) => void = () => {};

  private pageTitle(): string {
    if (this.section === 'journeys') return '我的主题漫游';
    if (this.section === 'account') return '账号与同步';
    if (this.section === 'preferences') return '阅读偏好';
    if (this.section === 'about') return '关于云河纪';
    return '我的';
  }

  @Builder
  menuRow(title: string, subtitle: string, icon: Resource, id: string, action: () => void) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 14 }) {
        SymbolGlyph(icon).fontSize(22).fontColor([T.accent]).width(30)
        Column({ space: 4 }) {
          Text(title).fontSize(F.body).fontWeight(FontWeight.Medium).fontColor(T.ink)
          Text(subtitle).fontSize(F.caption).fontColor(T.muted).maxLines(2)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(13).fontColor([T.muted])
      }.width('100%').padding({ top: 17, bottom: 17 })
    }.width('100%').padding(0).backgroundColor(Color.Transparent).borderRadius(0).id(id).onClick(action)
    Divider().color(T.line)
  }

  @Builder
  overview() {
    AccountPanel({ view: this.view, compact: true, onLogin: this.onLogin, onLogout: this.onLogout, onSync: this.onSync })
    Row({ space: 12 }) {
      Button({ type: ButtonType.Normal }) {
        Column({ space: 5 }) {
          Text(`${activeRecords(this.snapshot.records, 'note').length}`).fontSize(26).fontColor(T.ink).fontWeight(FontWeight.Bold)
          Text('我的手账').fontSize(F.caption).fontColor(T.muted)
        }.width('100%').padding({ top: 18, bottom: 18 })
      }.layoutWeight(1).padding(0).backgroundColor(T.blue).borderRadius(14).id('profile-memories')
        .onClick(() => this.onOpenMemory(false))
      Button({ type: ButtonType.Normal }) {
        Column({ space: 5 }) {
          Text(`${activeRecords(this.snapshot.records, 'note').filter(item => item.aiAssist !== undefined).length}`)
            .fontSize(26).fontColor(T.mintInk).fontWeight(FontWeight.Bold)
          Text('AI 辅助手账').fontSize(F.caption).fontColor(T.mintInk)
        }.width('100%').padding({ top: 18, bottom: 18 })
      }.layoutWeight(1).padding(0).backgroundColor(T.mint).borderRadius(14).id('profile-ai-memories')
        .onClick(() => this.onOpenMemory(true))
    }.width('100%').margin({ top: 18, bottom: 8 })
    this.menuRow('AI 观察', '方鼎与双连壶 · 提问、看部位、查依据', $r('sys.symbol.square_and_pencil'),
      'profile-ai-open', this.onOpenAi)
    this.menuRow('我的主题漫游', '三条路线与真实探索进度', $r('sys.symbol.map'),
      'profile-journeys', () => this.onOpenSection('journeys'))
    this.menuRow('账号与同步', this.view.signedIn ? '同步状态与账号管理' : '登录后，在另一端翻开记忆',
      $r('sys.symbol.person'), 'profile-account', () => this.onOpenSection('account'))
    this.menuRow('阅读偏好', '沉浸光感与动态效果', $r('sys.symbol.bookmark'),
      'profile-preferences', () => this.onOpenSection('preferences'))
    this.menuRow('关于与资料说明', '内容来源、AI 范围与版本', $r('sys.symbol.folder'),
      'profile-info-top', () => this.onOpenSection('about'))
  }

  @Builder
  preferences() {
    Text('跟随系统外观').fontSize(F.caption).fontColor(T.muted).width('100%').padding({ bottom: 14 })
    Row({ space: 12 }) {
      Text('沉浸光感').fontSize(F.body).fontColor(T.ink).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.snapshot.lightEnabled }).enabled(!this.saving).id('light-enabled')
        .selectedColor(T.accent).onChange((enabled: boolean) => {
          if (this.saving || enabled === this.snapshot.lightEnabled) return;
          const next = copySnapshot(this.snapshot); next.lightEnabled = enabled; this.onCommit(next);
        })
    }.width('100%').padding({ top: 16, bottom: 16 })
    Divider().color(T.line)
    ArchiveStatusRow({ label: '显示效果', value: HarmonyEffects.hdsSupported() ? '原生沉浸光感' : '系统自适应材质', valueId: 'native-material-capability' })
    Divider().color(T.line)
    Row({ space: 12 }) {
      Text('减少动态效果').fontSize(F.body).fontColor(T.ink).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.snapshot.reducedMotion }).enabled(!this.saving).id('reduced-motion')
        .selectedColor(T.accent).onChange((enabled: boolean) => {
          if (this.saving || enabled === this.snapshot.reducedMotion) return;
          const next = copySnapshot(this.snapshot); next.reducedMotion = enabled; this.onCommit(next);
        })
    }.width('100%').padding({ top: 16, bottom: 16 })
  }

  @Builder
  heading(title: string, caption: string = '') {
    Row({ space: 8 }) {
      Text(title).fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink).layoutWeight(1)
      if (caption) { Text(caption).fontSize(F.caption).fontColor(T.muted) }
    }.width('100%').padding({ top: 24, bottom: 14 })
  }

  @Builder
  infoSheet() {
    Column({ space: 14 }) {
      Text('资料说明').fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink).width('100%')
      Text('文化内容').fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.accent).width('100%')
      Text('五城二十处档案仍为初稿待校审；事实与来源以详情中列出的官方页面为准，机构入口不等于条目级校审。')
        .fontSize(F.caption).fontColor(T.muted).lineHeight(21).width('100%')
      Text('图像与模型').fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.accent).width('100%')
      Text('封面插画与程序化几何为原创学习示意，不是文物照片、测绘或考古复原；比例、纹样和标记均已简化。')
        .fontSize(F.caption).fontColor(T.muted).lineHeight(21).width('100%')
      Text('AI 参考解读').fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.mintInk).width('100%')
      Text('当前开放杜岭二号方鼎与大河村彩陶双连壶两件；AI 只依据本对象已核事实解释，资料不足时会明确说明，不替代馆方原文或人工校审。')
        .fontSize(F.caption).fontColor(T.muted).lineHeight(21).width('100%')
      Text('提问会发送到在线模型服务，仅用于生成这次回答；请勿输入个人敏感信息。')
        .fontSize(F.caption).fontColor(T.muted).lineHeight(21).width('100%')
      Text('数据').fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.accent).width('100%')
      Text('收藏、手账与浏览记录按账号同步；未登录记录保存在本机。设备标识是安装实例，不是账号身份。')
        .fontSize(F.caption).fontColor(T.muted).lineHeight(21).width('100%')
    }.width('100%').padding({ left: 22, right: 22, top: 8, bottom: 30 }).alignItems(HorizontalAlign.Start)
      .id('archive-info-sheet')
  }

  build() {
    NavDestination() {
      Scroll() {
        Column() {
          if (!this.section) { this.overview() }
          if (this.section === 'journeys') {
            JourneyPanel({ records: this.snapshot.records, onOpenSite: this.onOpenSite,
              onOpenGraph: this.onOpenJourneyGraph })
          }
          if (this.section === 'account') {
          AccountPanel({ view: this.view, onLogin: this.onLogin, onLogout: this.onLogout, onSync: this.onSync })
          this.heading('账号同步')
          Column() {
            ArchiveStatusRow({ label: '其他账号设备', value: this.view.signedIn && this.view.lastSync > 0
              ? `${this.view.otherDevices} 台` : '暂无同步记录', valueId: 'connected-devices-value' })
            Divider().color(T.line)
            ArchiveStatusRow({ label: '最近账号同步', value: this.view.signedIn && this.view.lastSync > 0
              ? new Date(this.view.lastSync).toLocaleTimeString() : '尚未接入', valueId: 'last-sync-value' })
          }.width('100%').padding({ left: 18, right: 18 }).backgroundColor(T.surface).borderRadius(T.cardRadius)
          }
          if (this.section === 'preferences') { this.preferences() }
          if (this.section === 'about') {
          Column({ space: 12 }) {
            Text('云河纪 · 个人文化手账').fontSize(F.card).fontWeight(FontWeight.Bold).fontColor(T.ink).width('100%')
            Text('沿黄河读文化，把看到的细节、当时的视角和自己的想法留在一页手账里。')
              .fontSize(F.caption).fontColor(T.muted).lineHeight(21).width('100%')
            Text('版本 0.1.0').fontSize(F.caption).fontColor(T.tertiary).width('100%')
          }.width('100%').padding(18).alignItems(HorizontalAlign.Start).backgroundColor(T.surface).borderRadius(T.cardRadius)
          this.infoSheet()
          }
        }.width('100%').constraintSize({ maxWidth: 720 }).padding({ left: 18, right: 18, top: 16, bottom: 36 })
      }.width('100%').height('100%').align(Alignment.Top).id('profile-scroll')
    }.title(this.pageTitle(), { systemMaterial: HarmonyEffects.material(this.snapshot.lightEnabled, this.snapshot.reducedMotion) })
      .backgroundColor(T.canvas).id('profile-page')
  }
}
