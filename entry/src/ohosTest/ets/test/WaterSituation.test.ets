import { abilityDelegatorRegistry, ON } from '@kit.TestKit';
import { describe, expect, it } from '@ohos/hypium';
import { ArchiveUiSession } from './ArchiveUiSession';

async function capture(name: string): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  expect((await delegator.executeShellCommand(`uitest screenCap -p /data/local/tmp/water-situation-${name}.png`)).exitCode).assertEqual(0);
  expect((await delegator.executeShellCommand(`uitest dumpLayout -p /data/local/tmp/water-situation-${name}.json`)).exitCode).assertEqual(0);
}

export default function waterSituationTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requested = parameters['class'] || parameters['-s class'] || '';
  // 只按显式 class 注册，避免把水情专项塞进默认长回归。
  if (!requested.includes('WaterSituationTest')) return;
  describe('WaterSituationTest', () => {
    it('water_card_opens_sourced_page', 0, async () => {
      const session = new ArchiveUiSession('water_situation', '', true);
      await session.run(async () => {
        await session.inScroll('explore-scroll', ON.id('water-entry'));
        await capture('home-entry');
        await (await session.waitId('water-entry')).click();
        await session.waitId('water-page');
        // 最新一条是 2026-09-21 的公开报道，不是实时值；页面顶部必须同时给出日期与来源。
        expect(await (await session.waitId('water-latest-level')).getText()).assertEqual('88.42 m');
        expect(await (await session.waitId('water-latest-flow')).getText()).assertEqual('607 m³/s');
        await capture('hero');
        // 流量柱形对照是全页唯一的图形表达，单独滚到并截图，避免只验证文字。
        await session.inScroll('water-scroll', ON.id('water-chart'));
        await capture('chart');
        const disclaimer = await (await session.inScroll('water-scroll', ON.id('water-disclaimer'))).getText();
        expect(disclaimer.includes('非实时')).assertTrue();
        expect(disclaimer.includes('不提供')).assertTrue();
        // 三条来源都在页面底部，滚动后逐条存在。
        await session.inScroll('water-scroll', ON.id('water-source-2'));
        await capture('bottom');
      });
    });
  });
}
