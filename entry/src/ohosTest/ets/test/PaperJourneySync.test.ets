import { abilityDelegatorRegistry, Component, ON, On } from '@kit.TestKit';
import { application, UIAbility } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { describe, expect, it } from '@ohos/hypium';
import { activeRecords, ArchiveRecord, ArchiveSnapshot, compareVersions, emptySnapshot, parseSnapshot,
  recordVersionConfirmed } from '../../../main/ets/domain/ArchiveDomain';
import { accountStoreName } from '../../../main/ets/domain/AccountSync';
import { PAPER_COLUMNS, PAPER_ROWS, PaperWorkV1, createPaperWork, judgePaper, paperCellIsCut } from '../../../main/ets/domain/PaperJourney';
import { paperWorkFromRecords, paperWorkRecordId } from '../../../main/ets/domain/PaperJourneyRecords';
import { PAPER_CITIES, PaperCity } from '../../../main/ets/data/PaperJourneyCatalog';
import { AccountWorkspaceStore } from '../../../main/ets/data/AccountWorkspaceStore';
import { LocalArchiveRepository } from '../../../main/ets/data/LocalArchiveRepository';
import { AccountSyncClient } from '../../../main/ets/sync/AccountSyncClient';
import { ArchiveUiSession } from './ArchiveUiSession';
import { TestContext } from './TestContext';

interface PaperSyncFixture { run: string; username: string; password: string; }
interface PaperSyncBaseline { accountId: string; snapshot: ArchiveSnapshot; note: ArchiveRecord; progress: ArchiveRecord; }
interface ScenePoint { x: number; y: number; }

const MEMORY_BODY: string = '我给纸灯留下三处不同方向的光，让另一台设备也能看到这张纸当时的样子。';

async function fixture(): Promise<PaperSyncFixture> {
  // 主机仅运行一次已有 tools/prepare-account-test.mjs，生成随机临时账号材料。
  // 两台测试包共用同一份被忽略的 rawfile；不修改主包资源、不在源码中保存凭据。
  const module = await application.createModuleContext(TestContext.context, 'entry_test');
  const value = JSON.parse(new util.TextDecoder().decodeToString(await module.resourceManager
    .getRawFileContent('account-sync-test.json'))) as PaperSyncFixture;
  if (!/^[a-z0-9_]{1,30}$/.test(value.run) || !/^[a-z0-9_]{4,32}$/.test(value.username) ||
    typeof value.password !== 'string' || value.password.length < 10 || value.password.length > 128) {
    throw new Error('PAPER_SYNC_FIXTURE_INVALID');
  }
  return value;
}

function storeFor(value: PaperSyncFixture, side: string): string {
  if (!['a', 'b', 'a_return'].includes(side)) throw new Error('PAPER_SYNC_SIDE_INVALID');
  return `yunheji_test_ui_${value.run}_papersync_${side === 'a_return' ? 'a' : side}`;
}

function city(): PaperCity {
  const value = PAPER_CITIES.find(item => item.id === 'paper-kf');
  if (!value) throw new Error('PAPER_SYNC_CITY_MISSING');
  return value;
}

class PaperSyncUiSession extends ArchiveUiSession {
  private paperAbility: UIAbility | undefined = undefined;

  constructor(scenario: string, storeName: string) { super(scenario, storeName); }

  async start(_resumeAccount: boolean = false): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator();
    await delegator.startAbility({ bundleName: 'com.yunheji.archive', abilityName: 'EntryAbility',
      parameters: { yunhejiTestStore: this.name } });
    await this.waitId('native-dock');
    await this.waitId('paper-journey-home');
    this.paperAbility = await delegator.getCurrentTopAbility();
    expect(this.paperAbility.context.abilityInfo.name).assertEqual('EntryAbility');
    this.context = this.paperAbility.context;
    // 与旧测试约定隔离，只换库名；正式启动仍使用同一个 EntryAbility 和真实登录页。
    const store = await preferences.getPreferences(this.context, { name: this.name });
    expect(await store.has('snapshot')).assertTrue();
    console.info(`PAPER_SYNC_TEST_STORE:${this.name}`);
  }

  async stop(): Promise<void> {
    if (!this.paperAbility) return;
    await this.paperAbility.context.terminateSelf();
    this.paperAbility = undefined;
    await this.wait(ON.text('设备回归准备中'));
  }
}

