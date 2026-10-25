import { abilityDelegatorRegistry, ON } from '@kit.TestKit';
import { describe, expect, it } from '@ohos/hypium';
import { activeRecords, ArchiveRecord, HeritageSite } from '../../../main/ets/domain/ArchiveDomain';
import { HERITAGE_SITES } from '../../../main/ets/data/HeritageCatalog';
import { groupMemoryRecords } from '../../../main/ets/domain/MemoryJournal';
import { ArchiveUiSession } from './ArchiveUiSession';

async function click(session: ArchiveUiSession, scrollId: string, id: string): Promise<void> {
  await (await session.inScroll(scrollId, ON.id(id))).click();
}

async function capture(name: string): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  expect((await delegator.executeShellCommand(
    `uitest screenCap -p /data/local/tmp/content-memory-${name}.png`)).exitCode).assertEqual(0);
  expect((await delegator.executeShellCommand(
    `uitest dumpLayout -p /data/local/tmp/content-memory-${name}.json`)).exitCode).assertEqual(0);
}

function siteFor(id: string): HeritageSite {
  const site = HERITAGE_SITES.find(item => item.id === id);
  if (!site) throw new Error(`CONTENT_MEMORY_SITE_MISSING:${id}`);
  return site;
}

async function memoryCount(session: ArchiveUiSession, count: number, conditions: string): Promise<void> {
  expect(await (await session.inScroll('archive-scroll', ON.id('memory-result-count'))).getText())
    .assertEqual(`${count} 篇`);
  expect(await (await session.waitId('memory-conditions')).getText()).assertEqual(conditions);
}

async function chooseLibraryOption(session: ArchiveUiSession, id: string, label: string): Promise<void> {
  // Select 先滚进真实无遮挡区；菜单展开后只选 Option，不能命中目录里的同名城市文字。
  await session.inScroll('device-scroll', ON.id(id));
  await session.select(id, label);
}

async function writePlainNote(session: ArchiveUiSession, body: string, tags: string[],
  siteId: string = 'zz-duling-fangding', fromAllSites: boolean = false): Promise<ArchiveRecord> {
  const previousIds = activeRecords((await session.read()).records, 'note').map(note => note.id);
  await (await session.waitId('archive-scroll')).scrollToTop(40000);
  await click(session, 'archive-scroll', 'memory-new');
  await session.waitId('memory-write-page');
  // 独立空库的明确起点包含方鼎；首次选择之后，它又是真实最近浏览档案。
  // 三条正文通过同一个正式编辑器保存，不能往 Preferences 注入记录来替代“写一页”。
  if (fromAllSites) {
    await click(session, 'memory-write-scroll', 'memory-write-browse');
    await session.waitId('memory-write-all-page');
    expect(await (await session.waitId('memory-write-scope')).getText()).assertEqual(`全部文化档案 · ${HERITAGE_SITES.length} 处`);
  }
  await click(session, fromAllSites ? 'memory-write-all-scroll' : 'memory-write-scroll', `memory-write-${siteId}`);
  await session.waitId('note-editor-scroll');
  await (await session.inScroll('note-editor-scroll', ON.id('note-body'))).inputText(body);
  await (await session.inScroll('note-editor-scroll', ON.id('note-tags'))).inputText(tags.join('，'));
  await (await session.waitId('save-note')).click();
  await session.editorClosed();
  const notes = activeRecords((await session.read()).records, 'note');
  expect(notes.length).assertEqual(previousIds.length + 1);
  const saved = notes.find(note => !previousIds.includes(note.id));
  if (!saved) throw new Error('CONTENT_MEMORY_NEW_NOTE_NOT_PERSISTED');
  expect(saved.siteId).assertEqual(siteId);
  expect(saved.id.startsWith('note:')).assertTrue();
  expect(saved.body).assertEqual(body);
  expect(JSON.stringify(saved.tags)).assertEqual(JSON.stringify(tags));
  expect(saved.deleted).assertFalse();
  expect(saved.aiAssist === undefined).assertTrue();
  expect(saved.snapshot3DPose === undefined).assertTrue();
  await session.driver.pressBack();
  await session.waitId('archive-scroll');
  // 选择页被正式详情路由替换；一次返回就回到记忆，不能多按一次返回掩盖路由问题。
  expect(!await session.driver.findComponent(ON.id('memory-write-page'))).assertTrue();
  expect(!await session.driver.findComponent(ON.id('memory-write-all-page'))).assertTrue();
  console.info(`CONTENT_MEMORY_NOTE_SAVED:${JSON.stringify({ id: saved.id, siteId: saved.siteId,
    body: saved.body, tags: saved.tags, updatedAt: saved.updatedAt })}`);
  return saved;
}

