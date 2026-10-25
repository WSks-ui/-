import { KAIFENG_AI_FACTS } from '../entry/src/main/ets/domain/KaifengAiFacts.ts';

// 开封州桥的 AI 适配层。与 ai-observation.mjs 分开：
//  - 观察导览是“看器物”的多轮问答；这里是“校书”，只围绕州桥的 7 条事实；
//  - 工具 schema 不同（ask / colophon），混在一起会让既有 26 条契约测试变脆。
// 复用 ai-observation 的配置读取与错误码，不复制密钥处理。
//
// 服务端只做输入边界与形状归一；逐句接地、年份硬校验、拒收降级都在客户端
// KaifengAi.ts 里再做一遍。两边都做，是因为模型输出不能作为可信输入。

const DEFAULT_TIMEOUT_MS = 20000;
const KAIFENG_AI_SITE_ID = 'kf-zhouqiao';
const ANCHORS = ['bridge', 'section', 'motif', 'market', 'lantern'];

const fail = (code, status = 400) => Object.assign(new Error(code), { status });

function factById(id) {
  return KAIFENG_AI_FACTS.find(fact => fact.id === id);
}

function factBlock() {
  return KAIFENG_AI_FACTS.map(fact =>
    `- [${fact.id}] ${fact.text}\n  原文/考古表述：「${fact.quote}」`).join('\n');
}

function systemPrompt(mode) {
  const common = [
    '你是《云河纪》开封州桥的校书人，不是通用聊天助手。',
    '只能使用下面列出的事实；不得引入表外的年代、数字、地名、人物或考古结论。',
    '如果事实不足，明确拒答，不要补写。',
    '回答用简体中文，语气克制，不用“据说”“可能”来掩盖没有依据的内容。',
    '',
    '可用事实：',
    factBlock()
  ];
  if (mode === 'colophon') {
    common.push(
      '',
      '任务：为玩家已经建成的汴京城写 2–4 句题跋草稿。',
      '每一句都必须带一个事实 id，并尽量复用该事实里的词；不要写事实表以外的细节。',
      '如果玩家草稿里有与事实冲突的说法，放入 conflicts，指出原句、对应事实与原因。',
      'suggestion 只写一句可操作的补充建议，不要展开。'
    );
  } else {
    common.push(
      '',
      '任务：回答玩家关于州桥、层位、石壁、夜市或灯事的一个问题。',
      '回答不超过 260 字；必须带 1–3 条 cites；anchor 只能是 bridge/section/motif/market/lantern。',
      '事实不足时把 refused 设为 true，cites 可以为空。'
    );
  }
  return common.join('\n');
}

function askTool() {
  return {
    type: 'function',
    function: {
      name: 'submit_answer',
      description: '提交一条有出处的州桥回答。',
      parameters: {
        type: 'object',
        additionalProperties: false,
        required: ['answer', 'cites', 'anchor', 'refused'],
        properties: {
          answer: { type: 'string', description: '不超过 260 字的回答' },
          cites: {
            type: 'array', minItems: 1, maxItems: 3,
            items: { type: 'string', enum: KAIFENG_AI_FACTS.map(fact => fact.id) }
          },
          anchor: { type: 'string', enum: ANCHORS },
          refused: { type: 'boolean' }
        }
      }
    }
  };
}

function colophonTool() {
  return {
    type: 'function',
    function: {
      name: 'submit_colophon',
      description: '提交一段逐句带事实 id 的题跋草稿。',
      parameters: {
        type: 'object',
        additionalProperties: false,
        required: ['sentences', 'conflicts', 'suggestion'],
        properties: {
          sentences: {
            type: 'array', minItems: 1, maxItems: 4,
            items: {
              type: 'object', additionalProperties: false, required: ['text', 'fact'],
              properties: {
                text: { type: 'string', description: '不超过 120 字的题跋句' },
                fact: { type: 'string', enum: KAIFENG_AI_FACTS.map(fact => fact.id) }
              }
            }
          },
          conflicts: {
            type: 'array', maxItems: 3,
            items: {
              type: 'object', additionalProperties: false, required: ['quote', 'fact', 'why'],
              properties: {
                quote: { type: 'string' },
                fact: { type: 'string', enum: KAIFENG_AI_FACTS.map(fact => fact.id) },
                why: { type: 'string' }
              }
            }
          },
          suggestion: { type: 'string' }
        }
      }
    }
  };
}

export function buildKaifengMessages(request) {
  const user = request.mode === 'colophon'
    ? `我的城：${request.city || '（未提供摘要）'}\n我写下的草稿：${request.draft || '（还没有写）'}\n请校这一页。`
    : `我的城：${request.city || '（未提供摘要）'}\n问题：${request.question}`;
  return [
    { role: 'system', content: systemPrompt(request.mode) },
    { role: 'user', content: user }
  ];
}

function normalizeAsk(parsed) {
  return {
    answer: typeof parsed?.answer === 'string' ? parsed.answer : '',
    cites: Array.isArray(parsed?.cites) ? parsed.cites.filter(id => factById(id)).slice(0, 3) : [],
    anchor: ANCHORS.includes(parsed?.anchor) ? parsed.anchor : '',
    refused: parsed?.refused === true
  };
}

