import type { AiKnowledgeScope } from './AiObservation';
import { AI_OBSERVATION_SITE_ID, buildAiKnowledgeScope } from './AiObservation';
import type { MaterialObservationDefinition } from './MaterialObservation';
import { materialObservationForSite } from './MaterialObservation';
import type { MaterialStudy } from '../data/MaterialStudyCatalog';
import { materialStudyForId } from '../data/MaterialStudyCatalog';

// 客户端唯一的 AI 资料入口：只读现有内容目录与原生热点定义，不复制事实正文。
// 服务端在 Node 中直接读取同一份 MaterialStudyCatalog.ts 和 DulingObservation.ts 组装同一结构。
export function aiKnowledgeScope(siteId: string): AiKnowledgeScope | undefined {
  if (siteId !== AI_OBSERVATION_SITE_ID) return undefined;
  const study: MaterialStudy | undefined = materialStudyForId(siteId);
  const observation: MaterialObservationDefinition | undefined = materialObservationForSite(siteId);
  if (!study || !observation) return undefined;
  return buildAiKnowledgeScope(study, observation);
}