async function readAccount(session: PaperSyncUiSession, accountId: string): Promise<ArchiveSnapshot> {
  const name = accountStoreName(accountId, session.name);
  await preferences.removePreferencesFromCache(session.context, name);
  const snapshot = await new LocalArchiveRepository(session.context, name).load();
  const store = await preferences.getPreferences(session.context, { name });
  expect(JSON.stringify(parseSnapshot(await store.get('snapshot', '') as string))).assertEqual(JSON.stringify(snapshot));
  return snapshot;
}

async function exposed(session: PaperSyncUiSession, scrollId: string, target: On): Promise<Component> {
  if (scrollId === 'login-scroll' || scrollId === 'profile-scroll') return session.inScroll(scrollId, target);
  const scroll = await session.waitId(scrollId);
  for (let attempt = 0; attempt < 10; attempt++) {
    let component = await session.driver.findComponent(target);
    if (!component) component = await scroll.scrollSearch(target, true, 100);
    if (!component) {
      await scroll.scrollToTop(2000);
      component = await scroll.scrollSearch(target, true, 100);
    }
    if (!component) throw new Error(`PAPER_SYNC_TARGET_NOT_FOUND:${scrollId}`);
    component = await session.wait(target, scrollId);
    const viewport = await scroll.getBounds();
    let top = viewport.top + 25;
    let bottom = viewport.bottom - 30;
    if (['paper-journey-home', 'paper-memory', 'paper-profile'].includes(scrollId)) {
      const header = await (await session.waitId('top-navigation-content')).getBounds();
      const dock = await (await session.waitId('tab-0')).getBounds();
      top = Math.max(top, header.bottom + 18);
      bottom = Math.min(bottom, dock.top - 18);
    }
    const bounds = await component.getBounds();
    if (bounds.right <= bounds.left || bounds.bottom <= bounds.top) {
      await scroll.scrollToTop(2000); continue;
    }
    const center = (bounds.top + bounds.bottom) / 2;
    if (center >= top && center <= bottom) return component;
    const below = center > bottom;
    const distance = Math.min((bottom - top) * 0.4, Math.max(90, below ? center - bottom + 45 : top - center + 45));
    const start = below ? bottom - 35 : top + 35;
    await session.driver.swipe(Math.round(viewport.left + 10), Math.round(start),
      Math.round(viewport.left + 10), Math.round(start + (below ? -distance : distance)), 600);
  }
  throw new Error(`PAPER_SYNC_TARGET_NOT_EXPOSED:${scrollId}`);
}

async function openAccount(session: PaperSyncUiSession): Promise<void> {
  await (await session.waitId('tab-3')).click();
  await (await exposed(session, 'paper-profile', ON.id('profile-account'))).click();
  await session.waitId('profile-scroll');
}

async function signIn(session: PaperSyncUiSession, value: PaperSyncFixture, register: boolean): Promise<string> {
  await openAccount(session);
  await (await session.inScroll('profile-scroll', ON.id('profile-login'))).click();
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
    if (restored && !await session.driver.findComponent(ON.id('login-scroll'))) {
      // 认证回到触发的 account 页；后台可见首页不能当作已返回。
      for (let depth = 0; depth < 3; depth++) {
        if (!await session.driver.findComponent(ON.id('profile-scroll'))) break;
        await session.driver.pressBack();
        await session.driver.delayMs(200);
      }
      await (await session.waitId('tab-0')).click();
      await session.waitId('paper-journey-home');
      return restored.workspace.accountId;
    }
    const failure = await session.driver.findComponent(ON.id('account-message'));
    if (failure && (await failure.getText()).length > 0) throw new Error(`PAPER_SYNC_AUTH_FAILED:${await failure.getText()}`);
    await session.driver.delayMs(300);
  }
  throw new Error('PAPER_SYNC_AUTH_TIMEOUT');
}

async function signOut(session: PaperSyncUiSession): Promise<void> {
  await openAccount(session);
  await (await session.inScroll('profile-scroll', ON.id('account-logout'))).click();
  await session.waitId('paper-journey-home');
  expect(await new AccountWorkspaceStore(session.context, session.name).load() === undefined).assertTrue();
}

async function openCity(session: PaperSyncUiSession): Promise<void> {
  const home = await session.waitId('paper-journey-home');
  await home.scrollToTop(2000);
  await (await exposed(session, 'paper-journey-home', ON.id(`paper-home-city-${city().id}`))).click();
  await (await exposed(session, 'paper-journey-home', ON.id('paper-home-start'))).click();
  await session.waitId('paper-journey-page');
  expect(await (await session.waitId('paper-goal')).getText()).assertEqual(city().goal);
}

