import { abilityDelegatorRegistry, Component, ON, On } from '@kit.TestKit';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { describe, expect, it } from '@ohos/hypium';
import { CITIES, HeritageSite } from '../../../main/ets/domain/ArchiveDomain';
import { decodeExplorationProgress } from '../../../main/ets/domain/ExplorationProgress';
import { HERITAGE_SITES } from '../../../main/ets/data/HeritageCatalog';
import { ArchiveUiSession } from './ArchiveUiSession';
import { TestContext } from './TestContext';

interface PageWindow { top: number; bottom: number; left: number; }

async function capture(session: ArchiveUiSession, name: string): Promise<void> {
  // 只截取随机独立库的离线页面，不登录或展示私人账号。原始图与布局一并保留，
  // 画面内容仍须人工查看；日志中的视口范围供主机裁切静帧比较，截图成功不等于渲染通过。
  await session.driver.delayMs(350);
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  const image = await delegator.executeShellCommand(`uitest screenCap -p /data/local/tmp/yunheji-engine-${name}.png`);
  expect(image.exitCode).assertEqual(0);
  const layout = await delegator.executeShellCommand(`uitest dumpLayout -p /data/local/tmp/yunheji-engine-${name}.json`);
  expect(layout.exitCode).assertEqual(0);
}

async function pageWindow(session: ArchiveUiSession, page: string): Promise<PageWindow> {
  // 页面已经存在时直接读取当前范围。旧实现为每次可见性检查重新执行 waitId，
  // 每次至少四轮 bounds / enabled / findComponent，五城二十张卡片会反复等待同一 Scroll。
  // 只有真正跨页面、目标 Scroll 尚未出现时，才沿用会检查动画稳定性的完整等待。
  const current = await session.driver.findComponent(ON.id(page));
  const bounds = await (current || await session.waitId(page)).getBounds();
  let top = bounds.top + 24;
  let bottom = bounds.bottom - 24;
  if (page === 'explore-scroll' || page === 'device-scroll') {
    const header = await session.driver.findComponent(ON.id('top-navigation-content'));
    const dock = await session.driver.findComponent(ON.id('tab-0'));
    if (header) top = Math.max(top, (await header.getBounds()).bottom + 24);
    if (dock) bottom = Math.min(bottom, (await dock.getBounds()).top - 24);
  }
  if (bottom - top < 200) throw new Error(`ENGINE_PAGE_TOO_SMALL:${page}`);
  return { top, bottom, left: bounds.left };
}

async function pageSwipe(session: ArchiveUiSession, page: string, towardTop: boolean, window?: PageWindow): Promise<void> {
  const area = window || await pageWindow(session, page);
  const height = area.bottom - area.top;
  let upper: number;
  let lower: number;
  if (towardTop) {
    // 回到页首只寻找固定首项，可利用顶部边界收敛，仍采用较大的复位步长。
    const inset = Math.min(160, height * 0.18);
    upper = Math.round(area.top + inset);
    lower = Math.round(area.bottom - inset);
  } else {
    // 查找入口 / 短按钮必须保留重叠视野。本机有效高度约 2170px，旧手势
    // 跨约 1850px 且速度为 2200px/s，惯性曾一次跳过沙盘下方的“文明连线”。
    // 查找改为最多 32% 高度、上限 700px；相邻计划视野至少重叠约 68%，
    // 并降到 SDK 默认 600px/s，避免快速抬手继续大幅滑行。详情按钮同样走此路径。
    const distance = Math.min(700, height * 0.32);
    lower = Math.round(area.top + height * 0.72);
    upper = Math.round(lower - distance);
  }
  // 引擎支持水平拖动及缩放。所有页面滚动都从左侧 16vp 页面内边距外发起，
  // 不使用可能在画布中央无限拖动的 scrollSearch，且每个目标最多扫描十二次。
  const x = Math.round(area.left + 12);
  // 最后一个参数是 px/s，不能把它当成动画时长；不通过追加长延时修补过冲。
  await session.driver.swipe(x, towardTop ? upper : lower, x, towardTop ? lower : upper, towardTop ? 2200 : 600);
  await session.driver.delayMs(180);
}

