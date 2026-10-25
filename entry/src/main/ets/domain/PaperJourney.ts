// 纸上生城的纯领域接口：坐标归一化，mask 总是保存展开后的完整纸面。
// 1 表示剪掉；40 列 × 48 行，每行 10 位十六进制，共 480 字符。
export const PAPER_COLUMNS: number = 40;
export const PAPER_ROWS: number = 48;
export const PAPER_HISTORY_LIMIT: number = 4;
export const PAPER_MAX_BODY: number = 4000;
export const PAPER_PALETTE: string[] = ['#E9B17D', '#C96552', '#608B83', '#D5B55C', '#687E9B'];
export const PAPER_CITY_IDS: string[] = ['paper-smx', 'paper-ly', 'paper-zz', 'paper-kf', 'paper-py'];
export type PaperFold = 'none' | 'mirror' | 'quarter';

export interface PaperPoint { x: number; y: number; }

export interface PaperWorkV1 {
  version: number;
  cityId: string;
  revision: number;
  mask: string;
  history: string[];
  fold: PaperFold;
  paper: string;
  light: boolean;
  completedAt: number;
  // 完成时冻结展开后的作品；之后继续剪切不会把已经留下的作品改写。
  completedMask: string;
  completedPaper: string;
  updatedAt: number;
}

export interface PaperAction { work: PaperWorkV1; changed: boolean; message: string; }
export interface PaperCheck { id: string; title: string; detail: string; passed: boolean; }
export interface PaperJudgment {
  passed: boolean;
  title: string;
  detail: string;
  cutRatio: number;
  connectedRatio: number;
  checks: PaperCheck[];
  brokenCells: number[];
}

interface PaperBox { x0: number; y0: number; x1: number; y1: number; }
interface PaperRegion {
  cells: number[];
  minX: number;
  maxX: number;
  minY: number;
  maxY: number;
  centerX: number;
  centerY: number;
}

const PAPER_CELL_COUNT: number = PAPER_COLUMNS * PAPER_ROWS;
const PAPER_EMPTY_MASK: string = '0'.repeat(PAPER_ROWS * PAPER_COLUMNS / 4);

export function isPaperCityId(cityId: string): boolean {
  return PAPER_CITY_IDS.indexOf(cityId) >= 0;
}

function validTime(now: number): boolean {
  return Number.isSafeInteger(now) && now >= 0;
}

function validColor(paper: string): boolean {
  return typeof paper === 'string' && /^#[0-9A-Fa-f]{6}$/.test(paper);
}

function validFold(fold: string): boolean {
  return fold === 'none' || fold === 'mirror' || fold === 'quarter';
}

function validMask(mask: string): boolean {
  return typeof mask === 'string' && mask.length === PAPER_EMPTY_MASK.length && /^[0-9a-f]+$/.test(mask);
}

// 每四格编码为一个十六进制字符，避免 40 位行数据落入 JavaScript 的 32 位位运算截断。
export function paperCells(mask: string): number[] {
  if (!validMask(mask)) throw new Error('PAPER_INVALID_MASK');
  const cells: number[] = [];
  for (let index = 0; index < mask.length; index++) {
    const nibble = parseInt(mask.charAt(index), 16);
    for (let bit = 3; bit >= 0; bit--) cells.push((nibble >>> bit) & 1);
  }
  return cells;
}

function encodeCells(cells: number[]): string {
  let mask = '';
  for (let index = 0; index < cells.length; index += 4) {
    const nibble = cells[index] * 8 + cells[index + 1] * 4 + cells[index + 2] * 2 + cells[index + 3];
    mask += nibble.toString(16);
  }
  return mask;
}

// 仅供场景本地预览编码；它不复制作品/history、不推进时间、不冻结完成状态。
// 持久化仍由 cutPaperStroke 在抬手时统一生成，预览与正式动作共用下方同一段印记规则。
export function paperMaskFromCells(cells: number[]): string {
  return encodeCells(cells);
}

