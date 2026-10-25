import { abilityDelegatorRegistry, Component, ON, On } from '@kit.TestKit';
import { UIAbility } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { describe, expect, it } from '@ohos/hypium';
import { activeRecords, ArchiveRecord, compareVersions } from '../../../main/ets/domain/ArchiveDomain';
import { RoamChapter, roamProgress } from '../../../main/ets/domain/Roaming';
import { ROAM_CHAPTERS } from '../../../main/ets/data/RoamingCatalog';
import { ArchiveUiSession } from './ArchiveUiSession';

interface RoamingChoicePayload { choiceId: string; }

// 新版首次直接进入漫游。仅在本套件重载启动约定，旧登录专项和旧测试助手保持各自语义。
// 仍由正式 EntryAbility 接收 debug 测试库名；不写 Preferences 预填线索或个人记忆。
export class RoamingUiSession extends ArchiveUiSession {
  private roamingAbility: UIAbility | undefined = undefined;

  constructor(scenario: string, storeName: string = '') { super(scenario, storeName); }

  async start(_resumeAccount: boolean = false): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator();
    await delegator.startAbility({
      bundleName: 'com.yunheji.archive', abilityName: 'EntryAbility',
      parameters: { yunhejiTestStore: this.name }
    });
    await this.waitId('native-dock');
    this.roamingAbility = await delegator.getCurrentTopAbility();
    expect(this.roamingAbility.context.abilityInfo.name).assertEqual('EntryAbility');
    this.context = this.roamingAbility.context;
    await this.waitId('roaming-home');
    expect(!await this.driver.findComponent(ON.id('login-scroll'))).assertTrue();
    const store = await preferences.getPreferences(this.context, { name: this.name });
    expect(await store.has('snapshot')).assertTrue();
    console.info(`ROAMING_TEST_STORE:${this.name}`);
  }

  async stop(): Promise<void> {
    if (!this.roamingAbility) return;
    await this.roamingAbility.context.terminateSelf();
    this.roamingAbility = undefined;
    await this.wait(ON.text('设备回归准备中'));
  }
}

async function capture(name: string): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  expect((await delegator.executeShellCommand(
    `uitest screenCap -p /data/local/tmp/roaming-${name}.png`)).exitCode).assertEqual(0);
  expect((await delegator.executeShellCommand(
    `uitest dumpLayout -p /data/local/tmp/roaming-${name}.json`)).exitCode).assertEqual(0);
}

export async function visible(session: ArchiveUiSession, scrollId: string, target: On, requireEnabled: boolean = true): Promise<Component> {
  const scroll = await session.waitId(scrollId);
  let component = await session.driver.findComponent(target);
  if (!component) component = await scroll.scrollSearch(target, true, 90);
  if (!component) {
    // 原生 Scroll 会裁掉屏外节点；当前位置搜不到时回到真实页首再搜索，不能据此判功能缺失。
    await scroll.scrollToTop(40000);
    component = await scroll.scrollSearch(target, true, 90);
  }
  if (!component) throw new Error(`ROAMING_TARGET_NOT_FOUND:${scrollId}`);
  // 新主页在浮动栏下滚动。UiTest 已找到节点仍可能只露出边缘，点击前核对真实可触范围。
  // 纵向手势从左侧页边发起，避免抢走场景内的横向拨动；不更改应用 Scroller 或完成状态。
  for (let attempt = 0; attempt < 8; attempt++) {
    const viewport = await (await session.waitId(scrollId)).getBounds();
    let top = viewport.top + 24;
    let bottom = viewport.bottom - 30;
    if (scrollId === 'roaming-home') {
      const header = await (await session.waitId('top-navigation-content')).getBounds();
      const dock = await (await session.waitId('tab-0')).getBounds();
      top = Math.max(top, header.bottom + 20);
      bottom = Math.min(bottom, dock.top - 20);
    }
    if (requireEnabled) component = await session.wait(target, scrollId);
    else {
      // “尚不能确认”是需要验证的真实禁用状态，不能复用强制等 enabled 的点击等待器。
      component = await session.driver.waitForComponent(target, 10000);
      if (!component) throw new Error(`ROAMING_DISABLED_TARGET_NOT_FOUND:${scrollId}`);
    }
    const bounds = await component.getBounds();
    if (bounds.right <= bounds.left || bounds.bottom <= bounds.top) {
      // UiTest 对已滚出视口的节点可能只回零范围，无法据此判断在上方还是下方。
      // 从真实页首重新搜索，避免把“作/居”发现后位于上方的另一按钮越滚越远。
      await scroll.scrollToTop(40000);
      const searched = await scroll.scrollSearch(target, true, 90);
      if (!searched) throw new Error(`ROAMING_ZERO_BOUNDS_TARGET_NOT_FOUND:${scrollId}`);
      continue;
    }
    const center = (bounds.top + bounds.bottom) / 2;
    if (bounds.right > bounds.left && bounds.bottom > bounds.top && center >= top && center <= bottom) {
      return component;
    }
    const lower = center > bottom || bounds.bottom <= bounds.top;
    const distance = Math.min((bottom - top) * 0.4,
      Math.max(110, lower ? center - bottom + 65 : top - center + 65));
    const start = lower ? bottom - 40 : top + 40;
    await session.driver.swipe(Math.round(viewport.left + 12), Math.round(start),
      Math.round(viewport.left + 12), Math.round(start + (lower ? -distance : distance)), 700);
  }
  throw new Error(`ROAMING_TARGET_NOT_EXPOSED:${scrollId}`);
}

