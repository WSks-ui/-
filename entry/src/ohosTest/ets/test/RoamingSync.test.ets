import { abilityDelegatorRegistry, ON } from '@kit.TestKit';
import { application, common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { describe, expect, it } from '@ohos/hypium';
import { activeRecords, ArchiveRecord, ArchiveSnapshot, compareVersions } from '../../../main/ets/domain/ArchiveDomain';
import { accountStoreName } from '../../../main/ets/domain/AccountSync';
import { RoamChapter, roamProgress } from '../../../main/ets/domain/Roaming';
import { ROAM_CHAPTERS, ROAM_CONTENT_REVISION } from '../../../main/ets/data/RoamingCatalog';
import { LocalArchiveRepository } from '../../../main/ets/data/LocalArchiveRepository';
import { AccountWorkspaceStore } from '../../../main/ets/data/AccountWorkspaceStore';
import { RoamingUiSession, visible, click, selectChapter, readingScroll } from './Roaming.test';
import { TestContext } from './TestContext';

interface RoamingSyncFixture { run: string; username: string; password: string; }
interface RoamingCheckpoint { version: number; chapterId: string; clueId: string; }

const ORIGINAL_BODY: string = '我沿着水线找到州桥，想把街与河交会的这一刻留给下一次阅读。';
const EDITED_BODY: string = '另一端继续读开封：街河的交会仍在，时间的层次和点亮的灯又添了新的理解。';

async function fixture(): Promise<RoamingSyncFixture> {
  // 只从测试 feature 的私有 rawfile 读取本轮新账号材料，不进入主包，不输出凭证。
  const testModule = await application.createModuleContext(TestContext.context, 'entry_test');
  const value = JSON.parse(new util.TextDecoder().decodeToString(await testModule.resourceManager
    .getRawFileContent('roaming-sync-test.json'))) as RoamingSyncFixture;
  if (!/^[a-z0-9_]{1,30}$/.test(value.run) || !/^[a-z0-9_]{4,32}$/.test(value.username) ||
    typeof value.password !== 'string' || value.password.length < 10 || value.password.length > 128) {
    throw new Error('ROAMING_SYNC_FIXTURE_INVALID');
  }
  return value;
}

function storeFor(value: RoamingSyncFixture, side: string): string {
  if (!['a', 'b', 'b_retry1', 'a_return'].includes(side)) throw new Error('ROAMING_SYNC_SIDE_INVALID');
  return `yunheji_test_ui_${value.run}_roamsync_${side === 'a_return' ? 'a' : side}`;
}

function chapter(): RoamChapter {
  const item = ROAM_CHAPTERS.find(value => value.id === 'roam-kf-night');
  if (!item) throw new Error('ROAMING_SYNC_CHAPTER_MISSING');
  return item;
}

function tagFor(value: RoamingSyncFixture): string { return `漫游跨端${value.run}`; }

async function capture(session: RoamingUiSession, phase: string): Promise<void> {
  for (const privateId of ['login-scroll', 'profile-scroll', 'account-panel']) {
    if (await session.driver.findComponent(ON.id(privateId))) throw new Error('ROAMING_SYNC_PRIVATE_CAPTURE_DENIED');
  }
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  expect((await delegator.executeShellCommand(
    `uitest screenCap -p /data/local/tmp/roaming-sync-${phase}.png`)).exitCode).assertEqual(0);
  expect((await delegator.executeShellCommand(
    `uitest dumpLayout -p /data/local/tmp/roaming-sync-${phase}.json`)).exitCode).assertEqual(0);
}

async function runPhase(session: RoamingUiSession, value: RoamingSyncFixture, phase: string,
  action: () => Promise<void>, resume: boolean = false): Promise<void> {
  const started = Date.now();
  let startedSession = false;
  try {
    // A 更新前基线由主机在启动 EntryAbility 前，只读复制精确的原 A Preferences 并断言
    // 原正文、同一 note ID、1 条线索与第 2 条位置，原件哈希和 JSON 另存证据清单。
    // application.createModuleContext 适合测试资源读取，实测并未切换测试 feature 的数据目录；
    // 不能把它读不到身份指针误报为原 A 数据丢失，也不能先启动自动同步再伪称取到了旧基线。
    await session.start();
    startedSession = true;
    // A/B首次进入独立空库；返程复用原A库。三阶段均没有预填note或progress。
    if (!resume) {
      expect((await session.read()).records.length).assertEqual(0);
      expect(await new AccountWorkspaceStore(session.context, session.name).load() === undefined).assertTrue();
    } else {
      // 此处已取得真实 EntryAbility Context，只证明恢复原身份；更新前版本由上述主机只读证据证明。
      if (!await new AccountWorkspaceStore(session.context, session.name).load()) {
        throw new Error('ROAMING_SYNC_A_RESTORED_WORKSPACE_MISSING');
      }
    }
    await action();
    console.info(`ROAMING_SYNC_PHASE_DONE:${phase}:${Date.now() - started}`);
  } catch (error) {
    if (startedSession) {
      try { await capture(session, `${phase}-failure`); }
      catch { console.info(`ROAMING_SYNC_FAILURE_CAPTURE_SKIPPED:${phase}`); }
    }
    const message = (error as Error).message.split(value.username).join('[账号已隐藏]')
      .split(value.password).join('[凭证已隐藏]');
    throw new Error(message);
  } finally {
    // 留存独立磁盘库供主任务核对；不清空正式账号，不在日志中输出身份指针或ASSET。
    if (startedSession) await session.stop();
  }
}

async function signIn(session: RoamingUiSession, value: RoamingSyncFixture, register: boolean): Promise<string> {
  await (await session.waitId('profile-entry')).click();
  await (await session.inScroll('profile-scroll', ON.id('profile-login'))).click();
  await session.waitId('login-scroll');
  await (await session.inScroll('login-scroll', ON.id(register ? 'account-mode-register' : 'account-mode-login'))).click();
  for (const id of ['account-username', 'account-password']) {
    const field = await session.inScroll('login-scroll', ON.id(id));
    if ((await field.getText()).length > 0) await field.clearText();
    await (await session.inScroll('login-scroll', ON.id(id))).inputText(id === 'account-username' ? value.username : value.password);
  }
  await session.driver.pressBack();
  await (await session.inScroll('login-scroll', ON.id('account-submit'))).click();
  for (let attempt = 0; attempt < 100; attempt++) {
    const restored = await new AccountWorkspaceStore(session.context, session.name).load();
    // 新版按需登录会回到触发的个人页。先核对真实身份指针，再通过系统返回回到首页，
    // 不再把“认证必定落到首页”当成产品约定；平板后方可见的首页也不能冒充返回完成。
    if (restored && !await session.driver.findComponent(ON.id('login-scroll'))) {
      for (let depth = 0; depth < 3; depth++) {
        if (!await session.driver.findComponent(ON.id('profile-scroll'))) break;
        await session.driver.pressBack();
        await session.driver.delayMs(300);
      }
      await session.waitId('roaming-home');
      return restored.workspace.accountId;
    }
    const home = await session.driver.findComponent(ON.id('roaming-home'));
    if (home) {
      const bounds = await home.getBounds();
      if (bounds.right > bounds.left && bounds.bottom > bounds.top) {
        if (restored) return restored.workspace.accountId;
      }
    }
    const failure = await session.driver.findComponent(ON.id('account-message'));
    if (failure && (await failure.getText()).length > 0) {
      // A必须注册本轮新账号；账号已存在也不能改成读取旧数据继续跑。
      throw new Error(`ROAMING_SYNC_AUTH_FAILED:${await failure.getText()}`);
    }
    await session.driver.delayMs(300);
  }
  throw new Error('ROAMING_SYNC_AUTH_TIMEOUT');
}

async function readAccount(session: RoamingUiSession, accountId: string): Promise<ArchiveSnapshot> {
  return readAccountAt(session.context, session.name, accountId);
}

async function readAccountAt(context: common.Context, scope: string, accountId: string): Promise<ArchiveSnapshot> {
  const name = accountStoreName(accountId, scope);
  await preferences.removePreferencesFromCache(context, name);
  return new LocalArchiveRepository(context, name).load();
}

function ownNote(snapshot: ArchiveSnapshot, tag: string): ArchiveRecord | undefined {
  const notes = activeRecords(snapshot.records, 'note').filter(record => record.tags.includes(tag));
  if (notes.length > 1) throw new Error('ROAMING_SYNC_DUPLICATE_NOTES');
  return notes[0];
}

async function waitForState(session: RoamingUiSession, accountId: string, tag: string,
  body: string, completedCount: number): Promise<ArchiveSnapshot> {
  for (let attempt = 0; attempt < 90; attempt++) {
    const snapshot = await readAccount(session, accountId);
    if (ownNote(snapshot, tag)?.body === body && roamProgress(snapshot.records, chapter()).completedCount === completedCount) return snapshot;
    await session.driver.delayMs(500);
  }
  throw new Error(`ROAMING_SYNC_STATE_NOT_RECEIVED:${completedCount}`);
}

function assertMemory(note: ArchiveRecord, body: string): void {
  const target = chapter();
  const context = note.roamingContext;
  if (!context) throw new Error('ROAMING_SYNC_CONTEXT_MISSING');
  expect(note.body).assertEqual(body);
  expect(note.siteId).assertEqual(target.clues[0].id);
  expect(context.chapterId).assertEqual(target.id);
  expect(context.clueId).assertEqual(target.clues[0].id);
  expect(context.choiceId).assertEqual(target.clues[0].options[0].id);
  expect(context.sceneRevision).assertEqual(1);
  expect(context.contentRevision).assertEqual(ROAM_CONTENT_REVISION);
  expect(context.excerpt.includes(target.clues[0].body)).assertTrue();
  expect(context.sources.length).assertEqual(target.clues[0].sourceIds.length);
  expect(note.quotedPoemOrFact).assertEqual(context.excerpt);
  expect(note.aiAssist === undefined && note.snapshot3DPose === undefined).assertTrue();
  expect(note.deleted).assertFalse();
}

function checkpoint(snapshot: ArchiveSnapshot): ArchiveRecord {
  const record = snapshot.records.find(item => item.id === 'progress:roaming-position:v1' && !item.deleted);
  if (!record) throw new Error('ROAMING_SYNC_CHECKPOINT_MISSING');
  const value = JSON.parse(record.body) as RoamingCheckpoint;
  expect(value.version).assertEqual(1);
  expect(value.chapterId).assertEqual(chapter().id);
  expect(chapter().clues.some(item => item.id === value.clueId)).assertTrue();
  return record;
}

function logJson(phase: string, name: string, raw: string): void {
  // HiLog单条输出可能被截断；定长分片保留全部嵌套字段，由主任务按序还原比较。
  // 这里只序列化测试内容，绝不包含账号、密码、token或身份指针。
  const count = Math.ceil(raw.length / 200);
  for (let index = 0; index < count; index++) {
    console.info(`ROAMING_SYNC_JSON:${phase}:${name}:${index + 1}/${count}:${raw.slice(index * 200, (index + 1) * 200)}`);
  }
}

function logRecords(phase: string, snapshot: ArchiveSnapshot, note: ArchiveRecord): void {
  const progress = snapshot.records.filter(item => item.id.startsWith(`progress:roam:v1:${chapter().id}:`));
  logJson(phase, 'note', JSON.stringify(note));
  logJson(phase, 'context', JSON.stringify(note.roamingContext));
  logJson(phase, 'progress', JSON.stringify(progress));
  logJson(phase, 'checkpoint', JSON.stringify(checkpoint(snapshot)));
  console.info(`ROAMING_SYNC_STATE:${phase}:${JSON.stringify({ noteId: note.id,
    completedCount: roamProgress(snapshot.records, chapter()).completedCount, recordCount: snapshot.records.length })}`);
}

async function sceneScroll(session: RoamingUiSession): Promise<string> {
  // 点击城市入口后先等待目的页稳定；转场中尚无宽栏时，不能立刻误判成手机 Scroll。
  await session.waitId('roaming-chapter-page');
  return await session.driver.findComponent(ON.id('roam-chapter-wide-scroll')) ? 'roam-chapter-wide-scroll' : 'roam-chapter-scroll';
}

async function sceneVisible(session: RoamingUiSession, target: string, requireEnabled: boolean = true): Promise<void> {
  await visible(session, await sceneScroll(session), ON.id(target), requireEnabled);
}

async function sceneClick(session: RoamingUiSession, id: string): Promise<void> {
  await click(session, await sceneScroll(session), id);
}

async function sceneSlider(session: RoamingUiSession, percent: number): Promise<void> {
  const slider = await visible(session, await sceneScroll(session), ON.id('roam-slider'));
  const bounds = await slider.getBounds();
  const inset = Math.min((bounds.bottom - bounds.top) * 0.32, (bounds.right - bounds.left) * 0.15);
  const left = bounds.left + inset;
  const right = bounds.right - inset;
  const y = Math.round((bounds.top + bounds.bottom) / 2);
  await session.driver.swipe(Math.round(left), y, Math.round(left + (right - left) * percent / 100), y, 600);
}

async function completeStep(session: RoamingUiSession, accountId: string, index: number): Promise<void> {
  const target = chapter();
  const clue = target.clues[index];
  await visible(session, await sceneScroll(session), ON.id('roam-current-goal').text(clue.goal));
  const inactive = await visible(session, await sceneScroll(session), ON.id('roam-complete'), false);
  expect(await inactive.isEnabled()).assertFalse();
  if (index < 2) await sceneSlider(session, index === 0 ? 65 : 85);
  await sceneClick(session, `roam-choice-${clue.options[0].id}`);
  if (index === 2) await sceneClick(session, 'roam-light-lantern');
  await sceneClick(session, 'roam-complete');
  if (index < 2) await visible(session, await sceneScroll(session), ON.id('roam-current-goal').text(target.clues[index + 1].goal));
  else await sceneVisible(session, 'roam-chapter-closing');
  expect(roamProgress((await readAccount(session, accountId)).records, target).completedCount).assertEqual(index + 1);
}

async function awaitServerConfirmation(session: RoamingUiSession): Promise<void> {
  // 调用方先回根页；只用正式账号卡的刷新与确认状态，不用测试client发同步请求。
  await (await session.waitId('profile-entry')).click();
  await (await session.inScroll('profile-scroll', ON.id('profile-account'))).click();
  await (await session.inScroll('profile-scroll', ON.id('account-refresh'))).click();
  await session.inScroll('profile-scroll', ON.id('account-sync-state'));
  await session.wait(ON.id('account-sync-state').text('已同步'), '服务器实际版本确认');
  await session.driver.pressBack();
  await session.driver.pressBack();
  await session.waitId('native-dock');
}

async function signOutForRealLogin(session: RoamingUiSession): Promise<void> {
  await (await session.waitId('profile-entry')).click();
  await (await session.inScroll('profile-scroll', ON.id('profile-account'))).click();
  await (await session.inScroll('profile-scroll', ON.id('account-logout'))).click();
  await session.waitId('roaming-home');
  expect(await new AccountWorkspaceStore(session.context, session.name).load() === undefined).assertTrue();
}

async function openMemoryFromRoot(session: RoamingUiSession, note: ArchiveRecord): Promise<void> {
  await (await session.waitId('tab-2')).click();
  await (await session.inScroll('archive-scroll', ON.id(`memory-open-${note.id}`))).click();
  await session.waitId('roam-memory-scroll');
  expect(await (await visible(session, 'roam-memory-scroll', ON.id('roam-memory-body'))).getText()).assertEqual(note.body);
  expect(await (await visible(session, 'roam-memory-scroll', ON.id('roam-memory-excerpt'))).getText())
    .assertEqual(note.roamingContext?.excerpt || '');
}

export default function roamingSyncTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requested = parameters['class'] || parameters['-s class'] || '';
  if (!requested.includes('RoamingSyncTest')) return;
  describe('RoamingSyncTest', () => {
    it('device_a_register_save_memory_and_first_clue', 0, async () => {
      const value = await fixture();
      const session = new RoamingUiSession('roaming_sync_a', storeFor(value, 'a'));
      await runPhase(session, value, 'a-publish', async () => {
        const accountId = await signIn(session, value, true);
        expect((await readAccount(session, accountId)).records.length).assertEqual(0);
        await selectChapter(session, chapter());
        await completeStep(session, accountId, 0);
        expect(activeRecords((await readAccount(session, accountId)).records, 'note').length).assertEqual(0);
        // 第1条确认后已进入第2条；显式回到已完成的第一条，为它保存一页真正的亲笔记忆。
        await sceneClick(session, `roam-step-${chapter().clues[0].id}`);
        await sceneClick(session, 'roam-write-memory');
        const draftScroll = await readingScroll(session, true);
        expect(await (await visible(session, draftScroll, ON.id('roam-note-body'))).getText()).assertEqual('');
        await (await visible(session, draftScroll, ON.id('roam-note-body'))).inputText(ORIGINAL_BODY);
        await (await visible(session, draftScroll, ON.id('roam-note-tags'))).inputText(`${tagFor(value)}，开封`);
        await click(session, draftScroll, 'roam-save-note');
        await visible(session, draftScroll, ON.id('roam-open-memory'));
        const saved = await waitForState(session, accountId, tagFor(value), ORIGINAL_BODY, 1);
        const note = ownNote(saved, tagFor(value));
        if (!note) throw new Error('ROAMING_SYNC_A_NOTE_MISSING');
        assertMemory(note, ORIGINAL_BODY);
        await capture(session, 'a-saved');
        // 写笺返回首条会真实更新检查点；离开前明确回到第2条，另一端应从这里继续。
        const close = await session.driver.findComponent(ON.id('roam-sheet-close'));
        if (close) await close.click();
        await sceneClick(session, `roam-step-${chapter().clues[1].id}`);
        await visible(session, await sceneScroll(session), ON.id('roam-current-goal').text(chapter().clues[1].goal));
        await session.driver.pressBack();
        await session.waitId('roaming-home');
        await awaitServerConfirmation(session);
        const confirmed = await readAccount(session, accountId);
        const stored = ownNote(confirmed, tagFor(value));
        if (!stored) throw new Error('ROAMING_SYNC_A_CONFIRMED_NOTE_MISSING');
        expect(compareVersions(note, stored)).assertEqual(0);
        expect((JSON.parse(checkpoint(confirmed).body) as RoamingCheckpoint).clueId).assertEqual(chapter().clues[1].id);
        logRecords('a-publish', confirmed, stored);
        await capture(session, 'a-confirmed');
      });
    });

    it('device_b_receive_continue_and_edit_same_memory', 0, async () => {
      const value = await fixture();
      // B 首次在收到原记录后、进入宽屏章节的等待器处停止，尚未修改正文或完成新线索。
      // 原 b 库和失败报告保留；本次明确使用新的空 b_retry1 库重新登录同账号，不注入数据。
      const session = new RoamingUiSession('roaming_sync_b_retry1', storeFor(value, 'b_retry1'));
      await runPhase(session, value, 'b-continue', async () => {
        const accountId = await signIn(session, value, false);
        const received = await waitForState(session, accountId, tagFor(value), ORIGINAL_BODY, 1);
        const note = ownNote(received, tagFor(value));
        if (!note) throw new Error('ROAMING_SYNC_B_RECEIVED_NOTE_MISSING');
        assertMemory(note, ORIGINAL_BODY);
        expect((JSON.parse(checkpoint(received).body) as RoamingCheckpoint).clueId).assertEqual(chapter().clues[1].id);
        logRecords('b-received', received, note);
        await selectChapter(session, chapter());
        await visible(session, await sceneScroll(session), ON.id('roam-current-goal').text(chapter().clues[1].goal));
        await capture(session, 'b-resume-second-clue');
        await completeStep(session, accountId, 1);
        await completeStep(session, accountId, 2);
        await session.driver.pressBack();
        await session.waitId('roaming-home');
        await openMemoryFromRoot(session, note);
        await capture(session, 'b-original-fulltext');
        await click(session, 'roam-memory-scroll', 'roam-memory-edit');
        await (await visible(session, 'roam-memory-scroll', ON.id('roam-edit-body'))).inputText(EDITED_BODY);
        await session.driver.pressBack();
        await (await visible(session, 'roam-memory-scroll', ON.id('roam-edit-tags'))).inputText(`${tagFor(value)}，开封，续读`);
        await session.driver.pressBack();
        await click(session, 'roam-memory-scroll', 'roam-edit-save');
        await visible(session, 'roam-memory-scroll', ON.id('roam-memory-body').text(EDITED_BODY));
        const editedState = await waitForState(session, accountId, tagFor(value), EDITED_BODY, 3);
        const edited = ownNote(editedState, tagFor(value));
        if (!edited) throw new Error('ROAMING_SYNC_B_EDITED_NOTE_MISSING');
        assertMemory(edited, EDITED_BODY);
        expect(edited.id).assertEqual(note.id);
        expect(edited.updatedAt > note.updatedAt).assertTrue();
        expect(edited.deviceId).assertEqual(editedState.deviceId);
        expect(edited.deviceId !== note.deviceId).assertTrue();
        expect(JSON.stringify(edited.roamingContext)).assertEqual(JSON.stringify(note.roamingContext));
        expect(edited.quotedPoemOrFact).assertEqual(note.quotedPoemOrFact);
        expect(edited.paperTheme).assertEqual(note.paperTheme);
        expect(edited.stampType).assertEqual(note.stampType);
        for (const original of received.records.filter(item => item.id.startsWith('progress:roam:v1:'))) {
          const retained = editedState.records.find(item => item.id === original.id);
          if (!retained) throw new Error('ROAMING_SYNC_B_FIRST_PROGRESS_REMOVED');
          expect(compareVersions(original, retained)).assertEqual(0);
        }
        await capture(session, 'b-edited-fulltext');
        await session.driver.pressBack();
        await session.waitId('archive-scroll');
        await awaitServerConfirmation(session);
        const confirmed = await readAccount(session, accountId);
        const stored = ownNote(confirmed, tagFor(value));
        if (!stored) throw new Error('ROAMING_SYNC_B_CONFIRMED_NOTE_MISSING');
        expect(compareVersions(edited, stored)).assertEqual(0);
        expect((JSON.parse(checkpoint(confirmed).body) as RoamingCheckpoint).clueId).assertEqual(chapter().clues[2].id);
        logRecords('b-edited', confirmed, stored);
        await capture(session, 'b-confirmed');
      });
    });

    it('device_a_receive_new_version_with_all_progress_and_frozen_context', 0, async () => {
      const value = await fixture();
      const session = new RoamingUiSession('roaming_sync_a_return', storeFor(value, 'a_return'));
      await runPhase(session, value, 'a-return', async () => {
        // 本次启动可能已触发真实自动同步；旧A版本已在启动前记录。仍经退出/登录UI重新认证。
        await signOutForRealLogin(session);
        const accountId = await signIn(session, value, false);
        const received = await waitForState(session, accountId, tagFor(value), EDITED_BODY, 3);
        const note = ownNote(received, tagFor(value));
        if (!note) throw new Error('ROAMING_SYNC_A_RETURN_NOTE_MISSING');
        assertMemory(note, EDITED_BODY);
        expect(activeRecords(received.records, 'note').length).assertEqual(1);
        expect((JSON.parse(checkpoint(received).body) as RoamingCheckpoint).clueId).assertEqual(chapter().clues[2].id);
        logRecords('a-return-received', received, note);
        await openMemoryFromRoot(session, note);
        await capture(session, 'a-return-fulltext');
        await session.driver.pressBack();
        await session.waitId('archive-scroll');
        const afterReading = await readAccount(session, accountId);
        const unchanged = ownNote(afterReading, tagFor(value));
        if (!unchanged) throw new Error('ROAMING_SYNC_A_RETURN_RECORD_MISSING');
        expect(compareVersions(note, unchanged)).assertEqual(0);
        expect(JSON.stringify(afterReading.records)).assertEqual(JSON.stringify(received.records));
        await (await session.waitId('tab-0')).click();
        await click(session, 'roaming-home', `roam-pick-${chapter().id}`);
        expect(await (await visible(session, 'roaming-home', ON.id('roam-home-progress'))).getText()).assertEqual('3 / 3 线索');
        const finalSnapshot = await readAccount(session, accountId);
        expect(roamProgress(finalSnapshot.records, chapter()).completed).assertTrue();
        expect(JSON.stringify(finalSnapshot.records)).assertEqual(JSON.stringify(received.records));
        await capture(session, 'a-return-completed-chapter');
      }, true);
    });
  });
}
