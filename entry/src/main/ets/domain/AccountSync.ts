import type { ArchiveRecord } from './ArchiveDomain';

export interface AccountSession {
  accountId: string;
  username: string;
  token: string;
  expiresAt: number;
}

export interface AccountSyncReply {
  accountId: string;
  records: ArchiveRecord[];
  otherDevices: number;
  conflictCount: number;
  serverTime: number;
}

export interface AccountView {
  signedIn: boolean;
  username: string;
  busy: boolean;
  syncing: boolean;
  serviceConfigured: boolean;
  otherDevices: number;
  lastSync: number;
  conflictCount: number;
  message: string;
}

export interface AccountViewChange {
  signedIn?: boolean;
  username?: string;
  busy?: boolean;
  syncing?: boolean;
  serviceConfigured?: boolean;
  otherDevices?: number;
  lastSync?: number;
  conflictCount?: number;
  message?: string;
}

export function changedAccountView(view: AccountView, change: AccountViewChange): AccountView {
  // ArkTS 不支持对象展开；每次发布完整状态，使异步同步反馈可靠触发 @Prop 更新。
  return {
    signedIn: change.signedIn ?? view.signedIn, username: change.username ?? view.username,
    busy: change.busy ?? view.busy, syncing: change.syncing ?? view.syncing,
    serviceConfigured: change.serviceConfigured ?? view.serviceConfigured,
    otherDevices: change.otherDevices ?? view.otherDevices, lastSync: change.lastSync ?? view.lastSync,
    conflictCount: change.conflictCount ?? view.conflictCount, message: change.message ?? view.message
  };
}

export function guestAccountView(): AccountView {
  return {
    signedIn: false, username: '', busy: false, syncing: false, serviceConfigured: false,
    otherDevices: -1, lastSync: 0, conflictCount: 0, message: ''
  };
}

export function accountStoreName(accountId: string, testStore: string = ''): string {
  // 账号身份来自已认证服务端，不接受任意库名或把安装 ID 当账号；游客库保留原值。
  if (!/^[a-f0-9]{32}$/.test(accountId)) throw new Error('ACCOUNT_INVALID_RESPONSE');
  if (testStore && !/^yunheji_test_ui_[a-z0-9_]{1,80}$/.test(testStore)) throw new Error('ACCOUNT_INVALID_TEST_STORE');
  return testStore ? `${testStore}_account_${accountId}` : `yunheji_account_v1_${accountId}`;
}

export function validateAccountInput(username: string, password: string): void {
  if (!/^[a-zA-Z0-9_]{4,32}$/.test(username.trim())) throw new Error('ACCOUNT_INVALID_NAME');
  if (password.length < 10 || password.length > 128) throw new Error('ACCOUNT_INVALID_PASSWORD');
}

export function validateAccountSession(value: AccountSession): AccountSession {
  if (!value || !/^[a-f0-9]{32}$/.test(value.accountId) || !/^[a-z0-9_]{4,32}$/.test(value.username) ||
    !/^[a-f0-9]{64}$/.test(value.token) || !Number.isSafeInteger(value.expiresAt) || value.expiresAt <= Date.now()) {
    throw new Error('ACCOUNT_INVALID_RESPONSE');
  }
  return value;
}

export function validateAccountReply(reply: AccountSyncReply, accountId: string): void {
  // 账号切换隔离于 v1 快照之外。远端身份、记录和统计都须验证，不能让错误响应
  // 覆盖本机档案；设备 ID / 阅读偏好留在本机，墓碑随记录同步且不得硬删除。
  if (!reply || reply.accountId !== accountId || !Number.isSafeInteger(reply.otherDevices) || reply.otherDevices < 0 ||
    !Number.isSafeInteger(reply.conflictCount) || reply.conflictCount < 0 ||
    !Number.isSafeInteger(reply.serverTime) || reply.serverTime <= 0) throw new Error('ACCOUNT_INVALID_RESPONSE');
  if (!Array.isArray(reply.records)) throw new Error('ACCOUNT_INVALID_RESPONSE');
}

export function accountErrorMessage(code: string): string {
  switch (code) {
    case 'ACCOUNT_INVALID_NAME': return '账号使用 4—32 位字母、数字或下划线。';
    case 'ACCOUNT_INVALID_PASSWORD': return '密码长度为 10—128 位。';
    case 'ACCOUNT_EXISTS': return '这个账号已注册，请直接登录。';
    case 'ACCOUNT_INVALID_CREDENTIALS': return '账号或密码不正确。';
    case 'ACCOUNT_SESSION_EXPIRED': return '登录已过期，请重新登录。本机记录仍已保存。';
    case 'ACCOUNT_RATE_LIMITED': return '尝试次数较多，请稍后重试。';
    case 'ACCOUNT_SERVICE_NOT_CONFIGURED': return '账号服务尚未接入，仍可在本机浏览和记录。';
    case 'ACCOUNT_INVALID_RESPONSE': return '同步内容校验失败，本机档案未被替换。';
    case 'ACCOUNT_TIME_INVALID': return '设备时间偏差较大，请校准时间后重试。';
    case 'ACCOUNT_LOCAL_SAVE_FAILED': return '同步记录暂时无法保存，当前本机档案仍保留，请稍后重试。';
    case 'ARCHIVE_READ_FAILED': return '账号档案读取失败，已有记录仍保留，请稍后重试。';
    default: return '暂时无法连接账号服务。记录已保存在本机，连接恢复后会重试。';
  }
}
