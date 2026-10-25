import { abilityDelegatorRegistry, Component, ON, On } from '@kit.TestKit';
import { common, UIAbility } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { window } from '@kit.ArkUI';
import { describe, expect, it } from '@ohos/hypium';
import { ArchiveRecord, ArchiveSnapshot, activeRecords, compareVersions, parseSnapshot } from '../../../main/ets/domain/ArchiveDomain';
import { PAPER_COLUMNS, PAPER_ROWS, createPaperWork } from '../../../main/ets/domain/PaperJourney';
import { paperWorkFromRecords } from '../../../main/ets/domain/PaperJourneyRecords';
import { PAPER_CITIES, PaperCity } from '../../../main/ets/data/PaperJourneyCatalog';
import { LocalArchiveRepository } from '../../../main/ets/data/LocalArchiveRepository';
import { ArchiveUiSession } from './ArchiveUiSession';

const BODY: string = '我把选中的材料拖进草稿，再写下自己的想法：院子里的空与周围留下的墙，要放在一起看。';

function city(): PaperCity {
  const selected = PAPER_CITIES.find(item => item.id === 'paper-smx');
  if (!selected) throw new Error('PAPER_EXCERPT_CITY_MISSING');
  return selected;
}

function expectedSelection(): string {
  // SelectionContainer内只有每条材料的四个独立Text，NEWLINE按它们的阅读顺序相接。
  // createExcerpt上限是1800；测试比较真实全选的固定结果，不把测试造的字符串回灌页面。
  const paragraphs: string[] = [];
  for (const source of city().sources) paragraphs.push(source.title, source.era, source.quote, source.url);
  return paragraphs.join('\n').trim().slice(0, 1800);
}

class PaperExcerptUiSession extends ArchiveUiSession {
  private paperAbility: UIAbility | undefined = undefined;

  constructor() { super('paper_native_excerpt'); }

  async start(_resumeAccount: boolean = false): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator();
    await delegator.startAbility({ bundleName: 'com.yunheji.archive', abilityName: 'EntryAbility',
      parameters: { yunhejiTestStore: this.name } });
    await this.waitId('paper-journey-home');
    this.paperAbility = await delegator.getCurrentTopAbility();
    expect(this.paperAbility.context.abilityInfo.name).assertEqual('EntryAbility');
    this.context = this.paperAbility.context;
    expect(!await this.driver.findComponent(ON.id('login-scroll'))).assertTrue();
    const store = await preferences.getPreferences(this.context, { name: this.name });
    expect(await store.has('snapshot')).assertTrue();
    console.info(`PAPER_EXCERPT_STORE:${this.name}`);
  }

  async stop(): Promise<void> {
    if (!this.paperAbility) return;
    await this.paperAbility.context.terminateSelf();
    this.paperAbility = undefined;
    await this.wait(ON.text('设备回归准备中'));
  }

  async raw(): Promise<string> {
    await preferences.removePreferencesFromCache(this.context, this.name);
    const store = await preferences.getPreferences(this.context, { name: this.name });
    expect(await store.has('snapshot')).assertTrue();
    return await store.get('snapshot', '') as string;
  }

  async read(): Promise<ArchiveSnapshot> {
    const raw = await this.raw();
    const disk = await new LocalArchiveRepository(this.context, this.name).load();
    expect(JSON.stringify(parseSnapshot(raw))).assertEqual(JSON.stringify(disk));
    return disk;
  }
}

