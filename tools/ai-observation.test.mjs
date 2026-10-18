import test from 'node:test';
import assert from 'node:assert/strict';
import { HERITAGE_SITES } from '../entry/src/main/ets/data/HeritageCatalog.ts';
import { materialStudyForId } from '../entry/src/main/ets/data/MaterialStudyCatalog.ts';
import { DULING_OBSERVATION } from '../entry/src/main/ets/domain/DulingObservation.ts';
import {
  AI_CONTENT_REVISION, AI_OBSERVATION_SITE_ID, acceptAiReply, aiErrorMessage,
  buildAiKnowledgeScope, buildAiMemoryAssist, collectAiReplyFactIds, validateAiObservationReply,
  validateAiObservationRequest
} from '../entry/src/main/ets/domain/AiObservation.ts';
import {
  activeRecords, compareVersions, copySnapshot, emptySnapshot, mergeRecords, parseSnapshot
} from '../entry/src/main/ets/domain/ArchiveDomain.ts';

const study = materialStudyForId(AI_OBSERVATION_SITE_ID);
const scope = buildAiKnowledgeScope(study, DULING_OBSERVATION);
const request = (patch = {}) => ({
  version: 1, requestId: 'ai-12345678-1', siteId: AI_OBSERVATION_SITE_ID, sceneRevision: 2,
  hotspotId: 'centers', purpose: 'observe', question: '只有四面，八组是怎么数出来的？',
  turns: [], userObservation: '', ...patch
});
const reply = (patch = {}) => ({
  version: 1, requestId: 'ai-12345678-1', siteId: AI_OBSERVATION_SITE_ID, contentRevision: AI_CONTENT_REVISION,
  status: 'grounded', answer: '每壁正中一组，四个折角再各一组，合计八组。', factIds: ['duling-eight'],
  actions: [{ type: 'focus_hotspot', hotspotId: 'corners', factIds: ['duling-eight'], label: '看四个折角' }],
  ...patch
});

test('AI knowledge scope comes from the existing Ding catalog and hotspots', () => {
  assert.equal(study.siteId, AI_OBSERVATION_SITE_ID);
  assert.equal(scope.siteId, AI_OBSERVATION_SITE_ID);
  assert.equal(scope.sceneRevision, 2);
  assert.equal(scope.contentRevision, 1);
  assert.deepEqual(scope.facts.map(fact => fact.id), ['duling-object', 'duling-size', 'duling-eight']);
  assert.deepEqual(scope.facts.map(fact => fact.body), study.facts.map(fact => fact.body));
  assert.deepEqual(scope.hotspots.map(hotspot => hotspot.id), ['centers', 'corners', 'frame']);
  assert.equal(scope.sources[0].publisher, '河南博物院');
  assert.ok(HERITAGE_SITES.some(site => site.id === AI_OBSERVATION_SITE_ID));
});

test('AI request validation rejects another site, scene revision, hotspot or oversized context', () => {
  const valid = validateAiObservationRequest(request(), scope);
  assert.equal(valid.siteId, AI_OBSERVATION_SITE_ID);
  assert.equal(valid.sceneRevision, 2);
  assert.throws(() => validateAiObservationRequest(request({ siteId: 'zz-dahecun' }), scope), /AI_INVALID_REQUEST/);
  assert.throws(() => validateAiObservationRequest(request({ sceneRevision: 1 }), scope), /AI_INVALID_REQUEST/);
  assert.throws(() => validateAiObservationRequest(request({ hotspotId: 'paint' }), scope), /AI_INVALID_REQUEST/);
  assert.throws(() => validateAiObservationRequest(request({ question: '   ' }), scope), /AI_INVALID_REQUEST/);
  assert.throws(() => validateAiObservationRequest(request({ question: '问'.repeat(201) }), scope), /AI_INVALID_REQUEST/);
  assert.throws(() => validateAiObservationRequest(request({ turns: Array(7).fill({ role: 'user', content: 'x' }) }), scope), /AI_INVALID_REQUEST/);
  assert.doesNotThrow(() => validateAiObservationRequest(request({ purpose: 'draft_memory', userObservation: '' }), scope));
  assert.doesNotThrow(() => validateAiObservationRequest(request({ userObservation: '我先数到四个正面。' }), scope));
});

