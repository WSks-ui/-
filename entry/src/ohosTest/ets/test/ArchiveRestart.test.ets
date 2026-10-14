import { abilityDelegatorRegistry, ON } from '@kit.TestKit';
import { describe, expect, it } from '@ohos/hypium';
import { activeRecords } from '../../../main/ets/domain/ArchiveDomain';
import { ArchiveUiSession } from './ArchiveUiSession';

// 单个 Hypium 进程不能把自己强杀后继续断言。仅当外部脚本传入独立库名时注册
// 两阶段场景，准备阶段经真实 UI 保存；脚本核实 PID 消失后在新进程启动验证阶段。
export default function archiveRestartTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  // AbilityDelegator 保留原始 aa test 参数键（含 '-s '）；Hypium 的内部配置才去掉前缀。
  const storeName = parameters['archiveRestartStore'] || parameters['-s archiveRestartStore'];
  if (!storeName || !/^yunheji_test_ui_restart_[a-z0-9_]{1,60}$/.test(storeName)) return;
  describe('ArchiveRestartTest', () => {
    it('prepare_process_restart', 0, async () => {
      const session = new ArchiveUiSession('restart', storeName);
      await session.run(async () => {
        await session.openYangshao();
        await (await session.waitId('favorite-toggle')).click();
        await session.waitText('已收藏');
        await (await session.waitId('write-note')).click();
        await (await session.waitId('note-body')).inputText('进程重启后仍应保留的中文笔记');
        await (await session.inScroll('note-editor-scroll', ON.id('note-tags'))).inputText('持久化，重启验证');
        await (await session.waitId('save-note')).click();
        await session.editorClosed();
        expect(activeRecords((await session.read()).records, 'note').length).assertEqual(1);
      }, true);
    });

    it('verify_after_process_restart', 0, async () => {
      const session = new ArchiveUiSession('restart', storeName);
      await session.run(async () => {
        const saved = await session.read();
        const note = activeRecords(saved.records, 'note')[0];
        expect(note.body).assertEqual('进程重启后仍应保留的中文笔记');
        expect(note.tags.join('|')).assertEqual('持久化|重启验证');
        expect(activeRecords(saved.records, 'favorite')[0].siteId).assertEqual('smx-yangshao');
        await (await session.waitId('tab-1')).click();
        await (await session.inScroll('archive-scroll', ON.id('site-row-smx-yangshao'))).click();
        await session.waitText('已收藏');
        await (await session.waitId('detail-scroll')).scrollToBottom(40000);
        await (await session.inScroll('detail-scroll', ON.id(`edit-${note.id}`))).click();
        expect(await (await session.waitId('note-body')).getText()).assertEqual(note.body);
        expect(await (await session.inScroll('note-editor-scroll', ON.id('note-tags'))).getText()).assertEqual('持久化，重启验证');
        await (await session.waitId('close-note-editor')).click();
        await session.editorClosed();
      });
    });
  });
}