export function paperCellIsCut(work: PaperWorkV1, col: number, row: number): boolean {
  if (!Number.isInteger(col) || !Number.isInteger(row) || col < 0 || col >= PAPER_COLUMNS ||
    row < 0 || row >= PAPER_ROWS) return false;
  const index = row * PAPER_COLUMNS + col;
  const nibble = parseInt(work.mask.charAt(Math.floor(index / 4)), 16);
  return ((nibble >>> (3 - index % 4)) & 1) === 1;
}

function isFrame(index: number): boolean {
  const col = index % PAPER_COLUMNS;
  const row = Math.floor(index / PAPER_COLUMNS);
  return col === 0 || col === PAPER_COLUMNS - 1 || row === 0 || row === PAPER_ROWS - 1;
}

function frameKept(cells: number[]): boolean {
  return cells.every((value: number, index: number) => !isFrame(index) || value === 0);
}

function inBox(index: number, box: PaperBox): boolean {
  const x = index % PAPER_COLUMNS;
  const y = Math.floor(index / PAPER_COLUMNS);
  return x >= box.x0 && x <= box.x1 && y >= box.y0 && y <= box.y1;
}

function countInBox(cells: number[], value: number, box: PaperBox): number {
  let count = 0;
  for (let y = box.y0; y <= box.y1; y++) {
    for (let x = box.x0; x <= box.x1; x++) if (cells[y * PAPER_COLUMNS + x] === value) count++;
  }
  return count;
}

function countRegionInBox(region: PaperRegion, box: PaperBox): number {
  return region.cells.filter((index: number) => inBox(index, box)).length;
}

function keepInBox(cells: number[], box: PaperBox): number {
  return countInBox(cells, 0, box) / ((box.x1 - box.x0 + 1) * (box.y1 - box.y0 + 1));
}

// 使用四邻接：只在角上相碰的两块纸没有可承托的纸骨，剪口也不算真正贯通。
// 同一算法用于整纸支撑、河道与双口内部连通，避免判定与画面使用两套空间逻辑。
function paperRegions(cells: number[], value: number, box?: PaperBox): PaperRegion[] {
  const regions: PaperRegion[] = [];
  const visited: boolean[] = new Array<boolean>(PAPER_CELL_COUNT).fill(false);
  for (let start = 0; start < cells.length; start++) {
    if (visited[start] || cells[start] !== value || (box && !inBox(start, box))) continue;
    const queue: number[] = [start];
    visited[start] = true;
    let cursor = 0;
    let minX = PAPER_COLUMNS;
    let maxX = 0;
    let minY = PAPER_ROWS;
    let maxY = 0;
    let sumX = 0;
    let sumY = 0;
    while (cursor < queue.length) {
      const current = queue[cursor++];
      const x = current % PAPER_COLUMNS;
      const y = Math.floor(current / PAPER_COLUMNS);
      minX = Math.min(minX, x); maxX = Math.max(maxX, x);
      minY = Math.min(minY, y); maxY = Math.max(maxY, y);
      sumX += x; sumY += y;
      const neighbors: number[] = [];
      if (x > 0) neighbors.push(current - 1);
      if (x + 1 < PAPER_COLUMNS) neighbors.push(current + 1);
      if (y > 0) neighbors.push(current - PAPER_COLUMNS);
      if (y + 1 < PAPER_ROWS) neighbors.push(current + PAPER_COLUMNS);
      for (const neighbor of neighbors) {
        if (!visited[neighbor] && cells[neighbor] === value && (!box || inBox(neighbor, box))) {
          visited[neighbor] = true;
          queue.push(neighbor);
        }
      }
    }
    regions.push({ cells: queue, minX, maxX, minY, maxY, centerX: sumX / queue.length, centerY: sumY / queue.length });
  }
  return regions;
}

function check(id: string, title: string, detail: string, passed: boolean): PaperCheck {
  return { id, title, detail, passed };
}

