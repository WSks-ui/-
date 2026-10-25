import { common } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { AccountSession, AccountSyncReply, validateAccountInput, validateAccountReply, validateAccountSession } from '../domain/AccountSync';
import { loadServiceConfiguration, ServiceConfiguration } from './ServiceConfiguration';
import { ArchiveRecord, ArchiveSnapshot, copySnapshot, mergeRecords, parseSnapshot } from '../domain/ArchiveDomain';
import { AiObservationReply, AiObservationRequest, validateAiObservationReply, validateAiObservationRequest } from '../domain/AiObservation';
import { aiKnowledgeScope } from '../domain/AiObservationKnowledge';
import {
  KaifengAiAnswer, KaifengAiColophon, KaifengAiColophonResult, KaifengAiRequest,
  validateKaifengAiAnswer, validateKaifengAiRequest, validateKaifengColophon
} from '../domain/KaifengAi';

interface ErrorReply { code: string; }
interface SyncRequest { deviceId: string; records: ArchiveRecord[]; }

export class AccountSyncClient {
  private configuration: ServiceConfiguration | undefined = undefined;
  private session: AccountSession | undefined = undefined;
  private context: common.Context;
  // 在线 AI 一次只允许一个在途请求；停止等待或离开页面时销毁原生请求，迟到结果不能写回新页面。
  private activeAi: http.HttpRequest | undefined = undefined;
  private aiCancelled: boolean = false;
  // 本次合并的冲突数只来自最近一次 mergeRecords；服务端返回的 conflictCount 是
  // 账号历史累计值，两者含义不同，面板必须分开显示，不能互相冒充。
  private lastMergeConflicts: number = 0;

  constructor(context: common.Context) { this.context = context; }

  async configure(): Promise<boolean> {
    this.configuration = await loadServiceConfiguration(this.context);
    return this.configuration !== undefined;
  }

  restoreSession(session: AccountSession): void { this.session = validateAccountSession(session); }

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
    const merged = mergeRecords(snapshot.records, reply.records);
    // 记录冲突条数供同步面板展示“本次”，落败内容已由服务端留档，客户端不回写。
    this.lastMergeConflicts = merged.conflicts.length;
    next.records = merged.records;
    return next;
  }

  mergeConflictCount(): number { return this.lastMergeConflicts; }

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

  // 开封 AI 与观察导览分开在途请求：一个在等模型时切去另一处，不应互相取消。
  private activeKaifeng: http.HttpRequest | undefined = undefined;

  private async kaifengPost(request: KaifengAiRequest): Promise<string> {
    const session = this.session;
    if (!session || session.expiresAt <= Date.now()) throw new Error('ACCOUNT_SESSION_EXPIRED');
    const config = this.configuration;
    if (!config) throw new Error('ACCOUNT_SERVICE_NOT_CONFIGURED');
    const validated = validateKaifengAiRequest(request);
    const httpRequest = http.createHttp();
    this.activeKaifeng = httpRequest;
    try {
      const result = await httpRequest.request(config.endpoint + '/ai/kaifeng', {
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
        // 服务端的开封错误码同样以 KAIFENG_AI_ 开头，不能在正则里漏掉。
        throw new Error(/^(ACCOUNT|AI|KAIFENG_AI)_[A-Z_]+$/.test(code) ? code : 'ACCOUNT_NETWORK_ERROR');
      }
      return result.result;
    } finally {
      if (this.activeKaifeng === httpRequest) {
        this.activeKaifeng = undefined;
        httpRequest.destroy();
      }
    }
  }

  // 服务端返回只当作“待校验文本”：引用、年份、锚点都由领域层再判一次。
  async kaifengAsk(request: KaifengAiRequest): Promise<KaifengAiAnswer> {
    const text = await this.kaifengPost(request);
    return validateKaifengAiAnswer(JSON.parse(text) as KaifengAiAnswer);
  }

  async kaifengColophon(request: KaifengAiRequest): Promise<KaifengAiColophonResult> {
    const text = await this.kaifengPost(request);
    return validateKaifengColophon(JSON.parse(text) as KaifengAiColophon);
  }

  async logout(): Promise<void> {
    this.cancelAi();
    try { if (this.session) await this.request('/auth/logout', '{}'); }
    finally { this.session = undefined; }
  }

  clearSession(): void { this.cancelAi(); this.session = undefined; }
}
