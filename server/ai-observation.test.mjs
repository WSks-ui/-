import test from 'node:test';
import assert from 'node:assert/strict';
import {
  buildObservationMessages, createAiObservationService, describeAiConfiguration,
  loadAiConfiguration
} from './ai-observation.mjs';
import { aiScopeFor } from './ai-observation.mjs';

const request = (patch = {}) => ({
  version: 1, requestId: 'ai-server-test-1', siteId: 'zz-duling-fangding', sceneRevision: 2,
  hotspotId: 'centers', purpose: 'observe', question: '只有四面，八组是怎么数出来的？',
  turns: [], userObservation: '', ...patch
});
const modelReply = (patch = {}) => ({
  status: 'grounded',
  answer: '每壁正中一组，四个折角再各一组，合计八组。可以先看玫瑰标记，再沿折角找陶土色折片。',
  factIds: ['duling-eight'],
  actions: [{ type: 'focus_hotspot', hotspotId: 'corners', factIds: ['duling-eight'], label: '模型自带标签会被应用覆盖' }],
  ...patch
});
const response = (value, status = 200) => ({
  ok: status >= 200 && status < 300,
  status,
  json: async () => ({ choices: [{ message: { content: '', tool_calls: [{ function: {
    name: 'submit_observation', arguments: typeof value === 'string' ? value : JSON.stringify(value)
  } }] } }] })
});
const configuration = (patch = {}) => ({
  provider: 'deepseek', model: 'deepseek-test', baseUrl: 'https://api.example.invalid/v1', apiKey: 'sk-test-key-12345678',
  timeoutMs: 5000, configured: true, ...patch
});
const twinDraftRequest = () => request({
  siteId: 'zz-dahecun', hotspotId: 'opening', purpose: 'draft_memory',
  question: '把腹部通口的观察整理成手账', userObservation: '我沿浅绿色通道看到了两侧内腔相通的位置。'
});
const twinModelReply = (patch = {}) => modelReply({
  answer: '腹部接合处有椭圆形通口，使两壶内部相通。', factIds: ['dahecun-opening'],
  actions: [{ type: 'focus_hotspot', hotspotId: 'opening', factIds: ['dahecun-opening'], label: '模型自带标签' }],
  draft: { body: '我沿浅绿色通道观察两侧内腔，腹部接合处的椭圆形通口让两壶内部相通。',
    tags: ['双连壶', '腹部通口'], factIds: ['dahecun-opening'] },
  ...patch
});

test('AI configuration reports availability without exposing the key', () => {
  const loaded = loadAiConfiguration({ env: { DEEPSEEK_API_KEY: 'sk-test-key-12345678', YUNHEJI_AI_MODEL: 'deepseek-test' }, configPath: null });
  assert.equal(loaded.configured, true);
  assert.equal(loaded.model, 'deepseek-test');
  const description = describeAiConfiguration(loaded);
  assert.equal(description.configured, true);
  assert.equal(description.model, 'deepseek-test');
  assert.equal(JSON.stringify(description).includes('sk-test'), false);
  assert.equal(JSON.stringify(description).includes('api.example'), false);
  const missing = loadAiConfiguration({ env: {}, configPath: null });
  assert.equal(missing.configured, false);
  assert.equal(describeAiConfiguration(missing).configured, false);
});

test('unconfigured AI returns a real failure state instead of a canned answer', async () => {
  const service = createAiObservationService({ configuration: configuration({ configured: false, apiKey: '' }) });
  assert.equal(service.available, false);
  await assert.rejects(() => service.run(request(), {}), error => error.message === 'AI_NOT_CONFIGURED' && error.status === 503);
});

test('draft request without a user observation asks for one without calling the model', async () => {
  let calls = 0;
  const service = createAiObservationService({
    configuration: configuration(),
    fetchImpl: async () => { calls++; return response(modelReply()); }
  });
  const reply = await service.run(request({ purpose: 'draft_memory', userObservation: '' }), {});
  assert.equal(calls, 0);
  assert.equal(reply.status, 'needs_clarification');
  assert.equal(reply.factIds.length, 0);
  assert.match(reply.answer, /先写一句/);
});

test('real adapter sends facts, JSON mode and returns a validated application reply', async () => {
  let captured;
  const service = createAiObservationService({
    configuration: configuration(),
    now: (() => { let value = 1000; return () => { value += 25; return value; }; })(),
    logger: { info: () => {} },
    fetchImpl: async (url, init) => { captured = { url, init }; return response(modelReply()); }
  });
  const reply = await service.run(request(), { account_id: 'a'.repeat(32) });
  assert.equal(captured.url, 'https://api.example.invalid/v1/chat/completions');
  assert.equal(captured.init.headers.Authorization, 'Bearer sk-test-key-12345678');
  const body = JSON.parse(captured.init.body);
  assert.equal(body.model, 'deepseek-test');
  assert.equal(body.response_format, undefined);
  assert.equal(body.tools[0].function.name, 'submit_observation');
  assert.deepEqual(body.tool_choice, { type: 'function', function: { name: 'submit_observation' } });
  assert.deepEqual(body.thinking, { type: 'disabled' });
  assert.equal(body.stream, false);
  assert.ok(body.messages[0].content.includes('duling-eight'));
  assert.ok(body.messages[0].content.includes('杜岭二号方鼎'));
  assert.ok(body.messages[0].content.includes('submit_observation'));
  assert.equal(body.messages.at(-1).role, 'user');
  assert.equal(reply.requestId, 'ai-server-test-1');
  assert.equal(reply.contentRevision, 1);
  assert.equal(reply.factIds[0], 'duling-eight');
  assert.equal(reply.actions[0].label, '看四个折角');
  assert.equal(reply.draft, undefined);
});

