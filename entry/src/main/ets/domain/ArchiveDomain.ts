export interface SourceRef {
  title: string;
  url: string;
}

export interface HeritageSite {
  id: string;
  name: string;
  city: string;
  era: string;
  type: string;
  tags: string[];
  summary: string;
  overview: string;
  archaeology: string;
  history: string;
  poetry: string;
  travel: string;
  source: SourceRef;
  reviewStatus: string;
  illustration: string;
  accent: string;
  // 真实遗址照片文件名列表，放在 resources/rawfile/photos/ 下。
  // 空数组时降级显示 illustration 插画；图片来源与版权由内容录入者负责。
  photos: string[];
  // 单张照片的说明与授权署名；当前每条档案只展示首张照片。
  photoCaption?: string;
  photoCredit?: string;
}

export interface SiteFilter {
  keyword: string;
  city: string;
  era: string;
  type: string;
}

// 原取景使用保存时的虚拟画布，预览只做等比适配，不用卡片尺寸重新取景。
// 文字密度和明暗模式仍为可选，便于保留信息不完整的记录；能否完整重建由回放层判断。
export interface MemoryViewFrame {
  width: number;
  height: number;
  textDensity?: number;
  dark?: boolean;
}

// 手账只保存可重建的示意视角，不保存模型像素或声称拥有实景照片。
// version 继续为 1；新信息按需扩展，未知正修订号或渲染配置可归档，由回放层决定是否支持。
export interface MemoryPose {
  version: number;
  sceneType: string;
  yaw: number;
  pitch: number;
  zoom: number;
  hotspotId: string;
  sectionId: string;
  label: string;
  proceduralPreset?: string;
  sceneRevision?: number;
  rendererProfile?: string;
  viewFrame?: MemoryViewFrame;
}

// AI 参考元数据冻结采纳时的资料事实，资料日后修订仍能解释这页手账当时依据了什么。
// 它不是“整页由 AI 生成”的证明：正文由用户确认，字段只说明这页曾参考 AI 辅助整理。
export interface AiFactSnapshot {
  id: string;
  title: string;
  body: string;
  sourceIds: string[];
}

export interface AiMemoryAssist {
  version: number;
  question: string;
  factIds: string[];
  contentRevision: number;
  facts: AiFactSnapshot[];
}

// 收藏、笔记、进度共用版本信封。删除保留墓碑，后续设备重连时不能把旧记录复活。
// updatedAt 由单设备逻辑时钟生成；跨设备时钟偏差仍需同步适配层处理，不能承诺物理时间绝对准确。
export interface ArchiveRecord {
  id: string;
  kind: string;
  siteId: string;
  body: string;
  tags: string[];
  updatedAt: number;
  deviceId: string;
  deleted: boolean;
  // schema v1 的可选扩展：只有用户保存手账时才写入，旧普通笔记不自动补值或改时间戳。
  stampType?: string;
  paperTheme?: string;
  quotedPoemOrFact?: string;
  snapshot3DPose?: MemoryPose;
  // 仅在用户采纳或修改 AI 草稿后确认保存时写入；只问答、放弃草稿或失败均不补标。
  aiAssist?: AiMemoryAssist;
}

export interface ArchiveSnapshot {
  schemaVersion: number;
  deviceId: string;
  records: ArchiveRecord[];
  lightEnabled: boolean;
  reducedMotion: boolean;
}

export interface Recommendation {
  site: HeritageSite;
  score: number;
  reason: string;
}

export interface MergeResult {
  records: ArchiveRecord[];
  conflicts: ArchiveRecord[];
}

export const CITIES: string[] = ['全部城市', '三门峡', '洛阳', '郑州', '开封', '濮阳'];