export async function click(session: ArchiveUiSession, scrollId: string, id: string): Promise<void> {
  await (await visible(session, scrollId, ON.id(id))).click();
}

function chapterFor(city: string): RoamChapter {
  const chapter = ROAM_CHAPTERS.find(item => item.city === city);
  if (!chapter) throw new Error(`ROAMING_CHAPTER_MISSING:${city}`);
  return chapter;
}

function assertPreserved(current: ArchiveRecord[], baselines: ArchiveRecord[]): void {
  for (const baseline of baselines) {
    const persisted = current.find(item => item.id === baseline.id);
    if (!persisted) throw new Error(`ROAMING_BASELINE_REMOVED:${baseline.id}`);
    expect(compareVersions(baseline, persisted)).assertEqual(0);
  }
}

export async function selectChapter(session: ArchiveUiSession, chapter: RoamChapter): Promise<void> {
  await (await session.waitId('roaming-home')).scrollToTop(40000);
  await click(session, 'roaming-home', `roam-pick-${chapter.id}`);
  expect(await (await visible(session, 'roaming-home', ON.id('roam-home-chapter-title'))).getText())
    .assertEqual(chapter.title);
  await click(session, 'roaming-home', 'roam-start');
}

export async function setSlider(session: ArchiveUiSession, percent: number): Promise<void> {
  const slider = await visible(session, 'roam-chapter-scroll', ON.id('roam-slider'));
  const bounds = await slider.getBounds();
  const inset = Math.min((bounds.bottom - bounds.top) * 0.32, (bounds.right - bounds.left) * 0.15);
  const left = bounds.left + inset;
  const right = bounds.right - inset;
  const y = Math.round((bounds.top + bounds.bottom) / 2);
  // 使用原生滑条的当前屏幕坐标做真实横向操作。开封第一条取65%，必须经过桥下观察区；
  // 不点击完成按钮前预填progress，也不调用页面的move/confirm函数替代手势。
  const target = percent >= 99 ? bounds.right - 2 : left + (right - left) * percent / 100;
  await session.driver.swipe(Math.round(left), y, Math.round(target), y, 600);
}

async function revealBySceneGesture(session: ArchiveUiSession): Promise<void> {
  const scene = await visible(session, 'roam-chapter-scroll', ON.id('roam-scene'));
  const bounds = await scene.getBounds();
  const width = bounds.right - bounds.left;
  const y = Math.round((bounds.top + bounds.bottom) / 2);
  // 地坑院直接拖动画面遮罩：横移68%画幅约对应95%的展开量，落在本线索72%的目标之外。
  // 使用真实PanGesture改变画面，不经测试参数或数据层直接标记“已发现”。
  await session.driver.swipe(Math.round(bounds.left + width * 0.16), y,
    Math.round(bounds.left + width * 0.84), y, 600);
}

