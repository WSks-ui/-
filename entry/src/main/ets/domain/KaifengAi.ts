import type { AiFactSnapshot, AiMemoryAssist } from './ArchiveDomain';
import { KAIFENG_AI_FACTS, kaifengAiFactFor } from './KaifengAiFacts';
import type { KaifengAiFact } from './KaifengAiFacts';

// 开封 AI 的客户端契约。定位是“校书人”，不是作者：
//   ask      只回答州桥/层位/石壁/夜市/灯事，必须带 1–3 条事实引用；
//   colophon 把玩家的城写成 2–4 句题跋草稿，逐句给事实 id；客户端逐句接地，
//            落不到事实的句子直接丢弃，并告知“有一句没有出处”。
// 这里不调用模型，只做输入归一、输出校验与拒收降级；服务端另有一份同样的边界。

export const KAIFENG_AI_SITE_ID: string = 'kf-zhouqiao';
export const KAIFENG_AI_CONTENT_REVISION: number = 1;
export const KAIFENG_AI_MAX_QUESTION: number = 80;
export const KAIFENG_AI_MAX_ANSWER: number = 260;
export const KAIFENG_AI_MAX_DRAFT: number = 200;
export const KAIFENG_AI_MAX_SENTENCES: number = 4;
export const KAIFENG_AI_ANCHORS: string[] = ['bridge', 'section', 'motif', 'market', 'lantern'];

export interface KaifengAiRequest {
  siteId: string;
  // 'ask' 或 'colophon'。
  mode: string;
  question: string;
  draft: string;
  // 城的摘要（桥型/层序/纹样/灯位/城格），只用于题跋，不写入档案。
  city: string;
}

export interface KaifengAiAnswer {
  answer: string;
  cites: string[];
  anchor: string;
  refused: boolean;
}

export interface KaifengAiSentence {
  text: string;
  fact: string;
}

export interface KaifengAiConflict {
  quote: string;
  fact: string;
  why: string;
}

export interface KaifengAiColophon {
  sentences: KaifengAiSentence[];
  conflicts: KaifengAiConflict[];
  suggestion: string;
}

export interface KaifengAiColophonResult {
  sentences: KaifengAiSentence[];
  // 被丢弃的句子数，界面据此显示“有一句没有出处，已略去”。
  dropped: number;
  conflicts: KaifengAiConflict[];
  suggestion: string;
}

function text(value: string, max: number, code: string): string {
  if (typeof value !== 'string' || value.length > max) throw new Error(code);
  return value;
}

export function validateKaifengAiRequest(raw: KaifengAiRequest): KaifengAiRequest {
  if (!raw || raw.siteId !== KAIFENG_AI_SITE_ID) throw new Error('KAIFENG_AI_INVALID_SITE');
  if (raw.mode !== 'ask' && raw.mode !== 'colophon') throw new Error('KAIFENG_AI_INVALID_MODE');
  const question = text(raw.question || '', KAIFENG_AI_MAX_QUESTION, 'KAIFENG_AI_INVALID_QUESTION');
  if (raw.mode === 'ask' && !question.trim()) throw new Error('KAIFENG_AI_INVALID_QUESTION');
  const draft = text(raw.draft || '', KAIFENG_AI_MAX_DRAFT, 'KAIFENG_AI_INVALID_DRAFT');
  const city = text(raw.city || '', 600, 'KAIFENG_AI_INVALID_CITY');
  return { siteId: raw.siteId, mode: raw.mode, question: question.trim(), draft: draft.trim(), city };
}

function uniqueKnownCites(value: string[]): boolean {
  if (!Array.isArray(value) || value.length > 3) return false;
  for (const id of value) {
    if (typeof id !== 'string' || !kaifengAiFactFor(id)) return false;
  }
  return new Set<string>(value).size === value.length;
}

// 年份硬校验：回答里出现的四位年份必须能在被引事实的原文或表述里找到。
// 这不是语义理解，而是防“编一个看起来很真的年代”的最低成本闸门。
function yearsGrounded(answer: string, cites: string[]): boolean {
  const years = answer.match(/\d{4}/g);
  if (!years) return true;
  let corpus = '';
  cites.forEach((id: string) => {
    const fact = kaifengAiFactFor(id);
    if (fact) corpus += `${fact.text}${fact.quote}`;
  });
  return years.every((year: string) => corpus.indexOf(year) >= 0);
}

