import { common } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { DEBUG } from 'BuildProfile';
import { AccountSession, AccountSyncReply, validateAccountInput, validateAccountReply, validateAccountSession, validateServiceEndpoint } from '../domain/AccountSync';
import { ArchiveRecord, ArchiveSnapshot, copySnapshot, mergeRecords, parseSnapshot } from '../domain/ArchiveDomain';
import { AiObservationReply, AiObservationRequest, validateAiObservationReply, validateAiObservationRequest } from '../domain/AiObservation';
import { aiKnowledgeScope } from '../domain/AiObservationKnowledge';

interface ServiceConfiguration { endpoint: string; caData: string; }
interface ErrorReply { code: string; }
interface SyncRequest { deviceId: string; records: ArchiveRecord[]; }

export class AccountSyncClient {
  private configuration: ServiceConfiguration | undefined = undefined;
  private session: AccountSession | undefined = undefined;
  private context: common.Context;
  // 在线 AI 一次只允许一个在途请求；停止等待或离开页面时销毁原生请求，迟到结果不能写回新页面。
  private activeAi: http.HttpRequest | undefined = undefined;
  private aiCancelled: boolean = false;

  constructor(context: common.Context) { this.context = context; }

  async configure(): Promise<boolean> {
    // 仅 debug 演示包读取本机 / 局域网服务的公开证书。正式发行须接入具有正式 TLS 的
    // 服务配置；不能把开发机地址、自签证书或访问令牌带进 release。
    // 端点规则集中在领域层校验，避免客户端与服务脚本各写一份正则而漂移。
    if (!DEBUG) return false;
    try {
      const bytes = await this.context.resourceManager.getRawFileContent('account-sync-dev.json');
      const config = JSON.parse(new util.TextDecoder().decodeToString(bytes).replace(/^\uFEFF/, '')) as ServiceConfiguration;
      if (!validateServiceEndpoint(config.endpoint, DEBUG) ||
        typeof config.caData !== 'string' || !config.caData.startsWith('-----BEGIN CERTIFICATE-----')) return false;
      this.configuration = config;
      return true;
    } catch { return false; }
  }

  private async request(path: string, payload: string, readTimeout: number = 10000): Promise<string> {
    const config = this.configuration;
    if (!config) throw new Error('ACCOUNT_SERVICE_NOT_CONFIGURED');
    const request = http.createHttp();
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (this.session) headers['Authorization'] = `Bearer ${this.session.token}`;
    try {
      const result = await request.request(config.endpoint + path, {
        method: http.RequestMethod.POST, header: headers, body: payload,
        caData: config.caData, expectDataType: http.HttpDataType.STRING, usingCache: false,
        usingProxy: false, connectTimeout: 5000, readTimeout
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

  // AI 生成通常比账号同步慢，单独使用更长的读超时；不为了 AI 放宽所有同步请求。
  // 服务端模型超时为 20 秒，客户端读超时 25 秒，留出 HTTPS 与结果校验余量。
  async aiObserve(request: AiObservationRequest): Promise<AiObservationReply> {
    const session = this.session;
    if (!session || session.expiresAt <= Date.now()) throw new Error('ACCOUNT_SESSION_EXPIRED');
    const config = this.configuration;
    if (!config) throw new Error('ACCOUNT_SERVICE_NOT_CONFIGURED');
    const scope = aiKnowledgeScope(request.siteId);
    if (!scope) throw new Error('AI_INVALID_REQUEST');
    const validated = validateAiObservationRequest(request, scope);
    this.aiCancelled = false;
    const httpRequest = http.createHttp();
    this.activeAi = httpRequest;
    try {
      const result = await httpRequest.request(config.endpoint + '/ai/observe', {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${session.token}` },
        body: JSON.stringify(validated),
        caData: config.caData, expectDataType: http.HttpDataType.STRING, usingCache: false,
        usingProxy: false, connectTimeout: 5000, readTimeout: 25000
      });
      if (typeof result.result !== 'string') throw new Error('ACCOUNT_INVALID_RESPONSE');
      if (result.responseCode !== 200) {
        let code = 'ACCOUNT_NETWORK_ERROR';
        try { code = (JSON.parse(result.result) as ErrorReply).code; } catch {}
        throw new Error(/^(ACCOUNT|AI)_[A-Z_]+$/.test(code) ? code : 'ACCOUNT_NETWORK_ERROR');
      }
      const reply = JSON.parse(result.result) as AiObservationReply;
      return validateAiObservationReply(reply, validated, scope);
    } catch (error) {
      // 主动停止等待时，销毁请求触发的底层异常统一标记为取消，页面不显示成网络失败。
      if (this.aiCancelled) throw new Error('AI_REQUEST_CANCELLED');
      const message = (error as Error).message;
      throw new Error(message || 'ACCOUNT_NETWORK_ERROR');
    } finally {
      if (this.activeAi === httpRequest) {
        this.activeAi = undefined;
        httpRequest.destroy();
      }
    }
  }

  cancelAi(): void {
    this.aiCancelled = true;
    const active = this.activeAi;
    this.activeAi = undefined;
    if (active) active.destroy();
  }

  async logout(): Promise<void> {
    this.cancelAi();
    try { if (this.session) await this.request('/auth/logout', '{}'); }
    finally { this.session = undefined; }
  }

  clearSession(): void { this.cancelAi(); this.session = undefined; }
}
