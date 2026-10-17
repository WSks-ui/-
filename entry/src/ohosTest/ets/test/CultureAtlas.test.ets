import { abilityDelegatorRegistry, Component, ON, On } from '@kit.TestKit';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { describe, expect, it } from '@ohos/hypium';
import { activeRecords } from '../../../main/ets/domain/ArchiveDomain';
import { ArchiveUiSession } from './ArchiveUiSession';
import { TestContext } from './TestContext';

async function capture(session: ArchiveUiSession, name: string): Promise<void> {
  await session.driver.delayMs(300);
  await abilityDelegatorRegistry.getAbilityDelegator().executeShellCommand(
    `uitest screenCap -p /data/local/tmp/yunheji-culture-${name}.png`);
}

async function atlasSwipe(session: ArchiveUiSession, towardTop: boolean): Promise<void> {
  const bounds = await (await session.waitId('culture-atlas-scroll')).getBounds();
  // Web 节点支持拖动。滚动手势必须从 Scroll 左侧原生留白处发起，
  // 否则 scrollSearch 会反复拖动节点而不滚动页面，并持续到 Hypium 超时。
  const x = bounds.left + 18;
  const upper = bounds.top + 220;
  const lower = bounds.bottom - 220;
  await session.driver.swipe(x, towardTop ? upper : lower, x, towardTop ? lower : upper, 2500);
  await session.driver.delayMs(250);
}

async function atlasTop(session: ArchiveUiSession): Promise<void> {
  for (let attempt = 0; attempt < 12; attempt++) {
    const scroll = await (await session.waitId('culture-atlas-scroll')).getBounds();
    const title = await session.driver.findComponent(ON.text('一条河，许多种相遇'));
    if (title && (await title.getBounds()).top >= scroll.top + 16) return;
    await atlasSwipe(session, true);
  }
  throw new Error('ATLAS_TOP_NOT_REACHED');
}

async function inAtlas(session: ArchiveUiSession, target: On): Promise<Component> {
  const exposed = async (): Promise<boolean> => {
    const node = await session.driver.findComponent(target);
    if (!node) return false;
    const bounds = await node.getBounds();
    const scroll = await (await session.waitId('culture-atlas-scroll')).getBounds();
    const center = (bounds.top + bounds.bottom) / 2;
    return bounds.bottom - bounds.top > 12 && center >= scroll.top + 80 && center <= scroll.bottom - 80;
  };
  if (await exposed()) return session.wait(target);
  await atlasTop(session);
  for (let attempt = 0; attempt < 16; attempt++) {
    if (await exposed()) return session.wait(target);
    await atlasSwipe(session, false);
  }
  throw new Error('ATLAS_SCROLL_TARGET_NOT_FOUND');
}

