import { abilityDelegatorRegistry, Component, MatchPattern, ON, On } from '@kit.TestKit';
import { application } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { describe, expect, it } from '@ohos/hypium';
import { activeRecords, ArchiveRecord, ArchiveSnapshot, MemoryPose } from '../../../main/ets/domain/ArchiveDomain';
import { accountStoreName } from '../../../main/ets/domain/AccountSync';
import { HERITAGE_SITES } from '../../../main/ets/data/HeritageCatalog';
import { materialStudyForId } from '../../../main/ets/data/MaterialStudyCatalog';
import { materialObservationForSite, MaterialObservationHotspot } from '../../../main/ets/domain/MaterialObservation';
import { JOURNEY_ROUTES } from '../../../main/ets/domain/JourneyRoutes';
import { defaultStampForSite, PAPER_THEMES, STAMP_TYPES } from '../../../main/ets/domain/MemoryJournal';
import { LocalArchiveRepository } from '../../../main/ets/data/LocalArchiveRepository';
import { AccountSyncClient } from '../../../main/ets/sync/AccountSyncClient';
import { ArchiveUiSession } from './ArchiveUiSession';
import { TestContext } from './TestContext';

// T11 双端样板：A 端经真实账号登录页进入独立空账号，在庙底沟“西部陶窑”主动右转后
// 保存一页手账；B 端用同一账号登录，只能由真实 HTTPS 交换收到该记录，再预览并正式回放。
// 两阶段分两次设备测试执行以保留各自独立库；断言读取磁盘快照，不以页面文字代替落盘。
interface AccountFixture { run: string; username: string; password: string; otherUsername: string; otherPassword: string; }

interface PageArea {
  left: number;
  right: number;
  top: number;
  bottom: number;
}

interface KilnExpectation {
  siteName: string;
  nextSiteName: string;
  body: string;
  tags: string[];
  quote: string;
  stamp: string;
  paper: string;
  yaw: number;
  pitch: number;
  zoom: number;
  angle: number;
  label: string;
}

const SITE_ID: string = 'smx-miaodigou';
const BODY: string = '在陶窑与居住遗存之间，记下我对庙底沟西部空间关系的观察。';

async function fixture(): Promise<AccountFixture> {
  // 与既有账号用例一致：凭证只从 entry_test 的私有 rawfile 读取；
  // 本次 A/B 共用同一份 fixture，不在两端之间重新生成账号。
  const testModule = await application.createModuleContext(TestContext.context, 'entry_test');
  return JSON.parse(new util.TextDecoder().decodeToString(await testModule.resourceManager
    .getRawFileContent('account-sync-test.json'))) as AccountFixture;
}

function kilnExpectation(run: string): KilnExpectation {
  // 期望值全部由正式领域配置推导：热点、事实摘录、印章与纸色都取真实目录项，
  // 不在测试里另写一份文案。右转一步固定为 +π/8，与视口实现一致。
  const site = HERITAGE_SITES.find(item => item.id === SITE_ID);
  const study = materialStudyForId(SITE_ID);
  const observation = materialObservationForSite(SITE_ID);
  const route = JOURNEY_ROUTES.find(item => item.id === 'earth-and-fire');
  if (!site || !study || !observation || !route) throw new Error('MEMORY_SYNC_CONTENT_MISSING');
  const kiln: MaterialObservationHotspot | undefined = observation.hotspots.find(item => item.id === 'kilns');
  if (!kiln) throw new Error('MEMORY_SYNC_KILN_MISSING');
  const fact = study.facts.find(item => item.id === kiln.factId);
  if (!fact) throw new Error('MEMORY_SYNC_FACT_MISSING');
  const nextSite = HERITAGE_SITES.find(item => item.id === route.siteIds[1]);
  if (!nextSite) throw new Error('MEMORY_SYNC_ROUTE_MISSING');
  const savedYaw = kiln.yaw + Math.PI / 8;
  const defaultStamp = defaultStampForSite(site);
  // 刻意选择与该档案默认值不同的印章与纸色，才能证明装饰元数据确实随记录传输。
  const stamp = STAMP_TYPES.find(value => value !== defaultStamp) || STAMP_TYPES[0];
  const paper = PAPER_THEMES.find(value => value !== 'rose') || PAPER_THEMES[0];
  return {
    siteName: site.name, nextSiteName: nextSite.name, body: BODY,
    tags: ['庙底沟', '陶窑', '空间观察', `跨端样板${run}`],
    quote: fact.body, stamp, paper, yaw: savedYaw, pitch: kiln.pitch, zoom: kiln.zoom,
    angle: Math.round(savedYaw * 180 / Math.PI) % 360,
    label: `${kiln.label} · ${Math.round(savedYaw * 180 / Math.PI)}°`
  };
}