// 五城简介只解释阅读线索，不把城市宣传语当作考古结论；换城市时同步显示。
export const CITY_INTROS: Record<string, string> = {
  '三门峡': '黄河入豫的第一段，仰韶村、庙底沟与西坡把“早期中国”的聚落线索串在一起。',
  '洛阳': '从二里头到汉魏洛阳城，再到龙门石窟，五都荟洛，适合按时间顺序慢读。',
  '郑州': '商代王都叠压在现代城市之下，大河村、郑韩故城与杜岭方鼎补充了更早与更晚的章节。',
  '开封': '宋都的中轴线、铁塔与繁塔、州桥和城墙，把一座城的兴废与黄河水患写在同一层地面上。',
  '濮阳': '西水坡的蚌塑龙、戚城的会盟台、仓颉陵的地方记忆与单拐的抗战旧址，组成一条跨时代的龙乡线索。'
};
// 保留原检索顺序，扩展项只补内容分类；“城市史 / 民间记忆”是主题分组，不是考古断代。
export const ERAS: string[] = ['全部年代', '仰韶', '龙山', '夏商', '周', '汉唐', '宋', '城市史', '民间记忆', '近现代'];
export const TYPES: string[] = ['全部类型', '聚落遗址', '都城遗址', '城址', '墓葬群', '窑址', '古建筑', '青铜器', '文化纪念地', '革命旧址'];
export const COLLECTION_TAGS: string[] = ['待实地探访', '已去过', '研究资料'];
export const MAX_NOTE_LENGTH: number = 4000;
export const MAX_NOTE_TAGS: number = 20;
export const MAX_NOTE_TAG_LENGTH: number = 40;
// 标签编辑框必须容纳全部合法标签及分隔符，不能在编辑既有记录时截断后面的标签。
export const MAX_NOTE_TAGS_TEXT_LENGTH: number = MAX_NOTE_TAGS * MAX_NOTE_TAG_LENGTH + MAX_NOTE_TAGS - 1;

export function emptySnapshot(deviceId: string): ArchiveSnapshot {
  return { schemaVersion: 1, deviceId, records: [], lightEnabled: true, reducedMotion: false };
}

export function copyMemoryViewFrame(frame: MemoryViewFrame): MemoryViewFrame {
  const copy: MemoryViewFrame = { width: frame.width, height: frame.height };
  if (frame.textDensity !== undefined) copy.textDensity = frame.textDensity;
  if (frame.dark !== undefined) copy.dark = frame.dark;
  return copy;
}

export function copyMemoryPose(pose: MemoryPose): MemoryPose {
  const copy: MemoryPose = {
    version: pose.version, sceneType: pose.sceneType, yaw: pose.yaw, pitch: pose.pitch,
    zoom: pose.zoom, hotspotId: pose.hotspotId, sectionId: pose.sectionId, label: pose.label
  };
  // 不补新字段，也不将 viewFrame 与已保存记录共享；草稿和回放请求均可复用这一复制边界。
  if (pose.proceduralPreset !== undefined) copy.proceduralPreset = pose.proceduralPreset;
  if (pose.sceneRevision !== undefined) copy.sceneRevision = pose.sceneRevision;
  if (pose.rendererProfile !== undefined) copy.rendererProfile = pose.rendererProfile;
  if (pose.viewFrame !== undefined) copy.viewFrame = copyMemoryViewFrame(pose.viewFrame);
  return copy;
}

export function copyAiFactSnapshot(fact: AiFactSnapshot): AiFactSnapshot {
  return { id: fact.id, title: fact.title, body: fact.body, sourceIds: fact.sourceIds.slice() };
}

export function copyAiMemoryAssist(assist: AiMemoryAssist): AiMemoryAssist {
  // 冻结事实与引用数组都深拷贝；手账草稿、快照和同步请求不能共享可变数组。
  return {
    version: assist.version, question: assist.question, factIds: assist.factIds.slice(),
    contentRevision: assist.contentRevision,
    facts: assist.facts.map((fact: AiFactSnapshot): AiFactSnapshot => copyAiFactSnapshot(fact))
  };
}

