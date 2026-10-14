import { abilityDelegatorRegistry, ON } from '@kit.TestKit';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { describe, expect, it } from '@ohos/hypium';
import { ArchiveUiSession } from './ArchiveUiSession';
import { TestContext } from './TestContext';

async function capture(session: ArchiveUiSession, name: string): Promise<void> {
  // 只截取独立测试库的真实应用窗口。截图供人工视觉验收，存在文件不能替代视觉判断。
  await session.driver.delayMs(500);
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  await delegator.executeShellCommand(`uitest screenCap -p /data/local/tmp/yunheji-design-${name}.png`);
  await delegator.executeShellCommand(`uitest dumpLayout -p /data/local/tmp/yunheji-design-${name}.json`);
}

async function visibleControl(session: ArchiveUiSession, id: string): Promise<void> {
  const control = await session.waitId(id);
  const bounds = await control.getBounds();
  const display = await session.driver.getDisplaySize();
  expect(bounds.left >= 0 && bounds.top >= 0 && bounds.right <= display.x && bounds.bottom <= display.y).assertTrue();
  expect(bounds.right > bounds.left && bounds.bottom > bounds.top).assertTrue();
}

export default function archiveAppearanceTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requestedClass = parameters['class'] || parameters['-s class'] || '';
  // 外观审查只按显式 class 注册，不改变默认 12 项功能回归，也不往主应用加入调试入口。
  if (!requestedClass.includes('ArchiveAppearanceTest')) return;
  describe('ArchiveAppearanceTest', () => {
    it('native_light_dark_and_large_text_review', 0, async () => {
      const app = TestContext.context.getApplicationContext();
      const originalScale = TestContext.context.config.fontSizeScale || 1;
      const session = new ArchiveUiSession('appearance');
      try {
        app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
        app.setFontSizeScale(1);
        await session.run(async () => {
          await capture(session, 'home');
          await session.inScroll('explore-scroll', ON.id('search-result-count'));
          await session.inScroll('explore-scroll', ON.id('site-row-smx-yangshao').within(ON.id('explore-site-grid')));
          await capture(session, 'catalog');
          await (await session.waitId('explore-scroll')).scrollToTop(40000);
          // 首屏三个快捷入口必须使用真实导航，不用装饰卡片冒充功能。
          await (await session.waitId('memory-entry')).click();
          await session.waitId('collection-filter');
          await (await session.waitId('tab-0')).click();
          await (await session.waitId('featured-site')).click();
          await visibleControl(session, 'write-note');
          await capture(session, 'detail');
          await (await session.waitId('favorite-toggle')).click();
          await session.waitText('已收藏');
          await (await session.waitId('write-note')).click();
          await capture(session, 'editor');
          await (await session.waitId('note-body')).inputText('从器物的纹饰开始，记下一个想继续阅读的问题。');
          await (await session.inScroll('note-editor-scroll', ON.id('note-tags'))).inputText('彩陶，阅读手记');
          await visibleControl(session, 'save-note');
          await (await session.waitId('save-note')).click();
          await session.editorClosed();
          await session.driver.pressBack();
          await (await session.waitId('tab-1')).click();
          await session.waitId('collection-filter');
          expect(await (await session.waitId('collection-count')).getText()).assertEqual('1');
          expect(await (await session.waitId('note-count')).getText()).assertEqual('1');
          await capture(session, 'collection');
          await (await session.waitId('tab-2')).click();
          await session.inScroll('device-scroll', ON.id('last-sync-value'));
          await capture(session, 'device');

          app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
          await (await session.waitId('tab-0')).click();
          await (await session.waitId('explore-scroll')).scrollToTop(40000);
          await capture(session, 'home-dark');
          await (await session.waitId('featured-site')).click();
          await visibleControl(session, 'write-note');
          await capture(session, 'detail-dark');

          app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
          app.setFontSizeScale(1.5);
          // 重建 EntryAbility，让纸片高度读取本次真实字体配置；档案仍使用同一专属库。
          await session.stop();
          await session.start();
          // 卡片内容必须全部在纸片范围内；仅检查按钮可点击会漏掉大字时文字溢出容器。
          const content = await (await session.waitId('memory-content')).getBounds();
          const paper = await (await session.waitId('memory-paper')).getBounds();
          expect(content.bottom <= paper.bottom).assertTrue();
          await capture(session, 'home-large');
          await session.inScroll('explore-scroll', ON.id('featured-site'));
          await visibleControl(session, 'featured-site');
          await (await session.waitId('featured-site')).click();
          await session.inScroll('detail-scroll', ON.id('write-note'));
          await visibleControl(session, 'write-note');
          await (await session.waitId('write-note')).click();
          await (await session.waitId('note-body')).inputText('放大字体后的输入检查');
          await session.inScroll('note-editor-scroll', ON.id('note-tags'));
          await visibleControl(session, 'save-note');
          await visibleControl(session, 'close-note-editor');
          await capture(session, 'editor-large-keyboard');
          await (await session.waitId('close-note-editor')).click();
          await (await session.waitText('放弃修改')).click();
          await session.editorClosed();
        });
      } finally {
        // 恢复应用配置，不修改系统全局外观、字体或正式用户数据。
        app.setFontSizeScale(originalScale);
        app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
    });
  });
}