async function setLoginField(session: ArchiveUiSession, id: string, text: string): Promise<void> {
  // 重试时页面可能保留上次输入；先确认并清空非空字段，避免账号被追加成新名字。
  const field = await session.inScroll('login-scroll', ON.id(id));
  if ((await field.getText()).length > 0) await field.clearText();
  const target = await session.inScroll('login-scroll', ON.id(id));
  await target.inputText(text);
}

async function fillAndSubmit(session: ArchiveUiSession, value: AccountFixture, register: boolean): Promise<string> {
  await (await session.inScroll('login-scroll', ON.id(register ? 'account-mode-register' : 'account-mode-login'))).click();
  await setLoginField(session, 'account-username', value.username);
  await setLoginField(session, 'account-password', value.password);
  // 收起软键盘后再点固定提交按钮，避免候选栏改变按钮位置。
  await session.driver.pressBack();
  await (await session.inScroll('login-scroll', ON.id('account-submit'))).click();
  // 提交后页面先清空旧提示，再出现成功首页或新的错误提示。必须看到提示先消失，
  // 否则会把上一次的“已注册”误当成本次结果。
  let sawCleared = false;
  for (let attempt = 0; attempt < 120; attempt++) {
    if (await session.driver.findComponent(ON.id('explore-scroll'))) return '';
    const message = await session.driver.findComponent(ON.id('account-message'));
    if (message) {
      const text = await message.getText();
      if (text.length > 0 && sawCleared) return text;
    } else {
      sawCleared = true;
    }
    await session.driver.delayMs(250);
  }
  throw new Error('MEMORY_SYNC_AUTH_TIMEOUT');
}

async function signIn(session: ArchiveUiSession, value: AccountFixture, register: boolean): Promise<void> {
  // 首次尝试按本轮新账号注册。仅当账号已存在（同一 fixture 被重复使用时）才退回登录，
  // 不把其他登录错误自动重试成成功；失败信息保留在异常里用于定位。
  let error = await fillAndSubmit(session, value, register);
  if (!error) return;
  if (register && error.includes('已注册')) {
    error = await fillAndSubmit(session, value, false);
    if (!error) return;
  }
  throw new Error(`MEMORY_SYNC_AUTH_FAILED: ${error}`);
}

async function accountIdOf(session: ArchiveUiSession, value: AccountFixture): Promise<string> {
  // 身份由真实账号 API 回读，只用于定位当前账号实际磁盘库；令牌不输出到日志。
  const client = new AccountSyncClient(session.context);
  if (!await client.configure()) throw new Error('MEMORY_SYNC_SERVICE_NOT_CONFIGURED');
  const identity = await client.authenticate(value.username, value.password, false);
  await client.logout();
  return identity.accountId;
}

async function readAccount(session: ArchiveUiSession, accountId: string): Promise<ArchiveSnapshot> {
  const name = accountStoreName(accountId, session.name);
  await preferences.removePreferencesFromCache(session.context, name);
  return new LocalArchiveRepository(session.context, name).load();
}