test('AI reply validation closes request identity, facts and executable actions', () => {
  const validRequest = validateAiObservationRequest(request(), scope);
  const valid = validateAiObservationReply(reply(), validRequest, scope);
  assert.equal(valid.status, 'grounded');
  assert.deepEqual(collectAiReplyFactIds(valid), ['duling-eight']);
  assert.throws(() => validateAiObservationReply(reply({ requestId: 'ai-other-request' }), validRequest, scope), /AI_INVALID_REPLY/);
  assert.throws(() => validateAiObservationReply(reply({ siteId: 'zz-dahecun' }), validRequest, scope), /AI_INVALID_REPLY/);
  assert.throws(() => validateAiObservationReply(reply({ contentRevision: 2 }), validRequest, scope), /AI_INVALID_REPLY/);
  assert.throws(() => validateAiObservationReply(reply({ factIds: ['made-up-fact'] }), validRequest, scope), /AI_INVALID_REPLY/);
  assert.throws(() => validateAiObservationReply(reply({ factIds: [] }), validRequest, scope), /AI_INVALID_REPLY/);
  assert.throws(() => validateAiObservationReply(reply({
    actions: [{ type: 'focus_hotspot', hotspotId: 'paint', factIds: [], label: '看错部位' }]
  }), validRequest, scope), /AI_INVALID_REPLY/);
  assert.throws(() => validateAiObservationReply(reply({
    actions: [{ type: 'run_script', hotspotId: '', factIds: [], label: '执行' }]
  }), validRequest, scope), /AI_INVALID_REPLY/);
  assert.throws(() => validateAiObservationReply(reply({
    draft: { body: '草稿', tags: ['观察'], factIds: ['duling-eight'] }
  }), validRequest, scope), /AI_INVALID_REPLY/);
  assert.throws(() => validateAiObservationReply(reply({ status: 'grounded', factIds: [] }), validRequest, scope), /AI_INVALID_REPLY/);
});

test('insufficient evidence and draft replies keep their own contract', () => {
  const observeRequest = validateAiObservationRequest(request(), scope);
  const insufficient = validateAiObservationReply(reply({
    status: 'insufficient_evidence', answer: '当前资料没有记载具体祭祀对象，不能推测。', factIds: [], actions: []
  }), observeRequest, scope);
  assert.equal(insufficient.status, 'insufficient_evidence');
  const draftRequest = validateAiObservationRequest(request({
    purpose: 'draft_memory', userObservation: '我先数到四个正面，转到折角才找到另外四组。'
  }), scope);
  const draftReply = validateAiObservationReply(reply({
    draft: { body: '正面四组，折角四组，合起来八组。', tags: ['方鼎', '兽面纹'], factIds: ['duling-eight'] }
  }), draftRequest, scope);
  assert.ok(draftReply.draft);
  assert.equal(draftReply.draft.body, '正面四组，折角四组，合起来八组。');
  assert.throws(() => validateAiObservationReply(reply({
    draft: { body: '', tags: [], factIds: ['duling-eight'] }
  }), draftRequest, scope), /AI_INVALID_REPLY/);
});

test('late AI replies cannot overwrite a stopped or changed observation', () => {
  const validRequest = validateAiObservationRequest(request(), scope);
  const validReply = validateAiObservationReply(reply(), validRequest, scope);
  assert.equal(acceptAiReply(validReply, validRequest, AI_OBSERVATION_SITE_ID, 2, validRequest.requestId), true);
  assert.equal(acceptAiReply(validReply, validRequest, AI_OBSERVATION_SITE_ID, 2, ''), false);
  assert.equal(acceptAiReply(validReply, validRequest, 'zz-dahecun', 2, validRequest.requestId), false);
  assert.equal(acceptAiReply(validReply, validRequest, AI_OBSERVATION_SITE_ID, 1, validRequest.requestId), false);
  assert.equal(acceptAiReply({ ...validReply, requestId: 'ai-stale-reply' }, validRequest,
    AI_OBSERVATION_SITE_ID, 2, validRequest.requestId), false);
});

