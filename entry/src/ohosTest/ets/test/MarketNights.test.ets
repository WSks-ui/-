import { abilityDelegatorRegistry, Component, Driver, ON, On } from '@kit.TestKit';
import { common, UIAbility } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { describe, expect, it } from '@ohos/hypium';
import { activeRecords, ArchiveRecord, ArchiveSnapshot, compareVersions, parseSnapshot } from '../../../main/ets/domain/ArchiveDomain';
import { MarketNightId, MarketNightResource, MarketNightStallType, RiverMarketV2, marketNightLayout,
  marketNightSummary, NIGHT_CONFIGS, NIGHT_SUPPLIES, marketNightSupplyCost } from '../../../main/ets/domain/RiverMarketV2';
import { marketNightFromRecords, marketNightRecordId } from '../../../main/ets/domain/RiverMarketV2Records';
import { RIVER_MARKET_RECORD_ID, riverMarketFromRecords } from '../../../main/ets/domain/RiverMarketRecords';
import { LocalArchiveRepository } from '../../../main/ets/data/LocalArchiveRepository';
import { TestContext } from './TestContext';

const MEMORY_BODY: string = '我把东街的一块铺位留给灯棚。客人先看灯，再买一碗茶，这一夜的热闹才留下来。';

function requestedStore(): string {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const name = parameters['archiveMarketNightsStore'] || parameters['-s archiveMarketNightsStore'] || '';
  // 三次 aa test 共用宿主明确指定的独立库。缺参数不回退正式档案，也不悄悄新建另一份库。
  if (!/^yunheji_test_ui_nights_[a-z0-9_]{1,60}$/.test(name)) throw new Error('NIGHTS_TEST_STORE_REQUIRED');
  return name;
}

class MarketNightsUiSession {
  readonly name: string;
  readonly driver: Driver = Driver.create();
  context: common.Context = TestContext.context;
  phase: string = 'new';
  private ability: UIAbility | undefined = undefined;

  constructor() { this.name = requestedStore(); }

  async wait(target: On, hint: string = ''): Promise<Component> {
    if (!await this.driver.waitForComponent(target, 10000)) throw new Error(`NIGHTS_TEST_TARGET_MISSING:${hint}`);
    let previous = ''; let stable = 0;
    for (let attempt = 0; attempt < 45; attempt++) {
      const component = await this.driver.findComponent(target);
      if (component) {
        try {
          const bounds = await component.getBounds(); const current = JSON.stringify(bounds);
          stable = current === previous && bounds.right > bounds.left && bounds.bottom > bounds.top &&
            await component.isEnabled() ? stable + 1 : 0;
          if (stable >= 2) return component;
          previous = current;
        } catch (error) {
          const original = error as Error;
          if (!original.message.includes('NoCandidates')) throw original;
          stable = 0; previous = '';
        }
      } else { stable = 0; previous = ''; }
      await this.driver.delayMs(120);
    }
    throw new Error(`NIGHTS_TEST_TARGET_UNSTABLE:${hint}`);
  }
  async id(id: string): Promise<Component> { return this.wait(ON.id(id), id); }
  async click(id: string): Promise<void> { await (await this.id(id)).click(); }

