import { abilityDelegatorRegistry, Component, Driver, ON, On } from '@kit.TestKit';
import { common, UIAbility } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { describe, expect, it } from '@ohos/hypium';
import { ArchiveRecord, ArchiveSnapshot, activeRecords, compareVersions, parseSnapshot } from '../../../main/ets/domain/ArchiveDomain';
import { RiverMarketState, MarketResource, marketSummary } from '../../../main/ets/domain/RiverMarket';
import { RIVER_MARKET_RECORD_ID, riverMarketFromRecords } from '../../../main/ets/domain/RiverMarketRecords';
import { MARKET_SOURCE_QUOTE, MARKET_SOURCES } from '../../../main/ets/data/RiverMarketCatalog';
import { LocalArchiveRepository } from '../../../main/ets/data/LocalArchiveRepository';
import { TestContext } from './TestContext';

const BODY: string = '我把空地留给了茶铺，前两段省灯油，夜深后再点亮三街。留住客人也要舍得花钱。';

// 本套只接收独立游客库名，从正式EntryAbility的新首页操作；不预填经营进度、note或成功结果。
// 不复用旧登录助手的异常重包装，以保留失败控件与原始Error.stack供设备报告定位。
class RiverMarketUiSession {
  readonly name: string;
  readonly driver: Driver = Driver.create();
  context: common.Context = TestContext.context;
  private ability: UIAbility | undefined = undefined;
  phase: string = 'new';

  constructor(scenario: string) {
    this.name = `yunheji_test_ui_${Date.now()}_${scenario}`;
    if (!/^yunheji_test_ui_[a-z0-9_]{1,80}$/.test(this.name)) throw new Error('MARKET_TEST_INVALID_STORE');
  }

  async wait(target: On, hint: string = ''): Promise<Component> {
    if (!await this.driver.waitForComponent(target, 10000)) throw new Error(`MARKET_TEST_TARGET_MISSING:${hint}`);
    let previous = '';
    let stable = 0;
    for (let attempt = 0; attempt < 35; attempt++) {
      const component = await this.driver.findComponent(target);
      if (component) {
        try {
          const bounds = await component.getBounds();
          const current = JSON.stringify(bounds);
          stable = current === previous && bounds.right > bounds.left && bounds.bottom > bounds.top &&
            await component.isEnabled() ? stable + 1 : 0;
          if (stable >= 3) return component;
          previous = current;
        } catch (error) {
          // 页面重建会短暂替换Widget，仅重试已知NoCandidates，其他平台错误原样抛出。
          const original = error as Error;
          if (!original.message.includes('NoCandidates')) throw original;
          stable = 0; previous = '';
        }
      } else { stable = 0; previous = ''; }
      await this.driver.delayMs(120);
    }
    throw new Error(`MARKET_TEST_TARGET_UNSTABLE:${hint}`);
  }

  async id(id: string): Promise<Component> { return this.wait(ON.id(id), id); }

  async start(): Promise<void> {
    this.phase = 'start_entry';
    const delegator = abilityDelegatorRegistry.getAbilityDelegator();
    await delegator.startAbility({ bundleName: 'com.yunheji.archive', abilityName: 'EntryAbility',
      parameters: { yunhejiTestStore: this.name } });
    await this.id('river-market-home');
    this.ability = await delegator.getCurrentTopAbility();
    expect(this.ability.context.abilityInfo.name).assertEqual('EntryAbility');
    this.context = this.ability.context;
    expect(!await this.driver.findComponent(ON.id('login-scroll'))).assertTrue();
    const store = await preferences.getPreferences(this.context, { name: this.name });
    expect(await store.has('snapshot')).assertTrue();
    console.info(`RIVER_MARKET_TEST_STORE:${this.name}`);
  }

