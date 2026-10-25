export interface DistributedArchiveStatus {
  phase: string;
  recordCount: number;
  deviceCount: number;
  lastSuccessfulSync: number;
  message: string;
}

export function initialDistributedStatus(): DistributedArchiveStatus {
  return { phase: 'closed', recordCount: 0, deviceCount: -1, lastSuccessfulSync: 0,
    message: '登录后可启用鸿蒙设备同步' };
}

export function distributedPhaseLabel(phase: string): string {
  if (phase === 'ready') return '本机分布式库已就绪';
  if (phase === 'permission') return '需要设备同步授权';
  if (phase === 'waiting') return '等待可信设备';
  if (phase === 'syncing') return '正在传输';
  if (phase === 'synced') return '平台传输已完成';
  if (phase === 'unsupported') return '当前环境不支持';
  if (phase === 'error') return '暂时无法同步';
  return '尚未启用';
}