export async function readingScroll(session: ArchiveUiSession, writing: boolean = false): Promise<string> {
  if (writing && await session.driver.findComponent(ON.id('roam-writing-column'))) return 'roam-writing-column';
  return await session.driver.findComponent(ON.id('roam-reading-column')) ? 'roam-reading-column' : 'roam-sheet-scroll';
}

async function completeKaifeng(session: ArchiveUiSession, baselines: ArchiveRecord[]): Promise<ArchiveRecord[]> {
  const chapter = chapterFor('开封');
  await selectChapter(session, chapter);
  await session.waitId('roaming-chapter-page');
  const chosenIds: string[] = [];
  for (let index = 0; index < chapter.clues.length; index++) {
    const clue = chapter.clues[index];
    await visible(session, 'roam-chapter-scroll', ON.id('roam-current-goal').text(clue.goal));
    const incomplete = await visible(session, 'roam-chapter-scroll', ON.id('roam-complete'), false);
    expect(await incomplete.isEnabled()).assertFalse();
    if (index < 2) await setSlider(session, index === 0 ? 65 : 85);
    const option = clue.options[index === 2 ? 1 : 0];
    chosenIds.push(option.id);
    await click(session, 'roam-chapter-scroll', `roam-choice-${option.id}`);
    if (index === 2) {
      const beforeLight = await visible(session, 'roam-chapter-scroll', ON.id('roam-complete'), false);
      expect(await beforeLight.isEnabled()).assertFalse();
      await click(session, 'roam-chapter-scroll', 'roam-light-lantern');
      expect(await (await visible(session, 'roam-chapter-scroll', ON.id('roam-light-lantern'))).getText())
        .assertEqual('灯已亮起');
    }
    expect(await (await visible(session, 'roam-chapter-scroll', ON.id('roam-feedback'))).getText())
      .assertEqual(option.detail);
    // 留下每一步真实操作后的场景原图，随后再滚回确认按钮。截图不代替落盘断言。
    await (await session.waitId('roam-chapter-scroll')).scrollToTop(40000);
    await visible(session, 'roam-chapter-scroll', ON.id('roam-scene'));
    await capture(`kaifeng-clue-${index + 1}-observed`);
    await click(session, 'roam-chapter-scroll', 'roam-complete');
    if (index < 2) {
      await visible(session, 'roam-chapter-scroll', ON.id('roam-current-goal').text(chapter.clues[index + 1].goal));
    } else await visible(session, 'roam-chapter-scroll', ON.id('roam-chapter-closing'));
    const snapshot = await session.read();
    expect(roamProgress(snapshot.records, chapter).completedCount).assertEqual(index + 1);
    expect(activeRecords(snapshot.records, 'note').length).assertEqual(1);
    assertPreserved(snapshot.records, baselines);
    console.info(`ROAMING_CLUE_PERSISTED:${JSON.stringify({ chapterId: chapter.id, clueId: clue.id,
      choiceId: option.id, completedCount: index + 1 })}`);
  }
  const completed = await session.read();
  expect(roamProgress(completed.records, chapter).completed).assertTrue();
  const gameRecords = completed.records.filter(record => record.id.startsWith(`progress:roam:v1:${chapter.id}:`));
  expect(gameRecords.length).assertEqual(3);
  for (let index = 0; index < gameRecords.length; index++) {
    const record = gameRecords.find(item => item.id.endsWith(`:${chapter.clues[index].id}`));
    if (!record) throw new Error('ROAMING_COMPLETED_RECORD_MISSING');
    expect(record.deleted).assertFalse();
    expect((JSON.parse(record.body) as RoamingChoicePayload).choiceId).assertEqual(chosenIds[index]);
  }
  await capture('kaifeng-completed');
  return gameRecords;
}

