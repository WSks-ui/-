import type { MaterialObservationDefinition } from './MaterialObservation';

// 与几何共用 +Y 向上、+Z 为通常观察的前壁；角度为弧度，局部参数不表示实物尺寸。
// 三个热点都关联同一条已核事实，只解释八组的位置与乳钉边框，不补充纹样寓意或祭祀结论。
export const DULING_OBSERVATION: MaterialObservationDefinition = {
  siteId: 'zz-duling-fangding',
  proceduralPreset: 'duling_fangding',
  sceneRevision: 2,
  hotspots: [
    { id: 'centers', label: '壁面正中', factId: 'duling-eight',
      visibleDetail: '看玫瑰色位置片：每片位于一面腹壁上方的正中。转动方鼎，寻找四面各一处的标记。',
      point: { x: 0, y: 0.35, z: 0.65 }, yaw: 0.44, pitch: 0.7, zoom: 0.98 },
    { id: 'corners', label: '四个折角', factId: 'duling-eight',
      visibleDetail: '沿陶土色折片看过一条棱：同一片横跨相邻两壁，表示以折角为中心的一组，四个折角共四组。',
      point: { x: -0.635, y: 0.35, z: 0.635 }, yaw: 0.78, pitch: 0.58, zoom: 0.98 },
    { id: 'frame', label: '乳钉边框', factId: 'duling-eight',
      visibleDetail: '沿浅色点状带看每壁两侧和腹部近底端的边框。点数仅为示意；它们与玫瑰、陶土标记解释的上腹八组分开。',
      point: { x: 0.34, y: -0.105, z: 0.592 }, yaw: 0.5, pitch: 0.42, zoom: 1 }
  ],
  notice: '原创位置示意，非兽面纹摹本；比例与乳钉点数已简化，足部纹饰不计入八组。'
};
