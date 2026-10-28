import { abilityDelegatorRegistry, Component, MatchPattern, ON, On } from '@kit.TestKit';
import { common, UIAbility } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { window } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { formInfo, formProvider } from '@kit.FormKit';
import { KeyCode } from '@kit.InputKit';
import { describe, expect, it } from '@ohos/hypium';
import { ArchiveRecord, ArchiveSnapshot, activeRecords, compareVersions, parseSnapshot } from '../../../main/ets/domain/ArchiveDomain';
import { RiverMarketV2, NIGHT_CONFIGS } from '../../../main/ets/domain/RiverMarketV2';
import { marketNightFromRecords } from '../../../main/ets/domain/RiverMarketV2Records';
import { MARKET_CULTURES, MarketCultureEntry } from '../../../main/ets/data/MarketCultureCatalog';
import { LocalArchiveRepository } from '../../../main/ets/data/LocalArchiveRepository';
import { readRoamingCardPreview } from '../../../main/ets/platform/RoamingSystem';
import { ROAMING_CONTINUE_FORM } from '../../../main/ets/roamingform/RoamingCardData';
import { ArchiveUiSession } from './ArchiveUiSession';

const BUNDLE: string = 'com.yunheji.archive';
const CARD_CACHE: string = 'yunheji_roaming_card_cache_v1';
const PHONE_BODY: string = '三更卖茶让我想到晚归的人。今天只读文献，也能把这一句与自己的感受收好。';
const PHONE_EDITED_BODY: string = '再读提瓶卖茶，我想把注意力留给夜归的人。补写这段感受时，原来那篇文献与出处仍应跟着同一页。';
const PHONE_EDITED_TAGS: string[] = ['夜归人', '提瓶卖茶', '再读'];
const TABLET_BODY: string = '我把跨段选中的文字拖进草稿，再留下自己的想法：夜市里既有吃食，也有继续往来的生活。';
const MARKET_BODY: string = '第一批客人已经走过，我在应急暂停时留下此刻的街灯与铺位。分享和重开不应改写这一页。';
interface AddedMarketForm { id: string; name: string; }
type MarketScrollRegion = 'whole' | 'reading' | 'draft';

function entry(index: number): MarketCultureEntry { return MARKET_CULTURES[index]; }
function expectedSelection(content: MarketCultureEntry): string {
  // 只比较SelectionContainer中四个真实Text的聚合结果，不向页面回灌测试造的摘录。
  return [content.quote, content.source.title, content.body, content.question].join('\n').trim().slice(0, 1800);
}

class MarketCultureUiSession extends ArchiveUiSession {
  private marketAbility: UIAbility | undefined = undefined;
  readonly addedForms: AddedMarketForm[] = [];
  phase: string = 'start';
  constructor(scenario: string) { super(scenario); }

  async start(_resumeAccount: boolean = false): Promise<void> {
    await abilityDelegatorRegistry.getAbilityDelegator().startAbility({ bundleName: BUNDLE, abilityName: 'EntryAbility',
      parameters: { yunhejiTestStore: this.name } });
    await this.waitId('tn-home'); await this.adoptAbility();
    expect(!await this.driver.findComponent(ON.id('login-scroll'))).assertTrue();
    console.info(`MARKET_CULTURE_STORE:${this.name}`);
  }

  async adoptAbility(): Promise<void> {
    this.marketAbility = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility();
    expect(this.marketAbility.context.abilityInfo.name).assertEqual('EntryAbility');
    this.context = this.marketAbility.context;
    const store = await preferences.getPreferences(this.context, { name: this.name });
    expect(await store.has('snapshot')).assertTrue();
  }

  async stop(): Promise<void> {
    if (!this.marketAbility) return;
    await this.marketAbility.context.terminateSelf(); this.marketAbility = undefined;
    // 卡片启动后宿主可能是桌面。只确认本应用页面消失，不误报整进程force-stop。
    const pageIds = ['tn-home', 'tn-page', 'tn-culture-page', 'tn-memory-page', 'paper-memory', 'paper-library', 'roaming-system-back'];
    let absent = 0;
    for (let attempt = 0; attempt < 40; attempt++) {
      let present = false;
      for (const id of pageIds) if (await this.driver.findComponent(ON.id(id))) present = true;
      absent = present ? 0 : absent + 1;
      if (absent >= 3) return;
      await this.driver.delayMs(150);
    }
    throw new Error('MARKET_CULTURE_ENTRY_PAGES_REMAIN');
  }

  async raw(): Promise<string> {
    await preferences.removePreferencesFromCache(this.context, this.name);
    const store = await preferences.getPreferences(this.context, { name: this.name });
    expect(await store.has('snapshot')).assertTrue();
    return await store.get('snapshot', '') as string;
  }

  async read(): Promise<ArchiveSnapshot> {
    const raw = await this.raw(); const disk = await new LocalArchiveRepository(this.context, this.name).load();
    expect(JSON.stringify(parseSnapshot(raw))).assertEqual(JSON.stringify(disk)); return disk;
  }
}

