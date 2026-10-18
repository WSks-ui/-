import { abilityDelegatorRegistry, Component, ON, On } from '@kit.TestKit';
import { describe, expect, it } from '@ohos/hypium';
import { activeRecords } from '../../../main/ets/domain/ArchiveDomain';
import { HERITAGE_SITES } from '../../../main/ets/data/HeritageCatalog';
import { ArchiveUiSession } from './ArchiveUiSession';

interface PageArea {
  left: number;
  top: number;
  bottom: number;
}

async function capture(session: ArchiveUiSession, name: string): Promise<void> {
  // 独立离线测试库不含私人账号。截图和真实布局成对保留，画面仍需主机拉取后人工检查。
  await session.driver.delayMs(350);
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  const image = await delegator.executeShellCommand(`uitest screenCap -p /data/local/tmp/yunheji-memory-${name}.png`);
  expect(image.exitCode).assertEqual(0);
  const layout = await delegator.executeShellCommand(`uitest dumpLayout -p /data/local/tmp/yunheji-memory-${name}.json`);
  expect(layout.exitCode).assertEqual(0);
}

async function pageArea(session: ArchiveUiSession, page: string): Promise<PageArea> {
  const scroll = await session.waitId(page);
  const bounds = await scroll.getBounds();
  let top = bounds.top + 24;
  let bottom = bounds.bottom - 48;
  if (page === 'explore-scroll' || page === 'archive-scroll') {
    const header = await session.driver.findComponent(ON.id('top-navigation-content'));
    const dock = await session.driver.findComponent(ON.id('tab-0'));
    if (header) top = Math.max(top, (await header.getBounds()).bottom + 24);
    if (dock) bottom = Math.min(bottom, (await dock.getBounds()).top - 24);
  }
  if (bottom - top < 160) throw new Error(`MEMORY_PAGE_TOO_SMALL:${page}`);
  return { left: bounds.left, top, bottom };
}

async function visibleTarget(session: ArchiveUiSession, target: On, area: PageArea): Promise<Component | undefined> {
  const node = await session.driver.findComponent(target);
  if (!node) return undefined;
  const bounds = await node.getBounds();
  const center = (bounds.top + bounds.bottom) / 2;
  return bounds.right > bounds.left && bounds.bottom - bounds.top > 12 &&
    center >= area.top && center <= area.bottom ? node : undefined;
}

async function pageSwipe(session: ArchiveUiSession, area: PageArea, towardTop: boolean, requestedDistance: number = 700): Promise<void> {
  // 从页面左侧余白发起，避开文化视口、卡片按钮和原生 Switch；短距离保留相邻视野，
  // 不调用中央 scrollSearch，也不把 px/s 当作动画时长而产生整页 fling。
  const height = area.bottom - area.top;
  const distance = Math.min(700, height * 0.32, requestedDistance);
  const start = area.top + height * (towardTop ? 0.28 : 0.72);
  const end = start + (towardTop ? distance : -distance);
  const x = Math.round(area.left + 12);
  await session.driver.swipe(x, Math.round(start), x, Math.round(end), 600);
  await session.driver.delayMs(150);
}

async function inPage(session: ArchiveUiSession, page: string, target: On): Promise<Component> {
  const area = await pageArea(session, page);
  let unknownMoves = 0;
  // 本用例只走短编辑表单、一张画廊卡与首条路线。有真实范围时直接朝目标滚；
  // 节点缺失或只有零范围时，先在余白最多回滚四步，再向下扫描。总计最多十二步，
  // 每一步都重取真实 bounds，找不到就失败，不能无限滚动或改页面状态。
  for (let attempt = 0; attempt <= 12; attempt++) {
    if (await visibleTarget(session, target, area)) return session.wait(target, page);
    if (attempt === 12) break;
    const node = await session.driver.findComponent(target);
    let towardTop = unknownMoves < 4;
    if (node) {
      const bounds = await node.getBounds();
      if (bounds.right > bounds.left && bounds.bottom - bounds.top > 12) {
        towardTop = (bounds.top + bounds.bottom) / 2 < area.top;
      } else unknownMoves++;
    } else unknownMoves++;
    await pageSwipe(session, area, towardTop);
  }
  throw new Error(`MEMORY_TARGET_NOT_EXPOSED:${page}`);
}

