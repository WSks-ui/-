import { UIAbility } from '@kit.AbilityKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { Hypium } from '@ohos/hypium';
import testsuite from './test/List.test';
import { TestContext } from './test/TestContext';
import { window } from '@kit.ArkUI';

export default class TestAbility extends UIAbility {
  onCreate(): void {
    TestContext.context = this.context;
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 保留一个真正的测试宿主窗口。否则关闭最后一个 EntryAbility 时，系统会结束
    // 没有窗口的测试进程，Hypium 无法输出失败摘要，也无法继续验证 Ability 重建。
    windowStage.loadContent('pages/TestHost', (error) => {
      if (error.code) {
        abilityDelegatorRegistry.getAbilityDelegator().finishTest('TestHost failed to load', -1, () => {});
        return;
      }
      Hypium.hypiumTest(abilityDelegatorRegistry.getAbilityDelegator(),
        abilityDelegatorRegistry.getArguments(), testsuite);
    });
  }
}
