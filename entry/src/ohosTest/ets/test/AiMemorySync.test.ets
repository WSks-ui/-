import { abilityDelegatorRegistry, Component, MatchPattern, ON, On } from '@kit.TestKit';
import { application, common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { describe, expect, it } from '@ohos/hypium';
import {
  activeRecords, AiFactSnapshot, ArchiveRecord, ArchiveSnapshot, compareVersions, copySnapshot, MemoryPose
} from '../../../main/ets/domain/ArchiveDomain';
import { accountStoreName } from '../../../main/ets/domain/AccountSync';
import { aiKnowledgeScope } from '../../../main/ets/domain/AiObservationKnowledge';
import { HERITAGE_SITES } from '../../../main/ets/data/HeritageCatalog';
import { materialObservationForSite, MaterialObservationHotspot } from '../../../main/ets/domain/MaterialObservation';
import { defaultStampForSite, PAPER_THEMES, STAMP_TYPES } from '../../../main/ets/domain/MemoryJournal';
import { AccountWorkspaceStore } from '../../../main/ets/data/AccountWorkspaceStore';
import { LocalArchiveRepository } from '../../../main/ets/data/LocalArchiveRepository';
import { AccountSyncClient } from '../../../main/ets/sync/AccountSyncClient';
import { DistributedArchiveChannel } from '../../../main/ets/sync/DistributedArchiveChannel';
import { ArchiveUiSession } from './ArchiveUiSession';
import { TestContext } from './TestContext';

interface AiSyncFixture { run: string; username: string; password: string; }
interface PageArea { left: number; right: number; top: number; bottom: number; }
interface DahecunExpectation { tag: string; stamp: string; paper: string; opening: MaterialObservationHotspot; }

const SITE_ID: string = 'zz-dahecun';
const QUESTION: string = '腹部相通的位置在哪里？';
const OBSERVATION: string = '我先看两只壶口，再沿浅绿色通道找到两腹之间的椭圆通口，理解两壶内部相通。';
const CANVAS_ID: string = 'engine-native-relic_inspector';

async function fixture(): Promise<AiSyncFixture> {
  // A/B 使用同一个私有 rawfile。凭证由宿主机放到已被 Git 忽略的位置，
  // 不在源码里创建账号，也不把账号、密码、令牌写入日志或截图。
  const moduleContext = await application.createModuleContext(TestContext.context, 'entry_test');
  const value = JSON.parse(new util.TextDecoder().decodeToString(await moduleContext.resourceManager
    .getRawFileContent('account-sync-test.json'))) as AiSyncFixture;
  if (!/^[a-z0-9_]{1,30}$/.test(value.run) || !/^[a-z0-9_]{4,32}$/.test(value.username) ||
    value.password.length < 10 || value.password.length > 128) throw new Error('AI_MEMORY_SYNC_FIXTURE_INVALID');
  return value;
}

function storeFor(value: AiSyncFixture, side: string): string {
  if (side !== 'a' && side !== 'b' && side !== 'cleanup') throw new Error('AI_MEMORY_SYNC_SCOPE_INVALID');
  return `yunheji_test_ui_${value.run}_ai_${side}`;
}

function expectation(value: AiSyncFixture): DahecunExpectation {
  const site = HERITAGE_SITES.find(item => item.id === SITE_ID);
  const observation = materialObservationForSite(SITE_ID);
  const opening = observation?.hotspots.find(item => item.id === 'opening');
  if (!site || !opening || !observation) throw new Error('AI_MEMORY_SYNC_CONTENT_MISSING');
  expect(observation.sceneRevision).assertEqual(2);
  expect(observation.proceduralPreset).assertEqual('dahecun_pottery');
  return {
    // 标签只标识本次测试，不含账号信息；长度仍满足正式编辑器限制。
    tag: `双连壶跨端${value.run}`,
    stamp: STAMP_TYPES.find(item => item !== defaultStampForSite(site)) || STAMP_TYPES[0],
    paper: PAPER_THEMES.find(item => item !== 'rose') || PAPER_THEMES[0], opening
  };
}

function redactedError(error: Error, value: AiSyncFixture): string {
  return error.message.split(value.username).join('[账号已隐藏]').split(value.password).join('[凭证已隐藏]');
}

async function signIn(session: ArchiveUiSession, value: AiSyncFixture, register: boolean): Promise<void> {
  await (await session.inScroll('login-scroll', ON.id(register ? 'account-mode-register' : 'account-mode-login'))).click();
  for (const id of ['account-username', 'account-password']) {
    const field = await session.inScroll('login-scroll', ON.id(id));
    if ((await field.getText()).length > 0) await field.clearText();
    await (await session.inScroll('login-scroll', ON.id(id)))
      .inputText(id === 'account-username' ? value.username : value.password);
  }
  await session.driver.pressBack();
  await (await session.inScroll('login-scroll', ON.id('account-submit'))).click();
  for (let attempt = 0; attempt < 120; attempt++) {
    if (await session.driver.findComponent(ON.id('explore-scroll'))) return;
    const message = await session.driver.findComponent(ON.id('account-message'));
    if (message && (await message.getText()).length > 0) {
      // A 必须是真实新注册；账号已存在也失败，防止复用旧远端数据冒充本轮新保存。
      throw new Error(`AI_MEMORY_SYNC_AUTH_FAILED:${await message.getText()}`);
    }
    await session.driver.delayMs(250);
  }
  throw new Error('AI_MEMORY_SYNC_AUTH_TIMEOUT');
}

async function currentAccount(session: ArchiveUiSession): Promise<string> {
  const restored = await new AccountWorkspaceStore(session.context, session.name).load();
  if (!restored || !restored.session) throw new Error('AI_MEMORY_SYNC_AUTHENTICATED_WORKSPACE_MISSING');
  return restored.workspace.accountId;
}

async function identifyForB(session: ArchiveUiSession, value: AiSyncFixture): Promise<string> {
  // 登录 UI 前仅用真实认证定位 B 的独立库。这个临时会话不写身份指针，
  // 不传任何 note，立即注销；随后仍须经正式登录页进入同一账号。
  const client = new AccountSyncClient(session.context);
  if (!await client.configure()) throw new Error('AI_MEMORY_SYNC_SERVICE_NOT_CONFIGURED');
  try { return (await client.authenticate(value.username, value.password, false)).accountId; }
  finally { await client.logout(); }
}

async function readAccount(session: ArchiveUiSession, accountId: string): Promise<ArchiveSnapshot> {
  const name = accountStoreName(accountId, session.name);
  await preferences.removePreferencesFromCache(session.context, name);
  return new LocalArchiveRepository(session.context, name).load();
}

function ownNote(snapshot: ArchiveSnapshot, tag: string): ArchiveRecord | undefined {
  const notes = activeRecords(snapshot.records, 'note');
  const matched = notes.filter(note => note.tags.includes(tag));
  if (matched.length > 1) throw new Error('AI_MEMORY_SYNC_DUPLICATE_TAGGED_NOTES');
  return matched[0];
}

async function waitForNote(session: ArchiveUiSession, accountId: string, tag: string): Promise<ArchiveSnapshot> {
  for (let attempt = 0; attempt < 90; attempt++) {
    const snapshot = await readAccount(session, accountId);
    if (ownNote(snapshot, tag)) return snapshot;
    await session.driver.delayMs(500);
  }
  throw new Error('AI_MEMORY_SYNC_NOTE_NOT_RECEIVED');
}

async function capture(session: ArchiveUiSession, name: string, canvasId: string = ''): Promise<void> {
  // 登录页和个人页账号卡都可能显示身份资料；连失败截图也拒绝这些页面，
  // 不以“稍后放进私有目录”为由先截下账号。截图和同次 layout 一并保存。
  for (const privateId of ['login-scroll', 'account-panel', 'profile-scroll']) {
    if (await session.driver.findComponent(ON.id(privateId))) throw new Error('AI_MEMORY_SYNC_CAPTURE_WITH_ACCOUNT_DENIED');
  }
  await session.driver.delayMs(200);
  if (canvasId) {
    const canvas = await session.wait(ON.id(canvasId).type('Canvas'));
    console.info(`AI_MEMORY_SYNC_CANVAS:${name}:${JSON.stringify(await canvas.getBounds())}`);
  }
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  expect((await delegator.executeShellCommand(`uitest screenCap -p /data/local/tmp/ai-memory-sync-${name}.png`))
    .exitCode).assertEqual(0);
  expect((await delegator.executeShellCommand(`uitest dumpLayout -p /data/local/tmp/ai-memory-sync-${name}.json`))
    .exitCode).assertEqual(0);
}

async function runPhase(session: ArchiveUiSession, value: AiSyncFixture, phase: string,
  resume: boolean, action: () => Promise<void>): Promise<void> {
  const started = Date.now();
  let startedSession = false;
  try {
    await session.start(resume);
    startedSession = true;
    await action();
    console.info(`AI_MEMORY_SYNC_PHASE:${phase}:${Date.now() - started}`);
  } catch (error) {
    // ArchiveUiSession.run 的通用失败截屏会把登录中的账号带进证据。
    // 此组阶段独立包裹异常，只在明确离开登录页之后记录原生画面。
    try {
      if (startedSession && !await session.driver.findComponent(ON.id('login-scroll'))) {
        await capture(session, `${phase}-failure`);
      }
    } catch { console.error('AI_MEMORY_SYNC_FAILURE_CAPTURE_UNAVAILABLE'); }
    console.info(`AI_MEMORY_SYNC_PHASE_FAILED:${phase}:${Date.now() - started}`);
    throw new Error(redactedError(error as Error, value));
  } finally {
    // 保留账号身份指针、ASSET 和磁盘库，下一阶段必须从真实原库恢复。
    // 不在成功或失败后提前 dispose，清理由最后的显式 cleanup case 执行。
    if (startedSession) await session.stop();
  }
}

async function pageArea(session: ArchiveUiSession, page: string, inset: boolean = true): Promise<PageArea> {
  const bounds = await (await session.waitId(page)).getBounds();
  let top = bounds.top;
  let bottom = bounds.bottom;
  if (page === 'explore-scroll' || page === 'archive-scroll' || page === 'device-scroll') {
    const header = await session.driver.findComponent(ON.id('top-navigation-content'));
    const dock = await session.driver.findComponent(ON.id('tab-0'));
    if (header) top = Math.max(top, (await header.getBounds()).bottom);
    if (dock) bottom = Math.min(bottom, (await dock.getBounds()).top);
  }
  if (inset) { top += 24; bottom -= 80; }
  if (bottom - top < 200) throw new Error('AI_MEMORY_SYNC_PAGE_TOO_SMALL');
  return { left: bounds.left, right: bounds.right, top, bottom };
}

async function marginSwipe(session: ArchiveUiSession, area: PageArea, towardTop: boolean,
  requested: number = 700): Promise<void> {
  const height = area.bottom - area.top;
  const distance = Math.min(700, height * 0.32, requested);
  const start = area.top + height * (towardTop ? 0.28 : 0.72);
  // 手势从内容左缘开始，避免滚动时误转真实模型或拖动 TextArea。
  await session.driver.swipe(Math.round(area.left + 12), Math.round(start),
    Math.round(area.left + 12), Math.round(start + (towardTop ? distance : -distance)), 600);
  await session.driver.delayMs(100);
}

async function inPage(session: ArchiveUiSession, page: string, target: On, targetHint: string): Promise<Component> {
  // 详情目标可能在真实模型下方很远，UiTest 对屏外节点只给零范围或不挂载。
  // 复用已有页首 / 页尾锚点判断方向的搜索，不能把连续未知节点固定解释为目标在上方。
  if (page === 'detail-scroll') {
    try { return await session.inScroll(page, target); }
    catch (error) { throw new Error(`AI_MEMORY_SYNC_DETAIL_TARGET:${targetHint}:${(error as Error).message}`); }
  }
  const area = await pageArea(session, page);
  let unknownMoves = 0;
  for (let attempt = 0; attempt <= 12; attempt++) {
    const component = await session.driver.findComponent(target);
    let towardTop = unknownMoves >= 3;
    if (component) {
      const bounds = await component.getBounds();
      if (bounds.right > bounds.left && bounds.bottom - bounds.top > 12) {
        const center = (bounds.top + bounds.bottom) / 2;
        if (center >= area.top && center <= area.bottom) return session.wait(target, `${page}:${targetHint}`);
        towardTop = center < area.top;
      } else unknownMoves++;
    } else unknownMoves++;
    if (attempt < 12) await marginSwipe(session, area, towardTop);
  }
  throw new Error(`AI_MEMORY_SYNC_TARGET_NOT_EXPOSED:${page}:${targetHint}`);
}

async function click(session: ArchiveUiSession, page: string, id: string): Promise<void> {
  await (await inPage(session, page, ON.id(id), id)).click();
}

async function frameCanvas(session: ArchiveUiSession): Promise<void> {
  await (await session.waitId('detail-scroll')).scrollToTop(40000);
  await inPage(session, 'detail-scroll', ON.id(CANVAS_ID).type('Canvas'), CANVAS_ID);
  const safe = await pageArea(session, 'detail-scroll');
  const visible = await pageArea(session, 'detail-scroll', false);
  for (let attempt = 0; attempt <= 8; attempt++) {
    const bounds = await (await session.wait(ON.id(CANVAS_ID).type('Canvas'))).getBounds();
    if (bounds.right > bounds.left && bounds.bottom > bounds.top && bounds.left >= visible.left &&
      bounds.right <= visible.right && bounds.top >= visible.top && bounds.bottom <= visible.bottom) return;
    if (attempt < 8) await marginSwipe(session, safe, bounds.top < safe.top + 80);
  }
  throw new Error('AI_MEMORY_SYNC_CANVAS_CLIPPED');
}

async function waitForAi(session: ArchiveUiSession, id: string): Promise<void> {
  const result = await session.driver.waitForComponent(ON.id(id), 35000);
  if (!result) throw new Error(`AI_MEMORY_SYNC_REAL_MODEL_RESULT_MISSING:${id}`);
}

function assertNoFangding(text: string): void {
  for (const forbidden of ['zz-duling-fangding', 'duling_', 'duling-', 'museum-duling', 'fangding', '方鼎', '饕餮', '杜岭']) {
    expect(text.includes(forbidden)).assertFalse();
  }
}

function assertPose(pose: MemoryPose | undefined, expected: DahecunExpectation): void {
  if (!pose) throw new Error('AI_MEMORY_SYNC_POSE_MISSING');
  expect(pose.version).assertEqual(1);
  expect(pose.sceneType).assertEqual('relic_inspector');
  expect(pose.hotspotId).assertEqual('opening');
  expect(pose.sectionId).assertEqual('');
  expect(pose.proceduralPreset).assertEqual('dahecun_pottery');
  expect(pose.sceneRevision).assertEqual(2);
  expect(pose.rendererProfile).assertEqual('native-raster-v1');
  // 真实聚焦动作已把相机转到 opening；采纳草稿必须由 Canvas 回传该镜头，
  // 不能由编辑器重新套另一热点、默认相机或当前卡片大小。
  expect(Math.abs(pose.yaw - expected.opening.yaw) < 0.0001).assertTrue();
  expect(Math.abs(pose.pitch - expected.opening.pitch) < 0.0001).assertTrue();
  expect(Math.abs(pose.zoom - expected.opening.zoom) < 0.0001).assertTrue();
  expect(pose.label).assertEqual(`${expected.opening.label} · ${Math.round(pose.yaw * 180 / Math.PI)}°`);
  const frame = pose.viewFrame;
  if (!frame) throw new Error('AI_MEMORY_SYNC_FRAME_MISSING');
  expect(Number.isFinite(frame.width) && frame.width > 24).assertTrue();
  expect(Number.isFinite(frame.height) && frame.height > 46).assertTrue();
  expect(frame.textDensity !== undefined && Number.isFinite(frame.textDensity) && frame.textDensity > 0).assertTrue();
  expect(typeof frame.dark === 'boolean').assertTrue();
}

function assertNote(note: ArchiveRecord, expected: DahecunExpectation): void {
  expect(note.kind).assertEqual('note');
  expect(note.siteId).assertEqual(SITE_ID);
  expect(note.deleted).assertFalse();
  expect(note.id.startsWith('note:')).assertTrue();
  expect(note.updatedAt > 0).assertTrue();
  expect(note.body.length > 0).assertTrue();
  expect(note.tags.includes(expected.tag)).assertTrue();
  expect(note.stampType).assertEqual(expected.stamp);
  expect(note.paperTheme).assertEqual(expected.paper);
  assertPose(note.snapshot3DPose, expected);
  const scope = aiKnowledgeScope(SITE_ID);
  const assist = note.aiAssist;
  if (!scope || !assist) throw new Error('AI_MEMORY_SYNC_FROZEN_ASSIST_MISSING');
  expect(assist.version).assertEqual(1);
  expect(assist.question).assertEqual(QUESTION);
  expect(assist.contentRevision).assertEqual(scope.contentRevision);
  expect(assist.factIds.includes('dahecun-opening')).assertTrue();
  expect(assist.facts.some(fact => fact.id === 'dahecun-opening')).assertTrue();
  expect(assist.factIds.length).assertEqual(assist.facts.length);
  expect(new Set<string>(assist.factIds).size).assertEqual(assist.factIds.length);
  assist.facts.forEach((saved: AiFactSnapshot) => {
    const original = scope.facts.find(item => item.id === saved.id);
    if (!original) throw new Error('AI_MEMORY_SYNC_WRONG_OBJECT_FACT');
    expect(saved.id.startsWith('dahecun-')).assertTrue();
    expect(assist.factIds.includes(saved.id)).assertTrue();
    expect(saved.title).assertEqual(original.title);
    expect(saved.body).assertEqual(original.body);
    expect(saved.sourceIds.join('|')).assertEqual(original.sourceIds.join('|'));
    expect(saved.sourceIds.length > 0).assertTrue();
    saved.sourceIds.forEach((id: string) => {
      expect(scope.sources.some(source => source.id === id)).assertTrue();
      expect(id.includes('dahecun')).assertTrue();
    });
  });
  // 摘录由客户端从冻结事实选取，不接受模型自由生成的考古“依据”。
  expect(assist.facts.some(fact => fact.body === note.quotedPoemOrFact)).assertTrue();
  assertNoFangding(JSON.stringify(note));
}

function printNote(label: string, note: ArchiveRecord): void {
  // 单条完整 JSON 容易超过 HiLog 行长。分片保存 JSON 字符串，宿主机按序对每片
  // JSON.parse 后 join，再 JSON.parse 整条记录，逐字段比较 A/B；不裁掉任何 note 字段。
  const json = JSON.stringify(note);
  const count = Math.ceil(json.length / 360);
  console.info(`AI_MEMORY_SYNC_NOTE_META:${label}:${JSON.stringify({ parts: count, chars: json.length })}`);
  for (let part = 0; part < count; part++) {
    console.info(`AI_MEMORY_SYNC_NOTE_PART:${label}:${part}:${JSON.stringify(json.slice(part * 360, (part + 1) * 360))}`);
  }
}

async function confirmRemoteVersion(session: ArchiveUiSession, snapshot: ArchiveSnapshot,
  note: ArchiveRecord): Promise<void> {
  // 空 records 只读取服务端已接收版本；测试探测绝不把本地 note 上传，
  // 否则会掩盖正式页面没有同步的故障。设备 ID 沿用本端，不虚构新设备。
  const restored = await new AccountWorkspaceStore(session.context, session.name).load();
  if (!restored?.session) throw new Error('AI_MEMORY_SYNC_REMOTE_SESSION_MISSING');
  const client = new AccountSyncClient(session.context);
  if (!await client.configure()) throw new Error('AI_MEMORY_SYNC_SERVICE_NOT_CONFIGURED');
  client.restoreSession(restored.session);
  const probe = copySnapshot(snapshot);
  probe.records = [];
  for (let attempt = 0; attempt < 4; attempt++) {
    const remote = (await client.exchange(probe)).records.find(item => item.id === note.id);
    if (remote && compareVersions(note, remote) === 0) {
      console.info('AI_MEMORY_SYNC_SERVER_CONFIRMED:FULL_RECORD_VERSION');
      return;
    }
    await session.driver.delayMs(500);
  }
  throw new Error('AI_MEMORY_SYNC_SERVER_VERSION_NOT_CONFIRMED');
}

async function assertEvidence(session: ArchiveUiSession, prefix: string, page: string,
  facts: AiFactSnapshot[]): Promise<void> {
  const scope = aiKnowledgeScope(SITE_ID);
  if (!scope) throw new Error('AI_MEMORY_SYNC_SCOPE_MISSING');
  for (const fact of facts) {
    const cardId = `${prefix}${fact.id}`;
    await inPage(session, page, ON.id(cardId), cardId);
    expect(await (await session.wait(ON.text(fact.title).within(ON.id(cardId)))).getText()).assertEqual(fact.title);
    expect(await (await session.wait(ON.text(fact.body).within(ON.id(cardId)))).getText()).assertEqual(fact.body);
    for (const sourceId of fact.sourceIds) {
      const source = scope.sources.find(item => item.id === sourceId);
      if (!source) throw new Error('AI_MEMORY_SYNC_SOURCE_MISSING');
      await inPage(session, page, ON.text(source.publisher, MatchPattern.CONTAINS).within(ON.id(cardId)),
        `${cardId}:source:${sourceId}`);
    }
  }
}

async function openMemory(session: ArchiveUiSession, note: ArchiveRecord): Promise<void> {
  await (await session.waitId('tab-1')).click();
  await click(session, 'archive-scroll', `memory-open-${note.id}`);
  await session.waitId('memory-detail-scroll');
  expect(await (await inPage(session, 'memory-detail-scroll', ON.id('memory-detail-body'),
    'memory-detail-body')).getText()).assertEqual(note.body);
}

async function publishOnA(): Promise<void> {
  const value = await fixture();
  const expected = expectation(value);
  const session = new ArchiveUiSession('ai_memory_a', storeFor(value, 'a'), false);
  await runPhase(session, value, 'a-save', false, async () => {
    await signIn(session, value, true);
    const accountId = await currentAccount(session);
    expect((await readAccount(session, accountId)).records.length).assertEqual(0);
    console.info('AI_MEMORY_SYNC_A_FRESH:0');
    await (await session.waitId('tab-2')).click();
    await click(session, 'device-scroll', 'library-ai-open-dahecun');
    await session.waitId('detail-scroll');
    const question = await inPage(session, 'detail-scroll', ON.id('ai-question-input'), 'ai-question-input');
    if ((await question.getText()).length > 0) await question.clearText();
    await (await inPage(session, 'detail-scroll', ON.id('ai-question-input'), 'ai-question-input')).inputText(QUESTION);
    await session.driver.pressBack();
    await click(session, 'detail-scroll', 'ai-send');
    await waitForAi(session, 'ai-answer');
    const answer = await (await inPage(session, 'detail-scroll', ON.id('ai-answer'), 'ai-answer')).getText();
    expect(answer.length > 0).assertTrue();
    assertNoFangding(answer);
    await click(session, 'detail-scroll', 'ai-action-opening');
    expect(await (await session.waitId('ai-focus-visible')).getText()).assertEqual('AI 已定位 · 腹部通口');
    expect(await (await inPage(session, 'detail-scroll', ON.id('observation-selected-detail'), 'observation-selected-detail')).getText())
      .assertEqual('正在观察 · 腹部通口');
    await frameCanvas(session);
    await capture(session, 'a-opening-focus', CANVAS_ID);

    await click(session, 'detail-scroll', 'ai-continue');
    await inPage(session, 'detail-scroll', ON.id('ai-question-input'), 'ai-question-input');
    await session.driver.delayMs(650);
    // “继续追问”只尝试恢复焦点，不能据此认定键盘已经打开。
    // 无条件 Back 在键盘未出现时会退出详情；等真实输入框就绪后直接操作依据按钮。
    console.info('AI_MEMORY_SYNC_A_CONTINUE:QUESTION_READY');
    await click(session, 'detail-scroll', 'ai-evidence-toggle');
    const opening = aiKnowledgeScope(SITE_ID)?.facts.find(fact => fact.id === 'dahecun-opening');
    if (!opening) throw new Error('AI_MEMORY_SYNC_OPENING_FACT_MISSING');
    await assertEvidence(session, 'ai-evidence-', 'detail-scroll', [opening]);
    await capture(session, 'a-answer-evidence');
    await (await inPage(session, 'detail-scroll', ON.id('ai-observation-input'), 'ai-observation-input')).inputText(OBSERVATION);
    // 沿用已走通的单端路径：输入后直接滚动点击草稿按钮，不插入额外键盘操作。
    await click(session, 'detail-scroll', 'ai-draft-request');
    await waitForAi(session, 'ai-draft-adopt');
    const draftBody = await (await inPage(session, 'detail-scroll', ON.id('ai-draft-body'), 'ai-draft-body')).getText();
    expect(draftBody.length > 0).assertTrue();
    assertNoFangding(draftBody);
    await click(session, 'detail-scroll', 'ai-draft-adopt');
    await session.waitId('note-editor-scroll');
    expect(await (await inPage(session, 'note-editor-scroll', ON.id('note-body'), 'note-body')).getText()).assertEqual(draftBody);
    expect(await (await inPage(session, 'note-editor-scroll', ON.id('memory-draft-preview-status'), 'memory-draft-preview-status')).getText())
      .assertEqual('已恢复当时视角');
    await inPage(session, 'note-editor-scroll', ON.id('memory-stamp-index'), 'memory-stamp-index');
    await session.select('memory-stamp-index', expected.stamp);
    await click(session, 'note-editor-scroll', `memory-paper-${expected.paper}`);
    const tagsField = await inPage(session, 'note-editor-scroll', ON.id('note-tags'), 'note-tags');
    const aiTags = await tagsField.getText();
    await tagsField.clearText();
    await (await inPage(session, 'note-editor-scroll', ON.id('note-tags'), 'note-tags'))
      .inputText(`${aiTags}${aiTags ? '，' : ''}${expected.tag}`, { paste: true, addition: true });
    // UiTest 粘贴不保证打开 IME；直接点固定保存按钮，由正式 saveNote 结束输入。
    // 此处 Back 可能触发 Sheet 的“放弃修改”提示，不能用来替代确认保存。
    await capture(session, 'a-editor-confirm');
    console.info('AI_MEMORY_SYNC_A_CONFIRM_SAVE:EDITOR_READY');
    await (await session.waitId('save-note')).click();
    await session.editorClosed();
    const snapshot = await waitForNote(session, accountId, expected.tag);
    expect(activeRecords(snapshot.records, 'note').length).assertEqual(1);
    const note = ownNote(snapshot, expected.tag)!;
    assertNote(note, expected);
    expect(note.body).assertEqual(draftBody);
    expect(note.deviceId).assertEqual(snapshot.deviceId);

    // 先等正式页面确认当前记录版本，再进行空上传探测；只看旧的“已同步”时间不够。
    await session.driver.pressBack();
    await session.waitId('native-dock');
    await (await session.waitId('profile-entry')).click();
    await session.wait(ON.id('account-sync-state').text('已同步'), 'A 端本次记录已同步');
    await confirmRemoteVersion(session, snapshot, note);
    printNote('A', note);
    console.info('AI_MEMORY_SYNC_A_SAVE_CONFIRMED:DISK_AND_SERVER');
  });
}

async function receiveOnB(): Promise<void> {
  const value = await fixture();
  const expected = expectation(value);
  const session = new ArchiveUiSession('ai_memory_b', storeFor(value, 'b'), false);
  await runPhase(session, value, 'b-receive', false, async () => {
    const accountId = await identifyForB(session, value);
    const workspace = await new AccountWorkspaceStore(session.context, session.name).load();
    expect(workspace === undefined).assertTrue();
    // 首次 B 使用本次 run 的独立库；若存在残留不做预制数据覆盖，而是直接拒绝。
    // load 只创建空快照，唯一 note 只能从正式账号同步进入。
    const before = await readAccount(session, accountId);
    expect(before.records.length).assertEqual(0);
    console.info('AI_MEMORY_SYNC_B_BEFORE_LOGIN:EMPTY_ACCOUNT_STORE');
    await signIn(session, value, false);
    expect(await currentAccount(session)).assertEqual(accountId);
    const received = await waitForNote(session, accountId, expected.tag);
    expect(activeRecords(received.records, 'note').length).assertEqual(1);
    const note = ownNote(received, expected.tag)!;
    assertNote(note, expected);
    expect(note.deviceId !== received.deviceId).assertTrue();
    printNote('B', note);
    await openMemory(session, note);
    expect(await (await inPage(session, 'memory-detail-scroll', ON.id('memory-detail-question'),
      'memory-detail-question')).getText()).assertEqual(QUESTION);
    await click(session, 'memory-detail-scroll', 'memory-detail-evidence');
    await assertEvidence(session, 'memory-fact-', 'memory-detail-scroll', note.aiAssist!.facts);
    await capture(session, 'b-frozen-evidence');
    await click(session, 'memory-detail-scroll', 'memory-detail-replay');
    await session.wait(ON.id('engine-angle').text('已回到手账视角', MatchPattern.CONTAINS), 'B 真实 Canvas 回放完成');
    expect(await (await inPage(session, 'detail-scroll', ON.id('observation-selected-detail'), 'observation-selected-detail')).getText())
      .assertEqual('正在观察 · 腹部通口');
    expect(await (await inPage(session, 'detail-scroll', ON.id('engine-hotspot-reading'), 'engine-hotspot-reading')).getText())
      .assertEqual(note.aiAssist!.facts.find(fact => fact.id === 'dahecun-opening')!.body);
    await frameCanvas(session);
    await capture(session, 'b-replay', CANVAS_ID);
    const after = await readAccount(session, accountId);
    expect(activeRecords(after.records, 'note').length).assertEqual(1);
    expect(compareVersions(note, ownNote(after, expected.tag)!)).assertEqual(0);
    console.info('AI_MEMORY_SYNC_B_RECEIVED:PASSIVE_HTTPS_AND_NATIVE_REPLAY');
  });
}

async function askAgainOnB(): Promise<void> {
  const value = await fixture();
  const expected = expectation(value);
  const session = new ArchiveUiSession('ai_memory_b_ask', storeFor(value, 'b'), false);
  await runPhase(session, value, 'b-ask', true, async () => {
    const accountId = await currentAccount(session);
    const before = await readAccount(session, accountId);
    const note = ownNote(before, expected.tag);
    if (!note) throw new Error('AI_MEMORY_SYNC_B_RESUME_NOTE_MISSING');
    assertNote(note, expected);
    expect(activeRecords(before.records, 'note').length).assertEqual(1);
    await openMemory(session, note);
    await click(session, 'memory-detail-scroll', 'memory-detail-ai');
    await session.waitId('detail-scroll');
    // 此入口已自动定位到 AI 面板；先真实回顶并露出完整画布，再核对上方保存视角，
    // 避免从面板中部向下查找尚未挂载的上方 caption 而滚到档案正文末尾。
    await frameCanvas(session);
    await inPage(session, 'detail-scroll', ON.id('engine-angle').text('已回到手账视角', MatchPattern.CONTAINS),
      'engine-angle:memory-ai-replay');
    expect(await (await inPage(session, 'detail-scroll', ON.id('ai-question-input'), 'ai-question-input')).getText()).assertEqual(note.aiAssist!.question);
    expect(await (await inPage(session, 'detail-scroll', ON.id('ai-observation-input'), 'ai-observation-input')).getText()).assertEqual(note.body.slice(0, 300));
    expect(await (await inPage(session, 'detail-scroll', ON.id('observation-selected-detail'), 'observation-selected-detail')).getText())
      .assertEqual('正在观察 · 腹部通口');
    await inPage(session, 'detail-scroll', ON.id('ai-send'), 'ai-send');
    const idleFrom = Date.now();
    for (let attempt = 0; attempt < 8; attempt++) {
      for (const id of ['ai-waiting', 'ai-answer', 'ai-error', 'ai-draft-adopt']) {
        expect(!await session.driver.findComponent(ON.id(id))).assertTrue();
      }
      expect(await (await session.waitId('ai-send')).isEnabled()).assertTrue();
      await session.driver.delayMs(250);
    }
    console.info(`AI_MEMORY_SYNC_B_NO_AUTO_REQUEST:${JSON.stringify({ from: idleFrom, to: Date.now() })}`);
    await capture(session, 'b-resume-before-send');
    console.info(`AI_MEMORY_SYNC_B_EXPLICIT_SEND:${Date.now()}`);
    await click(session, 'detail-scroll', 'ai-send');
    await waitForAi(session, 'ai-answer');
    const answer = await (await inPage(session, 'detail-scroll', ON.id('ai-answer'), 'ai-answer')).getText();
    expect(answer.length > 0).assertTrue();
    assertNoFangding(answer);
    await inPage(session, 'detail-scroll', ON.id('ai-action-opening'), 'ai-action-opening');
    await click(session, 'detail-scroll', 'ai-evidence-toggle');
    await assertEvidence(session, 'ai-evidence-', 'detail-scroll',
      [note.aiAssist!.facts.find(fact => fact.id === 'dahecun-opening')!]);
    await capture(session, 'b-active-answer-evidence');
    const after = await readAccount(session, accountId);
    expect(activeRecords(after.records, 'note').length).assertEqual(1);
    const finalNote = ownNote(after, expected.tag)!;
    expect(finalNote.id).assertEqual(note.id);
    expect(compareVersions(note, finalNote)).assertEqual(0);
    printNote('B_FINAL', finalNote);
    console.info('AI_MEMORY_SYNC_B_ASK_CONFIRMED:ORIGINAL_NOTE_UNCHANGED');
  });
}

async function cleanupScope(session: ArchiveUiSession, value: AiSyncFixture, side: string,
  fallbackAccountId: string): Promise<void> {
  const base = storeFor(value, side);
  const workspaceStore = new AccountWorkspaceStore(session.context, base);
  const restored = await workspaceStore.load();
  const accountId = restored?.workspace.accountId || fallbackAccountId;
  // 必须在 forget 前取原身份指针；先删指针再调用 dispose 会失去账号 KV/Preferences 的定位。
  // 这里只访问本 run 的 A/B scope，账号 ID 只来自原指针或真实认证，不枚举正式库。
  if (accountId) {
    if (canIUse('SystemCapability.DistributedDataManager.KVStore.DistributedKVStore')) {
      const channel = new DistributedArchiveChannel(session.context as common.UIAbilityContext);
      try {
        if (!await channel.open(accountId, base)) throw new Error('AI_MEMORY_SYNC_CLEANUP_KV_OPEN_FAILED');
        await channel.cleanupTestStore();
      } finally { await channel.close(); }
    }
    await preferences.deletePreferences(session.context, accountStoreName(accountId, base));
  }
  // forget 同时删除该 scope 的 ASSET；即使未完成登录也要清除可能中断写入的别名。
  await workspaceStore.forget();
  expect(await workspaceStore.load() === undefined).assertTrue();
  await preferences.deletePreferences(session.context, `${base}_identity_v1`);
  await preferences.deletePreferences(session.context, base);
  console.info(`AI_MEMORY_SYNC_CLEANUP:${side}:PREFERENCES_KV_ASSET`);
}

async function cleanupRun(): Promise<void> {
  const value = await fixture();
  // 新建单独的宿主窗口取得正式模块 Context；不启动 A/B 本身，
  // 避免 cleanup 因恢复原账号而再次发起同步。每台设备都执行此 case。
  const session = new ArchiveUiSession('ai_memory_cleanup', storeFor(value, 'cleanup'), false);
  let started = false;
  try {
    await session.start();
    started = true;
    await session.stop();
    // B 在登录前已创建空账号库；若登录中断，身份指针可能尚未写入。
    // 仅从同一个私有 fixture 的真实认证补取账号 ID，覆盖这段可定位的残留，
    // 不记录会话、不写 note。账号从未注册时允许没有回退身份，其他网络故障须报告。
    let fallbackAccountId = '';
    try { fallbackAccountId = await identifyForB(session, value); }
    catch (error) {
      if ((error as Error).message !== 'ACCOUNT_INVALID_CREDENTIALS') throw new Error((error as Error).message);
    }
    await cleanupScope(session, value, 'a', fallbackAccountId);
    await cleanupScope(session, value, 'b', fallbackAccountId);
  } catch (error) { throw new Error(redactedError(error as Error, value)); }
  finally {
    if (started) {
      await session.dispose();
      await preferences.deletePreferences(session.context, `${session.name}_identity_v1`);
    }
  }
}

export default function aiMemorySyncTest() {
  const params = abilityDelegatorRegistry.getArguments().parameters;
  const requested = params['class'] || params['-s class'] || '';
  // 真实模型与双设备阶段只按显式 class 调用，不混入默认离线 UI 套件。
  if (!requested.includes('AiMemorySyncTest')) return;
  describe('AiMemorySyncTest', () => {
    it('device_a_real_ai_save_dahecun_memory', 0, async () => { await publishOnA(); });
    it('device_b_receive_evidence_and_replay', 0, async () => { await receiveOnB(); });
    it('device_b_resume_and_ask_without_mutating_memory', 0, async () => { await askAgainOnB(); });
    it('cleanup_only_this_run_ai_test_stores', 0, async () => { await cleanupRun(); });
  });
}