async function writePlainBaseline(session: ArchiveUiSession): Promise<ArchiveRecord[]> {
  await (await session.waitId('tab-2')).click();
  await (await session.inScroll('archive-scroll', ON.id('memory-new'))).click();
  await session.waitId('memory-write-page');
  await (await session.inScroll('memory-write-scroll', ON.id('memory-write-zz-duling-fangding'))).click();
  await session.waitId('note-editor-scroll');
  const body = '先留一页普通手账：我想从方鼎的整体轮廓继续观察。';
  await (await session.inScroll('note-editor-scroll', ON.id('note-body'))).inputText(body);
  await (await session.inScroll('note-editor-scroll', ON.id('note-tags'))).inputText('旧普通手账基线');
  await (await session.waitId('save-note')).click();
  await session.editorClosed();
  const snapshot = await session.read();
  const notes = activeRecords(snapshot.records, 'note');
  expect(notes.length).assertEqual(1);
  expect(notes[0].body).assertEqual(body);
  expect(notes[0].roamingContext === undefined).assertTrue();
  expect(notes[0].snapshot3DPose === undefined).assertTrue();
  expect(notes[0].aiAssist === undefined).assertTrue();
  expect(notes[0].siteId).assertEqual('zz-duling-fangding');
  await session.driver.pressBack();
  await session.waitId('archive-scroll');
  await (await session.waitId('tab-0')).click();
  await session.waitId('roaming-home');
  console.info(`ROAMING_PLAIN_BASELINE:${JSON.stringify({ noteId: notes[0].id, recordCount: snapshot.records.length })}`);
  return snapshot.records;
}

async function completeOfflineCity(city: string, scenario: string): Promise<void> {
  const session = new RoamingUiSession(scenario);
  const started = Date.now();
  await session.run(async () => {
    const chapter = chapterFor(city);
    expect((await session.read()).records.length).assertEqual(0);
    await selectChapter(session, chapter);
    await session.waitId('roaming-chapter-page');
    const selectedIds: string[] = [];
    for (let index = 0; index < chapter.clues.length; index++) {
      const clue = chapter.clues[index];
      await visible(session, 'roam-chapter-scroll', ON.id('roam-current-goal').text(clue.goal));
      const before = await session.read();
      expect(roamProgress(before.records, chapter).completedCount).assertEqual(index);
      expect(activeRecords(before.records, 'note').length).assertEqual(0);
      const confirm = await visible(session, 'roam-chapter-scroll', ON.id('roam-complete'), false);
      expect(await confirm.isEnabled()).assertFalse();

      const option = clue.options[index === 2 ? clue.options.length - 1 : chapter.scene === 'zz-meeting' && index === 0 ? 1 : 0];
      selectedIds.push(option.id);
      if (chapter.scene === 'zz-meeting' && index === 0) {
        // 郑州先明确选择陆门，再沿路走向城门；选择改变画面中的人物与行走路径。
        await click(session, 'roam-chapter-scroll', `roam-choice-${option.id}`);
        await setSlider(session, 85);
      } else if (chapter.scene === 'smx-home' && index === 0) {
        // 两处发现均经画面上的真实按钮，第一次点击后不应提前达到完整目标。
        await click(session, 'roam-chapter-scroll', 'roam-spot-kiln');
        expect((await (await visible(session, 'roam-chapter-scroll', ON.id('roam-feedback'))).getText())
          .includes('1 / 2')).assertTrue();
        await (await session.waitId('roam-chapter-scroll')).scrollToTop(40000);
        await click(session, 'roam-chapter-scroll', 'roam-spot-home');
      } else if (chapter.scene === 'smx-home' && index === 1) {
        await revealBySceneGesture(session);
      } else if (index < 2) {
        const needsWholeSentence = index === 1 && (chapter.scene === 'ly-spring' || chapter.scene === 'zz-meeting');
        await setSlider(session, needsWholeSentence ? 100 : 85);
      }
      if (!(chapter.scene === 'zz-meeting' && index === 0)) {
        await click(session, 'roam-chapter-scroll', `roam-choice-${option.id}`);
      }
      if (index === 1 && (chapter.scene === 'ly-spring' || chapter.scene === 'zz-meeting')) {
        expect(await (await visible(session, 'roam-chapter-scroll', ON.id('roam-revealed-quote'))).getText())
          .assertEqual(chapter.scene === 'ly-spring' ? '洛阳之俗，大抵好花。' : '溱与洧，方涣涣兮。');
      }
      expect(await (await visible(session, 'roam-chapter-scroll', ON.id('roam-feedback'))).getText())
        .assertEqual(option.detail);
      await (await session.waitId('roam-chapter-scroll')).scrollToTop(40000);
      await visible(session, 'roam-chapter-scroll', ON.id('roam-scene'));
      await capture(`${chapter.scene}-clue-${index + 1}-observed`);
      await click(session, 'roam-chapter-scroll', 'roam-complete');
      if (index < 2) {
        await visible(session, 'roam-chapter-scroll', ON.id('roam-current-goal').text(chapter.clues[index + 1].goal));
      } else await visible(session, 'roam-chapter-scroll', ON.id('roam-chapter-closing'));
      const after = await session.read();
      expect(roamProgress(after.records, chapter).completedCount).assertEqual(index + 1);
      expect(activeRecords(after.records, 'note').length).assertEqual(0);
      expect(activeRecords(after.records, 'favorite').length).assertEqual(0);
      console.info(`ROAMING_CITY_CLUE_PERSISTED:${JSON.stringify({ chapterId: chapter.id, clueId: clue.id,
        choiceId: option.id, completedCount: index + 1, activeNotes: 0 })}`);
    }
    const finished = await session.read();
    const progress = roamProgress(finished.records, chapter);
    expect(progress.completed).assertTrue();
    expect(progress.completedCount).assertEqual(3);
    expect(progress.nextClueId).assertEqual('');
    expect(activeRecords(finished.records, 'note').length).assertEqual(0);
    for (let index = 0; index < chapter.clues.length; index++) {
      const record = finished.records.find(item => item.id === `progress:roam:v1:${chapter.id}:${chapter.clues[index].id}`);
      if (!record) throw new Error(`ROAMING_CITY_RECORD_MISSING:${chapter.id}:${index}`);
      expect(record.deleted).assertFalse();
      expect((JSON.parse(record.body) as RoamingChoicePayload).choiceId).assertEqual(selectedIds[index]);
    }
    for (const other of ROAM_CHAPTERS) {
      if (other.id !== chapter.id) expect(roamProgress(finished.records, other).completedCount).assertEqual(0);
    }
    await capture(`${chapter.scene}-completed-no-note`);
    await session.driver.pressBack();
    await session.waitId('roaming-home');
    expect(await (await visible(session, 'roaming-home', ON.id('roam-home-progress'))).getText()).assertEqual('3 / 3 线索');
    console.info(`ROAMING_CITY_RESULT:${JSON.stringify({ chapterId: chapter.id, city: chapter.city,
      completedClues: 3, activeNotes: 0, activeFavorites: 0, elapsedMs: Date.now() - started })}`);
  });
}

