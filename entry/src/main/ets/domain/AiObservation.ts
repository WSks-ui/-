import type { AiFactSnapshot, AiMemoryAssist } from './ArchiveDomain';
import type { MaterialObservationDefinition, MaterialObservationHotspot } from './MaterialObservation';
import type { MaterialEvidenceSource, MaterialStudy, MaterialStudyFact } from '../data/MaterialStudyCatalog';

// 在线 AI 的开放对象采用显式白名单：对象、场景修订、事实和热点都从现有内容目录读取，
// 不在协议层另写一份容易漂移的正文。新增对象必须先有已核事实与 revision 2 热点，
// 再加进这里；不在清单内的档案仍保留手动观察、资料与手写手账。
// 资料修订号用于识别“这页手账当时依据的资料版本”。
export const AI_OBSERVATION_VERSION: number = 1;
export const AI_OBSERVATION_SITE_IDS: string[] = ['zz-duling-fangding', 'zz-dahecun'];
// 首页“本期观察”仍以方鼎为主入口；多对象入口由白名单统一判断。
export const AI_OBSERVATION_SITE_ID: string = AI_OBSERVATION_SITE_IDS[0];
export const AI_CONTENT_REVISION: number = 1;
export const AI_MAX_QUESTION_LENGTH: number = 200;
export const AI_MAX_OBSERVATION_LENGTH: number = 300;
export const AI_MAX_TURNS: number = 6;
export const AI_MAX_TURN_LENGTH: number = 600;
export const AI_MAX_ANSWER_LENGTH: number = 800;
export const AI_MAX_ACTIONS: number = 4;
export const AI_MAX_DRAFT_LENGTH: number = 600;
export const AI_MAX_DRAFT_TAGS: number = 3;

export interface AiTurn {
  role: string;
  content: string;
}

export interface AiSourceScope {
  id: string;
  title: string;
  publisher: string;
  checkedAt: string;
}

export interface AiHotspotScope {
  id: string;
  label: string;
  factId: string;
}

export interface AiKnowledgeScope {
  siteId: string;
  objectName: string;
  question: string;
  starters: string[];
  sceneRevision: number;
  contentRevision: number;
  facts: AiFactSnapshot[];
  sources: AiSourceScope[];
  hotspots: AiHotspotScope[];
  notice: string;
  visualCaption: string;
  evidenceLimit: string;
}

// UI 与请求分发共用同一条判断，避免“面板能开、服务端却拒绝”的错位。
export function isAiObservationSite(siteId: string): boolean {
  return AI_OBSERVATION_SITE_IDS.includes(siteId);
}

export interface AiObservationRequest {
  version: number;
  requestId: string;
  siteId: string;
  sceneRevision: number;
  hotspotId: string;
  purpose: string;
  question: string;
  turns: AiTurn[];
  userObservation: string;
}

export interface AiObservationAction {
  type: string;
  hotspotId: string;
  factIds: string[];
  label: string;
}

export interface AiDraft {
  body: string;
  tags: string[];
  factIds: string[];
}

export interface AiObservationReply {
  version: number;
  requestId: string;
  siteId: string;
  contentRevision: number;
  status: string;
  answer: string;
  factIds: string[];
  actions: AiObservationAction[];
  draft?: AiDraft;
}

// 采纳草稿时由客户端用当前资料事实组装，不把模型自由文本当作事实摘录。
export interface AiDraftAdoption {
  question: string;
  factIds: string[];
  contentRevision: number;
  facts: AiFactSnapshot[];
  body: string;
  tags: string[];
}

// 知识范围由调用方从现有内容目录组装（客户端读 data/，服务端用 Node 直接读同一份 .ts），
// 领域规则本身不导入内容模块，避免 Node 与 ArkTS 的模块解析差异带来第二份事实正文。
export function buildAiKnowledgeScope(study: MaterialStudy,
  observation: MaterialObservationDefinition): AiKnowledgeScope {
  const facts: AiFactSnapshot[] = study.facts.map((fact: MaterialStudyFact): AiFactSnapshot => ({
    id: fact.id, title: fact.title, body: fact.body, sourceIds: fact.sourceIds.slice()
  }));
  const sources: AiSourceScope[] = study.sources.map((source: MaterialEvidenceSource): AiSourceScope => ({
    id: source.id, title: source.title, publisher: source.publisher, checkedAt: source.checkedAt
  }));
  const hotspots: AiHotspotScope[] = observation.hotspots.map((hotspot: MaterialObservationHotspot): AiHotspotScope => ({
    id: hotspot.id, label: hotspot.label, factId: hotspot.factId
  }));
  return {
    siteId: study.siteId, objectName: study.objectName, question: study.question,
    starters: study.starters.slice(), sceneRevision: observation.sceneRevision,
    contentRevision: AI_CONTENT_REVISION, facts, sources, hotspots,
    notice: observation.notice, visualCaption: study.visualCaption, evidenceLimit: study.evidenceLimit
  };
}

