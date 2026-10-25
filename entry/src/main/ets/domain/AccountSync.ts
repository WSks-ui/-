import type { ArchiveRecord } from './ArchiveDomain';

export interface AccountSession {
  accountId: string;
  username: string;
  token: string;
  expiresAt: number;
}

export interface AccountWorkspace {
  version: number;
  accountId: string;
  username: string;
}

// 本机账号身份与网络会话分开。会话过期不影响离线访问原账号工作区，
// 但不能继续调用同步或 AI；用户名和账号 ID 仅接受此前真实认证写入的值。
export function parseAccountWorkspace(raw: string): AccountWorkspace {
  const value = JSON.parse(raw) as AccountWorkspace;
  if (!value || value.version !== 1 || !/^[a-f0-9]{32}$/.test(value.accountId) ||
    !/^[a-z0-9_]{4,32}$/.test(value.username)) throw new Error('ACCOUNT_WORKSPACE_INVALID');
  return { version: 1, accountId: value.accountId, username: value.username };
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
  sessionReady: boolean;
  username: string;
  busy: boolean;
  syncing: boolean;
  serviceConfigured: boolean;
  otherDevices: number;
  lastSync: number;
  // 账号历史落败版本总数（服务端累计），用于说明“这个账号一共留下过多少旧版本”。
  conflictCount: number;
  message: string;
  pendingCount: number;
  // 本机记录总数与“本次合并产生的冲突数”。两者用于画真实进度条，
  // 不能拿服务端累计值冒充本次冲突，否则面板上的数字会对不上刚发生的事。
  recordCount: number;
  mergeConflicts: number;
}

export interface AccountViewChange {
  signedIn?: boolean;
  sessionReady?: boolean;
  username?: string;
  busy?: boolean;
  syncing?: boolean;
  serviceConfigured?: boolean;
  otherDevices?: number;
  lastSync?: number;
  conflictCount?: number;
  message?: string;
  pendingCount?: number;
  recordCount?: number;
  mergeConflicts?: number;
}

export function changedAccountView(view: AccountView, change: AccountViewChange): AccountView {
  // ArkTS 不支持对象展开；每次发布完整状态，使异步同步反馈可靠触发 @Prop 更新。
  return {
    signedIn: change.signedIn ?? view.signedIn, sessionReady: change.sessionReady ?? view.sessionReady,
    username: change.username ?? view.username,
    busy: change.busy ?? view.busy, syncing: change.syncing ?? view.syncing,
    serviceConfigured: change.serviceConfigured ?? view.serviceConfigured,
    otherDevices: change.otherDevices ?? view.otherDevices, lastSync: change.lastSync ?? view.lastSync,
    conflictCount: change.conflictCount ?? view.conflictCount, message: change.message ?? view.message,
    pendingCount: change.pendingCount ?? view.pendingCount,
    recordCount: change.recordCount ?? view.recordCount,
    mergeConflicts: change.mergeConflicts ?? view.mergeConflicts
  };
}

export function guestAccountView(): AccountView {
  return {
    signedIn: false, sessionReady: false, username: '', busy: false, syncing: false, serviceConfigured: false,
    otherDevices: -1, lastSync: 0, conflictCount: 0, message: '', pendingCount: 0,
    recordCount: 0, mergeConflicts: 0
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

// 校赛演示的服务端点白名单：只允许本机回环与私有局域网 IPv4，并且只在 debug 包生效。
// 原因：账号与 AI 服务跑在开发机（或同网段电脑）上，模拟器经 HDC 反向端口 / 局域网访问；
// release 不能继续信任自签证书，因此这里直接拒绝，正式发布须另配受信任的 TLS 端点。
// 修改边界：调整 host / 端口规则时，必须同步更新 tools/domain.test.mjs 的边界用例，
// 并确认 tools/start-account-server.ps1 写入的证书 SAN 覆盖新地址，否则 HTTPS 会校验证书失败。
export function validateServiceEndpoint(endpoint: string, debug: boolean): boolean {
  if (!debug) return false;
  const match = /^https:\/\/([^/:]+):(\d{4,5})$/.exec(endpoint);
  if (!match) return false;
  const port = Number(match[2]);
  if (!Number.isInteger(port) || port < 1024 || port > 65535) return false;
  const host = match[1];
  if (host === 'localhost') return true;
  const parts = host.split('.').map((value: string) => Number(value));
  if (parts.length !== 4) return false;
  for (const value of parts) {
    if (!Number.isInteger(value) || value < 0 || value > 255) return false;
  }
  // 127.0.0.0/8 为回环；10/8、172.16/12、192.168/16 为私有网段。
  if (parts[0] === 127 || parts[0] === 10) return true;
  if (parts[0] === 192 && parts[1] === 168) return true;
  if (parts[0] === 172 && parts[1] >= 16 && parts[1] <= 31) return true;
  return false;
}

// 公网服务使用系统受信任 TLS，不读取调试 CA。这里只校验完整 HTTPS origin；
// 实际域名由随包 account-service.json 提供，没有配置时绝不猜测或连接示例域名。
export function validatePublicServiceEndpoint(endpoint: string): boolean {
  const match = /^https:\/\/([a-z0-9](?:[a-z0-9.-]*[a-z0-9])?)(?::([0-9]{1,5}))?$/.exec(endpoint);
  if (!match) return false;
  const host = match[1];
  if (!host.includes('.') || /^[0-9.]+$/.test(host) || host.endsWith('.local') || host.endsWith('.localhost')) return false;
  if (host.split('.').some((label: string) => !/^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/.test(label))) return false;
  if (match[2] && (Number(match[2]) < 1 || Number(match[2]) > 65535)) return false;
  return true;
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