export function copySnapshot(snapshot: ArchiveSnapshot): ArchiveSnapshot {
  return {
    schemaVersion: snapshot.schemaVersion,
    deviceId: snapshot.deviceId,
    records: snapshot.records.map((record: ArchiveRecord): ArchiveRecord => {
      const copy: ArchiveRecord = {
        id: record.id, kind: record.kind, siteId: record.siteId, body: record.body,
        tags: record.tags.slice(), updatedAt: record.updatedAt, deviceId: record.deviceId, deleted: record.deleted
      };
      // 条件复制让旧 note 继续缺省；视角必须逐字段复制，防止编辑草稿时改到已保存快照。
      if (record.stampType !== undefined) copy.stampType = record.stampType;
      if (record.paperTheme !== undefined) copy.paperTheme = record.paperTheme;
      if (record.quotedPoemOrFact !== undefined) copy.quotedPoemOrFact = record.quotedPoemOrFact;
      if (record.snapshot3DPose !== undefined) {
        copy.snapshot3DPose = copyMemoryPose(record.snapshot3DPose);
      }
      if (record.aiAssist !== undefined) {
        copy.aiAssist = copyAiMemoryAssist(record.aiAssist);
      }
      return copy;
    }),
    lightEnabled: snapshot.lightEnabled,
    reducedMotion: snapshot.reducedMotion
  };
}

export function filterSites(sites: HeritageSite[], filter: SiteFilter): HeritageSite[] {
  const words = filter.keyword.trim().toLowerCase().split(/\s+/).filter((word: string) => word.length > 0);
  return sites.filter((site: HeritageSite) => {
    const text = `${site.name} ${site.city} ${site.era} ${site.type} ${site.summary} ${site.tags.join(' ')}`.toLowerCase();
    return (filter.city === CITIES[0] || filter.city === site.city) &&
      (filter.era === ERAS[0] || filter.era === site.era) &&
      (filter.type === TYPES[0] || filter.type === site.type) &&
      words.every((word: string) => text.includes(word));
  });
}

export function activeRecords(records: ArchiveRecord[], kind: string): ArchiveRecord[] {
  return records.filter((record: ArchiveRecord) => record.kind === kind && !record.deleted)
    .sort((a: ArchiveRecord, b: ArchiveRecord) => b.updatedAt - a.updatedAt || compareText(a.id, b.id));
}

export function nextTimestamp(records: ArchiveRecord[], now: number): number {
  return records.reduce((latest: number, record: ArchiveRecord) => Math.max(latest, record.updatedAt + 1), now);
}

export function putRecord(records: ArchiveRecord[], record: ArchiveRecord): ArchiveRecord[] {
  return records.filter((item: ArchiveRecord) => item.id !== record.id).concat([record]);
}

export function compareText(a: string, b: string): number {
  return a === b ? 0 : (a < b ? -1 : 1);
}

function recordContent(record: ArchiveRecord): string {
  const pose = record.snapshot3DPose;
  const frame = pose === undefined ? undefined : pose.viewFrame;
  const assist = record.aiAssist;
  // 明确字段顺序，不依赖 JSON 对象的属性插入顺序。可选字段缺省在数组里规范化为 null。
  // 新手账字段也参与版本比较，正文相同而纸色、印章或视角不同的记录不能被判为同一版本。
  // AI 参考元数据包含冻结事实正文，必须参与比较；否则同一页删改依据后会被误判为相同版本。
  return JSON.stringify([record.kind, record.siteId, record.body, record.tags,
    record.stampType, record.paperTheme, record.quotedPoemOrFact,
    pose === undefined ? null : [pose.version, pose.sceneType, pose.yaw, pose.pitch, pose.zoom,
      pose.hotspotId, pose.sectionId, pose.label, pose.proceduralPreset, pose.sceneRevision, pose.rendererProfile,
      frame === undefined ? null : [frame.width, frame.height, frame.textDensity, frame.dark]],
    assist === undefined ? null : [assist.version, assist.question, assist.factIds, assist.contentRevision,
      assist.facts.map((fact: AiFactSnapshot): (string | string[])[] => [fact.id, fact.title, fact.body, fact.sourceIds])]]);
}

// 相同时间戳必须有稳定的次序，否则 A 合并 B 与 B 合并 A 会得出不同结果。
// 相同时间的删除优先，其次设备 ID，最后完整内容；禁止使用依赖语言环境的 localeCompare。
export function compareVersions(a: ArchiveRecord, b: ArchiveRecord): number {
  if (a.updatedAt !== b.updatedAt) return a.updatedAt - b.updatedAt;
  if (a.deleted !== b.deleted) return a.deleted ? 1 : -1;
  const deviceOrder = compareText(a.deviceId, b.deviceId);
  if (deviceOrder !== 0) return deviceOrder;
  return compareText(recordContent(a), recordContent(b));
}

