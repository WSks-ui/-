import { abilityDelegatorRegistry, ON, PointerMatrix } from '@kit.TestKit';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { describe, expect, it } from '@ohos/hypium';
import { copySnapshot } from '../../../main/ets/domain/ArchiveDomain';
import { HERITAGE_SITES } from '../../../main/ets/data/HeritageCatalog';
import { LocalArchiveRepository } from '../../../main/ets/data/LocalArchiveRepository';
import { ArchiveUiSession } from './ArchiveUiSession';
import { TestContext } from './TestContext';

async function capture(session: ArchiveUiSession, name: string): Promise<void> {
  await session.driver.delayMs(300);
  await abilityDelegatorRegistry.getAbilityDelegator().executeShellCommand(
    `uitest screenCap -p /data/local/tmp/yunheji-spatial-${name}.png`);
}

async function openSite(session: ArchiveUiSession, id: string): Promise<void> {
  const site = HERITAGE_SITES.find(item => item.id === id)!;
  await session.search(site.name, 1);
  await (await session.inScroll('explore-scroll', ON.id(`site-row-${id}`).within(ON.id('explore-site-grid')))).click();
  await session.waitId('site-object-viewport');
  await session.waitText('按档案类型生成的几何示意，非文物或遗址复原。');
}

async function checkObjects(ids: string[], scenario: string): Promise<void> {
  const session = new ArchiveUiSession(scenario);
  await session.run(async () => {
    for (const id of ids) {
      await openSite(session, id);
      if (id === 'smx-yangshao') await capture(session, 'object-before-turn');
      await (await session.waitId('site-object-right')).click();
      const angle = await (await session.waitId('site-object-angle')).getText();
      expect(angle.includes('视角')).assertTrue();
      expect(angle.includes('初始视角')).assertFalse();
      if (id === 'smx-yangshao') await capture(session, 'object-after-turn');
      await (await session.waitId('site-object-reset')).click();
      expect((await (await session.waitId('site-object-angle')).getText()).includes('初始视角')).assertTrue();
      if (id === 'smx-yangshao') {
        const bounds = await (await session.waitId('site-object-viewport')).getBounds();
        const centerX = Math.round((bounds.left + bounds.right) / 2);
        const centerY = Math.round((bounds.top + bounds.bottom) / 2);
        await session.driver.drag(centerX - 100, centerY, centerX + 100, centerY + 20, 700);
        expect((await (await session.waitId('site-object-angle')).getText()).includes('初始视角')).assertFalse();
        await (await session.waitId('site-object-reset')).click();
      }
      await capture(session, id);
      console.info(`NATIVE_OBJECT_VERIFIED:${id}`);
      await session.driver.pressBack();
      await session.waitId('explore-scroll');
    }
  });
}