async function disk(session: MarketCultureUiSession, matches: (snapshot: ArchiveSnapshot) => boolean,
  hint: string): Promise<ArchiveSnapshot> {
  for (let attempt = 0; attempt < 70; attempt++) {
    const snapshot = await session.read(); if (matches(snapshot)) return snapshot;
    await session.driver.delayMs(150);
  }
  throw new Error(`MARKET_CULTURE_DISK_NOT_CONFIRMED:${hint}`);
}

async function exposed(session: MarketCultureUiSession, rootId: string, target: On,
  region: MarketScrollRegion = 'whole'): Promise<Component> {
  // 文化页有左右独立Scroll。按真实容器bounds选择阅读/草稿中线，不把拖卡变成滚动右栏，
  // 也不让根页滚动从HDS浮动Dock起手。每次重新定位，避免持有Navigation替换前的节点。
  const mainWindow = await window.getLastWindow(session.context as common.UIAbilityContext);
  for (let attempt = 0; attempt < 22; attempt++) {
    const viewport = await (await session.waitId(rootId)).getBounds();
    let top = viewport.top + 26; let bottom = viewport.bottom - 30;
    if (['tn-home', 'paper-library', 'paper-memory', 'paper-profile'].includes(rootId)) {
      top = Math.max(top, (await (await session.waitId('top-navigation-content')).getBounds()).bottom + 26);
      bottom = Math.min(bottom, (await (await session.waitId('tab-0')).getBounds()).top - 30);
    }
    if (rootId === 'tn-culture-page' && region === 'reading' && await session.driver.findComponent(ON.id('tn-culture-write'))) bottom -= 55;
    const keyboard = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_KEYBOARD).bottomRect;
    const windowRect = mainWindow.getWindowProperties().windowRect;
    // UiTest节点bounds可能仍包含被IME遮住的布局，必须叠加真实键盘避让区。
    // AvoidArea按主窗口坐标返回；手势使用屏幕px，所以加主窗口top后截断bottom。
    const keyboardTop = windowRect.top + keyboard.top;
    if (keyboard.height > 0) bottom = Math.min(bottom, keyboardTop - 30);
    const wholeTargetRequired = keyboard.height > 0 &&
      ['tn-culture-draft-scroll', 'tn-culture-draft-column'].includes(rootId);
    if (bottom - top < 135 || viewport.right <= viewport.left) throw new Error(`MARKET_CULTURE_SCROLL_VIEWPORT_SMALL:${rootId}`);
    let lower = attempt < 11; let distance = (bottom - top) * 0.43;
    const candidate = await session.driver.findComponent(target);
    if (candidate) {
      const bounds = await candidate.getBounds(); const center = (bounds.top + bounds.bottom) / 2;
      if (bounds.right > bounds.left && bounds.bottom > bounds.top) {
        const visible = wholeTargetRequired ? bounds.top >= top && bounds.bottom <= bottom : center >= top && center <= bottom;
        if (visible) {
          const stable = await session.wait(target, `${rootId}:visible`); const fresh = await stable.getBounds();
          const current = (fresh.top + fresh.bottom) / 2;
          const stillVisible = wholeTargetRequired ? fresh.top >= top && fresh.bottom <= bottom : current >= top && current <= bottom;
          if (fresh.bottom > fresh.top && stillVisible) return stable;
          continue;
        }
        lower = center > bottom; distance = Math.min(distance, Math.max(95, lower ? center - bottom + 45 : top - center + 45));
      }
    }
    const xRatio = region === 'reading' ? 0.28 : region === 'draft' ? 0.8 : 0.5;
    let x = Math.round(viewport.left + (viewport.right - viewport.left) * xRatio);
    // 草稿有明确的左右内边距；沿内边距滚动父Scroll，避免TextArea消费手势，
    // 也避免在旧的整屏bottom起手把手势发给软键盘。
    if (['tn-culture-draft-scroll', 'tn-culture-draft-column'].includes(rootId)) {
      x = Math.round(viewport.left + Math.max(28, Math.min(60, (viewport.right - viewport.left) * 0.05)));
    }
    const start = lower ? bottom - (bottom - top) * 0.15 : top + (bottom - top) * 0.15;
    console.info(`MARKET_CULTURE_SAFE_SCROLL:${JSON.stringify({ rootId, attempt, viewport, top, bottom,
      keyboardTop: keyboard.height > 0 ? keyboardTop : -1, keyboardHeight: keyboard.height, x, start,
      end: start + (lower ? -distance : distance) })}`);
    await session.driver.swipe(x, Math.round(start), x, Math.round(start + (lower ? -distance : distance)), 600);
    await session.driver.delayMs(150);
  }
  throw new Error(`MARKET_CULTURE_TARGET_COVERED:${rootId}`);
}