export default function cultureAtlasTest() {
  const params = abilityDelegatorRegistry.getArguments().parameters;
  const requested = params['class'] || params['-s class'] || '';
  if (!requested.includes('CultureAtlasTest')) return;
  describe('CultureAtlasTest', () => {
    it('visible_graph_compare_and_personal_note_topic', 0, async () => {
      const session = new ArchiveUiSession('culture_atlas');
      await session.run(async () => {
        await capture(session, 'home');
        await (await session.inScroll('explore-scroll', ON.id('culture-atlas-entry'))).click();
        await session.waitId('culture-graph');
        expect(await (await inAtlas(session, ON.id('culture-selected-name'))).getText()).assertEqual('二里头遗址');
        await atlasTop(session);
        await inAtlas(session, ON.id('culture-graph-status').text('拖动节点 · 点选查看关联'));
        await atlasTop(session);
        await capture(session, 'graph');
        await (await inAtlas(session, ON.id('culture-node-smx-yangshao'))).click();
        expect(await (await inAtlas(session, ON.id('culture-selected-name'))).getText()).assertEqual('仰韶村遗址');
        await (await inAtlas(session, ON.id('culture-node-ly-erlitou'))).click();
        expect(await (await inAtlas(session, ON.id('culture-selected-name'))).getText()).assertEqual('二里头遗址');
        await (await inAtlas(session, ON.id('culture-compare-zz-shang'))).click();
        expect(await (await session.waitId('compare-left-name')).getText()).assertEqual('二里头遗址');
        expect(await (await session.waitId('compare-right-name')).getText()).assertEqual('郑州商城遗址');
        await session.waitText('同属夏商时期');
        await capture(session, 'compare');
        await (await session.waitId('culture-comparison-close')).click();
        await (await inAtlas(session, ON.id('culture-open-site'))).click();
        await (await session.inScroll('detail-scroll', ON.id('favorite-toggle'))).click();
        await (await session.inScroll('detail-scroll', ON.id('write-note'))).click();
        await session.pasteInto('note-body', '从宫殿与道路，观察早期城市的空间。');
        await session.pasteInto('note-tags', '都城研学');
        await (await session.waitId('save-note')).click();
        await session.editorClosed();
        expect(activeRecords((await session.read()).records, 'note')[0].tags[0]).assertEqual('都城研学');
        await session.driver.pressBack();
        // 第二座遗址也通过真实界面写入同一标签，演示用户记录实际生成专题连线。
        await (await inAtlas(session, ON.id('culture-node-zz-shang'))).click();
        await (await inAtlas(session, ON.id('culture-open-site'))).click();
        await (await session.inScroll('detail-scroll', ON.id('write-note'))).click();
        await session.pasteInto('note-body', '从城垣与手工业，比较商代城市的生活。');
        await session.pasteInto('note-tags', '都城研学');
        await (await session.waitId('save-note')).click();
        await session.editorClosed();
        expect(activeRecords((await session.read()).records, 'note').length).assertEqual(2);
        await session.driver.pressBack();
        await (await inAtlas(session, ON.text('我的图谱'))).click();
        await session.waitId('culture-topic-filter');
        await session.select('culture-topic-filter', '都城研学');
        expect(await (await session.waitId('culture-atlas-count')).getText()).assertEqual('2 处档案 · 1 条关联线索');
        await session.waitId('culture-node-ly-erlitou');
        await session.waitId('culture-node-zz-shang');
        await (await session.waitId('culture-node-ly-erlitou')).click();
        await inAtlas(session, ON.text('从宫殿与道路，观察早期城市的空间。'));
        await capture(session, 'personal');
        await (await inAtlas(session, ON.id('culture-compare-zz-shang'))).click();
        await session.inScroll('culture-comparison-scroll', ON.text('我的专题：都城研学'));
        await capture(session, 'personal-compare');
        await (await session.waitId('culture-comparison-close')).click();
      });
    });

    it('visible_graph_dark_and_large_text', 0, async () => {
      const app = TestContext.context.getApplicationContext();
      const scale = TestContext.context.config.fontSizeScale || 1;
      const session = new ArchiveUiSession('culture_appearance');
      try {
        app.setFontSizeScale(1);
        await session.run(async () => {
          // EntryAbility 启动时恢复跟随系统，外观覆盖必须在窗口就绪后设置。
          // 核对实际资源，不能仅凭名为 dark 的截图就宣称深色已生效。
          app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
          await session.driver.delayMs(500);
          expect(session.context.resourceManager.getColorByNameSync('canvas') & 0xFFFFFF).assertEqual(0x211D20);
          await (await session.inScroll('explore-scroll', ON.id('culture-atlas-entry'))).click();
          await session.waitId('culture-graph');
          await inAtlas(session, ON.id('culture-graph-status').text('拖动节点 · 点选查看关联'));
          await atlasTop(session);
          await capture(session, 'dark');
          app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
          app.setFontSizeScale(1.5);
          await session.stop();
          await session.start();
          app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
          await session.driver.delayMs(500);
          const ability = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility();
          expect(ability.context.config.fontSizeScale).assertEqual(1.5);
          await (await session.inScroll('explore-scroll', ON.id('culture-atlas-entry'))).click();
          // 图形已扩展为 15 节点，原生索引位于画布下方；先滚到真正可见的索引再测点击范围。
          const first = await (await inAtlas(session, ON.id('culture-node-smx-yangshao'))).getBounds();
          const right = await (await session.waitId('culture-node-ly-erlitou')).getBounds();
          expect(first.right < right.left).assertTrue();
          const display = await session.driver.getDisplaySize();
          expect(first.left >= 0 && right.right <= display.x).assertTrue();
          await capture(session, 'large');
        });
      } finally {
        app.setFontSizeScale(scale);
        app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
    });
  });
}