  async start(): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator();
    await delegator.startAbility({ bundleName: 'com.yunheji.archive', abilityName: 'EntryAbility',
      parameters: { yunhejiTestStore: this.name } });
    await this.id('tn-home'); this.ability = await delegator.getCurrentTopAbility();
    expect(this.ability.context.abilityInfo.name).assertEqual('EntryAbility'); this.context = this.ability.context;
    expect(!await this.driver.findComponent(ON.id('login-scroll'))).assertTrue();
    console.info(`MARKET_NIGHTS_TEST_STORE:${this.name}`);
  }
  async read(): Promise<ArchiveSnapshot> {
    await preferences.removePreferencesFromCache(this.context, this.name);
    const store = await preferences.getPreferences(this.context, { name: this.name });
    expect(await store.has('snapshot')).assertTrue();
    const raw = await store.get('snapshot', '') as string;
    const disk = await new LocalArchiveRepository(this.context, this.name).load();
    expect(JSON.stringify(parseSnapshot(raw))).assertEqual(JSON.stringify(disk)); return disk;
  }
  async stop(): Promise<void> {
    if (!this.ability) return;
    await this.ability.context.terminateSelf(); this.ability = undefined;
    let absent = 0;
    for (let attempt = 0; attempt < 35; attempt++) {
      let remaining = false;
      for (const id of ['tn-page', 'tn-home', 'tn-culture-page', 'tn-memory-page', 'river-market-page'])
        if (await this.driver.findComponent(ON.id(id))) remaining = true;
      absent = remaining ? 0 : absent + 1; if (absent >= 3) return;
      await this.driver.delayMs(150);
    }
    throw new Error('NIGHTS_TEST_ENTRY_REMAINS_AFTER_TERMINATE');
  }
  async run(label: string, action: () => Promise<void>): Promise<void> {
    const started = Date.now(); let failed = false;
    try { await this.start(); await action(); console.info(`MARKET_NIGHTS_PHASE_DONE:${label}:${Date.now() - started}`); }
    catch (error) {
      failed = true; const original = error as Error;
      console.error(`MARKET_NIGHTS_FAILED:${label}:${this.phase}:${original.message}\n${original.stack}`);
      try { await capture(`failure-${label}-${this.phase}`); } catch (diagnosticError) {
        console.error(`MARKET_NIGHTS_DIAGNOSTIC_FAILED:${(diagnosticError as Error).message}`);
      }
      throw original;
    } finally {
      // 每夜成功后只结束Ability，保留本轮独立库给下一夜。清理是最后单独显式case。
      try { await this.stop(); } catch (cleanupError) {
        const original = cleanupError as Error;
        if (!failed) throw original; console.error(`MARKET_NIGHTS_STOP_FAILED:${original.message}`);
      }
    }
  }
}

async function capture(label: string): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  expect((await delegator.executeShellCommand(`uitest screenCap -p /data/local/tmp/market-nights-${label}.png`)).exitCode).assertEqual(0);
  expect((await delegator.executeShellCommand(`uitest dumpLayout -p /data/local/tmp/market-nights-${label}.json`)).exitCode).assertEqual(0);
}

async function exposed(session: MarketNightsUiSession, scrollId: string, id: string): Promise<Component> {
  const target = ON.id(id).within(ON.id(scrollId));
  for (let attempt = 0; attempt < 18; attempt++) {
    const viewport = await (await session.id(scrollId)).getBounds();
    let top = viewport.top + 28; let bottom = viewport.bottom - 32;
    if (scrollId === 'tn-home' || scrollId === 'paper-memory') {
      top = Math.max(top, (await (await session.id('top-navigation-content')).getBounds()).bottom + 24);
      bottom = Math.min(bottom, (await (await session.id('tab-0')).getBounds()).top - 28);
    }
    let lower = attempt < 8; let distance = (bottom - top) * 0.43;
    const candidate = await session.driver.findComponent(target);
    if (candidate) {
      const bounds = await candidate.getBounds(); const center = (bounds.top + bounds.bottom) / 2;
      if (bounds.bottom > bounds.top && center >= top && center <= bottom) return session.wait(target, id);
      lower = center > bottom; distance = Math.min(distance, Math.max(100, lower ? center - bottom + 45 : top - center + 45));
    }
    const x = Math.round((viewport.left + viewport.right) / 2);
    const start = lower ? bottom - (bottom - top) * 0.15 : top + (bottom - top) * 0.15;
    await session.driver.swipe(x, Math.round(start), x, Math.round(start + (lower ? -distance : distance)), 600);
    await session.driver.delayMs(150);
  }
  throw new Error(`NIGHTS_TEST_NOT_EXPOSED:${scrollId}:${id}`);
}