export function createPaperWork(cityId: string, now: number): PaperWorkV1 {
  if (!isPaperCityId(cityId) || !validTime(now)) throw new Error('PAPER_INVALID_WORK');
  return { version: 1, cityId, revision: 1, mask: PAPER_EMPTY_MASK, history: [], fold: 'none',
    paper: PAPER_PALETTE[0], light: false, completedAt: 0, completedMask: '', completedPaper: '', updatedAt: now };
}

export function copyPaperWork(work: PaperWorkV1): PaperWorkV1 {
  return { version: work.version, cityId: work.cityId, revision: work.revision, mask: work.mask,
    history: work.history.slice(), fold: work.fold, paper: work.paper, light: work.light,
    completedAt: work.completedAt, completedMask: work.completedMask, completedPaper: work.completedPaper,
    updatedAt: work.updatedAt };
}

function actionTime(work: PaperWorkV1, now: number): number {
  if (!validTime(now)) throw new Error('PAPER_INVALID_TIME');
  return Math.max(work.updatedAt + 1, now);
}

function unchanged(work: PaperWorkV1, message: string): PaperAction {
  return { work, changed: false, message };
}

function freezeCompleted(work: PaperWorkV1): void {
  if (judgePaper(work).passed && (work.completedMask !== work.mask || work.completedPaper !== work.paper)) {
    work.completedAt = work.updatedAt;
    work.completedMask = work.mask;
    work.completedPaper = work.paper;
  }
}

function stampCut(cells: number[], x: number, y: number, radius: number): void {
  for (let row = Math.max(1, Math.floor(y - radius)); row <= Math.min(PAPER_ROWS - 2, Math.ceil(y + radius)); row++) {
    for (let col = Math.max(1, Math.floor(x - radius)); col <= Math.min(PAPER_COLUMNS - 2, Math.ceil(x + radius)); col++) {
      const dx = col - x;
      const dy = row - y;
      if (dx * dx + dy * dy <= radius * radius + 0.00001) cells[row * PAPER_COLUMNS + col] = 1;
    }
  }
}

function stampFolded(cells: number[], x: number, y: number, radius: number, fold: PaperFold): void {
  stampCut(cells, x, y, radius);
  if (fold === 'mirror' || fold === 'quarter') stampCut(cells, PAPER_COLUMNS - 1 - x, y, radius);
  if (fold === 'quarter') {
    stampCut(cells, x, PAPER_ROWS - 1 - y, radius);
    stampCut(cells, PAPER_COLUMNS - 1 - x, PAPER_ROWS - 1 - y, radius);
  }
}

// 将一段新输入直接落到调用方持有的 cells。from 缺省表示本笔第一点；之后只传新段，
// 每半格插值、折面镜像和最外夹持框都与正式剪纸共用，不能另写一套“看起来相同”的预览。
// 这里不判定完成、不修改 history；返回值只表示输入有效，实际 mask 是否变化由编码后比较。
export function stampPaperSegment(cells: number[], from: PaperPoint | undefined, to: PaperPoint,
  radius: number, fold: PaperFold): boolean {
  if (cells.length !== PAPER_CELL_COUNT || !Number.isFinite(radius) || radius < 0.5 || radius > 6 ||
    !Number.isFinite(to.x) || !Number.isFinite(to.y) ||
    (from !== undefined && (!Number.isFinite(from.x) || !Number.isFinite(from.y)))) return false;
  const x = Math.max(0, Math.min(1, to.x)) * (PAPER_COLUMNS - 1);
  const y = Math.max(0, Math.min(1, to.y)) * (PAPER_ROWS - 1);
  if (from === undefined) { stampFolded(cells, x, y, radius, fold); return true; }
  const startX = Math.max(0, Math.min(1, from.x)) * (PAPER_COLUMNS - 1);
  const startY = Math.max(0, Math.min(1, from.y)) * (PAPER_ROWS - 1);
  const dx = x - startX; const dy = y - startY;
  const steps = Math.max(1, Math.ceil(Math.sqrt(dx * dx + dy * dy) * 2));
  for (let step = 1; step <= steps; step++) {
    stampFolded(cells, startX + dx * step / steps, startY + dy * step / steps, radius, fold);
  }
  return true;
}

