import { abilityDelegatorRegistry, ON } from '@kit.TestKit';
import { application } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { describe, expect, it } from '@ohos/hypium';
import { activeRecords, ArchiveRecord, ArchiveSnapshot, compareVersions } from '../../../main/ets/domain/ArchiveDomain';
import { accountStoreName } from '../../../main/ets/domain/AccountSync';
import { RoamChapter, roamProgress } from '../../../main/ets/domain/Roaming';
import { ROAM_CHAPTERS, ROAM_CONTENT_REVISION, ROAM_SOURCES } from '../../../main/ets/data/RoamingCatalog';
import { AccountWorkspaceStore } from '../../../main/ets/data/AccountWorkspaceStore';
import { LocalArchiveRepository } from '../../../main/ets/data/LocalArchiveRepository';
import { RoamingUiSession, visible, click, selectChapter, readingScroll } from './Roaming.test';
import { TestContext } from './TestContext';

interface RoamingLoginFixture { run: string; username: string; password: string; }
interface RoamingLoginCheckpoint { version: number; chapterId: string; clueId: string; }
interface RoamingLoginChoice { choiceId: string; }
interface GuestBaseline { snapshot: ArchiveSnapshot; raw: string; }

const COPY_BODY: string = '在洛阳的第一段漫游里，我沿河看两岸山水；登录后仍想把这段自己的理解带在身边。';

async function fixture(): Promise<RoamingLoginFixture> {
  // 依赖先完成 RoamingSyncTest 的 A/B/A 三阶段：该阶段建立本轮新账号及其开封三条进度。
  // 登录专项只读测试 feature 私有材料，不注册替代账号，也不重置服务端记录。
  const testModule = await application.createModuleContext(TestContext.context, 'entry_test');
  const value = JSON.parse(new util.TextDecoder().decodeToString(await testModule.resourceManager
    .getRawFileContent('roaming-sync-test.json'))) as RoamingLoginFixture;
  if (!/^[a-z0-9_]{1,30}$/.test(value.run) || !/^[a-z0-9_]{4,32}$/.test(value.username) ||
    typeof value.password !== 'string' || value.password.length < 10 || value.password.length > 128) {
    throw new Error('ROAMING_LOGIN_FIXTURE_INVALID');
  }
  return value;
}

function chapterFor(id: string): RoamChapter {
  const chapter = ROAM_CHAPTERS.find(item => item.id === id);
  if (!chapter) throw new Error(`ROAMING_LOGIN_CHAPTER_MISSING:${id}`);
  return chapter;
}

function redact(message: string, value: RoamingLoginFixture): string {
  return message.split(value.username).join('[账号已隐藏]').split(value.password).join('[凭据已隐藏]')
    .replace(/[a-f0-9]{32,64}/g, '[身份已隐藏]');
}

async function capture(session: RoamingUiSession, phase: string): Promise<void> {
  for (const id of ['login-scroll', 'account-username', 'account-password', 'profile-scroll', 'account-panel']) {
    if (await session.driver.findComponent(ON.id(id))) throw new Error('ROAMING_LOGIN_PRIVATE_CAPTURE_DENIED');
  }
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  expect((await delegator.executeShellCommand(
    `uitest screenCap -p /data/local/tmp/roaming-login-${phase}.png`)).exitCode).assertEqual(0);
  expect((await delegator.executeShellCommand(
    `uitest dumpLayout -p /data/local/tmp/roaming-login-${phase}.json`)).exitCode).assertEqual(0);
}

async function runLogin(session: RoamingUiSession, value: RoamingLoginFixture, phase: string,
  action: () => Promise<void>): Promise<void> {
  let started = false;
  let actionFailed = false;
  try {
    await session.start();
    started = true;
    expect((await session.read()).records.length).assertEqual(0);
    expect(await new AccountWorkspaceStore(session.context, session.name).load() === undefined).assertTrue();
    await action();
  } catch (error) {
    actionFailed = true;
    // 公共 session.run 会无条件保存失败界面。本套件可能停在凭据输入页，因此使用专用包装，
    // 仅在明确离开身份页后截图；失败信息也先脱敏，不向原始设备日志输出账号或凭据。
    if (started) {
      try { await capture(session, `${phase}-failure`); }
      catch { console.info(`ROAMING_LOGIN_FAILURE_CAPTURE_SKIPPED:${phase}`); }
    }
    throw new Error(redact((error as Error).message, value));
  } finally {
    if (started) {
      try { await session.dispose(); }
      catch (error) {
        const message = redact((error as Error).message, value);
        if (!actionFailed) throw new Error(message);
        console.error(`ROAMING_LOGIN_CLEANUP_AFTER_FAILURE:${message}`);
      }
    }
  }
}

