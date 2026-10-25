import { abilityDelegatorRegistry, ON } from '@kit.TestKit';
import { describe, expect, it } from '@ohos/hypium';
import { activeRecords, ArchiveRecord, compareVersions } from '../../../main/ets/domain/ArchiveDomain';
import { HERITAGE_SITES } from '../../../main/ets/data/HeritageCatalog';
import { decodeExplorationProgress, explorationProgressRecordId } from '../../../main/ets/domain/ExplorationProgress';
import { materialObservationForSite } from '../../../main/ets/domain/MaterialObservation';
import { buildJourneyScroll } from '../../../main/ets/domain/JourneyScroll';
import { ArchiveUiSession } from './ArchiveUiSession';

const TWIN_SITE: string = 'zz-dahecun';
const DING_SITE: string = 'zz-duling-fangding';
const TOPIC: string = '泥火观察';
const REVISED_TOPIC: string = '青铜折角';
const TWIN_BODY: string = '我沿浅绿色通道辨认两腹之间的椭圆通口，记下双连壶内部相通的位置。';
const DING_BODY: string = '我先看方鼎壁面正中，再转向四个折角，把两处纹饰的位置分开观察。';

interface PreparedJourney {
  twin: ArchiveRecord;
  ding: ArchiveRecord;
  favorite: ArchiveRecord;
  section: ArchiveRecord;
}

interface JourneyNoteVersionLog {
  id: string;
  siteId: string;
  tags: string[];
  updatedAt: number;
}

interface JourneyRecordVersionLog { id: string; updatedAt: number; }

function journeyStoreName(allowLegacyCleanup: boolean = false): string {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const name = parameters['archiveJourneyStore'] || parameters['-s archiveJourneyStore'] || '';
  // 多个 Hypium 进程必须由宿主明确传同一个独立库；缺参数时直接失败，不能回落正式库或临时新库。
  if (!/^yunheji_test_ui_(?:journey_[a-z0-9_]{1,60}|[0-9]+_journey_scroll_main)$/.test(name)) {
    throw new Error('JOURNEY_SCROLL_STORE_REQUIRED');
  }
  // 旧格式只为清理本轮已确认的整段超时库；新阶段不可把残留记录当作本次 UI 准备结果。
  if (!allowLegacyCleanup && /^yunheji_test_ui_[0-9]+_journey_scroll_main$/.test(name)) {
    throw new Error('JOURNEY_SCROLL_LEGACY_STORE_CLEANUP_ONLY');
  }
  return name;
}

async function runJourneyPhase(phase: string, action: (session: ArchiveUiSession) => Promise<void>): Promise<void> {
  const session = new ArchiveUiSession(`journey_${phase}`, journeyStoreName());
  const started = Date.now();
  console.info(`JOURNEY_SCROLL_PHASE_BEGIN:${phase}:${session.name}`);
  try {
    // run 调用 start(false)，仍经真实登录页的“离线浏览”打开原 Preferences。
    // preserveStore=true 只结束窗口，不 dispose；后续阶段及失败复跑都保留原 note，最后单独清理。
    await session.run(async () => {
      console.info(`JOURNEY_SCROLL_PHASE_READY:${phase}:OFFLINE_EXISTING_STORE`);
      await action(session);
    }, true);
    console.info(`JOURNEY_SCROLL_PHASE_DONE:${phase}:${Date.now() - started}`);
  } catch (error) {
    console.error(`JOURNEY_SCROLL_PHASE_FAILED:${phase}:${Date.now() - started}:${(error as Error).message}`);
    throw new Error((error as Error).message);
  }
}

async function click(session: ArchiveUiSession, scrollId: string, id: string): Promise<void> {
  // 详情沿用已经验证过的页首 / 页尾锚点搜索，其余页面使用原生 Scroll 查找。
  // 不另建猜测滚动方向的通用助手；错误须同时保留具体目标与原始定位信息。
  console.info(`JOURNEY_SCROLL_STEP:click:${scrollId}:${id}`);
  try { await (await session.inScroll(scrollId, ON.id(id))).click(); }
  catch (error) { throw new Error(`JOURNEY_SCROLL_CLICK:${scrollId}:${id}:${(error as Error).message}`); }
}

async function capture(name: string): Promise<void> {
  // 所有阶段均从真实“离线浏览”进入独立测试库，不登录、不请求模型，画面不含账号。
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  expect((await delegator.executeShellCommand(`uitest screenCap -p /data/local/tmp/journey-scroll-${name}.png`))
    .exitCode).assertEqual(0);
  expect((await delegator.executeShellCommand(`uitest dumpLayout -p /data/local/tmp/journey-scroll-${name}.json`))
    .exitCode).assertEqual(0);
}