// 点间每半格插值一次，手指滑得快也剪出连续线段，不只留下系统上报的两个端点。
// 对折/四折把每次印记镜像到展开纸面；切换折法不重排已有剪口，不产生幽灵补剪。
// 最外一圈是操作夹持的边框，始终保留；内部被闭环切断的纸不会自动“当作剪掉”，而是报告断点供撤销。
export function cutPaperStroke(work: PaperWorkV1, points: PaperPoint[], radius: number = 1,
  now: number = Date.now()): PaperAction {
  if (points.length === 0) return unchanged(work, '沿纸面划下一剪。');
  if (!Number.isFinite(radius) || radius < 0.5 || radius > 6 ||
    points.some((point: PaperPoint) => !Number.isFinite(point.x) || !Number.isFinite(point.y))) {
    return unchanged(work, '这一剪没有落在纸面上。');
  }
  const cells = paperCells(work.mask);
  for (let index = 0; index < points.length; index++) {
    stampPaperSegment(cells, index === 0 ? undefined : points[index - 1], points[index], radius, work.fold);
  }
  const mask = encodeCells(cells);
  if (mask === work.mask) return unchanged(work, '这道剪口已经打开；换个位置试试。');
  const next = copyPaperWork(work);
  next.history = work.history.concat([work.mask]).slice(-PAPER_HISTORY_LIMIT);
  next.mask = mask;
  next.updatedAt = actionTime(work, now);
  freezeCompleted(next);
  const verdict = judgePaper(next);
  return { work: next, changed: true, message: verdict.brokenCells.length > 0 ?
    '这一剪让一片纸失去了支撑。撤回后，试着留一条相连的纸路。' :
    verdict.passed ? '空间关系成立了。还可以继续造景，或把这张纸收进记忆。' : verdict.detail };
}

export function undoPaper(work: PaperWorkV1, now: number = Date.now()): PaperAction {
  if (work.history.length === 0) return unchanged(work, '没有更早的一剪。');
  const next = copyPaperWork(work);
  next.mask = work.history[work.history.length - 1];
  next.history = work.history.slice(0, -1);
  next.updatedAt = actionTime(work, now);
  return { work: next, changed: true, message: '上一剪已经接回；已留下的完成作品仍保留。' };
}

export function setPaperFold(work: PaperWorkV1, fold: PaperFold, now: number = Date.now()): PaperAction {
  if (!validFold(fold) || fold === work.fold) return unchanged(work, '已有剪口保留；下一剪按当前折法展开。');
  const next = copyPaperWork(work); next.fold = fold; next.updatedAt = actionTime(work, now);
  return { work: next, changed: true, message: fold === 'quarter' ? '四折：下一剪会在四处展开。' :
    fold === 'mirror' ? '对折：下一剪会在左右展开。' : '整张展开，自由落剪。' };
}

export function setPaperColor(work: PaperWorkV1, paper: string, now: number = Date.now()): PaperAction {
  if (!validColor(paper) || paper.toUpperCase() === work.paper.toUpperCase()) return unchanged(work, '纸色保持原样。');
  const next = copyPaperWork(work); next.paper = paper.toUpperCase(); next.updatedAt = actionTime(work, now);
  freezeCompleted(next);
  return { work: next, changed: true, message: '纸色已换，剪口与折法保留。' };
}

export function togglePaperLight(work: PaperWorkV1, now: number = Date.now()): PaperAction {
  const next = copyPaperWork(work); next.light = !work.light; next.updatedAt = actionTime(work, now);
  return { work: next, changed: true, message: next.light ? '光穿过剪口。' : '回到纸面。' };
}

