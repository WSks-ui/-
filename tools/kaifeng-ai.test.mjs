import assert from 'node:assert/strict';
import { test } from 'node:test';
import { domainModuleUrl } from './load-domain-module.mjs';

const {
  KAIFENG_AI_SITE_ID, KAIFENG_AI_MAX_QUESTION, validateKaifengAiRequest, validateKaifengAiAnswer,
  validateKaifengColophon, buildKaifengAiAssist, kaifengAiFactCount
} = await import(domainModuleUrl('KaifengAi'));

const request = (patch = {}) => ({
  siteId: KAIFENG_AI_SITE_ID, mode: 'ask', question: '州桥为什么低平？', draft: '', city: '', ...patch
});
const answer = (patch = {}) => ({
  answer: '州桥低平，不通舟船，船要在东岸卸货。', cites: ['zf-low-flat'], anchor: 'bridge', refused: false, ...patch
});
const colophon = (patch = {}) => ({
  sentences: [
    { text: '州桥低平，不通舟船。', fact: 'zf-low-flat' },
    { text: '明代在同一位置改建单孔拱桥。', fact: 'zf-ming-arch' }
  ],
  conflicts: [], suggestion: '', ...patch
});

test('kaifeng ai: 只接受本对象的问与题跋请求', () => {
  assert.equal(validateKaifengAiRequest(request()).siteId, KAIFENG_AI_SITE_ID);
  assert.throws(() => validateKaifengAiRequest(request({ siteId: 'zz-duling-fangding' })));
  assert.throws(() => validateKaifengAiRequest(request({ mode: 'chat' })));
  assert.throws(() => validateKaifengAiRequest(request({ question: '问'.repeat(KAIFENG_AI_MAX_QUESTION + 1) })));
  assert.throws(() => validateKaifengAiRequest(request({ question: '   ' })));
  assert.equal(validateKaifengAiRequest(request({ mode: 'colophon', question: '' })).mode, 'colophon');
  assert.equal(kaifengAiFactCount(), 7);
});

test('kaifeng ai: 回答必须有已知事实引用与合法锚点', () => {
  const ok = validateKaifengAiAnswer(answer());
  assert.deepEqual(ok.cites, ['zf-low-flat']);
  assert.equal(ok.anchor, 'bridge');
  assert.equal(ok.refused, false);

  assert.throws(() => validateKaifengAiAnswer(answer({ cites: ['zf-not-exist'] })));
  assert.throws(() => validateKaifengAiAnswer(answer({ cites: [] })));
  assert.throws(() => validateKaifengAiAnswer(answer({ anchor: 'moon' })));
  assert.throws(() => validateKaifengAiAnswer(answer({ answer: '字'.repeat(261) })));
});

test('kaifeng ai: 回答里的四位年份必须能在被引事实中找到', () => {
  // 1642 只出现在明末淤埋那条里；引到“低平”条就是编年代。
  assert.throws(() => validateKaifengAiAnswer(answer({
    answer: '州桥在1642年被淤埋。', cites: ['zf-low-flat'], anchor: 'bridge'
  })));
  const grounded = validateKaifengAiAnswer(answer({
    answer: '州桥在1642年被黄河泥沙淤埋。', cites: ['zf-silt-burial'], anchor: 'section'
  }));
  assert.deepEqual(grounded.cites, ['zf-silt-burial']);
});

test('kaifeng ai: 证据不足时可以拒答，但拒答也必须说明锚点', () => {
  const refused = validateKaifengAiAnswer({
    answer: '现有依据不足以回答这个问题。', cites: [], anchor: 'bridge', refused: true
  });
  assert.equal(refused.refused, true);
  assert.equal(refused.cites.length, 0);
  assert.throws(() => validateKaifengAiAnswer({ answer: '不知道。', cites: [], anchor: 'moon', refused: true }));
});

test('kaifeng ai: 题跋逐句接地，落不到事实的句子被丢弃并计数', () => {
  const result = validateKaifengColophon(colophon({
    sentences: [
      { text: '州桥低平，不通舟船。', fact: 'zf-low-flat' },
      { text: '这里曾经有一座彩虹桥。', fact: 'zf-ming-arch' },
      { text: '明代在同一位置改建单孔拱桥。', fact: 'zf-ming-arch' }
    ]
  }));
  assert.equal(result.sentences.length, 2);
  assert.equal(result.dropped, 1);
  assert.deepEqual(result.sentences.map(item => item.fact), ['zf-low-flat', 'zf-ming-arch']);
});

test('kaifeng ai: 整段都没有出处时整条拒收，不返回空题跋', () => {
  assert.throws(() => validateKaifengColophon(colophon({
    sentences: [{ text: '这是一段没有出处的题跋。', fact: 'zf-low-flat' }]
  })));
  assert.throws(() => validateKaifengColophon(colophon({
    sentences: [{ text: '州桥低平。', fact: 'zf-missing' }]
  })));
});

test('kaifeng ai: 冲突条目只保留已知事实，并截断到界面可读长度', () => {
  const result = validateKaifengColophon(colophon({
    conflicts: [
      { quote: '船从桥下过', fact: 'zf-low-flat', why: '原文为低平不通舟船' },
      { quote: '编的', fact: 'zf-missing', why: '不存在' }
    ]
  }));
  assert.equal(result.conflicts.length, 1);
  assert.equal(result.conflicts[0].fact, 'zf-low-flat');
});

test('kaifeng ai: 题跋入库只冻结最多三条已接地事实', () => {
  const result = validateKaifengColophon(colophon({
    sentences: [
      { text: '州桥低平，不通舟船。', fact: 'zf-low-flat' },
      { text: '桥下密排石柱，是车驾御路。', fact: 'zf-stone-piles' },
      { text: '明代在同一位置改建单孔拱桥。', fact: 'zf-ming-arch' },
      { text: '明末黄河泥沙把州桥淤埋。', fact: 'zf-silt-burial' }
    ]
  }));
  const assist = buildKaifengAiAssist('为我的汴京城写题跋', result);
  assert.equal(assist.factIds.length, 3);
  assert.equal(assist.facts.length, 3);
  assert.equal(assist.question, '为我的汴京城写题跋');
  assert.ok(assist.facts.every(fact => fact.sourceIds.length === 1));
});
