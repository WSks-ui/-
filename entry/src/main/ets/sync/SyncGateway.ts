import type { ArchiveRecord } from '../domain/ArchiveDomain';

export interface SyncStatus {
  mode: string;
  connectedDevices: number;
  lastSuccessfulSync: number;
  conflictCount: number;
  message: string;
}

export interface SyncGateway {
  status(): SyncStatus;
  exchange(records: ArchiveRecord[]): Promise<ArchiveRecord[]>;
}

// 不伪装为网络同步：没有真实传输适配器时，界面必须显示未接入，时间不能填本地保存时间。
export class UnavailableSyncGateway implements SyncGateway {
  status(): SyncStatus {
    return {
      mode: 'unavailable', connectedDevices: 0, lastSuccessfulSync: 0, conflictCount: 0,
      message: '本地档案模式 · 跨设备同步尚未接入'
    };
  }

  async exchange(_records: ArchiveRecord[]): Promise<ArchiveRecord[]> {
    throw new Error('DISTRIBUTED_SYNC_NOT_CONFIGURED');
  }
}
