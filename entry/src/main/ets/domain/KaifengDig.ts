// 汴河探方：5 列 × 4 行，8 个工日。
//
// 与 KaifengPuzzle 的桥 / 叠层 / 灯三幕完全独立：那三幕降级为「档案导读」，
// 这里才是开封的主玩法。
//
// 设计约束（见 docs/HANDOVER_TANFANG_2026-10-24.md）：
// - 奖励的是判断，不是挖到东西：证据只有通用类别，没有器物价值，不做挖宝反馈。
// - 确定性：同 (chapterId, attempt) 必须生成同一布局，全程不调用 Math.random。
// - 严格解析：残缺 / 越界 / 自相矛盾的存档一律返回 undefined，
//   不补成「看起来正常」的局——否则玩家会拿到一局自己没挖过的探方。
//
// 对任务书 §3.2 的一处修订（必须记住，否则玩法会退化）：
// 若「桥位格上层固定为桥构件、非桥位格永不出石构件」，玩家挖一格命中就能锁定整列，
// 五列试三下就结束，仍是「点几下」。因此改为：
//   - 桥列 4 格中 3 格有桥构件，1 格被后世破坏成淤土；
//   - 非桥列中有 1 列、1 格出现「孤石」，单块石料，不能据此定轴。
// 这样单格命中不足以下结论，要同列第二格才能定轴，工日成本才真正咬合。

export const DIG_COLUMNS: number = 5;
export const DIG_ROWS: number = 4;
export const DIG_WORK_DAYS: number = 8;
export const DIG_COST_EXCAVATE: number = 1;
export const DIG_COST_DEEPER: number = 2;
// 甲级门槛：用工不超过 6。8 个工日里只允许浪费 2 格，逼玩家先想再挖。
// 工日不用 10：那样刚好够把五列各挖两格，排除法即可定轴，等于没有取舍。
export const DIG_ACUTE_WORK: number = 6;

export interface DigEvidence {
  id: string;
  label: string;
  note: string;
  // 是否桥体构件。孤石虽然也是石头，但不算——它是用来制造不确定性的。
  structural: boolean;
}

// 证据只描述「看到了什么」，不写「这说明什么」。
// 早期版本直接写「不能据此定桥轴」「疑为桥面构件」，等于把判断替玩家做了；
// 三种上层石料对玩家统一同名同描述，区别只在「同列还有没有第二块」。
// 保留内部 ID、种子和格位，不改旧 v1 存档的布局；若只让孤石模仿凿痕石块，
// 「平整石板」仍会成为桥列的唯一标记，单格就能泄露答案。
export const DIG_EVIDENCE: DigEvidence[] = [
  { id: 'silt', label: '淤土', note: '河相淤积，土色较纯。', structural: false },
  { id: 'brick', label: '砖瓦', note: '碎砖与瓦片混在一起，被翻动过。', structural: false },
  { id: 'porcelain', label: '瓷片', note: '生活堆积里的瓷片。', structural: false },
  { id: 'disturbed', label: '扰土', note: '后世翻动过的土，层位已被打乱。', structural: false },
  { id: 'wall-block', label: '加工石料', note: '可见加工痕迹，形面较规整。', structural: true },
  { id: 'deck-stone', label: '加工石料', note: '可见加工痕迹，形面较规整。', structural: true },
  { id: 'stray-stone', label: '加工石料', note: '可见加工痕迹，形面较规整。', structural: false },
  { id: 'earlier-base', label: '下层石料', note: '层位更低，石料与上层不是同一批。', structural: true },
  { id: 'bottom-void', label: '生土', note: '已到底，未见更早的堆积。', structural: false }
];

// 非桥位格的生活堆积权重。写在领域层，不散到界面里。
const FILL_WEIGHTS: string[] = ['silt', 'silt', 'silt', 'silt', 'brick', 'brick', 'brick',
  'porcelain', 'porcelain', 'disturbed', 'disturbed'];

export interface DigCell {
  col: number;
  row: number;
  top: string;
  // '' 表示没有下层。叠压型的桥位格才有。
  bottom: string;
}

export interface DigLayout {
  seed: number;
  column: number;
  layered: boolean;
  cells: DigCell[];
}

export function digEvidenceFor(id: string): DigEvidence | undefined {
  return DIG_EVIDENCE.find((item: DigEvidence) => item.id === id);
}

