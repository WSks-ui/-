import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import {
  AI_CONTENT_REVISION, AI_OBSERVATION_SITE_ID, aiHotspotLabel, buildAiKnowledgeScope,
  validateAiObservationReply, validateAiObservationRequest
} from '../entry/src/main/ets/domain/AiObservation.ts';
import { materialStudyForId } from '../entry/src/main/ets/data/MaterialStudyCatalog.ts';
import { DULING_OBSERVATION } from '../entry/src/main/ets/domain/DulingObservation.ts';

// 模型适配层只做三件事：按服务端掌握的资料组装提示、发起一次受控请求、把结果归一成应用契约。
// 客户端不接触供应商密钥、模型名或原始响应；任何未通过领域校验的文本都不能直接进入页面。
const DEFAULT_TIMEOUT_MS = 20000;
const DEFAULT_MODEL = 'deepseek-flash';
const DEFAULT_BASE_URL = 'https://api.deepseek.com';
const DEFAULT_CONFIG_URL = new URL('../.local/ai-observation/config.json', import.meta.url);
const MODEL_PATTERN = /^[A-Za-z0-9._:-]{1,80}$/;

// 服务端直接读取现有内容目录与热点定义，和客户端共用同一份事实正文；不另外维护题库正文。
const DULING_STUDY = materialStudyForId(AI_OBSERVATION_SITE_ID);
const DULING_SCOPE = DULING_STUDY ? buildAiKnowledgeScope(DULING_STUDY, DULING_OBSERVATION) : undefined;

export function aiScopeFor(siteId) {
  return siteId === AI_OBSERVATION_SITE_ID ? DULING_SCOPE : undefined;
}

const fail = (code, status = 400) => Object.assign(new Error(code), { status });

function readConfigFile(configPath) {
  if (!configPath) return {};
  try {
    if (!existsSync(configPath)) return {};
    return JSON.parse(readFileSync(configPath, 'utf8').replace(/^\uFEFF/, ''));
  } catch {
    // 配置损坏只让在线 AI 保持未配置，不影响账号、同步和本地观察。
    return {};
  }
}

function normalizeBaseUrl(value) {
  if (typeof value !== 'string' || !value.trim()) return DEFAULT_BASE_URL;
  const text = value.trim().replace(/\/+$/, '');
  const parsed = new URL(text);
  if (parsed.protocol !== 'https:' && parsed.hostname !== '127.0.0.1' && parsed.hostname !== 'localhost') {
    throw new Error('AI_INVALID_CONFIGURATION');
  }
  return text;
}

function endpointFor(baseUrl) {
  return /\/chat\/completions$/.test(baseUrl) ? baseUrl : `${baseUrl}/chat/completions`;
}

// 只从服务端环境或已忽略的本机配置读取密钥。返回对象供服务使用，describe() 永不包含密钥。
export function loadAiConfiguration({ env = process.env, configPath = DEFAULT_CONFIG_URL } = {}) {
  const file = readConfigFile(configPath);
  const apiKey = String(env.YUNHEJI_AI_API_KEY || env.DEEPSEEK_API_KEY || file.apiKey || '').trim();
  const provider = String(env.YUNHEJI_AI_PROVIDER || file.provider || 'deepseek').trim();
  const model = String(env.YUNHEJI_AI_MODEL || file.model || DEFAULT_MODEL).trim();
  const baseUrl = normalizeBaseUrl(env.YUNHEJI_AI_BASE_URL || file.baseUrl || DEFAULT_BASE_URL);
  const timeoutValue = Number(env.YUNHEJI_AI_TIMEOUT_MS || file.timeoutMs || DEFAULT_TIMEOUT_MS);
  const timeoutMs = Number.isFinite(timeoutValue) ? Math.max(3000, Math.min(60000, Math.trunc(timeoutValue))) : DEFAULT_TIMEOUT_MS;
  if (!MODEL_PATTERN.test(model) || !provider || provider.length > 40) throw new Error('AI_INVALID_CONFIGURATION');
  if (apiKey && (apiKey.length < 8 || apiKey.length > 512 || /\s/.test(apiKey))) {
    throw new Error('AI_INVALID_CONFIGURATION');
  }
  return { provider, model, baseUrl, apiKey, timeoutMs, configured: apiKey.length > 0 };
}

