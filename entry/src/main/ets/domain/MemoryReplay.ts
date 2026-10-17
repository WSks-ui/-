import type { MemoryPose, MemoryViewFrame } from './ArchiveDomain';
import { copyMemoryViewFrame, isValidMemoryPose } from './ArchiveDomain';
import { EXPLORATION_SECTIONS, getCulturalSiteMetadata } from './CulturalContent';
import { materialObservationForPreset, materialObservationForSite } from './MaterialObservation';

export const MEMORY_NATIVE_RENDERER_PROFILE: string = 'native-raster-v1';
// 与现有原生视口手势一致。这里校验而不截断，避免参数实际已改变却仍声称恢复了原视角。
export const MEMORY_REPLAY_MIN_PITCH: number = -0.5;
export const MEMORY_REPLAY_MAX_PITCH: number = 0.8;
export const MEMORY_REPLAY_MIN_ZOOM: number = 0.7;
export const MEMORY_REPLAY_MAX_ZOOM: number = 1.6;

export interface MemoryReplayResolution {
  state: 'ready' | 'legacy' | 'unavailable';
  canReplay: boolean;
  message: string;
  proceduralPreset: string;
  sceneRevision: number;
  rendererProfile: string;
  viewFrame?: MemoryViewFrame;
}

function unavailable(message: string, pose?: MemoryPose): MemoryReplayResolution {
  const result: MemoryReplayResolution = {
    state: 'unavailable', canReplay: false, message,
    proceduralPreset: pose === undefined ? '' : (pose.proceduralPreset || ''),
    sceneRevision: pose === undefined ? 0 : (pose.sceneRevision || 0),
    rendererProfile: pose === undefined ? '' : (pose.rendererProfile || '')
  };
  if (pose !== undefined && pose.viewFrame !== undefined) result.viewFrame = copyMemoryViewFrame(pose.viewFrame);
  return result;
}

// 归档层保留合法但未知的版本，回放层才核对支持名单；本函数不会修改记录或补写时间戳。
// ready 只表示参数可完整重建，界面须等实际绘制完成再宣告“已回到”，不能把判定本身当绘制结果。
export function resolveMemoryReplay(siteId: string, pose?: MemoryPose): MemoryReplayResolution {
  const metadata = getCulturalSiteMetadata(siteId);
  if (!metadata || metadata.siteId !== siteId) return unavailable('这张手账对应的档案已不在当前目录中');
  if (pose === undefined) return unavailable('这张手账未记录观察视角');
  if (!isValidMemoryPose(pose)) return unavailable('这张手账的视角数据不完整或已损坏');
  if (pose.version !== 1) return unavailable('这张手账的视角格式版本暂不支持', pose);
  if (pose.sceneType !== 'relic_inspector' && pose.sceneType !== 'stratum_slice') {
    return unavailable('这张手账的场景暂不支持重返观察', pose);
  }
  if (pose.pitch < MEMORY_REPLAY_MIN_PITCH || pose.pitch > MEMORY_REPLAY_MAX_PITCH ||
    pose.zoom < MEMORY_REPLAY_MIN_ZOOM || pose.zoom > MEMORY_REPLAY_MAX_ZOOM) {
    return unavailable('这张手账的视角超出当前画布可重建范围', pose);
  }

  // 缺省只为旧记录选择其原有 revision 1，不把新热点猜成新版场景，也不回退到其他档案。
  const proceduralPreset = pose.proceduralPreset === undefined ? metadata.proceduralPreset : pose.proceduralPreset;
  const sceneRevision = pose.sceneRevision === undefined ? 1 : pose.sceneRevision;
  const rendererProfile = pose.rendererProfile === undefined ? MEMORY_NATIVE_RENDERER_PROFILE : pose.rendererProfile;
  if (proceduralPreset !== metadata.proceduralPreset) return unavailable('手账预设与对应档案不匹配，暂不能重返观察', pose);
  if (rendererProfile !== MEMORY_NATIVE_RENDERER_PROFILE) return unavailable('这张手账的渲染配置暂不支持', pose);

  let hotspotIds: string[] = ['form', 'pattern', 'story'];
  if (sceneRevision === 2) {
    const siteObservation = materialObservationForSite(siteId);
    const observation = materialObservationForPreset(proceduralPreset, sceneRevision);
    if (!siteObservation || !observation || observation.siteId !== siteId ||
      observation.sceneRevision !== sceneRevision || siteObservation.sceneRevision !== sceneRevision ||
      observation.proceduralPreset !== proceduralPreset) {
      return unavailable('这张手账的场景修订尚未在此档案提供', pose);
    }
    hotspotIds = observation.hotspots.map(hotspot => hotspot.id);
  } else if (sceneRevision !== 1) {
    return unavailable('这张手账的场景修订暂不支持', pose);
  }

  // 不忽略与当前模式无关的选择值；否则可能恢复了角度，却丢掉用户实际记录的热点或主题。
  if (pose.sceneType === 'relic_inspector' &&
    (pose.sectionId !== '' || (pose.hotspotId !== '' && !hotspotIds.includes(pose.hotspotId)))) {
    return unavailable('这张手账的观察热点在对应场景中不可用', pose);
  }
  if (pose.sceneType === 'stratum_slice' && (pose.hotspotId !== '' ||
    (pose.sectionId !== '' && !EXPLORATION_SECTIONS.some(section => section.id === pose.sectionId)))) {
    return unavailable('这张手账的文化切片主题暂不支持', pose);
  }

  const frame = pose.viewFrame;
  // 归档只要求正有限尺寸；播放须避开 renderer 本身不绘制的画布，不能把空画面登记为 ready。
  if (frame !== undefined && (frame.width <= 24 || frame.height <= 46)) {
    return unavailable('这张手账记录的原取景尺寸无法绘制', pose);
  }
  const complete = pose.proceduralPreset !== undefined && pose.sceneRevision !== undefined &&
    pose.rendererProfile !== undefined && frame !== undefined &&
    frame.textDensity !== undefined && frame.dark !== undefined;
  const result: MemoryReplayResolution = {
    state: complete ? 'ready' : 'legacy', canReplay: true,
    message: complete ? '手账画面与视角可重建' : '旧版视角，原取景未记录',
    proceduralPreset, sceneRevision, rendererProfile
  };
  if (frame !== undefined) result.viewFrame = copyMemoryViewFrame(frame);
  return result;
}