async function capture(label: string): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  // 只在已知独立游客应用页调用；系统ShareKit可能带联系人，不调用截图。
  expect((await delegator.executeShellCommand(`uitest screenCap -p /data/local/tmp/market-culture-${label}.png`)).exitCode).assertEqual(0);
  expect((await delegator.executeShellCommand(`uitest dumpLayout -p /data/local/tmp/market-culture-${label}.json`)).exitCode).assertEqual(0);
}

async function openReading(session: MarketCultureUiSession, content: MarketCultureEntry): Promise<void> {
  session.phase = `open_${content.id}`;
  await (await session.waitId('tab-1')).click(); await session.waitId('paper-library');
  await (await exposed(session, 'paper-library', ON.id(`site-row-${content.id}`))).click();
  await session.waitId('tn-culture-page');
  await disk(session, snapshot => snapshot.records.some(record => record.id === `progress:${content.id}` &&
    record.body === 'opened' && !record.deleted), '真实阅读opened');
}

async function assertNoGame(session: MarketCultureUiSession): Promise<void> {
  const snapshot = await session.read();
  expect(snapshot.records.every(record => !record.id.startsWith('progress:river-market:'))).assertTrue();
}

async function saveDraft(session: MarketCultureUiSession, body: string, wide: boolean,
  keepKeyboard: boolean = false): Promise<ArchiveRecord> {
  const scrollId = wide ? 'tn-culture-draft-column' : 'tn-culture-draft-scroll';
  const beforeDraft = await session.raw();
  await (await exposed(session, scrollId, ON.id('tn-culture-body'))).inputText(body);
  expect(await (await session.waitId('tn-culture-body')).getText()).assertEqual(body);
  const mainWindow = await window.getLastWindow(session.context as common.UIAbilityContext);
  if (keepKeyboard) { await waitKeyboard(session, mainWindow); expect(await session.raw()).assertEqual(beforeDraft); }
  else await session.driver.pressBack();
  expect(activeRecords((await session.read()).records, 'note').length).assertEqual(0);
  const confirm = await exposed(session, scrollId, ON.id('tn-culture-save'));
  if (keepKeyboard) {
    // 滚到确认按钮后再次确认键盘仍可见、草稿没有提前落盘，不能用滚动隐式收起键盘蒙混。
    await waitKeyboard(session, mainWindow); expect(await session.raw()).assertEqual(beforeDraft);
    expect(activeRecords((await session.read()).records, 'note').length).assertEqual(0);
  }
  await confirm.click();
  const snapshot = await disk(session, current => activeRecords(current.records, 'note').some(note => note.body === body), '明确确认保存');
  const note = activeRecords(snapshot.records, 'note').find(item => item.body === body);
  if (!note) throw new Error('MARKET_CULTURE_NOTE_MISSING');
  if (keepKeyboard) { await session.driver.pressBack(); await session.waitId('tn-culture-page'); }
  return note;
}

async function withOrientation(session: MarketCultureUiSession, orientation: window.Orientation,
  action: (mainWindow: window.Window) => Promise<void>): Promise<void> {
  const mainWindow = await window.getLastWindow(session.context as common.UIAbilityContext);
  const original = mainWindow.getPreferredOrientation(); let failed = false;
  try {
    await mainWindow.setPreferredOrientation(orientation);
    let correct = false;
    for (let attempt = 0; attempt < 40; attempt++) {
      const rect = mainWindow.getWindowProperties().windowRect;
      correct = orientation === window.Orientation.LANDSCAPE ? rect.width > rect.height : rect.height > rect.width;
      if (correct) break; await session.driver.delayMs(150);
    }
    if (!correct) throw new Error('MARKET_CULTURE_REAL_ORIENTATION_NOT_REACHED');
    await action(mainWindow);
  } catch (error) { failed = true; throw error as Error; }
  finally {
    try { await mainWindow.setPreferredOrientation(original); }
    catch (error) { if (!failed) throw error as Error; console.error(`MARKET_CULTURE_ORIENTATION_RESTORE:${(error as Error).message}`); }
  }
}

async function waitKeyboard(session: MarketCultureUiSession, mainWindow: window.Window): Promise<void> {
  for (let attempt = 0; attempt < 35; attempt++) {
    const keyboard = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_KEYBOARD);
    if (keyboard.bottomRect.height > 0) { console.info(`MARKET_CULTURE_KEYBOARD:${JSON.stringify(keyboard.bottomRect)}`); return; }
    await session.driver.delayMs(150);
  }
  throw new Error('MARKET_CULTURE_REAL_SOFT_KEYBOARD_NOT_VISIBLE');
}

