import { ON } from '@kit.TestKit';
import { preferences } from '@kit.ArkData';
import { describe, it, expect } from '@ohos/hypium';
import { LocalArchiveRepository } from '../../../main/ets/data/LocalArchiveRepository';
import { ArchiveRecord, copySnapshot } from '../../../main/ets/domain/ArchiveDomain';
import { TestContext } from './TestContext';
import { ArchiveUiSession } from './ArchiveUiSession';

export default function archiveDeviceTest() {
  describe('ArchiveDeviceTest', () => {
    it('preferences_round_trip_after_cache_eviction', 0, async () => {
      const context = TestContext.context;
      const name = `yunheji_test_roundtrip_${Date.now()}`;
      const repo = new LocalArchiveRepository(context, name);
      const initial = await repo.load();
      const next = copySnapshot(initial);
      const note: ArchiveRecord = {
        id: 'note:test', kind: 'note', siteId: 'ly-erlitou', body: '设备端中文持久化测试',
        tags: ['研究资料'], updatedAt: 123456, deviceId: next.deviceId, deleted: false
      };
      next.records = [note];
      await repo.save(next);
      await preferences.removePreferencesFromCache(context, name);
      const restored = await new LocalArchiveRepository(context, name).load();
      expect(restored.records[0].body).assertEqual(note.body);
      expect(restored.deviceId).assertEqual(initial.deviceId);
      await preferences.deletePreferences(context, name);
    });

    it('corrupt_snapshot_is_not_overwritten', 0, async () => {
      const context = TestContext.context;
      const name = `yunheji_test_corrupt_${Date.now()}`;
      const store = await preferences.getPreferences(context, { name });
      await store.put('snapshot', '{broken');
      await store.flush();
      let rejected = false;
      try { await new LocalArchiveRepository(context, name).load(); }
      catch { rejected = true; }
      expect(rejected).assertTrue();
      expect(await store.get('snapshot', '')).assertEqual('{broken');
      await preferences.deletePreferences(context, name);
    });

    it('queued_saves_keep_latest_and_previous_snapshot', 0, async () => {
      const context = TestContext.context;
      const name = `yunheji_test_queue_${Date.now()}`;
      const repo = new LocalArchiveRepository(context, name);
      const initial = await repo.load();
      const first = copySnapshot(initial);
      first.lightEnabled = false;
      const second = copySnapshot(first);
      second.reducedMotion = true;
      await Promise.all([repo.save(first), repo.save(second)]);
      await preferences.removePreferencesFromCache(context, name);
      const restored = await new LocalArchiveRepository(context, name).load();
      expect(restored.reducedMotion).assertTrue();
      expect(restored.lightEnabled).assertFalse();
      const store = await preferences.getPreferences(context, { name });
      expect(await store.get('previous_snapshot', '')).assertEqual(JSON.stringify(first));
      await preferences.deletePreferences(context, name);
    });

    it('native_search_detail_and_note_validation', 0, async () => {
      const session = new ArchiveUiSession('search');
      await session.run(async () => {
        await session.search('不存在的文化条目', 0);
        await session.inScroll('device-scroll', ON.text('没有符合条件的档案'));
        await session.openYangshao();
        await (await session.waitId('write-note')).click();
        await (await session.waitId('save-note')).click();
        await session.waitText('笔记内容不能为空');
        await (await session.waitId('close-note-editor')).click();
        await session.editorClosed();
        await session.driver.pressBack();
        // 新目录保留离开前的滚动位置；搜索框可能在屏幕上方，先确认目录返回再滚到输入框。
        await session.inScroll('device-scroll', ON.id('library-search'));
      });
    });

    it('existing_invalid_values_are_not_initialized_over', 0, async () => {
      const values: preferences.ValueType[] = ['', true, 17];
      for (let index = 0; index < values.length; index++) {
        const name = `yunheji_test_invalid_${Date.now()}_${index}`;
        try {
          const store = await preferences.getPreferences(TestContext.context, { name });
          await store.put('snapshot', values[index]);
          await store.flush();
          let rejected = false;
          try { await new LocalArchiveRepository(TestContext.context, name).load(); }
          catch { rejected = true; }
          expect(rejected).assertTrue();
          expect(await store.get('snapshot', values[index])).assertEqual(values[index]);
        } finally { await preferences.deletePreferences(TestContext.context, name); }
      }
    });

    it('orphaned_previous_snapshot_is_preserved_for_recovery', 0, async () => {
      const name = `yunheji_test_orphan_${Date.now()}`;
      try {
        const store = await preferences.getPreferences(TestContext.context, { name });
        await store.put('previous_snapshot', '{original-backup}');
        await store.flush();
        let rejected = false;
        try { await new LocalArchiveRepository(TestContext.context, name).load(); }
        catch { rejected = true; }
        expect(rejected).assertTrue();
        expect(await store.has('snapshot')).assertFalse();
        expect(await store.get('previous_snapshot', '')).assertEqual('{original-backup}');
      } finally { await preferences.deletePreferences(TestContext.context, name); }
    });
  });
}