export function digCellKey(col: number, row: number): string {
  return `${col}-${row}`;
}

// FNV-1a：把章节与局号散列成 32 位种子。同一输入永远同一结果。
function digHash(text: string): number {
  let hash = 2166136261;
  for (let index = 0; index < text.length; index++) {
    hash ^= text.charCodeAt(index);
    hash = digMultiply(hash, 16777619);
  }
  return hash >>> 0;
}

// 32 位整数乘法。工程里其余代码从未用过平台的内建 32 位乘法，
// 而方舟运行时不保证提供它（真机上曾表现为整页不渲染），这里自己实现。
function digMultiply(a: number, b: number): number {
  const ah = (a >>> 16) & 0xffff;
  const al = a & 0xffff;
  const bh = (b >>> 16) & 0xffff;
  const bl = b & 0xffff;
  return ((al * bl) + (((ah * bl + al * bh) << 16) >>> 0) | 0);
}

// mulberry32：小而稳，够用，且不依赖平台随机源。
function digRandom(seed: number): () => number {
  let state = seed >>> 0;
  return (): number => {
    state = (state + 0x6D2B79F5) >>> 0;
    let value = state;
    value = digMultiply(value ^ (value >>> 15), value | 1);
    value ^= value + digMultiply(value ^ (value >>> 7), value | 61);
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  };
}

export function digSeed(chapterId: string, attempt: number): number {
  return digHash(`${chapterId}:${attempt}`);
}

export function createDigLayout(chapterId: string, attempt: number): DigLayout {
  const seed = digSeed(chapterId, attempt);
  const random = digRandom(seed);
  const column = Math.floor(random() * DIG_COLUMNS);
  const layered = random() < 0.7;
  // 桥列里哪一格被破坏（不含桥构件）。先定，避免与后续取值顺序耦合。
  const brokenRow = Math.floor(random() * DIG_ROWS);
  // 孤石：从非桥列里挑一列、一行。
  const strayColumn = (column + 1 + Math.floor(random() * (DIG_COLUMNS - 1))) % DIG_COLUMNS;
  const strayRow = Math.floor(random() * DIG_ROWS);

  const cells: DigCell[] = [];
  for (let row = 0; row < DIG_ROWS; row++) {
    for (let col = 0; col < DIG_COLUMNS; col++) {
      let top = '';
      if (col === column) {
        if (row === brokenRow) {
          top = 'silt';
        } else {
          top = row % 2 === 0 ? 'wall-block' : 'deck-stone';
        }
      } else if (col === strayColumn && row === strayRow) {
        top = 'stray-stone';
      } else {
        top = FILL_WEIGHTS[Math.floor(random() * FILL_WEIGHTS.length)];
      }
      const bottom = col === column && layered && row !== brokenRow ? 'earlier-base' : '';
      cells.push({ col, row, top, bottom });
    }
  }
  return { seed, column, layered, cells };
}

export function digCellAt(layout: DigLayout, col: number, row: number): DigCell | undefined {
  if (col < 0 || col >= DIG_COLUMNS || row < 0 || row >= DIG_ROWS) return undefined;
  return layout.cells[row * DIG_COLUMNS + col];
}

export interface KaifengDigV1 {
  version: number;
  chapterId: string;
  attempt: number;
  // playing / settled
  phase: string;
  workLeft: number;
  // 已见上层的格子，key 为 "列-行"
  dug: string[];
  // 已见下层的格子，必须是 dug 的子集
  deep: string[];
  // -1 表示还没选
  answerColumn: number;
  // unknown / layered（明桥压宋基）/ single（仅见明桥）
  answerLayered: string;
  bestGrade: string;
  lastGrade: string;
  updatedAt: number;
}

export type DigGrade = '甲' | '乙' | '丙' | '未过' | '';

export function emptyDig(chapterId: string, attempt: number, updatedAt: number): KaifengDigV1 {
  return {
    version: 1,
    chapterId,
    attempt,
    phase: 'playing',
    workLeft: DIG_WORK_DAYS,
    dug: [],
    deep: [],
    answerColumn: -1,
    answerLayered: 'unknown',
    bestGrade: '',
    lastGrade: '',
    updatedAt
  };
}

