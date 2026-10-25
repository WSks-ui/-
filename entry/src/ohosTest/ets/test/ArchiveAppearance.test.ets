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
          await (await session.waitId('tab-2')).click();
          await session.inScroll('device-scroll', ON.id('library-result-count'));
          await session.inScroll('device-scroll', ON.id('site-row-smx-yangshao').within(ON.id('archive-library-grid')));
          await capture(session, 'catalog');
          await (await session.waitId('tab-0')).click();
          await (await session.waitId('explore-scroll')).scrollToTop(40000);
          // 首屏快捷入口必须使用真实导航，不用装饰卡片冒充功能。新版首页把“河流记忆”
          // 与“从彩陶读起”放到纸页入口区，先滚动到真实控件再点击，断言不变。
          await (await session.inScroll('explore-scroll', ON.id('memory-entry'))).click();
          // 记忆页默认是“手账”分区，收藏筛选只在“收藏”分区出现；
          // 外观用例显式切到收藏，避免把默认分区当成固定前提。
          await session.waitId('memory-section-0');
          await (await session.inScroll('archive-scroll', ON.id('memory-section-1'))).click();
          await session.waitId('collection-filter');
          await (await session.waitId('tab-0')).click();
          await (await session.inScroll('explore-scroll', ON.id('featured-site'))).click();
          // 详情第一屏是文化视口，收藏与写手账在下方；按真实详情 Scroll 滚到控件再核对可见范围。
          await session.inScroll('detail-scroll', ON.id('write-note'));
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
          // 统计与筛选不在同一屏：先读顶部统计，再滚动到真实筛选控件截图。
          expect(await (await session.waitId('collection-count')).getText()).assertEqual('1');
          expect(await (await session.waitId('note-count')).getText()).assertEqual('1');
          await session.inScroll('archive-scroll', ON.id('collection-filter'));
          await capture(session, 'collection');
          await (await session.waitId('profile-entry')).click();
          // 个人页是独立导航页，先等滚动容器挂载；同步值在“账号与同步”分区内，
          // 外观用例只需要个人页主视图，不把账号分区是否展开当成前提。
          await session.waitId('profile-scroll');
          await capture(session, 'device');

          app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
          await session.driver.pressBack();
          await (await session.waitId('tab-0')).click();
          await (await session.waitId('explore-scroll')).scrollToTop(40000);
          await capture(session, 'home-dark');
          await (await session.inScroll('explore-scroll', ON.id('featured-site'))).click();
          await session.inScroll('detail-scroll', ON.id('write-note'));
          await capture(session, 'detail-dark');

          app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
          app.setFontSizeScale(1.5);
          // 重建 EntryAbility，让纸片高度读取本次真实字体配置；档案仍使用同一专属库。
          // 已知未通过（2026-10-20）：stop/start 后 Ability 未存活，后续在 archive-scroll
          // 处报目标不存在；设备 faultlogger 没有当日新 crash / freeze。修复重启流程前不得记为通过。
          await session.stop();
          await session.start();
          // 重建 EntryAbility 后回到首页，先显式进入记忆页再核对大字布局；
          // 不能沿用重启前的页面位置，否则会把“当前不在记忆页”误报成文字溢出。
          await (await session.waitId('tab-1')).click();
          // 1.5 倍字体下纸片可能被推到首屏之外；先把纸片滚入视口，再同时读取内外边界，
          // 避免因“未可见”把正常布局误报为文字溢出。
          await session.inScroll('archive-scroll', ON.id('memory-paper'));
          const content = await (await session.waitId('memory-content')).getBounds();
          const paper = await (await session.waitId('memory-paper')).getBounds();
          expect(content.bottom <= paper.bottom).assertTrue();
          await capture(session, 'home-large');
          await (await session.waitId('tab-0')).click();
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
