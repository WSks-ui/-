import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

// 设备记录用220字符分片，完整还原作品与冻结note再比较；不能只以“同步成功”文案验收。
// 输入限于本轮脱敏事件日志，输出仅记录ID、哈希和断言结果，不输出登录身份或会话。
const args = process.argv.slice(2);
function option(name) {
  const index = args.indexOf(name);
  if (index < 0 || !args[index + 1]) throw new Error(`缺少参数 ${name}`);
  return resolve(args[index + 1]);
}

function record(path, phase, name) {
  const pieces = new Map();
  let total;
  for (const line of readFileSync(path, 'utf8').split(/\r?\n/)) {
    const prefix = `PAPER_SYNC_RECORD:${phase}:${name}:`;
    const start = line.indexOf(prefix);
    if (start < 0) continue;
    const match = /^(\d+)\/(\d+):(.*)$/.exec(line.slice(start + prefix.length));
    assert.ok(match, `${phase}/${name} 分片格式错误`);
    const index = Number(match[1]);
    const count = Number(match[2]);
    assert.ok(Number.isInteger(count) && count > 0 && index >= 1 && index <= count);
    if (total !== undefined) assert.equal(count, total, '分片总数不一致');
    total = count;
    assert.ok(match[3].length > 0 && match[3].length <= 220, '分片长度异常');
    if (index < count) assert.equal(match[3].length, 220, '中间分片疑似被截断');
    if (pieces.has(index)) assert.equal(pieces.get(index), match[3], '重复分片内容不同');
    pieces.set(index, match[3]);
  }
  assert.ok(total, `${phase}/${name} 未记录`);
  assert.equal(pieces.size, total, `${phase}/${name} 缺少分片`);
  const raw = Array.from({ length: total }, (_, index) => {
    assert.ok(pieces.has(index + 1), '缺少指定片号');
    return pieces.get(index + 1);
  }).join('');
  return JSON.parse(raw);
}

function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value !== null && typeof value === 'object') {
    return `{${Object.keys(value).sort().map(key => `${JSON.stringify(key)}:${canonical(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}
const sha = value => createHash('sha256').update(canonical(value)).digest('hex').toUpperCase();

const aPath = option('--a');
const bPath = option('--b');
const returnPath = option('--return');
const phases = [
  [aPath, 'a-saved'], [bPath, 'b-received'], [bPath, 'b-continued'], [returnPath, 'a-return']
];
const values = phases.map(([path, phase]) => ({
  phase, work: record(path, phase, 'work'), note: record(path, phase, 'note')
}));
const [a, b, continued, returned] = values;
for (const value of values) {
  assert.equal(value.work.kind, 'progress');
  assert.equal(value.work.id, 'progress:paper-journey:v1:paper-kf');
  assert.equal(value.note.kind, 'note');
  assert.equal(value.note.paperContext.cityId, 'paper-kf');
  assert.equal(value.note.paperContext.work.mask.length, 480);
  assert.ok(value.note.paperContext.sources.length > 0);
  assert.deepEqual(value.note, a.note, `${value.phase} 改写了保存时的完整note`);
}
assert.deepEqual(b.work, a.work, 'B初次收到的整条作品与A不同');
assert.deepEqual(returned.work, continued.work, '原A未收到B的整条新作品');
const originalWork = JSON.parse(a.work.body);
const continuedWork = JSON.parse(continued.work.body);
assert.notEqual(continuedWork.mask, originalWork.mask, 'B没有产生真实新剪口');
assert.ok(continued.work.updatedAt > a.work.updatedAt, 'B进度版本未更新');
assert.equal(a.note.paperContext.work.mask, originalWork.mask, 'note并非A实际保存的作品');
assert.notEqual(returned.note.paperContext.work.mask, continuedWork.mask, '原note被当前剪口覆盖');

const result = {
  result: 'PASS', method: '完整220字符HiLog分片还原、JSON深比较、实际mask与逻辑版本核对',
  receivedWorkExactly: true, continuedWorkChanged: true, originalDeviceReceivedExactNewWork: true,
  frozenNoteUnchangedInAllFourPhases: true, noteId: a.note.id, workId: a.work.id,
  sourceCount: a.note.paperContext.sources.length,
  comparedNoteFields: Object.keys(a.note).sort(),
  frozenNoteSha256: sha(a.note), originalWorkSha256: sha(a.work), continuedWorkSha256: sha(continued.work),
  phases: values.map(value => ({ phase: value.phase, workSha256: sha(value.work), noteSha256: sha(value.note) }))
};
writeFileSync(option('--output'), JSON.stringify(result, null, 2) + '\n', 'utf8');
process.stdout.write('纸景完整记录比较通过：A保存 → B接收 → B续剪 → 原A收到；四阶段冻结note一致。\n');
