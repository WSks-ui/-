// 局部文化视口的纯数据契约。这里不依赖 ArkUI、ArkWeb 或存储；原生兼容画布也可复用。
export type CulturalSceneType = 'river_sandbox' | 'relic_inspector' | 'stratum_slice' | 'constellation_graph';
export type CulturalEngineSelectionType = 'city' | 'hotspot' | 'layer' | 'site';

export interface CulturalEngineNode {
  id: string;
  label: string;
  city?: string;
  era?: string;
  type?: string;
  accent?: string;
  explored?: boolean;
  x?: number;
  y?: number;
  z?: number;
}

export interface CulturalEngineEdge { source: string; target: string; }
export interface CulturalEngineLayer { id: string; label: string; summary?: string; }
export interface CulturalEngineView {
  yaw: number;
  pitch: number;
  distance: number;
  panX: number;
  panY: number;
}

export interface CulturalEnginePayload {
  version: number;
  itemId?: string;
  title?: string;
  proceduralPreset?: string;
  selectedId?: string;
  // 只允许 ../models/<本地文件名>.glb。未提供时尝试 itemId 对应资源；失败继续显示程序化示意。
  modelPath?: string;
  exploredIds?: string[];
  nodes?: CulturalEngineNode[];
  edges?: CulturalEngineEdge[];
  // 地层由条目显式提供。引擎不把统一四层主题解释成每个遗址的真实地层或考古分期。
  layers?: CulturalEngineLayer[];
}

export interface CulturalEngineStatus {
  renderer: string;
  sceneType: CulturalSceneType;
  modelState: string;
  modelMessage: string;
  selectedId: string;
  active: boolean;
  reducedMotion: boolean;
  automatic?: boolean;
}

// 这些方法由原生 javaScriptProxy 的 EngineBridge 对象提供；额外 onReady/onStatus 可选。
// progress 是去重后的分层探索比例，不表示已校审的知识掌握程度，也不等于完整阅读。
export interface CulturalEngineBridge {
  onNodeSelected(id: string, type: string): void;
  onProgressUnlocked(itemId: string, progress: number): void;
  onCaptureSnapshot(base64Data: string): void;
}

export const CULTURAL_ENGINE_HOTSPOTS: string[] = ['form', 'pattern', 'story'];
export const CULTURAL_ENGINE_RESOURCE: string = 'engine/index.html';