async function frameCapture(session: ArchiveUiSession, page: string, upperTarget: On, lowerTarget: On): Promise<void> {
  const area = await pageArea(session, page);
  // 实际 gallery 布局曾把 1629px 手账裁成 [2277,2662]，图谱则把 1540px Canvas
  // 裁成 [1983,2662]；两者中心都在屏内，却只有头部可见。截图改查两端叶节点，
  // 或要求整张 Canvas 的上下边都进入 Scroll 内侧，裁切边界不能当成完整内容边界。
  for (let attempt = 0; attempt <= 6; attempt++) {
    const upperNode = await session.driver.findComponent(upperTarget);
    const lowerNode = await session.driver.findComponent(lowerTarget);
    const upper = upperNode ? await upperNode.getBounds() : undefined;
    const lower = lowerNode ? await lowerNode.getBounds() : undefined;
    const hasUpper = upper !== undefined && upper.right > upper.left && upper.bottom - upper.top > 12;
    const hasLower = lower !== undefined && lower.right > lower.left && lower.bottom - lower.top > 12;
    if (hasUpper && hasLower && upper && lower &&
      upper.top >= area.top + 112 && lower.bottom <= area.bottom - 112) {
      console.info(`MEMORY_CAPTURE_FRAME:${page}:${JSON.stringify({ upper, lower })}`);
      return;
    }
    if (attempt === 6) break;
    let towardTop = false;
    let distance = 700;
    if (hasUpper && upper && upper.top < area.top + 112) {
      towardTop = true;
      distance = Math.max(160, area.top + 144 - upper.top);
    } else if (!hasUpper && hasLower) {
      towardTop = true;
    } else if (hasLower && lower && lower.bottom < area.bottom + 24) {
      // 两端已有真实范围时只补足留白；底边仍贴着 Scroll 裁切线时，继续完整短步向下。
      distance = Math.max(160, lower.bottom - area.bottom + 144);
    }
    await pageSwipe(session, area, towardTop, distance);
  }
  throw new Error(`MEMORY_CAPTURE_FRAME_NOT_EXPOSED:${page}`);
}