function ownNote(snapshot: ArchiveSnapshot): ArchiveRecord | undefined {
  const notes = activeRecords(snapshot.records, 'note').filter(note => note.paperContext?.cityId === city().id);
  if (notes.length > 1) throw new Error('PAPER_SYNC_DUPLICATE_NOTES');
  return notes[0];
}

function workFrom(snapshot: ArchiveSnapshot): PaperWorkV1 {
  const work = paperWorkFromRecords(snapshot.records, city().id);
  if (!work) throw new Error('PAPER_SYNC_WORK_MISSING');
  return work;
}

function progressFrom(snapshot: ArchiveSnapshot): ArchiveRecord {
  const record = snapshot.records.find(record => record.id === paperWorkRecordId(city().id) && !record.deleted);
  if (!record) throw new Error('PAPER_SYNC_PROGRESS_MISSING');
  return record;
}

function assertNote(note: ArchiveRecord): void {
  if (!note.paperContext) throw new Error('PAPER_SYNC_CONTEXT_MISSING');
  expect(note.body).assertEqual(MEMORY_BODY);
  expect(note.siteId).assertEqual(city().relatedSiteId);
  expect(note.paperContext.cityId).assertEqual(city().id);
  expect(note.paperContext.title).assertEqual(city().title);
  expect(note.paperContext.culture).assertEqual(city().culture);
  expect(JSON.stringify(note.paperContext.sources)).assertEqual(JSON.stringify(city().sources));
  expect(note.paperContext.work.mask.length).assertEqual(480);
  expect(note.paperContext.work.completedAt > 0).assertTrue();
  expect(judgePaper(note.paperContext.work).passed).assertTrue();
  expect(note.paperContext.work.history.length).assertEqual(0);
  expect(note.snapshot3DPose === undefined && note.aiAssist === undefined && note.roamingContext === undefined).assertTrue();
  expect(note.deleted).assertFalse();
}

async function waitForState(session: PaperSyncUiSession, accountId: string,
  matches: (snapshot: ArchiveSnapshot) => boolean, hint: string): Promise<ArchiveSnapshot> {
  for (let attempt = 0; attempt < 90; attempt++) {
    const snapshot = await readAccount(session, accountId);
    if (matches(snapshot)) return snapshot;
    await session.driver.delayMs(350);
  }
  throw new Error(`PAPER_SYNC_DISK_STATE_NOT_REACHED:${hint}`);
}

async function cutInScene(session: PaperSyncUiSession, fromCol: number, fromRow: number,
  toCol: number, toRow: number): Promise<void> {
  // 真实 UI 手势：取 Canvas 的 px 范围，再按同一1000×1200 contain纸面映射。
  // 不调用cutPaperStroke预填mask，不依赖手机固定分辨率，平板同样从实际画幅取点。
  const canvas = await session.wait(ON.id('paper-journey-scene').within(ON.id('paper-play-scene')));
  const bounds = await canvas.getBounds();
  const width = bounds.right - bounds.left;
  const height = bounds.bottom - bounds.top;
  expect(width > 0 && height > 0).assertTrue();
  const unit = Math.min(width / 1000, height / 1200);
  const offsetX = bounds.left + (width - 1000 * unit) / 2;
  const offsetY = bounds.top + (height - 1200 * unit) / 2;
  const start: ScenePoint = { x: offsetX + (110 + (fromCol + 0.5) / PAPER_COLUMNS * 780) * unit,
    y: offsetY + (105 + (fromRow + 0.5) / PAPER_ROWS * 936) * unit };
  const end: ScenePoint = { x: offsetX + (110 + (toCol + 0.5) / PAPER_COLUMNS * 780) * unit,
    y: offsetY + (105 + (toRow + 0.5) / PAPER_ROWS * 936) * unit };
  await session.driver.swipe(Math.round(start.x), Math.round(start.y), Math.round(end.x), Math.round(end.y), 350);
}