async function resetOwnAccountStore(session: ArchiveUiSession, accountId: string): Promise<void> {
  // 只重置本次运行自己的账号独立库，防止上次中断的残留被当成“先已收到”。
  // 在登录前调用：登录后应用已持有该 Preferences 实例，删除会留下失效引用。
  // 不枚举、不清理正式档案或其他运行编号的库。
  await preferences.deletePreferences(session.context, accountStoreName(accountId, session.name));
}

async function waitForComponent(session: ArchiveUiSession, target: On, attempts: number = 60): Promise<void> {
  for (let attempt = 0; attempt < attempts; attempt++) {
    if (await session.driver.findComponent(target)) return;
    await session.driver.delayMs(500);
  }
  throw new Error('MEMORY_SYNC_COMPONENT_NOT_READY');
}

async function waitForOwnNote(session: ArchiveUiSession, accountId: string, body: string): Promise<ArchiveSnapshot> {
  for (let attempt = 0; attempt < 120; attempt++) {
    const snapshot = await readAccount(session, accountId);
    const matched = activeRecords(snapshot.records, 'note').filter(record => record.body === body);
    if (matched.length > 0) return snapshot;
    await session.driver.delayMs(500);
  }
  throw new Error('MEMORY_SYNC_NOTE_NOT_RECEIVED');
}

function assertKilnPose(pose: MemoryPose, expected: KilnExpectation): void {
  expect(pose.version).assertEqual(1);
  expect(pose.sceneType).assertEqual('relic_inspector');
  expect(pose.hotspotId).assertEqual('kilns');
  expect(pose.sectionId).assertEqual('');
  expect(Math.abs(pose.yaw - expected.yaw) < 0.0001).assertTrue();
  expect(Math.abs(pose.pitch - expected.pitch) < 0.0001).assertTrue();
  expect(Math.abs(pose.zoom - expected.zoom) < 0.0001).assertTrue();
  expect(pose.label).assertEqual(expected.label);
  expect(pose.proceduralPreset).assertEqual('miaodigou_pottery');
  expect(pose.sceneRevision).assertEqual(2);
  expect(pose.rendererProfile).assertEqual('native-raster-v1');
  const frame = pose.viewFrame;
  if (!frame) throw new Error('MEMORY_SYNC_VIEW_FRAME_MISSING');
  // 原虚拟画幅必须随记录保存；卡片与另一端按它 contain，不用当前控件尺寸重算取景。
  expect(frame.width > 24 && frame.height > 46).assertTrue();
  expect(frame.textDensity !== undefined && frame.textDensity > 0).assertTrue();
  expect(typeof frame.dark === 'boolean').assertTrue();
}

function assertKilnNote(note: ArchiveRecord, expected: KilnExpectation): void {
  expect(note.kind).assertEqual('note');
  expect(note.siteId).assertEqual(SITE_ID);
  expect(note.deleted).assertFalse();
  expect(note.body).assertEqual(expected.body);
  expect(note.tags.join('|')).assertEqual(expected.tags.join('|'));
  expect(note.quotedPoemOrFact).assertEqual(expected.quote);
  expect(note.stampType).assertEqual(expected.stamp);
  expect(note.paperTheme).assertEqual(expected.paper);
  const pose = note.snapshot3DPose;
  if (!pose) throw new Error('MEMORY_SYNC_SAVED_POSE_MISSING');
  assertKilnPose(pose, expected);
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
  if (bottom - top < 200) throw new Error(`MEMORY_SYNC_PAGE_TOO_SMALL:${page}`);
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
    if (header) top = Math.max(top, (await header.getBounds()).bottom);
    if (dock) bottom = Math.min(bottom, (await dock.getBounds()).top);
  }
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
  throw new Error(`MEMORY_SYNC_TARGET_NOT_EXPOSED:${page}:${targetHint}`);
}