function assertObservationNote(note: ArchiveRecord, siteId: string, hotspotId: string, body: string,
  expectedTopic: string = TOPIC): void {
  const observation = materialObservationForSite(siteId);
  if (!observation || !note.snapshot3DPose) throw new Error(`JOURNEY_SCROLL_SAVED_POSE_MISSING:${siteId}`);
  expect(note.siteId).assertEqual(siteId);
  expect(note.body).assertEqual(body);
  expect(note.tags.join('|')).assertEqual(expectedTopic);
  expect(note.aiAssist === undefined).assertTrue();
  expect(note.deleted).assertFalse();
  expect(note.snapshot3DPose.sceneType).assertEqual('relic_inspector');
  expect(note.snapshot3DPose.hotspotId).assertEqual(hotspotId);
  expect(note.snapshot3DPose.proceduralPreset).assertEqual(observation.proceduralPreset);
  expect(note.snapshot3DPose.sceneRevision).assertEqual(2);
  expect(note.snapshot3DPose.rendererProfile).assertEqual('native-raster-v1');
  expect((note.snapshot3DPose.viewFrame?.width || 0) > 24).assertTrue();
  expect((note.snapshot3DPose.viewFrame?.height || 0) > 46).assertTrue();
}

async function preparedJourney(session: ArchiveUiSession, allowRevisedDing: boolean = false): Promise<PreparedJourney> {
  // 阶段之间只从清缓存后的原磁盘快照定位真实 UI 已保存的记录，不写 fixture、不注入或复制 note。
  const snapshot = await session.read();
  const originalDing = snapshot.records.find(note => note.kind === 'note' && note.siteId === DING_SITE && note.body === DING_BODY);
  if (originalDing?.deleted) {
    console.error(`JOURNEY_SCROLL_DING_ALREADY_DELETED:${originalDing.id}`);
    throw new Error('JOURNEY_SCROLL_DING_ALREADY_DELETED:NO_RECREATE');
  }
  const notes = activeRecords(snapshot.records, 'note');
  expect(notes.length).assertEqual(2);
  const twin = notes.find(note => note.siteId === TWIN_SITE && note.body === TWIN_BODY);
  const ding = notes.find(note => note.siteId === DING_SITE && note.body === DING_BODY);
  const favorite = activeRecords(snapshot.records, 'favorite').find(record => record.siteId === DING_SITE);
  const section = snapshot.records.find(record => record.id === explorationProgressRecordId(DING_SITE, 'overview'));
  if (!twin || !ding || !favorite || !section || section.deleted) throw new Error('JOURNEY_SCROLL_PREPARED_RECORDS_MISSING');
  assertObservationNote(twin, TWIN_SITE, 'opening', TWIN_BODY);
  const dingTopic = ding.tags.join('|');
  if (allowRevisedDing) expect(dingTopic === TOPIC || dingTopic === REVISED_TOPIC).assertTrue();
  assertObservationNote(ding, DING_SITE, 'corners', DING_BODY, allowRevisedDing ? dingTopic : TOPIC);
  expect(decodeExplorationProgress(snapshot.records, DING_SITE).completedSectionIds.join('|')).assertEqual('overview');
  const model = buildJourneyScroll(HERITAGE_SITES, snapshot.records);
  expect(model.noteCount).assertEqual(2);
  expect(model.personalSiteCount).assertEqual(2);
  expect(model.groups.length).assertEqual(1);
  expect(model.groups[0].city).assertEqual('郑州');
  expect(model.groups[0].entries.length).assertEqual(2);
  expect(model.progress.completedCount).assertEqual(2);
  const noteVersions: JourneyNoteVersionLog[] = [twin, ding].map((note: ArchiveRecord): JourneyNoteVersionLog =>
    ({ id: note.id, siteId: note.siteId, tags: note.tags, updatedAt: note.updatedAt }));
  const favoriteVersion: JourneyRecordVersionLog = { id: favorite.id, updatedAt: favorite.updatedAt };
  const sectionVersion: JourneyRecordVersionLog = { id: section.id, updatedAt: section.updatedAt };
  console.info(`JOURNEY_SCROLL_PREPARED_RECORDS:${JSON.stringify({ notes: noteVersions,
    favorite: favoriteVersion, section: sectionVersion })}`);
  return { twin, ding, favorite, section };
}