export function digUsedWork(state: KaifengDigV1): number {
  return state.dug.length + state.deep.length * DIG_COST_DEEPER;
}

export function digNeedsSubmit(state: KaifengDigV1): boolean {
  return state.phase === 'playing' && state.workLeft <= 0;
}

export function digIsDug(state: KaifengDigV1, col: number, row: number): boolean {
  return state.dug.indexOf(digCellKey(col, row)) >= 0;
}

export function digIsDeep(state: KaifengDigV1, col: number, row: number): boolean {
  return state.deep.indexOf(digCellKey(col, row)) >= 0;
}

export interface DigAction {
  ok: boolean;
  state: KaifengDigV1;
  message: string;
}

function digCopy(state: KaifengDigV1): KaifengDigV1 {
  return {
    version: state.version,
    chapterId: state.chapterId,
    attempt: state.attempt,
    phase: state.phase,
    workLeft: state.workLeft,
    dug: state.dug.slice(),
    deep: state.deep.slice(),
    answerColumn: state.answerColumn,
    answerLayered: state.answerLayered,
    bestGrade: state.bestGrade,
    lastGrade: state.lastGrade,
    updatedAt: state.updatedAt
  };
}

function digReject(state: KaifengDigV1, message: string): DigAction {
  return { ok: false, state, message };
}

// 发掘：花 1 工日，看该格上层。
export function digExcavate(state: KaifengDigV1, layout: DigLayout, col: number, row: number): DigAction {
  if (state.phase !== 'playing') return digReject(state, '这一局已经交付了；重开一局才能再挖。');
  const cell = digCellAt(layout, col, row);
  if (!cell) return digReject(state, '这里不在探方范围内。');
  if (digIsDug(state, col, row)) return digReject(state, '这一格已经清过上层了，可以继续下挖。');
  if (state.workLeft < DIG_COST_EXCAVATE) return digReject(state, '工日不够了，只能交付判断。');
  const next = digCopy(state);
  next.dug.push(digCellKey(col, row));
  next.workLeft = DIG_WORK_DAYS - digUsedWork(next);
  next.updatedAt = state.updatedAt;
  const evidence = digEvidenceFor(cell.top);
  return { ok: true, state: next,
    message: `第 ${col + 1} 列第 ${row + 1} 行：${evidence ? evidence.label : ''}。${evidence ? evidence.note : ''}` };
}

// 下挖：花 2 工日，看该格下层；没有下层时如实说「已到底」。
export function digDeeper(state: KaifengDigV1, layout: DigLayout, col: number, row: number): DigAction {
  if (state.phase !== 'playing') return digReject(state, '这一局已经交付了；重开一局才能再挖。');
  const cell = digCellAt(layout, col, row);
  if (!cell) return digReject(state, '这里不在探方范围内。');
  if (!digIsDug(state, col, row)) return digReject(state, '先把这一格的上层清出来。');
  if (digIsDeep(state, col, row)) return digReject(state, '这一格已经到底了。');
  if (state.workLeft < DIG_COST_DEEPER) {
    return digReject(state, `下挖要 ${DIG_COST_DEEPER} 个工日，现在只剩 ${state.workLeft} 个。`);
  }
  const next = digCopy(state);
  next.deep.push(digCellKey(col, row));
  next.workLeft = DIG_WORK_DAYS - digUsedWork(next);
  next.updatedAt = state.updatedAt;
  if (cell.bottom === '') {
    return { ok: true, state: next,
      message: `第 ${col + 1} 列第 ${row + 1} 行下挖到底：生土，没有更早的堆积。` };
  }
  const evidence = digEvidenceFor(cell.bottom);
  return { ok: true, state: next,
    message: `第 ${col + 1} 列第 ${row + 1} 行下层：${evidence ? evidence.label : ''}。${evidence ? evidence.note : ''}` };
}

export interface DigVerdict {
  grade: DigGrade;
  correctColumn: boolean;
  correctLayer: boolean;
  // 是否下挖到桥列的构件下层。破坏淤土格虽在同一列，也不能代替构件的层序证据。
  sawBridgeBottom: boolean;
  usedWork: number;
  bridgeCells: number;
  otherCells: number;
  // 桥列里见到加工石块的格数：结算用它解释「为什么这一列像桥」。
  structuralCells: number;
  message: string;
  reasons: string[];
}

