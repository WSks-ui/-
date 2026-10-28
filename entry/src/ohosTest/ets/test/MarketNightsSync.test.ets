import { abilityDelegatorRegistry, Component, ON, On } from '@kit.TestKit';
import { application, UIAbility } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { describe, expect, it } from '@ohos/hypium';
import { activeRecords, ArchiveRecord, ArchiveSnapshot, compareVersions, emptySnapshot, parseSnapshot,
  recordVersionConfirmed } from '../../../main/ets/domain/ArchiveDomain';
import { accountStoreName } from '../../../main/ets/domain/AccountSync';
import { RiverMarketV2 } from '../../../main/ets/domain/RiverMarketV2';
import { marketNightFromRecords, marketNightRecordId } from '../../../main/ets/domain/RiverMarketV2Records';
import { marketCultureForNight } from '../../../main/ets/data/MarketCultureCatalog';
import { AccountWorkspaceStore } from '../../../main/ets/data/AccountWorkspaceStore';
import { LocalArchiveRepository } from '../../../main/ets/data/LocalArchiveRepository';
import { AccountSyncClient } from '../../../main/ets/sync/AccountSyncClient';
import { ArchiveUiSession } from './ArchiveUiSession';
import { TestContext } from './TestContext';

interface NightsSyncFixture { run: string; username: string; password: string; }
interface NightsSyncBaseline { accountId: string; snapshot: ArchiveSnapshot; note: ArchiveRecord; progress: ArchiveRecord; tombstone?: ArchiveRecord; }
const MEMORY_BODY: string = '首批客人到来后，我想先记下中街的饭香，再把下一批真正需要的货送到铺前。';
const REVISED_BODY: string = MEMORY_BODY + '另一台设备接着迎客，但这一页仍保留首批暂停时的图景。';
const PLAIN_BODY: string = '我单独抄记一段州桥资料，稍后删除这一页，用来确认删除也能随账号到另一台设备。';

async function fixture(): Promise<NightsSyncFixture> {
  const module = await application.createModuleContext(TestContext.context, 'entry_test');
  const value = JSON.parse(new util.TextDecoder().decodeToString(await module.resourceManager
    .getRawFileContent('account-sync-test.json'))) as NightsSyncFixture;
  if (!/^[a-z0-9_]{1,30}$/.test(value.run) || !/^[a-z0-9_]{4,32}$/.test(value.username) ||
    typeof value.password !== 'string' || value.password.length < 10 || value.password.length > 128) throw new Error('NIGHTS_SYNC_FIXTURE_INVALID');
  return value;
}
function storeFor(value: NightsSyncFixture, side: string): string {
  if (!['a', 'b', 'a_return'].includes(side)) throw new Error('NIGHTS_SYNC_SIDE_INVALID');
  return `yunheji_test_ui_${value.run}_nightsync_${side === 'a_return' ? 'a' : side}`;
}

class NightsSyncUiSession extends ArchiveUiSession {
  private nightsAbility: UIAbility | undefined = undefined;
  async start(_resume: boolean = false): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator();
    await delegator.startAbility({ bundleName: 'com.yunheji.archive', abilityName: 'EntryAbility', parameters: { yunhejiTestStore: this.name } });
    await this.waitId('native-dock'); await this.waitId('tn-home');
    this.nightsAbility = await delegator.getCurrentTopAbility();
    expect(this.nightsAbility.context.abilityInfo.name).assertEqual('EntryAbility'); this.context = this.nightsAbility.context;
    expect(await (await preferences.getPreferences(this.context, { name: this.name })).has('snapshot')).assertTrue();
    console.info(`MARKET_NIGHTS_SYNC_SCOPE:${this.name}`);
  }
  async stop(): Promise<void> {
    if (!this.nightsAbility) return;
    await this.nightsAbility.context.terminateSelf(); this.nightsAbility = undefined;
    await this.wait(ON.text('设备回归准备中'));
  }
}

