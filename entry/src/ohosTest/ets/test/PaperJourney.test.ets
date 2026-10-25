import { abilityDelegatorRegistry, Component, ON, On } from '@kit.TestKit';
import { UIAbility } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { describe, expect, it } from '@ohos/hypium';
import { ArchiveRecord, ArchiveSnapshot, activeRecords, compareVersions, parseSnapshot } from '../../../main/ets/domain/ArchiveDomain';
import { PaperWorkV1, PAPER_COLUMNS, PAPER_ROWS, createPaperWork, judgePaper } from '../../../main/ets/domain/PaperJourney';
import { paperWorkFromRecords } from '../../../main/ets/domain/PaperJourneyRecords';
import { PAPER_CITIES, PaperCity } from '../../../main/ets/data/PaperJourneyCatalog';
import { LocalArchiveRepository } from '../../../main/ets/data/LocalArchiveRepository';
import { ArchiveUiSession } from './ArchiveUiSession';

const MEMORY_BODY: string = '我给纸灯留了三处不同方向的光，撤回后重新剪的那一道也留在了这张纸上。';

// 新首页测试拥有自己的启动约定，不更改旧登录/漫游专项的 session。
// 正式 EntryAbility 只接收独立测试库名；不预填作品、note、来源或通过状态。
class PaperJourneyUiSession extends ArchiveUiSession {
  private paperAbility: UIAbility | undefined = undefined;

  constructor(scenario: string) { super(scenario); }

  async start(_resumeAccount: boolean = false): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator();
    await delegator.startAbility({ bundleName: 'com.yunheji.archive', abilityName: 'EntryAbility',
      parameters: { yunhejiTestStore: this.name } });
    await this.waitId('native-dock');
    await this.waitId('paper-journey-home');
    this.paperAbility = await delegator.getCurrentTopAbility();
    expect(this.paperAbility.context.abilityInfo.name).assertEqual('EntryAbility');
    this.context = this.paperAbility.context;
    expect(!await this.driver.findComponent(ON.id('login-scroll'))).assertTrue();
    const store = await preferences.getPreferences(this.context, { name: this.name });
    expect(await store.has('snapshot')).assertTrue();
    console.info(`PAPER_JOURNEY_TEST_STORE:${this.name}`);
  }

  async stop(): Promise<void> {
    if (!this.paperAbility) return;
    await this.paperAbility.context.terminateSelf();
    this.paperAbility = undefined;
    await this.wait(ON.text('设备回归准备中'));
  }

  async read(): Promise<ArchiveSnapshot> {
    // 回读必须来自窗口所属Context，先移除缓存再分别通过正式Repository与严格解析器读取。
    // 两者一致才能把“画面变化”登记为真实落盘，不能只看“已保存”文字。
    await preferences.removePreferencesFromCache(this.context, this.name);
    const disk = await new LocalArchiveRepository(this.context, this.name).load();
    const store = await preferences.getPreferences(this.context, { name: this.name });
    const raw = await store.get('snapshot', '') as string;
    expect(JSON.stringify(parseSnapshot(raw))).assertEqual(JSON.stringify(disk));
    return disk;
  }
}

async function exposed(session: PaperJourneyUiSession, scrollId: string, target: On): Promise<Component> {
  const scroll = await session.waitId(scrollId);
  for (let attempt = 0; attempt < 10; attempt++) {
    let component = await session.driver.findComponent(target);
    if (!component) component = await scroll.scrollSearch(target, true, 100);
    if (!component) {
      await scroll.scrollToTop(2000);
      component = await scroll.scrollSearch(target, true, 100);
    }
    if (!component) throw new Error(`PAPER_TEST_TARGET_NOT_FOUND:${scrollId}`);
    component = await session.wait(target, scrollId);
    const viewport = await scroll.getBounds();
    const header = await (await session.waitId('top-navigation-content')).getBounds();
    const dock = await (await session.waitId('tab-0')).getBounds();
    const top = Math.max(viewport.top, header.bottom) + 18;
    const bottom = Math.min(viewport.bottom, dock.top) - 18;
    const bounds = await component.getBounds();
    if (bounds.right <= bounds.left || bounds.bottom <= bounds.top) {
      await scroll.scrollToTop(2000);
      await scroll.scrollSearch(target, true, 100);
      continue;
    }
    const center = (bounds.top + bounds.bottom) / 2;
    if (center >= top && center <= bottom) return component;
    const lower = center > bottom;
    const distance = Math.min((bottom - top) * 0.42, Math.max(90, lower ? center - bottom + 50 : top - center + 50));
    const start = lower ? bottom - 35 : top + 35;
    // 在页边操作真实Scroll，避开纸景Canvas和浮动栏；不改页面Scroller或挑战状态。
    await session.driver.swipe(Math.round(viewport.left + 10), Math.round(start),
      Math.round(viewport.left + 10), Math.round(start + (lower ? -distance : distance)), 600);
  }
  throw new Error(`PAPER_TEST_TARGET_NOT_EXPOSED:${scrollId}`);
}