async function exposed(session: PaperExcerptUiSession, scrollId: string, target: On): Promise<Component> {
  // 只在对应Scroll的真实安全视口中线滑动。根页扣除HDS标题/Dock，Sheet只认显式id，
  // 不能让scrollSearch从浮动栏上起手，也不能把草稿查询误投到后方仍存活的资料Scroll。
  for (let attempt = 0; attempt < 18; attempt++) {
    const viewport = await (await session.waitId(scrollId)).getBounds();
    let top = viewport.top + 28;
    let bottom = viewport.bottom - 32;
    if (scrollId === 'paper-journey-home' || scrollId === 'paper-memory') {
      top = Math.max(top, (await (await session.waitId('top-navigation-content')).getBounds()).bottom + 28);
      bottom = Math.min(bottom, (await (await session.waitId('tab-0')).getBounds()).top - 32);
    }
    if (viewport.right <= viewport.left || bottom - top < 160) throw new Error(`PAPER_EXCERPT_NO_SAFE_SCROLL_RECT:${scrollId}`);
    let lower = attempt < 8;
    let distance = (bottom - top) * 0.42;
    const component = await session.driver.findComponent(target);
    if (component) {
      const bounds = await component.getBounds();
      if (bounds.right > bounds.left && bounds.bottom > bounds.top) {
        const center = (bounds.top + bounds.bottom) / 2;
        if (center >= top && center <= bottom) {
          const stable = await session.wait(target, scrollId);
          const current = await stable.getBounds();
          const currentCenter = (current.top + current.bottom) / 2;
          if (current.bottom > current.top && currentCenter >= top && currentCenter <= bottom) return stable;
          continue;
        }
        lower = center > bottom;
        distance = Math.min(distance, Math.max(90, lower ? center - bottom + 50 : top - center + 50));
      }
    }
    const x = Math.round((viewport.left + viewport.right) / 2);
    const start = lower ? bottom - (bottom - top) * 0.15 : top + (bottom - top) * 0.15;
    const end = start + (lower ? -distance : distance);
    console.info(`PAPER_EXCERPT_SAFE_SCROLL:${JSON.stringify({ scrollId, attempt, viewport, top, bottom, x, start, end })}`);
    await session.driver.swipe(x, Math.round(start), x, Math.round(end), 600);
    await session.driver.delayMs(180);
  }
  throw new Error(`PAPER_EXCERPT_TARGET_NOT_EXPOSED:${scrollId}`);
}

async function makeOneCut(session: PaperExcerptUiSession): Promise<string> {
  const canvas = await session.wait(ON.id('paper-journey-scene').within(ON.id('paper-play-scene')));
  const bounds = await canvas.getBounds();
  const width = bounds.right - bounds.left;
  const height = bounds.bottom - bounds.top;
  const unit = Math.min(width / 1000, height / 1200);
  expect(unit > 0).assertTrue();
  const left = bounds.left + (width - unit * 1000) / 2;
  const top = bounds.top + (height - unit * 1200) / 2;
  const y = Math.round(top + (105 + 23.5 / PAPER_ROWS * 936) * unit);
  await session.driver.swipe(Math.round(left + (110 + 17.5 / PAPER_COLUMNS * 780) * unit), y,
    Math.round(left + (110 + 23.5 / PAPER_COLUMNS * 780) * unit), y, 350);
  const emptyMask = createPaperWork(city().id, 0).mask;
  for (let attempt = 0; attempt < 60; attempt++) {
    const work = paperWorkFromRecords((await session.read()).records, city().id);
    if (work && work.mask !== emptyMask) return work.mask;
    await session.driver.delayMs(150);
  }
  throw new Error('PAPER_EXCERPT_REAL_CUT_NOT_SAVED');
}

async function sheetTarget(session: PaperExcerptUiSession, target: On): Promise<Component> {
  await session.waitId('paper-sheet-close');
  return exposed(session, 'paper-sheet-scroll', target.within(ON.id('paper-sheet-scroll')));
}

async function assertTogether(session: PaperExcerptUiSession, source: Component, target: Component): Promise<void> {
  const viewport = await (await session.waitId('paper-culture-column')).getBounds();
  const from = await source.getBounds();
  const to = await target.getBounds();
  if (from.right <= from.left || to.right <= to.left || from.top < viewport.top + 6 ||
    from.bottom > viewport.bottom - 6 || to.top < viewport.top + 6 || to.bottom > viewport.bottom - 6) {
    console.error(`PAPER_EXCERPT_DRAG_VIEWPORT:${JSON.stringify({ viewport, from, to })}`);
    throw new Error('PAPER_EXCERPT_DRAG_PAIR_NOT_SIMULTANEOUSLY_EXPOSED');
  }
}

async function capture(phase: string): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  expect((await delegator.executeShellCommand(`uitest screenCap -p /data/local/tmp/paper-excerpt-${phase}.png`)).exitCode).assertEqual(0);
  expect((await delegator.executeShellCommand(`uitest dumpLayout -p /data/local/tmp/paper-excerpt-${phase}.json`)).exitCode).assertEqual(0);
}

function logNote(note: ArchiveRecord): void {
  const json = JSON.stringify(note);
  const count = Math.ceil(json.length / 700);
  for (let index = 0; index < count; index++) console.info(`PAPER_EXCERPT_NOTE:${index + 1}/${count}:${json.slice(index * 700, (index + 1) * 700)}`);
}