test('adopted AI draft freezes catalog facts and deep copies source ids', () => {
  const assist = buildAiMemoryAssist({
    question: '只有四面，八组是怎么数出来的？', factIds: ['duling-eight'], contentRevision: 1,
    facts: [scope.facts.find(fact => fact.id === 'duling-eight')], body: '我沿折角数了四组，加上正面四组合为八组。',
    tags: ['方鼎', '观察']
  }, scope);
  assert.equal(assist.version, 1);
  assert.equal(assist.contentRevision, 1);
  assert.equal(assist.facts[0].body, study.facts[2].body);
  assert.equal(assist.question, '只有四面，八组是怎么数出来的？');
  assist.facts[0].sourceIds.push('mutated');
  assert.deepEqual(scope.facts.find(fact => fact.id === 'duling-eight').sourceIds, ['museum-duling-two']);
  assert.throws(() => buildAiMemoryAssist({
    question: '问题', factIds: ['duling-eight'], contentRevision: 99,
    facts: [scope.facts[2]], body: '正文', tags: []
  }, scope), /AI_INVALID_DRAFT/);
  assert.throws(() => buildAiMemoryAssist({
    question: '问题', factIds: ['duling-eight', 'duling-size'], contentRevision: 1,
    facts: [scope.facts[2]], body: '正文', tags: []
  }, scope), /AI_INVALID_DRAFT/);
});

test('AI note metadata survives parse, deep copy and deterministic merge', () => {
  const assist = buildAiMemoryAssist({
    question: '只有四面，八组是怎么数出来的？', factIds: ['duling-eight'], contentRevision: 1,
    facts: [scope.facts[2]], body: '我沿折角数了四组，加上正面四组合为八组。', tags: ['方鼎']
  }, scope);
  const record = {
    id: 'note:device_a:100', kind: 'note', siteId: AI_OBSERVATION_SITE_ID, body: '我沿折角数了四组。',
    tags: ['方鼎'], updatedAt: 100, deviceId: 'device_a', deleted: false, stampType: '商都吉金',
    paperTheme: 'ochre', quotedPoemOrFact: study.facts[2].body, aiAssist: assist
  };
  const snapshot = { schemaVersion: 1, deviceId: 'device_a', records: [record], lightEnabled: true, reducedMotion: false };
  const parsed = parseSnapshot(JSON.stringify(snapshot));
  assert.equal(parsed.records[0].aiAssist.factIds[0], 'duling-eight');
  assert.equal(parsed.records[0].aiAssist.facts[0].title, '四面正中，加上四个折角');
  const copied = copySnapshot(parsed);
  copied.records[0].aiAssist.facts[0].body = '被修改';
  copied.records[0].aiAssist.factIds.push('duling-size');
  assert.notEqual(parsed.records[0].aiAssist.facts[0].body, '被修改');
  assert.deepEqual(parsed.records[0].aiAssist.factIds, ['duling-eight']);
  assert.throws(() => parseSnapshot(JSON.stringify({
    ...snapshot, records: [{ ...record, aiAssist: { ...assist, factIds: ['duling-eight', 'duling-size'] } }]
  })), /ARCHIVE_INVALID_RECORD/);
  assert.throws(() => parseSnapshot(JSON.stringify({
    ...snapshot, records: [{ ...record, aiAssist: { ...assist, facts: [] } }]
  })), /ARCHIVE_INVALID_RECORD/);

  const newer = { ...record, body: '补充：乳钉边框不算八组。', updatedAt: 200, deviceId: 'device_b',
    aiAssist: { ...assist, question: '乳钉边框为什么不算八组？', factIds: ['duling-eight'],
      facts: assist.facts.map(fact => ({ ...fact, sourceIds: fact.sourceIds.slice() })) } };
  assert.notEqual(compareVersions(newer, record), 0);
  const merged = mergeRecords([record], [newer]);
  assert.equal(merged.records[0].body, '补充：乳钉边框不算八组。');
  assert.equal(merged.records[0].aiAssist.question, '乳钉边框为什么不算八组？');
  assert.equal(merged.conflicts[0].aiAssist.question, '只有四面，八组是怎么数出来的？');
  const deleted = { ...newer, deleted: true, updatedAt: 300, deviceId: 'device_a' };
  const tombstone = mergeRecords([record], [deleted]);
  assert.equal(tombstone.records[0].deleted, true);
  assert.ok(tombstone.records[0].aiAssist);
  assert.equal(activeRecords(tombstone.records, 'note').length, 0);
});

test('AI error copy never disguises failure as a successful answer', () => {
  assert.match(aiErrorMessage('AI_NOT_CONFIGURED'), /没有调用 AI/);
  assert.match(aiErrorMessage('AI_TIMEOUT'), /没有生成回答/);
  assert.match(aiErrorMessage('AI_INVALID_REPLY'), /没有采用/);
  assert.match(aiErrorMessage('ACCOUNT_SESSION_EXPIRED'), /重新登录/);
  assert.match(aiErrorMessage('UNKNOWN'), /没有生成回答/);
});