async function sceneScroll(session: RoamingUiSession): Promise<string> {
  return await session.driver.findComponent(ON.id('roam-chapter-wide-scroll')) ?
    'roam-chapter-wide-scroll' : 'roam-chapter-scroll';
}

async function assertCurrentClue(session: RoamingUiSession, chapter: RoamChapter, index: number): Promise<void> {
  await session.waitId('roaming-chapter-page');
  await visible(session, await sceneScroll(session), ON.id('roam-current-goal').text(chapter.clues[index].goal));
}

function completedRecord(snapshot: ArchiveSnapshot, chapter: RoamChapter): ArchiveRecord {
  const record = snapshot.records.find(item => item.id === `progress:roam:v1:${chapter.id}:${chapter.clues[0].id}` && !item.deleted);
  if (!record) throw new Error('ROAMING_LOGIN_FIRST_PROGRESS_MISSING');
  return record;
}

function assertCheckpoint(snapshot: ArchiveSnapshot, chapter: RoamChapter, index: number): void {
  const record = snapshot.records.find(item => item.id === 'progress:roaming-position:v1' && !item.deleted);
  if (!record) throw new Error('ROAMING_LOGIN_CHECKPOINT_MISSING');
  const value = JSON.parse(record.body) as RoamingLoginCheckpoint;
  expect(value.version).assertEqual(1);
  expect(value.chapterId).assertEqual(chapter.id);
  expect(value.clueId).assertEqual(chapter.clues[index].id);
}

async function prepareFirstChoice(session: RoamingUiSession, chapter: RoamChapter, choiceIndex: number): Promise<void> {
  await selectChapter(session, chapter);
  await assertCurrentClue(session, chapter, 0);
  const scrollId = await sceneScroll(session);
  const incomplete = await visible(session, scrollId, ON.id('roam-complete'), false);
  expect(await incomplete.isEnabled()).assertFalse();
  const slider = await visible(session, scrollId, ON.id('roam-slider'));
  const bounds = await slider.getBounds();
  const inset = Math.min((bounds.bottom - bounds.top) * 0.32, (bounds.right - bounds.left) * 0.15);
  const left = bounds.left + inset;
  const right = bounds.right - inset;
  const y = Math.round((bounds.top + bounds.bottom) / 2);
  const percent = chapter.scene === 'kf-night' ? 65 : 85;
  // 开封必须经过桥下观察区，洛阳实际向右观察两岸；不预填 progress 或代调页面的 move/confirm。
  await session.driver.swipe(Math.round(left), y, Math.round(left + (right - left) * percent / 100), y, 600);
  await click(session, scrollId, `roam-choice-${chapter.clues[0].options[choiceIndex].id}`);
  expect(await (await visible(session, scrollId, ON.id('roam-feedback'))).getText())
    .assertEqual(chapter.clues[0].options[choiceIndex].detail);
}

async function finishFirstClue(session: RoamingUiSession, chapter: RoamChapter, choiceIndex: number): Promise<void> {
  await click(session, await sceneScroll(session), 'roam-complete');
  await assertCurrentClue(session, chapter, 1);
  const snapshot = await session.read();
  expect(roamProgress(snapshot.records, chapter).completedCount).assertEqual(1);
  expect((JSON.parse(completedRecord(snapshot, chapter).body) as RoamingLoginChoice).choiceId)
    .assertEqual(chapter.clues[0].options[choiceIndex].id);
  assertCheckpoint(snapshot, chapter, 1);
}

async function guestRaw(session: RoamingUiSession): Promise<string> {
  await preferences.removePreferencesFromCache(session.context, session.name);
  const store = await preferences.getPreferences(session.context, { name: session.name });
  expect(await store.has('snapshot')).assertTrue();
  const raw = await store.get('snapshot', '') as string;
  if (!raw) throw new Error('ROAMING_LOGIN_GUEST_SNAPSHOT_EMPTY');
  return raw;
}

async function baseline(session: RoamingUiSession): Promise<GuestBaseline> {
  return { snapshot: await session.read(), raw: await guestRaw(session) };
}