async function homeClick(session: PaperJourneyUiSession, id: string): Promise<void> {
  await (await exposed(session, 'paper-journey-home', ON.id(id))).click();
}

async function openCity(session: PaperJourneyUiSession, city: PaperCity): Promise<void> {
  await (await session.waitId('paper-journey-home')).scrollToTop(2000);
  await homeClick(session, `paper-home-city-${city.id}`);
  await homeClick(session, 'paper-home-start');
  await session.waitId('paper-journey-page');
  expect(await (await session.waitId('paper-goal')).getText()).assertEqual(city.goal);
}

async function waitSnapshot(session: PaperJourneyUiSession,
  matches: (snapshot: ArchiveSnapshot) => boolean, hint: string): Promise<ArchiveSnapshot> {
  for (let attempt = 0; attempt < 60; attempt++) {
    const snapshot = await session.read();
    if (matches(snapshot)) return snapshot;
    await session.driver.delayMs(150);
  }
  throw new Error(`PAPER_TEST_DISK_STATE_NOT_REACHED:${hint}`);
}

function workFrom(snapshot: ArchiveSnapshot, cityId: string): PaperWorkV1 {
  const work = paperWorkFromRecords(snapshot.records, cityId);
  if (!work) throw new Error(`PAPER_TEST_WORK_MISSING:${cityId}`);
  return work;
}

async function searchLongmen(session: PaperJourneyUiSession): Promise<void> {
  await (await session.waitId('tab-1')).click();
  await session.waitId('paper-library');
  await (await session.waitId('paper-library')).scrollToTop(2000);
  const search = ON.type('SearchField').within(ON.id('library-search'));
  await (await exposed(session, 'paper-library', search)).inputText('龙门石窟');
  expect(await (await session.wait(search)).getText()).assertEqual('龙门石窟');
  await (await session.wait(ON.text('查找').type('Button'), '文化库原生查找按钮')).click();
  expect(await (await exposed(session, 'paper-library', ON.id('library-result-count'))).getText()).assertEqual('1 处档案');
  await exposed(session, 'paper-library', ON.id('site-row-ly-longmen'));
}

async function makeLegacyFavorite(session: PaperJourneyUiSession): Promise<ArchiveRecord> {
  await searchLongmen(session);
  await (await exposed(session, 'paper-library', ON.id('library-favorite-ly-longmen'))).click();
  const snapshot = await waitSnapshot(session, current => activeRecords(current.records, 'favorite')
    .some(record => record.siteId === 'ly-longmen'), 'UI收藏落盘');
  const favorite = activeRecords(snapshot.records, 'favorite').find(record => record.siteId === 'ly-longmen');
  if (!favorite) throw new Error('PAPER_TEST_LEGACY_FAVORITE_MISSING');
  expect(favorite.paperContext === undefined).assertTrue();
  return favorite;
}

function assertLegacyUnchanged(snapshot: ArchiveSnapshot, baseline: ArchiveRecord): void {
  const current = snapshot.records.find(record => record.id === baseline.id);
  if (!current) throw new Error('PAPER_TEST_LEGACY_FAVORITE_REMOVED');
  expect(compareVersions(current, baseline)).assertEqual(0);
  expect(JSON.stringify(current)).assertEqual(JSON.stringify(baseline));
}

interface ScenePoint { x: number; y: number; }

async function cutInScene(session: PaperJourneyUiSession, fromCol: number, fromRow: number,
  toCol: number, toRow: number): Promise<void> {
  // 2026-10-25 核对本机 API 26 UiTest：getBounds 返回px，swipe五参末尾是px/s。
  // 与当前Scene共用1000×1200 contain纸面，整张展开时纸张x110/y105/w780/h936。
  // 先取交互Canvas真实bounds，再由格心映射；不使用手机分辨率或固定全屏坐标。
  const canvas = await session.wait(ON.id('paper-journey-scene').within(ON.id('paper-play-scene')), '可剪切纸面Canvas');
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
  console.info(`PAPER_JOURNEY_SWIPE:${JSON.stringify({ bounds, start, end })}`);
  await session.driver.swipe(Math.round(start.x), Math.round(start.y), Math.round(end.x), Math.round(end.y), 350);
}