export default function spatialExperienceTest() {
  const params = abilityDelegatorRegistry.getArguments().parameters;
  const requested = params['class'] || params['-s class'] || '';
  if (!requested.includes('SpatialExperienceTest')) return;
  describe('SpatialExperienceTest', () => {
    it('graph_depth_rotation_and_two_finger_selection', 0, async () => {
      const session = new ArchiveUiSession('spatial_graph');
      await session.run(async () => {
        await (await session.inScroll('explore-scroll', ON.id('culture-atlas-entry'))).click();
        await session.waitId('culture-web-canvas');
        // 180 次有界布局每 40ms 推进，先等真实动画收敛，再比较复位前后的相同视角。
        await session.driver.delayMs(7800);
        const nearTarget = ON.id('graph-canvas-node-smx-yangshao');
        const farTarget = ON.id('graph-canvas-node-kf-iron-pagoda');
        const near = await (await session.wait(nearTarget)).getBounds();
        const far = await (await session.wait(farTarget)).getBounds();
        console.info(`SPATIAL_GRAPH_DEPTH:${near.right - near.left}/${far.right - far.left}`);
        expect(near.right - near.left > far.right - far.left).assertTrue();
        await capture(session, 'graph-depth');
        await (await session.waitId('graph-turn')).click();
        const turned = await (await session.wait(nearTarget)).getBounds();
        console.info(`SPATIAL_GRAPH_TURN:${Math.abs(turned.left - near.left) + Math.abs(turned.top - near.top)}`);
        expect(Math.abs(turned.left - near.left) + Math.abs(turned.top - near.top) > 6).assertTrue();
        await capture(session, 'graph-turned');
        await (await session.waitId('graph-reset')).click();
        const reset = await (await session.wait(nearTarget)).getBounds();
        console.info(`SPATIAL_GRAPH_RESET:${Math.abs(reset.left - near.left) + Math.abs(reset.top - near.top)}`);
        expect(Math.abs(reset.left - near.left) + Math.abs(reset.top - near.top) < 10).assertTrue();
        const canvas = await (await session.waitId('culture-web-canvas')).getBounds();
        const centerX = Math.round((canvas.left + canvas.right) / 2);
        const centerY = Math.round(Math.min(canvas.bottom - 150, (canvas.top + canvas.bottom) / 2));
        const fingers = PointerMatrix.create(2, 3);
        for (let step = 0; step < 3; step++) {
          // PointerMatrix 使用屏幕 px，而 GestureEvent 的位移是 vp；在高密度手机上
          // 保留足够真实行程，不能把很小的手势结果当作视角没有变化。
          fingers.setPoint(0, step, { x: centerX - 90 + step * 100, y: centerY - 60 + step * 12 });
          fingers.setPoint(1, step, { x: centerX + 30 + step * 100, y: centerY + 60 + step * 12 });
        }
        const injected = await session.driver.injectMultiPointerAction(fingers, 500);
        console.info(`SPATIAL_GRAPH_TWO_FINGER_INJECTED:${injected}`);
        expect(injected).assertTrue();
        const rotated = await (await session.wait(nearTarget)).getBounds();
        console.info(`SPATIAL_GRAPH_TWO_FINGER_DELTA:${Math.abs(rotated.left - reset.left) + Math.abs(rotated.top - reset.top)}`);
        expect(Math.abs(rotated.left - reset.left) + Math.abs(rotated.top - reset.top) > 6).assertTrue();
        await capture(session, 'graph-two-finger');
        const beforeDrag = await (await session.wait(nearTarget)).getBounds();
        const dragX = Math.round((beforeDrag.left + beforeDrag.right) / 2);
        const dragY = Math.round((beforeDrag.top + beforeDrag.bottom) / 2);
        await session.driver.drag(dragX, dragY, dragX + 80, dragY + 50, 700);
        const afterDrag = await (await session.wait(nearTarget)).getBounds();
        console.info(`SPATIAL_GRAPH_DRAG:${Math.abs(afterDrag.left - beforeDrag.left) + Math.abs(afterDrag.top - beforeDrag.top)}`);
        expect(Math.abs(afterDrag.left - beforeDrag.left) + Math.abs(afterDrag.top - beforeDrag.top) > 8).assertTrue();
        expect(afterDrag.left >= canvas.left && afterDrag.right <= canvas.right && afterDrag.bottom <= canvas.bottom).assertTrue();
        await capture(session, 'graph-drag');
        await (await session.wait(nearTarget)).click();
        expect(await (await session.inScroll('culture-atlas-scroll', ON.id('culture-selected-name'))).getText()).assertEqual('仰韶村遗址');
      });
    });
    it('graph_reduced_motion_keeps_manual_rotation_and_selection', 0, async () => {
      const session = new ArchiveUiSession('spatial_graph_reduced');
      await session.run(async () => {
        const snapshot = copySnapshot(await session.read());
        snapshot.reducedMotion = true;
        snapshot.lightEnabled = false;
        const repository = new LocalArchiveRepository(session.context, session.name);
        await repository.load(); await repository.save(snapshot);
        await preferences.removePreferencesFromCache(session.context, session.name);
        await session.stop(); await session.start();
        await (await session.inScroll('explore-scroll', ON.id('culture-atlas-entry'))).click();
        await session.waitId('culture-native-canvas');
        const target = ON.id('graph-canvas-node-smx-yangshao');
        const before = await (await session.wait(target)).getBounds();
        await session.driver.delayMs(1200);
        expect(JSON.stringify(await (await session.wait(target)).getBounds())).assertEqual(JSON.stringify(before));
        await (await session.waitId('graph-turn')).click();
        const turned = await (await session.wait(target)).getBounds();
        expect(Math.abs(turned.left - before.left) + Math.abs(turned.top - before.top) > 6).assertTrue();
        await (await session.waitId('graph-reset')).click();
        await capture(session, 'graph-reduced');
        await (await session.wait(target)).click();
        expect(await (await session.inScroll('culture-atlas-scroll', ON.id('culture-selected-name'))).getText()).assertEqual('仰韶村遗址');
        expect((await session.read()).reducedMotion).assertTrue();
        expect((await session.read()).lightEnabled).assertFalse();
      });
    });
    it('native_pottery_terraces_and_city_ring_rotate', 0, async () => {
      await checkObjects(['smx-yangshao', 'ly-erlitou', 'py-qicheng'], 'native_forms_a');
    });
    it('native_tower_and_mound_release_when_leaving', 0, async () => {
      await checkObjects(['kf-iron-pagoda', 'smx-guoguo'], 'native_forms_b');
    });
    it('native_object_reduced_motion_dark_and_large_text', 0, async () => {
      const app = TestContext.context.getApplicationContext();
      const previousScale = TestContext.context.config.fontSizeScale || 1;
      const session = new ArchiveUiSession('native_forms_appearance');
      try {
        await session.run(async () => {
          const snapshot = copySnapshot(await session.read());
          snapshot.reducedMotion = true;
          snapshot.lightEnabled = false;
          const repository = new LocalArchiveRepository(session.context, session.name);
          await repository.load(); await repository.save(snapshot);
          await preferences.removePreferencesFromCache(session.context, session.name);
          await session.stop(); await session.start();
          app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
          await session.driver.delayMs(400);
          await openSite(session, 'smx-yangshao');
          expect(session.context.resourceManager.getColorByNameSync('canvas') & 0xFFFFFF).assertEqual(0x211D20);
          const initial = await (await session.waitId('site-object-angle')).getText();
          const reducedViewport = await (await session.waitId('site-object-viewport')).getBounds();
          console.info(`OBJECT_REDUCED_VIEWPORT:${JSON.stringify(reducedViewport)}`);
          expect(initial.includes('已减少动态')).assertTrue();
          expect(!!(await session.driver.findComponent(ON.id('site-object-motion')))).assertFalse();
          await capture(session, 'object-reduced-before');
          await session.driver.delayMs(1200);
          expect(await (await session.waitId('site-object-angle')).getText()).assertEqual(initial);
          await capture(session, 'object-reduced-after');
          await (await session.waitId('site-object-right')).click();
          expect(await (await session.waitId('site-object-angle')).getText() === initial).assertFalse();
          await capture(session, 'object-dark-reduced');
          await session.stop();
          app.setFontSizeScale(1.5);
          await session.start();
          app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
          await openSite(session, 'kf-iron-pagoda');
          const display = await session.driver.getDisplaySize();
          const viewport = await (await session.waitId('site-object-viewport')).getBounds();
          expect(viewport.left >= 0 && viewport.right <= display.x).assertTrue();
          expect((await session.read()).reducedMotion).assertTrue();
          await capture(session, 'object-large-reduced');
        });
      } finally {
        app.setFontSizeScale(previousScale);
        app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
    });
  });
}