async function assertFirstCard(session: ArchiveUiSession, expected: ArchiveRecord,
  allNotes: ArchiveRecord[], phase: string, captureFirstScreen: boolean = false): Promise<void> {
  await (await session.waitId('archive-scroll')).scrollToTop(40000);
  const cardId = `memory-card-${expected.id}`;
  const card = await session.waitId(cardId);
  const cardBounds = await card.getBounds();
  expect(cardBounds.right > cardBounds.left && cardBounds.bottom > cardBounds.top).assertTrue();
  const month = groupMemoryRecords([expected])[0].label;
  const monthBounds = await (await session.waitId(`memory-month-${month}`)).getBounds();
  expect(monthBounds.right > monthBounds.left && monthBounds.bottom > monthBounds.top).assertTrue();
  // 三条样本在同一次用例内创建，月份一致。回顶后的首卡必须紧接月份标题；
  // 仅找到目标卡、或仅看到“最早”文案，都不能证明排序真正改变了第一条记录。
  expect(cardBounds.top >= monthBounds.bottom).assertTrue();
  expect(cardBounds.top - monthBounds.bottom <= (monthBounds.bottom - monthBounds.top) * 2).assertTrue();
  for (const other of allNotes) {
    if (other.id === expected.id) continue;
    const otherCard = await session.driver.findComponent(ON.id(`memory-card-${other.id}`));
    if (otherCard) {
      const otherBounds = await otherCard.getBounds();
      if (otherBounds.right > otherBounds.left && otherBounds.bottom > otherBounds.top) {
        expect(otherBounds.top > cardBounds.top).assertTrue();
      }
    }
  }
  const title = await session.wait(ON.text(siteFor(expected.siteId).name).within(ON.id(cardId)), '首张手账档案名');
  const body = await session.wait(ON.text(expected.body).within(ON.id(cardId)), '首张手账正文');
  expect(await title.getText()).assertEqual(siteFor(expected.siteId).name);
  expect(await body.getText()).assertEqual(expected.body);
  const titleBounds = await title.getBounds();
  const bodyBounds = await body.getBounds();
  const readBounds = await (await session.waitId(`memory-open-${expected.id}`)).getBounds();
  const dockBounds = await (await session.waitId('tab-0')).getBounds();
  const headerBounds = await (await session.waitId('top-navigation-content')).getBounds();
  // 这里刻意不调用 inScroll：首屏检查不能先把按钮滚出 Dock 再声称它原本可见。
  for (const bounds of [titleBounds, bodyBounds, readBounds]) {
    expect(bounds.right > bounds.left && bounds.bottom > bounds.top).assertTrue();
    expect(bounds.top >= headerBounds.bottom && bounds.bottom <= dockBounds.top).assertTrue();
  }
  expect(titleBounds.top < bodyBounds.top && bodyBounds.top < readBounds.top).assertTrue();
  console.info(`CONTENT_MEMORY_FIRST_CARD_BOUNDS:${phase}:${JSON.stringify({ id: expected.id,
    card: cardBounds, month: monthBounds, title: titleBounds, body: bodyBounds,
    read: readBounds, dock: dockBounds, header: headerBounds })}`);
  if (captureFirstScreen) await capture(phase);
}