async function assertGuestUnchanged(session: RoamingUiSession, original: GuestBaseline): Promise<void> {
  // 对原始序列化文本逐字比较，检查登录/复制没有重新保存游客副本；不通过排序或重新序列化掩盖变化。
  if (await guestRaw(session) !== original.raw) throw new Error('ROAMING_LOGIN_GUEST_RAW_CHANGED');
  const current = await session.read();
  expect(JSON.stringify(current)).assertEqual(JSON.stringify(original.snapshot));
}

async function openBlankLogin(session: RoamingUiSession): Promise<void> {
  await click(session, await sceneScroll(session), 'roam-account-continue');
  await session.waitId('login-scroll');
  for (const id of ['account-username', 'account-password']) {
    const field = await session.inScroll('login-scroll', ON.id(id));
    if ((await field.getText()).length !== 0) throw new Error('ROAMING_LOGIN_FORM_NOT_BLANK');
  }
  expect(await (await session.inScroll('login-scroll', ON.id('login-title'))).getText()).assertEqual('登录云河纪');
}

async function loginWithDecision(session: RoamingUiSession, value: RoamingLoginFixture,
  chapter: RoamChapter, decision: string): Promise<string> {
  await (await session.inScroll('login-scroll', ON.id('account-mode-login'))).click();
  await (await session.inScroll('login-scroll', ON.id('account-username'))).inputText(value.username);
  await (await session.inScroll('login-scroll', ON.id('account-password'))).inputText(value.password);
  await session.driver.pressBack();
  await (await session.inScroll('login-scroll', ON.id('account-submit'))).click();
  let dialogShown = false;
  for (let attempt = 0; attempt < 100; attempt++) {
    if (await session.driver.findComponent(ON.text('把本机漫游带入这个账号？'))) { dialogShown = true; break; }
    const failure = await session.driver.findComponent(ON.id('account-message'));
    if (failure && (await failure.getText()).length > 0) throw new Error('ROAMING_LOGIN_AUTH_REJECTED');
    await session.driver.delayMs(300);
  }
  if (!dialogShown) throw new Error('ROAMING_LOGIN_COPY_DECISION_NOT_SHOWN');
  await (await session.waitText(decision)).click();
  for (let attempt = 0; attempt < 100; attempt++) {
    const current = await session.driver.findComponent(ON.id('roam-current-goal').text(chapter.clues[1].goal));
    if (current) {
      const bounds = await current.getBounds();
      if (bounds.right > bounds.left && bounds.bottom > bounds.top) {
        const restored = await new AccountWorkspaceStore(session.context, session.name).load();
        if (restored) {
          if (restored.workspace.username !== value.username) throw new Error('ROAMING_LOGIN_AUTH_IDENTITY_MISMATCH');
          await assertCurrentClue(session, chapter, 1);
          expect(!await session.driver.findComponent(ON.id('login-scroll'))).assertTrue();
          return restored.workspace.accountId;
        }
      }
    }
    await session.driver.delayMs(300);
  }
  throw new Error('ROAMING_LOGIN_CURRENT_CLUE_NOT_RESTORED');
}

async function readAccount(session: RoamingUiSession, accountId: string): Promise<ArchiveSnapshot> {
  const name = accountStoreName(accountId, session.name);
  if (name === session.name) throw new Error('ROAMING_LOGIN_STORE_NOT_ISOLATED');
  await preferences.removePreferencesFromCache(session.context, name);
  return new LocalArchiveRepository(session.context, name).load();
}

function assertCopyNote(note: ArchiveRecord, chapter: RoamChapter, tag: string): void {
  const clue = chapter.clues[0];
  const option = clue.options[0];
  const context = note.roamingContext;
  if (!context) throw new Error('ROAMING_LOGIN_COPY_CONTEXT_MISSING');
  expect(note.body).assertEqual(COPY_BODY);
  expect(JSON.stringify(note.tags)).assertEqual(JSON.stringify([tag]));
  expect(note.siteId).assertEqual(clue.id);
  expect(note.deleted).assertFalse();
  expect(note.snapshot3DPose === undefined && note.aiAssist === undefined).assertTrue();
  expect(context.version).assertEqual(1);
  expect(context.chapterId).assertEqual(chapter.id);
  expect(context.clueId).assertEqual(clue.id);
  expect(context.choiceId).assertEqual(option.id);
  expect(context.sceneRevision).assertEqual(1);
  expect(context.contentRevision).assertEqual(ROAM_CONTENT_REVISION);
  expect(context.excerpt).assertEqual(`${clue.body}\n\n我选择：${option.label}。${option.detail}`);
  expect(note.quotedPoemOrFact).assertEqual(context.excerpt);
  expect(context.sources.length).assertEqual(clue.sourceIds.length);
  for (let index = 0; index < clue.sourceIds.length; index++) {
    const source = ROAM_SOURCES.find(item => item.id === clue.sourceIds[index]);
    if (!source) throw new Error('ROAMING_LOGIN_COPY_SOURCE_MISSING');
    const frozen = context.sources[index];
    expect(frozen.id).assertEqual(source.id);
    expect(frozen.title).assertEqual(source.title);
    expect(frozen.url).assertEqual(source.url);
    expect(frozen.accessedAt).assertEqual(source.accessedAt);
  }
}