async function readAccount(session: NightsSyncUiSession, accountId: string): Promise<ArchiveSnapshot> {
  const name = accountStoreName(accountId, session.name); await preferences.removePreferencesFromCache(session.context, name);
  const snapshot = await new LocalArchiveRepository(session.context, name).load();
  const store = await preferences.getPreferences(session.context, { name });
  expect(JSON.stringify(parseSnapshot(await store.get('snapshot', '') as string))).assertEqual(JSON.stringify(snapshot)); return snapshot;
}
async function exposed(session: NightsSyncUiSession, scrollId: string, target: On): Promise<Component> {
  if (scrollId === 'login-scroll' || scrollId === 'profile-scroll') return session.inScroll(scrollId, target);
  const scoped = target.within(ON.id(scrollId));
  for (let attempt = 0; attempt < 18; attempt++) {
    const viewport = await (await session.waitId(scrollId)).getBounds();
    let top = viewport.top + 26; let bottom = viewport.bottom - 32;
    if (['tn-home', 'paper-memory', 'paper-profile'].includes(scrollId)) {
      top = Math.max(top, (await (await session.waitId('top-navigation-content')).getBounds()).bottom + 22);
      bottom = Math.min(bottom, (await (await session.waitId('tab-0')).getBounds()).top - 28);
    }
    let lower = attempt < 8; let distance = (bottom - top) * 0.43;
    const component = await session.driver.findComponent(scoped);
    if (component) {
      const bounds = await component.getBounds(); const center = (bounds.top + bounds.bottom) / 2;
      if (bounds.bottom > bounds.top && center >= top && center <= bottom) return session.wait(scoped, scrollId);
      lower = center > bottom; distance = Math.min(distance, Math.max(100, lower ? center - bottom + 45 : top - center + 45));
    }
    const x = Math.round((viewport.left + viewport.right) / 2); const start = lower ? bottom - (bottom - top) * 0.15 : top + (bottom - top) * 0.15;
    await session.driver.swipe(x, Math.round(start), x, Math.round(start + (lower ? -distance : distance)), 600); await session.driver.delayMs(150);
  }
  throw new Error(`NIGHTS_SYNC_TARGET_NOT_EXPOSED:${scrollId}`);
}
async function openAccount(session: NightsSyncUiSession): Promise<void> {
  await (await session.waitId('tab-3')).click(); await (await exposed(session, 'paper-profile', ON.id('profile-account'))).click(); await session.waitId('profile-scroll');
}
async function signIn(session: NightsSyncUiSession, value: NightsSyncFixture, register: boolean): Promise<string> {
  await openAccount(session); await (await session.inScroll('profile-scroll', ON.id('profile-login'))).click();
  await (await session.inScroll('login-scroll', ON.id(register ? 'account-mode-register' : 'account-mode-login'))).click();
  for (const id of ['account-username', 'account-password']) {
    const field = await session.inScroll('login-scroll', ON.id(id)); if ((await field.getText()).length > 0) await field.clearText();
    await (await session.inScroll('login-scroll', ON.id(id))).inputText(id === 'account-username' ? value.username : value.password);
  }
  await session.driver.pressBack(); await (await session.inScroll('login-scroll', ON.id('account-submit'))).click();
  for (let attempt = 0; attempt < 100; attempt++) {
    const restored = await new AccountWorkspaceStore(session.context, session.name).load();
    if (restored && !await session.driver.findComponent(ON.id('login-scroll'))) {
      for (let depth = 0; depth < 3; depth++) {
        if (!await session.driver.findComponent(ON.id('profile-scroll'))) break;
        await session.driver.pressBack(); await session.driver.delayMs(200);
      }
      await (await session.waitId('tab-0')).click(); await session.waitId('tn-home'); return restored.workspace.accountId;
    }
    const failure = await session.driver.findComponent(ON.id('account-message'));
    if (failure && (await failure.getText()).length > 0) throw new Error(`NIGHTS_SYNC_AUTH_FAILED:${await failure.getText()}`);
    await session.driver.delayMs(300);
  }
  throw new Error('NIGHTS_SYNC_AUTH_TIMEOUT');
}
function ownNote(snapshot: ArchiveSnapshot): ArchiveRecord | undefined {
  const notes = activeRecords(snapshot.records, 'note').filter(note => note.marketContext?.nightId === 'night-1');
  if (notes.length > 1) throw new Error('NIGHTS_SYNC_DUPLICATE_FROZEN_NOTE'); return notes[0];
}
function progressFrom(snapshot: ArchiveSnapshot): ArchiveRecord {
  const record = snapshot.records.find(item => item.id === marketNightRecordId('night-1') && !item.deleted);
  if (!record) throw new Error('NIGHTS_SYNC_PROGRESS_MISSING'); return record;
}
function stateFrom(snapshot: ArchiveSnapshot): RiverMarketV2 {
  const state = marketNightFromRecords(snapshot.records, 'night-1'); if (!state) throw new Error('NIGHTS_SYNC_STATE_MISSING'); return state;
}
function plainTombstone(snapshot: ArchiveSnapshot): ArchiveRecord | undefined {
  return snapshot.records.find(record => record.kind === 'note' && record.body === PLAIN_BODY && record.deleted);
}
function assertFrozen(note: ArchiveRecord, revised: boolean): void {
  const entry = marketCultureForNight('night-1');
  if (!note.marketContext || !entry) throw new Error('NIGHTS_SYNC_CONTEXT_MISSING');
  expect(note.body).assertEqual(revised ? REVISED_BODY : MEMORY_BODY); expect(note.siteId).assertEqual(entry.id);
  expect(note.marketContext.nightId).assertEqual('night-1'); expect(note.marketContext.routeId).assertEqual('balanced');
  expect(note.marketContext.round).assertEqual(0); expect(note.marketContext.batch).assertEqual(1);
  expect(note.marketContext.summary.arrivals).assertEqual(6); expect(note.marketContext.summary.served).assertEqual(5);
  expect(note.marketContext.summary.cash).assertEqual(79); expect(note.marketContext.layout.stalls[2].workers).assertEqual(2);
  expect(note.marketContext.layout.stalls[3].type).assertEqual('meat'); expect(note.marketContext.layout.tourZone).assertEqual(-1);
  expect(JSON.stringify(note.marketContext.sources)).assertEqual(JSON.stringify([entry.source]));
  expect(!note.paperContext && !note.roamingContext && !note.aiAssist && !note.snapshot3DPose && !note.deleted).assertTrue();
}
async function waitForState(session: NightsSyncUiSession, accountId: string,
  matches: (snapshot: ArchiveSnapshot) => boolean, hint: string): Promise<ArchiveSnapshot> {
  for (let attempt = 0; attempt < 90; attempt++) { const snapshot = await readAccount(session, accountId); if (matches(snapshot)) return snapshot; await session.driver.delayMs(250); }
  throw new Error(`NIGHTS_SYNC_DISK_NOT_REACHED:${hint}`);
}
async function serverBaseline(session: NightsSyncUiSession, value: NightsSyncFixture): Promise<NightsSyncBaseline> {
  const client = new AccountSyncClient(session.context); if (!await client.configure()) throw new Error('NIGHTS_SYNC_SERVICE_NOT_CONFIGURED');
  try {
    const authenticated = await client.authenticate(value.username, value.password, false);
    const local = await readAccount(session, authenticated.accountId);
    // 独立会话只带空records查询，UI才有权上传这轮实际操作产生的经营/记忆；不代替页面造进度。
    const reply = await client.exchange(emptySnapshot(local.deviceId)); const snapshot = emptySnapshot(local.deviceId); snapshot.records = reply.records;
    const note = ownNote(snapshot); if (!note) throw new Error('NIGHTS_SYNC_REMOTE_NOTE_MISSING');
    return { accountId: authenticated.accountId, snapshot, note, progress: progressFrom(snapshot), tombstone: plainTombstone(snapshot) };
  } finally { await client.logout(); }
}
async function serverConfirmed(session: NightsSyncUiSession, value: NightsSyncFixture, accountId: string,
  baseline: ArchiveSnapshot): Promise<NightsSyncBaseline> {
  await openAccount(session); await (await session.inScroll('profile-scroll', ON.id('account-refresh'))).click();
  await session.wait(ON.id('account-sync-state').text('已同步'), '正式UI收到服务器版本确认');
  await session.driver.pressBack(); await (await session.waitId('tab-0')).click(); await session.waitId('tn-home');
  const remote = await serverBaseline(session, value); expect(remote.accountId).assertEqual(accountId);
  for (const record of baseline.records) expect(recordVersionConfirmed(record, remote.snapshot.records)).assertTrue();
  expect(JSON.stringify(remote.progress)).assertEqual(JSON.stringify(progressFrom(baseline)));
  expect(JSON.stringify(remote.note)).assertEqual(JSON.stringify(ownNote(baseline)));
  if (plainTombstone(baseline)) expect(JSON.stringify(remote.tombstone)).assertEqual(JSON.stringify(plainTombstone(baseline)));
  return remote;
}
async function openNote(session: NightsSyncUiSession, note: ArchiveRecord): Promise<void> {
  await (await session.waitId('tab-2')).click(); await (await exposed(session, 'paper-memory', ON.id(`memory-open-${note.id}`))).click();
  await session.waitId('tn-memory-page');
  expect(await (await exposed(session, 'tn-memory-page', ON.id('tn-memory-body'))).getText()).assertEqual(note.body);
}
async function writeCultureDraft(session: NightsSyncUiSession, body: string, tags: string): Promise<void> {
  await session.waitId('tn-culture-page'); const write = await session.driver.findComponent(ON.id('tn-culture-write'));
  if (write) await (await session.waitId('tn-culture-write')).click();
  const scroll = write ? 'tn-culture-draft-scroll' : 'tn-culture-draft-column';
  await (await exposed(session, scroll, ON.id('tn-culture-body'))).inputText(body);
  await (await exposed(session, scroll, ON.id('tn-culture-tags'))).inputText(tags);
  await session.driver.pressBack(); await (await exposed(session, scroll, ON.id('tn-culture-save'))).click();
}
async function closeDraft(session: NightsSyncUiSession): Promise<void> {
  if (await session.driver.findComponent(ON.id('tn-culture-draft-close'))) await (await session.waitId('tn-culture-draft-close')).click();
}
async function capture(session: NightsSyncUiSession, label: string): Promise<void> {
  for (const id of ['login-scroll', 'profile-scroll', 'account-panel']) if (await session.driver.findComponent(ON.id(id))) throw new Error('NIGHTS_SYNC_PRIVATE_CAPTURE_DENIED');
  const profile = await session.driver.findComponent(ON.id('paper-profile'));
  if (profile) { const bounds = await profile.getBounds(); if (bounds.right > bounds.left && bounds.bottom > bounds.top) throw new Error('NIGHTS_SYNC_PROFILE_CAPTURE_DENIED'); }
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  expect((await delegator.executeShellCommand(`uitest screenCap -p /data/local/tmp/market-nights-sync-${label}.png`)).exitCode).assertEqual(0);
  expect((await delegator.executeShellCommand(`uitest dumpLayout -p /data/local/tmp/market-nights-sync-${label}.json`)).exitCode).assertEqual(0);
}
function logRecord(phase: string, name: string, record: ArchiveRecord): void {
  const raw = JSON.stringify(record); const count = Math.ceil(raw.length / 220);
  // 分片仅含业务记录，可还原整条正文/嵌套sources比较；不输出账号、口令、token或身份指针。
  for (let index = 0; index < count; index++) console.info(`MARKET_NIGHTS_SYNC_RECORD:${phase}:${name}:${index + 1}/${count}:${raw.slice(index * 220, (index + 1) * 220)}`);
}
async function runPhase(session: NightsSyncUiSession, value: NightsSyncFixture, phase: string, resume: boolean,
  action: () => Promise<void>): Promise<void> {
  const started = Date.now(); let launched = false;
  try {
    await session.start(resume); launched = true; const identity = await new AccountWorkspaceStore(session.context, session.name).load();
    if (!resume) { expect((await session.read()).records.length).assertEqual(0); expect(identity === undefined).assertTrue(); }
    else expect(identity !== undefined).assertTrue();
    await action(); console.info(`MARKET_NIGHTS_SYNC_DONE:${phase}:${Date.now() - started}`);
  } catch (error) {
    if (launched) { try { await capture(session, `${phase}-failure`); } catch { console.info(`MARKET_NIGHTS_SYNC_FAILURE_CAPTURE_SKIPPED:${phase}`); } }
    const message = (error as Error).message.split(value.username).join('[账号已隐藏]').split(value.password).join('[凭证已隐藏]'); throw new Error(message);
  } finally { if (launched) await session.stop(); }
}