export function aiHotspotLabel(scope: AiKnowledgeScope | undefined, hotspotId: string): string {
  if (!scope) return '';
  const hotspot = scope.hotspots.find((item: AiHotspotScope) => item.id === hotspotId);
  return hotspot ? hotspot.label : '';
}

export function aiFactForId(scope: AiKnowledgeScope | undefined, factId: string): AiFactSnapshot | undefined {
  if (!scope) return undefined;
  return scope.facts.find((fact: AiFactSnapshot) => fact.id === factId);
}

function validRequestId(value: string): boolean {
  return /^[A-Za-z0-9_-]{8,64}$/.test(value);
}

function uniqueFactIds(ids: string[], scope: AiKnowledgeScope): boolean {
  if (ids.length === 0 || ids.length > 3) return false;
  if (new Set<string>(ids).size !== ids.length) return false;
  return ids.every((id: string) => scope.facts.some((fact: AiFactSnapshot) => fact.id === id));
}

// 客户端发送前与服务端接收后都走同一校验：对象、场景修订、热点和轮数不属于请求自带的自由文本，
// 不能因为模型或调用方“看起来合理”就直接执行。
export function validateAiObservationRequest(raw: AiObservationRequest, scope: AiKnowledgeScope): AiObservationRequest {
  if (!raw || raw.version !== AI_OBSERVATION_VERSION || typeof raw.requestId !== 'string' ||
    !validRequestId(raw.requestId.trim()) || typeof raw.siteId !== 'string' || raw.siteId !== scope.siteId) {
    throw new Error('AI_INVALID_REQUEST');
  }
  if (raw.sceneRevision !== scope.sceneRevision) throw new Error('AI_INVALID_REQUEST');
  const hotspotId = typeof raw.hotspotId === 'string' ? raw.hotspotId.trim() : '';
  if (hotspotId && !scope.hotspots.some((hotspot: AiHotspotScope) => hotspot.id === hotspotId)) {
    throw new Error('AI_INVALID_REQUEST');
  }
  const purpose = raw.purpose;
  if (purpose !== 'observe' && purpose !== 'draft_memory') throw new Error('AI_INVALID_REQUEST');
  if (typeof raw.question !== 'string') throw new Error('AI_INVALID_REQUEST');
  const question = raw.question.trim();
  if (!question || question.length > AI_MAX_QUESTION_LENGTH) throw new Error('AI_INVALID_REQUEST');
  const userObservation = typeof raw.userObservation === 'string' ? raw.userObservation.trim() : '';
  if (userObservation.length > AI_MAX_OBSERVATION_LENGTH) throw new Error('AI_INVALID_REQUEST');
  if (!Array.isArray(raw.turns) || raw.turns.length > AI_MAX_TURNS) throw new Error('AI_INVALID_REQUEST');
  const turns: AiTurn[] = raw.turns.map((turn: AiTurn): AiTurn => {
    if (!turn || (turn.role !== 'user' && turn.role !== 'assistant') || typeof turn.content !== 'string') {
      throw new Error('AI_INVALID_REQUEST');
    }
    const content = turn.content.trim();
    if (!content || content.length > AI_MAX_TURN_LENGTH) throw new Error('AI_INVALID_REQUEST');
    return { role: turn.role, content };
  });
  return {
    version: AI_OBSERVATION_VERSION, requestId: raw.requestId.trim(), siteId: raw.siteId,
    sceneRevision: scope.sceneRevision, hotspotId, purpose, question, turns, userObservation
  };
}

function validAction(action: AiObservationAction, scope: AiKnowledgeScope): boolean {
  if (!action || typeof action.label !== 'string' || !action.label.trim() || action.label.length > 40) return false;
  if (!Array.isArray(action.factIds)) return false;
  if (action.type === 'focus_hotspot') {
    // 定位动作可以不附事实；一旦附带引用，就必须属于当前对象且不重复。
    // 否则合法的双连壶热点仍能夹带方鼎依据，在“定位后看依据”时出现对象串用。
    // 客户端与服务端共用此规则，新增开放对象时不在这里另写事实白名单。
    return typeof action.hotspotId === 'string' &&
      scope.hotspots.some((hotspot: AiHotspotScope) => hotspot.id === action.hotspotId) &&
      (action.factIds.length === 0 || uniqueFactIds(action.factIds, scope));
  }
  if (action.type === 'show_evidence') {
    return action.factIds.length > 0 && uniqueFactIds(action.factIds, scope);
  }
  return false;
}