export function mergeRecords(local: ArchiveRecord[], remote: ArchiveRecord[]): MergeResult {
  const records: ArchiveRecord[] = [];
  const conflicts: ArchiveRecord[] = [];
  local.concat(remote).forEach((candidate: ArchiveRecord) => {
    const index = records.findIndex((record: ArchiveRecord) => record.id === candidate.id);
    if (index < 0) {
      records.push(candidate);
    } else {
      const previous = records[index];
      const order = compareVersions(candidate, previous);
      if (order !== 0 && candidate.deviceId !== previous.deviceId &&
        (candidate.deleted !== previous.deleted || recordContent(candidate) !== recordContent(previous))) {
        conflicts.push(order > 0 ? previous : candidate);
      }
      if (order > 0) records[index] = candidate;
    }
  });
  records.sort((a: ArchiveRecord, b: ArchiveRecord) => compareText(a.id, b.id));
  return { records, conflicts };
}

export function recommendSites(sites: HeritageSite[], records: ArchiveRecord[], currentId: string = ''): Recommendation[] {
  const favorites = activeRecords(records, 'favorite');
  const viewed = activeRecords(records, 'progress');
  const anchors = sites.filter((site: HeritageSite) => site.id === currentId ||
    favorites.some((record: ArchiveRecord) => record.siteId === site.id) ||
    viewed.some((record: ArchiveRecord) => record.siteId === site.id));
  return sites.filter((site: HeritageSite) => site.id !== currentId &&
    !favorites.some((record: ArchiveRecord) => record.siteId === site.id) &&
    !viewed.some((record: ArchiveRecord) => record.siteId === site.id))
    .map((site: HeritageSite): Recommendation => {
      let score = 0;
      let reason = '从另一座城市开启探索';
      anchors.forEach((anchor: HeritageSite) => {
        let value = 0;
        const reasons: string[] = [];
        if (anchor.era === site.era) { value += 4; reasons.push(`同属${site.era}时期`); }
        if (anchor.city === site.city) { value += 3; reasons.push(`同在${site.city}`); }
        if (anchor.type === site.type) { value += 2; reasons.push(`同为${site.type}`); }
        const shared = anchor.tags.filter((tag: string) => site.tags.includes(tag));
        value += shared.length;
        if (shared.length > 0) reasons.push(`关联${shared[0]}`);
        if (value > score) { score = value; reason = reasons.join(' · '); }
      });
      return { site, score, reason };
    }).sort((a: Recommendation, b: Recommendation) => b.score - a.score || compareText(a.site.id, b.site.id)).slice(0, 3);
}

export function parseSnapshot(raw: string): ArchiveSnapshot {
  const value = JSON.parse(raw) as ArchiveSnapshot;
  if (!value || value.schemaVersion !== 1 || typeof value.deviceId !== 'string' || !value.deviceId ||
    !Array.isArray(value.records) || typeof value.lightEnabled !== 'boolean' ||
    typeof value.reducedMotion !== 'boolean' || value.records.length > 10000) {
    throw new Error('ARCHIVE_INVALID_SCHEMA');
  }
  const ids: string[] = [];
  value.records.forEach((record: ArchiveRecord) => {
    if (!record || typeof record.id !== 'string' || !record.id || ids.includes(record.id) ||
      !['favorite', 'note', 'progress'].includes(record.kind) || typeof record.siteId !== 'string' || !record.siteId ||
      typeof record.body !== 'string' || record.body.length > MAX_NOTE_LENGTH ||
      !Array.isArray(record.tags) || record.tags.length > MAX_NOTE_TAGS ||
      !record.tags.every((tag: string) => typeof tag === 'string' && tag.length <= MAX_NOTE_TAG_LENGTH) ||
      !Number.isSafeInteger(record.updatedAt) || record.updatedAt < 0 ||
      typeof record.deviceId !== 'string' || !record.deviceId || typeof record.deleted !== 'boolean' ||
      (record.stampType !== undefined && typeof record.stampType !== 'string') ||
      (record.paperTheme !== undefined && typeof record.paperTheme !== 'string') ||
      (record.quotedPoemOrFact !== undefined && typeof record.quotedPoemOrFact !== 'string') ||
      (record.snapshot3DPose !== undefined && !isValidMemoryPose(record.snapshot3DPose)) ||
      (record.aiAssist !== undefined && !isValidAiMemoryAssist(record.aiAssist))) {
      throw new Error('ARCHIVE_INVALID_RECORD');
    }
    ids.push(record.id);
  });
  return value;
}