function topAnchor(page: string): On {
  if (page === 'explore-scroll') return ON.text('沿河，遇见文明');
  if (page === 'device-scroll') return ON.text('文化档案');
  if (page === 'detail-scroll') return ON.id('engine-mode-relic');
  return ON.text('一条河，许多种相遇');
}

async function pageTop(session: ArchiveUiSession, page: string, window?: PageWindow): Promise<void> {
  // 一次查找只测量一遍视口；滚动改变内容偏移，不会改变 Scroll 与系统栏的外框。
  // 不跨 inPage 调用缓存，因此模式切换、Ability 重建和字号变化仍会读取新的真实范围。
  const area = window || await pageWindow(session, page);
  for (let attempt = 0; attempt < 12; attempt++) {
    const anchor = await session.driver.findComponent(topAnchor(page));
    if (anchor) {
      const bounds = await anchor.getBounds();
      if (bounds.top >= area.top && bounds.top < area.top + (area.bottom - area.top) * 0.4) return;
    }
    await pageSwipe(session, page, true, area);
  }
  throw new Error(`ENGINE_PAGE_TOP_NOT_REACHED:${page}`);
}

async function visibleTarget(session: ArchiveUiSession, target: On, area: PageWindow): Promise<Component | undefined> {
  const node = await session.driver.findComponent(target);
  if (!node) return undefined;
  const bounds = await node.getBounds();
  const center = (bounds.top + bounds.bottom) / 2;
  const visible = bounds.right > bounds.left && bounds.bottom - bounds.top > 12 && center >= area.top + 24 && center <= area.bottom - 24;
  return visible ? node : undefined;
}

async function inPage(session: ArchiveUiSession, page: string, target: On, hint: string): Promise<Component> {
  const area = await pageWindow(session, page);
  const visible = await visibleTarget(session, target, area);
  // 连续读取同屏卡片、标签和按钮时直接复用刚核对过位置的节点。
  // 实际发生滚动后仍在最终目标处确认动画稳定，保留点击坐标的可靠性。
  if (visible) return visible;
  await pageTop(session, page, area);
  for (let attempt = 0; attempt < 12; attempt++) {
    if (await visibleTarget(session, target, area)) return session.wait(target, hint);
    await pageSwipe(session, page, false, area);
  }
  throw new Error(`ENGINE_PAGE_TARGET_NOT_FOUND:${page}:${hint}`);
}

async function inDetail(session: ArchiveUiSession, id: string): Promise<Component> {
  return inPage(session, 'detail-scroll', ON.id(id), id);
}

function siteFor(id: string): HeritageSite {
  const site = HERITAGE_SITES.find(item => item.id === id);
  if (!site) throw new Error(`ENGINE_TEST_SITE_MISSING:${id}`);
  return site;
}

async function openSite(session: ArchiveUiSession, id: string): Promise<void> {
  const site = siteFor(id);
  await session.search(site.name, 1);
  const target = ON.id(`site-row-${id}`).within(ON.id('archive-library-grid'));
  await (await inPage(session, 'device-scroll', target, id)).click();
  await session.waitId('detail-scroll');
  await inDetail(session, 'engine-native-relic_inspector');
}

async function assertProgress(session: ArchiveUiSession, id: string, percent: number, completed: number): Promise<void> {
  // 页面仅在 onCommit 确认落盘后发布新进度。先等这个真实确认，再打开独立 Repository 回读，
  // 避免移除多余 UI 等待之后，测试反而与异步 Preferences.flush 竞争。
  const label = await inPage(session, 'detail-scroll', ON.id('exploration-progress').text(`探索进度 ${percent}%`), '磁盘确认后的探索进度');
  expect(await label.getText()).assertEqual(`探索进度 ${percent}%`);
  const progress = decodeExplorationProgress((await session.read()).records, id);
  expect(progress.percent).assertEqual(percent);
  expect(progress.completedSectionIds.length).assertEqual(completed);
}