async function serverBaseline(session: PaperSyncUiSession, value: PaperSyncFixture): Promise<PaperSyncBaseline> {
  const client = new AccountSyncClient(session.context);
  if (!await client.configure()) throw new Error('PAPER_SYNC_SERVICE_NOT_CONFIGURED');
  try {
    const authenticated = await client.authenticate(value.username, value.password, false);
    const local = await readAccount(session, authenticated.accountId);
    // 只查询服务端已存在的记录；空records不会替UI上传作品或笔记。
    // 独立网络会话结束时注销，不复用/撤销正式UI当前的ASSET令牌。
    const reply = await client.exchange(emptySnapshot(local.deviceId));
    const snapshot = emptySnapshot(local.deviceId); snapshot.records = reply.records;
    const note = ownNote(snapshot);
    const progress = snapshot.records.find(record => record.id === paperWorkRecordId(city().id) && !record.deleted);
    if (!note || !progress) throw new Error('PAPER_SYNC_REMOTE_RECORDS_MISSING');
    assertNote(note);
    return { accountId: authenticated.accountId, snapshot, note, progress };
  } finally { await client.logout(); }
}

async function awaitServerConfirmation(session: PaperSyncUiSession, value: PaperSyncFixture,
  accountId: string, baseline: ArchiveSnapshot): Promise<void> {
  await openAccount(session);
  await (await session.inScroll('profile-scroll', ON.id('account-refresh'))).click();
  await session.wait(ON.id('account-sync-state').text('已同步'), '正式页面收到服务器版本确认');
  await session.driver.pressBack();
  await (await session.waitId('tab-0')).click();
  const remote = await serverBaseline(session, value);
  expect(remote.accountId).assertEqual(accountId);
  for (const record of baseline.records) expect(recordVersionConfirmed(record, remote.snapshot.records)).assertTrue();
}

async function openNote(session: PaperSyncUiSession, note: ArchiveRecord): Promise<void> {
  await (await session.waitId('tab-2')).click();
  await (await exposed(session, 'paper-memory', ON.id(`memory-open-${note.id}`))).click();
  await session.waitId('paper-memory-page');
  await session.waitId('paper-note-preview');
  expect(await (await exposed(session, 'paper-memory-page', ON.id('paper-note-body'))).getText()).assertEqual(note.body);
}

async function capture(session: PaperSyncUiSession, name: string): Promise<void> {
  for (const id of ['login-scroll', 'profile-scroll', 'account-panel']) {
    if (await session.driver.findComponent(ON.id(id))) throw new Error('PAPER_SYNC_PRIVATE_CAPTURE_DENIED');
  }
  const profile = await session.driver.findComponent(ON.id('paper-profile'));
  if (profile) {
    const bounds = await profile.getBounds();
    if (bounds.right > bounds.left && bounds.bottom > bounds.top) throw new Error('PAPER_SYNC_PROFILE_CAPTURE_DENIED');
  }
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  expect((await delegator.executeShellCommand(`uitest screenCap -p /data/local/tmp/paper-sync-${name}.png`)).exitCode).assertEqual(0);
  expect((await delegator.executeShellCommand(`uitest dumpLayout -p /data/local/tmp/paper-sync-${name}.json`)).exitCode).assertEqual(0);
}

function logRecord(phase: string, name: string, record: ArchiveRecord): void {
  // 嵌套mask/完成图/全部来源分片输出，主机可还原逐字比较；不输出账号、口令、会话或身份指针。
  const raw = JSON.stringify(record);
  const count = Math.ceil(raw.length / 220);
  for (let index = 0; index < count; index++) console.info(`PAPER_SYNC_RECORD:${phase}:${name}:${index + 1}/${count}:${raw.slice(index * 220, (index + 1) * 220)}`);
}

async function runPhase(session: PaperSyncUiSession, value: PaperSyncFixture, phase: string,
  resume: boolean, action: () => Promise<void>): Promise<void> {
  const started = Date.now();
  let launched = false;
  try {
    await session.start(resume); launched = true;
    const identity = await new AccountWorkspaceStore(session.context, session.name).load();
    if (!resume) {
      expect((await session.read()).records.length).assertEqual(0);
      expect(identity === undefined).assertTrue();
    } else expect(identity !== undefined).assertTrue();
    await action();
    console.info(`PAPER_SYNC_PHASE_DONE:${phase}:${Date.now() - started}`);
  } catch (error) {
    if (launched) {
      try { await capture(session, `${phase}-failure`); }
      catch { console.info(`PAPER_SYNC_FAILURE_CAPTURE_SKIPPED:${phase}`); }
    }
    const message = (error as Error).message.split(value.username).join('[账号已隐藏]')
      .split(value.password).join('[凭证已隐藏]');
    throw new Error(message);
  } finally {
    // 三阶段之间保留各自的测试库与账号身份；不清理正式档案或擅自注销用户账号。
    // A返程复用原A scope，不创建一个空A库再冒称同一台设备恢复。
    if (launched) await session.stop();
  }
}