  async read(): Promise<ArchiveSnapshot> {
    // 用实际窗口Context移除缓存后回读，正式Repository结果必须与严格解析的磁盘正文一致。
    // 测试只读取存储；所有建铺、调人、补货、结算和记忆都通过下方真实控件产生。
    await preferences.removePreferencesFromCache(this.context, this.name);
    const store = await preferences.getPreferences(this.context, { name: this.name });
    expect(await store.has('snapshot')).assertTrue();
    const raw = await store.get('snapshot', '') as string;
    const disk = await new LocalArchiveRepository(this.context, this.name).load();
    expect(JSON.stringify(parseSnapshot(raw))).assertEqual(JSON.stringify(disk));
    return disk;
  }

  async stop(): Promise<void> {
    if (!this.ability) return;
    await this.ability.context.terminateSelf();
    this.ability = undefined;
    // 冷重开确认Ability已结束，不假定系统随后把测试宿主或桌面带到前台。
    const ids: string[] = ['river-market-page', 'river-market-home', 'paper-memory', 'paper-library', 'native-dock'];
    let absent = 0;
    for (let attempt = 0; attempt < 35; attempt++) {
      let remaining = false;
      for (const id of ids) if (await this.driver.findComponent(ON.id(id))) remaining = true;
      absent = remaining ? 0 : absent + 1;
      if (absent >= 3) return;
      await this.driver.delayMs(150);
    }
    throw new Error('MARKET_TEST_ENTRY_PAGES_REMAIN_AFTER_TERMINATE');
  }

  async run(action: () => Promise<void>): Promise<void> {
    let failed = false;
    try {
      await this.start();
      await action();
    } catch (error) {
      failed = true;
      const original = error as Error;
      console.error(`RIVER_MARKET_TEST_FAILED:${this.phase}:${original.message}\n${original.stack}`);
      try { await capture(`failure-${this.phase}`); }
      catch (diagnosticError) { console.error(`RIVER_MARKET_DIAGNOSTIC_FAILED:${(diagnosticError as Error).message}`); }
      throw original;
    } finally {
      try {
        await this.stop();
        // 两个名称都由本次独立前缀派生；本套不登录、不进入账号页，也不触及正式档案。
        await preferences.deletePreferences(this.context, this.name);
        await preferences.deletePreferences(this.context, `${this.name}_identity_v1`);
      } catch (cleanupError) {
        const original = cleanupError as Error;
        if (!failed) throw original;
        console.error(`RIVER_MARKET_CLEANUP_AFTER_FAILURE:${original.message}\n${original.stack}`);
      }
    }
  }
}

async function capture(label: string): Promise<void> {
  // 页面仅包含当前独立游客库。此套从不展示账号，截图不含用户身份或凭据。
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  expect((await delegator.executeShellCommand(`uitest screenCap -p /data/local/tmp/river-market-${label}.png`)).exitCode).assertEqual(0);
  expect((await delegator.executeShellCommand(`uitest dumpLayout -p /data/local/tmp/river-market-${label}.json`)).exitCode).assertEqual(0);
}

async function exposed(session: RiverMarketUiSession, scrollId: string, target: On): Promise<Component> {
  // HDS浮动Dock覆盖根Scroll底部；只在当前安全视口中线滑动，先检查可见目标。
  // 不调用scrollSearch，不持有重建前的Scroll，也不让左边缘手势误触返回。
  const scoped = target.within(ON.id(scrollId));
  for (let attempt = 0; attempt < 18; attempt++) {
    const viewport = await (await session.id(scrollId)).getBounds();
    let top = viewport.top + 28;
    let bottom = viewport.bottom - 32;
    if (['river-market-home', 'paper-library', 'paper-memory'].includes(scrollId)) {
      top = Math.max(top, (await (await session.id('top-navigation-content')).getBounds()).bottom + 28);
      bottom = Math.min(bottom, (await (await session.id('tab-0')).getBounds()).top - 32);
    }
    if (viewport.right <= viewport.left || bottom - top < 150) throw new Error(`MARKET_TEST_SCROLL_RECT_SMALL:${scrollId}`);
    let lower = attempt < 8;
    let distance = (bottom - top) * 0.43;
    const component = await session.driver.findComponent(scoped);
    if (component) {
      const bounds = await component.getBounds();
      if (bounds.right > bounds.left && bounds.bottom > bounds.top) {
        const center = (bounds.top + bounds.bottom) / 2;
        if (center >= top && center <= bottom) {
          const stable = await session.wait(scoped, `${scrollId}:visible_target`);
          const fresh = await stable.getBounds();
          const freshCenter = (fresh.top + fresh.bottom) / 2;
          if (fresh.bottom > fresh.top && freshCenter >= top && freshCenter <= bottom) return stable;
          continue;
        }
        lower = center > bottom;
        distance = Math.min(distance, Math.max(100, lower ? center - bottom + 45 : top - center + 45));
      }
    }
    const x = Math.round((viewport.left + viewport.right) / 2);
    const start = lower ? bottom - (bottom - top) * 0.15 : top + (bottom - top) * 0.15;
    await session.driver.swipe(x, Math.round(start), x, Math.round(start + (lower ? -distance : distance)), 600);
    await session.driver.delayMs(150);
  }
  throw new Error(`MARKET_TEST_TARGET_NOT_EXPOSED:${scrollId}`);
}

