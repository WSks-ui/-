import type { MaterialObservationDefinition } from './MaterialObservation';

// 与几何共用世界坐标：+X 为东、-X 为西、+Y 向上；Z 只用于排开符号，不指认南北。
// 相机角度为弧度。调整沙盘尺度或符号位置时，应同步核对三个标注与推荐镜头。
export const MIAODIGOU_OBSERVATION: MaterialObservationDefinition = {
  siteId: 'smx-miaodigou',
  proceduralPreset: 'miaodigou_pottery',
  sceneRevision: 2,
  hotspots: [
    { id: 'living', label: '居住遗存', factId: 'miaodigou-living',
      visibleDetail: '沿沙盘上的“西—中—东”字标，找出西部和中部的玫瑰色房形符号。它们标记居住遗存的大致方位，房形、数量与间距均为学习示意。',
      point: { x: 0.13, y: 0.10, z: -0.27 }, yaw: -0.12, pitch: 0.72, zoom: 0.94 },
    { id: 'kilns', label: '西部陶窑', factId: 'miaodigou-kilns',
      visibleDetail: '看“西”一侧的陶色圆环和较深内腔，再找它们旁边的玫瑰色居住符号。两类符号在西部共存；圆环为学习示意，不表示实际窑形或窑址数量。',
      point: { x: -0.72, y: -0.015, z: 0.12 }, yaw: 0.18, pitch: 0.77, zoom: 0.99 },
    { id: 'ditches', label: '东西壕沟', factId: 'miaodigou-ditches',
      visibleDetail: '对照“西”和“东”两侧的灰绿色浅槽：两条线段的端部开放，没有连成围墙。槽深、长度与端点均为学习示意，不能当作实测壕沟轮廓。',
      point: { x: 1.05, y: -0.19, z: 0.08 }, yaw: -0.08, pitch: 0.80, zoom: 0.94 }
  ],
  notice: '依据官方概述绘制，方位关系为学习示意，非实测平面。'
};