// 回复校验不把“JSON 可解析”当作正确：请求身份、资料修订、引用事实和可执行动作必须全部闭合，
// 否则整条回复进入失败/重试，不能只挑出看起来合法的片段执行。
export function validateAiObservationReply(raw: AiObservationReply, request: AiObservationRequest,
  scope: AiKnowledgeScope): AiObservationReply {
  if (!raw || raw.version !== AI_OBSERVATION_VERSION || raw.requestId !== request.requestId ||
    raw.siteId !== request.siteId || raw.siteId !== scope.siteId) throw new Error('AI_INVALID_REPLY');
  if (raw.contentRevision !== scope.contentRevision) throw new Error('AI_INVALID_REPLY');
  if (raw.status !== 'grounded' && raw.status !== 'needs_clarification' && raw.status !== 'insufficient_evidence') {
    throw new Error('AI_INVALID_REPLY');
  }
  if (typeof raw.answer !== 'string') throw new Error('AI_INVALID_REPLY');
  const answer = raw.answer.trim();
  if (!answer || answer.length > AI_MAX_ANSWER_LENGTH) throw new Error('AI_INVALID_REPLY');
  if (!Array.isArray(raw.factIds) || new Set<string>(raw.factIds).size !== raw.factIds.length) {
    throw new Error('AI_INVALID_REPLY');
  }
  const factIds: string[] = raw.factIds.slice();
  if (factIds.length > 0 && !uniqueFactIds(factIds, scope)) throw new Error('AI_INVALID_REPLY');
  if (raw.status === 'grounded' && factIds.length === 0) throw new Error('AI_INVALID_REPLY');
  if (!Array.isArray(raw.actions) || raw.actions.length > AI_MAX_ACTIONS) throw new Error('AI_INVALID_REPLY');
  const actions: AiObservationAction[] = raw.actions.map((action: AiObservationAction): AiObservationAction => {
    if (!validAction(action, scope)) throw new Error('AI_INVALID_REPLY');
    return {
      type: action.type, hotspotId: action.hotspotId || '', factIds: action.factIds.slice(),
      label: action.label.trim()
    };
  });
  let draft: AiDraft | undefined = undefined;
  if (raw.draft !== undefined) {
    if (request.purpose !== 'draft_memory' || !raw.draft) throw new Error('AI_INVALID_REPLY');
    if (typeof raw.draft.body !== 'string') throw new Error('AI_INVALID_REPLY');
    const body = raw.draft.body.trim();
    if (!body || body.length > AI_MAX_DRAFT_LENGTH) throw new Error('AI_INVALID_REPLY');
    if (!Array.isArray(raw.draft.tags) || raw.draft.tags.length > AI_MAX_DRAFT_TAGS) throw new Error('AI_INVALID_REPLY');
    const tags: string[] = raw.draft.tags.map((tag: string): string => {
      if (typeof tag !== 'string') throw new Error('AI_INVALID_REPLY');
      const value = tag.trim();
      if (!value || value.length > 20) throw new Error('AI_INVALID_REPLY');
      return value;
    });
    if (!Array.isArray(raw.draft.factIds) || !uniqueFactIds(raw.draft.factIds, scope)) {
      throw new Error('AI_INVALID_REPLY');
    }
    draft = { body, tags, factIds: raw.draft.factIds.slice() };
  }
  return {
    version: AI_OBSERVATION_VERSION, requestId: request.requestId, siteId: request.siteId,
    contentRevision: scope.contentRevision, status: raw.status, answer, factIds, actions, draft
  };
}

// 迟到回复只有同时匹配当前请求、对象、场景修订和资料修订才允许进入页面；
// 用户停止等待或切换对象后，即使旧请求最后成功，也不能覆盖新问题。
export function acceptAiReply(reply: AiObservationReply, request: AiObservationRequest,
  currentSiteId: string, currentSceneRevision: number, activeRequestId: string): boolean {
  return !!activeRequestId && request.requestId === activeRequestId && reply.requestId === activeRequestId &&
    request.siteId === currentSiteId && reply.siteId === currentSiteId &&
    request.sceneRevision === currentSceneRevision && reply.contentRevision === AI_CONTENT_REVISION;
}

