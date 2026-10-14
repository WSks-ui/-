import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { ArchiveSnapshot, copySnapshot, emptySnapshot, parseSnapshot } from '../domain/ArchiveDomain';

export interface ArchiveRepository {
  load(): Promise<ArchiveSnapshot>;
  save(snapshot: ArchiveSnapshot): Promise<void>;
}

// 首轮用 Preferences 存小体量快照，不声称它是分布式数据库。
// Repository 是唯一存储边界，第二轮迁移到 RDB/KV 时保持页面和领域规则不变。
export class LocalArchiveRepository implements ArchiveRepository {
  private store: preferences.Preferences | undefined = undefined;
  private lastSaved: string = '';
  private tail: Promise<void> = Promise.resolve();
  private context: common.Context;
  private storeName: string;

  constructor(context: common.Context, storeName: string = 'yunheji_archive_v1') {
    this.context = context;
    this.storeName = storeName;
  }

  async load(): Promise<ArchiveSnapshot> {
    try {
      this.store = await preferences.getPreferences(this.context, { name: this.storeName });
      const hasSnapshot = await this.store.has('snapshot');
      const current = await this.store.get('snapshot', '') as string;
      if (!hasSnapshot) {
        // get 在类型不符时也会返回默认值；只有键确实不存在才允许初始化。
        // 当前键丢失但备份仍在时同样停止，避免把可恢复数据替换成空档案。
        if (await this.store.has('previous_snapshot')) throw new Error('ARCHIVE_RECOVERY_REQUIRED');
        const initial = emptySnapshot(util.generateRandomUUID(true));
        await this.save(initial);
        return initial;
      }
      // 读取损坏时禁止静默初始化，否则下一次操作会覆盖用户的真实笔记。
      const snapshot = parseSnapshot(current);
      this.lastSaved = current;
      return snapshot;
    } catch {
      throw new Error('ARCHIVE_READ_FAILED');
    }
  }

  async save(snapshot: ArchiveSnapshot): Promise<void> {
    const payload = JSON.stringify(copySnapshot(snapshot));
    parseSnapshot(payload);
    const write = this.tail.then(async () => {
      const store = this.store;
      if (!store) throw new Error('ARCHIVE_NOT_READY');
      try {
        if (this.lastSaved.length > 0) await store.put('previous_snapshot', this.lastSaved);
        await store.put('snapshot', payload);
        await store.flush();
        this.lastSaved = payload;
      } catch (error) {
        // put 先改变缓存、flush 才落盘；失败时回滚缓存，避免之后的 flush 带入未确认写入。
        if (this.lastSaved.length > 0) await store.put('snapshot', this.lastSaved);
        else await store.delete('snapshot');
        throw new Error('ARCHIVE_WRITE_FAILED');
      }
    });
    this.tail = write.catch(() => {});
    return write;
  }
}
