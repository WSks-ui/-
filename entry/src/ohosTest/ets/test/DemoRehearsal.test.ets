import { abilityDelegatorRegistry, Component, MatchPattern, ON, On } from '@kit.TestKit';
import { application } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { describe, expect, it } from '@ohos/hypium';
import { activeRecords } from '../../../main/ets/domain/ArchiveDomain';
import { MATERIAL_COMPARISON } from '../../../main/ets/data/MaterialStudyCatalog';
import { HERITAGE_SITES } from '../../../main/ets/data/HeritageCatalog';
import { materialStudyForId } from '../../../main/ets/data/MaterialStudyCatalog';
import { ArchiveUiSession } from './ArchiveUiSession';
import { TestContext } from './TestContext';

// T13.1 三分钟主线排练：只操作正式页面，按演示顺序记录每段真实耗时。
// A 段使用独立离线库，避免把排练笔记写进账号；B 段读取 T11 已同步的同一条手账。
// 计时从首页可见开始，登录、设备切换和讲述停顿由现场掌握，不计入本文件的操作耗时。
interface AccountFixture { run: string; username: string; password: string; }

interface PageArea {
  left: number;
  right: number;
  top: number;
  bottom: number;
}

const BODY: string = '在陶窑与居住遗存之间，记下我对庙底沟西部空间关系的观察。';
const TAGS: string = '庙底沟，陶窑，空间观察';

async function fixture(): Promise<AccountFixture> {
  const testModule = await application.createModuleContext(TestContext.context, 'entry_test');
  return JSON.parse(new util.TextDecoder().decodeToString(await testModule.resourceManager
    .getRawFileContent('account-sync-test.json'))) as AccountFixture;
}

async function pageArea(session: ArchiveUiSession, page: string): Promise<PageArea> {
  const scroll = await session.waitId(page);
  const bounds = await scroll.getBounds();
  let top = bounds.top + 24;
  let bottom = bounds.bottom - 80;
  if (page === 'material-comparison-scroll') bottom = bounds.bottom - 24;
  if (page === 'explore-scroll' || page === 'archive-scroll') {
    const header = await session.driver.findComponent(ON.id('top-navigation-content'));
    const dock = await session.driver.findComponent(ON.id('tab-0'));
    if (header) top = Math.max(top, (await header.getBounds()).bottom + 24);
    if (dock) bottom = Math.min(bottom, (await dock.getBounds()).top - 24);
  }
  if (bottom - top < 200) throw new Error(`DEMO_PAGE_TOO_SMALL:${page}`);
  return { left: bounds.left, right: bounds.right, top, bottom };
}

async function marginSwipe(session: ArchiveUiSession, area: PageArea, towardTop: boolean,
  requestedDistance: number = 700): Promise<void> {
  const height = area.bottom - area.top;
  const distance = Math.min(700, height * 0.32, requestedDistance);
  const start = area.top + height * (towardTop ? 0.28 : 0.72);
  const x = Math.round(area.left + 12);
  await session.driver.swipe(x, Math.round(start), x,
    Math.round(start + (towardTop ? distance : -distance)), 600);
  await session.driver.delayMs(150);
}

async function inPage(session: ArchiveUiSession, page: string, target: On, hint: string): Promise<Component> {
  const area = await pageArea(session, page);
  let unknownMoves = 0;
  for (let attempt = 0; attempt <= 12; attempt++) {
    const node = await session.driver.findComponent(target);
    let towardTop = unknownMoves >= 3;
    if (node) {
      const bounds = await node.getBounds();
      if (bounds.right > bounds.left && bounds.bottom - bounds.top > 12) {
        const center = (bounds.top + bounds.bottom) / 2;
        if (center >= area.top && center <= area.bottom) return session.wait(target, hint);
        towardTop = center < area.top;
      } else unknownMoves++;
    } else unknownMoves++;
    if (attempt < 12) await marginSwipe(session, area, towardTop);
  }
  throw new Error(`DEMO_TARGET_NOT_EXPOSED:${page}:${hint}`);
}

async function frameCanvas(session: ArchiveUiSession, page: string, canvasId: string): Promise<void> {
  if (page === 'detail-scroll') {
    await (await session.waitId(page)).scrollToTop(40000);
    await session.wait(ON.id('engine-mode-relic'), '详情回顶后的真实观察模式');
  }
  const area = await pageArea(session, page);
  await inPage(session, page, ON.id(canvasId).type('Canvas'), canvasId);
  for (let attempt = 0; attempt <= 8; attempt++) {
    const node = await session.driver.findComponent(ON.id(canvasId).type('Canvas'));
    const canvas = node ? await node.getBounds() : undefined;
    if (canvas && canvas.bottom > canvas.top && canvas.top >= area.top - 8 && canvas.bottom <= area.bottom + 8) {
      console.info(`DEMO_CANVAS_FRAME:${canvasId}:${JSON.stringify(canvas)}`);
      return;
    }
    if (attempt === 8) break;
    await marginSwipe(session, area, false, 320);
  }
  throw new Error(`DEMO_CANVAS_CLIPPED:${page}:${canvasId}`);
}

