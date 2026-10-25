import { abilityDelegatorRegistry, Component, ON } from '@kit.TestKit';
import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { describe, expect, it } from '@ohos/hypium';
import { activeRecords, ArchiveRecord, compareVersions } from '../../../main/ets/domain/ArchiveDomain';
import { RoamChapter, RoamSource, roamProgress } from '../../../main/ets/domain/Roaming';
import { ROAM_CHAPTERS, ROAM_CONTENT_REVISION, ROAM_SOURCES } from '../../../main/ets/data/RoamingCatalog';
import { RoamingUiSession, visible, click, selectChapter, readingScroll } from './Roaming.test';

const EXCERPT_BODY: string = '在平板上把街与河的关系摘下来，转成竖屏后，我仍想保留这一次自己的理解。';
const EXCERPT_TAGS: string[] = ['平板摘录', '街河相遇'];
const KAIFENG_BODY: string = '开封的第一段记忆：街市沿着河流展开，我想记住桥连接两岸日常的关系。';
const LUOYANG_BODY: string = '洛阳的第一段记忆：站在河岸读两山与石窟，把这一页留给春日的山水。';

function chapterFor(id: string): RoamChapter {
  const chapter = ROAM_CHAPTERS.find(item => item.id === id);
  if (!chapter) throw new Error(`ROAMING_TABLET_CHAPTER_MISSING:${id}`);
  return chapter;
}

function defaultExcerpt(chapter: RoamChapter): string {
  const clue = chapter.clues[0];
  const option = clue.options[0];
  return `${clue.body}\n\n我选择：${option.label}。${option.detail}`;
}

async function capture(session: RoamingUiSession, phase: string): Promise<void> {
  // 本套件只进入独立游客库；若意外进入身份页，停止截图，避免把私人资料纳入演示证据。
  for (const id of ['login-scroll', 'profile-scroll', 'account-panel']) {
    if (await session.driver.findComponent(ON.id(id))) throw new Error('ROAMING_TABLET_PRIVATE_CAPTURE_DENIED');
  }
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  expect((await delegator.executeShellCommand(
    `uitest screenCap -p /data/local/tmp/roaming-tablet-${phase}.png`)).exitCode).assertEqual(0);
  expect((await delegator.executeShellCommand(
    `uitest dumpLayout -p /data/local/tmp/roaming-tablet-${phase}.json`)).exitCode).assertEqual(0);
}

function logNote(phase: string, note: ArchiveRecord): void {
  // 冻结出处使单条记忆超过一条 hilog 的长度；分片保留真实磁盘读回值，不能用截图替代落盘证据。
  const json = JSON.stringify(note);
  const count = Math.ceil(json.length / 700);
  for (let index = 0; index < count; index++) {
    console.info(`ROAMING_TABLET_NOTE:${phase}:${index + 1}/${count}:${json.slice(index * 700, (index + 1) * 700)}`);
  }
}

async function rotate(session: RoamingUiSession, appWindow: window.Window,
  orientation: window.Orientation, phase: string): Promise<void> {
  // 2026-10-23 按本机 API 26 声明调用真实主窗口。只改变系统方向偏好，
  // 不修改组件宽度、density 或页面状态；必须等 windowRect 实际转向后才继续核对响应式分支。
  await appWindow.setPreferredOrientation(orientation);
  let previous = '';
  let stable = 0;
  for (let attempt = 0; attempt < 40; attempt++) {
    const rect = appWindow.getWindowProperties().windowRect;
    const matches = orientation === window.Orientation.LANDSCAPE ? rect.width > rect.height : rect.height > rect.width;
    const current = `${rect.width}:${rect.height}`;
    stable = matches && current === previous ? stable + 1 : 0;
    if (stable >= 3) {
      expect(appWindow.getPreferredOrientation()).assertEqual(orientation);
      console.info(`ROAMING_TABLET_ORIENTATION:${phase}:${JSON.stringify(rect)}`);
      return;
    }
    previous = current;
    await session.driver.delayMs(200);
  }
  console.error(`ROAMING_TABLET_ORIENTATION_ACTUAL:${phase}:${JSON.stringify(appWindow.getWindowProperties().windowRect)}`);
  throw new Error(`ROAMING_TABLET_ORIENTATION_NOT_APPLIED:${phase}`);
}

