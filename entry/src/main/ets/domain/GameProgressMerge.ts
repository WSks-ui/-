import type { KaifengCityV1, KaifengLightPoint, KaifengMotifSlots } from './KaifengPuzzle';
import { parseKaifengCity, serializeKaifengCity } from './KaifengPuzzle';
import { mergeDig, parseDig, serializeDig } from './KaifengDig';
import { isPaperCityId, mergePaperWork, parsePaperWork, serializePaperWork } from './PaperJourney';

// 只描述适配器需要的字段，不反向导入 ArchiveDomain。
// ArchiveDomain -> 本模块 -> 纯玩法模块保持单向依赖；SDK 与存储不进入领域合并。
export interface GameProgressValue {
  id: string;
  kind: string;
  siteId: string;
  body: string;
  deleted: boolean;
}

const CITY_PREFIX: string = 'progress:kaifeng-city:v1:';
const DIG_PREFIX: string = 'progress:kaifeng-dig:v1:';
const PAPER_PREFIX: string = 'progress:paper-journey:v1:';

function nonemptySlot(a: string, b: string): string {
  // 正常玩法中，每个槽位只有约定的一件材料。非空优先；如果旧有效记录
  // 在同一槽位上发生冲突，固定字符串次序保证输入方向不会改变结果。
  return a >= b ? a : b;
}

function citySceneKey(city: KaifengCityV1): string {
  // 只用可替换的场景状态决胜，不用 acts/槽位/成志时间等并集字段。
  // 否则合并后新增的完成标记会改变同刻桥灯状态的胜负，产生反复覆盖。
  const lights = city.lights.map((light: KaifengLightPoint): string => `${light.id}:${light.x}:${light.y}`).sort();
  return JSON.stringify([city.bridge.x, city.bridge.y, city.bridge.angle, city.bridgeKind, city.boatSpot,
    city.lantern.frame, city.lantern.paper, city.lantern.wish, city.lantern.spot, lights]);
}

function mergeMotif(a: KaifengMotifSlots, b: KaifengMotifSlots): KaifengMotifSlots | undefined {
  const sides = [a.left, a.right, b.left, b.right];
  if (sides.some((piece: string) => piece !== '' && piece !== 'crane-a' && piece !== 'crane-b')) return undefined;
  const hasA = sides.includes('crane-a');
  const hasB = sides.includes('crane-b');
  const out: KaifengMotifSlots = {
    center: nonemptySlot(a.center, b.center), left: '', right: '', bottom: nonemptySlot(a.bottom, b.bottom)
  };
  // 两只仙鹤允许互换左右，跨端直接按槽位并集会把同一只鹤复制到两边。
  // 它们画面与标签相同；两片都出现时用固定排位，只有一片时保留已用侧（冲突取左）。
  // 这样保留的是实际放过的材料，不会凭一次同步凭空补出第二片。
  if (hasA && hasB) { out.left = 'crane-a'; out.right = 'crane-b'; }
  else if (hasA || hasB) {
    const piece = hasA ? 'crane-a' : 'crane-b';
    if (a.left === piece || b.left === piece) out.left = piece;
    else out.right = piece;
  }
  return out;
}