export function describeAiConfiguration(configuration) {
  // 只说明是否可用与所选型号；不输出密钥、完整地址、账号或题库。
  return {
    configured: !!configuration?.configured,
    provider: configuration?.provider || 'deepseek',
    model: configuration?.model || DEFAULT_MODEL,
    timeoutMs: configuration?.timeoutMs || DEFAULT_TIMEOUT_MS,
    knowledgeRevision: AI_CONTENT_REVISION
  };
}

function turnMessages(request) {
  const messages = [];
  request.turns.forEach(turn => messages.push({ role: turn.role, content: turn.content }));
  return messages;
}

// 资料事实、来源、热点和场景说明都由服务端从内容目录组装；客户端提交的正文不作为权威来源。
export function buildObservationMessages(scope, request) {
  const draftRule = request.purpose === 'draft_memory' ?
    '本次 purpose 是 draft_memory：还必须填写 draft（body 40—120 字可编辑草稿、1—3 个短标签、合法 factIds）。草稿保留用户原意，不虚构到馆、亲眼见到实物或未提供的行程；不要包含自动保存指令。' :
    '本次 purpose 是 observe：不要填写 draft。';
  const system = [
    '你是“云河纪”的中文文化观察导览，只服务一件文物：杜岭二号方鼎（zz-duling-fangding）。',
    '你的任务不是讲百科，而是依据下列资料，引导用户观察原生示意中的具体部位，并允许用户核对依据。',
    '资料事实（唯一允许引用的事实）：',
    JSON.stringify(scope.facts),
    '来源（不得编造其他来源、作者或网址）：',
    JSON.stringify(scope.sources),
    '场景热点（focus_hotspot 只能使用这些 id）：',
    JSON.stringify(scope.hotspots),
    '场景说明（属于应用表达，不是考古原貌）：',
    scope.notice,
    '图注与资料边界：',
    `${scope.visualCaption}；${scope.evidenceLimit}`,
    '必须区分三类信息：资料事实；场景说明（玫瑰标记、陶土色折片、镜头与简化几何）；个人表达。',
    '资料没有支持的纹样寓意、祭祀对象、族属、制作细节、传承关系或其他文物信息，必须明确说“当前资料不足”，不要猜测，不要补写来源。',
    '回答控制在 80—180 个汉字：先直接回答，再给一个可执行的观察动作；不要重复用户问题；不要使用 Markdown。',
    'status 只能取 grounded、needs_clarification、insufficient_evidence；grounded 必须至少引用一个合法 factId。',
    'actions 只能从 focus_hotspot 和 show_evidence 中选：focus_hotspot 必须给合法 hotspotId；show_evidence 必须给合法 factIds。可以不返回动作。',
    '必须调用 submit_observation 工具提交结构化结果；不要用普通文本回答。',
    draftRule
  ].join('\n');
  const messages = [{ role: 'system', content: system }];
  turnMessages(request).forEach(message => messages.push(message));
  if (request.purpose === 'draft_memory') {
    messages.push({
      role: 'user',
      content: `用户自己写下的一句观察：${request.userObservation}\n用户选择保留的问题：${request.question}\n请整理为草稿并通过 submit_observation 提交。`
    });
  } else {
    // 从手账继续观察时只接收用户确认的这一段表达，不把个人记忆升级为资料事实。
    const observation = request.userObservation ?
      `用户的个人观察（不是已核史实）：${request.userObservation}\n请结合这段观察回答以下问题。\n` : '';
    messages.push({ role: 'user', content: `${observation}${request.question}` });
  }
  return messages;
}

