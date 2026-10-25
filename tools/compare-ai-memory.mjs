import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

// HiLog 对单行有长度限制。设备将完整 note 分片输出，主机必须先核对片数、
// 顺序与字符数再比较整条记录；任何缺片 / 截断都失败，不能只挑几个字段宣布跨端一致。
const args = process.argv.slice(2);
const option = name => {
  const index = args.indexOf(name);
  if (index < 0 || !args[index + 1]) throw new Error(`缺少参数 ${name}`);
  return resolve(args[index + 1]);
};

function readNote(path, label) {
  let meta;
  let pieces = new Map();
  for (const line of readFileSync(path, 'utf8').split(/\r?\n/)) {
    const marker = `AI_MEMORY_SYNC_NOTE_META:${label}:`;
    const position = line.indexOf(marker);
    if (position >= 0) {
      meta = JSON.parse(line.slice(position + marker.length));
      pieces = new Map();
      continue;
    }
    const prefix = `AI_MEMORY_SYNC_NOTE_PART:${label}:`;
    const start = line.indexOf(prefix);
    if (start < 0 || !meta) continue;
    const fragment = line.slice(start + prefix.length);
    const separator = fragment.indexOf(':');
    assert.ok(separator > 0, `${label} 分片格式不完整`);
    const index = Number(fragment.slice(0, separator));
    assert.ok(Number.isInteger(index) && index >= 0 && index < meta.parts, `${label} 分片序号错误`);
    const text = JSON.parse(fragment.slice(separator + 1));
    assert.equal(typeof text, 'string', `${label} 分片不是字符串`);
    if (pieces.has(index)) assert.equal(pieces.get(index), text, `${label} 重复分片内容不一致`);
    pieces.set(index, text);
  }
  assert.ok(meta && Number.isInteger(meta.parts) && meta.parts > 0, `${label} 缺少完整记录元信息`);
  assert.equal(pieces.size, meta.parts, `${label} 分片缺失`);
  const json = Array.from({ length: meta.parts }, (_, index) => {
    assert.ok(pieces.has(index), `${label} 缺少第 ${index} 片`);
    return pieces.get(index);
  }).join('');
  assert.equal(json.length, meta.chars, `${label} 字符数不一致，可能已截断`);
  return JSON.parse(json);
}

function canonicalJson(value) {
  // 输入均由 JSON.parse 还原。逐层排序对象键、保留数组顺序，让完整相机、事实与来源都参与哈希；
  // JSON.stringify 的数组 replacer 会在每层套用同一字段白名单，不能用于完整记录规范化。
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(',')}]`;
  if (value !== null && typeof value === 'object') {
    return `{${Object.keys(value).sort().map(key => `${JSON.stringify(key)}:${canonicalJson(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

const a = readNote(option('--a'), 'A');
const b = readNote(option('--b'), 'B');
const after = readNote(option('--after'), 'B_FINAL');
assert.equal(a.siteId, 'zz-dahecun');
assert.equal(a.kind, 'note');
assert.equal(a.deleted, false);
assert.equal(a.snapshot3DPose?.hotspotId, 'opening');
assert.equal(a.snapshot3DPose?.proceduralPreset, 'dahecun_pottery');
assert.equal(a.snapshot3DPose?.sceneRevision, 2);
assert.ok(a.aiAssist?.facts.length > 0);
assert.deepEqual(b, a, 'B 实际收到的完整 note 与 A 磁盘记录不一致');
assert.deepEqual(after, a, 'B 主动再问后改写了原 note');

const fields = Object.keys(a).sort();
const result = {
  result: 'PASS',
  method: '完整 HiLog 分片还原后逐字段深比较；不是同步状态文案比较',
  siteId: a.siteId,
  noteId: a.id,
  receivedExactly: true,
  unchangedAfterExplicitAsk: true,
  comparedFields: fields,
  factIds: a.aiAssist.factIds,
  frozenFactCount: a.aiAssist.facts.length,
  cameraAndFrame: a.snapshot3DPose,
  paperTheme: a.paperTheme,
  stampType: a.stampType,
  canonicalRecordSha256: createHash('sha256').update(canonicalJson(a), 'utf8').digest('hex').toUpperCase()
};
// 摘要只保存本次测试的记录标识与比较结论；账号、密码和网络会话不进入结果。
writeFileSync(option('--output'), `${JSON.stringify(result, null, 2)}\n`, 'utf8');
process.stdout.write(`完整记录比较通过：A → B → B 主动再问后，${fields.length} 个顶层字段及全部嵌套内容一致。\n`);