async function disk(session: RiverMarketUiSession, matches: (snapshot: ArchiveSnapshot) => boolean,
  hint: string): Promise<ArchiveSnapshot> {
  for (let attempt = 0; attempt < 60; attempt++) {
    const snapshot = await session.read();
    if (matches(snapshot)) return snapshot;
    await session.driver.delayMs(120);
  }
  throw new Error(`MARKET_TEST_DISK_NOT_REACHED:${hint}`);
}

function stateOf(snapshot: ArchiveSnapshot): RiverMarketState {
  const state = riverMarketFromRecords(snapshot.records);
  if (!state) throw new Error('MARKET_TEST_PROGRESS_MISSING');
  return state;
}

function unchangedRecord(snapshot: ArchiveSnapshot, original: ArchiveRecord): void {
  const current = snapshot.records.find(record => record.id === original.id);
  if (!current) throw new Error(`MARKET_TEST_OLD_RECORD_REMOVED:${original.kind}`);
  expect(compareVersions(current, original)).assertEqual(0);
  expect(JSON.stringify(current)).assertEqual(JSON.stringify(original));
}

async function openMarket(session: RiverMarketUiSession): Promise<void> {
  await (await exposed(session, 'river-market-home', ON.id('market-home-open'))).click();
  await session.id('river-market-page');
}

async function advanceOne(session: RiverMarketUiSession, round: number, checkPlayback: boolean): Promise<RiverMarketState> {
  session.phase = `advance_${round}`;
  await (await session.id('market-open-round')).click();
  if (checkPlayback) {
    // 回放开始后按钮必须禁用。用禁用按钮的实时bounds发真实双击，不能调用领域动作代替连点。
    // 结算落盘在回放之前完成；回放结束后整条progress的版本与正文都必须保持同一笔。
    let sawPlayback = false;
    for (let attempt = 0; attempt < 25; attempt++) {
      const button = await session.driver.findComponent(ON.id('market-open-round'));
      if (button && !await button.isEnabled() && (await button.getText()).includes('客人正在进街')) {
        const bounds = await button.getBounds();
        expect(bounds.right > bounds.left && bounds.bottom > bounds.top).assertTrue();
        await session.driver.doubleClick(Math.round((bounds.left + bounds.right) / 2),
          Math.round((bounds.top + bounds.bottom) / 2));
        sawPlayback = true;
        break;
      }
      await session.driver.delayMs(60);
    }
    expect(sawPlayback).assertTrue();
  }
  const first = await disk(session, snapshot => riverMarketFromRecords(snapshot.records)?.round === round, `第${round}段一次落盘`);
  const progress = first.records.find(record => record.id === RIVER_MARKET_RECORD_ID);
  if (!progress) throw new Error('MARKET_TEST_PERSISTED_PROGRESS_MISSING');
  expect(stateOf(first).reports.length).assertEqual(round);
  expect(stateOf(first).reports[round - 1].round).assertEqual(round);
  await session.id('market-open-round');
  expect(await (await session.id('market-save-state')).getText()).assertEqual('已保存在本机');
  const ready = await session.read();
  unchangedRecord(ready, progress);
  expect(stateOf(ready).round).assertEqual(round);
  expect(activeRecords(ready.records, 'note').length).assertEqual(0);
  return stateOf(ready);
}