function normalizeColophon(parsed) {
  const sentences = Array.isArray(parsed?.sentences)
    ? parsed.sentences.filter(item => item && typeof item.text === 'string' && factById(item.fact))
      .slice(0, 4).map(item => ({ text: item.text.slice(0, 120), fact: item.fact }))
    : [];
  const conflicts = Array.isArray(parsed?.conflicts)
    ? parsed.conflicts.filter(item => item && typeof item.quote === 'string' &&
      typeof item.why === 'string' && factById(item.fact)).slice(0, 3)
      .map(item => ({ quote: item.quote.slice(0, 120), fact: item.fact, why: item.why.slice(0, 120) }))
    : [];
  return {
    sentences,
    conflicts,
    suggestion: typeof parsed?.suggestion === 'string' ? parsed.suggestion.slice(0, 120) : ''
  };
}

function parseJsonContent(text) {
  try { return JSON.parse(text); } catch { throw fail('AI_INVALID_REPLY', 502); }
}

// 与观察导览一致的错误映射：401/402 单独成码，429 限流，其余供应商错误不读正文。
export function createKaifengAiService({ configuration, fetchImpl = globalThis.fetch, now = Date.now,
  logger = console } = {}) {
  const config = configuration || { configured: false };
  const available = !!config.configured;

  async function run(body) {
    if (!available) throw fail('AI_NOT_CONFIGURED', 503);
    if (!body || body.siteId !== KAIFENG_AI_SITE_ID) throw fail('KAIFENG_AI_INVALID_SITE');
    if (body.mode !== 'ask' && body.mode !== 'colophon') throw fail('KAIFENG_AI_INVALID_MODE');
    const question = typeof body.question === 'string' ? body.question.trim() : '';
    const draft = typeof body.draft === 'string' ? body.draft.trim() : '';
    const city = typeof body.city === 'string' ? body.city.trim() : '';
    if (question.length > 80 || draft.length > 200 || city.length > 600) throw fail('KAIFENG_AI_INVALID_REQUEST');
    if (body.mode === 'ask' && !question) throw fail('KAIFENG_AI_INVALID_QUESTION');
    const request = { siteId: body.siteId, mode: body.mode, question, draft, city };

    const tool = body.mode === 'colophon' ? colophonTool() : askTool();
    const payload = {
      model: config.model,
      messages: buildKaifengMessages(request),
      tools: [tool],
      tool_choice: { type: 'function', function: { name: tool.function.name } },
      temperature: 0.2,
      max_tokens: 700
    };
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), config.timeoutMs || DEFAULT_TIMEOUT_MS);
    const started = now();
    let response;
    try {
      response = await fetchImpl(`${config.baseUrl.replace(/\/+$/, '')}/chat/completions`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${config.apiKey}` },
        body: JSON.stringify(payload),
        signal: controller.signal
      });
    } catch (error) {
      if (error?.name === 'AbortError' || error?.name === 'TimeoutError') throw fail('AI_TIMEOUT', 504);
      throw fail('AI_PROVIDER_ERROR', 502);
    } finally {
      clearTimeout(timer);
    }
    if (!response || !response.ok) {
      const status = response ? response.status : 0;
      if (status === 401) throw fail('AI_PROVIDER_AUTH', 503);
      if (status === 402) throw fail('AI_PROVIDER_QUOTA', 503);
      throw fail(status === 429 ? 'AI_RATE_LIMITED' : 'AI_PROVIDER_ERROR', status === 429 ? 429 : 502);
    }
    let data;
    try { data = await response.json(); } catch { throw fail('AI_INVALID_REPLY', 502); }
    const message = data?.choices?.[0]?.message;
    const args = message?.tool_calls?.[0]?.function?.arguments;
    const parsed = typeof args === 'string' && args.trim() ? parseJsonContent(args)
      : typeof message?.content === 'string' && message.content.trim() ? parseJsonContent(message.content)
        : (() => { throw fail('AI_INVALID_REPLY', 502); })();
    const reply = body.mode === 'colophon' ? normalizeColophon(parsed) : normalizeAsk(parsed);
    if (body.mode === 'colophon' && reply.sentences.length === 0) throw fail('KAIFENG_AI_NO_GROUNDED_SENTENCE', 502);
    if (body.mode === 'ask' && !reply.refused && reply.cites.length === 0) {
      throw fail('KAIFENG_AI_NEEDS_CITATION', 502);
    }
    const elapsed = now() - started;
    if (logger && typeof logger.info === 'function') {
      logger.info(`AI_KAIFENG_OK model=${config.model} mode=${body.mode} ` +
        `facts=${body.mode === 'colophon' ? reply.sentences.length : reply.cites.length} elapsedMs=${elapsed}`);
    }
    return reply;
  }

  return {
    available,
    describe: () => ({ configured: available, provider: config.provider, model: config.model }),
    run
  };
}
