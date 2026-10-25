import { abilityAccessCtrl, bundleManager, common, Permissions } from '@kit.AbilityKit';
import { distributedKVStore } from '@kit.ArkData';
import { distributedDeviceManager } from '@kit.DistributedServiceKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { ArchiveRecord, ArchiveSnapshot, copySnapshot, mergeRecords, parseSnapshot } from '../domain/ArchiveDomain';
import { DistributedArchiveStatus, initialDistributedStatus } from '../domain/DistributedArchive';

const BUNDLE: string = 'com.yunheji.archive';
const PERMISSION: Permissions = 'ohos.permission.DISTRIBUTED_DATASYNC';
const PREFIX: string = 'record_v1_';

// 记录版本以内容摘要作为不可变键。不同设备离线修改同一篇时会留下两个键，
// 平台传输并集，再由现有 compareVersions/mergeRecords 裁决，避免底层 KV
// 把同一逻辑 ID 的另一版本提前覆盖。墓碑、视角和 AI 冻结事实原样保留。
// Preferences 继续作为已确认快照与迁移回退；本轮不删除旧库或把无对端写库称为同步成功。
export class DistributedArchiveChannel {
  private context: common.UIAbilityContext;
  private manager: distributedKVStore.KVManager | undefined = undefined;
  private store: distributedKVStore.SingleKVStore | undefined = undefined;
  private devices: distributedDeviceManager.DeviceManager | undefined = undefined;
  private storeId: string = '';
  private testScope: boolean = false;
  private knownKeys: Set<string> = new Set<string>();
  private state: DistributedArchiveStatus = initialDistributedStatus();
  private sink: (state: DistributedArchiveStatus) => void;
  private busy: boolean = false;
  private disposed: boolean = false;
  private syncTimer: number = -1;
  private completion: (result: [string, number][]) => void = (result: [string, number][]) => {
    if (this.disposed) return;
    if (this.syncTimer >= 0) clearTimeout(this.syncTimer);
    this.syncTimer = -1;
    const complete = result.length > 0 && result.every((item: [string, number]) => item[1] === 0);
    if (complete) this.state.lastSuccessfulSync = Date.now();
    this.publish(complete ? 'synced' : 'error', complete ? '可信设备间平台传输已完成' : '平台未确认全部设备传输成功');
  };

  constructor(context: common.UIAbilityContext, sink: (state: DistributedArchiveStatus) => void = () => {}) {
    this.context = context;
    this.sink = sink;
  }

  private publish(phase: string, message: string): void {
    if (this.disposed) return;
    this.state = { phase, message, recordCount: this.state.recordCount, deviceCount: this.state.deviceCount,
      lastSuccessfulSync: this.state.lastSuccessfulSync };
    this.sink(this.state);
  }

  private async hash(value: string): Promise<string> {
    const digest = cryptoFramework.createMd('SHA256');
    await digest.update({ data: new util.TextEncoder().encodeInto(value) });
    return Array.from((await digest.digest()).data).map((byte: number) => byte.toString(16).padStart(2, '0')).join('');
  }

  async open(accountId: string, scope: string = ''): Promise<boolean> {
    if (!/^[a-f0-9]{32}$/.test(accountId)) throw new Error('ACCOUNT_INVALID_RESPONSE');
    if (scope && !/^yunheji_test_ui_[a-z0-9_]{1,80}$/.test(scope)) throw new Error('ACCOUNT_INVALID_TEST_STORE');
    this.disposed = false;
    this.testScope = scope.length > 0;
    try {
      if (!canIUse('SystemCapability.DistributedDataManager.KVStore.DistributedKVStore')) {
        this.publish('unsupported', '模拟器没有提供分布式数据库能力'); return false;
      }
      this.storeId = `yunheji_v1_${await this.hash(`${scope}:${accountId}`)}`;
      this.manager = distributedKVStore.createKVManager({ bundleName: BUNDLE, context: this.context });
      this.store = await this.manager.getKVStore<distributedKVStore.SingleKVStore>(this.storeId, {
        createIfMissing: true, encrypt: true, backup: true, autoSync: false,
        kvStoreType: distributedKVStore.KVStoreType.SINGLE_VERSION,
        securityLevel: distributedKVStore.SecurityLevel.S1
      });
      this.store.on('syncComplete', this.completion);
      this.publish('ready', '本机记录按版本写入；跨端状态以真实平台回调为准');
      return true;
    } catch (error) {
      this.publish('error', `分布式库暂不可用（${(error as BusinessError).code || '平台错误'}）`);
      return false;
    }
  }