async function writeFirstMemory(session: RoamingUiSession, chapter: RoamChapter, tag: string): Promise<ArchiveRecord> {
  await click(session, await sceneScroll(session), 'roam-write-memory');
  const writing = await readingScroll(session, true);
  expect(await (await visible(session, writing, ON.id('roam-note-body'))).getText()).assertEqual('');
  await (await visible(session, writing, ON.id('roam-note-body'))).inputText(COPY_BODY);
  // 平板软键盘会挡住长摘录后的标签；先通过真实 Back 收起输入法，再在原列定位。
  // 与平板保存专项保持同一真实操作顺序，不修改窗口高度或直接调用保存方法。
  await session.driver.pressBack();
  await (await visible(session, writing, ON.id('roam-note-tags'))).inputText(tag);
  await session.driver.pressBack();
  await click(session, writing, 'roam-save-note');
  await visible(session, writing, ON.id('roam-open-memory'));
  const saved = await visible(session, writing, ON.id('roam-save-note'), false);
  expect(await saved.isEnabled()).assertFalse();
  const notes = activeRecords((await session.read()).records, 'note');
  expect(notes.length).assertEqual(1);
  assertCopyNote(notes[0], chapter, tag);
  const close = await session.driver.findComponent(ON.id('roam-sheet-close'));
  if (close) await (await session.waitId('roam-sheet-close')).click();
  return notes[0];
}

async function openCopiedMemory(session: RoamingUiSession, note: ArchiveRecord): Promise<void> {
  await session.driver.pressBack();
  await session.waitId('roaming-home');
  await (await session.waitId('tab-2')).click();
  await click(session, 'archive-scroll', `memory-open-${note.id}`);
  await session.waitId('roam-memory-scroll');
  expect(await (await visible(session, 'roam-memory-scroll', ON.id('roam-memory-body'))).getText()).assertEqual(COPY_BODY);
  const context = note.roamingContext;
  if (!context) throw new Error('ROAMING_LOGIN_COPIED_DETAIL_CONTEXT_MISSING');
  expect(await (await visible(session, 'roam-memory-scroll', ON.id('roam-memory-excerpt'))).getText()).assertEqual(context.excerpt);
  for (const source of context.sources) {
    await visible(session, 'roam-memory-scroll', ON.text(`${source.title}\n${source.url}`).within(ON.id('roam-memory-scroll')));
  }
  await capture(session, 'copy-account-memory-sources');
  await (await session.waitId('roam-memory-scroll')).scrollToTop(40000);
  await visible(session, 'roam-memory-scroll', ON.id('roam-memory-body').text(COPY_BODY));
  await capture(session, 'copy-account-memory');
}