test('draft reply is normalized and keeps only validated fact references', async () => {
  const service = createAiObservationService({
    configuration: configuration(),
    fetchImpl: async () => response(modelReply({
      draft: { body: '正面四组，折角四组，合起来八组。', tags: ['方鼎', '兽面纹'], factIds: ['duling-eight'] }
    }))
  });
  const reply = await service.run(request({
    purpose: 'draft_memory', question: '把这次观察整理为手账', userObservation: '我先数到四个正面，转到折角才找到另外四组。'
  }), {});
  assert.ok(reply.draft);
  assert.equal(reply.draft.body, '正面四组，折角四组，合起来八组。');
  assert.deepEqual(reply.draft.tags, ['方鼎', '兽面纹']);
});

test('twin vessel opening draft keeps its facts, tags and own hotspot label', async () => {
  let captured;
  const service = createAiObservationService({
    configuration: configuration(), logger: { info: () => {} },
    fetchImpl: async (_url, init) => { captured = JSON.parse(init.body); return response(twinModelReply()); }
  });
  const reply = await service.run(twinDraftRequest(), { account_id: 'a'.repeat(32) });
  assert.equal(reply.siteId, 'zz-dahecun');
  assert.equal(reply.requestId, twinDraftRequest().requestId);
  assert.equal(reply.contentRevision, aiScopeFor('zz-dahecun').contentRevision);
  assert.deepEqual(reply.factIds, ['dahecun-opening']);
  assert.deepEqual(reply.actions, [{
    type: 'focus_hotspot', hotspotId: 'opening', factIds: ['dahecun-opening'], label: '看腹部通口'
  }]);
  assert.deepEqual(reply.draft, twinModelReply().draft);
  assert.ok(captured.messages[0].content.includes('dahecun-opening'));
  assert.ok(!captured.messages[0].content.includes('duling-eight'));
  assert.ok(captured.messages.at(-1).content.includes(twinDraftRequest().userObservation));
});

test('twin vessel adapter rejects Ding facts in every reply reference', async () => {
  // 服务端须拒绝整条跨对象回复，不能删掉错引后把草稿显示为可采纳。
  const foreignReferences = [
    { factIds: ['dahecun-opening', 'duling-eight'] },
    { actions: [{ type: 'focus_hotspot', hotspotId: 'opening', factIds: ['duling-eight'] }] },
    { actions: [{ type: 'show_evidence', factIds: ['duling-eight'] }] },
    { draft: { ...twinModelReply().draft, factIds: ['dahecun-opening', 'duling-eight'] } }
  ];
  for (const patch of foreignReferences) {
    const service = createAiObservationService({
      configuration: configuration(), logger: { info: () => {} },
      fetchImpl: async () => response(twinModelReply(patch))
    });
    await assert.rejects(() => service.run(twinDraftRequest(), {}),
      error => error.message === 'AI_INVALID_REPLY' && error.status === 502,
      `双连壶拒绝跨对象引用：${JSON.stringify(patch)}`);
  }
});

test('invalid model content, facts or actions fail the whole reply', async () => {
  const invalidCases = [
    'not json at all',
    modelReply({ factIds: ['made-up-fact'], actions: [] }),
    modelReply({ factIds: [], actions: [] }),
    modelReply({ actions: [{ type: 'focus_hotspot', hotspotId: 'paint', factIds: [], label: '看错部位' }] }),
    modelReply({ actions: [{ type: 'run_script', hotspotId: '', factIds: [], label: '执行' }] })
  ];
  for (const value of invalidCases) {
    const service = createAiObservationService({ configuration: configuration(), fetchImpl: async () => response(value) });
    await assert.rejects(() => service.run(request(), {}), error => error.message === 'AI_INVALID_REPLY' && error.status === 502);
  }
  const empty = createAiObservationService({
    configuration: configuration(),
    fetchImpl: async () => ({ ok: true, status: 200, json: async () => ({ choices: [{ message: { content: '' } }] }) })
  });
  await assert.rejects(() => empty.run(request(), {}), error => error.message === 'AI_INVALID_REPLY');
});