export default function paperJourneySyncTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requested = parameters['class'] || parameters['-s class'] || '';
  if (!requested.includes('PaperJourneySyncTest')) return;
  describe('PaperJourneySyncTest', () => {
    it('device_a_register_cut_and_save_frozen_paper_memory', 0, async () => {
      const value = await fixture();
      const session = new PaperSyncUiSession('paper_sync_a', storeFor(value, 'a'));
      await runPhase(session, value, 'a-saved', false, async () => {
        const accountId = await signIn(session, value, true);
        expect((await readAccount(session, accountId)).records.length).assertEqual(0);
        await openCity(session);
        const blank = createPaperWork(city().id, 0).mask;
        for (const segment of [[8, 12, 12, 12], [27, 14, 31, 14], [17, 34, 22, 34]]) {
          const before = paperWorkFromRecords((await readAccount(session, accountId)).records, city().id)?.mask || blank;
          await cutInScene(session, segment[0], segment[1], segment[2], segment[3]);
          await waitForState(session, accountId, snapshot => {
            const work = paperWorkFromRecords(snapshot.records, city().id); return !!work && work.mask !== before;
          }, 'A逐笔真实UI剪口落盘');
        }
        await (await session.waitId('paper-light')).click();
        const made = await waitForState(session, accountId, snapshot => paperWorkFromRecords(snapshot.records, city().id)?.light === true,
          'A透光落盘');
        const work = workFrom(made);
        expect(judgePaper(work).passed).assertTrue();
        expect(work.completedMask).assertEqual(work.mask);
        await capture(session, 'a-three-windows');
        await (await session.waitId('paper-keep')).click();
        await (await session.waitId('paper-memory-body')).inputText(MEMORY_BODY);
        await session.driver.pressBack();
        await (await session.waitId('paper-memory-save')).click();
        const saved = await waitForState(session, accountId, snapshot => ownNote(snapshot) !== undefined, 'A真实UI保存纸景');
        const note = ownNote(saved);
        if (!note || !note.paperContext) throw new Error('PAPER_SYNC_A_NOTE_MISSING');
        assertNote(note);
        expect(note.paperContext.work.mask).assertEqual(work.mask);
        expect(note.paperContext.work.paper).assertEqual(work.paper);
        expect(note.paperContext.work.light).assertEqual(work.light);
        expect(activeRecords(saved.records, 'note').length).assertEqual(1);
        await (await session.waitId('paper-back')).click();
        await awaitServerConfirmation(session, value, accountId, saved);
        logRecord('a-saved', 'work', progressFrom(saved)); logRecord('a-saved', 'note', note);
        await openNote(session, note);
        await capture(session, 'a-frozen-note');
        expect(compareVersions(note, ownNote(await readAccount(session, accountId))!)).assertEqual(0);
      });
    });

    it('device_b_receive_exact_mask_note_sources_and_continue_by_ui', 0, async () => {
      const value = await fixture();
      const session = new PaperSyncUiSession('paper_sync_b', storeFor(value, 'b'));
      await runPhase(session, value, 'b-continued', false, async () => {
        const remote = await serverBaseline(session, value);
        expect((await readAccount(session, remote.accountId)).records.length).assertEqual(0);
        const accountId = await signIn(session, value, false);
        expect(accountId).assertEqual(remote.accountId);
        const received = await waitForState(session, accountId, snapshot => {
          const note = ownNote(snapshot);
          const work = paperWorkFromRecords(snapshot.records, city().id);
          return !!note && !!work && note.id === remote.note.id && work.mask === workFrom(remote.snapshot).mask;
        }, 'B经HTTPS收到A保存的作品和手账');
        const note = ownNote(received);
        if (!note || !note.paperContext) throw new Error('PAPER_SYNC_B_NOTE_MISSING');
        expect(JSON.stringify(note)).assertEqual(JSON.stringify(remote.note));
        expect(JSON.stringify(progressFrom(received))).assertEqual(JSON.stringify(remote.progress));
        expect(note.deviceId !== received.deviceId).assertTrue();
        expect(note.paperContext.work.mask).assertEqual(workFrom(received).mask);
        logRecord('b-received', 'work', progressFrom(received)); logRecord('b-received', 'note', note);
        await openNote(session, note); await capture(session, 'b-received-note');
        await (await exposed(session, 'paper-memory-page', ON.id('paper-note-continue'))).click();
        await session.waitId('paper-journey-page');
        const before = workFrom(received);
        await cutInScene(session, 27, 33, 31, 33);
        const continued = await waitForState(session, accountId, snapshot => {
          const work = paperWorkFromRecords(snapshot.records, city().id);
          return !!work && work.updatedAt > before.updatedAt && work.mask !== before.mask;
        }, 'B真实续剪落盘');
        const after = workFrom(continued);
        expect(paperCellIsCut(after, 29, 33)).assertTrue();
        expect(after.history.includes(before.mask)).assertTrue();
        expect(progressFrom(continued).deviceId).assertEqual(continued.deviceId);
        expect(JSON.stringify(ownNote(continued))).assertEqual(JSON.stringify(note));
        expect(JSON.stringify(ownNote(continued)?.paperContext?.sources)).assertEqual(JSON.stringify(city().sources));
        await capture(session, 'b-continued-paper');
        await (await session.waitId('paper-back')).click();
        // 返回note后再真实返回根页，不能让后方Dock节点冒充已离开详情。
        await session.waitId('paper-memory-page'); await session.driver.pressBack();
        await session.waitId('paper-memory');
        await awaitServerConfirmation(session, value, accountId, continued);
        logRecord('b-continued', 'work', progressFrom(continued)); logRecord('b-continued', 'note', note);
      });
    });

    it('device_a_receive_b_new_version_in_original_scope_and_keep_frozen_memory', 0, async () => {
      const value = await fixture();
      const session = new PaperSyncUiSession('paper_sync_a_return', storeFor(value, 'a_return'));
      await runPhase(session, value, 'a-return', true, async () => {
        // 冷启动可能已发自动同步。原A的更新前版本以A阶段日志/主机启动前只读证据为准；
        // 此处只证明同scope身份恢复与最终接收，不虚构“启动后读到的就是旧版本”。
        const restored = await new AccountWorkspaceStore(session.context, session.name).load();
        if (!restored) throw new Error('PAPER_SYNC_A_IDENTITY_NOT_RESTORED');
        const original = await readAccount(session, restored.workspace.accountId);
        const originalDevice = original.deviceId;
        const remote = await serverBaseline(session, value);
        expect(remote.accountId).assertEqual(restored.workspace.accountId);
        expect(paperCellIsCut(workFrom(remote.snapshot), 29, 33)).assertTrue();
        expect(workFrom(remote.snapshot).mask !== remote.note.paperContext?.work.mask).assertTrue();
        await signOut(session);
        const accountId = await signIn(session, value, false);
        const received = await waitForState(session, accountId, snapshot => {
          const work = paperWorkFromRecords(snapshot.records, city().id);
          return !!work && work.mask === workFrom(remote.snapshot).mask && ownNote(snapshot)?.id === remote.note.id;
        }, '原A收到B续剪版本');
        expect(received.deviceId).assertEqual(originalDevice);
        expect(JSON.stringify(progressFrom(received))).assertEqual(JSON.stringify(remote.progress));
        expect(progressFrom(received).deviceId !== originalDevice).assertTrue();
        const note = ownNote(received);
        if (!note) throw new Error('PAPER_SYNC_A_RETURN_NOTE_MISSING');
        expect(JSON.stringify(note)).assertEqual(JSON.stringify(remote.note));
        assertNote(note);
        expect(activeRecords(received.records, 'note').length).assertEqual(1);
        await openCity(session); await capture(session, 'a-return-paper');
        expect(workFrom(await readAccount(session, accountId)).mask).assertEqual(workFrom(remote.snapshot).mask);
        await (await session.waitId('paper-back')).click();
        await openNote(session, note); await capture(session, 'a-return-frozen-note');
        const unchanged = await readAccount(session, accountId);
        expect(JSON.stringify(ownNote(unchanged))).assertEqual(JSON.stringify(note));
        expect(JSON.stringify(unchanged.records)).assertEqual(JSON.stringify(received.records));
        logRecord('a-return', 'work', progressFrom(unchanged)); logRecord('a-return', 'note', note);
      });
    });
  });
}
