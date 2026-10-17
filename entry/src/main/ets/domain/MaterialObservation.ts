import type { ObjectPoint } from './SiteObjectGeometry';

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

// 热点与镜头共用同一份纯配置，详情、原生绘制和手账恢复不可各自猜测部位。
// 局部坐标以双连壶两腹之间为原点，+Y 向上、+Z 为通常观察的前侧；角度为弧度。
// 此版只表达馆方文字已核实的双口、腹部相通与红衣黑彩；不启用另外两处的精细场景。
const DAHECUN_OBSERVATION: MaterialObservationDefinition = {
  siteId: 'zz-dahecun',
  proceduralPreset: 'dahecun_pottery',
  sceneRevision: 2,
  hotspots: [
    { id: 'mouth', label: '两只壶口', factId: 'dahecun-object',
      visibleDetail: '从上方看两个敞口：每个口分别连着一个壶腹，能辨认出并列的两个壶体。',
      point: { x: -0.48, y: 0.735, z: 0.025 }, yaw: -0.12, pitch: 0.42, zoom: 0.94 },
    { id: 'opening', label: '腹部通口', factId: 'dahecun-opening',
      visibleDetail: '沿浅绿色通道看两侧内腔。示意剖开了前侧器壁，让腹部相通的位置显露出来。',
      point: { x: 0, y: -0.035, z: -0.13 }, yaw: 0.34, pitch: 0.14, zoom: 0.98 },
    { id: 'paint', label: '红衣黑彩', factId: 'dahecun-lines',
      visibleDetail: '在红色器腹表面寻找黑彩平行横线，再看横线之间的竖向、斜向短线。',
      point: { x: 0.56, y: 0.095, z: 0.44 }, yaw: -0.16, pitch: 0.12, zoom: 1.04 }
  ],
  notice: '原创结构学习示意 · 比例与纹线已简化，非实物复原；腹部通口采用剖开解释。'
};

export function materialObservationForSite(siteId: string): MaterialObservationDefinition | undefined {
  return siteId === DAHECUN_OBSERVATION.siteId ? DAHECUN_OBSERVATION : undefined;
}

export function materialObservationForPreset(preset: string, revision: number = 2): MaterialObservationDefinition | undefined {
  // 场景版本参与匹配：缺省旧手账由调用方传 1，不能被新几何静默替换。
  return preset === DAHECUN_OBSERVATION.proceduralPreset && revision === DAHECUN_OBSERVATION.sceneRevision ?
    DAHECUN_OBSERVATION : undefined;
}