export function isValidMemoryPose(pose: MemoryPose): boolean {
  // 空热点与空主题表示普通视角。支持名单属于视口播放规则，归档层只校验可保留的数据形状。
  return !!pose && Number.isSafeInteger(pose.version) && pose.version > 0 &&
    typeof pose.sceneType === 'string' && pose.sceneType.length > 0 &&
    Number.isFinite(pose.yaw) && Number.isFinite(pose.pitch) && Number.isFinite(pose.zoom) && pose.zoom > 0 &&
    typeof pose.hotspotId === 'string' && typeof pose.sectionId === 'string' && typeof pose.label === 'string' &&
    (pose.proceduralPreset === undefined ||
      (typeof pose.proceduralPreset === 'string' && pose.proceduralPreset.trim().length > 0)) &&
    (pose.sceneRevision === undefined || (Number.isSafeInteger(pose.sceneRevision) && pose.sceneRevision > 0)) &&
    (pose.rendererProfile === undefined ||
      (typeof pose.rendererProfile === 'string' && pose.rendererProfile.trim().length > 0)) &&
    (pose.viewFrame === undefined || validMemoryViewFrame(pose.viewFrame));
}

function validMemoryViewFrame(frame: MemoryViewFrame): boolean {
  // 损坏的扩展必须拒绝整条快照并交给既有读取保护，不能悄悄删掉扩展后覆盖原档案。
  return !!frame && Number.isFinite(frame.width) && frame.width > 0 &&
    Number.isFinite(frame.height) && frame.height > 0 &&
    (frame.textDensity === undefined || (Number.isFinite(frame.textDensity) && frame.textDensity > 0)) &&
    (frame.dark === undefined || typeof frame.dark === 'boolean');
}

function validFactSnapshot(fact: AiFactSnapshot): boolean {
  return !!fact && typeof fact.id === 'string' && /^[a-z0-9-]{1,60}$/.test(fact.id) &&
    typeof fact.title === 'string' && fact.title.trim().length > 0 && fact.title.length <= 120 &&
    typeof fact.body === 'string' && fact.body.trim().length > 0 && fact.body.length <= 1000 &&
    Array.isArray(fact.sourceIds) && fact.sourceIds.length > 0 && fact.sourceIds.length <= 4 &&
    fact.sourceIds.every((id: string) => typeof id === 'string' && /^[a-z0-9-]{1,80}$/.test(id));
}

export function isValidAiMemoryAssist(assist: AiMemoryAssist): boolean {
  // 只校验保留的数据形状；资料版本是否仍可解析由界面按冻结事实显示，不在这里删字段或改写记录。
  return !!assist && Number.isSafeInteger(assist.version) && assist.version > 0 &&
    typeof assist.question === 'string' && assist.question.trim().length > 0 && assist.question.length <= 200 &&
    Array.isArray(assist.factIds) && assist.factIds.length > 0 && assist.factIds.length <= 3 &&
    assist.factIds.every((id: string) => typeof id === 'string' && /^[a-z0-9-]{1,60}$/.test(id)) &&
    new Set<string>(assist.factIds).size === assist.factIds.length &&
    Number.isSafeInteger(assist.contentRevision) && assist.contentRevision > 0 &&
    Array.isArray(assist.facts) && assist.facts.length > 0 && assist.facts.length <= 3 &&
    assist.facts.every((fact: AiFactSnapshot) => validFactSnapshot(fact)) &&
    assist.facts.every((fact: AiFactSnapshot) => assist.factIds.includes(fact.id)) &&
    assist.factIds.every((id: string) => assist.facts.some((fact: AiFactSnapshot) => fact.id === id));
}
