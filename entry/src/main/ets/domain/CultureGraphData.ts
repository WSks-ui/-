import type { ArchiveRecord, HeritageSite } from './ArchiveDomain';
import { cultureConnections } from './CultureConnections';

export interface CultureGraphNode {
  id: string;
  label: string;
  city: string;
  era: string;
  accent: string;
}

export interface CultureGraphEdge {
  source: string;
  target: string;
  reasons: string[];
}

export interface CultureGraphData {
  nodes: CultureGraphNode[];
  edges: CultureGraphEdge[];
  selectedId: string;
}

// 背景保留每个节点最相关的两条线，选中节点则显示全部真实关联。
// 15 条内容共享“考古”等宽泛标签时，完整连边会盖住节点；这里仅裁减展示密度，
// 不改变关联规则、排序、个人记录或下方完整线索列表，也不把线条描述为历史因果。
export function cultureGraphData(sites: HeritageSite[], selectedId: string,
  records: ArchiveRecord[] = []): CultureGraphData {
  const selected = sites.some((site: HeritageSite) => site.id === selectedId) ? selectedId : (sites[0]?.id || '');
  const edges: CultureGraphEdge[] = [];
  const edgeIds: string[] = [];
  sites.forEach((site: HeritageSite) => {
    const connections = cultureConnections(sites, site.id, records);
    const visible = site.id === selected ? connections : connections.slice(0, 2);
    visible.forEach((connection) => {
      const pair = [site.id, connection.site.id].sort();
      const key = pair.join('|');
      if (edgeIds.includes(key)) return;
      edgeIds.push(key);
      edges.push({ source: pair[0], target: pair[1], reasons: connection.reasons.slice() });
    });
  });
  return {
    nodes: sites.map((site: HeritageSite): CultureGraphNode => ({
      id: site.id, label: site.name, city: site.city, era: site.era, accent: site.accent
    })),
    edges, selectedId: selected
  };
}