async function runTablet(session: RoamingUiSession, phase: string,
  action: (appWindow: window.Window) => Promise<void>): Promise<void> {
  await session.run(async () => {
    const appWindow = await window.getLastWindow(session.context as common.UIAbilityContext);
    const original = appWindow.getPreferredOrientation();
    let actionFailed = false;
    try {
      expect((await session.read()).records.length).assertEqual(0);
      await action(appWindow);
    } catch (error) {
      actionFailed = true;
      try { await capture(session, `${phase}-failure`); }
      catch { console.error(`ROAMING_TABLET_FAILURE_CAPTURE_UNAVAILABLE:${phase}`); }
      throw new Error((error as Error).message);
    } finally {
      // 在 EntryAbility 仍存活时恢复原方向；失败截图先保留出错布局，再由公共 session 退出并清理测试库。
      try { await appWindow.setPreferredOrientation(original); }
      catch (error) {
        if (!actionFailed) throw new Error(`ROAMING_TABLET_ORIENTATION_RESTORE_FAILED:${(error as Error).message}`);
        console.error(`ROAMING_TABLET_ORIENTATION_RESTORE_FAILED:${(error as Error).message}`);
      }
    }
  });
}

async function sceneScroll(session: RoamingUiSession): Promise<string> {
  return await session.driver.findComponent(ON.id('roam-chapter-wide-scroll')) ?
    'roam-chapter-wide-scroll' : 'roam-chapter-scroll';
}

async function assertThreeColumns(session: RoamingUiSession): Promise<void> {
  console.info(`ROAMING_TABLET_CHAPTER_BOUNDS:${JSON.stringify(await (await session.waitId('roaming-chapter-page')).getBounds())}`);
  const scene = await (await session.waitId('roam-chapter-wide-scroll')).getBounds();
  const reading = await (await session.waitId('roam-reading-column')).getBounds();
  const writing = await (await session.waitId('roam-writing-column')).getBounds();
  expect(scene.right > scene.left && reading.right > reading.left && writing.right > writing.left).assertTrue();
  expect(scene.right <= reading.left + 8 && reading.right <= writing.left + 8).assertTrue();
  expect(!await session.driver.findComponent(ON.id('roam-sheet-scroll'))).assertTrue();
}

async function assertExposed(session: RoamingUiSession, scrollId: string, component: Component): Promise<void> {
  const viewport = await (await session.waitId(scrollId)).getBounds();
  const bounds = await component.getBounds();
  const x = (bounds.left + bounds.right) / 2;
  const y = (bounds.top + bounds.bottom) / 2;
  expect(bounds.right > bounds.left && bounds.bottom > bounds.top).assertTrue();
  expect(x > viewport.left && x < viewport.right && y > viewport.top + 12 && y < viewport.bottom - 12).assertTrue();
}

async function chooseFirst(session: RoamingUiSession, chapter: RoamChapter): Promise<void> {
  await selectChapter(session, chapter);
  await session.waitId('roaming-chapter-page');
  await assertThreeColumns(session);
  const scrollId = await sceneScroll(session);
  const clue = chapter.clues[0];
  await visible(session, scrollId, ON.id('roam-current-goal').text(clue.goal));
  // 选摘前先通过真实手势观察关系；只选择片段不会替代“船到桥下／山河进入景窗”的目标。
  // 此处不确认通关，后续仍断言进度为 0，避免把写一页记忆误记为完成探索。
  const slider = await visible(session, scrollId, ON.id('roam-slider'));
  const bounds = await slider.getBounds();
  const inset = Math.min((bounds.bottom - bounds.top) * 0.32, (bounds.right - bounds.left) * 0.15);
  const left = bounds.left + inset;
  const right = bounds.right - inset;
  const y = Math.round((bounds.top + bounds.bottom) / 2);
  const percent = chapter.scene === 'kf-night' ? 65 : 85;
  await session.driver.swipe(Math.round(left), y, Math.round(left + (right - left) * percent / 100), y, 600);
  await click(session, scrollId, `roam-choice-${clue.options[0].id}`);
  expect(await (await visible(session, scrollId, ON.id('roam-feedback'))).getText()).assertEqual(clue.options[0].detail);
  expect(roamProgress((await session.read()).records, chapter).completedCount).assertEqual(0);
}

function assertSources(actual: RoamSource[], chapter: RoamChapter): void {
  const ids = chapter.clues[0].sourceIds;
  expect(actual.length).assertEqual(ids.length);
  for (let index = 0; index < ids.length; index++) {
    const source = ROAM_SOURCES.find(item => item.id === ids[index]);
    if (!source) throw new Error(`ROAMING_TABLET_SOURCE_MISSING:${ids[index]}`);
    expect(actual[index].id).assertEqual(source.id);
    expect(actual[index].title).assertEqual(source.title);
    expect(actual[index].url).assertEqual(source.url);
    expect(actual[index].accessedAt).assertEqual(source.accessedAt);
  }
}

