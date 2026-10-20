import { bundleManager } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { activeRecords, ArchiveSnapshot, copySnapshot } from '../domain/ArchiveDomain';
import { HERITAGE_SITES } from '../data/HeritageCatalog';
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
  onOpenCollection: () => void = () => {};
  onOpenLibrary: (scope: string) => void = () => {};
  onOpenAi: () => void = () => {};
  onCommit: (next: ArchiveSnapshot) => Promise<boolean> = async () => false;
  onLogin: () => void = () => {};
  onLogout: () => void = () => {};
  onSync: () => void = () => {};
  onOpenSite: (siteId: string) => void = () => {};
  onOpenJourneyGraph: (routeId: string) => void = () => {};

  private favoriteCount(): number {
    return activeRecords(this.snapshot.records, 'favorite').length;
  }

  private visitedCount(): number {
    // 浏览与主题探索共用 progress 记录，按 siteId 去重后与档案页“已读”口径一致。
    return HERITAGE_SITES.filter((site) => this.snapshot.records.some((record) =>
      record.kind === 'progress' && !record.deleted && record.siteId === site.id)).length;
  }

  private storageKb(): number {
    // 以实际序列化体积估算本机占用；这是备份体积，不是 Preferences 的磁盘页对齐值。
    return Math.max(1, Math.round(JSON.stringify(this.snapshot).length / 1024));
  }

  private versionName(): string {
    try {
      return bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT).versionName;
    } catch {
      // 取不到包信息时保留构建期版本，不显示空白。
      return '0.1.0';
    }
  }

  private async copyBackup(): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, JSON.stringify(this.snapshot));
      await pasteboard.getSystemPasteboard().setData(data);
      this.getUIContext().getPromptAction().showToast({ message: '本机档案已复制为 JSON 备份' });
    } catch {
      this.getUIContext().getPromptAction().showToast({ message: '复制失败，请稍后重试' });
    }
  }

  private pageTitle(): string {
    if (this.section === 'journeys') return '我的主题漫游';
    if (this.section === 'account') return '账号与同步';
    if (this.section === 'data') return '数据与存储';
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
  statCard(label: string, value: number, surface: Resource, ink: Resource, id: string, action: () => void) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 4 }) {
        Text(`${value}`).fontSize(24).fontWeight(FontWeight.Bold).fontColor(ink)
        Text(label).fontSize(F.caption).fontColor(ink)
      }.width('100%').padding({ top: 14, bottom: 14 })
    }.layoutWeight(1).padding(0).backgroundColor(surface).borderRadius(14)
      .id(id).accessibilityText(`${label} ${value}，查看详情`).onClick(action)
  }

  @Builder
  groupLabel(title: string) {
    Text(title).fontSize(F.caption).fontWeight(FontWeight.Medium).fontColor(T.accent)
      .width('100%').padding({ top: 20, bottom: 2 })
  }

  @Builder
  overview() {
    AccountPanel({ view: this.view, compact: true, onLogin: this.onLogin, onLogout: this.onLogout, onSync: this.onSync })
    Row({ space: 12 }) {
      this.statCard('手账', activeRecords(this.snapshot.records, 'note').length, T.blue, T.ink,
        'profile-memories', () => this.onOpenMemory(false))
      this.statCard('收藏', this.favoriteCount(), T.accentSoft, T.accent,
        'profile-collections', this.onOpenCollection)
    }.width('100%').margin({ top: 18 })
    Row({ space: 12 }) {
      this.statCard('AI 辅助', activeRecords(this.snapshot.records, 'note').filter(item => item.aiAssist !== undefined).length,
        T.mint, T.mintInk, 'profile-ai-memories', () => this.onOpenMemory(true))
      this.statCard('已浏览', this.visitedCount(), T.soft, T.mintInk,
        'profile-visited', () => this.onOpenLibrary('已浏览'))
    }.width('100%').margin({ top: 10, bottom: 8 })
    this.groupLabel('内容')
    this.menuRow('AI 观察', '方鼎与双连壶 · 提问、看部位、查依据', $r('sys.symbol.square_and_pencil'),
      'profile-ai-open', this.onOpenAi)
    this.menuRow('我的主题漫游', '三条路线与真实探索进度', $r('sys.symbol.map'),
      'profile-journeys', () => this.onOpenSection('journeys'))
    this.groupLabel('账号与数据')
    this.menuRow('账号与同步', this.view.signedIn ? '同步状态与账号管理' : '登录后，在另一端翻开记忆',
      $r('sys.symbol.person'), 'profile-account', () => this.onOpenSection('account'))
    this.menuRow('数据与存储', '本机记录、备份与占用', $r('sys.symbol.folder'),
      'profile-data', () => this.onOpenSection('data'))
    this.groupLabel('应用')
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

  @Builder
  dataSection() {
    this.heading('本机数据', '离线优先')
    Column() {
      ArchiveStatusRow({ label: '本机手账', value: `${activeRecords(this.snapshot.records, 'note').length} 篇`,
        valueId: 'data-notes' })
      Divider().color(T.line)
      ArchiveStatusRow({ label: '本机收藏', value: `${this.favoriteCount()} 处`, valueId: 'data-favorites' })
      Divider().color(T.line)
      ArchiveStatusRow({ label: '已浏览档案', value: `${this.visitedCount()} / ${HERITAGE_SITES.length} 处`,
        valueId: 'data-visited' })
      Divider().color(T.line)
      ArchiveStatusRow({ label: 'AI 辅助手账',
        value: `${activeRecords(this.snapshot.records, 'note').filter(item => item.aiAssist !== undefined).length} 篇`,
        valueId: 'data-ai-notes' })
      Divider().color(T.line)
      ArchiveStatusRow({ label: '本机占用', value: `约 ${this.storageKb()} KB`, valueId: 'data-storage' })
    }.width('100%').padding({ left: 18, right: 18 }).backgroundColor(T.surface)
      .borderRadius(T.cardRadius).id('data-summary')
    Text('收藏、手账、浏览记录与 AI 依据都保存在本机 Preferences；登录后随账号同步，退出登录不会清空本机记录。')
      .fontSize(F.caption).fontColor(T.muted).lineHeight(21).width('100%').padding({ top: 14, bottom: 14 })
    Button('复制本机备份 JSON', { type: ButtonType.Normal }).id('profile-copy-backup')
      .width('100%').constraintSize({ minHeight: 44 }).fontSize(F.small)
      .fontColor(T.mintInk).backgroundColor(T.mint).borderRadius(11)
      .onClick(() => { this.copyBackup(); })
    Text('备份包含收藏、手账正文、标签、视角与 AI 依据，不包含账号密码。')
      .fontSize(F.caption).fontColor(T.muted).lineHeight(20).width('100%').padding({ top: 10 })
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
            Divider().color(T.line)
            ArchiveStatusRow({ label: '服务连接', value: this.view.serviceConfigured ? '已配置' : '未配置',
              valueId: 'service-state' })
            Divider().color(T.line)
            ArchiveStatusRow({ label: '同步冲突', value: this.view.conflictCount > 0
              ? `${this.view.conflictCount} 项待处理` : '无', valueId: 'conflict-count' })
          }.width('100%').padding({ left: 18, right: 18 }).backgroundColor(T.surface).borderRadius(T.cardRadius)
          }
          if (this.section === 'data') { this.dataSection() }
          if (this.section === 'preferences') { this.preferences() }
          if (this.section === 'about') {
          Column({ space: 12 }) {
            Text('云河纪 · 个人文化手账').fontSize(F.card).fontWeight(FontWeight.Bold).fontColor(T.ink).width('100%')
            Text('沿黄河读文化，把看到的细节、当时的视角和自己的想法留在一页手账里。')
              .fontSize(F.caption).fontColor(T.muted).lineHeight(21).width('100%')
            Text(`版本 ${this.versionName()}`).fontSize(F.caption).fontColor(T.tertiary).width('100%')
              .id('about-version')
          }.width('100%').padding(18).alignItems(HorizontalAlign.Start).backgroundColor(T.surface).borderRadius(T.cardRadius)
          this.infoSheet()
          }
        }.width('100%').constraintSize({ maxWidth: 720 }).padding({ left: 18, right: 18, top: 16, bottom: 36 })
      }.width('100%').height('100%').align(Alignment.Top).id('profile-scroll')
    }.title(this.pageTitle(), { systemMaterial: HarmonyEffects.material(this.snapshot.lightEnabled, this.snapshot.reducedMotion) })
      .backgroundColor(T.canvas).id('profile-page')
  }
}