export default function roamingLoginTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requested = parameters['class'] || parameters['-s class'] || '';
  if (!requested.includes('RoamingLoginTest')) return;
  describe('RoamingLoginTest', () => {
    it('current_clue_returns_after_offline_cancel_and_login_only_keeps_guest_isolated', 0, async () => {
      const value = await fixture();
      const session = new RoamingUiSession('roaming_login_only');
      await runLogin(session, value, 'only', async () => {
        const chapter = chapterFor('roam-kf-night');
        // A/B/A 账号首条选择第一个选项；游客明确选择第二个，便于辨认“仅登录”有没有意外复制。
        await prepareFirstChoice(session, chapter, 1);
        await finishFirstClue(session, chapter, 1);
        const original = await baseline(session);
        expect(activeRecords(original.snapshot.records, 'note').length).assertEqual(0);
        await capture(session, 'only-guest-second-clue');
        await openBlankLogin(session);
        await (await session.inScroll('login-scroll', ON.id('login-offline'))).click();
        await assertCurrentClue(session, chapter, 1);
        await assertGuestUnchanged(session, original);
        expect(await new AccountWorkspaceStore(session.context, session.name).load() === undefined).assertTrue();
        await capture(session, 'only-offline-return-second-clue');

        await openBlankLogin(session);
        const accountId = await loginWithDecision(session, value, chapter, '仅登录');
        const account = await readAccount(session, accountId);
        expect(account.deviceId !== original.snapshot.deviceId).assertTrue();
        expect(account.records.some(item => item.deviceId === original.snapshot.deviceId)).assertFalse();
        expect(roamProgress(account.records, chapter).completedCount).assertEqual(3);
        const remote = completedRecord(account, chapter);
        expect((JSON.parse(remote.body) as RoamingLoginChoice).choiceId).assertEqual(chapter.clues[0].options[0].id);
        expect(compareVersions(completedRecord(original.snapshot, chapter), remote) !== 0).assertTrue();
        // UI 返回第2条来自登录前路由；账号自己的第3条检查点不会因此被游客检查点覆盖。
        assertCheckpoint(account, chapter, 2);
        await assertGuestUnchanged(session, original);
        await assertCurrentClue(session, chapter, 1);
        await capture(session, 'only-account-return-second-clue');
        console.info('ROAMING_LOGIN_RESULT:only:currentClue=2,guestCompleted=1,accountCompleted=3,guestRawUnchanged=true,isolated=true');
      });
    });

    it('copy_roaming_keeps_guest_source_and_restores_second_clue_with_same_memory', 0, async () => {
      const value = await fixture();
      const session = new RoamingUiSession('roaming_login_copy');
      await runLogin(session, value, 'copy', async () => {
        const chapter = chapterFor('roam-ly-spring');
        const tag = `登录复制${value.run}`;
        await prepareFirstChoice(session, chapter, 0);
        const note = await writeFirstMemory(session, chapter, tag);
        await finishFirstClue(session, chapter, 0);
        const original = await baseline(session);
        assertCopyNote(note, chapter, tag);
        assertCheckpoint(original.snapshot, chapter, 1);
        await capture(session, 'copy-guest-second-clue');
        await openBlankLogin(session);
        const accountId = await loginWithDecision(session, value, chapter, '复制漫游');
        const account = await readAccount(session, accountId);
        expect(account.deviceId !== original.snapshot.deviceId).assertTrue();
        expect(roamProgress(account.records, chapter).completedCount).assertEqual(1);
        assertCheckpoint(account, chapter, 1);
        for (const guestRecord of original.snapshot.records) {
          const copied = account.records.find(item => item.id === guestRecord.id);
          if (!copied) throw new Error('ROAMING_LOGIN_COPIED_RECORD_MISSING');
          expect(compareVersions(guestRecord, copied)).assertEqual(0);
          expect(JSON.stringify(copied)).assertEqual(JSON.stringify(guestRecord));
        }
        const copiedNote = activeRecords(account.records, 'note').find(item => item.id === note.id);
        if (!copiedNote) throw new Error('ROAMING_LOGIN_COPIED_NOTE_MISSING');
        assertCopyNote(copiedNote, chapter, tag);
        expect(JSON.stringify(copiedNote.roamingContext)).assertEqual(JSON.stringify(note.roamingContext));
        expect(roamProgress(account.records, chapterFor('roam-kf-night')).completedCount).assertEqual(3);
        expect(activeRecords(account.records, 'note').some(item => item.roamingContext?.chapterId === 'roam-kf-night')).assertTrue();
        await assertGuestUnchanged(session, original);
        await assertCurrentClue(session, chapter, 1);
        await capture(session, 'copy-account-return-second-clue');
        await openCopiedMemory(session, copiedNote);
        await assertGuestUnchanged(session, original);
        const finalAccount = await readAccount(session, accountId);
        const finalNote = activeRecords(finalAccount.records, 'note').find(item => item.id === note.id);
        if (!finalNote) throw new Error('ROAMING_LOGIN_COPIED_NOTE_DISAPPEARED');
        expect(compareVersions(copiedNote, finalNote)).assertEqual(0);
        expect(JSON.stringify(finalNote.roamingContext)).assertEqual(JSON.stringify(note.roamingContext));
        console.info('ROAMING_LOGIN_RESULT:copy:currentClue=2,guestCompleted=1,accountCompleted=1,sameMemoryVersion=true,guestRawUnchanged=true');
      });
    });
  });
}