// 结构化函数调用比 JSON 文本模式更稳定：DeepSeek 的 json_object 在多轮上下文下偶发只返回空白，
// 而强制 tool_choice 会直接给出可校验的参数。应用仍对参数做完整领域校验，函数调用不等于可信内容。
export function observationTool(request) {
  const actionSchema = {
    type: 'object',
    properties: {
      type: { type: 'string', enum: ['focus_hotspot', 'show_evidence'] },
      hotspotId: { type: 'string' },
      factIds: { type: 'array', items: { type: 'string' } },
      label: { type: 'string' }
    },
    required: ['type', 'factIds', 'label']
  };
  const properties = {
    status: { type: 'string', enum: ['grounded', 'needs_clarification', 'insufficient_evidence'] },
    answer: { type: 'string' },
    factIds: { type: 'array', items: { type: 'string' } },
    actions: { type: 'array', items: actionSchema }
  };
  const required = ['status', 'answer', 'factIds', 'actions'];
  if (request.purpose === 'draft_memory') {
    properties.draft = {
      type: 'object',
      properties: {
        body: { type: 'string' },
        tags: { type: 'array', items: { type: 'string' } },
        factIds: { type: 'array', items: { type: 'string' } }
      },
      required: ['body', 'tags', 'factIds']
    };
    required.push('draft');
  }
  return {
    type: 'function',
    function: {
      name: 'submit_observation',
      description: '提交依据已核资料事实的方鼎观察导览回答',
      parameters: { type: 'object', properties, required }
    }
  };
}

function parseJsonContent(content) {
  let text = content.trim();
  text = text.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start < 0 || end <= start) throw fail('AI_INVALID_REPLY', 502);
  try { return JSON.parse(text.slice(start, end + 1)); }
  catch { throw fail('AI_INVALID_REPLY', 502); }
}

function stringArray(value) {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value) || value.some(item => typeof item !== 'string')) throw fail('AI_INVALID_REPLY', 502);
  return value.slice();
}

function normalizeAction(raw, scope) {
  if (!raw || typeof raw !== 'object') return undefined;
  const type = raw.type;
  const factIds = stringArray(raw.factIds);
  if (type === 'focus_hotspot') {
    const hotspotId = typeof raw.hotspotId === 'string' ? raw.hotspotId : '';
    const label = aiHotspotLabel(scope, hotspotId) ? `看${aiHotspotLabel(scope, hotspotId)}` :
      (typeof raw.label === 'string' ? raw.label : '');
    return { type, hotspotId, factIds, label };
  }
  if (type === 'show_evidence') {
    return { type, hotspotId: '', factIds, label: '查看依据' };
  }
  return undefined;
}

function normalizeReply(raw, request, scope) {
  // 模型只提供内容字段；请求身份、对象和资料修订由服务端设置，不能靠模型猜。
  let actions = [];
  if (raw.actions !== undefined) {
    if (!Array.isArray(raw.actions)) throw fail('AI_INVALID_REPLY', 502);
    const normalized = raw.actions.map(item => normalizeAction(item, scope));
    // 非法动作不能悄悄丢弃后把其余内容当成有效回答；整条回复进入重试。
    if (normalized.some(action => !action)) throw fail('AI_INVALID_REPLY', 502);
    actions = normalized;
  }
  let factIds = stringArray(raw.factIds);
  if (factIds.length === 0 && actions.length > 0) {
    actions.forEach(action => action.factIds.forEach(id => { if (!factIds.includes(id)) factIds.push(id); }));
  }
  let draft;
  if (request.purpose === 'draft_memory' && raw.draft !== undefined) {
    if (!raw.draft || typeof raw.draft !== 'object' || Array.isArray(raw.draft)) throw fail('AI_INVALID_REPLY', 502);
    draft = {
      body: typeof raw.draft.body === 'string' ? raw.draft.body : '',
      tags: stringArray(raw.draft.tags),
      factIds: stringArray(raw.draft.factIds)
    };
  }
  return {
    version: request.version, requestId: request.requestId, siteId: request.siteId,
    contentRevision: scope.contentRevision,
    status: typeof raw.status === 'string' ? raw.status : '',
    answer: typeof raw.answer === 'string' ? raw.answer : '',
    factIds, actions, draft
  };
}