function digGradeRank(grade: string): number {
  if (grade === '甲') return 3;
  if (grade === '乙') return 2;
  if (grade === '丙') return 1;
  if (grade === '未过') return 0;
  return -1;
}

function validDigGrade(grade: string): boolean {
  // 空字符串只表示尚无历史评级；缺字段、未知字符串和非字符串都不能冒充它。
  return typeof grade === 'string' && (grade === '' || digGradeRank(grade) >= 0);
}

export function digHigherGrade(a: string, b: string): string {
  return digGradeRank(a) >= digGradeRank(b) ? a : b;
}

// 判定只看两件事：桥列选对没有，层序判断有没有证据支撑。
// 挖了多少格不直接加分——只通过「用工」影响甲级门槛。
export function digVerdict(state: KaifengDigV1, layout: DigLayout): DigVerdict {
  let bridgeCells = 0;
  let otherCells = 0;
  let structuralCells = 0;
  for (const key of state.dug) {
    const parts = key.split('-');
    const col = parseInt(parts[0], 10);
    const row = parseInt(parts[1], 10);
    if (col === layout.column) {
      bridgeCells++;
      const cell = digCellAt(layout, col, row);
      if (cell && (cell.top === 'wall-block' || cell.top === 'deck-stone')) structuralCells++;
    } else {
      otherCells++;
    }
  }
  let sawBridgeBottom = false;
  let sawLowerStone = false;
  let sawIntactBottomSoil = false;
  let sawBrokenBottomSoil = false;
  const lowerObservations: string[] = [];
  for (const key of state.deep) {
    const parts = key.split('-');
    const col = parseInt(parts[0], 10);
    const row = parseInt(parts[1], 10);
    const cell = digCellAt(layout, col, row);
    if (!cell) continue;
    // 结算依据逐格取玩家实际下挖的内容，不能用隐藏的 layered 布局标记
    // 把「只挖到生土」改写成「看见另一批石料」。上层被破坏的格子不作桥体层序依据。
    if (cell.bottom === 'earlier-base') {
      lowerObservations.push(`你下挖的第 ${col + 1} 列第 ${row + 1} 行见到下层石料。`);
    } else if (cell.bottom === '') {
      lowerObservations.push(`你下挖的第 ${col + 1} 列第 ${row + 1} 行已到底，只见生土。`);
    }
    if (col !== layout.column) continue;
    const intact = cell.top === 'wall-block' || cell.top === 'deck-stone';
    if (!intact) {
      if (cell.bottom === '') sawBrokenBottomSoil = true;
      continue;
    }
    sawBridgeBottom = true;
    if (cell.bottom === 'earlier-base') sawLowerStone = true;
    if (cell.bottom === '') sawIntactBottomSoil = true;
  }

  const usedWork = digUsedWork(state);
  const correctColumn = state.answerColumn === layout.column;
  const wantsLayered = state.answerLayered === 'layered';
  const wantsSingle = state.answerLayered === 'single';
  const answered = wantsLayered || wantsSingle;
  const correctLayer = answered &&
    ((wantsLayered && sawLowerStone) || (wantsSingle && sawIntactBottomSoil && !layout.layered));

  let grade: DigGrade = '未过';
  if (correctColumn) {
    // 两处上层石料才支持定轴。单格命中（包括石板）仍可能是孤石，
    // 即使猜对桥列和层序，也不把未得到支撑的轴线判断写成甲/乙。
    if (correctLayer && structuralCells >= 2) grade = usedWork <= DIG_ACUTE_WORK ? '甲' : '乙';
    else grade = '丙';
  }

  const reasons: string[] = [];
  reasons.push(`你清出了 ${state.dug.length} 格，其中第 ${layout.column + 1} 列 ${bridgeCells} 格、其余 ${otherCells} 格。`);
  reasons.push(bridgeCells > 0 ? `这一列有 ${structuralCells} 格见到加工过的石料。` :
    '你没有清到第 ' + (layout.column + 1) + ' 列，所以这一列是凭别的线索判断的。');
  if (structuralCells < 2) reasons.push('同列尚未见到两处上层加工石料，桥轴判断仍缺少连续证据。');
  lowerObservations.forEach((observation: string) => reasons.push(observation));
  if (!sawBridgeBottom) {
    reasons.push(sawBrokenBottomSoil ? '破坏淤土格的生土不能代替桥体构件下的层序证据。' :
      '你没有下挖到桥列构件的下层，所以层序判断没有可用证据。');
  } else if (sawLowerStone) {
    reasons.push('桥列构件下实见另一批石料，支持这一处不止一次建桥。');
  } else if (sawIntactBottomSoil) {
    reasons.push('桥列构件下已到底，只见生土，支持这一处只见到一次桥。');
  }
  if (state.answerLayered === 'unknown') reasons.push('你没有回答层序，最高只能记丙。');
  else if (correctColumn && !correctLayer) {
    reasons.push(sawBridgeBottom ? '层序判断与本局证据相反。' : '层序判断缺少证据，按猜处理。');
  }
  reasons.push(`这一局用了 ${usedWork} 个工日。甲级要求两项判断都有证据支持且不超过 ${DIG_ACUTE_WORK} 个。`);

  let message = '';
  if (grade === '甲') message = '桥列与层序都对，工日也省：这是一次干净的判断。';
  else if (grade === '乙') message = '桥列与层序都对，但工日花得多了些。';
  else if (grade === '丙') message = '桥列选对了，桥轴或层序还缺少站得住的证据。';
  else message = `桥列不在这里。本局桥轴在第 ${layout.column + 1} 列。`;

  return {
    grade,
    correctColumn,
    correctLayer,
    sawBridgeBottom,
    usedWork,
    bridgeCells,
    otherCells,
    structuralCells,
    message,
    reasons
  };
}