export default function marketNightsSyncTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requested = parameters['class'] || parameters['-s class'] || '';
  if (!requested.includes('MarketNightsSyncTest')) return;
  describe('MarketNightsSyncTest', () => {
    it('device_a_register_first_batch_and_confirm_frozen_memory', 0, async () => {
      const value = await fixture(); const session = new NightsSyncUiSession('nights_sync_a', storeFor(value, 'a'));
      await runPhase(session, value, 'a-saved', false, async () => {
        const accountId = await signIn(session, value, true); expect((await readAccount(session, accountId)).records.length).assertEqual(0);
        await (await exposed(session, 'tn-home', ON.id('tn-open-night-1'))).click(); await session.waitId('tn-page');
        await (await session.waitId('tn-primary')).click();
        const first = await waitForState(session, accountId, snapshot => marketNightFromRecords(snapshot.records, 'night-1')?.batch === 1, 'A首批真实落盘');
        await session.waitId('tn-primary'); expect(stateFrom(first).phase).assertEqual('emergency');
        expect(stateFrom(first).round).assertEqual(0); expect(stateFrom(first).served).assertEqual(5); expect(stateFrom(first).cash).assertEqual(79);
        expect(activeRecords(first.records, 'note').length).assertEqual(0); await capture(session, 'a-first-batch');
        await (await session.waitId('tn-culture')).click(); await (await exposed(session, 'tn-sheet-scroll', ON.id('tn-moment-memory'))).click();
        await writeCultureDraft(session, MEMORY_BODY, '开封，三夜同步，首批暂停');
        const saved = await waitForState(session, accountId, snapshot => !!ownNote(snapshot), 'A明确确认保存冻结记忆');
        const note = ownNote(saved); if (!note) throw new Error('NIGHTS_SYNC_A_NOTE_MISSING'); assertFrozen(note, false);
        expect(JSON.stringify(progressFrom(saved))).assertEqual(JSON.stringify(progressFrom(first)));
        await closeDraft(session); await session.driver.pressBack(); await session.waitId('tn-page');
        await (await session.waitId('tn-back')).click(); await session.waitId('tn-home');
        await serverConfirmed(session, value, accountId, saved); logRecord('a-saved', 'progress', progressFrom(saved)); logRecord('a-saved', 'note', note);
        await openNote(session, note); await capture(session, 'a-frozen-memory');
      });
    });

    it('device_b_receive_checkpoint_emergency_continue_edit_and_delete_plain_note', 0, async () => {
      const value = await fixture(); const session = new NightsSyncUiSession('nights_sync_b', storeFor(value, 'b'));
      await runPhase(session, value, 'b-continued', false, async () => {
        const remote = await serverBaseline(session, value); assertFrozen(remote.note, false);
        const accountId = await signIn(session, value, false); expect(accountId).assertEqual(remote.accountId);
        const received = await waitForState(session, accountId, snapshot => !!ownNote(snapshot) && marketNightFromRecords(snapshot.records, 'night-1')?.batch === 1, 'B收到A首批与冻结记忆');
        const note = ownNote(received); if (!note || !note.marketContext) throw new Error('NIGHTS_SYNC_B_NOTE_MISSING');
        expect(JSON.stringify(note)).assertEqual(JSON.stringify(remote.note)); expect(JSON.stringify(progressFrom(received))).assertEqual(JSON.stringify(remote.progress));
        expect(note.deviceId !== received.deviceId).assertTrue(); logRecord('b-received', 'progress', progressFrom(received)); logRecord('b-received', 'note', note);
        await openNote(session, note); await capture(session, 'b-received-memory');
        await (await exposed(session, 'tn-memory-page', ON.id('tn-memory-continue'))).click(); await session.waitId('tn-page');
        expect(await (await session.waitId('tn-phase')).getText()).assertEqual('应急暂停');
        await (await session.waitId('tn-emergency-open')).click(); await (await exposed(session, 'tn-sheet-scroll', ON.id('tn-emergency-buy-meat'))).click();
        const delivered = await waitForState(session, accountId, snapshot => marketNightFromRecords(snapshot.records, 'night-1')?.emergencyUsed === 1, 'B真实急送肉');
        expect(stateFrom(delivered).stock.meat).assertEqual(stateFrom(received).stock.meat + 8);
        expect(stateFrom(delivered).cash).assertEqual(stateFrom(received).cash - 15);
        expect(JSON.stringify(stateFrom(delivered).reports)).assertEqual(JSON.stringify(stateFrom(received).reports));
        await (await session.waitId('tn-sheet-close')).click(); await (await session.waitId('tn-primary')).click();
        const continued = await waitForState(session, accountId, snapshot => marketNightFromRecords(snapshot.records, 'night-1')?.batch === 2, 'B继续第二批真实落盘');
        await session.waitId('tn-primary'); const after = stateFrom(continued);
        expect(after.arrivals).assertEqual(12); expect(after.served).assertEqual(10); expect(after.stock.meat).assertEqual(15); expect(after.cash).assertEqual(81);
        expect(after.reports[0].batches[1].income).assertEqual(17); expect(JSON.stringify(ownNote(continued))).assertEqual(JSON.stringify(note));
        expect(JSON.stringify(after.reports[0].batches[0])).assertEqual(JSON.stringify(stateFrom(received).reports[0].batches[0]));
        await capture(session, 'b-second-batch'); await (await session.waitId('tn-back')).click(); await session.waitId('tn-memory-page');
        await (await exposed(session, 'tn-memory-page', ON.id('tn-memory-edit'))).click();
        await (await exposed(session, 'tn-memory-page', ON.id('tn-memory-edit-body'))).inputText(REVISED_BODY); await session.driver.pressBack();
        await (await exposed(session, 'tn-memory-page', ON.id('tn-memory-save'))).click();
        const edited = await waitForState(session, accountId, snapshot => ownNote(snapshot)?.body === REVISED_BODY, 'B只编辑正文');
        const revised = ownNote(edited); if (!revised || !revised.marketContext) throw new Error('NIGHTS_SYNC_B_REVISED_NOTE_MISSING');
        expect(JSON.stringify(revised.marketContext)).assertEqual(JSON.stringify(note.marketContext)); assertFrozen(revised, true);
        // 从记忆进入资料时不携带经营context，这一篇是独立普通note；只删它，唯一冻结记忆保留供原A回读。
        await (await exposed(session, 'tn-memory-page', ON.id('tn-memory-archive'))).click(); await writeCultureDraft(session, PLAIN_BODY, '同步墓碑');
        const extra = await waitForState(session, accountId, snapshot => activeRecords(snapshot.records, 'note').some(item => item.body === PLAIN_BODY), 'B独立普通摘记');
        const plain = activeRecords(extra.records, 'note').find(item => item.body === PLAIN_BODY); if (!plain) throw new Error('NIGHTS_SYNC_PLAIN_NOTE_MISSING');
        expect(plain.marketContext === undefined).assertTrue(); await closeDraft(session); await session.driver.pressBack(); await session.waitId('tn-memory-page');
        await session.driver.pressBack(); await session.waitId('paper-memory');
        await (await exposed(session, 'paper-memory', ON.id(`memory-open-${plain.id}`))).click(); await session.waitId('memory-detail-page');
        await (await exposed(session, 'memory-detail-scroll', ON.id('memory-detail-delete'))).click();
        await (await session.wait(ON.text('删除').within(ON.type('AlertDialog')), '确认删除独立摘记')).click();
        const removed = await waitForState(session, accountId, snapshot => !!plainTombstone(snapshot), 'B普通note墓碑落盘');
        const tombstone = plainTombstone(removed); if (!tombstone) throw new Error('NIGHTS_SYNC_TOMBSTONE_MISSING');
        expect(activeRecords(removed.records, 'note').length).assertEqual(1); expect(JSON.stringify(ownNote(removed))).assertEqual(JSON.stringify(revised));
        await session.waitId('paper-memory'); await serverConfirmed(session, value, accountId, removed);
        logRecord('b-continued', 'progress', progressFrom(removed)); logRecord('b-continued', 'note', revised); logRecord('b-continued', 'tombstone', tombstone);
      });
    });

    it('device_a_receive_b_complete_state_frozen_context_sources_and_tombstone', 0, async () => {
      const value = await fixture(); const session = new NightsSyncUiSession('nights_sync_a_return', storeFor(value, 'a_return'));
      await runPhase(session, value, 'a-return', true, async () => {
        const restored = await new AccountWorkspaceStore(session.context, session.name).load(); if (!restored) throw new Error('NIGHTS_SYNC_ORIGINAL_A_IDENTITY_MISSING');
        const before = await readAccount(session, restored.workspace.accountId); const originalDevice = before.deviceId;
        const remote = await serverBaseline(session, value); expect(remote.accountId).assertEqual(restored.workspace.accountId);
        expect(stateFrom(remote.snapshot).batch).assertEqual(2); assertFrozen(remote.note, true); if (!remote.tombstone) throw new Error('NIGHTS_SYNC_REMOTE_TOMBSTONE_MISSING');
        // 冷启动可能已自动同步。这里按原A scope与deviceId证明恢复，再由正式刷新按钮取最新版本；
        // 不把启动后第一次读盘冒称“更新前旧版本”，也不创建第三个空scope假装原设备返程。
        await openAccount(session); await (await session.inScroll('profile-scroll', ON.id('account-refresh'))).click();
        await session.wait(ON.id('account-sync-state').text('已同步'), '原A正式刷新收到服务器确认');
        await session.driver.pressBack(); await (await session.waitId('tab-0')).click(); await session.waitId('tn-home');
        const received = await waitForState(session, restored.workspace.accountId, snapshot => {
          const state = marketNightFromRecords(snapshot.records, 'night-1'); return !!state && state.batch === 2 && ownNote(snapshot)?.body === REVISED_BODY && !!plainTombstone(snapshot);
        }, '原A收到B经营、正文与墓碑');
        expect(received.deviceId).assertEqual(originalDevice); expect(progressFrom(received).deviceId !== originalDevice).assertTrue();
        expect(JSON.stringify(progressFrom(received))).assertEqual(JSON.stringify(remote.progress));
        expect(JSON.stringify(ownNote(received))).assertEqual(JSON.stringify(remote.note)); expect(JSON.stringify(plainTombstone(received))).assertEqual(JSON.stringify(remote.tombstone));
        const note = ownNote(received); if (!note) throw new Error('NIGHTS_SYNC_A_RETURN_NOTE_MISSING'); assertFrozen(note, true);
        expect(stateFrom(received).arrivals).assertEqual(12); expect(note.marketContext?.summary.arrivals).assertEqual(6);
        await (await exposed(session, 'tn-home', ON.id('tn-open-night-1'))).click(); await session.waitId('tn-page');
        expect(await (await session.waitId('tn-batch')).getText()).assertEqual('已迎 2/3 批'); await capture(session, 'a-return-second-batch');
        await (await session.waitId('tn-back')).click(); await openNote(session, note); await capture(session, 'a-return-frozen-memory');
        const after = await readAccount(session, restored.workspace.accountId);
        expect(JSON.stringify(ownNote(after))).assertEqual(JSON.stringify(note)); expect(JSON.stringify(progressFrom(after))).assertEqual(JSON.stringify(remote.progress));
        expect(JSON.stringify(plainTombstone(after))).assertEqual(JSON.stringify(remote.tombstone));
        logRecord('a-return', 'progress', progressFrom(after)); logRecord('a-return', 'note', note); logRecord('a-return', 'tombstone', remote.tombstone);
        expect(compareVersions(note, remote.note)).assertEqual(0);
      });
    });
  });
}
