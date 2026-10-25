import { abilityDelegatorRegistry, ON } from '@kit.TestKit';
import { describe, expect, it } from '@ohos/hypium';
import { activeRecords } from '../../../main/ets/domain/ArchiveDomain';
import { HERITAGE_SITES } from '../../../main/ets/data/HeritageCatalog';
import { ArchiveUiSession } from './ArchiveUiSession';

export default function archiveUiTest() {
  // 两阶段共用独立库：先经真实 UI 输入最大记录，再在下一条用例重建页面并编辑。
  // 避免把几十次分段输入、展开/收起与修改全部塞进单条 Hypium 用例而超时。
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const preparedStore = parameters['archiveMaximumStore'] || parameters['-s archiveMaximumStore'];
  const maximumStoreName = preparedStore && /^yunheji_test_ui_[0-9]+_maximum$/.test(preparedStore)
    ? preparedStore : `yunheji_test_ui_${Date.now()}_maximum`;
  describe('ArchiveUiTest', () => {
    it('native_sync_panel_reports_unavailable', 0, async () => {
      const session = new ArchiveUiSession('sync_status');
      await session.run(async () => {
        await (await session.waitId('profile-entry')).click();
        // 未登录的真实同步状态在独立“我的”页，登录表单仅在启动页。
        await session.inScroll('profile-scroll', ON.id('profile-login'));
        expect(!await session.driver.findComponent(ON.id('account-sync-state'))).assertTrue();
        await (await session.inScroll('profile-scroll', ON.id('profile-account'))).click();
        expect(await (await session.inScroll('profile-scroll', ON.id('connected-devices-value'))).getText()).assertEqual('暂无同步记录');
        expect(await (await session.inScroll('profile-scroll', ON.id('last-sync-value'))).getText()).assertEqual('尚未接入');
      });
    });
    it('native_combined_filters_and_reset', 0, async () => {
      const session = new ArchiveUiSession('filters');
      await session.run(async () => {
        await (await session.waitId('tab-2')).click();
        await session.inScroll('device-scroll', ON.id('library-city'));
        await session.select('library-city', '洛阳');
        await session.inScroll('device-scroll', ON.id('library-era'));
        await session.select('library-era', '夏商');
        await session.inScroll('device-scroll', ON.id('library-type'));
        await session.select('library-type', '都城遗址');
        // 扩充后的洛阳有两处夏商都城；保留 AND 筛选，并同时核对两张真实结果卡片。
        await session.search('青铜 都城', 2);
        await session.inScroll('device-scroll', ON.id('site-row-ly-erlitou').within(ON.id('archive-library-grid')));
        await session.inScroll('device-scroll', ON.id('site-row-ly-yanshi-shang').within(ON.id('archive-library-grid')));
        // 同时核对实际卡片，避免结果数量更新了、双列 ForEach 却仍保留旧配对。
        expect(!await session.driver.findComponent(ON.id('site-row-smx-yangshao').within(ON.id('archive-library-grid')))).assertTrue();
        expect(!await session.driver.findComponent(ON.id('site-row-zz-shang').within(ON.id('archive-library-grid')))).assertTrue();
        await (await session.waitId('device-scroll')).scrollToTop(40000);
        await session.inScroll('device-scroll', ON.id('library-reset'));
        await (await session.waitId('library-reset')).click();
        expect(await (await session.waitId('library-result-count')).getText()).assertEqual(`${HERITAGE_SITES.length} 处`);
        await session.inScroll('device-scroll', ON.id('library-city'));
        await session.select('library-city', '洛阳');
        await session.inScroll('device-scroll', ON.id('library-era'));
        await session.select('library-era', '宋');
        expect(await (await session.waitId('library-result-count')).getText()).assertEqual('0 处');
        await session.inScroll('device-scroll', ON.text('没有符合条件的档案'));
      });
    });

    it('native_favorite_note_crud_and_ability_restart', 0, async () => {
      const session = new ArchiveUiSession('crud');
      await session.run(async () => {
        await session.openYangshao();
        // 文化视口把收藏 / 笔记操作推到首屏以下，必须先滚入真实可点击区域。
        await (await session.inScroll('detail-scroll', ON.id('favorite-toggle'))).click();
        await session.inScroll('detail-scroll', ON.text('已收藏').within(ON.id('favorite-toggle')));
        await session.waitText('已收藏');
        await session.inScroll('detail-scroll', ON.id('favorite-category'));
        await session.select('favorite-category', '研究资料');
        await (await session.inScroll('detail-scroll', ON.id('write-note'))).click();
        await (await session.waitId('note-body')).inputText('自动回归：仰韶文化的学习记录');
        await (await session.inScroll('note-editor-scroll', ON.id('note-tags'))).inputText('彩陶，研学');
        await (await session.waitId('save-note')).click();
        await session.editorClosed();
        const saved = await session.read();
        const note = activeRecords(saved.records, 'note')[0];
        expect(note.body).assertEqual('自动回归：仰韶文化的学习记录');
        expect(note.tags.join('|')).assertEqual('彩陶|研学');
        expect(activeRecords(saved.records, 'favorite')[0].tags[0]).assertEqual('研究资料');
        console.info('UI_CRUD: 收藏分类和新笔记已落盘');

        // 结束并重建真实 EntryAbility，清缓存后再读取。进程级强杀由独立两阶段测试覆盖。
        await session.stop();
        await session.start();
        console.info('UI_CRUD: EntryAbility 已重建');
        await (await session.waitId('tab-1')).click();
        await (await session.waitId('memory-section-1')).click();
        await session.select('collection-filter', '研究资料');
        await (await session.inScroll('archive-scroll', ON.id('site-row-smx-yangshao'))).click();
        await session.inScroll('detail-scroll', ON.text('已收藏').within(ON.id('favorite-toggle')));
        await session.waitText('已收藏');
        console.info('UI_CRUD: 重建后收藏分类和详情已恢复');
        await (await session.waitId('detail-scroll')).scrollToBottom(40000);
        await (await session.inScroll('detail-scroll', ON.id(`edit-${note.id}`))).click();
        expect(await (await session.waitId('note-body')).getText()).assertEqual(note.body);
        expect(await (await session.inScroll('note-editor-scroll', ON.id('note-tags'))).getText()).assertEqual('彩陶，研学');
        await (await session.waitId('note-body')).inputText('自动回归：修改后的学习记录');
        await (await session.inScroll('note-editor-scroll', ON.id('note-tags'))).inputText('考古,中文标签');
        await (await session.waitId('save-note')).click();
        await session.editorClosed();
        const edited = activeRecords((await session.read()).records, 'note')[0];
        expect(edited.id).assertEqual(note.id);
        expect(edited.body).assertEqual('自动回归：修改后的学习记录');
        expect(edited.tags.join('|')).assertEqual('考古|中文标签');
        expect(edited.updatedAt > note.updatedAt).assertTrue();
        await (await session.waitId('detail-scroll')).scrollToBottom(40000);
        await (await session.inScroll('detail-scroll', ON.id(`delete-${note.id}`))).click();
        await (await session.waitText('取消')).click();
        expect(activeRecords((await session.read()).records, 'note').length).assertEqual(1);
        await (await session.inScroll('detail-scroll', ON.id(`delete-${note.id}`))).click();
        // 原生 AlertDialog 的操作标签在可访问树中是 Text，按精确文字命中实际操作。
        await (await session.waitText('删除')).click();
        await session.inScroll('detail-scroll', ON.text('尚无笔记'));
        const deleted = await session.read();
        expect(activeRecords(deleted.records, 'note').length).assertEqual(0);
        expect(deleted.records.find((record) => record.id === note.id)?.deleted).assertTrue();
        await (await session.waitId('detail-scroll')).scrollToTop(40000);
        await (await session.inScroll('detail-scroll', ON.id('favorite-toggle'))).click();
        await session.inScroll('detail-scroll', ON.text('收藏档案').within(ON.id('favorite-toggle')));
        await session.waitText('收藏档案');
        const unfavorited = await session.read();
        expect(activeRecords(unfavorited.records, 'favorite').length).assertEqual(0);
        expect(unfavorited.records.find((record) => record.id === 'favorite:smx-yangshao')?.deleted).assertTrue();
      });
    });

    it('native_unsaved_draft_close_back_and_keep_editing', 0, async () => {
      const session = new ArchiveUiSession('draft');
      await session.run(async () => {
        await session.openYangshao();
        await (await session.waitId('write-note')).click();
        await (await session.waitId('note-body')).inputText('尚未保存的中文草稿');
        await (await session.inScroll('note-editor-scroll', ON.id('note-tags'))).inputText('草稿标签');
        await (await session.waitId('close-note-editor')).click();
        await session.waitText('放弃尚未保存的修改？');
        await (await session.waitText('继续编辑')).click();
        expect(await (await session.waitId('note-body')).getText()).assertEqual('尚未保存的中文草稿');
        expect(await (await session.inScroll('note-editor-scroll', ON.id('note-tags'))).getText()).assertEqual('草稿标签');
        await session.driver.pressBack();
        await session.waitText('放弃尚未保存的修改？');
        await (await session.waitText('放弃修改')).click();
        await session.editorClosed();
        expect(activeRecords((await session.read()).records, 'note').length).assertEqual(0);
        await (await session.waitId('write-note')).click();
        expect(await (await session.waitId('note-body')).getText()).assertEqual('');
        await (await session.waitId('close-note-editor')).click();
        await session.editorClosed();
      });
    });

    it('native_maximum_note_and_tags_are_saved', 0, async () => {
      const session = new ArchiveUiSession('limits', maximumStoreName);
      await session.run(async () => {
        await session.openYangshao();
        await (await session.waitId('write-note')).click();
        console.info('UI_LIMITS: 开始空白校验');
        await (await session.waitId('note-body')).inputText('  \n  ');
        await (await session.waitId('save-note')).click();
        await session.waitText('笔记内容不能为空');
        console.info('UI_LIMITS: 空白校验通过');
        await (await session.waitId('note-body')).inputText('边界记录');
        await (await session.inScroll('note-editor-scroll', ON.id('note-tags'))).inputText('文'.repeat(41));
        await (await session.waitId('save-note')).click();
        await session.waitText('笔记最多 4000 字；最多 20 个标签，每个标签不超过 40 字');
        console.info('UI_LIMITS: 41 字标签校验通过');
        const excessiveTags: string[] = [];
        for (let index = 0; index < 21; index++) excessiveTags.push(`${index}`);
        await (await session.inScroll('note-editor-scroll', ON.id('note-tags'))).inputText(excessiveTags.join(','));
        await (await session.waitId('save-note')).click();
        await session.waitText('笔记最多 4000 字；最多 20 个标签，每个标签不超过 40 字');
        console.info('UI_LIMITS: 21 个标签校验通过');
        const tags: string[] = [];
        for (let index = 0; index < 20; index++) tags.push(`${index}`.padEnd(40, '文'));
        await session.pasteInto('note-tags', tags.join('，'));
        console.info('UI_LIMITS: 已粘贴 819 字标签，开始 4001 字正文输入');
        await session.pasteInto('note-body', '河'.repeat(4001));
        console.info('UI_LIMITS: 已粘贴 4001 字正文，开始落盘核对上限');
        await (await session.waitId('save-note')).click();
        await session.editorClosed();
        const saved = activeRecords((await session.read()).records, 'note')[0];
        expect(saved.body).assertEqual('河'.repeat(4000));
        expect(saved.tags.join('，')).assertEqual(tags.join('，'));
        console.info('UI_LIMITS: 4000 字正文和完整 20 个标签已确认落盘');
      }, true);
    });

    it('native_maximum_tags_survive_edit_and_expansion', 0, async () => {
      const session = new ArchiveUiSession('limits_edit', maximumStoreName);
      await session.run(async () => {
        const notes = activeRecords((await session.read()).records, 'note');
        if (notes.length !== 1) throw new Error('请先运行 native_maximum_note_and_tags_are_saved 准备真实 UI 保存的边界记录');
        const saved = notes[0];
        const tags = saved.tags.slice();
        expect(saved.body.length).assertEqual(4000);
        expect(tags.length).assertEqual(20);
        await session.openYangshao();
        await (await session.waitId('detail-scroll')).scrollToBottom(40000);
        await (await session.inScroll('detail-scroll', ON.text('展开全文'))).click();
        await (await session.waitText('收起全文')).click();
        await (await session.inScroll('detail-scroll', ON.id(`edit-${saved.id}`))).click();
        // 只修改正文，保存后全部 20 个标签仍应保留，而不是被旧的 300 字输入上限裁掉。
        await session.replaceLongBody('保留完整标签的修改');
        await (await session.waitId('save-note')).click();
        await session.editorClosed();
        expect(activeRecords((await session.read()).records, 'note')[0].tags.join('，')).assertEqual(tags.join('，'));
      });
    });
  });
}