async function frameCanvas(session: ArchiveUiSession, page: string, canvasId: string): Promise<void> {
  // 详情页与编辑器都使用真实 Scroll；先回顶，再按未裁切视区核对 Canvas 四边。
  if (page === 'detail-scroll') {
    await (await session.waitId(page)).scrollToTop(40000);
    await session.wait(ON.id('engine-mode-relic'), '详情回顶后的真实观察模式');
  }
  await inPage(session, page, ON.id(canvasId).type('Canvas'), canvasId);
  const area = await pageArea(session, page);
  const visibleArea = await visiblePageArea(session, page);
  for (let attempt = 0; attempt <= 8; attempt++) {
    const node = await session.driver.findComponent(ON.id(canvasId).type('Canvas'));
    const canvas = node ? await node.getBounds() : undefined;
    if (canvas && canvas.right > canvas.left && canvas.bottom > canvas.top &&
      canvas.left >= visibleArea.left && canvas.right <= visibleArea.right &&
      canvas.top >= visibleArea.top && canvas.bottom <= visibleArea.bottom) {
      console.info(`T11_CANVAS_FRAME:${canvasId}:${JSON.stringify({ page, area, canvas })}`);
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
  throw new Error(`MEMORY_SYNC_CANVAS_CLIPPED:${page}:${canvasId}`);
}

async function capture(session: ArchiveUiSession, name: string, canvasId: string = ''): Promise<void> {
  // 截图与同次 dumpLayout 成对保存；Canvas 边界另行记录，供宿主机裁切逐像素核对。
  await session.driver.delayMs(250);
  if (canvasId) {
    const canvas = await session.driver.findComponent(ON.id(canvasId).type('Canvas'));
    if (!canvas) throw new Error(`MEMORY_SYNC_CAPTURE_CANVAS_MISSING:${name}`);
    console.info(`T11_CAPTURE_CANVAS:${name}:${JSON.stringify(await canvas.getBounds())}`);
  }
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  const image = await delegator.executeShellCommand(
    `uitest screenCap -p /data/local/tmp/memory-sync-${name}.png`);
  expect(image.exitCode).assertEqual(0);
  const layout = await delegator.executeShellCommand(
    `uitest dumpLayout -p /data/local/tmp/memory-sync-${name}.json`);
  expect(layout.exitCode).assertEqual(0);
}

async function assertSiteTitle(session: ArchiveUiSession, siteName: string): Promise<void> {
  // 档案名由导航栏标题承载，位于 detail-scroll 外层；只按全局可见文字查找。
  const title = await session.wait(ON.text(siteName), '详情导航标题');
  expect(await title.getText()).assertEqual(siteName);
}

async function publishOnA(): Promise<void> {
  const value = await fixture();
  const expected = kilnExpectation(value.run);
  const session = new ArchiveUiSession('memory_sync_a', `yunheji_test_ui_${value.run}_a`, false);
  const started = Date.now();
  await session.run(async () => {
    await signIn(session, value, true);
    // 注册成功后回读服务端身份；新账号的独立档案必须是 0 条，游客记录不会混入。
    const accountId = await accountIdOf(session, value);
    const fresh = await readAccount(session, accountId);
    expect(fresh.records.length).assertEqual(0);
    console.info(`T11_A_FRESH:${JSON.stringify({ deviceId: fresh.deviceId, records: fresh.records.length })}`);
    await session.waitId('explore-scroll');
    expect(await (await session.waitId('home-theme-progress')).getText()).assertEqual('已探索 0 / 4 处');
    expect(await (await session.waitId('home-theme-next-site')).getText()).assertEqual(`从${expected.siteName}开始`);

    // 首页主题直达庙底沟；打开本身只写浏览记录，不点亮路线。
    await (await inPage(session, 'explore-scroll', ON.id('home-theme-entry'), 'home-theme-entry')).click();
    await session.waitId('detail-scroll');
    await assertSiteTitle(session, expected.siteName);
    await (await inPage(session, 'detail-scroll', ON.id('observation-hotspot-kilns'),
      'observation-hotspot-kilns')).click();
    expect(await (await inPage(session, 'detail-scroll', ON.id('observation-selected-detail'),
      'observation-selected-detail')).getText()).assertEqual('正在观察 · 西部陶窑');
    expect(await (await inPage(session, 'detail-scroll', ON.id('engine-hotspot-reading'),
      'engine-hotspot-reading')).getText()).assertEqual(expected.quote);
    // 主动右转一步，使保存镜头区别于推荐镜头；回放若回到默认镜头会直接暴露。
    await (await inPage(session, 'detail-scroll', ON.id('engine-right'), 'engine-right')).click();
    expect((await (await inPage(session, 'detail-scroll', ON.id('engine-angle'), 'engine-angle')).getText())
      .includes(`视角 ${expected.angle}°`)).assertTrue();
    await frameCanvas(session, 'detail-scroll', 'engine-native-relic_inspector');
    await capture(session, 'a-saved-view', 'engine-native-relic_inspector');

    // 经“留住此刻”进入原生编辑器，保留当前视角和事实摘录。
    await (await inPage(session, 'detail-scroll', ON.id('engine-remember-view'),
      'engine-remember-view')).click();
    await session.waitId('note-editor-scroll');
    expect(await (await inPage(session, 'note-editor-scroll',
      ON.id('memory-draft-preview-status').text('已恢复当时视角'), 'memory-draft-preview-status')).getText())
      .assertEqual('已恢复当时视角');
    await frameCanvas(session, 'note-editor-scroll', 'memory-draft-preview-canvas');
    // 改用非默认印章与纸色；保存后的记录必须与这两个选择一致。
    await inPage(session, 'note-editor-scroll', ON.id('memory-stamp-index'), 'memory-stamp-index');
    await session.select('memory-stamp-index', expected.stamp);
    await (await inPage(session, 'note-editor-scroll', ON.id(`memory-paper-${expected.paper}`),
      `memory-paper-${expected.paper}`)).click();
    await (await inPage(session, 'note-editor-scroll', ON.id('note-body'), 'note-body'))
      .inputText(expected.body, { paste: true, addition: true });
    await (await inPage(session, 'note-editor-scroll', ON.id('note-tags'), 'note-tags'))
      .inputText(expected.tags.join('，'), { paste: true, addition: true });
    expect(await (await session.waitId('note-body')).getText()).assertEqual(expected.body);
    expect(await (await session.waitId('note-tags')).getText()).assertEqual(expected.tags.join('，'));
    await session.driver.pressBack();
    // 保存按钮是编辑器固定页脚，不参与滚动内容可见区。
    await (await session.waitId('save-note')).click();
    await session.editorClosed();

    // 清 Preferences 缓存后从磁盘回读；不得用预制 note 或页面文字冒充保存。
    const persisted = await waitForOwnNote(session, accountId, expected.body);
    const notes = activeRecords(persisted.records, 'note');
    expect(notes.length).assertEqual(1);
    const note = notes[0];
    assertKilnNote(note, expected);
    expect(note.deviceId).assertEqual(persisted.deviceId);
    expect(note.id.startsWith('note:')).assertTrue();
    const savedAt = Date.now();
    console.info(`T11_A_SAVED:${JSON.stringify(note)}`);
    console.info(`T11_A_SAVED_AT:${savedAt}`);

    // 首页必须真实刷新为这条记录；主题进度按有效手账点亮 1/4。
    await session.driver.pressBack();
    await session.waitId('explore-scroll');
    await (await session.waitId('explore-scroll')).scrollToTop(40000);
    await waitForComponent(session, ON.id('home-recent-memory'));
    await inPage(session, 'explore-scroll', ON.id('home-recent-memory'), 'home-recent-memory');
    expect(await (await session.waitId('home-recent-memory-site')).getText()).assertEqual(expected.siteName);
    expect(await (await session.waitId('home-recent-memory-body')).getText()).assertEqual(expected.body);
    expect(await (await session.waitId('home-theme-progress')).getText()).assertEqual('已探索 1 / 4 处');
    expect(await (await session.waitId('home-theme-next-site')).getText()).assertEqual(`下一处 · ${expected.nextSiteName}`);
    expect(await (await inPage(session, 'explore-scroll',
      ON.id('home-recent-memory-preview-status').text('已恢复当时视角'),
      'home-recent-memory-preview-status')).getText()).assertEqual('已恢复当时视角');
    await frameCanvas(session, 'explore-scroll', 'home-recent-memory-preview-canvas');
    await capture(session, 'a-home-preview', 'home-recent-memory-preview-canvas');

    // A 端的交换成功时间只读取真实账号面板：只有服务端响应通过且本机落盘后才出现。
    await (await session.waitId('profile-entry')).click();
    await session.waitId('profile-scroll');
    // 新版账号卡把旧长文案收为“已同步”。按固定状态 ID 与真实完成文案一起等待，
    // 仍要求远端交换完成，不能只看到账号面板就当作同步通过。
    const syncStatus = await session.wait(ON.id('account-sync-state').text('已同步'), 'A 端真实同步完成');
    expect(await syncStatus.getText()).assertEqual('已同步');
    console.info('T11_A_SYNC:已同步');
    await capture(session, 'a-sync-status');
    console.info(`T11_A_PHASE_MS:${Date.now() - started}`);
  }, true);
}

async function receiveOnB(): Promise<void> {
  const value = await fixture();
  const expected = kilnExpectation(value.run);
  const session = new ArchiveUiSession('memory_sync_b', `yunheji_test_ui_${value.run}_b`, false);
  const started = Date.now();
  await session.run(async () => {
    // 登录前先按服务端身份定位 B 自己的独立库，只重置本运行自己的账号库；
    // 随后确认为空，证明这条 note 不是 B 本地已有或由测试注入。
    const accountId = await accountIdOf(session, value);
    await resetOwnAccountStore(session, accountId);
    const before = await readAccount(session, accountId);
    expect(before.records.length).assertEqual(0);
    console.info(`T11_B_PRECONDITION:${JSON.stringify({ deviceId: before.deviceId, records: before.records.length })}`);

    await signIn(session, value, false);
    await session.waitId('explore-scroll');
    const loginAt = Date.now();
    const received = await waitForOwnNote(session, accountId, expected.body);
    const receivedAt = Date.now();
    const notes = activeRecords(received.records, 'note');
    expect(notes.length).assertEqual(1);
    const note = notes[0];
    assertKilnNote(note, expected);
    // 源记录身份必须保留 A 的安装实例；B 自己的快照设备 ID 仍是独立值。
    expect(note.deviceId !== received.deviceId).assertTrue();
    expect(note.updatedAt > 0).assertTrue();
    expect(activeRecords(received.records, 'progress').some(record => record.siteId === SITE_ID)).assertTrue();
    console.info(`T11_B_RECEIVED:${JSON.stringify(note)}`);
    console.info(`T11_B_SNAPSHOT_DEVICE:${received.deviceId}`);
    console.info(`T11_B_TIMING:${JSON.stringify({ loginAt, receivedAt, latencyMs: receivedAt - loginAt })}`);

    // B 首页必须显示收到的最新手账与真实 1/4，预览按保存画幅重建。
    // 磁盘同步先于页面发布，这里等待首页由新快照重建后再核对文字与画面。
    await waitForComponent(session, ON.id('home-recent-memory'));
    await (await session.waitId('explore-scroll')).scrollToTop(40000);
    await inPage(session, 'explore-scroll', ON.id('home-recent-memory'), 'home-recent-memory');
    expect(await (await session.waitId('home-recent-memory-site')).getText()).assertEqual(expected.siteName);
    expect(await (await session.waitId('home-recent-memory-body')).getText()).assertEqual(expected.body);
    expect(await (await session.waitId('home-theme-progress')).getText()).assertEqual('已探索 1 / 4 处');
    expect(await (await session.waitId('home-theme-next-site')).getText()).assertEqual(`下一处 · ${expected.nextSiteName}`);
    expect(await (await inPage(session, 'explore-scroll',
      ON.id('home-recent-memory-preview-status').text('已恢复当时视角'),
      'home-recent-memory-preview-status')).getText()).assertEqual('已恢复当时视角');
    await frameCanvas(session, 'explore-scroll', 'home-recent-memory-preview-canvas');
    await capture(session, 'b-home-preview', 'home-recent-memory-preview-canvas');

    // 点击 B 卡片画面进入正式回放；等待实际绘制回调，而不是只看参数解析。
    await (await inPage(session, 'explore-scroll',
      ON.id('home-recent-memory-preview-canvas').type('Canvas'),
      'home-recent-memory-preview-canvas')).click();
    await session.waitId('detail-scroll');
    await session.wait(ON.id('engine-angle').text('已回到手账视角', MatchPattern.CONTAINS),
      '保存观察视角已由 B 端详情 Canvas 实际绘制');
    await assertSiteTitle(session, expected.siteName);
    expect(await (await inPage(session, 'detail-scroll', ON.id('observation-selected-detail'),
      'observation-selected-detail')).getText()).assertEqual('正在观察 · 西部陶窑');
    expect(await (await inPage(session, 'detail-scroll', ON.id('engine-hotspot-reading'),
      'engine-hotspot-reading')).getText()).assertEqual(expected.quote);
    await frameCanvas(session, 'detail-scroll', 'engine-native-relic_inspector');
    await capture(session, 'b-replay', 'engine-native-relic_inspector');
    // 恢复后的相机仍是保存值：再右转一步应得到保存角度 +45°。
    const turnedAngle = Math.round((expected.yaw + Math.PI / 8) * 180 / Math.PI) % 360;
    await (await inPage(session, 'detail-scroll', ON.id('engine-right'), 'engine-right')).click();
    expect((await (await inPage(session, 'detail-scroll', ON.id('engine-angle'), 'engine-angle')).getText())
      .includes(`视角 ${turnedAngle}°`)).assertTrue();

    // B 的账号同步状态来自真实账号面板，并从磁盘回读确认仍是同一条记录。
    await session.driver.pressBack();
    await session.waitId('explore-scroll');
    await (await session.waitId('profile-entry')).click();
    await session.waitId('profile-scroll');
    const syncStatus = await session.wait(ON.id('account-sync-state').text('已同步'), 'B 端真实同步完成');
    expect(await syncStatus.getText()).assertEqual('已同步');
    console.info('T11_B_SYNC:已同步');
    await capture(session, 'b-sync-status');
    const finalSnapshot = await readAccount(session, accountId);
    expect(finalSnapshot.records.some(record => record.id === note.id && record.body === expected.body)).assertTrue();
    console.info(`T11_B_FINAL:${JSON.stringify({ noteId: note.id, recordCount: finalSnapshot.records.length })}`);
    console.info(`T11_B_PHASE_MS:${Date.now() - started}`);
  }, true);
}

async function cleanupRun(): Promise<void> {
  const value = await fixture();
  const session = new ArchiveUiSession('memory_sync_cleanup', `yunheji_test_ui_${value.run}_cleanup`);
  await session.run(async () => {
    let accountId = '';
    try { accountId = await accountIdOf(session, value); } catch { accountId = ''; }
    // 只删除本轮已知的 a/b 独立测试库；不枚举或清理正式档案与其他运行编号。
    for (const suffix of ['a', 'b']) {
      const base = `yunheji_test_ui_${value.run}_${suffix}`;
      if (accountId) await preferences.deletePreferences(session.context, accountStoreName(accountId, base));
      await preferences.deletePreferences(session.context, base);
    }
    console.info(`T11_CLEANUP:${value.run}`);
  });
}

export default function memorySyncTest() {
  const params = abilityDelegatorRegistry.getArguments().parameters;
  const requested = params['class'] || params['-s class'] || '';
  if (!requested.includes('MemorySyncTest')) return;
  describe('MemorySyncTest', () => {
    it('device_a_publish_kiln_memory', 0, async () => {
      await publishOnA();
    });

    it('device_b_receive_preview_and_replay', 0, async () => {
      await receiveOnB();
    });

    it('cleanup_only_this_run_test_preferences', 0, async () => {
      await cleanupRun();
    });
  });
}