export function validateKaifengAiAnswer(raw: KaifengAiAnswer): KaifengAiAnswer {
  if (!raw || typeof raw.answer !== 'string') throw new Error('KAIFENG_AI_INVALID_REPLY');
  const answer = text(raw.answer.trim(), KAIFENG_AI_MAX_ANSWER, 'KAIFENG_AI_ANSWER_TOO_LONG');
  const refused = raw.refused === true;
  const cites = Array.isArray(raw.cites) ? raw.cites.slice() : [];
  if (!uniqueKnownCites(cites)) throw new Error('KAIFENG_AI_UNKNOWN_FACT');
  if (!refused && cites.length === 0) throw new Error('KAIFENG_AI_NEEDS_CITATION');
  if (KAIFENG_AI_ANCHORS.indexOf(raw.anchor) < 0) throw new Error('KAIFENG_AI_INVALID_ANCHOR');
  if (!refused && !yearsGrounded(answer, cites)) throw new Error('KAIFENG_AI_UNGROUNDED_YEAR');
  return { answer, cites, anchor: raw.anchor, refused };
}

function sentenceGrounded(text: string, fact: KaifengAiFact): boolean {
  return fact.keywords.some((keyword: string) => text.indexOf(keyword) >= 0);
}

// 题跋逐句接地：句子必须带一个已知 fact，且至少命中该 fact 的一个关键词。
// 不通过的句子不抛错，而是丢弃并计数——界面要能告诉用户“有一句没有出处”。
export function validateKaifengColophon(raw: KaifengAiColophon): KaifengAiColophonResult {
  if (!raw || !Array.isArray(raw.sentences)) throw new Error('KAIFENG_AI_INVALID_REPLY');
  const kept: KaifengAiSentence[] = [];
  let dropped = 0;
  for (const sentence of raw.sentences) {
    if (!sentence || typeof sentence.text !== 'string' || typeof sentence.fact !== 'string' ||
      sentence.text.trim().length === 0 || sentence.text.length > 120) {
      dropped += 1;
      continue;
    }
    const fact = kaifengAiFactFor(sentence.fact);
    if (!fact || !sentenceGrounded(sentence.text, fact)) {
      dropped += 1;
      continue;
    }
    kept.push({ text: sentence.text.trim(), fact: fact.id });
  }
  if (kept.length === 0 || kept.length > KAIFENG_AI_MAX_SENTENCES) throw new Error('KAIFENG_AI_NO_GROUNDED_SENTENCE');
  const conflicts: KaifengAiConflict[] = [];
  if (Array.isArray(raw.conflicts)) {
    for (const conflict of raw.conflicts) {
      if (!conflict || typeof conflict.quote !== 'string' || typeof conflict.fact !== 'string' ||
        typeof conflict.why !== 'string') continue;
      const fact = kaifengAiFactFor(conflict.fact);
      if (!fact) continue;
      conflicts.push({ quote: conflict.quote.slice(0, 120), fact: fact.id, why: conflict.why.slice(0, 120) });
      if (conflicts.length >= 3) break;
    }
  }
  const suggestion = typeof raw.suggestion === 'string' ? raw.suggestion.slice(0, 120) : '';
  return { sentences: kept, dropped, conflicts, suggestion };
}

export function kaifengAiFactSnapshots(ids: string[]): AiFactSnapshot[] {
  const snapshots: AiFactSnapshot[] = [];
  for (const id of ids) {
    const fact = kaifengAiFactFor(id);
    if (fact) snapshots.push({ id: fact.id, title: fact.title, body: fact.text, sourceIds: [fact.sourceId] });
    if (snapshots.length >= 3) break;
  }
  return snapshots;
}

// 只把已接地的句子所引事实冻进 aiAssist；冲突列表是界面提示，不入库。
export function buildKaifengAiAssist(question: string, result: KaifengAiColophonResult): AiMemoryAssist {
  const ids: string[] = [];
  result.sentences.forEach((sentence: KaifengAiSentence) => {
    if (ids.indexOf(sentence.fact) < 0 && ids.length < 3) ids.push(sentence.fact);
  });
  const facts = kaifengAiFactSnapshots(ids);
  if (facts.length === 0) throw new Error('KAIFENG_AI_NO_GROUNDED_SENTENCE');
  return {
    version: 1,
    question: question || '为我的汴京城写题跋',
    factIds: facts.map((fact: AiFactSnapshot) => fact.id),
    contentRevision: KAIFENG_AI_CONTENT_REVISION,
    facts
  };
}

export function kaifengAiAnchorLabel(anchor: string): string {
  if (anchor === 'bridge') return '州桥';
  if (anchor === 'section') return '剖面';
  if (anchor === 'motif') return '石壁纹样';
  if (anchor === 'market') return '夜市';
  if (anchor === 'lantern') return '灯';
  return '这一页';
}

export function kaifengAiFactCount(): number { return KAIFENG_AI_FACTS.length; }