test('timeouts, provider errors and rate limits map to distinct states', async () => {
  const aborted = createAiObservationService({
    configuration: configuration(),
    fetchImpl: async () => { const error = new Error('aborted'); error.name = 'AbortError'; throw error; }
  });
  await assert.rejects(() => aborted.run(request(), {}), error => error.message === 'AI_TIMEOUT' && error.status === 504);
  const provider = createAiObservationService({
    configuration: configuration(),
    fetchImpl: async () => ({ ok: false, status: 503, json: async () => ({}) })
  });
  await assert.rejects(() => provider.run(request(), {}), error => error.message === 'AI_PROVIDER_ERROR' && error.status === 502);
  const limited = createAiObservationService({
    configuration: configuration(),
    fetchImpl: async () => ({ ok: false, status: 429, json: async () => ({}) })
  });
  await assert.rejects(() => limited.run(request(), {}), error => error.message === 'AI_RATE_LIMITED' && error.status === 429);
  // 凭证与余额分别成码，避免现场把 401/402 误判成网络故障。
  const unauthorized = createAiObservationService({
    configuration: configuration(),
    fetchImpl: async () => ({ ok: false, status: 401, json: async () => ({}) })
  });
  await assert.rejects(() => unauthorized.run(request(), {}), error => error.message === 'AI_PROVIDER_AUTH' && error.status === 503);
  const unpaid = createAiObservationService({
    configuration: configuration(),
    fetchImpl: async () => ({ ok: false, status: 402, json: async () => ({}) })
  });
  await assert.rejects(() => unpaid.run(request(), {}), error => error.message === 'AI_PROVIDER_QUOTA' && error.status === 503);
});

test('server rejects unsupported sites or unknown hotspot before calling the model', async () => {
  let calls = 0;
  const service = createAiObservationService({
    configuration: configuration(),
    fetchImpl: async () => { calls++; return response(modelReply()); }
  });
  // 庙底沟有资料但未开放 AI；双连壶已开放，但 paint 是它的热点，不能用于方鼎请求。
  await assert.rejects(() => service.run(request({ siteId: 'smx-miaodigou' }), {}), error => error.message === 'AI_INVALID_REQUEST');
  await assert.rejects(() => service.run(request({ hotspotId: 'paint' }), {}), error => error.message === 'AI_INVALID_REQUEST');
  assert.equal(calls, 0);
  assert.equal(aiScopeFor('smx-miaodigou'), undefined);
  assert.equal(aiScopeFor('zz-duling-fangding').facts.length, 3);
  assert.equal(aiScopeFor('zz-dahecun').facts.length, 3);
});

test('twin vessel prompt uses its own object, facts and hotspots', () => {
  const scope = aiScopeFor('zz-dahecun');
  const twinRequest = request({ siteId: 'zz-dahecun', hotspotId: 'opening', question: scope.question });
  const messages = buildObservationMessages(scope, twinRequest);
  const system = messages[0].content;
  assert.ok(system.includes('大河村彩陶双连壶'));
  assert.ok(system.includes('椭圆形通口'));
  assert.ok(system.includes('opening'));
  assert.ok(!system.includes('上腹兽面纹'));
  assert.ok(messages[1].content.includes('内部相通'));
});

test('prompt keeps the three fact bodies and forbids unsupported conclusions', () => {
  const scope = aiScopeFor('zz-duling-fangding');
  const messages = buildObservationMessages(scope, request());
  const system = messages[0].content;
  assert.ok(system.includes('杜岭二号方鼎'));
  assert.ok(system.includes('上腹兽面纹环绕一周'));
  assert.match(system, /资料没有支持/);
  assert.match(system, /不要猜测/);
  assert.match(system, /focus_hotspot/);
  assert.match(system, /show_evidence/);
  assert.match(system, /submit_observation/);
  assert.ok(messages[1].content.includes('只有四面'));
});

test('model output normalizes spaces between Chinese characters only', async () => {
  // 防御性归一化：即使供应商在汉字间夹带空白或零宽字符，也只折叠汉字之间的部分；
  // 数字、英文和单位周围的空格必须保留，避免把有意义的排版一起改掉。
  const service = createAiObservationService({
    configuration: configuration(),
    fetchImpl: async () => response(modelReply({
      answer: '所 以 要看折角，竖\u200b向，共 8 组，详见 Han 8。',
      draft: { body: '我把四面 和折角分开看。', tags: ['观察'], factIds: ['duling-eight'] }
    }))
  });
  const reply = await service.run(request({ purpose: 'draft_memory', userObservation: '我先看了四面。' }), {});
  assert.equal(reply.answer, '所以要看折角，竖向，共 8 组，详见 Han 8。');
  assert.equal(reply.draft.body, '我把四面和折角分开看。');
});

test('revisiting a note includes only its confirmed observation as personal expression', () => {
  const scope = aiScopeFor('zz-duling-fangding');
  const observation = '我先看正面，再转到折角。';
  const messages = buildObservationMessages(scope, request({ userObservation: observation }));
  assert.ok(messages.at(-1).content.includes(observation));
  assert.match(messages.at(-1).content, /不是已核史实/);
  assert.ok(messages.at(-1).content.endsWith(request().question));
  assert.ok(!messages[0].content.includes(observation));
});