function courtyardChecks(cells: number[], regions: PaperRegion[]): PaperCheck[] {
  const center: PaperBox = { x0: 14, y0: 18, x1: 25, y1: 29 };
  const opening = regions.some((region: PaperRegion) => countRegionInBox(region, center) >= 20 &&
    region.maxX - region.minX >= 4 && region.maxY - region.minY >= 4);
  const walls: PaperBox[] = [{ x0: 8, y0: 14, x1: 11, y1: 33 }, { x0: 28, y0: 14, x1: 31, y1: 33 },
    { x0: 12, y0: 10, x1: 27, y1: 13 }, { x0: 12, y0: 34, x1: 27, y1: 37 }];
  const wallCount = walls.filter((box: PaperBox) => keepInBox(cells, box) >= 0.7).length;
  return [check('courtyard-light', '中央打开天光', '把中央剪成有宽度、连在一起的院落，形状由你决定。', opening),
    check('courtyard-walls', '四周院壁仍在', `四周 ${wallCount} / 4 面院壁留住了；留白承托着向下的院子。`, wallCount === 4)];
}

function riverChecks(cells: number[], regions: PaperRegion[]): PaperCheck[] {
  const upper: PaperBox = { x0: 12, y0: 8, x1: 27, y1: 12 };
  const lower: PaperBox = { x0: 12, y0: 35, x1: 27, y1: 39 };
  const connected = regions.some((region: PaperRegion) => region.cells.length >= 50 &&
    countRegionInBox(region, upper) >= 3 && countRegionInBox(region, lower) >= 3);
  const left = keepInBox(cells, { x0: 4, y0: 10, x1: 9, y1: 37 });
  const right = keepInBox(cells, { x0: 30, y0: 10, x1: 35, y1: 37 });
  return [check('river-window', '内河从上游通到下游', '在纸面内部接通上下河段；弯曲的走法也能成立。', connected),
    check('river-banks', '左右两岸都留下', '河窗两旁需要留下足够的纸，才能同时看见两岸山影。', left >= 0.8 && right >= 0.8)];
}

function twinChecks(cells: number[], regions: PaperRegion[]): PaperCheck[] {
  const left: PaperBox = { x0: 8, y0: 8, x1: 15, y1: 14 };
  const right: PaperBox = { x0: 24, y0: 8, x1: 31, y1: 14 };
  const belly: PaperBox = { x0: 12, y0: 22, x1: 27, y1: 35 };
  const necks = paperRegions(cells, 1, { x0: 4, y0: 6, x1: 35, y1: 15 });
  const leftMouth = necks.some((region: PaperRegion) => countRegionInBox(region, left) >= 3 && countRegionInBox(region, right) === 0);
  const rightMouth = necks.some((region: PaperRegion) => countRegionInBox(region, right) >= 3 && countRegionInBox(region, left) === 0);
  const chamber = regions.some((region: PaperRegion) => countRegionInBox(region, left) >= 3 &&
    countRegionInBox(region, right) >= 3 && countRegionInBox(region, belly) >= 12);
  return [check('twin-mouths', '两道上口各自打开', '左右上方保持两道分开的口，别只在顶上横剪一条。', leftMouth && rightMouth),
    check('twin-chamber', '在腹部共享同一片光', '从两口向下，在更低的腹部让剪口相通；不以器物用途作答案。', chamber)];
}

function lanternChecks(regions: PaperRegion[]): PaperCheck[] {
  const windows = regions.filter((region: PaperRegion) => region.cells.length >= 6);
  let spread = false;
  for (const a of windows) {
    for (const b of windows) {
      if (Math.abs(a.centerX - b.centerX) >= 14 || Math.abs(a.centerY - b.centerY) >= 17) spread = true;
    }
  }
  return [check('lantern-windows', '至少三处独立镂光', `现在有 ${windows.length} 处能透光的小窗；每一处留一点面积，别只点一个针孔。`, windows.length >= 3),
    check('lantern-spread', '光在不同方向相望', '把镂光分散开；排列、大小与形状都由你决定。', spread)];
}