async function checkViewport(session: ArchiveUiSession, scene: string, page: string): Promise<void> {
  const node = await inPage(session, page, ON.id(`engine-native-${scene}`), scene);
  const bounds = await node.getBounds();
  const display = await session.driver.getDisplaySize();
  expect(bounds.left >= 0 && bounds.right <= display.x && bounds.top >= 0 && bounds.bottom <= display.y).assertTrue();
  expect(bounds.right - bounds.left > 120 && bounds.bottom - bounds.top > 120).assertTrue();
  console.info(`ENGINE_VIEWPORT:${scene}:${JSON.stringify(bounds)}`);
}

async function setReducedMotion(session: ArchiveUiSession): Promise<void> {
  await (await session.waitId('profile-entry')).click();
  const control = await session.inScroll('profile-scroll', ON.id('reduced-motion'));
  if (!await control.isChecked()) {
    const bounds = await control.getBounds();
    // 使用真实 Switch 滑块，不直接改 Repository 预填减少动态状态。
    await session.driver.click(Math.round(bounds.left + (bounds.bottom - bounds.top) / 2), Math.round((bounds.top + bounds.bottom) / 2));
    await session.wait(ON.id('reduced-motion').checked(true), '减少动态已开启');
  }
  expect((await session.read()).reducedMotion).assertTrue();
  await session.driver.pressBack();
  await session.waitId('explore-scroll');
}