async function oldFavorite(session: RiverMarketUiSession): Promise<ArchiveRecord> {
  session.phase = 'legacy_favorite';
  await (await session.id('tab-1')).click();
  await session.id('paper-library');
  const search = ON.type('SearchField').within(ON.id('library-search'));
  await (await exposed(session, 'paper-library', ON.type('SearchField'))).inputText('龙门石窟');
  expect(await (await session.wait(search, '文化库检索框')).getText()).assertEqual('龙门石窟');
  await (await session.wait(ON.text('查找').type('Button').within(ON.id('paper-library')), '文化库原生查找')).click();
  expect(await (await exposed(session, 'paper-library', ON.id('library-result-count'))).getText()).assertEqual('1 处档案');
  await (await exposed(session, 'paper-library', ON.id('library-favorite-ly-longmen'))).click();
  const snapshot = await disk(session, current => activeRecords(current.records, 'favorite')
    .some(record => record.siteId === 'ly-longmen'), '实际点击收藏');
  const favorite = activeRecords(snapshot.records, 'favorite').find(record => record.siteId === 'ly-longmen');
  if (!favorite) throw new Error('MARKET_TEST_UI_FAVORITE_MISSING');
  return favorite;
}

async function supplies(session: RiverMarketUiSession, resources: MarketResource[]): Promise<void> {
  session.phase = `supplies_${resources.join('_')}`;
  await (await session.id('market-supply')).click();
  await session.id('market-sheet-scroll');
  for (const resource of resources) {
    const before = stateOf(await session.read());
    await (await exposed(session, 'market-sheet-scroll', ON.id(`market-buy-${resource}`))).click();
    await disk(session, snapshot => {
      const state = riverMarketFromRecords(snapshot.records);
      return !!state && state.round === before.round && state.supplyTrips === before.supplyTrips + 1 &&
        stockOf(state, resource) > stockOf(before, resource);
    }, `UI补${resource}`);
  }
  expect((await (await exposed(session, 'market-sheet-scroll', ON.id('market-supply-trips'))).getText()).includes('本段还可 0 趟')).assertTrue();
  await (await session.id('market-sheet-close')).click();
}

function stockOf(state: RiverMarketState, resource: MarketResource): number {
  // ArkTS不以动态字符串索引结构化库存；与页面一样显式列出四种可补货资源。
  if (resource === 'rice') return state.stock.rice;
  if (resource === 'meat') return state.stock.meat;
  if (resource === 'tea') return state.stock.tea;
  return state.stock.oil;
}

async function lights(session: RiverMarketUiSession, zones: number[], on: boolean): Promise<void> {
  session.phase = on ? 'light_three_streets' : 'save_early_oil';
  await (await session.id('market-forecast')).click();
  await session.id('market-sheet-scroll');
  for (const zone of zones) {
    expect(stateOf(await session.read()).lamps[zone]).assertEqual(!on);
    await (await exposed(session, 'market-sheet-scroll', ON.id(`market-zone-lamp-${zone}`))).click();
    await disk(session, snapshot => riverMarketFromRecords(snapshot.records)?.lamps[zone] === on, `UI街灯${zone}`);
  }
  await (await session.id('market-sheet-close')).click();
}

