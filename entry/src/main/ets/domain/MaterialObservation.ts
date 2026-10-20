import type { ObjectPoint } from './SiteObjectGeometry';
import { MIAODIGOU_OBSERVATION } from './MiaodigouObservation';
import { DAHECUN_OBSERVATION } from './DahecunObservation';
import { DULING_OBSERVATION } from './DulingObservation';

export interface MaterialObservationHotspot {
  id: string;
  label: string;
  factId: string;
  // 指出当前示意中应看的具体细节；资料事实仍由 factId 独立关联，避免把解释手段混作考古原貌。
  visibleDetail: string;
  point: ObjectPoint;
  yaw: number;
  pitch: number;
  zoom: number;
}

export interface MaterialObservationDefinition {
  siteId: string;
  proceduralPreset: string;
  sceneRevision: number;
  hotspots: MaterialObservationHotspot[];
  notice: string;
}

// 每处保留独立的内容与几何模块；这里只登记真实可提供的场景，不给其他档案套通用热点。
const MATERIAL_OBSERVATIONS: MaterialObservationDefinition[] = [
  MIAODIGOU_OBSERVATION, DAHECUN_OBSERVATION, DULING_OBSERVATION
];

export function materialObservationForSite(siteId: string): MaterialObservationDefinition | undefined {
  return MATERIAL_OBSERVATIONS.find(item => item.siteId === siteId);
}

export function materialObservationForPreset(preset: string, revision: number = 2): MaterialObservationDefinition | undefined {
  // 场景版本参与匹配：缺省旧手账由调用方传 1，不能被新几何静默替换。
  return MATERIAL_OBSERVATIONS.find(item => item.proceduralPreset === preset && item.sceneRevision === revision);
}