function assertNote(note: ArchiveRecord, chapter: RoamChapter, body: string, tags: string[], excerpt: string): void {
  const context = note.roamingContext;
  if (!context) throw new Error('ROAMING_TABLET_CONTEXT_MISSING');
  expect(note.kind).assertEqual('note');
  expect(note.deleted).assertFalse();
  expect(note.body).assertEqual(body);
  expect(JSON.stringify(note.tags)).assertEqual(JSON.stringify(tags));
  expect(note.snapshot3DPose === undefined && note.aiAssist === undefined).assertTrue();
  expect(context.version).assertEqual(1);
  expect(context.chapterId).assertEqual(chapter.id);
  expect(context.clueId).assertEqual(chapter.clues[0].id);
  expect(context.choiceId).assertEqual(chapter.clues[0].options[0].id);
  expect(context.sceneRevision).assertEqual(1);
  expect(context.contentRevision).assertEqual(ROAM_CONTENT_REVISION);
  expect(context.city).assertEqual(chapter.city);
  expect(context.title).assertEqual(`${chapter.title} · ${chapter.clues[0].title}`);
  expect(context.excerpt).assertEqual(excerpt);
  assertSources(context.sources, chapter);
}

async function assertDraft(session: RoamingUiSession, scrollId: string, body: string, tags: string[], excerpt: string): Promise<void> {
  expect(await (await visible(session, scrollId, ON.id('roam-note-body'))).getText()).assertEqual(body);
  expect(await (await visible(session, scrollId, ON.id('roam-note-tags'))).getText()).assertEqual(tags.join('，'));
  expect(await (await visible(session, scrollId, ON.id('roam-draft-excerpt'))).getText()).assertEqual(excerpt);
}

async function assertSavedButton(session: RoamingUiSession, scrollId: string): Promise<void> {
  await visible(session, scrollId, ON.id('roam-open-memory'));
  const button = await visible(session, scrollId, ON.id('roam-save-note'), false);
  expect(await button.getText()).assertEqual('这一页已保存');
  expect(await button.isEnabled()).assertFalse();
}

async function returnHome(session: RoamingUiSession): Promise<void> {
  await session.driver.pressBack();
  await session.waitId('roaming-home');
  expect(!await session.driver.findComponent(ON.id('roaming-chapter-page'))).assertTrue();
}

async function saveFirstMemory(session: RoamingUiSession, chapter: RoamChapter, body: string, tag: string): Promise<ArchiveRecord> {
  const before = await session.read();
  await chooseFirst(session, chapter);
  await click(session, await sceneScroll(session), 'roam-write-memory');
  const writing = await readingScroll(session, true);
  expect(await (await visible(session, writing, ON.id('roam-note-body'))).getText()).assertEqual('');
  expect(activeRecords((await session.read()).records, 'note').length).assertEqual(activeRecords(before.records, 'note').length);
  await (await visible(session, writing, ON.id('roam-note-body'))).inputText(body);
  // 平板软键盘会遮住长摘录下方的标签；先真实收起键盘，再在本列滚动定位下一项。
  await session.driver.pressBack();
  await (await visible(session, writing, ON.id('roam-note-tags'))).inputText(tag);
  await session.driver.pressBack();
  await click(session, writing, 'roam-save-note');
  await assertSavedButton(session, writing);
  const snapshot = await session.read();
  const notes = activeRecords(snapshot.records, 'note');
  expect(notes.length).assertEqual(activeRecords(before.records, 'note').length + 1);
  const note = notes.find(item => item.tags.includes(tag));
  if (!note) throw new Error(`ROAMING_TABLET_SAVED_NOTE_MISSING:${chapter.id}`);
  assertNote(note, chapter, body, [tag], defaultExcerpt(chapter));
  // 切换城市会按正式导航更新唯一的阅读位置检查点；只允许该项变化，旧记忆和其他数据必须保留原版本。
  for (const original of before.records.filter(item => item.id !== 'progress:roaming-position:v1')) {
    const retained = snapshot.records.find(item => item.id === original.id);
    if (!retained) throw new Error(`ROAMING_TABLET_PREVIOUS_RECORD_REMOVED:${original.id}`);
    expect(compareVersions(original, retained)).assertEqual(0);
  }
  expect(roamProgress(snapshot.records, chapter).completedCount).assertEqual(0);
  logNote(`directory-${chapter.scene}-saved`, note);
  await returnHome(session);
  return note;
}