export default function memoryJourneyTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requested = parameters['class'] || parameters['-s class'] || '';
  // 只在本轮明确选择核心演示路径时启用，不把新场景塞进旧默认全量回归。
  if (!requested.includes('MemoryJourneyTest')) return;
  describe('MemoryJourneyTest', () => {
    it('native_postcard_capture_gallery_pose_and_route', 0, async () => {
      const session = new ArchiveUiSession('memory_journey');
      await session.run(async () => {
        const started = Date.now();
        const siteId = 'smx-yangshao';
        const body = '从彩陶纹带里，记下今天的黄河线索。';
        const site = HERITAGE_SITES.find((item) => item.id === siteId);
        if (!site) throw new Error('MEMORY_TEST_SITE_MISSING');

        await session.search(site.name, 1);
        await (await inPage(session, 'explore-scroll',
          ON.id(`site-row-${siteId}`).within(ON.id('explore-site-grid')))).click();
        await session.waitId('detail-scroll');
        await (await session.inScroll('detail-scroll', ON.id('engine-remember-view'))).click();
        await (await inPage(session, 'note-editor-scroll', ON.id('note-body'))).inputText(body);
        await (await inPage(session, 'note-editor-scroll', ON.id('note-tags'))).inputText('彩陶，黄河');
        // 输入后先用一次真实返回收起键盘，随后仍确认保存按钮与编辑页存在，不退出手账。
        await session.driver.pressBack();
        await session.waitId('save-note');

        await inPage(session, 'note-editor-scroll', ON.id('memory-stamp-index'));
        await session.select('memory-stamp-index', '仰韶初光');
        await (await inPage(session, 'note-editor-scroll', ON.id('memory-paper-jade'))).click();
        const quote = await inPage(session, 'note-editor-scroll', ON.id('memory-quote-toggle'));
        if (!await quote.isChecked()) {
          const bounds = await quote.getBounds();
          // 标签行可能比滑块宽；点真实 Switch 的左侧滑块中心，不点整行文字。
          await session.driver.click(Math.round(bounds.left + (bounds.bottom - bounds.top) / 2),
            Math.round((bounds.top + bounds.bottom) / 2));
          await session.wait(ON.id('memory-quote-toggle').checked(true), '手账私人摘录已开启');
        }
        await (await session.waitId('save-note')).click();
        await session.editorClosed();

        // 保存确认后再移除 Preferences 缓存回读；不直接注入笔记或预填路线进度。
        const records = (await session.read()).records;
        const notes = activeRecords(records, 'note');
        expect(notes.length).assertEqual(1);
        const note = notes[0];
        expect(note.siteId).assertEqual(siteId);
        expect(note.body).assertEqual(body);
        expect(note.tags.join('|')).assertEqual('彩陶|黄河');
        expect(note.stampType).assertEqual('仰韶初光');
        expect(note.paperTheme).assertEqual('jade');
        expect(note.quotedPoemOrFact).assertEqual(site.summary);
        const pose = note.snapshot3DPose;
        if (!pose) throw new Error('MEMORY_SAVED_POSE_MISSING');
        expect(pose.version).assertEqual(1);
        expect(pose.sceneType).assertEqual('relic_inspector');
        expect(Number.isFinite(pose.yaw) && Number.isFinite(pose.pitch)).assertTrue();
        expect(pose.zoom).assertEqual(1);
        expect(pose.hotspotId).assertEqual('form');
        expect(typeof pose.sectionId === 'string' && pose.label.length > 0).assertTrue();
        console.info(`MEMORY_SAVED:${JSON.stringify(note)}`);
        // 手账位于完整档案正文下方；先到详情页尾，再用既有余白定位助手向上寻找卡片。
        await (await session.waitId('detail-scroll')).scrollToBottom(40000);
        await session.inScroll('detail-scroll', ON.text('云河手记').within(ON.id(`memory-card-${note.id}`)));
        await capture(session, 'detail-card');

        await session.driver.pressBack();
        await session.waitId('explore-scroll');
        await (await session.waitId('tab-1')).click();
        await session.waitId('archive-scroll');
        await inPage(session, 'archive-scroll', ON.id('memory-view-list'));
        await (await inPage(session, 'archive-scroll', ON.id('memory-view-gallery'))).click();
        // 手账已前置到统计下方、收藏前方；从其标题到页脚按钮定位整张卡，不再先滚到收藏页尾。
        await frameCapture(session, 'archive-scroll',
          ON.text('云河手记').within(ON.id(`memory-card-${note.id}`)),
          ON.id(`memory-open-${note.id}`).within(ON.id('archive-scroll')));
        await capture(session, 'gallery');
        await (await inPage(session, 'archive-scroll',
          ON.id(`memory-pose-${note.id}`).within(ON.id('archive-scroll')))).click();
        await session.waitId('detail-scroll');
        const angle = await session.inScroll('detail-scroll', ON.id('engine-angle'));
        expect((await angle.getText()).includes('已回到手账视角')).assertTrue();

        await session.driver.pressBack();
        await session.waitId('archive-scroll');
        await (await session.waitId('profile-entry')).click();
        await session.waitId('profile-scroll');
        await (await session.inScroll('profile-scroll', ON.id('profile-journeys'))).click();
        const route = 'seeking-xia';
        await inPage(session, 'profile-scroll', ON.id(`journey-route-${route}`).within(ON.id('profile-scroll')));
        const progress = await inPage(session, 'profile-scroll',
          ON.id(`journey-progress-${route}`).within(ON.id('profile-scroll')));
        expect(await progress.getText()).assertEqual('1 / 5');
        const node = ON.id(`journey-node-${route}-${siteId}`).within(ON.id('profile-scroll'));
        await inPage(session, 'profile-scroll', node);
        await session.wait(ON.text('已点亮').within(ON.id(`journey-node-${route}-${siteId}`)), '仰韶村真实手账点亮路线节点');
        await capture(session, 'route');
        await (await inPage(session, 'profile-scroll',
          ON.id(`journey-graph-${route}`).within(ON.id('profile-scroll')))).click();
        await session.waitId('culture-atlas-scroll');
        await inPage(session, 'culture-atlas-scroll', ON.id('culture-journey-header'));
        const graphProgress = await inPage(session, 'culture-atlas-scroll', ON.id('culture-journey-progress'));
        expect(await graphProgress.getText()).assertEqual('1 / 5 处点亮');
        // 只从左侧余白推进至完整 Canvas；截图前不再用容器中心判定把页面回滚到路线页首。
        const graphCanvas = ON.id('engine-native-constellation_graph');
        await frameCapture(session, 'culture-atlas-scroll', graphCanvas, graphCanvas);
        await capture(session, 'route-graph');
        console.info(`MEMORY_CORE_PATH_MS:${Date.now() - started}`);
      });
    });
  });
}