async function openSavedNote(session: MarketCultureUiSession, note: ArchiveRecord, fromMarket: boolean = false): Promise<void> {
  const draftClose = await session.driver.findComponent(ON.id('tn-culture-draft-close'));
  if (draftClose) await (await session.waitId('tn-culture-draft-close')).click();
  await session.driver.pressBack(); await session.waitId(fromMarket ? 'tn-page' : 'paper-library');
  if (fromMarket) { await (await session.waitId('tn-back')).click(); await session.waitId('tn-home'); }
  await (await session.waitId('tab-2')).click(); await session.waitId('paper-memory');
  await (await exposed(session, 'paper-memory', ON.id(`memory-open-${note.id}`))).click();
  await session.waitId(note.marketContext ? 'tn-memory-page' : 'memory-detail-page');
}

async function oneMarketBatch(session: MarketCultureUiSession): Promise<RiverMarketV2> {
  session.phase = 'real_first_batch';
  await (await exposed(session, 'tn-home', ON.id('tn-open-night-1'))).click(); await session.waitId('tn-page');
  await disk(session, current => marketNightFromRecords(current.records, 'night-1') !== undefined, '新局实际保存');
  await (await session.waitId('tn-primary')).click();
  const snapshot = await disk(session, current => {
    const state = marketNightFromRecords(current.records, 'night-1'); return !!state && state.batch === 1 && state.phase === 'emergency';
  }, '第一段第一批真实结算');
  // 等真实回放结束后才取用应急按钮，不能用领域函数直接填一个通关记录。
  await session.waitId('tn-primary');
  expect(await (await session.waitId('tn-batch')).getText()).assertEqual('已迎 1/3 批');
  const saved = marketNightFromRecords(snapshot.records, 'night-1');
  if (!saved) throw new Error('MARKET_CULTURE_FIRST_BATCH_MISSING');
  expect(saved.round).assertEqual(0); expect(saved.batch).assertEqual(1); expect(saved.phase).assertEqual('emergency');
  return saved;
}

async function saveMarketMoment(session: MarketCultureUiSession): Promise<ArchiveRecord> {
  const state = await oneMarketBatch(session);
  await (await session.waitId('tn-culture')).click();
  await (await exposed(session, 'tn-sheet-scroll', ON.id('tn-moment-memory'))).click();
  await session.waitId('tn-culture-page');
  const wide = !!await session.driver.findComponent(ON.id('tn-culture-draft-column'));
  if (!wide) await (await session.waitId('tn-culture-write')).click();
  const note = await saveDraft(session, MARKET_BODY, wide);
  if (!note.marketContext) throw new Error('MARKET_CULTURE_MOMENT_CONTEXT_MISSING');
  expect(note.marketContext.round).assertEqual(state.round); expect(note.marketContext.batch).assertEqual(state.batch);
  expect(note.marketContext.summary.served).assertEqual(state.served);
  expect(JSON.stringify(note.marketContext.layout.stalls)).assertEqual(JSON.stringify(state.stalls));
  expect(JSON.stringify(note.marketContext.sources)).assertEqual(JSON.stringify([entry(0).source]));
  await openSavedNote(session, note, true); return note;
}

async function forms(session: MarketCultureUiSession): Promise<AddedMarketForm[]> {
  await preferences.removePreferencesFromCache(session.context, CARD_CACHE);
  const store = await preferences.getPreferences(session.context, { name: CARD_CACHE });
  return JSON.parse(await store.get('forms', '[]') as string) as AddedMarketForm[];
}

async function desktopCard(session: MarketCultureUiSession, form: AddedMarketForm): Promise<Component> {
  await session.driver.triggerKey(KeyCode.KEYCODE_HOME);
  const workspace = await session.waitId('GridSwiper_Stack_Swiper'); const id = `FormItem_${BUNDLE}_${form.id}column`;
  for (const direction of [1, -1]) {
    for (let page = 0; page < 5; page++) {
      const candidate = await session.driver.findComponent(ON.id(id));
      if (candidate) {
        const bounds = await candidate.getBounds();
        if (bounds.right > bounds.left && bounds.bottom > bounds.top) {
          await session.wait(ON.text('继续经营').within(ON.id(id)), '当前三夜卡片标题'); return session.waitId(id);
        }
      }
      const rect = await workspace.getBounds(); const width = rect.right - rect.left;
      const y = Math.round(rect.top + (rect.bottom - rect.top) * 0.6);
      await session.driver.swipe(Math.round(rect.left + width * (direction > 0 ? 0.82 : 0.18)), y,
        Math.round(rect.left + width * (direction > 0 ? 0.18 : 0.82)), y, 1000);
      await session.driver.delayMs(180);
    }
  }
  const known = await session.driver.findComponents(ON.id(`FormItem_${BUNDLE}_`, MatchPattern.STARTS_WITH));
  const ids: string[] = []; for (const item of known) ids.push(await item.getId());
  console.error(`MARKET_CULTURE_CARD_MISSING:${JSON.stringify({ id, ids })}`); throw new Error('MARKET_CULTURE_OWN_CARD_NOT_FOUND');
}