async function assertMemoryDetail(session: RoamingUiSession, note: ArchiveRecord, phase: string): Promise<void> {
  const context = note.roamingContext;
  if (!context) throw new Error('ROAMING_TABLET_DETAIL_CONTEXT_MISSING');
  await (await session.waitId('roam-memory-scroll')).scrollToTop(40000);
  expect(await (await visible(session, 'roam-memory-scroll', ON.id('roam-memory-title'))).getText()).assertEqual(context.title);
  expect(await (await visible(session, 'roam-memory-scroll', ON.id('roam-memory-body'))).getText()).assertEqual(note.body);
  expect(await (await visible(session, 'roam-memory-scroll', ON.id('roam-memory-excerpt'))).getText()).assertEqual(context.excerpt);
  for (const source of context.sources) {
    await visible(session, 'roam-memory-scroll', ON.text(`${source.title}\n${source.url}`).within(ON.id('roam-memory-scroll')));
  }
  await capture(session, `${phase}-sources`);
  await (await session.waitId('roam-memory-scroll')).scrollToTop(40000);
  await visible(session, 'roam-memory-scroll', ON.id('roam-memory-body').text(note.body));
  await capture(session, phase);
}

async function assertDirectory(session: RoamingUiSession, note: ArchiveRecord): Promise<void> {
  await visible(session, 'archive-scroll', ON.text('已保存在本机').within(ON.id(`memory-card-${note.id}`)));
  const directory = await (await session.waitId('archive-scroll')).getBounds();
  const detail = await (await session.waitId('roam-memory-scroll')).getBounds();
  expect(directory.right > directory.left && detail.right > detail.left).assertTrue();
  expect(directory.left < detail.left && directory.right <= detail.left + 8).assertTrue();
}

