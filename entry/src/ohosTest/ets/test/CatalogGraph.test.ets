import { abilityDelegatorRegistry, ON } from '@kit.TestKit';
import { preferences } from '@kit.ArkData';
import { describe, expect, it } from '@ohos/hypium';
import { HERITAGE_SITES } from '../../../main/ets/data/HeritageCatalog';
import { activeRecords, copySnapshot, HeritageSite } from '../../../main/ets/domain/ArchiveDomain';
import { LocalArchiveRepository } from '../../../main/ets/data/LocalArchiveRepository';
import { ArchiveUiSession } from './ArchiveUiSession';

async function capture(session: ArchiveUiSession, name: string): Promise<void> {
  await session.driver.delayMs(350);
  await abilityDelegatorRegistry.getAbilityDelegator().executeShellCommand(
    `uitest screenCap -p /data/local/tmp/yunheji-expanded-${name}.png`);
}

async function checkSourceNotice(session: ArchiveUiSession, title: string): Promise<void> {
  const scroll = await session.waitId('detail-scroll');
  await scroll.scrollToBottom(40000);
  let reviewSeen: boolean = false;
  let sourceSeen: boolean = false;
  // 新增详情正文较长，设备 scrollSearch 会反复小幅滚动。改为有上限的实际手势，
  // 仍核对真正显示的初稿标记及来源，不用目录字段替代界面结果，也不无限等待。
  for (let attempt = 0; attempt < 9; attempt++) {
    reviewSeen = reviewSeen || !!(await session.driver.findComponent(ON.text('初稿待校审').within(ON.id('detail-scroll'))));
    sourceSeen = sourceSeen || !!(await session.driver.findComponent(ON.text(title).within(ON.id('detail-scroll'))));
    if (reviewSeen && sourceSeen) return;
    const bounds = await scroll.getBounds();
    const centerX = Math.round((bounds.left + bounds.right) / 2);
    await session.driver.swipe(centerX, bounds.top + 280, centerX, bounds.bottom - 280, 2500);
    await session.driver.delayMs(250);
  }
  expect(reviewSeen).assertTrue();
  expect(sourceSeen).assertTrue();
}

async function checkNewSites(sites: HeritageSite[], scenario: string): Promise<void> {
  const session = new ArchiveUiSession(scenario);
  await session.run(async () => {
    for (const site of sites) {
      await session.search(site.name, 1);
      await (await session.inScroll('explore-scroll', ON.id(`site-row-${site.id}`).within(ON.id('explore-site-grid')))).click();
      await session.waitId('detail-scroll');
      await session.inScroll('detail-scroll', ON.text(site.summary));
      await checkSourceNotice(session, site.source.title);
      expect(activeRecords((await session.read()).records, 'progress').some(record => record.siteId === site.id)).assertTrue();
      console.info(`CATALOG_DETAIL_VERIFIED:${site.id}`);
      if (site.id === sites[sites.length - 1].id) await capture(session, scenario);
      await session.driver.pressBack();
    }
    await session.search('', HERITAGE_SITES.length);
    await capture(session, `${scenario}-list`);
  });
}

export default function catalogGraphTest() {
  const params = abilityDelegatorRegistry.getArguments().parameters;
  const requested = params['class'] || params['-s class'] || '';
  if (!requested.includes('CatalogGraphTest')) return;
  describe('CatalogGraphTest', () => {
    it('new_smx_and_luoyang_sites_open_from_real_search', 0, async () => {
      await checkNewSites(HERITAGE_SITES.slice(5, 10), 'catalog_smx_ly');
    });
    it('new_zhengzhou_kaifeng_puyang_sites_open_from_real_search', 0, async () => {
      await checkNewSites(HERITAGE_SITES.slice(10), 'catalog_zz_kf_py');
    });
    it('offline_web_graph_bridge_and_reduced_motion', 0, async () => {
      const session = new ArchiveUiSession('graph_web');
      await session.run(async () => {
        // 只在本轮独立测试库设定减少动态，随后重建真实页面并回读磁盘。
        const snapshot = copySnapshot(await session.read());
        snapshot.reducedMotion = true;
        snapshot.lightEnabled = false;
        const repository = new LocalArchiveRepository(session.context, session.name);
        await repository.load();
        await repository.save(snapshot);
        await preferences.removePreferencesFromCache(session.context, session.name);
        await session.stop(); await session.start();
        await (await session.inScroll('explore-scroll', ON.id('culture-atlas-entry'))).click();
        const state = await session.inScroll('culture-atlas-scroll', ON.id('culture-graph-status').text('点选节点查看关联 · 已减少动态'));
        expect(await state.getText()).assertEqual('点选节点查看关联 · 已减少动态');
        await (await session.waitId('culture-atlas-scroll')).scrollToTop(40000);
        // 直接点击 ArkWeb 内的 HTML 节点，原生索引不能代替桥接回调的验证。
        // 本机 ArkWeb 将 aria-label 暴露为 toggleButton.text，description 为空。
        const node = await session.wait(ON.text('仰韶村遗址，三门峡，仰韶，查看关联').type('toggleButton'), 'ArkWeb 仰韶村节点');
        await node.click();
        expect(await (await session.inScroll('culture-atlas-scroll', ON.id('culture-selected-name'))).getText()).assertEqual('仰韶村遗址');
        await (await session.waitId('culture-atlas-scroll')).scrollToTop(40000);
        await capture(session, 'graph-reduced');
        await (await session.inScroll('culture-atlas-scroll', ON.id('culture-index-expand'))).click();
        await (await session.inScroll('culture-atlas-scroll', ON.id('culture-node-py-xishuipo'))).click();
        expect(await (await session.inScroll('culture-atlas-scroll', ON.id('culture-selected-name'))).getText()).assertEqual('西水坡遗址');
        expect((await session.read()).lightEnabled).assertFalse();
        expect((await session.read()).reducedMotion).assertTrue();
      });
    });
    it('animated_web_nodes_accept_real_click_and_drag', 0, async () => {
      const session = new ArchiveUiSession('graph_drag');
      await session.run(async () => {
        await (await session.inScroll('explore-scroll', ON.id('culture-atlas-entry'))).click();
        await session.inScroll('culture-atlas-scroll', ON.id('culture-graph-status').text('拖动节点 · 点选查看关联'));
        await (await session.waitId('culture-atlas-scroll')).scrollToTop(40000);
        const target = ON.text('仰韶村遗址，三门峡，仰韶，查看关联').type('toggleButton');
        const node = await session.wait(target, '可拖动 ArkWeb 节点');
        await node.click();
        expect(await (await session.inScroll('culture-atlas-scroll', ON.id('culture-selected-name'))).getText()).assertEqual('仰韶村遗址');
        await (await session.waitId('culture-atlas-scroll')).scrollToTop(40000);
        const before = await (await session.wait(target)).getBounds();
        const startX = Math.round((before.left + before.right) / 2);
        const startY = Math.round((before.top + before.bottom) / 2);
        await session.driver.drag(startX, startY, startX + 110, startY + 70, 700);
        await session.driver.delayMs(1000);
        const after = await (await session.wait(target)).getBounds();
        const canvas = await (await session.waitId('culture-web-canvas')).getBounds();
        expect(Math.abs(after.left - before.left) + Math.abs(after.top - before.top) > 15).assertTrue();
        expect(after.left >= canvas.left && after.right <= canvas.right && after.bottom <= canvas.bottom).assertTrue();
        await capture(session, 'graph-drag');
        expect(await (await session.inScroll('culture-atlas-scroll', ON.id('culture-selected-name'))).getText()).assertEqual('仰韶村遗址');
      });
    });
  });
}
