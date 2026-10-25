import type { HeritageSite } from '../domain/ArchiveDomain';
import type { RoamChapter, RoamClue } from '../domain/Roaming';
import { HERITAGE_SITES } from './HeritageCatalog';
import { ROAM_CHAPTERS, ROAM_SOURCES } from './RoamingCatalog';

export const ROAM_LIBRARY_TYPES: string[] = ['全部类型', '考古与空间', '诗文与生活', '非遗技艺', '地方记忆'];
// 资料年代直接取目录的完整标注，不把北宋记述和当代传承合并成同一个历史事实。
export const ROAM_LIBRARY_ERAS: string[] = ['全部年代'];
ROAM_CHAPTERS.forEach((chapter: RoamChapter) => chapter.clues.forEach((clue: RoamClue) => {
  if (!ROAM_LIBRARY_ERAS.includes(clue.era)) ROAM_LIBRARY_ERAS.push(clue.era);
}));

export function roamingContentType(clue: RoamClue): string {
  if (['excerpt', 'words', 'echo'].includes(clue.mode)) return '诗文与生活';
  if (['find', 'window', 'gate', 'crossing', 'timeline', 'trace'].includes(clue.mode)) return '考古与空间';
  if (['characters', 'remember'].includes(clue.mode)) return '地方记忆';
  return '非遗技艺';
}

export function roamingChapterForId(id: string): RoamChapter | undefined {
  return ROAM_CHAPTERS.find(chapter => chapter.id === id || chapter.clues.some(clue => clue.id === id));
}

// 旧记录的 siteId 保持原值，新文化线索使用独立 ID。这里只提供给收藏/全文检索的
// 阅读适配，不把非遗内容塞进旧器物观察器，也不借用其他遗址的几何或 AI 权限。
export function culturalEntryForId(id: string): HeritageSite | undefined {
  const heritage = HERITAGE_SITES.find(site => site.id === id);
  if (heritage) return heritage;
  const chapter = roamingChapterForId(id);
  if (!chapter) return undefined;
  const clue: RoamClue | undefined = chapter.clues.find(item => item.id === id);
  const sourceIds = clue?.sourceIds || chapter.sourceIds;
  const source = ROAM_SOURCES.find(item => sourceIds.includes(item.id));
  return {
    id, name: clue ? `${chapter.city} · ${clue.title}` : chapter.title, city: chapter.city,
    era: clue?.era || '城市文化', type: clue ? roamingContentType(clue) : '城市篇章', tags: [chapter.city, '文化漫游'],
    summary: clue?.goal || chapter.subtitle, overview: clue?.body || chapter.opening,
    archaeology: '', history: chapter.closing, poetry: '', travel: '',
    source: { title: source?.title || '篇章资料', url: source?.url || '' },
    reviewStatus: '初稿待校审', illustration: 'motif_city.svg', accent: chapter.accent, photos: []
  };
}