export default function roamingTabletTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requested = parameters['class'] || parameters['-s class'] || '';
  if (!requested.includes('RoamingTabletTest')) return;
  describe('RoamingTabletTest', () => {
    it('native_excerpt_drag_survives_portrait_and_landscape_before_save', 0, async () => {
      const session = new RoamingUiSession('roaming_tablet_excerpt');
      await runTablet(session, 'excerpt', async (appWindow: window.Window) => {
        const chapter = chapterFor('roam-kf-night');
        const clue = chapter.clues[0];
        const excerpt = `${clue.body}\n${clue.options[0].detail}`;
        await rotate(session, appWindow, window.Orientation.LANDSCAPE, 'excerpt-landscape-start');
        await chooseFirst(session, chapter);
        const reading = await readingScroll(session);
        const paragraph = await visible(session, reading, ON.id('roam-reading-paragraph-0'));
        expect(await paragraph.getText()).assertEqual(clue.body);
        // 必须由 SelectionContainer 的系统菜单全选两个独立 Text；
        // 不使用“加入草稿”按钮、不调用业务方法，也不把领域层默认整段摘录当作跨段选区。
        await paragraph.longClick();
        await (await session.waitText('全选')).click();
        await (await session.waitText('做成摘录笺')).click();
        await visible(session, reading, ON.id('roam-excerpt-card'));
        expect(await (await session.wait(ON.text(excerpt).within(ON.id('roam-excerpt-card')))).getText()).assertEqual(excerpt);
        const writing = await readingScroll(session, true);
        expect(await (await visible(session, writing, ON.id('roam-draft-excerpt'))).getText()).assertEqual(defaultExcerpt(chapter));
        await visible(session, writing, ON.id('roam-draft-drop'));
        const source = await visible(session, reading, ON.id('roam-excerpt-card'));
        const target = await visible(session, writing, ON.id('roam-draft-drop'));
        await assertExposed(session, reading, source);
        await assertExposed(session, writing, target);
        await capture(session, 'excerpt-before-native-drag');
        console.info('ROAMING_TABLET_STEP:NATIVE_DRAG');
        await source.dragTo(target);
        expect(await (await visible(session, writing, ON.id('roam-draft-excerpt'))).getText()).assertEqual(excerpt);
        expect(activeRecords((await session.read()).records, 'note').length).assertEqual(0);
        await (await visible(session, writing, ON.id('roam-note-body'))).inputText(EXCERPT_BODY);
        await session.driver.pressBack();
        await (await visible(session, writing, ON.id('roam-note-tags'))).inputText(EXCERPT_TAGS.join('，'));
        await session.driver.pressBack();
        await capture(session, 'excerpt-landscape-draft');

        await rotate(session, appWindow, window.Orientation.PORTRAIT, 'excerpt-portrait');
        await session.waitId('roam-chapter-scroll');
        expect(await (await visible(session, 'roam-chapter-scroll', ON.id('roam-feedback'))).getText()).assertEqual(clue.options[0].detail);
        await click(session, 'roam-chapter-scroll', 'roam-write-memory');
        await session.waitId('roam-sheet-writing');
        await assertDraft(session, 'roam-sheet-scroll', EXCERPT_BODY, EXCERPT_TAGS, excerpt);
        expect(activeRecords((await session.read()).records, 'note').length).assertEqual(0);
        await capture(session, 'excerpt-portrait-writing-sheet');

        await rotate(session, appWindow, window.Orientation.LANDSCAPE, 'excerpt-landscape-return');
        await assertThreeColumns(session);
        await assertDraft(session, 'roam-writing-column', EXCERPT_BODY, EXCERPT_TAGS, excerpt);
        expect(await (await visible(session, await sceneScroll(session), ON.id('roam-feedback'))).getText()).assertEqual(clue.options[0].detail);
        await capture(session, 'excerpt-landscape-restored-draft');
        await click(session, 'roam-writing-column', 'roam-save-note');
        await assertSavedButton(session, 'roam-writing-column');
        const saved = await session.read();
        const notes = activeRecords(saved.records, 'note');
        expect(notes.length).assertEqual(1);
        assertNote(notes[0], chapter, EXCERPT_BODY, EXCERPT_TAGS, excerpt);
        expect(roamProgress(saved.records, chapter).completedCount).assertEqual(0);
        logNote('excerpt-final-disk', notes[0]);
        await capture(session, 'excerpt-landscape-saved');
        expect(compareVersions(notes[0], activeRecords((await session.read()).records, 'note')[0])).assertEqual(0);
        console.info(`ROAMING_TABLET_RESULT:excerpt:${JSON.stringify({ store: session.name,
          noteId: notes[0].id, excerpt: 'native-selection-two-texts', drag: 'Component.dragTo', rotations: 2, activeNotes: 1 })}`);
      });
    });

    it('native_memory_directory_keeps_selected_note_after_orientation_changes', 0, async () => {
      const session = new RoamingUiSession('roaming_tablet_directory');
      await runTablet(session, 'directory', async (appWindow: window.Window) => {
        await rotate(session, appWindow, window.Orientation.LANDSCAPE, 'directory-landscape-start');
        const kaifeng = await saveFirstMemory(session, chapterFor('roam-kf-night'), KAIFENG_BODY, '平板开封');
        const luoyang = await saveFirstMemory(session, chapterFor('roam-ly-spring'), LUOYANG_BODY, '平板洛阳');
        const baseline = await session.read();
        expect(activeRecords(baseline.records, 'note').length).assertEqual(2);
        await (await session.waitId('tab-2')).click();
        await session.waitId('archive-scroll');
        // 目录按钮一直留在系统 Navigation 的真实左栏。两次均点击对应记录，
        // 旋转回横屏后不再重选洛阳，借详情正文证明原选择由路由和状态自然保留。
        await click(session, 'archive-scroll', `memory-open-${kaifeng.id}`);
        await assertDirectory(session, kaifeng);
        await assertMemoryDetail(session, kaifeng, 'directory-kaifeng-selected');
        await click(session, 'archive-scroll', `memory-open-${luoyang.id}`);
        await assertDirectory(session, luoyang);
        await assertMemoryDetail(session, luoyang, 'directory-luoyang-selected');

        await rotate(session, appWindow, window.Orientation.PORTRAIT, 'directory-portrait');
        await assertMemoryDetail(session, luoyang, 'directory-portrait-luoyang-retained');
        await rotate(session, appWindow, window.Orientation.LANDSCAPE, 'directory-landscape-return');
        await assertDirectory(session, luoyang);
        await assertMemoryDetail(session, luoyang, 'directory-landscape-luoyang-retained');
        const afterReading = await session.read();
        expect(JSON.stringify(afterReading.records)).assertEqual(JSON.stringify(baseline.records));
        for (const original of [kaifeng, luoyang]) {
          const retained = activeRecords(afterReading.records, 'note').find(item => item.id === original.id);
          if (!retained) throw new Error(`ROAMING_TABLET_DIRECTORY_NOTE_REMOVED:${original.id}`);
          expect(compareVersions(original, retained)).assertEqual(0);
          expect(JSON.stringify(retained.roamingContext)).assertEqual(JSON.stringify(original.roamingContext));
          logNote('directory-final-disk', retained);
        }
        console.info(`ROAMING_TABLET_RESULT:directory:${JSON.stringify({ store: session.name,
          activeNotes: 2, selectedNoteId: luoyang.id, rotations: 2, recordsUnchanged: true })}`);
      });
    });
  });
}
