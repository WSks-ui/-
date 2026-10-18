import { abilityDelegatorRegistry, Component, MatchPattern, ON, On } from '@kit.TestKit';
import { describe, expect, it } from '@ohos/hypium';
import { activeRecords } from '../../../main/ets/domain/ArchiveDomain';
import { HERITAGE_SITES } from '../../../main/ets/data/HeritageCatalog';
import { materialStudyForId } from '../../../main/ets/data/MaterialStudyCatalog';
import { materialObservationForSite } from '../../../main/ets/domain/MaterialObservation';
import { JOURNEY_ROUTES } from '../../../main/ets/domain/JourneyRoutes';
import { ArchiveUiSession } from './ArchiveUiSession';

interface PageArea {
  left: number;
  right: number;
  top: number;
  bottom: number;
}

async function pageArea(session: ArchiveUiSession, page: string): Promise<PageArea> {
  const scroll = await session.waitId(page);
  const bounds = await scroll.getBounds();
  let top = bounds.top + 24;
  let bottom = bounds.bottom - 80;
  if (page === 'explore-scroll' || page === 'archive-scroll') {
    const header = await session.driver.findComponent(ON.id('top-navigation-content'));
    const dock = await session.driver.findComponent(ON.id('tab-0'));
    if (header) top = Math.max(top, (await header.getBounds()).bottom + 24);
    if (dock) bottom = Math.min(bottom, (await dock.getBounds()).top - 24);
  }
  if (bottom - top < 200) throw new Error(`HOME_EXPERIENCE_PAGE_TOO_SMALL:${page}`);
  return { left: bounds.left, right: bounds.right, top, bottom };
}

async function visiblePageArea(session: ArchiveUiSession, page: string): Promise<PageArea> {
  const scroll = await session.waitId(page);
  const bounds = await scroll.getBounds();
  let top = bounds.top;
  let bottom = bounds.bottom;
  if (page === 'explore-scroll' || page === 'archive-scroll') {
    const header = await session.driver.findComponent(ON.id('top-navigation-content'));
    const dock = await session.driver.findComponent(ON.id('tab-0'));
    // 首页的导航栏和 Dock 覆盖 Scroll 内容；实际可见范围按覆盖控件边缘截取，不额外叠安全边距。
    if (header) top = Math.max(top, (await header.getBounds()).bottom);
    if (dock) bottom = Math.min(bottom, (await dock.getBounds()).top);
  }
  return { left: bounds.left, right: bounds.right, top, bottom };
}

async function marginSwipe(session: ArchiveUiSession, area: PageArea, towardTop: boolean,
  requestedDistance: number = 700): Promise<void> {
  // 页面左侧余白避开首页画面与详情热点；短步滚动保持相邻视野，防止跳过路线节点和编辑控件。
  const height = area.bottom - area.top;
  const distance = Math.min(700, height * 0.32, requestedDistance);
  const start = area.top + height * (towardTop ? 0.28 : 0.72);
  const x = Math.round(area.left + 12);
  await session.driver.swipe(x, Math.round(start), x,
    Math.round(start + (towardTop ? distance : -distance)), 600);
  await session.driver.delayMs(150);
}

async function inPage(session: ArchiveUiSession, page: string, target: On, targetHint: string): Promise<Component> {
  const area = await pageArea(session, page);
  let unknownMoves = 0;
  for (let attempt = 0; attempt <= 12; attempt++) {
    const node = await session.driver.findComponent(target);
    let towardTop = unknownMoves >= 3;
    if (node) {
      const bounds = await node.getBounds();
      if (bounds.right > bounds.left && bounds.bottom - bounds.top > 12) {
        const center = (bounds.top + bounds.bottom) / 2;
        if (center >= area.top && center <= area.bottom) return session.wait(target, page);
        towardTop = center < area.top;
      } else unknownMoves++;
    } else unknownMoves++;
    if (attempt < 12) await marginSwipe(session, area, towardTop);
  }
  throw new Error(`HOME_EXPERIENCE_TARGET_NOT_EXPOSED:${page}:${targetHint}`);
}