async function capture(session: ArchiveUiSession, name: string): Promise<void> {
  await session.driver.delayMs(200);
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  const image = await delegator.executeShellCommand(`uitest screenCap -p /data/local/tmp/demo-rehearsal-${name}.png`);
  expect(image.exitCode).assertEqual(0);
  const layout = await delegator.executeShellCommand(`uitest dumpLayout -p /data/local/tmp/demo-rehearsal-${name}.json`);
  expect(layout.exitCode).assertEqual(0);
}

async function openMiaodigouKilns(session: ArchiveUiSession): Promise<void> {
  const site = HERITAGE_SITES.find(item => item.id === 'smx-miaodigou');
  if (!site) throw new Error('DEMO_SITE_MISSING');
  await (await inPage(session, 'explore-scroll', ON.id('home-theme-entry'), 'home-theme-entry')).click();
  await session.waitId('detail-scroll');
  await session.wait(ON.text(site.name), '详情导航标题');
  await (await inPage(session, 'detail-scroll', ON.id('observation-hotspot-kilns'),
    'observation-hotspot-kilns')).click();
  expect(await (await inPage(session, 'detail-scroll', ON.id('observation-selected-detail'),
    'observation-selected-detail')).getText()).assertEqual('正在观察 · 西部陶窑');
}

async function rehearsalA(): Promise<void> {
  const study = materialStudyForId('smx-miaodigou');
  const dimension = MATERIAL_COMPARISON.dimensions.find(item => item.id === 'body');
  if (!study || !dimension) throw new Error('DEMO_CONTENT_MISSING');
  const session = new ArchiveUiSession('demo_rehearsal_a');
  let started = 0;
  await session.run(async () => {
    await session.waitId('explore-scroll');
    started = Date.now();
    console.info('DEMO_TIMER_START');
    expect(await (await session.waitId('home-theme-progress')).getText()).assertEqual('已探索 0 / 4 处');
    await capture(session, 'home-empty');
    console.info(`DEMO_SEGMENT:home-ready:${Date.now() - started}`);

    // 第一段：首页主题直接进入庙底沟，选择西部陶窑并主动右转。
    await openMiaodigouKilns(session);
    await (await inPage(session, 'detail-scroll', ON.id('engine-right'), 'engine-right')).click();
    expect((await (await inPage(session, 'detail-scroll', ON.id('engine-angle'), 'engine-angle')).getText())
      .includes('视角 33°')).assertTrue();
    await frameCanvas(session, 'detail-scroll', 'engine-native-relic_inspector');
    await capture(session, 'observation');
    console.info(`DEMO_SEGMENT:observation:${Date.now() - started}`);

    // 第二段：首页文明连线进入双连壶与方鼎对照，切一个维度并展开一处依据。
    await session.driver.pressBack();
    await session.waitId('explore-scroll');
    await (await inPage(session, 'explore-scroll', ON.id('culture-atlas-entry'), 'culture-atlas-entry')).click();
    await session.waitId('culture-atlas-scroll');
    await (await inPage(session, 'culture-atlas-scroll', ON.id('culture-material-comparison-open'),
      'culture-material-comparison-open')).click();
    await session.waitId('material-comparison-panel');
    await session.waitId('material-comparison-scroll');
    // 维度按钮在对照面板固定头部，不属于 material-comparison-scroll 的滚动内容。
    await (await session.waitId('material-comparison-body')).click();
    expect(await (await inPage(session, 'material-comparison-scroll',
      ON.id('material-comparison-fact-left-body'), 'material-comparison-fact-left-body')).getText())
      .assertEqual(dimension.left);
    await (await inPage(session, 'material-comparison-scroll', ON.id('material-comparison-sources-left'),
      'material-comparison-sources-left')).click();
    const source = await inPage(session, 'material-comparison-scroll',
      ON.id(`material-comparison-source-left-${dimension.leftSourceIds[0]}`), 'material-comparison-source-left');
    console.info(`DEMO_COMPARISON_SOURCE:${await source.getText()}`);
    await capture(session, 'comparison');
    await (await inPage(session, 'material-comparison-scroll', ON.id('material-comparison-sources-left'),
      'material-comparison-sources-left')).click();
    console.info(`DEMO_SEGMENT:comparison:${Date.now() - started}`);
    await session.driver.pressBack();
    await session.waitId('culture-atlas-scroll');
    await session.driver.pressBack();
    await session.waitId('explore-scroll');

    // 第三段：回到庙底沟，再次选择西部陶窑并右转，真实输入并保存手账。
    await openMiaodigouKilns(session);
    await (await inPage(session, 'detail-scroll', ON.id('engine-right'), 'engine-right')).click();
    await frameCanvas(session, 'detail-scroll', 'engine-native-relic_inspector');
    await capture(session, 'saved-view');
    await (await inPage(session, 'detail-scroll', ON.id('engine-remember-view'), 'engine-remember-view')).click();
    await session.waitId('note-editor-scroll');
    await (await inPage(session, 'note-editor-scroll', ON.id('note-body'), 'note-body'))
      .inputText(BODY, { paste: true, addition: true });
    await (await inPage(session, 'note-editor-scroll', ON.id('note-tags'), 'note-tags'))
      .inputText(TAGS, { paste: true, addition: true });
    await session.driver.pressBack();
    await (await session.waitId('save-note')).click();
    await session.editorClosed();
    const saved = await session.read();
    const notes = activeRecords(saved.records, 'note');
    expect(notes.length).assertEqual(1);
    expect(notes[0].body).assertEqual(BODY);
    expect(notes[0].snapshot3DPose !== undefined).assertTrue();
    console.info(`DEMO_SEGMENT:save:${Date.now() - started}`);

    // 第四段：首页出现最新手账和真实 1/4，点击画面回到保存视角。
    await session.driver.pressBack();
    await session.waitId('explore-scroll');
    await (await session.waitId('explore-scroll')).scrollToTop(40000);
    await inPage(session, 'explore-scroll', ON.id('home-recent-memory'), 'home-recent-memory');
    expect(await (await session.waitId('home-theme-progress')).getText()).assertEqual('已探索 1 / 4 处');
    expect(await (await session.waitId('home-theme-next-site')).getText()).assertEqual('下一处 · 大河村遗址');
    expect(await (await inPage(session, 'explore-scroll',
      ON.id('home-recent-memory-preview-status').text('已恢复当时视角'),
      'home-recent-memory-preview-status')).getText()).assertEqual('已恢复当时视角');
    await frameCanvas(session, 'explore-scroll', 'home-recent-memory-preview-canvas');
    await capture(session, 'home-recent');
    await (await inPage(session, 'explore-scroll',
      ON.id('home-recent-memory-preview-canvas').type('Canvas'),
      'home-recent-memory-preview-canvas')).click();
    await session.waitId('detail-scroll');
    await session.wait(ON.id('engine-angle').text('已回到手账视角', MatchPattern.CONTAINS),
      'A 端保存视角已由详情 Canvas 实际绘制');
    expect(await (await inPage(session, 'detail-scroll', ON.id('observation-selected-detail'),
      'observation-selected-detail')).getText()).assertEqual('正在观察 · 西部陶窑');
    await frameCanvas(session, 'detail-scroll', 'engine-native-relic_inspector');
    await capture(session, 'replay');
    console.info(`DEMO_SEGMENT:replay:${Date.now() - started}`);
    console.info(`DEMO_TOTAL_A:${Date.now() - started}`);
  });
}