export interface DigSubmit {
  state: KaifengDigV1;
  verdict: DigVerdict;
}

export function digSubmit(state: KaifengDigV1, layout: DigLayout, updatedAt: number): DigSubmit {
  const verdict = digVerdict(state, layout);
  const next = digCopy(state);
  next.phase = 'settled';
  next.lastGrade = verdict.grade;
  next.bestGrade = digHigherGrade(state.bestGrade, verdict.grade);
  next.updatedAt = updatedAt;
  return { state: next, verdict };
}

export function digAnswerColumn(state: KaifengDigV1, column: number): KaifengDigV1 {
  const next = digCopy(state);
  next.answerColumn = column >= 0 && column < DIG_COLUMNS ? column : -1;
  return next;
}

export function digAnswerLayered(state: KaifengDigV1, value: string): KaifengDigV1 {
  const next = digCopy(state);
  next.answerLayered = value === 'layered' || value === 'single' ? value : 'unknown';
  return next;
}

export function digRestart(state: KaifengDigV1, updatedAt: number): KaifengDigV1 {
  const next = emptyDig(state.chapterId, state.attempt + 1, updatedAt);
  next.bestGrade = state.bestGrade;
  next.lastGrade = state.lastGrade;
  return next;
}

export function digRecordId(chapterId: string): string {
  if (typeof chapterId !== 'string' || !/^roam-[a-z0-9-]{2,60}$/.test(chapterId)) {
    throw new Error('KAIFENG_INVALID_CHAPTER');
  }
  return `progress:kaifeng-dig:v1:${chapterId}`;
}

export function serializeDig(state: KaifengDigV1): string {
  const text = JSON.stringify(state);
  if (text.length > 1800) throw new Error('KAIFENG_DIG_TOO_LARGE');
  return text;
}

function digValidKey(key: string): boolean {
  if (typeof key !== 'string' || !/^[0-4]-[0-3]$/.test(key)) return false;
  return true;
}

