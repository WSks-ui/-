import assert from 'node:assert/strict';
import { test } from 'node:test';
import { buildKaifengMessages, createKaifengAiService } from './kaifeng-ai.mjs';
import { KAIFENG_AI_FACTS } from '../entry/src/main/ets/domain/KaifengAiFacts.ts';

const configured = { configured: true, provider: 'deepseek', model: 'stub-model',
  baseUrl: 'https://example.invalid', apiKey: 'not-a-real-key', timeoutMs: 1000 };

const askReply = {
  answer: '州桥低平，不通舟船；船在东岸卸货，西河换平船。',
  cites: ['zf-low-flat'], anchor: 'bridge', refused: false
};

const colophonReply = {
  sentences: [
    { text: '州桥低平，不通舟船。', fact: 'zf-low-flat' },
    { text: '明代在同一位置改建单孔拱桥。', fact: 'zf-ming-arch' }
  ],
  conflicts: [{ quote: '船从桥下过', fact: 'zf-low-flat', why: '原文为低平不通舟船' }],
  suggestion: '可以补一句：船在东岸卸货。'
};

function stubFetch(reply, captured) {
  return async (url, init) => {
    captured.url = url;
    captured.body = JSON.parse(init.body);
    return {
      ok: true, status: 200,
      json: async () => ({ choices: [{ message: { tool_calls: [{ function: { arguments: JSON.stringify(reply) } }] } }] })
    };
  };
}

test('kaifeng ai server: 提示词只带七条事实，并要求逐句给 id', () => {
  const messages = buildKaifengMessages({ mode: 'colophon', question: '', draft: '我写的一句', city: '桥型:平桥' });
  assert.equal(messages[0].role, 'system');
  for (const fact of KAIFENG_AI_FACTS) assert.ok(messages[0].content.includes(fact.id), fact.id);
  assert.ok(messages[0].content.includes('不得引入表外'));
  assert.ok(messages[1].content.includes('我写的一句'));
});

test('kaifeng ai server: ask 工具只允许七条事实与五个锚点', async () => {
  let captured = {};
  const service = createKaifengAiService({ configuration: configured,
    fetchImpl: stubFetch(askReply, captured), logger: { info: () => {} } });
  const reply = await service.run({ siteId: 'kf-zhouqiao', mode: 'ask', question: '州桥为什么低平？', draft: '', city: '' });
  assert.equal(reply.cites[0], 'zf-low-flat');
  const tool = captured.body.tools[0].function;
  assert.equal(tool.name, 'submit_answer');
  assert.deepEqual(tool.parameters.properties.cites.items.enum, KAIFENG_AI_FACTS.map(fact => fact.id));
  assert.deepEqual(tool.parameters.properties.anchor.enum, ['bridge', 'section', 'motif', 'market', 'lantern']);
  assert.equal(captured.body.tool_choice.function.name, 'submit_answer');
});

test('kaifeng ai server: 题跋工具返回逐句事实与冲突，未知事实被过滤', async () => {
  let captured = {};
  const replyWithUnknown = {
    sentences: colophonReply.sentences.concat([{ text: '不存在的一句。', fact: 'zf-missing' }]),
    conflicts: colophonReply.conflicts.concat([{ quote: '编的', fact: 'zf-missing', why: '不存在' }]),
    suggestion: colophonReply.suggestion
  };
  const service = createKaifengAiService({ configuration: configured,
    fetchImpl: stubFetch(replyWithUnknown, captured), logger: { info: () => {} } });
  const reply = await service.run({ siteId: 'kf-zhouqiao', mode: 'colophon', question: '', draft: '', city: '桥型:平桥' });
  assert.equal(reply.sentences.length, 2);
  assert.equal(reply.conflicts.length, 1);
  assert.equal(captured.body.tools[0].function.name, 'submit_colophon');
});

test('kaifeng ai server: 未配置、错对象、错模式都给出真实错误码', async () => {
  const unconfigured = createKaifengAiService({ configuration: { configured: false } });
  await assert.rejects(() => unconfigured.run({ siteId: 'kf-zhouqiao', mode: 'ask', question: '问' }),
    error => error.message === 'AI_NOT_CONFIGURED');
  let captured = {};
  const service = createKaifengAiService({ configuration: configured,
    fetchImpl: stubFetch(askReply, captured), logger: { info: () => {} } });
  await assert.rejects(() => service.run({ siteId: 'zz-duling-fangding', mode: 'ask', question: '问' }),
    error => error.message === 'KAIFENG_AI_INVALID_SITE');
  await assert.rejects(() => service.run({ siteId: 'kf-zhouqiao', mode: 'chat', question: '问' }),
    error => error.message === 'KAIFENG_AI_INVALID_MODE');
  await assert.rejects(() => service.run({ siteId: 'kf-zhouqiao', mode: 'ask', question: '' }),
    error => error.message === 'KAIFENG_AI_INVALID_QUESTION');
});

test('kaifeng ai server: 供应商失败不读取正文，映射为统一错误', async () => {
  const service = createKaifengAiService({ configuration: configured,
    fetchImpl: async () => ({ ok: false, status: 401, json: async () => { throw new Error('should not read'); } }),
    logger: { info: () => {} } });
  await assert.rejects(() => service.run({ siteId: 'kf-zhouqiao', mode: 'ask', question: '问' }),
    error => error.message === 'AI_PROVIDER_AUTH');
});
