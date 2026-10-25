import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DEBUG } from 'BuildProfile';
import { archiveStoreForLaunch, DEFAULT_ARCHIVE_STORE } from '../platform/ArchiveLaunch';
import { ROAMING_ROUTE_STORAGE_KEY, roamingRouteFromWant } from '../roamingform/RoamingCardData';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private archiveStoreName: string = DEFAULT_ARCHIVE_STORE;
  private sharedStorage: LocalStorage = new LocalStorage();

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.archiveStoreName = archiveStoreForLaunch(want.parameters?.['yunhejiTestStore'], DEBUG);
    // 原生手势性能采样只允许debug独立测试库显式开启；不记录正文或账号，
    // 正式库和默认启动始终关闭。开关只采绘制CPU/合帧统计，不修改作品或游戏进度。
    AppStorage.setOrCreate('paperScenePerfEnabled', DEBUG && this.archiveStoreName.startsWith('yunheji_test_ui_') &&
      want.parameters?.['yunhejiPaperPerf'] === true);
    this.sharedStorage.setOrCreate(ROAMING_ROUTE_STORAGE_KEY, roamingRouteFromWant(want));
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 桌面卡片可能命中已在后台的单实例 Ability，必须同样传给当前窗口。
    // requestId 让连续点击同一张卡片仍能触发一次消费；不更换当前账号档案库。
    const route: string = roamingRouteFromWant(want);
    if (route.length > 0) this.sharedStorage.setOrCreate(ROAMING_ROUTE_STORAGE_KEY, route);
  }

  onDestroy(): void {
    AppStorage.setOrCreate('paperScenePerfEnabled', false);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // 用窗口级 LocalStorage 传递库名，避免 AppStorage 在多个 Ability 之间串库。
    const storage = this.sharedStorage;
    storage.setOrCreate('archiveStoreName', this.archiveStoreName);
    storage.setOrCreate('appForeground', true);

    // 先完成窗口配置，再挂载 HDS/ArkUI。此前 loadContent 与两个异步设置并发，
    // 首帧和后续 NavDestination 可能以不同的默认安全区/系统栏状态开始绘制。
    this.loadWindowContent(windowStage, storage);

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
  }

  private async loadWindowContent(windowStage: window.WindowStage, storage: LocalStorage): Promise<void> {
    try {
      // 2026-10-25 核对本机 API26：SystemBarProperties 可设栏背景，
      // Navigation/HDS 的 SystemBarStyle 只设状态栏文字。页面提供实际背景，
      // 系统栏自身透明，让页面 expandSafeArea 绘出的深色/浅纸背景真实露出；
      // 控件继续按系统安全区避让，浅纸记忆页可自行选深色文字而不撞上不透明暗栏。
      // 不把窗口改成全屏布局后再靠固定高度补状态栏，手机和平板的避让尺寸不同。
      const mainWindow = windowStage.getMainWindowSync();
      // setWindowBackgroundColor 在本机SDK标为不支持phone/tablet，实测也抛错；
      // 不调用它，避免外观兜底先失败后跳过真正受支持的系统栏设置。
      await mainWindow.setWindowLayoutFullScreen(false).catch(() => {
        hilog.warn(DOMAIN, 'PaperWindow', 'System safe-area layout kept its default.');
      });
      await mainWindow.setWindowSystemBarProperties({ statusBarColor: '#00000000',
        statusBarContentColor: '#FFF4ECD9', navigationBarColor: '#00000000',
        navigationBarContentColor: '#FFF4ECD9' }).catch(() => {
        hilog.warn(DOMAIN, 'PaperWindow', 'System bar appearance was not applied.');
      });
    } catch (_error) {
      hilog.warn(DOMAIN, 'PaperWindow', 'Window background kept its system default.');
    }

    // 系统栏不受支持时仍加载正式页面，不能让外观设置失败阻断本地文化与记忆。
    windowStage.loadContent('pages/Index', storage, (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    this.sharedStorage.setOrCreate('appForeground', true);
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    this.sharedStorage.setOrCreate('appForeground', false);
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