export function createAiObservationService({ configuration, fetchImpl = globalThis.fetch, now = Date.now,
  logger = console } = {}) {
  const config = configuration || {
    provider: 'deepseek', model: DEFAULT_MODEL, baseUrl: DEFAULT_BASE_URL, apiKey: '', timeoutMs: DEFAULT_TIMEOUT_MS,
    configured: false
  };
  const endpoint = endpointFor(config.baseUrl || DEFAULT_BASE_URL);
  const available = !!config.configured;

  async function run(rawRequest, session) {
    // 请求先过领域校验；服务端不信任客户端自带的 siteId、热点或资料修订。
    const scope = aiScopeFor(rawRequest && rawRequest.siteId);
    if (!scope) throw fail('AI_INVALID_REQUEST');
    const request = validateAiObservationRequest(rawRequest, scope);
    if (!available) throw fail('AI_NOT_CONFIGURED', 503);
    if (request.purpose === 'draft_memory' && !request.userObservation) {
      // 用户还没留下自己的观察：不虚构个人经历，也不消耗一次模型调用。
      return {
        version: 1, requestId: request.requestId, siteId: request.siteId,
        contentRevision: AI_CONTENT_REVISION, status: 'needs_clarification',
        answer: '先写一句你自己看到或想到的观察，我再帮你整理成手账；不会替你编造到馆经历或亲眼见到的细节。',
        factIds: [], actions: []
      };
    }
    const messages = buildObservationMessages(scope, request);
    const tool = observationTool(request);
    const body = {
      model: config.model,
      messages,
      tools: [tool],
      tool_choice: { type: 'function', function: { name: tool.function.name } },
      max_tokens: 1200,
      temperature: 0.3,
      stream: false
    };
    // DeepSeek 默认开启思考模式；观察导览要短回答，显式关闭以控制等待时间。
    // 其他兼容供应商不发送该字段，避免不认识参数的网关直接拒绝。
    if ((config.provider || 'deepseek') === 'deepseek') body.thinking = { type: 'disabled' };
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), config.timeoutMs || DEFAULT_TIMEOUT_MS);
    const started = now();
    let response;
    try {
      response = await fetchImpl(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${config.apiKey}` },
        body: JSON.stringify(body),
        signal: controller.signal
      });
    } catch (error) {
      if (error?.name === 'AbortError' || error?.name === 'TimeoutError') throw fail('AI_TIMEOUT', 504);
      throw fail('AI_PROVIDER_ERROR', 502);
    } finally {
      clearTimeout(timer);
    }
    if (!response || !response.ok) {
      // 不读取或记录供应商错误正文，避免把密钥、请求内容或账号信息带进日志。
      throw fail(response && response.status === 429 ? 'AI_RATE_LIMITED' : 'AI_PROVIDER_ERROR',
        response && response.status === 429 ? 429 : 502);
    }
    let payload;
    try { payload = await response.json(); }
    catch { throw fail('AI_INVALID_REPLY', 502); }
    const message = payload?.choices?.[0]?.message;
    // 首选强制函数调用的参数；兼容性回退只在供应商忽略 tools、直接返回 JSON 文本时使用。
    const toolArguments = message?.tool_calls?.[0]?.function?.arguments;
    let parsed;
    if (typeof toolArguments === 'string' && toolArguments.trim()) parsed = parseJsonContent(toolArguments);
    else if (typeof message?.content === 'string' && message.content.trim()) parsed = parseJsonContent(message.content);
    else throw fail('AI_INVALID_REPLY', 502);
    let reply;
    try { reply = validateAiObservationReply(normalizeReply(parsed, request, scope), request, scope); }
    catch { throw fail('AI_INVALID_REPLY', 502); }
    const elapsed = now() - started;
    if (logger && typeof logger.info === 'function') {
      // 只记录可审计的调用元数据，不记录问题、回答、账号、密钥或原始响应。
      logger.info(`AI_OBSERVE_OK provider=${config.provider} model=${config.model} site=${request.siteId} ` +
        `purpose=${request.purpose} status=${reply.status} facts=${reply.factIds.length} ` +
        `actions=${reply.actions.length} elapsedMs=${elapsed} account=${session ? 'authenticated' : 'unknown'}`);
    }
    return reply;
  }

  return { available, describe: () => describeAiConfiguration(config), run };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  // 便于不启动 HTTPS 服务时单独检查配置与真实调用；密钥仍只从配置或环境读取。
  const config = loadAiConfiguration();
  const service = createAiObservationService({ configuration: config });
  const question = process.argv.slice(2).join(' ') || '只有四面，八组是怎么数出来的？';
  const request = {
    version: 1, requestId: `cli-${Date.now()}`, siteId: 'zz-duling-fangding', sceneRevision: 2,
    hotspotId: 'centers', purpose: 'observe', question, turns: [], userObservation: ''
  };
  try {
    const reply = await service.run(request, { account_id: 'cli' });
    process.stdout.write(`${JSON.stringify(reply, null, 2)}\n`);
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}