export function parseDig(text: string): KaifengDigV1 | undefined {
  if (typeof text !== 'string' || !text.trim()) return undefined;
  let value: KaifengDigV1;
  try {
    value = JSON.parse(text) as KaifengDigV1;
  } catch (_error) {
    return undefined;
  }
  if (!value || value.version !== 1) return undefined;
  if (typeof value.chapterId !== 'string' || !/^roam-[a-z0-9-]{2,60}$/.test(value.chapterId)) return undefined;
  if (!Number.isSafeInteger(value.attempt) || value.attempt < 1) return undefined;
  if (value.phase !== 'playing' && value.phase !== 'settled') return undefined;
  if (!Array.isArray(value.dug) || !Array.isArray(value.deep)) return undefined;
  if (value.dug.length > DIG_COLUMNS * DIG_ROWS || value.deep.length > value.dug.length) return undefined;
  if (!value.dug.every((key: string) => digValidKey(key))) return undefined;
  if (!value.deep.every((key: string) => digValidKey(key) && value.dug.indexOf(key) >= 0)) return undefined;
  if (new Set<string>(value.dug).size !== value.dug.length) return undefined;
  if (new Set<string>(value.deep).size !== value.deep.length) return undefined;
  if (!Number.isSafeInteger(value.workLeft) || value.workLeft < 0 || value.workLeft > DIG_WORK_DAYS) return undefined;
  // 工日必须与已挖格对得上：每格 1 + 下挖 2。对不上说明存档被动过。
  if (value.workLeft !== DIG_WORK_DAYS - (value.dug.length + value.deep.length * DIG_COST_DEEPER)) return undefined;
  if (!Number.isSafeInteger(value.answerColumn) || value.answerColumn < -1 || value.answerColumn >= DIG_COLUMNS) {
    return undefined;
  }
  if (value.answerLayered !== 'unknown' && value.answerLayered !== 'layered' &&
    value.answerLayered !== 'single') return undefined;
  if (!validDigGrade(value.bestGrade) || !validDigGrade(value.lastGrade)) return undefined;
  if (digGradeRank(value.bestGrade) < digGradeRank(value.lastGrade)) return undefined;
  if (value.phase === 'settled' && value.answerColumn < 0) return undefined;
  if (value.phase === 'settled' && value.lastGrade === '') return undefined;
  if (!Number.isSafeInteger(value.updatedAt) || value.updatedAt < 0) return undefined;
  return {
    version: 1,
    chapterId: value.chapterId,
    attempt: value.attempt,
    phase: value.phase,
    workLeft: value.workLeft,
    dug: value.dug.slice(),
    deep: value.deep.slice(),
    answerColumn: value.answerColumn,
    answerLayered: value.answerLayered,
    bestGrade: value.bestGrade,
    lastGrade: value.lastGrade,
    updatedAt: value.updatedAt
  };
}

function digStateKey(state: KaifengDigV1): string {
  // 历史最佳不参与当前局的决胜，否则合并进来的最佳成绩会反过来改变同刻局面的胜负。
  // dug/deep 是集合；排序只用于稳定决策和合并输出，不改变原存档的解析方式。
  return JSON.stringify([state.phase, state.workLeft, state.dug.slice().sort(), state.deep.slice().sort(),
    state.answerColumn, state.answerLayered, state.lastGrade]);
}

// 合并：局号大的一方是「更新的局」，整体采用；同局号按状态时间与固定内容顺序决胜。
// bestGrade 独立取较高者。updatedAt 保留获选局面的时间，不提升成另一旧局的时间：
// 否则一个较晚的旧局会冻结新局，让它之后真实发生的操作也被误判成旧编辑。
export function mergeDig(local: KaifengDigV1 | undefined,
  incoming: KaifengDigV1 | undefined): KaifengDigV1 | undefined {
  if (!local) return incoming ? parseDig(serializeDig(incoming)) : undefined;
  if (!incoming) return parseDig(serializeDig(local));
  let newer: KaifengDigV1;
  let older: KaifengDigV1;
  if (local.attempt !== incoming.attempt) {
    newer = incoming.attempt > local.attempt ? incoming : local;
    older = incoming.attempt > local.attempt ? local : incoming;
  } else {
    const incomingWins = incoming.updatedAt > local.updatedAt ||
      (incoming.updatedAt === local.updatedAt && digStateKey(incoming) >= digStateKey(local));
    newer = incomingWins ? incoming : local;
    older = incomingWins ? local : incoming;
  }
  const merged: KaifengDigV1 = {
    version: 1,
    chapterId: newer.chapterId,
    attempt: newer.attempt,
    phase: newer.phase,
    workLeft: newer.workLeft,
    dug: newer.dug.slice().sort(),
    deep: newer.deep.slice().sort(),
    answerColumn: newer.answerColumn,
    answerLayered: newer.answerLayered,
    bestGrade: digHigherGrade(newer.bestGrade, older.bestGrade),
    lastGrade: newer.lastGrade,
    updatedAt: newer.updatedAt
  };
  return parseDig(serializeDig(merged));
}
