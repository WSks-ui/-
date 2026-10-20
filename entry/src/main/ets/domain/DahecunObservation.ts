import type { MaterialObservationDefinition } from './MaterialObservation';

// 双连壶热点与镜头共用同一份纯配置，详情、原生绘制和手账恢复不可各自猜测部位。
// 局部坐标以双连壶两腹之间为原点，+Y 向上、+Z 为通常观察的前侧；角度为弧度。
// 只表达馆方文字已核实的双口、腹部相通与红衣黑彩；不把通口画成真实剖面测绘。
// 修改边界：新增或调整热点时必须同步 ai 白名单事实（dahecun-*）与内容目录正文，
// 并保留 sceneRevision 2 的旧记录可回放性，不能静默替换已保存视线的几何含义。
export const DAHECUN_OBSERVATION: MaterialObservationDefinition = {
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
  notice: '原创结构示意；比例与纹线已简化，腹部通口采用剖开解释。'
};