  private async permitted(): Promise<boolean> {
    const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
    return await abilityAccessCtrl.createAtManager().checkAccessToken(info.appInfo.accessTokenId, PERMISSION) ===
      abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
  }

  async requestPermission(): Promise<boolean> {
    const result = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(this.context, [PERMISSION]);
    return result.authResults.length === 1 && result.authResults[0] === 0;
  }

  async exchange(snapshot: ArchiveSnapshot): Promise<ArchiveRecord[]> {
    const store = this.store;
    if (!store || this.busy || this.disposed) return snapshot.records;
    this.busy = true;
    try {
      const entries = await store.getEntries(PREFIX);
      const versions: ArchiveRecord[] = [];
      entries.forEach((entry: distributedKVStore.Entry) => {
        if (typeof entry.value.value !== 'string') throw new Error('DISTRIBUTED_RECORD_INVALID');
        // 每条先用正式 v1 校验器检查，再合并逻辑 ID，不能静默丢弃损坏版本。
        const envelope = copySnapshot(snapshot);
        envelope.records = [JSON.parse(entry.value.value as string) as ArchiveRecord];
        versions.push(parseSnapshot(JSON.stringify(envelope)).records[0]);
        this.knownKeys.add(entry.key);
      });
      for (const record of snapshot.records) {
        const raw = JSON.stringify(record);
        const key = PREFIX + await this.hash(raw);
        if (!this.knownKeys.has(key)) {
          await store.put(key, raw);
          this.knownKeys.add(key);
        }
      }
      const merged = mergeRecords(snapshot.records, versions).records;
      this.state.recordCount = merged.length;
      if (!await this.permitted()) {
        this.publish('permission', '本机记录已写入；授权后查询系统可信设备'); return merged;
      }
      if (!this.devices) this.devices = distributedDeviceManager.createDeviceManager(BUNDLE);
      const peers = this.devices.getAvailableDeviceListSync();
      const ids = peers.filter((peer: distributedDeviceManager.DeviceBasicInfo) => Boolean(peer.networkId))
        .map((peer: distributedDeviceManager.DeviceBasicInfo) => peer.networkId!);
      this.state.deviceCount = ids.length;
      if (ids.length === 0) {
        this.publish('waiting', '系统未发现可用可信设备；账号网络同步可继续使用');
      } else if (this.syncTimer < 0) {
        this.publish('syncing', '正在与系统可信设备交换记录版本');
        this.syncTimer = setTimeout(() => {
          this.syncTimer = -1;
          this.publish('error', '平台传输未在 20 秒内确认，请重试');
        }, 20000);
        try { store.sync(ids, distributedKVStore.SyncMode.PUSH_PULL); }
        catch (error) {
          clearTimeout(this.syncTimer); this.syncTimer = -1;
          throw new Error(`DISTRIBUTED_SYNC_${(error as BusinessError).code || 'FAILED'}`);
        }
      }
      return merged;
    } catch (error) {
      this.publish('error', `本机档案仍保留；${(error as Error).message || '平台交换失败'}`);
      throw new Error('DISTRIBUTED_EXCHANGE_FAILED');
    } finally { this.busy = false; }
  }

  status(): DistributedArchiveStatus { return this.state; }

  async close(): Promise<void> {
    this.disposed = true;
    if (this.syncTimer >= 0) clearTimeout(this.syncTimer);
    this.syncTimer = -1;
    try { this.store?.off('syncComplete', this.completion); } catch { }
    if (this.devices) { try { distributedDeviceManager.releaseDeviceManager(this.devices); } catch { } }
    this.devices = undefined;
    const manager = this.manager;
    this.store = undefined;
    if (manager && this.storeId) { try { await manager.closeKVStore(BUNDLE, this.storeId); } catch { } }
  }

  async cleanupTestStore(): Promise<void> {
    // 仅供独立设备测试收尾，正式账号库绝不能经此入口删除。
    if (!this.testScope || !this.storeId) throw new Error('DISTRIBUTED_NOT_A_TEST_STORE');
    await this.close();
    if (this.manager) await this.manager.deleteKVStore(BUNDLE, this.storeId);
  }
}