async function disk(session: MarketNightsUiSession, matches: (snapshot: ArchiveSnapshot) => boolean, hint: string): Promise<ArchiveSnapshot> {
  for (let attempt = 0; attempt < 70; attempt++) { const snapshot = await session.read(); if (matches(snapshot)) return snapshot; await session.driver.delayMs(120); }
  throw new Error(`NIGHTS_TEST_DISK_NOT_REACHED:${hint}`);
}
function stateOf(snapshot: ArchiveSnapshot, night: MarketNightId): RiverMarketV2 {
  const state = marketNightFromRecords(snapshot.records, night); if (!state) throw new Error(`NIGHTS_TEST_PROGRESS_MISSING:${night}`); return state;
}
function recordOf(snapshot: ArchiveSnapshot, id: string): ArchiveRecord {
  const record = snapshot.records.find(item => item.id === id); if (!record) throw new Error(`NIGHTS_TEST_RECORD_MISSING:${id}`); return record;
}
function unchanged(snapshot: ArchiveSnapshot, original: ArchiveRecord): void {
  const current = recordOf(snapshot, original.id); expect(compareVersions(current, original)).assertEqual(0);
  expect(JSON.stringify(current)).assertEqual(JSON.stringify(original));
}
async function openNight(session: MarketNightsUiSession, night: MarketNightId): Promise<RiverMarketV2> {
  await (await exposed(session, 'tn-home', `tn-open-${night}`)).click(); await session.id('tn-page');
  const snapshot = await disk(session, value => !!marketNightFromRecords(value.records, night), `${night}:initial_flush`);
  await session.id('tn-primary'); return stateOf(snapshot, night);
}
async function closeSheet(session: MarketNightsUiSession): Promise<void> {
  if (await session.driver.findComponent(ON.id('tn-sheet-close'))) await session.click('tn-sheet-close');
}
async function mutate(session: MarketNightsUiSession, night: MarketNightId, id: string,
  matches: (state: RiverMarketV2, before: RiverMarketV2) => boolean): Promise<RiverMarketV2> {
  const before = stateOf(await session.read(), night);
  await (await exposed(session, 'tn-sheet-scroll', id)).click();
  const snapshot = await disk(session, value => { const state = marketNightFromRecords(value.records, night);
    return !!state && state.updatedAt > before.updatedAt && matches(state, before); }, id);
  return stateOf(snapshot, night);
}
async function stall(session: MarketNightsUiSession, night: MarketNightId, lot: number,
  type: MarketNightStallType | '' = '', staffDelta: number = 0, demolish: boolean = false): Promise<void> {
  session.phase = `arrange_${lot}_${type}_${staffDelta}`; await session.click('tn-emergency-open');
  await (await exposed(session, 'tn-sheet-scroll', `tn-select-lot-${lot}`)).click();
  if (demolish) await mutate(session, night, 'tn-demolish', state => state.stalls[lot].type === '');
  if (type) await mutate(session, night, `tn-build-${type}`, state => state.stalls[lot].type === type);
  for (let count = 0; count < Math.abs(staffDelta); count++) {
    const delta = staffDelta > 0 ? 1 : -1;
    await mutate(session, night, delta > 0 ? 'tn-staff-plus' : 'tn-staff-minus',
      (state, before) => state.stalls[lot].workers === before.stalls[lot].workers + delta);
  }
  await closeSheet(session);
}
async function lamps(session: MarketNightsUiSession, night: MarketNightId, zones: number[], on: boolean): Promise<void> {
  session.phase = `lamps_${on}`; await session.click('tn-forecast');
  for (const zone of zones) await mutate(session, night, `tn-zone-lamp-${zone}`, state => state.lamps[zone] === on);
  await closeSheet(session);
}
function stockOf(state: RiverMarketV2, resource: MarketNightResource): number {
  if (resource === 'rice') return state.stock.rice; if (resource === 'meat') return state.stock.meat;
  if (resource === 'tea') return state.stock.tea; return state.stock.oil;
}
function supplyAmount(resource: MarketNightResource): number {
  if (resource === 'rice') return NIGHT_SUPPLIES.rice; if (resource === 'meat') return NIGHT_SUPPLIES.meat;
  if (resource === 'tea') return NIGHT_SUPPLIES.tea; return NIGHT_SUPPLIES.oil;
}
async function supplies(session: MarketNightsUiSession, night: MarketNightId, resources: MarketNightResource[], emergency: boolean = false): Promise<void> {
  session.phase = `supply_${resources.join('_')}`; await session.click(emergency ? 'tn-emergency-open' : 'tn-supply-open');
  for (const resource of resources) await mutate(session, night, `${emergency ? 'tn-emergency-buy' : 'tn-buy'}-${resource}`,
    (state, before) => stockOf(state, resource) === stockOf(before, resource) + supplyAmount(resource) &&
      state.cash === before.cash - marketNightSupplyCost(resource, emergency));
  await closeSheet(session);
}
async function tour(session: MarketNightsUiSession, night: MarketNightId, zone: number): Promise<void> {
  session.phase = `tour_${zone}`; await session.click('tn-emergency-open');
  await mutate(session, night, `tn-tour-${zone}`, state => state.tourZone === zone); await closeSheet(session);
}