async function editTopicThroughEditor(session: ArchiveUiSession, original: ArchiveRecord,
  nextTopic: string): Promise<ArchiveRecord> {
  // 方鼎是本例单城的最后一篇，直接滚到真实页尾露出 read；不从 hero 逐屏搜索整张长卷。
  console.info(`JOURNEY_SCROLL_STEP:edit:READ_FROM_BOTTOM:${original.id}:${nextTopic}`);
  await (await session.waitId('journey-scroll')).scrollToBottom(40000);
  await click(session, 'journey-scroll', `journey-read-${original.id}`);
  await session.waitId('memory-detail-scroll');
  expect(await (await session.inScroll('memory-detail-scroll', ON.id('memory-detail-body'))).getText())
    .assertEqual(DING_BODY);
  await (await session.waitId('memory-detail-scroll')).scrollToBottom(40000);
  await click(session, 'memory-detail-scroll', 'memory-detail-edit');
  await session.waitId('note-editor-scroll');
  const tags = await session.inScroll('note-editor-scroll', ON.id('note-tags'));
  await tags.clearText();
  await (await session.inScroll('note-editor-scroll', ON.id('note-tags')))
    .inputText(nextTopic, { paste: true, addition: true });
  await (await session.waitId('save-note')).click();
  await session.editorClosed();
  const edited = activeRecords((await session.read()).records, 'note').find(note => note.id === original.id);
  if (!edited) throw new Error('JOURNEY_SCROLL_EDITED_NOTE_MISSING');
  expect(edited.tags.join('|')).assertEqual(nextTopic);
  expect(edited.body).assertEqual(original.body);
  expect(JSON.stringify(edited.snapshot3DPose)).assertEqual(JSON.stringify(original.snapshot3DPose));
  expect(edited.stampType).assertEqual(original.stampType);
  expect(edited.paperTheme).assertEqual(original.paperTheme);
  expect(edited.quotedPoemOrFact).assertEqual(original.quotedPoemOrFact);
  expect(edited.updatedAt > original.updatedAt).assertTrue();
  console.info(`JOURNEY_SCROLL_STEP:edit:EDIT_PERSISTED:${JSON.stringify({ noteId: edited.id,
    tags: edited.tags, updatedAt: edited.updatedAt })}`);
  // 已知栈为长卷→全文→编辑档案；保存仅关闭 Sheet，按两层返回并逐层确认。
  await session.driver.pressBack();
  await session.waitId('memory-detail-page');
  await session.driver.pressBack();
  await session.waitId('journey-scroll-page');
  return edited;
}

async function saveObservationNote(session: ArchiveUiSession, siteId: string, hotspotId: string,
  body: string, keepFavoriteAndSection: boolean = false): Promise<ArchiveRecord> {
  const site = HERITAGE_SITES.find(item => item.id === siteId);
  const observation = materialObservationForSite(siteId);
  const hotspot = observation?.hotspots.find(item => item.id === hotspotId);
  if (!site || !observation || !hotspot) throw new Error(`JOURNEY_SCROLL_CONTENT_MISSING:${siteId}:${hotspotId}`);
  const previousIds = activeRecords((await session.read()).records, 'note').map(note => note.id);
  console.info(`JOURNEY_SCROLL_STEP:save-observation:${siteId}:${hotspotId}`);
  // 档案名来自现有目录；双连壶是器物观察对象，不把它误作“大河村遗址”的导航标题。
  await session.search(site.name, 1);
  await click(session, 'device-scroll', `site-row-${siteId}`);
  await session.waitId('detail-scroll');

  if (keepFavoriteAndSection) {
    await click(session, 'detail-scroll', 'favorite-toggle');
    expect(activeRecords((await session.read()).records, 'favorite').some(record => record.siteId === siteId)).assertTrue();
    await (await session.waitId('detail-scroll')).scrollToTop(40000);
    await click(session, 'detail-scroll', 'engine-mode-stratum');
    await click(session, 'detail-scroll', 'exploration-overview');
    await click(session, 'detail-scroll', 'exploration-complete');
    expect(decodeExplorationProgress((await session.read()).records, siteId).completedSectionIds.join('|'))
      .assertEqual('overview');
    await (await session.waitId('detail-scroll')).scrollToTop(40000);
    await click(session, 'detail-scroll', 'engine-mode-relic');
  }

  await click(session, 'detail-scroll', `observation-hotspot-${hotspotId}`);
  expect(await (await session.inScroll('detail-scroll', ON.id('observation-selected-detail'))).getText())
    .assertEqual(`正在观察 · ${hotspot.label}`);
  await click(session, 'detail-scroll', 'engine-remember-view');
  await session.waitId('note-editor-scroll');
  expect(await (await session.waitId('note-associated-site')).getText()).assertEqual(site.name);
  await (await session.inScroll('note-editor-scroll', ON.id('note-body'))).inputText(body);
  await (await session.inScroll('note-editor-scroll', ON.id('note-tags'))).inputText(TOPIC);
  // 固定保存按钮自行结束输入；不按 Back 猜测 IME，避免触发 Sheet 的放弃修改提示。
  await (await session.waitId('save-note')).click();
  await session.editorClosed();
  const snapshot = await session.read();
  const notes = activeRecords(snapshot.records, 'note');
  expect(notes.length).assertEqual(previousIds.length + 1);
  const note = notes.find(item => !previousIds.includes(item.id));
  if (!note || !note.snapshot3DPose) throw new Error(`JOURNEY_SCROLL_NOTE_NOT_PERSISTED:${siteId}`);
  assertObservationNote(note, siteId, hotspotId, body);
  console.info(`JOURNEY_SCROLL_NOTE_SAVED:${JSON.stringify({ id: note.id, siteId: note.siteId,
    tags: note.tags, pose: note.snapshot3DPose, noteCount: notes.length })}`);
  // 新建并确认落盘后，正式页面回顶露出接续卡；不是测试打开另一个影子页面。
  await session.inScroll('detail-scroll', ON.id('detail-journey-scroll'));
  return note;
}

