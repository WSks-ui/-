import { ArchiveSnapshot, copySnapshot } from '../domain/ArchiveDomain';
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
  onCommit: (next: ArchiveSnapshot) => Promise<boolean> = async () => false;
  onLogin: () => void = () => {};
  onLogout: () => void = () => {};
  onSync: () => void = () => {};
  onOpenSite: (siteId: string) => void = () => {};
  onOpenJourneyGraph: (routeId: string) => void = () => {};

  @Builder
  heading(title: string, caption: string = '') {
    Row({ space: 8 }) {
      Text(title).fontSize(F.section).fontWeight(FontWeight.Bold).fontColor(T.ink).layoutWeight(1)
      if (caption) { Text(caption).fontSize(F.caption).fontColor(T.muted) }
    }.width('100%').padding({ top: 24, bottom: 14 })
  }

  build() {
    NavDestination() {
      Scroll() {
        Column() {
          Text('每一次探索，都成为你的一部分。').fontSize(F.small).fontColor(T.muted).lineHeight(22)
            .width('100%').margin({ top: 12, bottom: 22 })
          AccountPanel({ view: this.view, onLogin: this.onLogin, onLogout: this.onLogout, onSync: this.onSync })
          // 路线只读个人档案派生进度，不把大学或学号用于学习判定、账号认证或同步。
          // 两个旧资料属性仍保留给现有登录调用方，个人页不再显示教育计划占位。
          JourneyPanel({ records: this.snapshot.records, onOpenSite: this.onOpenSite,
            onOpenGraph: this.onOpenJourneyGraph }).margin({ top: 24 })
          this.heading('账号同步')
          Column() {
            ArchiveStatusRow({ label: '其他在线设备', value: this.view.signedIn && this.view.lastSync > 0
              ? `${this.view.otherDevices} 台` : '尚未接入', valueId: 'connected-devices-value' })
            Divider().color(T.line)
            ArchiveStatusRow({ label: '最近账号同步', value: this.view.signedIn && this.view.lastSync > 0
              ? new Date(this.view.lastSync).toLocaleTimeString() : '尚未接入', valueId: 'last-sync-value' })
            Divider().color(T.line)
            ArchiveStatusRow({ label: '保留冲突版本', value: this.view.signedIn && this.view.lastSync > 0
              ? `${this.view.conflictCount} 条` : '尚未检测' })
          }.width('100%').padding({ left: 18, right: 18 }).backgroundColor(T.surface).borderRadius(T.cardRadius)
          this.heading('阅读偏好', '跟随系统外观')
          Column() {
            Row({ space: 12 }) {
              Text('沉浸光感').fontSize(F.body).fontColor(T.ink).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.snapshot.lightEnabled }).enabled(!this.saving).id('light-enabled')
                .selectedColor(T.accent).onChange((enabled: boolean) => {
                  // 个人页会随共享快照 / 保存锁更新，原生开关也可能回调相同值。
                  // 只处理真实变化，禁止重绘触发重复保存，让保存锁反复禁用控件。
                  if (this.saving || enabled === this.snapshot.lightEnabled) return;
                  const next = copySnapshot(this.snapshot); next.lightEnabled = enabled; this.onCommit(next);
                })
            }.width('100%').padding({ top: 16, bottom: 16 })
            Divider().color(T.line)
            ArchiveStatusRow({ label: '设备光感能力', value: HarmonyEffects.hdsSupported() ? '原生沉浸光感' : '系统自适应材质', valueId: 'native-material-capability' })
            Divider().color(T.line)
            Row({ space: 12 }) {
              Text('减少动态效果').fontSize(F.body).fontColor(T.ink).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.snapshot.reducedMotion }).enabled(!this.saving).id('reduced-motion')
                .selectedColor(T.accent).onChange((enabled: boolean) => {
                  if (this.saving || enabled === this.snapshot.reducedMotion) return;
                  const next = copySnapshot(this.snapshot); next.reducedMotion = enabled; this.onCommit(next);
                })
            }.width('100%').padding({ top: 16, bottom: 16 })
          }.width('100%').padding({ left: 18, right: 18 }).backgroundColor(T.surface).borderRadius(T.cardRadius)
          this.heading('关于云河纪')
          Column() {
            ArchiveStatusRow({ label: '版本', value: '0.1.0 · 原生开发版' })
            Divider().color(T.line)
            ArchiveStatusRow({ label: '内容状态', value: '五城文化初稿待校审' })
          }.width('100%').padding({ left: 18, right: 18 }).backgroundColor(T.surface).borderRadius(T.cardRadius)
        }.width('100%').constraintSize({ maxWidth: 720 }).padding({ left: 18, right: 18, bottom: 36 })
      }.width('100%').height('100%').align(Alignment.Top).id('profile-scroll')
    }.title('我的', { systemMaterial: HarmonyEffects.material(this.snapshot.lightEnabled, this.snapshot.reducedMotion) })
      .backgroundColor(T.canvas).id('profile-page')
  }
}