export default function roamingTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requested = parameters['class'] || parameters['-s class'] || '';
  if (!requested.includes('RoamingTest')) return;
  describe('RoamingTest', () => {
    it('native_guest_five_city_entries_do_not_auto_complete', 0, async () => {
      const session = new RoamingUiSession('roaming_entries');
      await session.run(async () => {
        const initial = await session.read();
        expect(initial.records.length).assertEqual(0);
        await capture('native-first-home');
        for (const chapter of ROAM_CHAPTERS) {
          await selectChapter(session, chapter);
          // 篇章页面只承担进入与阅读；真实通关要由下一用例操作场景完成。
          await session.waitId('roaming-chapter-page');
          expect(await (await visible(session, 'roam-chapter-scroll', ON.id('roam-current-goal'))).getText())
            .assertEqual(chapter.clues[0].goal);
          expect(roamProgress((await session.read()).records, chapter).completedCount).assertEqual(0);
          expect(activeRecords((await session.read()).records, 'note').length).assertEqual(0);
          await capture(`entry-${chapter.scene}`);
          await session.driver.pressBack();
          await session.waitId('roaming-home');
          expect(await (await visible(session, 'roaming-home', ON.id('roam-home-chapter-title'))).getText())
            .assertEqual(chapter.title);
        }
        const finalSnapshot = await session.read();
        for (const chapter of ROAM_CHAPTERS) expect(roamProgress(finalSnapshot.records, chapter).completedCount).assertEqual(0);
        expect(activeRecords(finalSnapshot.records, 'note').length).assertEqual(0);
        console.info(`ROAMING_ENTRIES_RESULT:${JSON.stringify({ cityCount: 5, completedClues: 0,
          activeNotes: 0, recordCount: finalSnapshot.records.length })}`);
      });
    });

    it('kaifeng_real_three_clues_memory_crud_and_plain_note_preserved', 0, async () => {
      const session = new RoamingUiSession('roaming_kaifeng_memory');
      const started = Date.now();
      await session.run(async () => {
        const baselines = await writePlainBaseline(session);
        const oldNote = baselines.find(record => record.kind === 'note');
        if (!oldNote) throw new Error('ROAMING_PLAIN_BASELINE_MISSING');
        const gameRecords = await completeKaifeng(session, baselines);
        const chapter = chapterFor('开封');
        const clue = chapter.clues[2];

        await click(session, 'roam-chapter-scroll', 'roam-read-story');
        const materialScroll = await readingScroll(session);
        expect(await (await visible(session, materialScroll, ON.id('roam-reading-paragraph-0'))).getText())
          .assertEqual(clue.body);
        await click(session, materialScroll, 'roam-sources');
        await visible(session, materialScroll, ON.id('roam-review-status'));
        await capture('kaifeng-offline-sources');
        const closeReading = await session.driver.findComponent(ON.id('roam-sheet-close'));
        if (closeReading) await closeReading.click();

        await click(session, 'roam-chapter-scroll', 'roam-write-memory');
        const draftScroll = await readingScroll(session, true);
        const body = '我想记住州桥上街与河的交会，也把这盏灯留给可亲的日常。';
        const revisedBody = '再读州桥的资料，我更想记住街河交会的关系，以及灯事里相聚的人。';
        expect(await (await visible(session, draftScroll, ON.id('roam-note-body'))).getText()).assertEqual('');
        expect(activeRecords((await session.read()).records, 'note').length).assertEqual(1);
        await (await visible(session, draftScroll, ON.id('roam-note-body'))).inputText(body);
        await (await visible(session, draftScroll, ON.id('roam-note-tags'))).inputText('开封，街河');
        await click(session, draftScroll, 'roam-save-note');
        await visible(session, draftScroll, ON.id('roam-open-memory'));
        const savedSnapshot = await session.read();
        const saved = activeRecords(savedSnapshot.records, 'note').find(record => record.id !== oldNote.id);
        if (!saved || !saved.roamingContext) throw new Error('ROAMING_MEMORY_NOT_PERSISTED');
        expect(activeRecords(savedSnapshot.records, 'note').length).assertEqual(2);
        expect(saved.body).assertEqual(body);
        expect(JSON.stringify(saved.tags)).assertEqual(JSON.stringify(['开封', '街河']));
        expect(saved.roamingContext.chapterId).assertEqual(chapter.id);
        expect(saved.roamingContext.clueId).assertEqual(clue.id);
        expect(saved.roamingContext.choiceId).assertEqual(clue.options[1].id);
        expect(saved.roamingContext.sceneRevision).assertEqual(1);
        expect(saved.roamingContext.sources.length).assertEqual(clue.sourceIds.length);
        expect(saved.snapshot3DPose === undefined && saved.aiAssist === undefined).assertTrue();
        assertPreserved(savedSnapshot.records, baselines.concat(gameRecords));
        const frozenContext = JSON.stringify(saved.roamingContext);
        await capture('kaifeng-memory-saved');

        // 保存后的入口进入真实个人长卷，再打开刚保存的记录；不能用临时正文组件替代全文。
        console.info('ROAMING_CORE_STEP:OPEN_PERSONAL_SCROLL');
        await click(session, draftScroll, 'roam-open-memory');
        await session.waitId('roam-personal-scroll');
        await (await session.waitId('roam-personal-scroll')).scrollToTop(40000);
        // 最近入口是真实的同一note路由，避免为点击开封记忆穿过前面四城的重复目录卡。
        await click(session, 'roam-personal-scroll', `roam-recent-note-${saved.id}`);
        await session.waitId('roam-memory-scroll');
        console.info('ROAMING_CORE_STEP:ENTERED_MEMORY_DETAIL');
        await (await session.waitId('roam-memory-scroll')).scrollToTop(40000);
        expect(await (await visible(session, 'roam-memory-scroll', ON.id('roam-memory-title'))).getText())
          .assertEqual(saved.roamingContext.title);
        expect(await (await visible(session, 'roam-memory-scroll', ON.id('roam-memory-body'))).getText()).assertEqual(body);
        await capture('kaifeng-memory-fulltext');

        console.info('ROAMING_CORE_STEP:EDIT_BEGIN');
        await click(session, 'roam-memory-scroll', 'roam-memory-edit');
        await (await visible(session, 'roam-memory-scroll', ON.id('roam-edit-body'))).inputText(revisedBody);
        await (await visible(session, 'roam-memory-scroll', ON.id('roam-edit-tags'))).inputText('开封，重读');
        await click(session, 'roam-memory-scroll', 'roam-edit-save');
        await visible(session, 'roam-memory-scroll', ON.id('roam-memory-body').text(revisedBody));
        const editedSnapshot = await session.read();
        const edited = editedSnapshot.records.find(record => record.id === saved.id);
        if (!edited) throw new Error('ROAMING_EDITED_MEMORY_MISSING');
        expect(edited.body).assertEqual(revisedBody);
        expect(JSON.stringify(edited.tags)).assertEqual(JSON.stringify(['开封', '重读']));
        expect(edited.updatedAt > saved.updatedAt).assertTrue();
        expect(JSON.stringify(edited.roamingContext)).assertEqual(frozenContext);
        assertPreserved(editedSnapshot.records, baselines.concat(gameRecords));
        console.info('ROAMING_CORE_STEP:EDIT_SAVED');
        await capture('kaifeng-memory-edited');

        console.info('ROAMING_CORE_STEP:DELETE_BEGIN');
        await (await session.waitId('roam-memory-scroll')).scrollToBottom(40000);
        await click(session, 'roam-memory-scroll', 'roam-memory-delete');
        await session.waitText('删除这页记忆？');
        console.info('ROAMING_CORE_STEP:DELETE_DIALOG');
        await (await session.waitText('删除')).click();
        await session.waitId('roam-personal-scroll');
        const finalSnapshot = await session.read();
        const tombstone = finalSnapshot.records.find(record => record.id === saved.id);
        if (!tombstone) throw new Error('ROAMING_MEMORY_TOMBSTONE_MISSING');
        expect(tombstone.deleted).assertTrue();
        expect(tombstone.body).assertEqual(revisedBody);
        expect(tombstone.updatedAt > edited.updatedAt).assertTrue();
        expect(JSON.stringify(tombstone.roamingContext)).assertEqual(frozenContext);
        expect(activeRecords(finalSnapshot.records, 'note').length).assertEqual(1);
        assertPreserved(finalSnapshot.records, baselines.concat(gameRecords));
        expect(roamProgress(finalSnapshot.records, chapter).completed).assertTrue();
        console.info('ROAMING_CORE_STEP:DELETE_COMMITTED');
        await (await session.waitId('roam-personal-scroll')).scrollToTop(40000);
        expect(!await session.driver.findComponent(ON.id(`roam-scroll-note-${saved.id}`))).assertTrue();
        expect(!await session.driver.findComponent(ON.id(`roam-recent-note-${saved.id}`))).assertTrue();
        await visible(session, 'roam-personal-scroll', ON.id(`roam-recent-note-${oldNote.id}`));
        expect(await (await visible(session, 'roam-personal-scroll',
          ON.text(oldNote.body).within(ON.id(`roam-recent-note-${oldNote.id}`)))).getText()).assertEqual(oldNote.body);
        await capture('kaifeng-tombstone-preserves-plain-memory');
        console.info(`ROAMING_CORE_RESULT:${JSON.stringify({ chapterId: chapter.id, completedClues: 3,
          noteId: saved.id, tombstone: true, oldNoteId: oldNote.id, oldRecordCount: baselines.length,
          frozenContextPreserved: true, elapsedMs: Date.now() - started })}`);
      });
    });

    it('sanmenxia_real_hotspots_pit_house_and_paper_cut', 0, async () => {
      await completeOfflineCity('三门峡', 'roaming_sanmenxia');
    });

    it('luoyang_real_window_poem_and_water_banquet', 0, async () => {
      await completeOfflineCity('洛阳', 'roaming_luoyang');
    });

    it('zhengzhou_real_gate_poem_and_meeting', 0, async () => {
      await completeOfflineCity('郑州', 'roaming_zhengzhou');
    });

    it('puyang_real_shell_legend_and_fair', 0, async () => {
      await completeOfflineCity('濮阳', 'roaming_puyang');
    });
  });
}