async function runExcerptCase(session: PaperExcerptUiSession, action: () => Promise<void>): Promise<void> {
  let failed = false;
  try { await session.start(); await action(); }
  catch (error) {
    failed = true;
    if (error instanceof Error) {
      console.error(`PAPER_EXCERPT_CASE_ERROR:${error.message}\n${error.stack || ''}`);
      throw error;
    }
    throw new Error('PAPER_EXCERPT_NON_ERROR_FAILURE');
  } finally {
    try { await session.dispose(); }
    catch (error) {
      if (!failed) {
        if (error instanceof Error) throw error;
        throw new Error('PAPER_EXCERPT_NON_ERROR_CLEANUP_FAILURE');
      }
      console.error(`PAPER_EXCERPT_CLEANUP_AFTER_FAILURE:${(error as Error).message}`);
    }
  }
}

export default function paperExcerptTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requested = parameters['class'] || parameters['-s class'] || '';
  if (!requested.includes('PaperExcerptTest')) return;
  describe('PaperExcerptTest', () => {
    it('native_tablet_selection_udmf_drag_and_explicit_save_freeze_excerpt', 0, async () => {
      const session = new PaperExcerptUiSession();
      await runExcerptCase(session, async () => {
        expect((await session.read()).records.length).assertEqual(0);
        const mainWindow = await window.getLastWindow(session.context as common.UIAbilityContext);
        const originalOrientation = mainWindow.getPreferredOrientation();
        let excerptFailed = false;
        try {
          await mainWindow.setPreferredOrientation(window.Orientation.LANDSCAPE);
          let landscape = false;
          for (let attempt = 0; attempt < 40; attempt++) {
            const rect = mainWindow.getWindowProperties().windowRect;
            if (rect.width > rect.height) { landscape = true; break; }
            await session.driver.delayMs(150);
          }
          if (!landscape) throw new Error('PAPER_EXCERPT_REAL_LANDSCAPE_NOT_REACHED');
          await (await session.waitId('paper-journey-home')).scrollToTop(2000);
          await (await exposed(session, 'paper-journey-home', ON.id(`paper-home-city-${city().id}`))).click();
          await (await exposed(session, 'paper-journey-home', ON.id('paper-home-start'))).click();
          await session.waitId('paper-journey-page');
          // 只有真实宽屏分支才有同屏的资料栏与UDMF接收区。窄屏缺少时明确失败，不改density/组件宽度造平板。
          await session.waitId('paper-culture-column');
          console.info('PAPER_EXCERPT_STEP:WIDE_CULTURE_VISIBLE');
          const originalMask = await makeOneCut(session);
          console.info('PAPER_EXCERPT_STEP:REAL_CUT_SAVED');
          const beforeDraft = await session.raw();
          await (await session.waitId('paper-culture-column')).scrollToTop(2000);
          const paragraph = await exposed(session, 'paper-culture-column',
            ON.text(city().sources[0].quote).within(ON.id('paper-selection-reading')));
          console.info('PAPER_EXCERPT_STEP:SELECTION_BEGIN');
          await paragraph.longClick();
          await (await session.waitText('全选')).click();
          console.info('PAPER_EXCERPT_STEP:ALL_TEXTS_SELECTED');
          await (await session.waitText('做成摘录')).click();
          const selected = expectedSelection();
          await exposed(session, 'paper-culture-column', ON.id('paper-excerpt-card'));
          expect(await (await session.wait(ON.text(selected).within(ON.id('paper-excerpt-card')))).getText()).assertEqual(selected);
          console.info('PAPER_EXCERPT_STEP:FULL_EXCERPT_CARD_CONFIRMED');
          const emptyDrop = await exposed(session, 'paper-culture-column', ON.id('paper-wide-excerpt-value'));
          expect(await emptyDrop.getText()).assertEqual('把上面的摘录卡拖到这里');
          const source = await session.waitId('paper-excerpt-card');
          const target = await session.waitId('paper-wide-excerpt-drop');
          await assertTogether(session, source, target);
          await capture('before-system-drag');
          // 真正触发draggable/onDragStart→UnifiedData→onDrop；不点paper-excerpt-add，不生成测试UDMF替身。
          console.info('PAPER_EXCERPT_STEP:UDMF_DRAG_BEGIN');
          await source.dragTo(target);
          expect(await (await session.waitId('paper-wide-excerpt-value')).getText()).assertEqual(selected);
          expect(await (await session.waitId('paper-feedback')).getText()).assertEqual('摘录已放进记忆草稿，还要由你确认保存。');
          expect(await session.raw()).assertEqual(beforeDraft);
          expect(activeRecords((await session.read()).records, 'note').length).assertEqual(0);
          console.info('PAPER_EXCERPT_STEP:UDMF_DRAFT_CONFIRMED_NO_NOTE');
          await capture('draft-after-system-drag');

          await (await session.waitId('paper-keep')).click();
          await session.waitId('paper-sheet-scroll');
          console.info('PAPER_EXCERPT_STEP:MEMORY_SHEET_VISIBLE');
          expect(await (await session.wait(ON.text(selected).within(ON.id('paper-excerpt-drop')))).getText()).assertEqual(selected);
          await (await sheetTarget(session, ON.id('paper-memory-body'))).inputText(BODY);
          expect(await (await session.waitId('paper-memory-body')).getText()).assertEqual(BODY);
          console.info('PAPER_EXCERPT_STEP:BODY_INPUT_CONFIRMED');
          await session.driver.pressBack();
          await (await sheetTarget(session, ON.id('paper-memory-save'))).click();
          console.info('PAPER_EXCERPT_STEP:EXPLICIT_SAVE_CLICKED');
          let saved: ArchiveRecord | undefined = undefined;
          for (let attempt = 0; attempt < 60; attempt++) {
            saved = activeRecords((await session.read()).records, 'note').find(note => note.body === BODY);
            if (saved) break;
            await session.driver.delayMs(150);
          }
          if (!saved || !saved.paperContext) throw new Error('PAPER_EXCERPT_UI_SAVED_NOTE_MISSING');
          expect(saved.paperContext.excerpt).assertEqual(selected);
          expect(saved.paperContext.work.mask).assertEqual(originalMask);
          expect(saved.paperContext.work.history.length).assertEqual(0);
          expect(JSON.stringify(saved.paperContext.sources)).assertEqual(JSON.stringify(city().sources));
          expect(saved.body).assertEqual(BODY);
          expect(saved.roamingContext === undefined && saved.snapshot3DPose === undefined && saved.aiAssist === undefined).assertTrue();
          const frozenNote = JSON.stringify(saved);
          const savedNoteId = saved.id;
          logNote(saved);
          console.info('PAPER_EXCERPT_STEP:FULL_EXCERPT_FROZEN_ON_DISK');
          await (await session.waitId('paper-back')).click();
          await (await session.waitId('tab-2')).click();
          await (await exposed(session, 'paper-memory', ON.id(`memory-open-${saved.id}`))).click();
          await session.waitId('paper-memory-page');
          const excerpt = await exposed(session, 'paper-memory-page', ON.id('paper-note-excerpt'));
          expect(await excerpt.getText()).assertEqual(`「${selected}」`);
          const reopened = (await session.read()).records.find(note => note.id === savedNoteId);
          if (!reopened) throw new Error('PAPER_EXCERPT_FROZEN_NOTE_MISSING');
          expect(JSON.stringify(reopened)).assertEqual(frozenNote);
          expect(compareVersions(saved, reopened)).assertEqual(0);
          await capture('saved-frozen-excerpt');
          console.info(`PAPER_EXCERPT_RESULT:${JSON.stringify({ cityId: city().id, noteId: saved.id,
            selection: 'SelectionContainer-all-native-texts', drag: 'Component.dragTo-UDMF', excerptLength: selected.length,
            sources: saved.paperContext.sources.length, draftDidNotSave: true, explicitSaveFrozen: true,
            sourceSnapshotPreserved: true, maskPreserved: true, oldContextsNotFabricated: true })}`);
        } catch (error) {
          excerptFailed = true;
          // 选摘全程只在独立游客库。失败画面先于方向恢复保留，防止“恢复成功”遮掉实际出错布局。
          try { await capture('failure'); }
          catch (captureError) { console.error(`PAPER_EXCERPT_FAILURE_CAPTURE:${(captureError as Error).message}`); }
          throw error as Error;
        } finally {
          try { await mainWindow.setPreferredOrientation(originalOrientation); }
          catch (restoreError) {
            if (!excerptFailed) throw restoreError as Error;
            console.error(`PAPER_EXCERPT_RESTORE_AFTER_FAILURE:${(restoreError as Error).message}`);
          }
        }
      });
    });
  });
}