async function removeOwnCards(session: MarketCultureUiSession): Promise<void> {
  for (const form of session.addedForms) {
    await (await desktopCard(session, form)).longClick();
    let remove = await session.driver.findComponent(ON.text('移除卡片'));
    if (!remove) remove = await session.driver.findComponent(ON.text('移除').type('MenuItem'));
    if (!remove) remove = await session.driver.findComponent(ON.text('移除').type('Text'));
    if (!remove) throw new Error(`MARKET_CULTURE_OWN_CARD_REMOVE_MENU_UNKNOWN:${form.id}`);
    await remove.click(); let removed = false;
    for (let attempt = 0; attempt < 50; attempt++) {
      if (!(await forms(session)).some(item => item.id === form.id)) { removed = true; break; }
      const confirm = await session.driver.findComponent(ON.text('移除').type('Button')); if (confirm) await confirm.click();
      await session.driver.delayMs(150);
    }
    if (!removed) throw new Error(`MARKET_CULTURE_OWN_CARD_NOT_REMOVED:${form.id}`);
  }
}

async function runCase(session: MarketCultureUiSession, action: () => Promise<void>): Promise<void> {
  let failed = false;
  try { await session.start(); expect((await session.read()).records.length).assertEqual(0); await action(); }
  catch (error) {
    failed = true;
    if (error instanceof Error) {
      console.error(`MARKET_CULTURE_CASE_ERROR:${session.phase}:${error.message}\n${error.stack || ''}`);
      // 未知系统分享面板可能显示联系人，只在明确本应用游客页面时留失败图。
      const shareVisible = !!await session.driver.findComponent(ON.id('share_card'));
      const known = !!await session.driver.findComponent(ON.id('tn-culture-page')) ||
        !!await session.driver.findComponent(ON.id('tn-page')) || !!await session.driver.findComponent(ON.id('tn-memory-page'));
      if (!shareVisible && known) { try { await capture(`failure-${session.phase}`); } catch (_captureError) {} }
      throw error;
    }
    throw new Error('MARKET_CULTURE_NON_ERROR_FAILURE');
  } finally {
    try { if (session.addedForms.length > 0) await removeOwnCards(session); await session.dispose(); }
    catch (error) {
      if (!failed) { if (error instanceof Error) throw error; throw new Error('MARKET_CULTURE_NON_ERROR_CLEANUP_FAILURE'); }
      console.error(`MARKET_CULTURE_CLEANUP_AFTER_FAILURE:${(error as Error).message}`);
    }
  }
}