function mergeCity(a: KaifengCityV1, b: KaifengCityV1): KaifengCityV1 | undefined {
  const motif = mergeMotif(a.motif, b.motif);
  if (!motif) return undefined;
  const newer = b.updatedAt > a.updatedAt ||
    (b.updatedAt === a.updatedAt && citySceneKey(b) >= citySceneKey(a)) ? b : a;
  const out: KaifengCityV1 = {
    version: 1,
    chapterId: a.chapterId,
    acts: {
      bridge: a.acts.bridge || b.acts.bridge,
      layers: a.acts.layers || b.acts.layers,
      lantern: a.acts.lantern || b.acts.lantern,
      bridgeIndependent: a.acts.bridgeIndependent || b.acts.bridgeIndependent,
      note: a.acts.note || b.acts.note
    },
    bridge: { x: newer.bridge.x, y: newer.bridge.y, angle: newer.bridge.angle },
    bridgeKind: newer.bridgeKind,
    boatSpot: newer.boatSpot,
    layers: {
      lower: nonemptySlot(a.layers.lower, b.layers.lower),
      middle: nonemptySlot(a.layers.middle, b.layers.middle),
      upper: nonemptySlot(a.layers.upper, b.layers.upper)
    },
    motif,
    lantern: { frame: newer.lantern.frame, paper: newer.lantern.paper,
      wish: newer.lantern.wish, spot: newer.lantern.spot },
    lights: newer.lights.map((light: KaifengLightPoint): KaifengLightPoint => ({ id: light.id, x: light.x, y: light.y }))
      .sort((left: KaifengLightPoint, right: KaifengLightPoint): number => left.id === right.id ? 0 : left.id < right.id ? -1 : 1),
    updatedAt: newer.updatedAt
  };
  const closedA = a.closedAt !== undefined && a.closedAt > 0 ? a.closedAt : 0;
  const closedB = b.closedAt !== undefined && b.closedAt > 0 ? b.closedAt : 0;
  if (closedA > 0 && closedB > 0) out.closedAt = Math.min(closedA, closedB);
  else if (closedA > 0) out.closedAt = closedA;
  else if (closedB > 0) out.closedAt = closedB;
  // 不能把两个各自可读的版本合成损坏正文。未知或矛盾的历史组合交回原 LWW，
  // 不丢原文、不补成一座凭空完成的城市。
  return parseKaifengCity(serializeKaifengCity(out));
}

// 返回 undefined 表示不是已识别且完整有效的游戏记录，调用方继续原 LWW。
// 身份须同时匹配 id、siteId 和 body.chapterId / cityId；不能拿普通 progress 或其他章节套用规则。
// 墓碑完全交给 ArchiveDomain 原有版本比较，语义并集不得复活删除。
export function mergeGameProgressBody(a: GameProgressValue, b: GameProgressValue): string | undefined {
  if (a.id !== b.id || a.kind !== 'progress' || b.kind !== 'progress' || a.deleted || b.deleted ||
    a.siteId !== b.siteId) return undefined;
  try {
    if (a.id === PAPER_PREFIX + a.siteId && isPaperCityId(a.siteId)) {
      const local = parsePaperWork(a.body);
      const incoming = parsePaperWork(b.body);
      if (!local || !incoming || local.cityId !== a.siteId || incoming.cityId !== a.siteId) return undefined;
      // 当前剪口、撤销栈、折法、纸色与透光是一件完整作品，不能把两端 mask
      // 按位叠加成双方都没剪过的纸。mergePaperWork 只独立保留真实完成快照，
      // 原账号信封和墓碑仍由通用版本规则处理；这里不制造新保存时间。
      const merged = mergePaperWork(local, incoming);
      return merged ? serializePaperWork(merged) : undefined;
    }
    if (!/^roam-[a-z0-9-]{2,60}$/.test(a.siteId)) return undefined;
    if (a.id === CITY_PREFIX + a.siteId) {
      const local = parseKaifengCity(a.body);
      const incoming = parseKaifengCity(b.body);
      if (!local || !incoming || local.chapterId !== a.siteId || incoming.chapterId !== a.siteId) return undefined;
      const merged = mergeCity(local, incoming);
      return merged ? serializeKaifengCity(merged) : undefined;
    }
    if (a.id === DIG_PREFIX + a.siteId) {
      const local = parseDig(a.body);
      const incoming = parseDig(b.body);
      if (!local || !incoming || local.chapterId !== a.siteId || incoming.chapterId !== a.siteId) return undefined;
      const merged = mergeDig(local, incoming);
      return merged ? serializeDig(merged) : undefined;
    }
  } catch (_error) {
    // 玩法 codec 的长度约束不能让原本可归档的 v1 信封无法同步；保留原文交回 LWW。
    return undefined;
  }
  return undefined;
}