async function rehearsalB(): Promise<void> {
  const value = await fixture();
  const session = new ArchiveUiSession('demo_rehearsal_b', `yunheji_test_ui_${value.run}_b`, false);
  let started = 0;
  await session.run(async () => {
    // 复用 T11 的同一账号与 B 端独立库；登录在计时前完成，与现场准备一致。
    await (await session.inScroll('login-scroll', ON.id('account-mode-login'))).click();
    await (await session.inScroll('login-scroll', ON.id('account-username'))).inputText(value.username);
    await (await session.inScroll('login-scroll', ON.id('account-password'))).inputText(value.password);
    await session.driver.pressBack();
    await (await session.inScroll('login-scroll', ON.id('account-submit'))).click();
    await session.waitId('explore-scroll');
    started = Date.now();
    console.info('DEMO_B_TIMER_START');
    await (await session.waitId('explore-scroll')).scrollToTop(40000);
    await inPage(session, 'explore-scroll', ON.id('home-recent-memory'), 'home-recent-memory');
    expect(await (await session.waitId('home-theme-progress')).getText()).assertEqual('已探索 1 / 4 处');
    expect(await (await inPage(session, 'explore-scroll',
      ON.id('home-recent-memory-preview-status').text('已恢复当时视角'),
      'home-recent-memory-preview-status')).getText()).assertEqual('已恢复当时视角');
    await capture(session, 'b-home');
    await (await inPage(session, 'explore-scroll',
      ON.id('home-recent-memory-preview-canvas').type('Canvas'),
      'home-recent-memory-preview-canvas')).click();
    await session.waitId('detail-scroll');
    await session.wait(ON.id('engine-angle').text('已回到手账视角', MatchPattern.CONTAINS),
      'B 端正式回放已实际绘制');
    expect(await (await inPage(session, 'detail-scroll', ON.id('observation-selected-detail'),
      'observation-selected-detail')).getText()).assertEqual('正在观察 · 西部陶窑');
    await frameCanvas(session, 'detail-scroll', 'engine-native-relic_inspector');
    await capture(session, 'b-replay');
    console.info(`DEMO_TOTAL_B:${Date.now() - started}`);
  }, true);
}

export default function demoRehearsalTest() {
  const params = abilityDelegatorRegistry.getArguments().parameters;
  const requested = params['class'] || params['-s class'] || '';
  if (!requested.includes('DemoRehearsalTest')) return;
  describe('DemoRehearsalTest', () => {
    it('rehearsal_a_main_line', 0, async () => {
      await rehearsalA();
    });

    it('rehearsal_b_replay_segment', 0, async () => {
      await rehearsalB();
    });
  });
}
