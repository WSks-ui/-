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
        // 页面优先读服务端实时水情，失败才回退公开报道；断言状态明确、数值带单位，
        // 不把某一天的数值写死，避免日报更新后误报。
        let status = await (await session.waitId('water-data-status')).getText();
        if (status.includes('读取中')) {
          await new Promise<void>((resolve) => { setTimeout(resolve, 2000); });
          status = await (await session.waitId('water-data-status')).getText();
        }
        expect(status.includes('实时') || status.includes('上次快照') || status.includes('离线')).assertTrue();
        expect((await (await session.waitId('water-latest-level')).getText()).includes('m')).assertTrue();
        expect((await (await session.waitId('water-latest-flow')).getText()).includes('m³/s')).assertTrue();
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