async function batch(session: MarketNightsUiSession, night: MarketNightId, round: number, number: number,
  doubleTap: boolean = false): Promise<RiverMarketV2> {
  session.phase = `batch_${round}_${number}`; await session.click('tn-primary');
  const snapshot = await disk(session, value => { const state = marketNightFromRecords(value.records, night);
    return !!state && state.round === round - 1 && state.batch === number; }, `${night}:${round}:${number}`);
  const original = recordOf(snapshot, marketNightRecordId(night));
  if (doubleTap) {
    let playback = false;
    for (let attempt = 0; attempt < 20; attempt++) {
      const primary = await session.driver.findComponent(ON.id('tn-primary'));
      if (primary && !await primary.isEnabled() && (await primary.getText()).includes('客人正在进街')) {
        const rect = await primary.getBounds(); await session.driver.doubleClick(Math.round((rect.left + rect.right) / 2), Math.round((rect.top + rect.bottom) / 2));
        playback = true; break;
      }
      await session.driver.delayMs(60);
    }
    expect(playback).assertTrue();
  }
  await session.id('tn-primary'); unchanged(await session.read(), original);
  expect(await (await session.id('tn-save-state')).getText()).assertEqual('已保存在本机');
  expect(activeRecords((await session.read()).records, 'note').length).assertEqual(0);
  return stateOf(snapshot, night);
}
async function endRound(session: MarketNightsUiSession, night: MarketNightId, round: number): Promise<RiverMarketV2> {
  session.phase = `end_${round}`; await session.click('tn-primary');
  const snapshot = await disk(session, value => marketNightFromRecords(value.records, night)?.round === round, `${night}:end:${round}`);
  await session.id('tn-primary'); return stateOf(snapshot, night);
}
async function fullRound(session: MarketNightsUiSession, night: MarketNightId, round: number): Promise<RiverMarketV2> {
  for (let number = 1; number <= 3; number++) await batch(session, night, round, number);
  return endRound(session, night, round);
}

