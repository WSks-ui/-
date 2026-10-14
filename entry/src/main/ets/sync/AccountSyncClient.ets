import { common } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { DEBUG } from 'BuildProfile';
import { AccountSession, AccountSyncReply, validateAccountInput, validateAccountReply, validateAccountSession } from '../domain/AccountSync';
import { ArchiveRecord, ArchiveSnapshot, copySnapshot, mergeRecords, parseSnapshot } from '../domain/ArchiveDomain';

interface ServiceConfiguration { endpoint: string; caData: string; }
interface ErrorReply { code: string; }
interface SyncRequest { deviceId: string; records: ArchiveRecord[]; }

export class AccountSyncClient {
  private configuration: ServiceConfiguration | undefined = undefined;
  private session: AccountSession | undefined = undefined;
  private context: common.Context;

  constructor(context: common.Context) { this.context = context; }

  async configure(): Promise<boolean> {
    // 仅 debug 演示包读取本机服务的公开证书。正式发行须接入具有正式 TLS 的
    // 服务配置；不能把本机地址、开发证书或访问令牌带进 release。
    if (!DEBUG) return false;
    try {
      const bytes = await this.context.resourceManager.getRawFileContent('account-sync-dev.json');
      const config = JSON.parse(new util.TextDecoder().decodeToString(bytes).replace(/^\uFEFF/, '')) as ServiceConfiguration;
      if (!/^https:\/\/127\.0\.0\.1:[0-9]{4,5}$/.test(config.endpoint) ||
        typeof config.caData !== 'string' || !config.caData.startsWith('-----BEGIN CERTIFICATE-----')) return false;
      this.configuration = config;
      return true;
    } catch { return false; }
  }

  private async request(path: string, payload: string): Promise<string> {
    const config = this.configuration;
    if (!config) throw new Error('ACCOUNT_SERVICE_NOT_CONFIGURED');
    const request = http.createHttp();
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (this.session) headers['Authorization'] = `Bearer ${this.session.token}`;
    try {
      const result = await request.request(config.endpoint + path, {
        method: http.RequestMethod.POST, header: headers, body: payload,
        caData: config.caData, expectDataType: http.HttpDataType.STRING, usingCache: false,
        usingProxy: false, connectTimeout: 5000, readTimeout: 10000
      });
      if (typeof result.result !== 'string') throw new Error('ACCOUNT_INVALID_RESPONSE');
      if (result.responseCode !== 200) {
        let code = 'ACCOUNT_NETWORK_ERROR';
        try { code = (JSON.parse(result.result) as ErrorReply).code; } catch {}
        throw new Error(/^ACCOUNT_[A-Z_]+$/.test(code) ? code : 'ACCOUNT_NETWORK_ERROR');
      }
      return result.result;
    } finally { request.destroy(); }
  }

  async authenticate(username: string, password: string, register: boolean): Promise<AccountSession> {
    validateAccountInput(username, password);
    const response = await this.request(register ? '/auth/register' : '/auth/login', JSON.stringify({ username, password }));
    this.session = validateAccountSession(JSON.parse(response) as AccountSession);
    return this.session;
  }

  async exchange(snapshot: ArchiveSnapshot): Promise<AccountSyncReply> {
    const session = this.session;
    if (!session || session.expiresAt <= Date.now()) throw new Error('ACCOUNT_SESSION_EXPIRED');
    const payload: SyncRequest = { deviceId: snapshot.deviceId, records: snapshot.records };
    const reply = JSON.parse(await this.request('/sync', JSON.stringify(payload))) as AccountSyncReply;
    validateAccountReply(reply, session.accountId);
    // 复用正式 v1 解析器验证每条远端内容；偏好 / 安装身份不从网络覆盖。
    try {
      parseSnapshot(JSON.stringify({ schemaVersion: 1, deviceId: snapshot.deviceId, records: reply.records,
        lightEnabled: snapshot.lightEnabled, reducedMotion: snapshot.reducedMotion }));
    } catch { throw new Error('ACCOUNT_INVALID_RESPONSE'); }
    return reply;
  }

  mergedSnapshot(snapshot: ArchiveSnapshot, reply: AccountSyncReply): ArchiveSnapshot {
    const next = copySnapshot(snapshot);
    next.records = mergeRecords(snapshot.records, reply.records).records;
    return next;
  }

  async logout(): Promise<void> {
    try { if (this.session) await this.request('/auth/logout', '{}'); }
    finally { this.session = undefined; }
  }

  clearSession(): void { this.session = undefined; }
}
