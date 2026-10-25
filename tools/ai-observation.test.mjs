import test from 'node:test';
import assert from 'node:assert/strict';
import { HERITAGE_SITES } from '../entry/src/main/ets/data/HeritageCatalog.ts';
import { materialStudyForId } from '../entry/src/main/ets/data/MaterialStudyCatalog.ts';
import { DULING_OBSERVATION } from '../entry/src/main/ets/domain/DulingObservation.ts';
import {
  AI_CONTENT_REVISION, AI_OBSERVATION_SITE_ID, AI_OBSERVATION_SITE_IDS, acceptAiReply, aiErrorMessage,
  buildAiKnowledgeScope, buildAiMemoryAssist, collectAiReplyFactIds, isAiObservationSite,
  validateAiObservationReply, validateAiObservationRequest
} from '../entry/src/main/ets/domain/AiObservation.ts';
import { DAHECUN_OBSERVATION } from '../entry/src/main/ets/domain/DahecunObservation.ts';
import { domainModuleUrl } from './load-domain-module.mjs';
const { activeRecords, compareVersions, copySnapshot, emptySnapshot, mergeRecords, parseSnapshot } =
  await import(domainModuleUrl('ArchiveDomain'));

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
const twinStudy = materialStudyForId('zz-dahecun');
const twinScope = buildAiKnowledgeScope(twinStudy, DAHECUN_OBSERVATION);
const twinDraftRequest = (patch = {}) => request({
  siteId: 'zz-dahecun', hotspotId: 'opening', purpose: 'draft_memory',
  question: '把腹部通口的观察整理成手账', userObservation: '我沿浅绿色通道看到了两侧内腔相通的位置。',
  ...patch
});
const twinDraftReply = (patch = {}) => reply({
  siteId: 'zz-dahecun', answer: '腹部接合处有椭圆形通口，使两壶内部相通。', factIds: ['dahecun-opening'],
  actions: [{ type: 'focus_hotspot', hotspotId: 'opening', factIds: ['dahecun-opening'], label: '看腹部通口' }],
  draft: { body: '我沿浅绿色通道观察两侧内腔，腹部接合处的椭圆形通口让两壶内部相通。',
    tags: ['双连壶', '腹部通口'], factIds: ['dahecun-opening'] },
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

test('AI supports the twin vessel with its own facts, hotspots and starters', () => {
  // 第二对象必须使用自己的事实与热点；方鼎的八组问法不能复用到双连壶。
  const dahecun = buildAiKnowledgeScope(materialStudyForId('zz-dahecun'), DAHECUN_OBSERVATION);
  assert.deepEqual(AI_OBSERVATION_SITE_IDS, ['zz-duling-fangding', 'zz-dahecun']);
  assert.equal(dahecun.objectName, '大河村彩陶双连壶');
  assert.equal(dahecun.sceneRevision, 2);
  assert.deepEqual(dahecun.facts.map(fact => fact.id), ['dahecun-object', 'dahecun-opening', 'dahecun-lines']);
  assert.deepEqual(dahecun.hotspots.map(hotspot => hotspot.id), ['mouth', 'opening', 'paint']);
  assert.equal(dahecun.starters.length, 3);
  assert.equal(isAiObservationSite('zz-dahecun'), true);
  // 有资料但没有开放 AI 的对象保持不可问，避免入口与服务端错位。
  assert.equal(isAiObservationSite('smx-miaodigou'), false);
  const twinRequest = { ...request(), siteId: 'zz-dahecun', hotspotId: 'opening', question: dahecun.question };
  assert.equal(validateAiObservationRequest(twinRequest, dahecun).siteId, 'zz-dahecun');
  assert.throws(() => validateAiObservationRequest(twinRequest, scope), /AI_INVALID_REQUEST/);
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

test('twin vessel replies reject Ding facts in the answer, actions and draft', () => {
  const validRequest = validateAiObservationRequest(twinDraftRequest(), twinScope);
  const valid = validateAiObservationReply(twinDraftReply(), validRequest, twinScope);
  assert.deepEqual(collectAiReplyFactIds(valid), ['dahecun-opening']);
  assert.doesNotThrow(() => validateAiObservationReply(twinDraftReply({
    actions: [{ type: 'focus_hotspot', hotspotId: 'opening', factIds: [], label: '看腹部通口' }]
  }), validRequest, twinScope));
  // opening 是合法热点也不能夹带方鼎依据；回复、聚焦、依据按钮和草稿都属于同一对象契约。
  const foreignReferences = [
    { factIds: ['dahecun-opening', 'duling-eight'] },
    { actions: [{ type: 'focus_hotspot', hotspotId: 'opening', factIds: ['duling-eight'], label: '看腹部通口' }] },
    { actions: [{ type: 'show_evidence', hotspotId: '', factIds: ['duling-eight'], label: '查看依据' }] },
    { draft: { ...valid.draft, factIds: ['dahecun-opening', 'duling-eight'] } }
  ];
  for (const patch of foreignReferences) {
    assert.throws(() => validateAiObservationReply(twinDraftReply(patch), validRequest, twinScope), /AI_INVALID_REPLY/,
      `双连壶拒绝跨对象引用：${JSON.stringify(patch)}`);
  }
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

test('adopted twin vessel opening draft freezes its own catalog fact', () => {
  const adoptionScope = buildAiKnowledgeScope(twinStudy, DAHECUN_OBSERVATION);
  const opening = adoptionScope.facts.find(fact => fact.id === 'dahecun-opening');
  const validRequest = validateAiObservationRequest(twinDraftRequest(), adoptionScope);
  const validReply = validateAiObservationReply(twinDraftReply(), validRequest, adoptionScope);
  const adoption = {
    question: validRequest.question, factIds: validReply.draft.factIds,
    contentRevision: validReply.contentRevision, facts: [opening],
    body: validReply.draft.body, tags: validReply.draft.tags
  };
  const assist = buildAiMemoryAssist(adoption, adoptionScope);
  const frozen = structuredClone(assist);
  assert.equal(assist.version, 1);
  assert.equal(assist.contentRevision, AI_CONTENT_REVISION);
  assert.equal(assist.question, validRequest.question);
  assert.deepEqual(assist.factIds, ['dahecun-opening']);
  assert.deepEqual(assist.facts, [twinStudy.facts.find(fact => fact.id === 'dahecun-opening')]);
  // 保存依据是采纳当时的副本；后续问答更换引用、资料正文修订都不能改到这页手账。
  adoption.factIds.push('dahecun-lines');
  opening.body = '后续资料修订';
  opening.sourceIds.push('later-source');
  assert.deepEqual(assist, frozen);
  assert.throws(() => buildAiMemoryAssist({
    ...adoption, factIds: ['dahecun-opening', 'duling-eight'],
    facts: [frozen.facts[0], scope.facts.find(fact => fact.id === 'duling-eight')]
  }, adoptionScope), /AI_INVALID_DRAFT/);
});

test('twin vessel frozen AI metadata survives snapshot transfer, editing copy and merge', () => {
  const draft = twinDraftReply().draft;
  const assist = buildAiMemoryAssist({
    question: twinDraftRequest().question, factIds: draft.factIds, contentRevision: AI_CONTENT_REVISION,
    facts: [twinScope.facts.find(fact => fact.id === 'dahecun-opening')], body: draft.body, tags: draft.tags
  }, twinScope);
  const record = {
    id: 'note:device_a:100', kind: 'note', siteId: 'zz-dahecun', body: draft.body, tags: draft.tags,
    updatedAt: 100, deviceId: 'device_a', deleted: false, aiAssist: assist
  };
  const snapshot = { ...emptySnapshot('device_a'), records: [record] };
  const parsed = parseSnapshot(JSON.stringify(snapshot));
  assert.deepEqual(parsed, snapshot);
  // 这里只验证传输快照契约；B 的安装身份独立，收到的手账仍保留 A 的记录来源与冻结依据。
  const received = parseSnapshot(JSON.stringify({
    ...emptySnapshot('device_b'), records: mergeRecords([], parsed.records).records
  }));
  assert.equal(received.deviceId, 'device_b');
  assert.deepEqual(received.records[0], record);
  const editing = copySnapshot(received);
  editing.records[0].aiAssist.question = '编辑中的新问题';
  editing.records[0].aiAssist.factIds.push('dahecun-lines');
  editing.records[0].aiAssist.facts[0].body = '编辑中的依据';
  editing.records[0].aiAssist.facts[0].sourceIds.push('editing-source');
  assert.deepEqual(received.records[0].aiAssist, assist);
  assert.deepEqual(parsed.records[0].aiAssist, assist);

  const newer = { ...record, body: '我换个角度仍能找到连接两腹的通口。', updatedAt: 200, deviceId: 'device_b' };
  const merged = mergeRecords(parsed.records, [newer]);
  assert.deepEqual(merged.records, [newer]);
  assert.deepEqual(merged.records[0].aiAssist, assist);
  assert.deepEqual(merged.conflicts[0].aiAssist, assist);
  assert.deepEqual(mergeRecords([newer], parsed.records).records, merged.records);
  assert.deepEqual(mergeRecords(merged.records, parsed.records).records, merged.records);
  // 即使正文、时间与设备相同，换过提问的 AI 依据也须参与版本比较，不能被同步判成同一版本。
  assert.notEqual(compareVersions(record, { ...record, aiAssist: { ...assist, question: '腹部通口在哪里？' } }), 0);
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