export default function riverMarketTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requested = parameters['class'] || parameters['-s class'] || '';
  if (!requested.includes('RiverMarketTest')) return;
  // 用device-test.ps1 -TestTimeoutMs 360000运行；本套只有两条定向演示路径，未指定class时不注册。
  describe('RiverMarketTest', () => {
    it('native_default_four_segments_fail_without_note_and_playback_cannot_advance_twice', 0, async () => {
      const session = new RiverMarketUiSession('market_default');
      await session.run(async () => {
        const blank = await session.read();
        expect(blank.records.length).assertEqual(0);
        expect(blank.reducedMotion).assertFalse();
        await openMarket(session);
        expect(riverMarketFromRecords((await session.read()).records) === undefined).assertTrue();
        expect(await (await session.id('market-cash')).getText()).assertEqual('60 钱');
        let result: RiverMarketState | undefined = undefined;
        for (let round = 1; round <= 4; round++) result = await advanceOne(session, round, true);
        if (!result) throw new Error('MARKET_TEST_DEFAULT_NOT_RUN');
        expect(result.served).assertEqual(34); expect(result.cash).assertEqual(134);
        expect(result.arrivals).assertEqual(100); expect(marketSummary(result).passed).assertFalse();
        expect(result.reports.some(report => report.reasons[0] > 0)).assertTrue();
        expect(result.reports.some(report => report.reasons[4] > 0)).assertTrue();
        expect(await (await session.id('market-closing-title')).getText()).assertEqual('今夜还有客人没留住');
        expect(activeRecords((await session.read()).records, 'note').length).assertEqual(0);
        await capture('default-closing');
        await (await session.id('market-open-round')).click();
        await session.wait(ON.text('四段收市账本').within(ON.id('market-sheet-scroll')), '真实收市账本');
        expect(stateOf(await session.read()).round).assertEqual(4);
        await (await session.id('market-sheet-close')).click();
        console.info(`RIVER_MARKET_DEFAULT_RESULT:${JSON.stringify(result)};notes=0;playbackDoubleTap=4`);
      });
    });

    it('native_strategy_save_plain_memory_cold_reopen_and_restart_preserve_note_and_old_favorite', 0, async () => {
      const session = new RiverMarketUiSession('market_strategy');
      await session.run(async () => {
        expect((await session.read()).records.length).assertEqual(0);
        const favorite = await oldFavorite(session);
        await (await session.id('tab-0')).click();
        await openMarket(session);
        session.phase = 'build_tea_and_staff';
        await (await session.id('market-lot-0')).click();
        expect(await (await session.id('market-selected')).getText()).assertEqual('西街上铺 · 空地');
        await (await session.id('market-build-tea')).click();
        await disk(session, snapshot => riverMarketFromRecords(snapshot.records)?.stalls[0].type === 'tea', 'UI建茶铺');
        for (let workers = 1; workers <= 2; workers++) {
          await (await session.id('market-staff-plus')).click();
          await disk(session, snapshot => riverMarketFromRecords(snapshot.records)?.stalls[0].workers === workers, 'UI逐位调伙计');
        }
        expect(await (await session.id('market-selected-workers')).getText()).assertEqual('2 伙计');
        await lights(session, [1], false);
        await advanceOne(session, 1, false);
        await supplies(session, ['meat', 'rice']);
        await advanceOne(session, 2, false);
        await supplies(session, ['oil', 'meat']);
        await lights(session, [0, 1, 2], true);
        await advanceOne(session, 3, false);
        await supplies(session, ['meat', 'tea']);
        const final = await advanceOne(session, 4, false);
        expect(final.served).assertEqual(71); expect(final.cash).assertEqual(209);
        expect(marketSummary(final).passed).assertTrue();
        expect(await (await session.id('market-closing-title')).getText()).assertEqual('今夜开市顺利');
        unchangedRecord(await session.read(), favorite);
        await capture('strategy-closing');

        session.phase = 'write_personal_memory';
        await (await session.id('market-write')).click();
        const input = await exposed(session, 'market-sheet-scroll', ON.id('market-memory-body'));
        await input.inputText(BODY);
        expect(await (await session.id('market-memory-body')).getText()).assertEqual(BODY);
        await session.driver.pressBack();
        await (await exposed(session, 'market-sheet-scroll', ON.id('market-memory-save'))).click();
        const saved = await disk(session, snapshot => activeRecords(snapshot.records, 'note')
          .some(note => note.body === BODY), '真实输入并确认保存普通note');
        const note = activeRecords(saved.records, 'note').find(record => record.body === BODY);
        if (!note) throw new Error('MARKET_TEST_USER_NOTE_MISSING');
        expect(activeRecords(saved.records, 'note').length).assertEqual(1);
        expect(note.kind).assertEqual('note'); expect(note.siteId).assertEqual('kf-zhouqiao');
        expect(note.paperContext === undefined && note.roamingContext === undefined &&
          note.aiAssist === undefined && note.snapshot3DPose === undefined).assertTrue();
        const expectedQuote = `“${MARKET_SOURCE_QUOTE}”\n${MARKET_SOURCES[0].title}，孟元老南宋追记北宋。\n${MARKET_SOURCES[0].url}\n` +
          '经营小样记录：四段接待71/100客，收市余钱209。地图与经营数值为原创游戏规则。';
        expect(note.quotedPoemOrFact).assertEqual(expectedQuote);
        unchangedRecord(saved, favorite);
        const progressBeforeCold = saved.records.find(record => record.id === RIVER_MARKET_RECORD_ID);
        if (!progressBeforeCold) throw new Error('MARKET_TEST_COLD_BASELINE_MISSING');

        session.phase = 'cold_ability_reopen';
        await session.stop();
        await session.start();
        session.phase = 'verify_cold_restore';
        const restored = await session.read();
        unchangedRecord(restored, progressBeforeCold); unchangedRecord(restored, note); unchangedRecord(restored, favorite);
        expect(JSON.stringify(stateOf(restored))).assertEqual(JSON.stringify(final));
        await (await session.id('tab-2')).click();
        await (await exposed(session, 'paper-memory', ON.id(`memory-open-${note.id}`))).click();
        await session.id('memory-detail-page');
        expect(await (await exposed(session, 'memory-detail-scroll', ON.id('memory-detail-body'))).getText()).assertEqual(BODY);
        expect(await (await exposed(session, 'memory-detail-scroll', ON.text(expectedQuote))).getText()).assertEqual(expectedQuote);
        unchangedRecord(await session.read(), note);
        await capture('frozen-memory');
        await session.driver.pressBack();
        await session.id('paper-memory');
        await (await session.id('tab-0')).click();
        await openMarket(session);
        expect(await (await session.id('market-cash')).getText()).assertEqual('209 钱');
        expect(await (await session.id('market-served')).getText()).assertEqual('已接待 71');
        await capture('cold-restored');

        session.phase = 'restart_preserves_old_memory';
        await (await session.id('market-retry')).click();
        // 本机API26原生Alert把操作文案暴露为Text；按实际对话框后代匹配，
        // 不能套用业务Button类型，误把已显示的确认框登记为“按钮不存在”。
        await (await session.wait(ON.text('重新开市').within(ON.type('AlertDialog')), '原生Alert确认重新开市')).click();
        const restarted = await disk(session, snapshot => riverMarketFromRecords(snapshot.records)?.round === 0, 'UI重开新一夜');
        const fresh = stateOf(restarted);
        expect(fresh.cash).assertEqual(60); expect(fresh.served).assertEqual(0);
        expect(fresh.arrivals).assertEqual(0); expect(fresh.reports.length).assertEqual(0);
        expect(fresh.stalls[0].type).assertEqual(''); expect(fresh.stalls[2].type).assertEqual('rice');
        expect(fresh.stalls[3].type).assertEqual('meat');
        unchangedRecord(restarted, note); unchangedRecord(restarted, favorite);
        expect(activeRecords(restarted.records, 'note').length).assertEqual(1);
        expect(note.quotedPoemOrFact).assertEqual(expectedQuote);
        console.info(`RIVER_MARKET_STRATEGY_RESULT:${JSON.stringify(final)};coldProgressIdentical=true;restartKeptNote=true;legacyFavoriteUnchanged=true`);
        console.info(`RIVER_MARKET_SAVED_NOTE:${JSON.stringify(note)}`);
      });
    });
  });
}