async function frameCanvas(session: ArchiveUiSession, page: string, canvasId: string): Promise<void> {
  // 详情画布在页首；使用真实 Scroll 回顶固定坐标，再核对 Canvas 四边都落在未裁切视区内。
  if (page === 'detail-scroll') {
    await (await session.waitId(page)).scrollToTop(40000);
    await session.wait(ON.id('engine-mode-relic'), '详情回顶后的真实观察模式');
  }
  await inPage(session, page, ON.id(canvasId).type('Canvas'), canvasId);
  // 定位和滑动继续使用带余量的安全区；是否被裁切只按 Scroll 真正显示的视口判断。
  const area = await pageArea(session, page);
  const visibleArea = await visiblePageArea(session, page);
  for (let attempt = 0; attempt <= 8; attempt++) {
    const node = await session.driver.findComponent(ON.id(canvasId).type('Canvas'));
    const canvas = node ? await node.getBounds() : undefined;
    if (canvas && canvas.right > canvas.left && canvas.bottom > canvas.top &&
      canvas.left >= visibleArea.left && canvas.right <= visibleArea.right &&
      canvas.top >= visibleArea.top && canvas.bottom <= visibleArea.bottom) {
      console.info(`HOME_EXPERIENCE_CANVAS_FRAME:${canvasId}:${JSON.stringify({ page, area, canvas })}`);
      return;
    }
    if (attempt === 8) break;
    let towardTop = false;
    let distance = 700;
    if (canvas && canvas.top < area.top + 80) {
      towardTop = true;
      distance = Math.max(160, area.top + 112 - canvas.top);
    } else if (canvas && canvas.bottom < area.bottom + 24) {
      distance = Math.max(160, canvas.bottom - area.bottom + 112);
    }
    await marginSwipe(session, area, towardTop, distance);
  }
  throw new Error(`HOME_EXPERIENCE_CANVAS_CLIPPED:${page}:${canvasId}`);
}

async function capture(session: ArchiveUiSession, name: string, canvasId: string = ''): Promise<void> {
  // 每张关键页面都保留实际屏幕与 UiTest 布局配对，供设备侧核对原生控件和 Canvas 位置。
  await session.driver.delayMs(250);
  if (canvasId) {
    const canvas = await session.driver.findComponent(ON.id(canvasId).type('Canvas'));
    if (!canvas) throw new Error(`HOME_EXPERIENCE_CAPTURE_CANVAS_MISSING:${name}`);
    console.info(`HOME_EXPERIENCE_CAPTURE_BOUNDS:${name}:${JSON.stringify(await canvas.getBounds())}`);
  }
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  const image = await delegator.executeShellCommand(
    `uitest screenCap -p /data/local/tmp/home-experience-${name}.png`);
  expect(image.exitCode).assertEqual(0);
  const layout = await delegator.executeShellCommand(
    `uitest dumpLayout -p /data/local/tmp/home-experience-${name}.json`);
  expect(layout.exitCode).assertEqual(0);
}

async function assertSiteTitle(session: ArchiveUiSession, siteName: string): Promise<void> {
  // 详情档案名由导航栏标题承载，位于 detail-scroll 的 Scroll 外层；只按全局可见文字查找。
  const title = await session.wait(ON.text(siteName), '详情导航标题');
  expect(await title.getText()).assertEqual(siteName);
}