export default function marketNightsCultureTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requested = parameters['class'] || parameters['-s class'] || '';
  if (!requested.includes('MarketNightsCultureTest')) return;
  // 四例按设备/系统能力定向运行；不能将不同设备、不同包结果相加写成一次整套通过。
  describe('MarketNightsCultureTest', () => {
    it('native_tablet_market_selection_udmf_drag_and_explicit_plain_note', 0, async () => {
      const session = new MarketCultureUiSession('tn_culture_tablet');
      await runCase(session, async () => {
        expect(deviceInfo.sdkApiVersion >= 26).assertTrue(); expect(deviceInfo.deviceType).assertEqual('tablet');
        await withOrientation(session, window.Orientation.LANDSCAPE, async (_mainWindow: window.Window) => {
          await openReading(session, entry(0)); await session.waitId('tn-culture-draft-column');
          const before = await session.raw(); const selected = expectedSelection(entry(0));
          const paragraph = await exposed(session, 'tn-culture-page', ON.id('tn-culture-quote'), 'reading');
          session.phase = 'tablet_cross_text_select'; await paragraph.longClick(); await (await session.waitText('全选')).click();
          await (await session.waitText('做成摘录')).click();
          const card = await exposed(session, 'tn-culture-page', ON.id('tn-culture-excerpt-card'), 'reading');
          expect(await (await session.wait(ON.text(selected).within(ON.id('tn-culture-excerpt-card')))).getText()).assertEqual(selected);
          const target = await exposed(session, 'tn-culture-draft-column', ON.id('tn-culture-excerpt-drop'));
          const whole = await (await session.waitId('tn-culture-page')).getBounds(); const from = await card.getBounds(); const to = await target.getBounds();
          expect(from.bottom > from.top && to.bottom > to.top && from.left < to.left &&
            from.top >= whole.top && from.bottom <= whole.bottom && to.top >= whole.top && to.bottom <= whole.bottom).assertTrue();
          await capture('tablet-before-system-drag'); session.phase = 'tablet_real_udmf_drag';
          // 真正触发draggable→onDragStart→UnifiedData→onDrop，禁止点“加入”或构造UDMF替身。
          await card.dragTo(target); expect(await (await session.waitId('tn-culture-excerpt-value')).getText()).assertEqual(selected);
          expect(await session.raw()).assertEqual(before); expect(activeRecords((await session.read()).records, 'note').length).assertEqual(0);
          await capture('tablet-draft-after-system-drag');
          session.phase = 'tablet_explicit_save'; const note = await saveDraft(session, TABLET_BODY, true, true);
          expect(note.siteId).assertEqual(entry(0).id); expect(note.marketContext === undefined).assertTrue();
          expect(note.quotedPoemOrFact).assertEqual(`${selected}\n${entry(0).source.title}\n${entry(0).source.url}`);
          expect(note.paperContext === undefined && note.roamingContext === undefined && note.snapshot3DPose === undefined && note.aiAssist === undefined).assertTrue();
          await assertNoGame(session); const frozen = JSON.stringify(note); await openSavedNote(session, note);
          expect(await (await exposed(session, 'memory-detail-scroll', ON.id('memory-detail-body'))).getText()).assertEqual(TABLET_BODY);
          const reopened = (await session.read()).records.find(item => item.id === note.id);
          if (!reopened) throw new Error('MARKET_CULTURE_TABLET_NOTE_LOST'); expect(JSON.stringify(reopened)).assertEqual(frozen);
          await capture('tablet-frozen-plain-note');
          console.info(`MARKET_CULTURE_TABLET_RESULT:${JSON.stringify({ noteId: note.id, contentId: note.siteId,
            excerptLength: selected.length, selection: 'native-cross-Text-all', drag: 'Component.dragTo-UDMF', gameRequired: false })}`);
        });
      });
    });

    it('native_phone_culture_favorite_category_and_keyboard_save_without_game', 0, async () => {
      const session = new MarketCultureUiSession('tn_culture_phone');
      await runCase(session, async () => {
        expect(deviceInfo.sdkApiVersion >= 26).assertTrue(); expect(deviceInfo.deviceType).assertEqual('phone');
        await withOrientation(session, window.Orientation.PORTRAIT, async (mainWindow: window.Window) => {
          await openReading(session, entry(1)); await session.waitId('tn-culture-write');
          session.phase = 'phone_favorite_category'; await session.select('tn-culture-category', '待实地探访');
          await (await session.waitId('tn-culture-favorite')).click();
          await disk(session, current => activeRecords(current.records, 'favorite').some(record => record.siteId === entry(1).id &&
            record.tags.includes('待实地探访')), '真实收藏到分类');
          await session.select('tn-culture-category', '研究资料');
          await disk(session, current => activeRecords(current.records, 'favorite').some(record => record.siteId === entry(1).id &&
            record.tags.includes('研究资料') && !record.tags.includes('待实地探访')), '真实修改收藏分类');
          await assertNoGame(session); expect(activeRecords((await session.read()).records, 'note').length).assertEqual(0);
          await (await session.waitId('tn-culture-write')).click(); session.phase = 'phone_soft_keyboard';
          const beforeKeyboardDraft = await session.raw();
          const input = await exposed(session, 'tn-culture-draft-scroll', ON.id('tn-culture-body')); await input.click();
          await input.inputText(PHONE_BODY); await waitKeyboard(session, mainWindow);
          expect(await (await session.waitId('tn-culture-body')).getText()).assertEqual(PHONE_BODY);
          expect(activeRecords((await session.read()).records, 'note').length).assertEqual(0);
          // 保持真实软键盘可见，用避让区裁过的父Scroll安全区滚达并确认，不能先Back掩盖遮挡。
          session.phase = 'phone_save_with_keyboard';
          const keyboardConfirm = await exposed(session, 'tn-culture-draft-scroll', ON.id('tn-culture-save'));
          await waitKeyboard(session, mainWindow); expect(await session.raw()).assertEqual(beforeKeyboardDraft);
          expect(activeRecords((await session.read()).records, 'note').length).assertEqual(0);
          await keyboardConfirm.click();
          const saved = await disk(session, current => activeRecords(current.records, 'note').some(note => note.body === PHONE_BODY), '键盘中确认保存');
          const note = activeRecords(saved.records, 'note').find(item => item.body === PHONE_BODY);
          if (!note) throw new Error('MARKET_CULTURE_PHONE_NOTE_MISSING');
          expect(note.siteId).assertEqual(entry(1).id); expect(note.marketContext === undefined).assertTrue();
          expect(note.quotedPoemOrFact).assertEqual(`${entry(1).source.title}\n${entry(1).source.url}`);
          expect(activeRecords(saved.records, 'note').length).assertEqual(1); await assertNoGame(session);
          await session.driver.pressBack(); await session.waitId('tn-culture-page');
          session.phase = 'phone_plain_note_reopen_edit'; await openSavedNote(session, note);
          expect(await (await exposed(session, 'memory-detail-scroll', ON.id('memory-detail-body'))).getText()).assertEqual(PHONE_BODY);
          await session.wait(ON.text(entry(1).title).within(ON.id('memory-detail-scroll')), '普通文献笔记标题');
          await (await exposed(session, 'memory-detail-scroll', ON.id('memory-detail-edit'))).click();
          await session.waitId('note-editor-scroll');
          expect(await (await session.waitId('note-associated-site')).getText()).assertEqual(entry(1).title);
          expect(await (await exposed(session, 'note-editor-scroll', ON.id('note-body'))).getText()).assertEqual(PHONE_BODY);
          expect(await (await exposed(session, 'note-editor-scroll', ON.id('note-tags'))).getText()).assertEqual(note.tags.join('，'));
          // 只改原生编辑器中的正文和标签，不触碰印章、纸色、摘录开关或出处。
          await (await exposed(session, 'note-editor-scroll', ON.id('note-body'))).clearText();
          await (await exposed(session, 'note-editor-scroll', ON.id('note-body')))
            .inputText(PHONE_EDITED_BODY, { paste: true, addition: true });
          await (await exposed(session, 'note-editor-scroll', ON.id('note-tags'))).clearText();
          await (await exposed(session, 'note-editor-scroll', ON.id('note-tags')))
            .inputText(PHONE_EDITED_TAGS.join('，'), { paste: true, addition: true });
          expect(await (await session.waitId('note-tags')).getText()).assertEqual(PHONE_EDITED_TAGS.join('，'));
          const beforeEdit = await session.read();
          const latestBeforeEdit = beforeEdit.records.reduce((latest: number, record: ArchiveRecord): number => Math.max(latest, record.updatedAt), 0);
          session.phase = 'phone_plain_note_confirm_edit'; await (await session.waitId('save-note')).click();
          await session.editorClosed();
          const editedSnapshot = await disk(session, current => activeRecords(current.records, 'note').some(record =>
            record.id === note.id && record.body === PHONE_EDITED_BODY && record.tags.join('|') === PHONE_EDITED_TAGS.join('|')), '同一文献笔记明确确认编辑');
          const edited = activeRecords(editedSnapshot.records, 'note').find(record => record.id === note.id);
          if (!edited) throw new Error('MARKET_CULTURE_PHONE_EDITED_NOTE_MISSING');
          expect(edited.id).assertEqual(note.id); expect(edited.kind).assertEqual('note'); expect(edited.siteId).assertEqual(entry(1).id);
          expect(edited.body).assertEqual(PHONE_EDITED_BODY); expect(JSON.stringify(edited.tags)).assertEqual(JSON.stringify(PHONE_EDITED_TAGS));
          expect(Number.isSafeInteger(edited.updatedAt) && edited.updatedAt > latestBeforeEdit && edited.updatedAt > note.updatedAt).assertTrue();
          expect(edited.deviceId).assertEqual(editedSnapshot.deviceId); expect(edited.deleted).assertFalse();
          expect(edited.quotedPoemOrFact).assertEqual(note.quotedPoemOrFact);
          expect(edited.stampType).assertEqual(note.stampType); expect(edited.paperTheme).assertEqual(note.paperTheme);
          expect(edited.marketContext === undefined && edited.paperContext === undefined && edited.roamingContext === undefined &&
            edited.snapshot3DPose === undefined && edited.aiAssist === undefined).assertTrue();
          expect(activeRecords(editedSnapshot.records, 'note').length).assertEqual(1); await assertNoGame(session);
          // 保存只关闭SiteDetail的编辑Sheet，先回到同一篇记忆，再点它的真实“原文化档案”。
          await session.driver.pressBack(); await session.waitId('memory-detail-page');
          expect(await (await exposed(session, 'memory-detail-scroll', ON.id('memory-detail-body'))).getText()).assertEqual(PHONE_EDITED_BODY);
          session.phase = 'phone_plain_note_original_culture';
          await (await exposed(session, 'memory-detail-scroll', ON.id('memory-detail-archive'))).click();
          await session.waitId('tn-culture-page');
          expect(await (await exposed(session, 'tn-culture-page', ON.id('tn-culture-quote'), 'reading')).getText()).assertEqual(entry(1).quote);
          const afterArchive = (await session.read()).records.find(record => record.id === note.id);
          if (!afterArchive) throw new Error('MARKET_CULTURE_PHONE_EDITED_NOTE_LOST_AFTER_ARCHIVE');
          expect(compareVersions(afterArchive, edited)).assertEqual(0); expect(JSON.stringify(afterArchive)).assertEqual(JSON.stringify(edited));
          console.info(`MARKET_CULTURE_PHONE_RESULT:${JSON.stringify({ noteId: note.id, contentId: note.siteId,
            favoriteCategory: '研究资料', realSoftKeyboard: true, explicitSave: true, gameRequired: false,
            ordinaryNoteEdited: true, editKeptIdAndSource: true, editedAt: edited.updatedAt,
            originalCultureButtonRouted: true, marketContextFabricated: false })}`);
        });
      });
    });

    it('native_market_frozen_memory_sharekit_cancel_preserves_whole_snapshot', 0, async () => {
      const session = new MarketCultureUiSession('tn_memory_share');
      await runCase(session, async () => {
        const note = await saveMarketMoment(session); const before = await session.raw();
        session.phase = 'real_sharekit_cancel'; await (await exposed(session, 'tn-memory-page', ON.id('tn-memory-share'))).click();
        const panel = await session.waitId('share_card'); await session.wait(ON.id('slot_label').text('保存至图库'));
        console.info(`MARKET_CULTURE_SHARE_PANEL:${JSON.stringify({ id: await panel.getId(), noteId: note.id, receiverSelected: false })}`);
        expect(!!await session.driver.findComponent(ON.id('share_card'))).assertTrue(); await session.driver.pressBack();
        await session.waitId('tn-memory-page');
        for (let attempt = 0; attempt < 40 && await session.driver.findComponent(ON.id('share_card')); attempt++) await session.driver.delayMs(150);
        expect(!await session.driver.findComponent(ON.id('share_card'))).assertTrue(); expect(await session.raw()).assertEqual(before);
        const after = (await session.read()).records.find(item => item.id === note.id);
        if (!after) throw new Error('MARKET_CULTURE_SHARE_NOTE_LOST');
        expect(compareVersions(note, after)).assertEqual(0); expect(JSON.stringify(after)).assertEqual(JSON.stringify(note));
        console.info('MARKET_CULTURE_SHARE_CANCEL_RESULT:wholeSnapshotIdentical=true;frozenContextIdentical=true;receiverSelected=false');
      });
    });

    it('native_desktop_continue_market_card_actual_add_and_ability_cold_hot_batch', 0, async () => {
      const session = new MarketCultureUiSession('tn_market_form');
      await runCase(session, async () => {
        const state = await oneMarketBatch(session); await (await session.waitId('tn-back')).click(); await session.waitId('tn-home');
        const checkpoint = `第1段 · 已过1/3批`; let cacheReady = false;
        for (let attempt = 0; attempt < 60; attempt++) {
          const preview = readRoamingCardPreview(session.context, 'chapter');
          if (preview.chapterId === 'night-1' && preview.testStoreName === session.name && preview.progressLabel === checkpoint) { cacheReady = true; break; }
          await session.driver.delayMs(150);
        }
        expect(cacheReady).assertTrue(); await (await session.waitId('tab-3')).click(); await session.waitId('paper-profile');
        await (await exposed(session, 'paper-profile', ON.id('profile-system-cards'))).click(); await session.waitId('roaming-system-back');
        const before = await forms(session);
        const scroll = await session.wait(ON.type('Scroll').isAfter(ON.id('roaming-system-back')));
        const button = await scroll.scrollSearch(ON.id('roaming-add-chapter'), true, 90);
        if (!button) throw new Error('MARKET_CULTURE_ADD_CARD_BUTTON_MISSING');
        await button.click(); await (await session.waitText('添加这张漫游卡片')).click();
        let added: AddedMarketForm | undefined = undefined;
        for (let attempt = 0; attempt < 60; attempt++) {
          added = (await forms(session)).find(item => item.name === ROAMING_CONTINUE_FORM && !before.some(old => old.id === item.id));
          if (added) break;
          const title = await session.driver.findComponent(ON.text('添加到桌面').type('Text'));
          const confirm = await session.driver.findComponent(ON.text('添加').type('Button')); if (title && confirm) await confirm.click();
          await session.driver.delayMs(150);
        }
        if (!added) throw new Error('MARKET_CULTURE_FORM_NOT_ADDED'); session.addedForms.push(added);
        const published = await formProvider.getPublishedRunningFormInfoById(added.id);
        expect(published.formId).assertEqual(added.id); expect(published.formName).assertEqual(ROAMING_CONTINUE_FORM);
        expect(published.bundleName).assertEqual(BUNDLE); expect(published.dimension).assertEqual(formInfo.FormDimension.Dimension_2_4);
        expect(published.formLocation).assertEqual(formInfo.FormLocation.DESKTOP);
        for (const cold of [true, false]) {
          session.phase = cold ? 'card_ability_cold' : 'card_ability_hot'; if (cold) await session.stop();
          const card = await desktopCard(session, added);
          await session.wait(ON.text(NIGHT_CONFIGS[0].title).within(ON.id(await card.getId())));
          await session.wait(ON.text(checkpoint).within(ON.id(await card.getId()))); await card.click();
          await session.waitId('tn-page'); await session.adoptAbility();
          expect(await (await session.waitId('tn-batch')).getText()).assertEqual('已迎 1/3 批');
          const restored = marketNightFromRecords((await session.read()).records, 'night-1');
          if (!restored) throw new Error('MARKET_CULTURE_CARD_STATE_LOST'); expect(JSON.stringify(restored)).assertEqual(JSON.stringify(state));
          expect(activeRecords((await session.read()).records, 'note').length).assertEqual(0);
          console.info(`MARKET_CULTURE_CARD_ROUTE:${JSON.stringify({ formId: added.id, mode: cold ? 'ability-cold-onCreate' : 'ability-hot-onNewWant',
            nightId: restored.nightId, round: restored.round, batch: restored.batch, unchanged: true, processForceStop: false })}`);
        }
      });
    });
  });
}