export default function engineExperienceTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requested = parameters['class'] || parameters['-s class'] || '';
  // 首页城市入口、档案目录矩阵与图谱分别运行，保留每城全部真实卡片检查。
  // 不改变旧的默认功能套件，不把旧视口用例自动标成通过。
  // 本套件检验当前模拟器的真实原生兼容分支，真机 WebGL2 必须另留 GPU 画面证据。
  if (!requested.includes('EngineExperienceTest')) return;
  describe('EngineExperienceTest', () => {
    it('native_river_five_cities_filter_matrix', 0, async () => {
      const session = new ArchiveUiSession('engine_river_cities');
      await session.run(async () => {
        await inPage(session, 'explore-scroll', ON.id('river-sandbox-card'), '首页流光沙盘');
        await checkViewport(session, 'river_sandbox', 'explore-scroll');
        await (await inPage(session, 'explore-scroll', ON.id('river-city-0'), '沙盘选择三门峡')).click();
        const sandboxCity = CITIES[1];
        const sandboxCount = HERITAGE_SITES.filter(site => site.city === sandboxCity).length;
        await capture(session, 'river-home');
        for (let index = 0; index < 5; index++) {
          const started = Date.now();
          const city = CITIES[index + 1];
          const expected = HERITAGE_SITES.filter(site => site.city === city);
          expect(expected.length >= 4).assertTrue();
          await (await inPage(session, 'explore-scroll', ON.id(`city-${index}`), city)).click();
          await session.waitId('device-scroll');
          const selectedCity = await inPage(session, 'device-scroll', ON.id('library-city'), `${city}档案城市条件`);
          expect(await selectedCity.getText()).assertEqual(city);
          const count = await inPage(session, 'device-scroll', ON.id('library-result-count').text(`${expected.length} 处`), `${city}目录结果`);
          expect(await count.getText()).assertEqual(`${expected.length} 处`);
          for (const site of expected) {
            await inPage(session, 'device-scroll', ON.id(`site-row-${site.id}`).within(ON.id('archive-library-grid')), site.name);
          }
          await (await session.waitId('tab-0')).click();
          // 城市直达只重置档案条件，不能把沙盘先前选中的观察城市改成这次的目录城市。
          const selectedSandbox = await inPage(session, 'explore-scroll',
            ON.text(`${sandboxCity} · ${sandboxCount} 处文化档案`).within(ON.id('river-sandbox-card')), '返回后沙盘城市保留');
          expect(await selectedSandbox.getText()).assertEqual(`${sandboxCity} · ${sandboxCount} 处文化档案`);
          console.info(`ENGINE_CITY_VERIFIED:${city}:${expected.map(site => site.id).join('|')}:elapsed=${Date.now() - started}ms`);
        }
        await (await inPage(session, 'explore-scroll', ON.id('home-library-open'), '浏览完整文化档案')).click();
        await session.waitId('device-scroll');
        expect(await (await inPage(session, 'device-scroll', ON.id('library-result-count'), '完整目录结果')).getText())
          .assertEqual(`${HERITAGE_SITES.length} 处`);
      });
    });

    it('native_constellation_graph_selection_and_comparison', 0, async () => {
      const session = new ArchiveUiSession('engine_graph_compare');
      await session.run(async () => {
        await (await inPage(session, 'explore-scroll', ON.id('culture-atlas-entry'), '文明连线入口')).click();
        await checkViewport(session, 'constellation_graph', 'culture-atlas-scroll');
        await capture(session, 'constellation-graph');
        for (const id of ['smx-yangshao', 'ly-erlitou', 'zz-shang', 'kf-iron-pagoda', 'py-qicheng']) {
          await inPage(session, 'culture-atlas-scroll', ON.id('culture-site-index'), '档案索引');
          await session.select('culture-site-index', siteFor(id).name);
          const name = await inPage(session, 'culture-atlas-scroll', ON.id('culture-selected-name'), '选中档案');
          expect(await name.getText()).assertEqual(siteFor(id).name);
        }
        await inPage(session, 'culture-atlas-scroll', ON.id('culture-site-index'), '档案索引');
        await session.select('culture-site-index', siteFor('ly-erlitou').name);
        await (await inPage(session, 'culture-atlas-scroll', ON.id('culture-compare-zz-shang'), '双档案对照')).click();
        expect(await (await session.waitId('compare-left-name')).getText()).assertEqual(siteFor('ly-erlitou').name);
        expect(await (await session.waitId('compare-right-name')).getText()).assertEqual(siteFor('zz-shang').name);
        await capture(session, 'graph-comparison');
        await (await session.waitId('culture-comparison-close')).click();
        await inPage(session, 'culture-atlas-scroll', ON.id('culture-selected-name'), '返回选中档案');
      });
    });

    it('native_explicit_four_section_progress_and_ability_recreation', 0, async () => {
      const session = new ArchiveUiSession('engine_progress');
      await session.run(async () => {
        const id = 'smx-yangshao';
        const site = siteFor(id);
        await openSite(session, id);
        expect(decodeExplorationProgress((await session.read()).records, id).percent).assertEqual(0);
        await (await inDetail(session, 'engine-right')).click();
        await (await inDetail(session, 'engine-reset')).click();
        await (await inDetail(session, 'engine-mode-stratum')).click();
        await checkViewport(session, 'stratum_slice', 'detail-scroll');
        await capture(session, 'stratum-overview');
        await assertProgress(session, id, 0, 0);
        await (await inDetail(session, 'engine-mode-relic')).click();
        await (await inDetail(session, 'hotspot-story')).click();
        expect(await (await inDetail(session, 'engine-hotspot-reading')).getText()).assertEqual(site.history);
        await (await inDetail(session, 'engine-mode-stratum')).click();
        await assertProgress(session, id, 0, 0);
        const sections = ['overview', 'archaeology', 'history', 'poetry-travel'];
        const readings = [site.overview, site.archaeology, site.history, `${site.poetry}\n${site.travel}`];
        for (let index = 0; index < sections.length; index++) {
          await (await inDetail(session, `exploration-${sections[index]}`)).click();
          expect(await (await inDetail(session, 'exploration-reading')).getText()).assertEqual(readings[index]);
          expect(decodeExplorationProgress((await session.read()).records, id).percent).assertEqual(index * 25);
          await (await inDetail(session, 'exploration-complete')).click();
          await assertProgress(session, id, (index + 1) * 25, index + 1);
          const button = await session.driver.findComponent(ON.id('exploration-complete'));
          expect(!!button && !await button.isEnabled()).assertTrue();
        }
        await capture(session, 'progress-complete');
        // 真实结束并重建 Ability，再从同一独立库回读；不把此步骤写成进程强杀测试。
        await session.stop(); await session.start();
        expect(decodeExplorationProgress((await session.read()).records, id).percent).assertEqual(100);
        await openSite(session, id);
        await (await inDetail(session, 'engine-mode-stratum')).click();
        await assertProgress(session, id, 100, 4);
        await capture(session, 'progress-recreated');
      });
    });

    it('native_five_presets_rotate_hotspots_and_reset', 0, async () => {
      const session = new ArchiveUiSession('engine_five_presets');
      await session.run(async () => {
        for (const id of ['smx-yangshao', 'zz-duling-fangding', 'kf-iron-pagoda', 'py-xishuipo', 'ly-erlitou']) {
          const site = siteFor(id);
          await openSite(session, id);
          await checkViewport(session, 'relic_inspector', 'detail-scroll');
          await capture(session, `model-${id}-before`);
          await (await inDetail(session, 'engine-right')).click();
          const turned = await (await inDetail(session, 'engine-angle')).getText();
          expect(turned.includes('视角') && !turned.includes('初始视角')).assertTrue();
          await pageTop(session, 'detail-scroll');
          await capture(session, `model-${id}-turned`);
          await (await inDetail(session, 'engine-reset')).click();
          expect((await (await inDetail(session, 'engine-angle')).getText()).includes('初始视角')).assertTrue();
          if (id === 'smx-yangshao') {
            for (let index = 0; index < 3; index++) {
              await (await inDetail(session, ['hotspot-form', 'hotspot-pattern', 'hotspot-story'][index])).click();
              expect(await (await inDetail(session, 'engine-hotspot-reading')).getText()).assertEqual([site.overview, site.archaeology, site.history][index]);
            }
          }
          expect(decodeExplorationProgress((await session.read()).records, id).percent).assertEqual(0);
          console.info(`ENGINE_MODEL_VERIFIED:${id}`);
          await session.driver.pressBack();
          await session.waitId('device-scroll');
        }
      });
    });

    it('native_dark_large_text_and_reduced_motion_frames', 0, async () => {
      const app = TestContext.context.getApplicationContext();
      const originalScale = TestContext.context.config.fontSizeScale || 1;
      const session = new ArchiveUiSession('engine_appearance');
      try {
        await session.run(async () => {
          await setReducedMotion(session);
          app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
          await session.driver.delayMs(400);
          await openSite(session, 'smx-yangshao');
          expect(session.context.resourceManager.getColorByNameSync('canvas') & 0xFFFFFF).assertEqual(0x171311);
          await checkViewport(session, 'relic_inspector', 'detail-scroll');
          const angle = await (await inDetail(session, 'engine-angle')).getText();
          expect(angle.includes('已减少动态')).assertTrue();
          await pageTop(session, 'detail-scroll');
          const viewport = await (await session.waitId('engine-native-relic_inspector')).getBounds();
          console.info(`ENGINE_REDUCED_VIEWPORT:${JSON.stringify(viewport)}`);
          await capture(session, 'reduced-before');
          await session.driver.delayMs(1200);
          expect(await (await session.waitId('engine-angle')).getText()).assertEqual(angle);
          expect(JSON.stringify(await (await session.waitId('engine-native-relic_inspector')).getBounds())).assertEqual(JSON.stringify(viewport));
          await capture(session, 'reduced-after');
          await (await inDetail(session, 'engine-right')).click();
          expect(await (await inDetail(session, 'engine-angle')).getText() === angle).assertFalse();
          await pageTop(session, 'detail-scroll');
          await capture(session, 'dark-manual-turn');
          await session.stop();
          app.setFontSizeScale(1.5);
          await session.start();
          app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
          await session.driver.delayMs(400);
          await checkViewport(session, 'river_sandbox', 'explore-scroll');
          await capture(session, 'large-home');
          await openSite(session, 'kf-iron-pagoda');
          await checkViewport(session, 'relic_inspector', 'detail-scroll');
          for (const id of ['engine-mode-relic', 'engine-mode-stratum', 'engine-right', 'engine-reset']) {
            const bounds = await (await inDetail(session, id)).getBounds();
            const display = await session.driver.getDisplaySize();
            expect(bounds.left >= 0 && bounds.right <= display.x && bounds.bottom > bounds.top).assertTrue();
          }
          expect((await session.read()).reducedMotion).assertTrue();
          expect(session.context.resourceManager.getColorByNameSync('canvas') & 0xFFFFFF).assertEqual(0xFAF6F0);
          await pageTop(session, 'detail-scroll');
          await capture(session, 'large-detail');
        });
      } finally {
        // 恢复本应用外观和字号；不操作系统全局设置。session.run 负责独立库退出与清理。
        app.setFontSizeScale(originalScale);
        app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
    });
  });
}
