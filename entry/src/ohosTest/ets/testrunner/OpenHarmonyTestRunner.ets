import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit';

export default class OpenHarmonyTestRunner implements TestRunner {
  onPrepare(): void {}

  async onRun(): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator();
    try {
      await delegator.startAbility({
        bundleName: 'com.chr.myapplication', moduleName: 'entry_test', abilityName: 'TestAbility'
      });
    } catch {
      // finishTest 本身也可能拒绝，不能让启动失败路径再产生未处理的 Promise 异常。
      try { await delegator.finishTest('TestAbility failed to start', -1); }
      catch { console.error('TestAbility failed to start; finishTest also failed'); }
    }
  }
}