async function capture(name: string): Promise<void> {
  // 本套件只使用独立游客库，不进入登录/账号页。截图位置不含用户身份与凭据。
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  expect((await delegator.executeShellCommand(`uitest screenCap -p /data/local/tmp/paper-journey-${name}.png`)).exitCode).assertEqual(0);
  expect((await delegator.executeShellCommand(`uitest dumpLayout -p /data/local/tmp/paper-journey-${name}.json`)).exitCode).assertEqual(0);
}

function logNote(note: ArchiveRecord): void {
  const json = JSON.stringify(note);
  const count = Math.ceil(json.length / 700);
  for (let index = 0; index < count; index++) console.info(`PAPER_JOURNEY_NOTE:${index + 1}/${count}:${json.slice(index * 700, (index + 1) * 700)}`);
}

export default function paperJourneyTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requested = parameters['class'] || parameters['-s class'] || '';
  if (!requested.includes('PaperJourneyTest')) return;
  describe('PaperJourneyTest', () => {
    it('native_guest_five_cities_library_and_profile_entries', 0, async () => {
      const session = new PaperJourneyUiSession('paper_entries');
      await session.run(async () => {
        expect((await session.read()).records.length).assertEqual(0);
        await capture('first-home');
        for (const city of PAPER_CITIES) {
          await openCity(session, city);
          expect(paperWorkFromRecords((await session.read()).records, city.id) === undefined).assertTrue();
          expect(activeRecords((await session.read()).records, 'note').length).assertEqual(0);
          await (await session.waitId('paper-culture')).click();
          await session.waitText('这一剪，从哪里来');
          await (await session.waitId('paper-sheet-close')).click();
          await (await session.waitId('paper-back')).click();
          await session.waitId('paper-journey-home');
        }
        await searchLongmen(session);
        await capture('library-search');
        // 新版“我的”统一为第四页签，旧首页重复入口已撤下；从真实主导航进入。
        await (await session.waitId('tab-3')).click();
        await session.waitId('paper-profile');
        expect(await (await exposed(session, 'paper-profile', ON.id('profile-memories'))).getText()).assertEqual('0');
        await exposed(session, 'paper-profile', ON.id('profile-account'));
        await (await session.waitId('tab-2')).click();
        await session.waitId('paper-memory');
        expect(activeRecords((await session.read()).records, 'note').length).assertEqual(0);
        console.info('PAPER_JOURNEY_ENTRIES_RESULT:fiveCities=5;loginRequired=false;activeNotes=0;autoCompleted=0;librarySearch=龙门石窟;profileReached=true');
      });
    });

    it('native_cut_undo_ui_save_and_cold_reopen_preserve_work_sources_and_legacy_record', 0, async () => {
      const session = new PaperJourneyUiSession('paper_cut_memory');
      await session.run(async () => {
        const baseline = await makeLegacyFavorite(session);
        await (await session.waitId('tab-0')).click();
        const city = PAPER_CITIES.find(item => item.id === 'paper-kf');
        if (!city) throw new Error('PAPER_TEST_KAIFENG_MISSING');
        await openCity(session, city);
        const emptyMask = createPaperWork(city.id, 0).mask;
        await (await session.waitId('paper-fold-mirror')).click();
        await waitSnapshot(session, snapshot => paperWorkFromRecords(snapshot.records, city.id)?.fold === 'mirror', '对折实际保存');
        await (await session.waitId('paper-unfold')).click();
        await (await session.waitId('paper-fold-none')).click();
        await waitSnapshot(session, snapshot => paperWorkFromRecords(snapshot.records, city.id)?.fold === 'none', '回到整张展开纸面');

        await cutInScene(session, 8, 12, 12, 12);
        const firstCut = await waitSnapshot(session, snapshot => {
          const work = paperWorkFromRecords(snapshot.records, city.id); return !!work && work.mask !== emptyMask;
        }, '真实第一剪改变mask');
        expect(workFrom(firstCut, city.id).history.length).assertEqual(1);
        await (await session.waitId('paper-undo')).click();
        await waitSnapshot(session, snapshot => paperWorkFromRecords(snapshot.records, city.id)?.mask === emptyMask, '撤销真实恢复空纸');
        for (const segment of [[8, 12, 12, 12], [27, 14, 31, 14], [17, 34, 22, 34]]) {
          const before = workFrom(await session.read(), city.id).mask;
          await cutInScene(session, segment[0], segment[1], segment[2], segment[3]);
          await waitSnapshot(session, snapshot => {
            const savedWork = paperWorkFromRecords(snapshot.records, city.id);
            return !!savedWork && savedWork.mask !== before;
          }, '连续短剪逐笔保存');
        }
        await (await session.waitId('paper-light')).click();
        const cutSnapshot = await waitSnapshot(session, snapshot => paperWorkFromRecords(snapshot.records, city.id)?.light === true, '透光实际保存');
        const work = workFrom(cutSnapshot, city.id);
        expect(work.mask !== emptyMask).assertTrue();
        expect(judgePaper(work).passed).assertTrue();
        assertLegacyUnchanged(cutSnapshot, baseline);
        await capture('cut-three-windows');

        await (await session.waitId('paper-keep')).click();
        await (await session.waitId('paper-memory-body')).inputText(MEMORY_BODY);
        expect(await (await session.waitId('paper-memory-body')).getText()).assertEqual(MEMORY_BODY);
        await session.driver.pressBack();
        await (await session.waitId('paper-memory-save')).click();
        const savedSnapshot = await waitSnapshot(session, snapshot => activeRecords(snapshot.records, 'note')
          .some(note => note.paperContext?.cityId === city.id), '真实UI存入纸景记忆');
        const saved = activeRecords(savedSnapshot.records, 'note').find(note => note.paperContext?.cityId === city.id);
        if (!saved || !saved.paperContext) throw new Error('PAPER_TEST_SAVED_CONTEXT_MISSING');
        expect(saved.body).assertEqual(MEMORY_BODY);
        expect(saved.siteId).assertEqual(city.relatedSiteId);
        expect(saved.paperContext.work.mask).assertEqual(work.mask);
        expect(saved.paperContext.work.paper).assertEqual(work.paper);
        expect(saved.paperContext.work.light).assertTrue();
        expect(JSON.stringify(saved.paperContext.sources)).assertEqual(JSON.stringify(city.sources));
        expect(saved.paperContext.culture).assertEqual(city.culture);
        expect(saved.snapshot3DPose === undefined && saved.roamingContext === undefined && saved.aiAssist === undefined).assertTrue();
        assertLegacyUnchanged(savedSnapshot, baseline);
        const frozenNote = JSON.stringify(saved);
        const savedWork = JSON.stringify(workFrom(savedSnapshot, city.id));
        logNote(saved);

        // 正常结束EntryAbility后重启同一独立库，不经测试预填或页面变量回灌作品。
        await session.stop();
        await session.start();
        const reopened = await session.read();
        const reopenedNote = reopened.records.find(note => note.id === saved.id);
        if (!reopenedNote) throw new Error('PAPER_TEST_REOPEN_NOTE_MISSING');
        expect(JSON.stringify(reopenedNote)).assertEqual(frozenNote);
        expect(JSON.stringify(workFrom(reopened, city.id))).assertEqual(savedWork);
        assertLegacyUnchanged(reopened, baseline);
        await openCity(session, city);
        expect(workFrom(await session.read(), city.id).mask).assertEqual(work.mask);
        await capture('cold-reopened-work');
        await (await session.waitId('paper-back')).click();
        await (await session.waitId('tab-2')).click();
        await (await exposed(session, 'paper-memory', ON.id(`memory-open-${saved.id}`))).click();
        await session.waitId('paper-memory-page');
        await session.waitId('paper-note-preview');
        expect(await (await session.waitId('paper-note-body')).getText()).assertEqual(MEMORY_BODY);
        expect(JSON.stringify((await session.read()).records.find(note => note.id === saved.id))).assertEqual(frozenNote);
        console.info(`PAPER_JOURNEY_REOPEN_RESULT:${JSON.stringify({ noteId: saved.id, maskLength: work.mask.length,
          sources: saved.paperContext.sources.length, passed: judgePaper(work).passed, undoRestoredBlank: true,
          noteUnchanged: true, workUnchanged: true, legacyRecordUnchanged: true })}`);
      });
    });
  });
}