export default function contentMemoryTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requested = parameters['class'] || parameters['-s class'] || '';
  if (!requested.includes('ContentMemoryTest')) return;
  describe('ContentMemoryTest', () => {
    it('new_content_combined_filters_neutral_reading_and_real_favorites', 0, async () => {
      const session = new ArchiveUiSession('content_dimensions');
      const started = Date.now();
      await session.run(async () => {
        await (await session.waitId('tab-2')).click();
        for (const id of ['zz-wangchenggang', 'zz-huangye-kiln']) {
          const site = siteFor(id);
          await click(session, 'device-scroll', 'library-reset');
          await chooseLibraryOption(session, 'library-city', site.city);
          await chooseLibraryOption(session, 'library-era', site.era);
          await chooseLibraryOption(session, 'library-type', site.type);
          expect(await (await session.inScroll('device-scroll', ON.id('library-result-count'))).getText()).assertEqual('1 处');
          await (await session.inScroll('device-scroll', ON.id(`site-row-${id}`).within(ON.id('archive-library-grid')))).click();
          await session.waitId('detail-scroll');
          expect(await (await session.inScroll('detail-scroll', ON.id('engine-mode-relic'))).getText()).assertEqual('资料观察');
          expect(await (await session.inScroll('detail-scroll', ON.id('site-object-notice'))).getText())
            .assertEqual('通用资料学习示意，不表示本遗址平面、窑炉结构或出土器物。');
          expect(await (await session.inScroll('detail-scroll', ON.id('engine-hotspot-reading'))).getText()).assertEqual(site.overview);
          await click(session, 'detail-scroll', 'hotspot-pattern');
          expect(await (await session.inScroll('detail-scroll', ON.id('engine-hotspot-reading'))).getText()).assertEqual(site.archaeology);
          // 核对真实本地文字与正文来源，不向外打开网站，也不依赖账号或 AI 服务。
          await capture(`${id}-reading`);
          await click(session, 'detail-scroll', 'favorite-toggle');
          const favorite = activeRecords((await session.read()).records, 'favorite').find(record => record.siteId === id);
          expect(favorite !== undefined).assertTrue();
          await session.inScroll('detail-scroll', ON.text(site.overview));
          await session.inScroll('detail-scroll', ON.text(site.source.title));
          await session.inScroll('detail-scroll', ON.text(site.source.url));
          await session.inScroll('detail-scroll', ON.text('初稿待校审'));
          await capture(`${id}-source`);
          await session.driver.pressBack();
          await session.waitId('device-scroll');
          expect(await (await session.inScroll('device-scroll', ON.id('library-result-count'))).getText()).assertEqual('1 处');
        }
        const favorites = activeRecords((await session.read()).records, 'favorite');
        expect(favorites.length).assertEqual(2);
        expect(favorites.some(record => record.siteId === 'zz-wangchenggang')).assertTrue();
        expect(favorites.some(record => record.siteId === 'zz-huangye-kiln')).assertTrue();
        await (await session.waitId('tab-1')).click();
        await click(session, 'archive-scroll', 'memory-section-1');
        expect(await (await session.inScroll('archive-scroll', ON.id('collection-count'))).getText()).assertEqual('2');
        await session.inScroll('archive-scroll', ON.id('site-row-zz-wangchenggang').within(ON.id('archive-site-grid')));
        await session.inScroll('archive-scroll', ON.id('site-row-zz-huangye-kiln').within(ON.id('archive-site-grid')));
        await capture('new-content-favorites');
      });
      console.info(`CONTENT_MEMORY_DURATION:content:${Date.now() - started}`);
    });

    it('write_three_plain_notes_real_recent_oldest_tag_and_fulltext_return', 0, async () => {
      const session = new ArchiveUiSession('memory_order');
      const started = Date.now();
      await session.run(async () => {
        await (await session.waitId('tab-1')).click();
        const oldest = await writePlainNote(session, '第一回看方鼎，先记下四面的整体轮廓。', ['同行', '轮廓']);
        const middle = await writePlainNote(session, '第二回看方鼎，转到折角再辨认纹饰。', ['同行', '纹饰']);
        const newest = await writePlainNote(session, '第三回看方鼎，把今天的疑问留在纸上。', ['提问', '河岸']);
        const notes = [oldest, middle, newest];
        expect(oldest.id !== middle.id && middle.id !== newest.id && oldest.id !== newest.id).assertTrue();
        expect(oldest.updatedAt < middle.updatedAt && middle.updatedAt < newest.updatedAt).assertTrue();
        expect(groupMemoryRecords(notes).length).assertEqual(1);
        await memoryCount(session, 3, '最近');
        await assertFirstCard(session, newest, notes, 'recent-first-screen', true);
        await session.openMemoryFilters();
        await click(session, 'memory-filter-scroll', 'memory-sort-1');
        expect(await (await session.waitId('memory-filter-done')).getText()).assertEqual('查看 3 篇手账');
        await session.closeMemoryFilters();
        await memoryCount(session, 3, '最早');
        await assertFirstCard(session, oldest, notes, 'oldest-first-screen', true);
        await session.openMemoryFilters();
        await (await session.inScroll('memory-filter-scroll', ON.text('#同行').type('Button'))).click();
        expect(await (await session.waitId('memory-filter-done')).getText()).assertEqual('查看 2 篇手账');
        await session.closeMemoryFilters();
        await memoryCount(session, 2, '最早 · #同行');
        expect(!await session.driver.findComponent(ON.id(`memory-card-${newest.id}`))).assertTrue();
        await click(session, 'archive-scroll', `memory-open-${oldest.id}`);
        expect(await (await session.inScroll('memory-detail-scroll', ON.id('memory-detail-body'))).getText()).assertEqual(oldest.body);
        await capture('tag-fulltext');
        await session.driver.pressBack();
        await session.waitId('archive-scroll');
        await memoryCount(session, 2, '最早 · #同行');
        await assertFirstCard(session, oldest, [oldest, middle], 'tag-return');
        await capture('tag-return');
        await click(session, 'archive-scroll', 'memory-filter-clear');
        await memoryCount(session, 3, '最近');
        await assertFirstCard(session, newest, notes, 'cleared-recent');
        // 筛选、排序、阅读和清除只改变视图；三条磁盘记录仍保持原 ID、正文和标签。
        const persisted = activeRecords((await session.read()).records, 'note');
        expect(persisted.length).assertEqual(3);
        for (const note of notes) {
          expect(JSON.stringify(persisted.find(item => item.id === note.id))).assertEqual(JSON.stringify(note));
        }
      });
      console.info(`CONTENT_MEMORY_DURATION:order:${Date.now() - started}`);
    });

    it('ai_empty_write_returns_visible_gallery_manage_and_batch_tombstones', 0, async () => {
      const session = new ArchiveUiSession('memory_views');
      const started = Date.now();
      await session.run(async () => {
        await (await session.waitId('tab-1')).click();
        await session.openMemoryFilters();
        await click(session, 'memory-filter-scroll', 'memory-ai-filter');
        await capture('filters-ai');
        await session.closeMemoryFilters();
        await memoryCount(session, 0, '最近 · AI 辅助');
        await session.waitText('还没有 AI 辅助手账');
        await capture('ai-empty');
        await click(session, 'archive-scroll', 'memory-new');
        await click(session, 'memory-write-scroll', 'memory-write-browse');
        await session.waitId('memory-write-all-page');
        expect(await (await session.waitId('memory-write-scope')).getText()).assertEqual(`全部文化档案 · ${HERITAGE_SITES.length} 处`);
        await capture('write-all-before-cancel');
        await session.driver.pressBack();
        await session.waitId('archive-scroll');
        // “全部档案”只替换选择页；取消选择不能丢失进入前已经生效的 AI 条件。
        await memoryCount(session, 0, '最近 · AI 辅助');
        // 从已生效的 AI 空态真实写普通手账；返回后应自动解除会藏住新记录的条件。
        // 王城岗不在空库三个起点中，必须实际经过全部目录选择，而不是退回普通档案浏览。
        const first = await writePlainNote(session, '从 AI 筛选空页出发，也能写下自己的普通观察。',
          ['普通观察'], 'zz-wangchenggang', true);
        await memoryCount(session, 1, '最近');
        await assertFirstCard(session, first, [first], 'ai-empty-written', true);
        const second = await writePlainNote(session, '再留一页，核对画廊选择与真实删除墓碑。',
          ['回看'], 'zz-wangchenggang');
        await memoryCount(session, 2, '最近');
        expect(!await session.driver.findComponent(ON.id(`edit-${second.id}`))).assertTrue();
        await session.openMemoryFilters();
        await click(session, 'memory-filter-scroll', 'memory-view-gallery');
        await capture('filters-gallery');
        // 高亮颜色从本次保存的真实布局在主机核对；UiTest 的 description
        // 不是 accessibilityText，也不要求测试宿主另开 cat 子命令读取外部文件。
        await session.closeMemoryFilters();
        await memoryCount(session, 2, '最近 · 画廊');
        await session.inScroll('archive-scroll', ON.id(`edit-${second.id}`));
        await capture('gallery');
        await session.openMemoryFilters();
        await (await session.waitId('memory-filter-reset')).click();
        await session.inScroll('memory-filter-scroll', ON.id('memory-view-list'));
        await capture('filters-reset');
        await session.closeMemoryFilters();
        await memoryCount(session, 2, '最近');
        expect(!await session.driver.findComponent(ON.id(`edit-${second.id}`))).assertTrue();
        await session.setMemoryView(true);
        await click(session, 'archive-scroll', 'memory-manage');
        await session.waitId('memory-selection-bar');
        for (const note of [second, first]) {
          await session.inScroll('archive-scroll', ON.id(`memory-select-${note.id}`));
          // 管理时卡片只响应选择；画廊编辑、删除与全文/AI 导航全部应消失。
          for (const prefix of ['memory-open-', 'memory-pose-', 'memory-ask-', 'edit-', 'delete-']) {
            expect(!await session.driver.findComponent(ON.id(`${prefix}${note.id}`))).assertTrue();
          }
          await click(session, 'archive-scroll', `memory-select-${note.id}`);
        }
        expect(await (await session.inScroll('archive-scroll', ON.id('memory-selected-count'))).getText()).assertEqual('已选 2 篇');
        await capture('gallery-selected');
        await click(session, 'archive-scroll', 'memory-delete-selected');
        await (await session.waitText('确认删除')).click();
        await session.waitId('archive-scroll');
        await memoryCount(session, 0, '最近 · 画廊');
        const disk = await session.read();
        expect(activeRecords(disk.records, 'note').length).assertEqual(0);
        for (const original of [first, second]) {
          const tombstone = disk.records.find(record => record.id === original.id);
          expect(tombstone?.deleted).assertTrue();
          expect(tombstone?.siteId).assertEqual(original.siteId);
          expect(tombstone?.body).assertEqual(original.body);
          expect(JSON.stringify(tombstone?.tags)).assertEqual(JSON.stringify(original.tags));
          expect((tombstone?.updatedAt || 0) > original.updatedAt).assertTrue();
        }
        await capture('batch-tombstones');
      });
      console.info(`CONTENT_MEMORY_DURATION:views:${Date.now() - started}`);
    });
  });
}
