import { abilityDelegatorRegistry, ON } from '@kit.TestKit';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { hdsMaterial } from '@kit.UIDesignKit';
import { describe, expect, it } from '@ohos/hypium';
import { HarmonyEffects } from '../../../main/ets/platform/HarmonyEffects';
import { ArchiveUiSession } from './ArchiveUiSession';
import { TestContext } from './TestContext';

async function capture(session: ArchiveUiSession, name: string): Promise<void> {
  try {
    await session.driver.delayMs(500);
    const delegator = abilityDelegatorRegistry.getAbilityDelegator();
    await delegator.executeShellCommand(`uitest screenCap -p /data/local/tmp/yunheji-immersive-${name}.png`);
    await delegator.executeShellCommand(`uitest dumpLayout -p /data/local/tmp/yunheji-immersive-${name}.json`);
  } catch (error) { throw new Error(`IMMERSIVE_CAPTURE_FAILED: ${(error as Error).message}`); }
}

async function setToggle(session: ArchiveUiSession, id: string, enabled: boolean): Promise<void> {
  const control = await session.inScroll('profile-scroll', ON.id(id));
  expect(await control.isChecked()).assertEqual(!enabled);
  const bounds = await control.getBounds();
  // 当前模拟器上 Component.click 的默认中心点击曾返回成功却没有改变 Switch。
  // 根据当前稳定范围触摸真实滑块中心，仍只点一次，并由 checked / 落盘双重核对。
  const thumbX = enabled ? bounds.left + (bounds.bottom - bounds.top) / 2
    : bounds.right - (bounds.bottom - bounds.top) / 2;
  await session.driver.click(Math.round(thumbX), Math.round((bounds.top + bounds.bottom) / 2));
  // 原节点仍然 enabled 不等于手势已经改变开关。先等原生 checked 状态真正翻转，
  // 再等保存锁释放与坐标稳定；不重复点击掩盖未响应，也不绕过后续的磁盘回读断言。
  await session.wait(ON.id(id).checked(enabled), `${id} -> ${enabled}`);
}

async function checkBars(session: ArchiveUiSession): Promise<void> {
  const top = await (await session.waitId('top-navigation-content')).getBounds();
  const dock = await (await session.waitId('tab-0')).getBounds();
  const display = await session.driver.getDisplaySize();
  expect(top.left >= 0 && top.right <= display.x && top.top >= 0).assertTrue();
  expect(top.bottom < dock.top && dock.bottom <= display.y).assertTrue();
  const action = await (await session.waitId('top-collection')).getBounds();
  expect(action.left >= top.left && action.right <= top.right && action.bottom <= top.bottom).assertTrue();
}

export default function archiveImmersiveTest() {
  const params = abilityDelegatorRegistry.getArguments().parameters;
  const requested = params['class'] || params['-s class'] || '';
  // 显式运行的原生材质审查，默认 12 项功能套件数量不变。全部使用独立测试库，
  // 核对真实开关落盘、导航和遮挡；静态截图不作为触点光效帧率或功耗结论。
  if (!requested.includes('ArchiveImmersiveTest')) return;
  describe('ArchiveImmersiveTest', () => {
    it('native_hds_bars_and_saved_material_preferences', 0, async () => {
      const app = TestContext.context.getApplicationContext();
      const originalScale = TestContext.context.config.fontSizeScale || 1;
      const session = new ArchiveUiSession('hds_preferences');
      try {
        app.setFontSizeScale(1);
        await session.run(async () => {
          app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
          const types = hdsMaterial.getSystemMaterialTypes();
          console.info(`HDS_CAPABILITY: types=${JSON.stringify(types)}, uiMaterial=${HarmonyEffects.supported()}`);
          expect(HarmonyEffects.nativeMaterialType(true, false)).assertEqual(types.includes(hdsMaterial.MaterialType.IMMERSIVE)
            ? hdsMaterial.MaterialType.IMMERSIVE : hdsMaterial.MaterialType.ADAPTIVE);
          await checkBars(session);
          await capture(session, 'home');
          await session.inScroll('explore-scroll', ON.id('site-row-smx-yangshao').within(ON.id('explore-site-grid')));
          await capture(session, 'scrolled');
          // Component.scrollToBottom 的默认手势会从浮动 Dock 内开始，可能误切页。
          // 使用已避开覆盖区的真实滚动定位，并断言当前页尾；截图文件存在不等于场景正确。
          const footer = await session.inScroll('explore-scroll', ON.text('图形为主题示意 · 文化内容初稿待校审'));
          expect(await footer.getText()).assertEqual('图形为主题示意 · 文化内容初稿待校审');
          await session.waitId('explore-scroll');
          await capture(session, 'scroll-bottom');
          await (await session.waitId('top-collection')).click();
          await session.waitId('collection-filter');
          await (await session.waitId('profile-entry')).click();
          await session.inScroll('profile-scroll', ON.id('light-enabled'));
          expect(await (await session.waitId('native-material-capability')).getText()).assertEqual(HarmonyEffects.hdsSupported()
            ? '原生沉浸光感' : '系统自适应材质');
          await setToggle(session, 'light-enabled', false);
          expect((await session.read()).lightEnabled).assertFalse();
          expect(HarmonyEffects.nativeMaterialType(false, false)).assertEqual(hdsMaterial.MaterialType.NONE);
          await session.driver.pressBack();
          await (await session.waitId('tab-0')).click();
          await session.inScroll('explore-scroll', ON.text('沿河，遇见文明'));
          await checkBars(session);
          await capture(session, 'disabled');
          await (await session.waitId('profile-entry')).click();
          await setToggle(session, 'light-enabled', true);
          expect((await session.read()).lightEnabled).assertTrue();
          await setToggle(session, 'reduced-motion', true);
          expect((await session.read()).reducedMotion).assertTrue();
          expect(HarmonyEffects.nativeMaterialType(true, true)).assertEqual(hdsMaterial.MaterialType.NONE);
          await session.driver.pressBack();
          await (await session.waitId('tab-0')).click();
          await session.inScroll('explore-scroll', ON.text('沿河，遇见文明'));
          await capture(session, 'reduced');
          await (await session.waitId('profile-entry')).click();
          await setToggle(session, 'reduced-motion', false);
          expect((await session.read()).reducedMotion).assertFalse();
        });
      } finally {
        app.setFontSizeScale(originalScale);
        app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
    });

    it('native_hds_bars_dark_large_text_and_detail_return', 0, async () => {
      const app = TestContext.context.getApplicationContext();
      const originalScale = TestContext.context.config.fontSizeScale || 1;
      const session = new ArchiveUiSession('hds_appearance');
      try {
        app.setFontSizeScale(1);
        await session.run(async () => {
          app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
          await checkBars(session);
          await capture(session, 'dark');
          await session.inScroll('explore-scroll', ON.id('site-row-smx-yangshao').within(ON.id('explore-site-grid')));
          await capture(session, 'scrolled-dark');
          app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
          app.setFontSizeScale(1.5);
          await session.stop();
          await session.start();
          await checkBars(session);
          await capture(session, 'large');
          await session.inScroll('explore-scroll', ON.id('featured-site'));
          await (await session.waitId('featured-site')).click();
          await session.inScroll('detail-scroll', ON.id('write-note'));
          await capture(session, 'detail-large');
          await session.driver.pressBack();
          await session.waitId('native-dock');
          await session.inScroll('explore-scroll', ON.text('沿河，遇见文明'));
          await checkBars(session);
        });
      } finally {
        app.setFontSizeScale(originalScale);
        app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
    });
  });
}