export default function marketNightsTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requested = parameters['class'] || parameters['-s class'] || '';
  if (!requested.includes('MarketNightsTest')) return;
  describe('MarketNightsTest', () => {
    it('three_nights_phase_1_checkpoint_emergency', 0, async () => {
      const session = new MarketNightsUiSession();
      await session.run('night-1', async () => {
        expect((await session.read()).records.length).assertEqual(0);
        session.phase = 'legacy_v1_real_round';
        await (await exposed(session, 'tn-home', 'tn-legacy-market')).click(); await session.id('river-market-page');
        await session.click('market-open-round');
        const legacySnapshot = await disk(session, value => riverMarketFromRecords(value.records)?.round === 1, 'legacy_actual_first_round');
        const legacy = recordOf(legacySnapshot, RIVER_MARKET_RECORD_ID); await session.id('market-open-round');
        await session.click('market-back'); await session.id('tn-home'); await openNight(session, 'night-1');
        await stall(session, 'night-1', 3, '', 0, true); await stall(session, 'night-1', 0, 'meat', 2);
        await stall(session, 'night-1', 4, 'tea', 2); await lamps(session, 'night-1', [1], false);
        const first = await batch(session, 'night-1', 1, 1, true);
        const firstRecord = recordOf(await session.read(), marketNightRecordId('night-1'));
        expect(first.phase).assertEqual('emergency'); expect(first.reports[0].batches.length).assertEqual(1);
        session.phase = 'cold_checkpoint'; await capture('night1-first-batch'); await session.stop(); await session.start();
        unchanged(await session.read(), firstRecord); await openNight(session, 'night-1');
        expect(await (await session.id('tn-phase')).getText()).assertEqual('应急暂停');
        expect(JSON.stringify(stateOf(await session.read(), 'night-1'))).assertEqual(JSON.stringify(first));
        await batch(session, 'night-1', 1, 2); await batch(session, 'night-1', 1, 3); await endRound(session, 'night-1', 1);
        await batch(session, 'night-1', 2, 1); const shortage = await batch(session, 'night-1', 2, 2);
        expect(shortage.stock.meat).assertEqual(0);
        await capture('night1-shortage-before');
        await supplies(session, 'night-1', ['meat'], true);
        const delivered = stateOf(await session.read(), 'night-1');
        expect(delivered.emergencyUsed).assertEqual(1); expect(delivered.cash).assertEqual(shortage.cash - 15);
        expect(JSON.stringify(delivered.reports)).assertEqual(JSON.stringify(shortage.reports));
        expect(JSON.stringify(delivered.usedCapacity)).assertEqual(JSON.stringify(shortage.usedCapacity));
        expect(JSON.stringify(delivered.flow)).assertEqual(JSON.stringify(shortage.flow));
        const resumed = await batch(session, 'night-1', 2, 3);
        expect(resumed.reports[1].batches[2].served).assertEqual(9);
        expect(resumed.stock.meat).assertEqual(5); expect(resumed.reports[1].batches[2].reasons[0]).assertEqual(0);
        await capture('night1-emergency-after');
        await endRound(session, 'night-1', 2);
        await stall(session, 'night-1', 2, '', -1); await stall(session, 'night-1', 4, '', 1);
        await supplies(session, 'night-1', ['oil', 'rice']); await lamps(session, 'night-1', [0, 1, 2], true);
        await batch(session, 'night-1', 3, 1); await supplies(session, 'night-1', ['meat', 'tea'], true);
        await batch(session, 'night-1', 3, 2); await batch(session, 'night-1', 3, 3); await endRound(session, 'night-1', 3);
        await supplies(session, 'night-1', ['meat', 'tea']); const final = await fullRound(session, 'night-1', 4);
        expect(final.served).assertEqual(79); expect(final.cash).assertEqual(208); expect(marketNightSummary(final).passed).assertTrue();
        await session.id('tn-memory'); await session.id('tn-retry');
        unchanged(await session.read(), legacy); await capture('night1-closed');
        console.info(`MARKET_NIGHTS_NIGHT1:${JSON.stringify(final)};checkpointColdIdentical=true;doubleTapNoSecondCommit=true;emergencyMeatServedThree=true;notes=0;legacyV1Identical=true`);
      });
    });

    it('three_nights_phase_2_tea_inheritance', 0, async () => {
      const session = new MarketNightsUiSession();
      await session.run('night-2', async () => {
        const before = await session.read(); const first = stateOf(before, 'night-1'); expect(marketNightSummary(first).passed).assertTrue();
        const firstRecord = recordOf(before, marketNightRecordId('night-1')); const legacy = recordOf(before, RIVER_MARKET_RECORD_ID);
        const initial = await openNight(session, 'night-2');
        expect(JSON.stringify(marketNightLayout(initial))).assertEqual(JSON.stringify(marketNightLayout(first)));
        expect(initial.cash).assertEqual(70); expect(JSON.stringify(initial.stock)).assertEqual(JSON.stringify(NIGHT_CONFIGS[1].initialStock));
        expect(initial.round).assertEqual(0); expect(initial.served).assertEqual(0); expect(initial.reports.length).assertEqual(0);
        await lamps(session, 'night-2', [0, 1, 2], false);
        await stall(session, 'night-2', 0, '', 0, true); await stall(session, 'night-2', 3, 'meat', 1); await tour(session, 'night-2', 1);
        await fullRound(session, 'night-2', 1); await supplies(session, 'night-2', ['meat']); await fullRound(session, 'night-2', 2);
        await supplies(session, 'night-2', ['oil', 'tea']); await lamps(session, 'night-2', [0, 1, 2], true);
        await fullRound(session, 'night-2', 3); await supplies(session, 'night-2', ['meat', 'tea']);
        const final = await fullRound(session, 'night-2', 4);
        expect(final.served).assertEqual(82); expect(final.teaServed).assertEqual(45); expect(marketNightSummary(final).passed).assertTrue();
        expect(final.tourZone).assertEqual(1); unchanged(await session.read(), firstRecord); unchanged(await session.read(), legacy);
        await capture('night2-closed'); console.info(`MARKET_NIGHTS_NIGHT2:${JSON.stringify(final)};layoutOnlyInherited=true;priorNightIdentical=true;notes=0;legacyV1Identical=true`);
      });
    });

    it('three_nights_phase_3_lantern_memory_legacy', 0, async () => {
      const session = new MarketNightsUiSession();
      await session.run('night-3', async () => {
        const before = await session.read(); const second = stateOf(before, 'night-2'); expect(marketNightSummary(second).passed).assertTrue();
        const firstRecord = recordOf(before, marketNightRecordId('night-1')); const secondRecord = recordOf(before, marketNightRecordId('night-2'));
        const legacy = recordOf(before, RIVER_MARKET_RECORD_ID);
        expect(marketNightSummary(stateOf(before, 'night-1')).passed).assertTrue();
        expect(stateOf(before, 'night-1').served).assertEqual(79); expect(second.served).assertEqual(82); expect(second.teaServed).assertEqual(45);
        expect(riverMarketFromRecords(before.records)?.round).assertEqual(1);
        const existing = marketNightFromRecords(before.records, 'night-3');
        const resumedClosedCheckpoint = !!existing && existing.phase === 'closed' && marketNightSummary(existing).passed &&
          activeRecords(before.records, 'note').length === 0;
        const initial = await openNight(session, 'night-3'); let final: RiverMarketV2 = initial;
        if (resumedClosedCheckpoint) {
          // 只续验本轮真实UI已收市、尚未写记忆的检查点。读取而不注入经营state，
          // 不把这次尾部验证宣称为当前M/T包重新走过十二批；日志保留两种入口的实际边界。
          session.phase = 'resume_closed_checkpoint';
          expect(JSON.stringify(initial)).assertEqual(JSON.stringify(existing));
          expect(initial.phase).assertEqual('closed'); expect(initial.round).assertEqual(4); expect(initial.batch).assertEqual(0);
          expect(initial.routeId).assertEqual('balanced'); expect(initial.arrivals).assertEqual(108); expect(initial.cash).assertEqual(257);
          expect(initial.tourZone).assertEqual(-1); expect(JSON.stringify(initial.lamps)).assertEqual('[true,true,true]');
          expect(JSON.stringify(initial.stalls.map(item => item.type))).assertEqual('["","","rice","meat","tea","lantern"]');
          expect(JSON.stringify(initial.stalls.map(item => item.workers))).assertEqual('[0,0,1,2,2,1]');
          expect(initial.reports.length).assertEqual(4); expect(initial.reports.every(report => report.batches.length === 3)).assertTrue();
          expect(initial.reports.reduce((sum, report) => sum + report.arrivals, 0)).assertEqual(108);
          expect(initial.reports.reduce((sum, report) => sum + report.served, 0)).assertEqual(74);
          expect(initial.reports.reduce((sum, report) => sum + report.festivalServed, 0)).assertEqual(28);
          unchanged(await session.read(), firstRecord); unchanged(await session.read(), secondRecord); unchanged(await session.read(), legacy);
          console.info('MARKET_NIGHTS_NIGHT3_ENTRY:resumedClosedCheckpoint=true;newNightCreated=false;operatingBatchesReplayed=false');
        } else {
          console.info('MARKET_NIGHTS_NIGHT3_ENTRY:resumedClosedCheckpoint=false;newNightCreated=true;operatingBatchesReplayed=true');
          expect(JSON.stringify(marketNightLayout(initial))).assertEqual(JSON.stringify(marketNightLayout(second)));
          expect(initial.cash).assertEqual(90); expect(initial.served).assertEqual(0); expect(initial.arrivals).assertEqual(0);
          await tour(session, 'night-3', -1); await stall(session, 'night-3', 4, '', -1);
          await stall(session, 'night-3', 5, 'lantern', 1); await stall(session, 'night-3', 3, '', 1);
          await fullRound(session, 'night-3', 1); await supplies(session, 'night-3', ['meat']);
          await batch(session, 'night-3', 2, 1); await supplies(session, 'night-3', ['oil'], true);
          await batch(session, 'night-3', 2, 2); await batch(session, 'night-3', 2, 3); await endRound(session, 'night-3', 2);
          await supplies(session, 'night-3', ['oil', 'tea']); await fullRound(session, 'night-3', 3);
          await supplies(session, 'night-3', ['meat']); final = await fullRound(session, 'night-3', 4);
        }
        expect(final.served).assertEqual(74); expect(final.festivalServed).assertEqual(28); expect(marketNightSummary(final).passed).assertTrue();
        expect(activeRecords((await session.read()).records, 'note').length).assertEqual(0); await capture('night3-closed');
        session.phase = 'explicit_memory'; await session.click('tn-memory'); await session.id('tn-culture-page');
        await session.click('tn-culture-favorite');
        const favoriteSnapshot = await disk(session, value => activeRecords(value.records, 'favorite')
          .some(item => item.siteId === 'culture-kf-lantern-festival'), 'culture_real_favorite');
        const favorite = recordOf(favoriteSnapshot, 'favorite:culture-kf-lantern-festival');
        const write = await session.driver.findComponent(ON.id('tn-culture-write'));
        if (write) await session.click('tn-culture-write');
        const draftScroll = write ? 'tn-culture-draft-scroll' : 'tn-culture-draft-column';
        await (await exposed(session, draftScroll, 'tn-culture-body')).inputText(MEMORY_BODY);
        expect(activeRecords((await session.read()).records, 'note').length).assertEqual(0);
        await session.driver.pressBack(); await (await exposed(session, draftScroll, 'tn-culture-save')).click();
        const saved = await disk(session, value => activeRecords(value.records, 'note').some(note => note.body === MEMORY_BODY), 'explicit_confirm_memory');
        const note = activeRecords(saved.records, 'note').find(item => item.body === MEMORY_BODY);
        if (!note || !note.marketContext) throw new Error('NIGHTS_TEST_FROZEN_NOTE_MISSING');
        expect(activeRecords(saved.records, 'note').length).assertEqual(1);
        expect(note.marketContext.nightId).assertEqual('night-3'); expect(note.marketContext.routeId).assertEqual('balanced');
        expect(note.marketContext.summary.served).assertEqual(final.served); expect(note.marketContext.summary.festivalServed).assertEqual(final.festivalServed);
        expect(JSON.stringify(note.marketContext.layout)).assertEqual(JSON.stringify(marketNightLayout(final)));
        expect(note.marketContext.sources.length).assertEqual(1); expect(note.marketContext.sources[0].url.startsWith('https://')).assertTrue();
        expect(!note.paperContext && !note.roamingContext && !note.aiAssist && !note.snapshot3DPose).assertTrue();
        await session.stop(); await session.start(); unchanged(await session.read(), note); unchanged(await session.read(), favorite);
        await session.click('tab-2'); await (await exposed(session, 'paper-memory', `memory-open-${note.id}`)).click();
        await session.id('tn-memory-page');
        expect(await (await exposed(session, 'tn-memory-page', 'tn-memory-body')).getText()).assertEqual(MEMORY_BODY);
        expect((await (await exposed(session, 'tn-memory-page', 'tn-memory-summary')).getText()).includes('74 / 108')).assertTrue();
        await capture('frozen-memory'); await (await exposed(session, 'tn-memory-page', 'tn-memory-continue')).click(); await session.id('tn-page');
        session.phase = 'restart_keeps_frozen_memory'; await session.click('tn-retry');
        await (await exposed(session, 'tn-sheet-scroll', 'tn-route-west')).click();
        await (await session.wait(ON.text('确认重开').within(ON.type('AlertDialog')), 'confirm_route_restart')).click();
        await disk(session, value => { const state = marketNightFromRecords(value.records, 'night-3'); return !!state && state.round === 0 && state.routeId === 'west'; }, 'restart_actual_state');
        await lamps(session, 'night-3', [0], false);
        const restarted = await session.read(); unchanged(restarted, note); unchanged(restarted, favorite);
        unchanged(restarted, firstRecord); unchanged(restarted, secondRecord); unchanged(restarted, legacy);
        expect(stateOf(restarted, 'night-3').lamps[0]).assertFalse(); expect(note.marketContext.layout.lamps[0]).assertTrue();
        console.info(`MARKET_NIGHTS_NIGHT3:${JSON.stringify(final)};resumedClosedCheckpoint=${resumedClosedCheckpoint};notesCreatedOnlyOnConfirm=true;frozenMemoryColdIdentical=true;restartKeptFrozenNote=true;cultureFavoriteIdentical=true;priorNightsIdentical=true;legacyV1Identical=true`);
        console.info(`MARKET_NIGHTS_SAVED_NOTE:${JSON.stringify(note)}`); await capture('restart-preserves-memory');
      });
    });

    it('cleanup_only_requested_nights_store', 0, async () => {
      const session = new MarketNightsUiSession();
      await session.start(); const snapshot = await session.read(); await session.stop();
      await preferences.deletePreferences(session.context, session.name);
      await preferences.deletePreferences(session.context, `${session.name}_identity_v1`);
      console.info(`MARKET_NIGHTS_CLEANUP:${session.name}:records=${snapshot.records.length}`);
    });
  });
}
