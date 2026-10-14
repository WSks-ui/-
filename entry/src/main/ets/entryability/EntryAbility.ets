import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DEBUG } from 'BuildProfile';
import { archiveStoreForLaunch, DEFAULT_ARCHIVE_STORE } from '../platform/ArchiveLaunch';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private archiveStoreName: string = DEFAULT_ARCHIVE_STORE;
  private sharedStorage: LocalStorage = new LocalStorage();

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.archiveStoreName = archiveStoreForLaunch(want.parameters?.['yunhejiTestStore'], DEBUG);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // 用窗口级 LocalStorage 传递库名，避免 AppStorage 在多个 Ability 之间串库。
    const storage = this.sharedStorage;
    storage.setOrCreate('archiveStoreName', this.archiveStoreName);
    storage.setOrCreate('appForeground', true);
    windowStage.loadContent('pages/Index', storage, (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
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