async function runHomeExperience(): Promise<void> {
  const session = new ArchiveUiSession('home_experience');
  const started = Date.now();
  await session.run(async () => {
    const siteId = 'smx-miaodigou';
    const site = HERITAGE_SITES.find(item => item.id === siteId);
    const route = JOURNEY_ROUTES.find(item => item.id === 'earth-and-fire');
    const study = materialStudyForId(siteId);
    const observation = materialObservationForSite(siteId);
    if (!site || !route || !study || !observation) throw new Error('HOME_EXPERIENCE_CONTENT_MISSING');
    expect(route.siteIds.length).assertEqual(4);
    expect(observation.sceneRevision).assertEqual(2);

    // ArchiveUiSession 经真实登录页的“离线浏览”按钮进入首页，随机独立 Preferences 初始无档案记录。
    await session.waitId('explore-scroll');
    await inPage(session, 'explore-scroll', ON.id('home-theme-entry'), 'home-theme-entry');
    await session.wait(ON.text('泥火成器').within(ON.id('home-theme-entry')));
    expect(await (await session.waitId('home-theme-progress')).getText()).assertEqual('已探索 0 / 4 处');
    expect(await (await session.waitId('home-theme-next-site')).getText()).assertEqual('从庙底沟遗址开始');
    await inPage(session, 'explore-scroll', ON.id('home-empty-memory'), 'home-empty-memory');
    await session.wait(ON.text('还没有留下记忆').within(ON.id('home-empty-memory')));
    await session.waitId('home-empty-memory-explore');
    if (await session.driver.findComponent(ON.id('home-recent-memory'))) {
      throw new Error('HOME_EXPERIENCE_EMPTY_HOME_HAS_RECENT_NOTE');
    }
    await (await session.waitId('explore-scroll')).scrollToTop(40000);
    await capture(session, 'empty');

    // 首页整张主题卡直接打开路线首节点；真实访问记录落盘，但不会因“打开过”而点亮路线。
    await (await inPage(session, 'explore-scroll', ON.id('home-theme-entry'), 'home-theme-entry')).click();
    await session.waitId('detail-scroll');
    await assertSiteTitle(session, site.name);
    await session.driver.pressBack();
    await session.waitId('explore-scroll');
    // 首页重新派生真实主题进度；只留下 opened 浏览记录时仍为 0 / 4。
    expect(await (await session.waitId('home-theme-progress')).getText()).assertEqual('已探索 0 / 4 处');

    // 再从首页主题直达同一档案，选择“西部陶窑”并主动右转后保存真实观察参数。
    await (await inPage(session, 'explore-scroll', ON.id('home-theme-entry'), 'home-theme-entry')).click();
    await session.waitId('detail-scroll');
    await assertSiteTitle(session, site.name);
    const kiln = observation.hotspots.find(item => item.id === 'kilns');
    const kilnFact = kiln ? study.facts.find(item => item.id === kiln.factId) : undefined;
    if (!kiln || !kilnFact) throw new Error('HOME_EXPERIENCE_KILN_FACT_MISSING');
    await (await inPage(session, 'detail-scroll', ON.id('observation-hotspot-kilns'),
      'observation-hotspot-kilns')).click();
    expect(await (await inPage(session, 'detail-scroll', ON.id('observation-selected-detail'),
      'observation-selected-detail')).getText())
      .assertEqual('正在观察 · 西部陶窑');
    expect(await (await inPage(session, 'detail-scroll', ON.id('engine-hotspot-reading'),
      'engine-hotspot-reading')).getText())
      .assertEqual(kilnFact.body);
    const savedYaw = kiln.yaw + Math.PI / 8;
    const savedAngle = Math.round(savedYaw * 180 / Math.PI) % 360;
    await (await inPage(session, 'detail-scroll', ON.id('engine-right'), 'engine-right')).click();
    expect((await (await inPage(session, 'detail-scroll', ON.id('engine-angle'), 'engine-angle')).getText())
      .includes(`视角 ${savedAngle}°`)).assertTrue();
    await frameCanvas(session, 'detail-scroll', 'engine-native-relic_inspector');
    await capture(session, 'saved-view', 'engine-native-relic_inspector');

    await (await inPage(session, 'detail-scroll', ON.id('engine-remember-view'),
      'engine-remember-view')).click();
    await session.waitId('note-editor-scroll');
    const editorStatus = await inPage(session, 'note-editor-scroll',
      ON.id('memory-draft-preview-status').text('已恢复当时视角'), 'memory-draft-preview-status');
    expect(await editorStatus.getText()).assertEqual('已恢复当时视角');
    await frameCanvas(session, 'note-editor-scroll', 'memory-draft-preview-canvas');
    const body = '在陶窑与居住遗存之间，记下我对庙底沟西部空间关系的观察。';
    const tags = '庙底沟，陶窑，空间观察';
    await (await inPage(session, 'note-editor-scroll', ON.id('note-body'), 'note-body'))
      .inputText(body, { paste: true, addition: true });
    await (await inPage(session, 'note-editor-scroll', ON.id('note-tags'), 'note-tags'))
      .inputText(tags, { paste: true, addition: true });
    expect(await (await session.waitId('note-body')).getText()).assertEqual(body);
    expect(await (await session.waitId('note-tags')).getText()).assertEqual(tags);
    await session.driver.pressBack();
    // 保存按钮是编辑器固定页脚，不参与 note-editor-scroll 的内容滚动和可见区判定。
    await (await session.waitId('save-note')).click();
    await session.editorClosed();

    // 清 Preferences 缓存后从磁盘读回；摘录、完整场景参数和原始视口都必须仍然存在。
    const persisted = await session.read();
    expect(persisted.schemaVersion).assertEqual(1);
    const opened = activeRecords(persisted.records, 'progress').find(record => record.siteId === siteId);
    if (!opened) throw new Error('HOME_EXPERIENCE_OPENED_RECORD_NOT_SAVED');
    expect(opened.body).assertEqual('opened');
    const notes = activeRecords(persisted.records, 'note');
    expect(notes.length).assertEqual(1);
    const note = notes[0];
    expect(note.siteId).assertEqual(siteId);
    expect(note.body).assertEqual(body);
    expect(note.tags.join('|')).assertEqual('庙底沟|陶窑|空间观察');
    expect(note.quotedPoemOrFact).assertEqual(kilnFact.body);
    const pose = note.snapshot3DPose;
    if (!pose) throw new Error('HOME_EXPERIENCE_SAVED_POSE_MISSING');
    expect(pose.version).assertEqual(1);
    expect(pose.sceneType).assertEqual('relic_inspector');
    expect(pose.proceduralPreset).assertEqual('miaodigou_pottery');
    expect(pose.sceneRevision).assertEqual(2);
    expect(pose.rendererProfile).assertEqual('native-raster-v1');
    expect(pose.hotspotId).assertEqual('kilns');
    expect(pose.sectionId).assertEqual('');
    expect(Math.abs(pose.yaw - savedYaw) < 0.0001).assertTrue();
    expect(Math.abs(pose.pitch - kiln.pitch) < 0.0001).assertTrue();
    expect(Math.abs(pose.zoom - kiln.zoom) < 0.0001).assertTrue();
    const frame = pose.viewFrame;
    if (!frame) throw new Error('HOME_EXPERIENCE_SAVED_FRAME_MISSING');
    expect(Number.isFinite(frame.width) && frame.width > 24 && Number.isFinite(frame.height) && frame.height > 46)
      .assertTrue();
    expect(frame.textDensity !== undefined && Number.isFinite(frame.textDensity) && frame.textDensity > 0).assertTrue();
    expect(typeof frame.dark === 'boolean').assertTrue();
    console.info(`HOME_EXPERIENCE_SAVED:${JSON.stringify(note)}`);

    // 首页只显示这条刚写入的活跃手账；等待首页预览的真实原生 Canvas 完成等比重建。
    await session.driver.pressBack();
    await session.waitId('explore-scroll');
    await (await session.waitId('explore-scroll')).scrollToTop(40000);
    await inPage(session, 'explore-scroll', ON.id('home-recent-memory'), 'home-recent-memory');
    expect(await (await session.waitId('home-recent-memory-site')).getText()).assertEqual(site.name);
    expect(await (await session.waitId('home-recent-memory-body')).getText()).assertEqual(body);
    expect(await (await session.waitId('home-theme-progress')).getText()).assertEqual('已探索 1 / 4 处');
    expect(await (await session.waitId('home-theme-next-site')).getText()).assertEqual('下一处 · 大河村遗址');
    await capture(session, 'recent');
    expect(await (await inPage(session, 'explore-scroll',
      ON.id('home-recent-memory-preview-status').text('已恢复当时视角'),
      'home-recent-memory-preview-status')).getText()).assertEqual('已恢复当时视角');
    const previewCanvasId = 'home-recent-memory-preview-canvas';
    await frameCanvas(session, 'explore-scroll', previewCanvasId);
    await capture(session, 'home-preview', previewCanvasId);

    // 直接点击首页保存画面，走正式 openMemory(note, true) 路径并等真实 Canvas 重绘确认回放。
    await (await inPage(session, 'explore-scroll', ON.id(previewCanvasId).type('Canvas'),
      previewCanvasId)).click();
    await session.waitId('detail-scroll');
    const replayAngle = await session.wait(ON.id('engine-angle').text('已回到手账视角', MatchPattern.CONTAINS),
      '保存观察视角已由详情 Canvas 实际绘制');
    expect((await replayAngle.getText()).includes('已回到手账视角')).assertTrue();
    await assertSiteTitle(session, site.name);
    expect(await (await inPage(session, 'detail-scroll', ON.id('observation-selected-detail'),
      'observation-selected-detail')).getText())
      .assertEqual('正在观察 · 西部陶窑');
    expect(await (await inPage(session, 'detail-scroll', ON.id('engine-hotspot-reading'),
      'engine-hotspot-reading')).getText())
      .assertEqual(kilnFact.body);
    await frameCanvas(session, 'detail-scroll', 'engine-native-relic_inspector');
    await capture(session, 'replay', 'engine-native-relic_inspector');
    const replayYaw = pose.yaw + Math.PI / 8;
    const replayTurnAngle = Math.round(replayYaw * 180 / Math.PI) % 360;
    await (await inPage(session, 'detail-scroll', ON.id('engine-right'), 'engine-right')).click();
    expect((await (await inPage(session, 'detail-scroll', ON.id('engine-angle'), 'engine-angle')).getText())
      .includes(`视角 ${replayTurnAngle}°`)).assertTrue();

    // 从首页“全部路线”进入真实 JourneyPanel，核对 4 个节点与手账点亮规则。
    await session.driver.pressBack();
    await session.waitId('explore-scroll');
    await (await inPage(session, 'explore-scroll', ON.id('home-all-journeys'), 'home-all-journeys')).click();
    await session.waitId('profile-scroll');
    await session.waitId('journey-panel');
    const routeId = 'earth-and-fire';
    const progress = await inPage(session, 'profile-scroll', ON.id(`journey-progress-${routeId}`), `journey-progress-${routeId}`);
    expect(await progress.getText()).assertEqual('1 / 4');
    for (let index = 0; index < route.siteIds.length; index++) {
      const nodeId = `journey-node-${routeId}-${route.siteIds[index]}`;
      const node = ON.id(nodeId).within(ON.id(`journey-route-${routeId}`));
      await inPage(session, 'profile-scroll', node, nodeId);
      await session.wait(node, nodeId);
      const lit = await session.driver.findComponent(ON.text('已点亮').within(ON.id(nodeId)));
      if (route.siteIds[index] === siteId) {
        if (!lit) throw new Error(`HOME_EXPERIENCE_MIAODIGOU_NODE_NOT_LIT:${nodeId}`);
      } else if (lit) {
        throw new Error(`HOME_EXPERIENCE_UNVISITED_NODE_LIT:${nodeId}`);
      }
    }
    await session.waitId('journey-route-earth-and-fire');
    console.info(`HOME_EXPERIENCE_CORE_PATH_MS:${Date.now() - started}`);
  });
}

export default function homeExperienceTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requested = parameters['class'] || parameters['-s class'] || '';
  if (!requested.includes('HomeExperienceTest')) return;
  describe('HomeExperienceTest', () => {
    it('native_home_theme_recent_memory_route_replay', 0, async () => {
      await runHomeExperience();
    });
  });
}