export default function journeyScrollTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requested = parameters['class'] || parameters['-s class'] || '';
  if (!requested.includes('JourneyScrollTest')) return;
  describe('JourneyScrollTest', () => {
    it('prepare_real_observation_records', 0, async () => {
      await runJourneyPhase('prepare', async (session: ArchiveUiSession) => {
        expect((await session.read()).records.length).assertEqual(0);
        const twin = await saveObservationNote(session, TWIN_SITE, 'opening', TWIN_BODY);
        await session.driver.pressBack();
        await session.waitId('device-scroll');
        const ding = await saveObservationNote(session, DING_SITE, 'corners', DING_BODY, true);
        await preparedJourney(session);
        await click(session, 'detail-scroll', 'detail-journey-scroll');
        await session.waitId('journey-scroll-page');
        await (await session.waitId('journey-scroll')).scrollToTop(40000);
        expect(await (await session.inScroll('journey-scroll', ON.id('journey-scroll-progress'))).getText())
          .assertEqual('2 / 4 已点亮');
        await capture('two-observations');
        console.info(`JOURNEY_SCROLL_PREPARE_RESULT:${JSON.stringify({ noteIds: [twin.id, ding.id],
          activeNotes: 2, favoriteCount: 1, sectionPercent: 25 })}`);
      });
    });

    it('inspect_topics_sources_and_saved_replay', 0, async () => {
      await runJourneyPhase('inspect', async (session: ArchiveUiSession) => {
        const prepared = await preparedJourney(session);
        const twin = prepared.twin;
        const ding = prepared.ding;
        const model = buildJourneyScroll(HERITAGE_SITES, (await session.read()).records);
        await (await session.waitId('tab-1')).click();
        await click(session, 'archive-scroll', 'memory-journey-scroll');
        await session.waitId('journey-scroll-page');

        // 先展开双连壶步骤，再切回下一处展开出处；不重复点默认展开的步骤把它收起。
        await click(session, 'journey-scroll', `journey-step-${TWIN_SITE}`);
        const twinReason = await session.inScroll('journey-scroll', ON.id(`journey-reason-${TWIN_SITE}`));
        expect((await twinReason.getText()).includes('椭圆形通口')).assertTrue();
        const next = model.steps.find(step => step.site.id === model.progress.nextSiteId);
        if (!next) throw new Error('JOURNEY_SCROLL_NEXT_SITE_MISSING');
        expect(next.site.id).assertEqual('smx-miaodigou');
        await click(session, 'journey-scroll', `journey-step-${next.site.id}`);
        expect(await (await session.inScroll('journey-scroll', ON.id(`journey-reason-${next.site.id}`))).getText())
          .assertEqual(next.readingReason);
        await click(session, 'journey-scroll', `journey-source-${next.site.id}`);
        await session.inScroll('journey-scroll', ON.text(next.site.source.title));
        expect(await (await session.inScroll('journey-scroll', ON.text(next.site.source.url))).getText())
          .assertEqual(next.site.source.url);
        await capture('reading-source');
        console.info('JOURNEY_SCROLL_STEP:inspect:SOURCE_VERIFIED');

        // 这是页面自己的个人长卷入口，回顶后点击并核对实际落点；不由测试直接改内部滚动位置。
        await (await session.waitId('journey-scroll')).scrollToTop(40000);
        await click(session, 'journey-scroll', 'journey-personal-open');
        const personalTitle = await session.waitId('journey-personal-title');
        const personalBounds = await personalTitle.getBounds();
        const personalViewport = await (await session.waitId('journey-scroll')).getBounds();
        expect(personalBounds.right > personalBounds.left && personalBounds.bottom > personalBounds.top).assertTrue();
        expect(personalBounds.top >= personalViewport.top && personalBounds.bottom <= personalViewport.bottom).assertTrue();
        console.info(`JOURNEY_SCROLL_STEP:inspect:PERSONAL_ANCHOR:${JSON.stringify({ title: personalBounds,
          scroll: personalViewport })}`);

        // 个人分组与每张手账都按正式磁盘记录定位，不能用同地点的另一条镜头代替。
        console.info('JOURNEY_SCROLL_STEP:inspect:CITY_BEGIN');
        await session.inScroll('journey-scroll', ON.text('郑州').within(ON.id('journey-city-郑州')));
        console.info('JOURNEY_SCROLL_STEP:inspect:CITY_VERIFIED');
        for (const note of [twin, ding]) {
          console.info(`JOURNEY_SCROLL_STEP:inspect:TOPIC_BEGIN:${note.siteId}`);
          const topic = await session.inScroll('journey-scroll', ON.id(`journey-topic-${note.siteId}`));
          const text = await topic.getText();
          expect(text.includes(`我的专题：${TOPIC}`)).assertTrue();
          expect(text.includes('同在郑州')).assertTrue();
          expect(await (await session.inScroll('journey-scroll',
            ON.text(note.body).within(ON.id(`journey-note-${note.id}`)))).getText()).assertEqual(note.body);
          console.info(`JOURNEY_SCROLL_STEP:inspect:TOPIC_BODY_VERIFIED:${note.siteId}`);
        }
        await capture('zhengzhou-topic');
        const previewId = `journey-preview-${twin.id}`;
        console.info(`JOURNEY_SCROLL_STEP:inspect:PREVIEW_BEGIN:${twin.id}`);
        expect(await (await session.inScroll('journey-scroll',
          ON.id(`${previewId}-status`).text('已恢复当时视角'))).getText()).assertEqual('已恢复当时视角');
        // 点击实际绘制的预览 Canvas，走现有 onReplayMemory，不只点击一个静态标题。
        await (await session.inScroll('journey-scroll', ON.id(`${previewId}-canvas`).type('Canvas'))).click();
        await session.waitId('detail-scroll');
        await (await session.waitId('detail-scroll')).scrollToTop(40000);
        expect((await (await session.inScroll('detail-scroll', ON.id('engine-angle'))).getText())
          .includes('已回到手账视角')).assertTrue();
        expect(await (await session.inScroll('detail-scroll', ON.id('observation-selected-detail'))).getText())
          .assertEqual('正在观察 · 腹部通口');
        const observation = materialObservationForSite(TWIN_SITE);
        if (!observation) throw new Error('JOURNEY_SCROLL_REPLAY_CONTENT_MISSING');
        expect(await (await session.inScroll('detail-scroll', ON.id('site-object-notice'))).getText())
          .assertEqual(observation.notice);
        expect(compareVersions(twin, activeRecords((await session.read()).records, 'note').find(note => note.id === twin.id)!))
          .assertEqual(0);
        // 热点与资料说明在画布下方，核对后真实回顶，让本次回放画面与成功文案同屏留证。
        await (await session.waitId('detail-scroll')).scrollToTop(40000);
        await session.inScroll('detail-scroll', ON.id('engine-angle'));
        await session.inScroll('detail-scroll', ON.id('engine-native-relic_inspector').type('Canvas'));
        const replayCanvas = await (await session.waitId('engine-native-relic_inspector')).getBounds();
        const replayAngle = await (await session.waitId('engine-angle')).getBounds();
        const replayViewport = await (await session.waitId('detail-scroll')).getBounds();
        for (const bounds of [replayCanvas, replayAngle]) {
          expect(bounds.right > bounds.left && bounds.bottom > bounds.top).assertTrue();
          expect(bounds.top >= replayViewport.top && bounds.bottom <= replayViewport.bottom).assertTrue();
        }
        console.info(`JOURNEY_SCROLL_REPLAY_FRAME:${JSON.stringify({ canvas: replayCanvas, angle: replayAngle,
          scroll: replayViewport })}`);
        await capture('opening-replay');
        await session.driver.pressBack();
        await session.waitId('journey-scroll-page');
        const after = await preparedJourney(session);
        expect(compareVersions(prepared.twin, after.twin)).assertEqual(0);
        expect(compareVersions(prepared.ding, after.ding)).assertEqual(0);
        expect(compareVersions(prepared.favorite, after.favorite)).assertEqual(0);
        expect(compareVersions(prepared.section, after.section)).assertEqual(0);
        console.info(`JOURNEY_SCROLL_INSPECT_RESULT:${JSON.stringify({ noteIds: [twin.id, ding.id],
          originalRecordsUnchanged: true, replayHotspot: 'opening', revision: 2 })}`);
      });
    });

    it('edit_topic_and_refresh_scroll', 0, async () => {
      await runJourneyPhase('edit', async (session: ArchiveUiSession) => {
        const prepared = await preparedJourney(session, true);
        const twin = prepared.twin;
        let ding = prepared.ding;
        await (await session.waitId('tab-1')).click();
        await click(session, 'archive-scroll', 'memory-journey-scroll');
        await session.waitId('journey-scroll-page');
        if (ding.tags.join('|') === REVISED_TOPIC) {
          // 前次超时已经真实保存新标签时，仍须完整重走本次编辑；只经正式编辑器改回旧标签。
          // 清缓存回读的返回记录成为这一次 ding 基线，其他 note、收藏和 section 不做任何写入。
          console.info(`JOURNEY_SCROLL_STEP:edit:RESET_ORIGINAL_TOPIC_THROUGH_UI:${ding.id}`);
          ding = await editTopicThroughEditor(session, ding, TOPIC);
          assertObservationNote(ding, DING_SITE, 'corners', DING_BODY);
        }
        const edited = await editTopicThroughEditor(session, ding, REVISED_TOPIC);
        for (const siteId of [TWIN_SITE, DING_SITE]) {
          // twin 位于个人区开头，ding 位于当前单城页尾；使用页面锚点和真实页尾进入已知位置。
          if (siteId === TWIN_SITE) {
            await (await session.waitId('journey-scroll')).scrollToTop(40000);
            await click(session, 'journey-scroll', 'journey-personal-open');
            await session.waitId('journey-personal-title');
          } else await (await session.waitId('journey-scroll')).scrollToBottom(40000);
          console.info(`JOURNEY_SCROLL_STEP:edit:REFRESH_TOPIC_BEGIN:${siteId}`);
          const topic = await session.inScroll('journey-scroll', ON.id(`journey-topic-${siteId}`));
          const text = await topic.getText();
          expect(text.includes(`我的专题：${TOPIC}`)).assertFalse();
          expect(text.includes('同在郑州')).assertTrue();
          expect(text.includes(siteId === DING_SITE ? `#${REVISED_TOPIC}` : `#${TOPIC}`)).assertTrue();
        }
        await capture('edited-topic-refresh');
        const after = await session.read();
        expect(activeRecords(after.records, 'note').length).assertEqual(2);
        for (const original of [twin, prepared.favorite, prepared.section]) {
          const current = after.records.find(record => record.id === original.id);
          if (!current) throw new Error('JOURNEY_SCROLL_EDIT_CHANGED_OTHER_RECORD');
          expect(compareVersions(original, current)).assertEqual(0);
        }
        console.info(`JOURNEY_SCROLL_EDIT_RESULT:${JSON.stringify({ noteId: edited.id,
          tags: edited.tags, previousUpdatedAt: ding.updatedAt, updatedAt: edited.updatedAt,
          activeNotes: 2, otherRecordsUnchanged: true })}`);
        console.info('JOURNEY_SCROLL_STEP:edit:TOPIC_REFRESH_VERIFIED');
      });
    });

    it('delete_verified_note_and_preserve_memory_entry', 0, async () => {
      await runJourneyPhase('delete', async (session: ArchiveUiSession) => {
        const prepared = await preparedJourney(session, true);
        const twin = prepared.twin;
        const ding = prepared.ding;
        const edited = prepared.ding;
        const favorite = prepared.favorite;
        const section = prepared.section;
        expect(edited.tags.join('|')).assertEqual(REVISED_TOPIC);
        await (await session.waitId('tab-1')).click();
        await click(session, 'archive-scroll', 'memory-journey-scroll');
        await session.waitId('journey-scroll-page');
        await (await session.waitId('journey-scroll')).scrollToBottom(40000);
        console.info(`JOURNEY_SCROLL_STEP:delete:READ_VERIFIED_NOTE_FROM_BOTTOM:${ding.id}`);
        await click(session, 'journey-scroll', `journey-read-${ding.id}`);
        await session.waitId('memory-detail-scroll');
        expect(await (await session.inScroll('memory-detail-scroll', ON.id('memory-detail-body'))).getText())
          .assertEqual(edited.body);
        await (await session.waitId('memory-detail-scroll')).scrollToBottom(40000);
        await click(session, 'memory-detail-scroll', 'memory-detail-delete');
        console.info('JOURNEY_SCROLL_STEP:delete:CONFIRM_DIALOG');
        await (await session.waitText('删除')).click();
        // 删除后的 onBack 只 pop 当前全文，必须回到原长卷而非另开记忆页。
        await session.waitId('journey-scroll-page');
        const finalSnapshot = await session.read();
        const tombstone = finalSnapshot.records.find(record => record.id === ding.id);
        if (!tombstone) throw new Error('JOURNEY_SCROLL_TOMBSTONE_MISSING');
        expect(tombstone.deleted).assertTrue();
        expect(tombstone.tags.join('|')).assertEqual(REVISED_TOPIC);
        expect(tombstone.body).assertEqual(ding.body);
        expect(JSON.stringify(tombstone.snapshot3DPose)).assertEqual(JSON.stringify(ding.snapshot3DPose));
        expect(tombstone.stampType).assertEqual(edited.stampType);
        expect(tombstone.paperTheme).assertEqual(edited.paperTheme);
        expect(tombstone.quotedPoemOrFact).assertEqual(edited.quotedPoemOrFact);
        expect(tombstone.updatedAt > edited.updatedAt).assertTrue();
        expect(activeRecords(finalSnapshot.records, 'note').length).assertEqual(1);
        expect(compareVersions(twin, activeRecords(finalSnapshot.records, 'note')[0])).assertEqual(0);
        const finalFavorite = finalSnapshot.records.find(record => record.id === favorite.id);
        const finalSection = finalSnapshot.records.find(record => record.id === section.id);
        if (!finalFavorite || !finalSection) throw new Error('JOURNEY_SCROLL_OTHER_RECORD_REMOVED');
        expect(compareVersions(favorite, finalFavorite)).assertEqual(0);
        expect(compareVersions(section, finalSection)).assertEqual(0);
        console.info(`JOURNEY_SCROLL_STEP:delete:TOMBSTONE_AND_BASELINES_VERIFIED:${ding.id}`);
        expect(decodeExplorationProgress(finalSnapshot.records, DING_SITE).percent).assertEqual(25);
        const finalModel = buildJourneyScroll(HERITAGE_SITES, finalSnapshot.records);
        expect(finalModel.noteCount).assertEqual(1);
        expect(finalModel.personalSiteCount).assertEqual(2);
        expect(finalModel.progress.completedCount).assertEqual(1);
        const finalDingEntry = finalModel.groups[0].entries.find(entry => entry.site.id === DING_SITE);
        if (!finalDingEntry) throw new Error('JOURNEY_SCROLL_FAVORITE_SECTION_ENTRY_REMOVED');
        expect(finalDingEntry.favorite).assertTrue();
        expect(finalDingEntry.exploredPercent).assertEqual(25);
        expect(finalDingEntry.notes.length).assertEqual(0);
        await (await session.waitId('journey-scroll')).scrollToBottom(40000);
        expect(await (await session.inScroll('journey-scroll',
          ON.text('探索 25%').within(ON.id(`journey-entry-${DING_SITE}`)))).getText()).assertEqual('探索 25%');
        expect(await (await session.inScroll('journey-scroll', ON.id(`journey-topic-${DING_SITE}`))).getText())
          .assertEqual('同在郑州');
        expect(!await session.driver.findComponent(ON.id(`journey-read-${ding.id}`))).assertTrue();
        await capture('tombstone-preserves-other-records');
        await (await session.waitId('journey-scroll')).scrollToTop(40000);
        expect(await (await session.inScroll('journey-scroll', ON.id('journey-scroll-progress'))).getText())
          .assertEqual('1 / 4 已点亮');

        // 本阶段从记忆固定入口进入长卷，只需返回一层回到原记忆；不沿用创建阶段的档案路由层数。
        await session.driver.pressBack();
        await session.waitId('archive-scroll');
        await (await session.waitId('archive-scroll')).scrollToTop(40000);
        // 新增常驻长卷入口后，首张普通手账仍须直接露出主要信息，不滚动补救。
        const twinSite = HERITAGE_SITES.find(site => site.id === TWIN_SITE)!;
        const cardId = `memory-card-${twin.id}`;
        const titleBounds = await (await session.wait(ON.text(twinSite.name).within(ON.id(cardId)), 'memory-first-title')).getBounds();
        const bodyBounds = await (await session.wait(ON.text(TWIN_BODY).within(ON.id(cardId)), 'memory-first-body')).getBounds();
        const readBounds = await (await session.waitId(`memory-open-${twin.id}`)).getBounds();
        const headerBounds = await (await session.waitId('top-navigation-content')).getBounds();
        const dockBounds = await (await session.waitId('tab-0')).getBounds();
        for (const bounds of [titleBounds, bodyBounds, readBounds]) {
          expect(bounds.right > bounds.left && bounds.bottom > bounds.top).assertTrue();
          expect(bounds.top >= headerBounds.bottom && bounds.bottom <= dockBounds.top).assertTrue();
        }
        expect(titleBounds.top < bodyBounds.top && bodyBounds.top < readBounds.top).assertTrue();
        console.info(`JOURNEY_SCROLL_MEMORY_FIRST_CARD:${JSON.stringify({ noteId: twin.id,
          title: titleBounds, body: bodyBounds, read: readBounds, header: headerBounds, dock: dockBounds })}`);
        await capture('memory-entry-first-card');
        await click(session, 'archive-scroll', 'memory-journey-scroll');
        await session.waitId('journey-scroll-page');
        expect(await (await session.inScroll('journey-scroll', ON.id('journey-scroll-progress'))).getText())
          .assertEqual('1 / 4 已点亮');
        console.info(`JOURNEY_SCROLL_MAIN_RESULT:${JSON.stringify({ noteIds: [twin.id, ding.id],
          activeNotes: 1, tombstones: 1, favoritePreserved: true, sectionPercent: 25 })}`);
      });
    });

    it('cleanup_only_requested_journey_store', 0, async () => {
      const session = new ArchiveUiSession('journey_cleanup', journeyStoreName(true));
      console.info(`JOURNEY_SCROLL_PHASE_BEGIN:cleanup:${session.name}`);
      // 仍走离线入口取得正式模块 Context；run 的默认 finally 精确 dispose 这个测试前缀库。
      // 不枚举、不清空其他运行编号或正式档案，也不要求前一阶段通过才允许清理。
      await session.run(async () => {
        const snapshot = await session.read();
        console.info(`JOURNEY_SCROLL_CLEANUP_RECORD_COUNT:${snapshot.records.length}`);
      });
      console.info(`JOURNEY_SCROLL_PHASE_DONE:cleanup:${session.name}`);
    });

    it('empty_scroll_entry_and_real_suggestion', 0, async () => {
      const session = new ArchiveUiSession('journey_scroll_empty');
      const started = Date.now();
      await session.run(async () => {
        const before = await session.read();
        expect(before.records.length).assertEqual(0);
        await (await session.waitId('tab-1')).click();
        await click(session, 'archive-scroll', 'memory-journey-scroll');
        await session.waitId('journey-scroll-page');
        expect(await (await session.inScroll('journey-scroll', ON.id('journey-scroll-progress'))).getText())
          .assertEqual('0 / 4 已点亮');
        const model = buildJourneyScroll(HERITAGE_SITES, before.records);
        const next = model.steps.find(step => step.site.id === model.progress.nextSiteId);
        if (!next) throw new Error('JOURNEY_SCROLL_EMPTY_NEXT_MISSING');
        expect(next.site.id).assertEqual('smx-miaodigou');
        expect(await (await session.inScroll('journey-scroll',
          ON.text(next.site.name).within(ON.id('journey-next-open')))).getText()).assertEqual(next.site.name);
        await click(session, 'journey-scroll', `journey-source-${next.site.id}`);
        await session.inScroll('journey-scroll', ON.text(next.site.source.title));
        expect(await (await session.inScroll('journey-scroll', ON.text(next.site.source.url))).getText())
          .assertEqual(next.site.source.url);
        // 父空态容器只露一小截不代表标题已可见；始终把实际核对的叶节点滚入视口。
        expect(await (await session.inScroll('journey-scroll',
          ON.text('长卷，等你落下第一笔').within(ON.id('journey-empty')))).getText()).assertEqual('长卷，等你落下第一笔');
        expect((await session.read()).records.length).assertEqual(0);
        await capture('empty-real-suggestion');
        await click(session, 'journey-scroll', 'journey-empty-open');
        await session.waitId('detail-scroll');
        expect(await (await session.wait(ON.text(next.site.name).type('Text').within(ON.type('TitleBar')),
          'journey-empty-open-real-archive')).getText()).assertEqual(next.site.name);
        const opened = await session.read();
        expect(activeRecords(opened.records, 'note').length).assertEqual(0);
        expect(activeRecords(opened.records, 'favorite').length).assertEqual(0);
        expect(decodeExplorationProgress(opened.records, next.site.id).percent).assertEqual(0);
        expect(buildJourneyScroll(HERITAGE_SITES, opened.records).personalSiteCount).assertEqual(0);
        await capture('empty-opened-archive');
        await session.driver.pressBack();
        await session.waitId('journey-scroll-page');
        await session.inScroll('journey-scroll', ON.text('长卷，等你落下第一笔').within(ON.id('journey-empty')));
        console.info(`JOURNEY_SCROLL_EMPTY_RESULT:${JSON.stringify({ suggestedSiteId: next.site.id,
          activeNotes: 0, personalSites: 0, elapsedMs: Date.now() - started })}`);
      });
    });
  });
}