export function collectAiReplyFactIds(reply: AiObservationReply): string[] {
  const ids: string[] = [];
  const add = (value: string): void => { if (value && !ids.includes(value)) ids.push(value); };
  reply.factIds.forEach((id: string) => add(id));
  reply.actions.forEach((action: AiObservationAction) => action.factIds.forEach((id: string) => add(id)));
  if (reply.draft) reply.draft.factIds.forEach((id: string) => add(id));
  return ids;
}

export function aiStatusLabel(status: string): string {
  if (status === 'needs_clarification') return '需要补充';
  if (status === 'insufficient_evidence') return '资料不足';
  return 'AI 参考解读';
}

export function aiStatusTone(status: string): string {
  // 资料不足与网络失败必须视觉上分开：前者是模型如实说明，后者是本次没有生成回答。
  if (status === 'insufficient_evidence') return 'warning';
  if (status === 'needs_clarification') return 'neutral';
  return 'grounded';
}

export function aiErrorMessage(code: string): string {
  if (code === 'AI_NOT_CONFIGURED') return '服务端尚未配置模型凭证，本次没有调用 AI；本地观察与手写仍可使用。';
  if (code === 'AI_TIMEOUT') return '模型响应超时，本次没有生成回答；问题仍保留，可以重试。';
  if (code === 'AI_PROVIDER_ERROR') return '模型服务暂时不可用，本次没有生成回答，请稍后重试。';
  if (code === 'AI_PROVIDER_AUTH') return '模型凭证无效或已过期，本次没有生成回答；请联系演示负责人更换凭证。';
  if (code === 'AI_PROVIDER_QUOTA') return '模型账户余额不足，本次没有生成回答；本地观察与手写仍可使用。';
  if (code === 'AI_INVALID_REPLY') return '模型返回的内容未通过应用校验，本次没有采用，请重试。';
  if (code === 'AI_RATE_LIMITED') return 'AI 请求过于频繁，请稍后再试；问题仍保留。';
  if (code === 'AI_REQUEST_CANCELLED') return '已停止等待，问题仍保留。';
  if (code === 'AI_INVALID_REQUEST') return '这次提问的上下文不完整，请重新输入问题。';
  if (code === 'ACCOUNT_SESSION_EXPIRED') return '登录状态已失效，请到“我的”重新登录后再试。';
  if (code === 'ACCOUNT_SERVICE_NOT_CONFIGURED') return '本机未配置账号服务，在线 AI 暂不可用；本地观察仍可继续。';
  return '网络或服务暂时不可用，本次没有生成回答；问题仍保留，可以重试。';
}

export function buildAiMemoryAssist(adoption: AiDraftAdoption, scope: AiKnowledgeScope): AiMemoryAssist {
  // 冻结事实只取采纳时客户端的资料副本；问题保留为本次选择的问法，不保存整段对话。
  const question = adoption.question.trim();
  const body = adoption.body.trim();
  if (!question || question.length > AI_MAX_QUESTION_LENGTH || !body || body.length > AI_MAX_DRAFT_LENGTH) {
    throw new Error('AI_INVALID_DRAFT');
  }
  if (!Array.isArray(adoption.tags) || adoption.tags.length > AI_MAX_DRAFT_TAGS) throw new Error('AI_INVALID_DRAFT');
  const tags: string[] = adoption.tags.map((tag: string): string => tag.trim());
  if (tags.some((tag: string) => !tag || tag.length > 20)) throw new Error('AI_INVALID_DRAFT');
  if (adoption.contentRevision !== scope.contentRevision) throw new Error('AI_INVALID_DRAFT');
  if (!uniqueFactIds(adoption.factIds, scope)) throw new Error('AI_INVALID_DRAFT');
  const facts: AiFactSnapshot[] = adoption.facts.map((fact: AiFactSnapshot): AiFactSnapshot => {
    if (!adoption.factIds.includes(fact.id) || fact.title.length > 120 || fact.body.length > 1000 ||
      fact.body.trim().length === 0 || fact.sourceIds.length === 0) throw new Error('AI_INVALID_DRAFT');
    return { id: fact.id, title: fact.title, body: fact.body, sourceIds: fact.sourceIds.slice() };
  });
  if (facts.length !== adoption.factIds.length) throw new Error('AI_INVALID_DRAFT');
  return {
    version: 1, question, factIds: adoption.factIds.slice(), contentRevision: adoption.contentRevision, facts
  };
}

export function aiAssistBadge(assist: AiMemoryAssist | undefined): string {
  if (!assist) return '';
  return `AI 辅助整理 · 依据资料 v${assist.contentRevision}`;
}

export function aiAssistFactIdsText(assist: AiMemoryAssist | undefined): string {
  if (!assist) return '';
  return assist.factIds.join(' · ');
}