function shellChecks(regions: PaperRegion[]): PaperCheck[] {
  const pieces = regions.filter((region: PaperRegion) => region.cells.length >= 2 && region.cells.length <= 80);
  const visited: boolean[] = new Array<boolean>(pieces.length).fill(false);
  const queue: number[] = pieces.length > 0 ? [0] : [];
  if (pieces.length > 0) visited[0] = true;
  let cursor = 0;
  while (cursor < queue.length) {
    const current = pieces[queue[cursor++]];
    for (let index = 0; index < pieces.length; index++) {
      const dx = current.centerX - pieces[index].centerX;
      const dy = current.centerY - pieces[index].centerY;
      if (!visited[index] && dx * dx + dy * dy <= 144) { visited[index] = true; queue.push(index); }
    }
  }
  let minX = PAPER_COLUMNS; let maxX = 0; let minY = PAPER_ROWS; let maxY = 0;
  for (const region of pieces) {
    minX = Math.min(minX, region.centerX); maxX = Math.max(maxX, region.centerX);
    minY = Math.min(minY, region.centerY); maxY = Math.max(maxY, region.centerY);
  }
  return [check('shell-pieces', '至少六段分开的碎光', `现在有 ${pieces.length} 段分开的镂空；用小段来表达蚌片，不必临摹真实龙虎。`, pieces.length >= 6),
    check('shell-contour', '片段隔着留白呼应', '让相邻片段靠近，并把轮廓伸向横纵两个方向；弧线与折线都可以。',
      pieces.length >= 6 && queue.length === pieces.length && maxX - minX >= 18 && maxY - minY >= 12)];
}

export function judgePaper(work: PaperWorkV1): PaperJudgment {
  if (!isPaperCityId(work.cityId) || !validMask(work.mask)) {
    return { passed: false, title: '这张纸暂时无法读取', detail: '作品格式未被识别，原存档应保留。', cutRatio: 0,
      connectedRatio: 0, checks: [check('valid-work', '作品格式有效', '请保留原存档后重试。', false)], brokenCells: [] };
  }
  const cells = paperCells(work.mask);
  const regions = paperRegions(cells, 1);
  const kept = paperRegions(cells, 0);
  const anchored = kept.find((region: PaperRegion) => region.cells.some((index: number) => isFrame(index)));
  const remaining = cells.filter((value: number) => value === 0).length;
  const brokenCells: number[] = [];
  for (const region of kept) {
    if (region !== anchored) for (const index of region.cells) brokenCells.push(index);
  }
  const cutRatio = (PAPER_CELL_COUNT - remaining) / PAPER_CELL_COUNT;
  const connectedRatio = remaining > 0 && anchored ? anchored.cells.length / remaining : 0;
  const checks: PaperCheck[] = [
    check('paper-frame', '夹持边框完整', '最外一圈留作纸面的夹持边，不作为剪口。', frameKept(cells)),
    check('paper-body', '留有承托的纸面', '剪口和留白要一起存在；剪空纸面不会完成这一城。', cutRatio > 0 && cutRatio <= 0.4),
    check('paper-support', '纸骨连着边框', brokenCells.length > 0 ?
      '有一片纸与边框断开了。可以撤回上一剪，给它留一条纸路。' : '所有留下的纸仍与边框相连。', brokenCells.length === 0 && remaining > 0)
  ];
  let cityChecks: PaperCheck[] = [];
  if (work.cityId === 'paper-smx') cityChecks = courtyardChecks(cells, regions);
  else if (work.cityId === 'paper-ly') cityChecks = riverChecks(cells, regions);
  else if (work.cityId === 'paper-zz') cityChecks = twinChecks(cells, regions);
  else if (work.cityId === 'paper-kf') cityChecks = lanternChecks(regions);
  else cityChecks = shellChecks(regions);
  for (const cityCheck of cityChecks) checks.push(cityCheck);
  const failed = checks.find((item: PaperCheck) => !item.passed);
  return { passed: !failed, title: !failed ? '这一城，亮起来了' : brokenCells.length > 0 ? '纸骨断开了，可以撤回一剪' : '再让纸景生长一点',
    detail: failed ? failed.detail : '空间关系成立了；这幅原创纸景属于你的选择。', cutRatio, connectedRatio, checks, brokenCells };
}

