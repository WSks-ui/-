import { copyPaperWork, parsePaperWork } from './PaperJourney';
import type { PaperWorkV1 } from './PaperJourney';

export interface PaperMemorySource {
  id: string;
  title: string;
  url: string;
  quote: string;
  accessedAt: string;
  era: string;
}

// 作品与文化依据在用户确认存入记忆时一起冻结。后续重剪、资料修订或另一端
// 继续游玩，都不能改写这一页。旧 note 没有这个字段，不补值、不改时间戳。
export interface PaperMemoryContext {
  version: number;
  cityId: string;
  title: string;
  culture: string;
  excerpt?: string;
  work: PaperWorkV1;
  sources: PaperMemorySource[];
}

export function copyPaperMemory(context: PaperMemoryContext): PaperMemoryContext {
  const copy: PaperMemoryContext = { version: context.version, cityId: context.cityId, title: context.title,
    culture: context.culture, work: copyPaperWork(context.work),
    sources: context.sources.map((source: PaperMemorySource): PaperMemorySource => ({
      id: source.id, title: source.title, url: source.url, quote: source.quote,
      accessedAt: source.accessedAt, era: source.era
    })) };
  if (context.excerpt !== undefined) copy.excerpt = context.excerpt;
  return copy;
}

export function validPaperMemory(context: PaperMemoryContext): boolean {
  if (!context || context.version !== 1 || typeof context.cityId !== 'string' ||
    !['paper-smx', 'paper-ly', 'paper-zz', 'paper-kf', 'paper-py'].includes(context.cityId) ||
    typeof context.title !== 'string' || !context.title.trim() || context.title.length > 180 ||
    typeof context.culture !== 'string' || context.culture.length > 2400 ||
    (context.excerpt !== undefined && (typeof context.excerpt !== 'string' || context.excerpt.length > 2400)) ||
    !context.work || context.work.cityId !== context.cityId || !Array.isArray(context.sources) ||
    context.sources.length < 1 || context.sources.length > 8) return false;
  try {
    if (!parsePaperWork(JSON.stringify(context.work))) return false;
  } catch { return false; }
  return context.sources.every((source: PaperMemorySource): boolean => !!source &&
    typeof source.id === 'string' && /^[a-z0-9-]{1,100}$/.test(source.id) &&
    typeof source.title === 'string' && source.title.length > 0 && source.title.length <= 240 &&
    typeof source.url === 'string' && /^https?:\/\/[^\s]+$/.test(source.url) && source.url.length <= 2048 &&
    typeof source.quote === 'string' && source.quote.length > 0 && source.quote.length <= 2400 &&
    typeof source.accessedAt === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(source.accessedAt) &&
    typeof source.era === 'string' && source.era.length <= 160);
}
