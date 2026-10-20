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
    it('water_card_opens_live_page', 0, async () => {
      const session = new ArchiveUiSession('water_situation', '', true);
      await session.run(async () => {
        await session.inScroll('explore-scroll', ON.id('water-entry'));
        await capture('home-entry');
        await (await session.waitId('water-entry')).click();
        await session.waitId('water-page');
        // 页面优先读服务端实时水情，失败才回退公开报道；断言状态明确、数值带单位，
        // 不把某一天的数值写死，避免日报更新后误报。
        let status = await (await session.waitId('water-data-status')).getText();
        if (status.includes('正在更新')) {
          await new Promise<void>((resolve) => { setTimeout(resolve, 2000); });
          status = await (await session.waitId('water-data-status')).getText();
        }
        expect(status.includes('实时') || status.includes('更新') || status.includes('离线')).assertTrue();
        // 大数字与单位分开排版，这里只断言数值存在且不是缺测占位。
        const level = await (await session.waitId('water-latest-level')).getText();
        const flow = await (await session.waitId('water-latest-flow')).getText();
        expect(level.length > 0 && level !== '—').assertTrue();
        expect(flow.length > 0 && flow !== '—').assertTrue();
        await capture('hero');
        // 三站对照与花园口故事分段截图；首屏已包含对照卡，底部再确认故事卡。
        await session.inScroll('water-scroll', ON.id('water-chart'));
        await session.inScroll('water-scroll', ON.id('water-story'));
        await capture('story');
      });
    });
  });
}