// 新格式只存在于独立 progress body，不改变档案 schema v1。损坏作品返回 undefined，
// 调用方必须保留原记录并提示；这里不把错误 mask 补成空白纸，也不静默裁切历史。
export function parsePaperWork(text: string): PaperWorkV1 | undefined {
  if (typeof text !== 'string' || text.length > PAPER_MAX_BODY || !text.trim()) return undefined;
  let value: PaperWorkV1;
  try { value = JSON.parse(text) as PaperWorkV1; } catch (_error) { return undefined; }
  if (!value || value.version !== 1 || value.revision !== 1 || !isPaperCityId(value.cityId) || !validMask(value.mask)) return undefined;
  if (!Array.isArray(value.history) || value.history.length > PAPER_HISTORY_LIMIT ||
    !value.history.every((mask: string) => validMask(mask) && frameKept(paperCells(mask)))) return undefined;
  if (!frameKept(paperCells(value.mask)) || !validFold(value.fold) || !validColor(value.paper) || typeof value.light !== 'boolean') return undefined;
  if (!validTime(value.updatedAt) || !validTime(value.completedAt) || value.completedAt > value.updatedAt) return undefined;
  if (typeof value.completedMask !== 'string' || typeof value.completedPaper !== 'string') return undefined;
  if (value.completedAt === 0) {
    if (value.completedMask !== '' || value.completedPaper !== '') return undefined;
  } else {
    if (!validMask(value.completedMask) || !validColor(value.completedPaper)) return undefined;
    const completed = copyPaperWork(value); completed.mask = value.completedMask;
    if (!judgePaper(completed).passed) return undefined;
  }
  return copyPaperWork(value);
}

export function serializePaperWork(work: PaperWorkV1): string {
  const text = JSON.stringify(work);
  if (text.length > PAPER_MAX_BODY) throw new Error('PAPER_WORK_TOO_LARGE');
  if (!parsePaperWork(text)) throw new Error('PAPER_INVALID_WORK');
  return text;
}

// 单条作品采用 LWW 选择“当前编辑”，绝不把两端剪口按位相加。
// 独立保留时间较新的完成快照，便于新编辑失败后仍回看已留下的作品。
// GameProgressMerge 已将此规则接入本机、HTTPS与原生通道的共用合并入口；
// 这是规则接线说明，具体双端是否验收仍以对应包与实际设备记录为准。
export function mergePaperWork(local: PaperWorkV1 | undefined,
  incoming: PaperWorkV1 | undefined): PaperWorkV1 | undefined {
  const a = local ? parsePaperWork(JSON.stringify(local)) : undefined;
  const b = incoming ? parsePaperWork(JSON.stringify(incoming)) : undefined;
  if (!a) return b;
  if (!b) return a;
  if (a.cityId !== b.cityId) throw new Error('PAPER_CITY_MISMATCH');
  const winner = b.updatedAt > a.updatedAt || (b.updatedAt === a.updatedAt && JSON.stringify(b) > JSON.stringify(a)) ? b : a;
  const next = copyPaperWork(winner);
  const aCompletedKey = a.completedMask + ':' + a.completedPaper;
  const bCompletedKey = b.completedMask + ':' + b.completedPaper;
  const completed = b.completedAt > a.completedAt ||
    (b.completedAt === a.completedAt && bCompletedKey > aCompletedKey) ? b : a;
  next.completedAt = completed.completedAt;
  next.completedMask = completed.completedMask;
  next.completedPaper = completed.completedPaper;
  next.updatedAt = Math.max(a.updatedAt, b.updatedAt);
  return next;
}
