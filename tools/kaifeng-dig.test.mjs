import test from 'node:test';
import assert from 'node:assert/strict';
import { domainModuleUrl } from './load-domain-module.mjs';

// 探方领域层：种子布局、动作代价、判定与评级、存档编解码。
// 这些断言是「它还是一个游戏」的底线：只要有一条挂了，玩法就可能退化成点几下。

const {
  DIG_COLUMNS, DIG_ROWS, DIG_WORK_DAYS, DIG_COST_EXCAVATE, DIG_COST_DEEPER, DIG_ACUTE_WORK,
  DIG_EVIDENCE, createDigLayout, digCellAt, digCellKey, digEvidenceFor, digSeed,
  emptyDig, digUsedWork, digNeedsSubmit, digExcavate, digDeeper, digVerdict, digSubmit,
  digAnswerColumn, digAnswerLayered, digRestart, digRecordId, serializeDig, parseDig, mergeDig,
  digHigherGrade
} = await import(domainModuleUrl('KaifengDig'));

const CHAPTER = 'roam-kf-night';

function layoutOf(attempt) {
  return createDigLayout(CHAPTER, attempt);
}

// 桥列里第一个带桥构件的格子（brokenRow 那格是淤土，不能拿来当桥证据）。
function bridgeCellOf(layout) {
  for (let row = 0; row < DIG_ROWS; row++) {
    const cell = digCellAt(layout, layout.column, row);
    if (cell.top === 'wall-block' || cell.top === 'deck-stone') return cell;
  }
  throw new Error('桥列应当至少有一个构件格');
}

function secondBridgeCellOf(layout, first) {
  return layout.cells.find(cell => cell.col === layout.column && cell.row !== first.row &&
    (cell.top === 'wall-block' || cell.top === 'deck-stone'));
}

function findLayout(predicate, limit = 40) {
  for (let attempt = 1; attempt <= limit; attempt++) {
    const layout = layoutOf(attempt);
    if (predicate(layout)) return layout;
  }
  throw new Error('在给定局数内没找到目标类型的局');
}

test('dig: 同种子同布局，不同局号布局不同', () => {
  assert.deepEqual(layoutOf(1), layoutOf(1));
  assert.equal(digSeed(CHAPTER, 1), digSeed(CHAPTER, 1));
  assert.notEqual(digSeed(CHAPTER, 1), digSeed(CHAPTER, 2));
  // 局号变大必须真的换局：至少出现两种桥列，否则「重开」只是换个数字。
  const columns = new Set();
  for (let attempt = 1; attempt <= 12; attempt++) columns.add(layoutOf(attempt).column);
  assert.ok(columns.size >= 2, '十二局里应当出现不止一种桥列');
});

test('dig: 桥列恰好一整列，构件只出现在桥列，孤石最多一块且不在桥列', () => {
  for (let attempt = 1; attempt <= 30; attempt++) {
    const layout = layoutOf(attempt);
    assert.ok(layout.column >= 0 && layout.column < DIG_COLUMNS);
    let structural = 0;
    let broken = 0;
    let strays = 0;
    for (let row = 0; row < DIG_ROWS; row++) {
      for (let col = 0; col < DIG_COLUMNS; col++) {
        const cell = digCellAt(layout, col, row);
        assert.ok(digEvidenceFor(cell.top), `未知证据 ${cell.top}`);
        const isStructural = cell.top === 'wall-block' || cell.top === 'deck-stone';
        if (col === layout.column) {
          if (isStructural) structural++;
          else {
            assert.equal(cell.top, 'silt', '桥列被破坏的那格只能是淤土');
            broken++;
          }
        } else {
          assert.ok(!isStructural, '非桥列不该出现桥体构件');
          if (cell.top === 'stray-stone') {
            strays++;
            assert.notEqual(col, layout.column);
          }
        }
      }
    }
    // 3 格构件 + 1 格破坏：单格命中不足以下结论，这是防「点几下」的关键。
    assert.equal(structural, 3);
    assert.equal(broken, 1);
    assert.equal(strays, 1);
  }
});

test('dig: 叠压型桥位格有下层，单层型全无下层，非桥列永无下层', () => {
  const layered = findLayout(layout => layout.layered);
  const single = findLayout(layout => !layout.layered);
  for (let row = 0; row < DIG_ROWS; row++) {
    for (let col = 0; col < DIG_COLUMNS; col++) {
      const cell = digCellAt(layered, col, row);
      if (col === layered.column && cell.top !== 'silt') assert.equal(cell.bottom, 'earlier-base');
      if (col !== layered.column) assert.equal(cell.bottom, '');
      assert.equal(digCellAt(single, col, row).bottom, '');
    }
  }
});

test('dig: 发掘扣 1、下挖扣 2，重复发掘不重复扣', () => {
  const layout = layoutOf(1);
  const cell = bridgeCellOf(layout);
  let state = emptyDig(CHAPTER, 1, 100);
  assert.equal(state.workLeft, DIG_WORK_DAYS);

  const first = digExcavate(state, layout, cell.col, cell.row);
  assert.equal(first.ok, true);
  assert.equal(first.state.workLeft, DIG_WORK_DAYS - DIG_COST_EXCAVATE);
  assert.equal(digUsedWork(first.state), 1);

  const again = digExcavate(first.state, layout, cell.col, cell.row);
  assert.equal(again.ok, false);
  assert.equal(again.state.workLeft, DIG_WORK_DAYS - 1, '重复发掘不该再扣工日');
  assert.equal(again.state.dug.length, 1);

  const deep = digDeeper(again.state, layout, cell.col, cell.row);
  assert.equal(deep.ok, true);
  assert.equal(deep.state.workLeft, DIG_WORK_DAYS - 1 - DIG_COST_DEEPER);
  assert.equal(digUsedWork(deep.state), 3);

  const deepAgain = digDeeper(deep.state, layout, cell.col, cell.row);
  assert.equal(deepAgain.ok, false);
  assert.equal(deepAgain.state.workLeft, DIG_WORK_DAYS - 3);
});

test('dig: 工日不足时下挖被拒绝且状态不变', () => {
  const layout = layoutOf(1);
  const cell = bridgeCellOf(layout);
  let state = emptyDig(CHAPTER, 1, 100);
  state = digExcavate(state, layout, cell.col, cell.row).state;
  // 把工日压到 1：直接造一个只够一次发掘的状态，再试图下挖。
  let cursor = state;
  for (let row = 0; row < DIG_ROWS && cursor.workLeft > 1; row++) {
    for (let col = 0; col < DIG_COLUMNS && cursor.workLeft > 1; col++) {
      if (col === cell.col && row === cell.row) continue;
      const next = digExcavate(cursor, layout, col, row);
      if (next.ok) cursor = next.state;
    }
  }
  assert.ok(cursor.workLeft <= 1, '应当能挖到只剩 1 个工日');
  const before = JSON.parse(serializeDig(cursor));
  const denied = digDeeper(cursor, layout, cell.col, cell.row);
  assert.equal(denied.ok, false);
  assert.equal(denied.message.includes('工日'), true);
  assert.deepEqual(JSON.parse(serializeDig(denied.state)), before);
});

test('dig: 未挖的格子不能下挖', () => {
  const layout = layoutOf(1);
  const cell = bridgeCellOf(layout);
  const state = emptyDig(CHAPTER, 1, 100);
  const refused = digDeeper(state, layout, cell.col, cell.row);
  assert.equal(refused.ok, false);
  assert.equal(refused.state.dug.length, 0);
  assert.equal(refused.state.workLeft, DIG_WORK_DAYS);
});

test('dig: 工日耗尽后进入待交付状态，交付之后不能再挖', () => {
  const layout = layoutOf(1);
  let state = emptyDig(CHAPTER, 1, 100);
  // 八次发掘正好用光。
  let count = 0;
  for (let row = 0; row < DIG_ROWS && count < DIG_WORK_DAYS; row++) {
    for (let col = 0; col < DIG_COLUMNS && count < DIG_WORK_DAYS; col++) {
      const next = digExcavate(state, layout, col, row);
      if (next.ok) { state = next.state; count++; }
    }
  }
  assert.equal(state.workLeft, 0);
  assert.equal(digNeedsSubmit(state), true);

  state = digAnswerColumn(state, layout.column);
  state = digAnswerLayered(state, layout.layered ? 'layered' : 'single');
  const submitted = digSubmit(state, layout, 200);
  assert.equal(submitted.state.phase, 'settled');
  assert.equal(digNeedsSubmit(submitted.state), false);

  const afterSubmit = digExcavate(submitted.state, layout, 0, 0);
  assert.equal(afterSubmit.ok, false);
});

test('dig: 四档评级与甲级用工门槛', () => {
  const layout = layoutOf(1);
  const cell = bridgeCellOf(layout);

  // 未过：桥列选错。
  let wrong = emptyDig(CHAPTER, 1, 100);
  wrong = digExcavate(wrong, layout, cell.col, cell.row).state;
  wrong = digDeeper(wrong, layout, cell.col, cell.row).state;
  wrong = digAnswerColumn(wrong, (layout.column + 1) % DIG_COLUMNS);
  wrong = digAnswerLayered(wrong, layout.layered ? 'layered' : 'single');
  assert.equal(digVerdict(wrong, layout).grade, '未过');

  // 丙：桥列对，层序留空。
  let naked = emptyDig(CHAPTER, 1, 100);
  naked = digExcavate(naked, layout, cell.col, cell.row).state;
  naked = digAnswerColumn(naked, layout.column);
  assert.equal(digVerdict(naked, layout).grade, '丙');

  // 丙：桥列对，但没下挖就答层序——按猜处理。
  let guessed = emptyDig(CHAPTER, 1, 100);
  guessed = digExcavate(guessed, layout, cell.col, cell.row).state;
  guessed = digAnswerColumn(guessed, layout.column);
  guessed = digAnswerLayered(guessed, layout.layered ? 'layered' : 'single');
  const guessVerdict = digVerdict(guessed, layout);
  assert.equal(guessVerdict.correctLayer, false);
  assert.equal(guessVerdict.grade, '丙');

  // 甲：同列两处上层石料 + 真正构件下的证据 + 用工 ≤ 6。
  let acute = emptyDig(CHAPTER, 1, 100);
  acute = digExcavate(acute, layout, cell.col, cell.row).state;
  acute = digDeeper(acute, layout, cell.col, cell.row).state;
  const second = secondBridgeCellOf(layout, cell);
  acute = digExcavate(acute, layout, second.col, second.row).state;
  acute = digAnswerColumn(acute, layout.column);
  acute = digAnswerLayered(acute, layout.layered ? 'layered' : 'single');
  const acuteVerdict = digVerdict(acute, layout);
  assert.equal(acuteVerdict.usedWork, 4);
  assert.equal(acuteVerdict.grade, '甲');

  // 乙：判断都对，但用工超过 6。
  let slow = acute;
  for (let row = 0; row < DIG_ROWS; row++) {
    for (let col = 0; col < DIG_COLUMNS; col++) {
      if (slow.workLeft <= DIG_ACUTE_WORK - 0 && digUsedWork(slow) >= DIG_ACUTE_WORK + 1) continue;
      if (col === cell.col && row === cell.row) continue;
      const next = digExcavate(slow, layout, col, row);
      if (next.ok && digUsedWork(next.state) <= DIG_WORK_DAYS) slow = next.state;
    }
  }
  const slowVerdict = digVerdict(slow, layout);
  assert.ok(slowVerdict.usedWork > DIG_ACUTE_WORK, `用工应超过 ${DIG_ACUTE_WORK}，实际 ${slowVerdict.usedWork}`);
  assert.equal(slowVerdict.correctLayer, true);
  assert.equal(slowVerdict.grade, '乙');
});

test('dig: 单层局不挖下层就答「明桥压宋基」判错', () => {
  const single = findLayout(layout => !layout.layered);
  const cell = bridgeCellOf(single);
  let state = emptyDig(CHAPTER, 1, 100);
  state = digExcavate(state, single, cell.col, cell.row).state;
  // 看见上层石构件就断言叠压，是典型的过度推断。
  state = digAnswerColumn(state, single.column);
  state = digAnswerLayered(state, 'layered');
  const verdict = digVerdict(state, single);
  assert.equal(verdict.correctColumn, true);
  assert.equal(verdict.correctLayer, false);
  assert.equal(verdict.grade, '丙');

  // 真下挖过、看到生土，再答「仅见明桥」才算对。
  state = digAnswerLayered(state, 'single');
  state = digDeeper(state, single, cell.col, cell.row).state;
  assert.equal(digVerdict(state, single).correctLayer, true);
});

test('dig: 结算写入评级，重开推进局号并保留最佳', () => {
  const layout = layoutOf(1);
  const cell = bridgeCellOf(layout);
  let state = emptyDig(CHAPTER, 1, 100);
  state = digExcavate(state, layout, cell.col, cell.row).state;
  state = digDeeper(state, layout, cell.col, cell.row).state;
  const second = secondBridgeCellOf(layout, cell);
  state = digExcavate(state, layout, second.col, second.row).state;
  state = digAnswerColumn(state, layout.column);
  state = digAnswerLayered(state, layout.layered ? 'layered' : 'single');
  const submitted = digSubmit(state, layout, 200);
  assert.equal(submitted.state.bestGrade, '甲');
  assert.equal(submitted.state.lastGrade, '甲');

  const restarted = digRestart(submitted.state, 300);
  assert.equal(restarted.attempt, 2);
  assert.equal(restarted.phase, 'playing');
  assert.equal(restarted.workLeft, DIG_WORK_DAYS);
  assert.equal(restarted.dug.length, 0);
  assert.equal(restarted.answerColumn, -1);
  assert.equal(restarted.bestGrade, '甲', '重开不该抹掉最佳评级');
  assert.equal(digHigherGrade('丙', '乙'), '乙');
  assert.equal(digHigherGrade('', '未过'), '未过');
});

test('dig: codec 往返一致，残缺存档一律 undefined', () => {
  const layout = layoutOf(1);
  const cell = bridgeCellOf(layout);
  let state = emptyDig(CHAPTER, 1, 100);
  state = digExcavate(state, layout, cell.col, cell.row).state;
  state = digDeeper(state, layout, cell.col, cell.row).state;
  const parsed = parseDig(serializeDig(state));
  assert.deepEqual(parsed, state);
  assert.ok(serializeDig(state).length <= 1800);

  const good = JSON.parse(serializeDig(state));
  assert.equal(parseDig(''), undefined);
  assert.equal(parseDig('not json'), undefined);
  const badVersion = JSON.parse(JSON.stringify(good)); badVersion.version = 2;
  assert.equal(parseDig(JSON.stringify(badVersion)), undefined);
  const badChapter = JSON.parse(JSON.stringify(good)); badChapter.chapterId = '../etc';
  assert.equal(parseDig(JSON.stringify(badChapter)), undefined);
  const badCell = JSON.parse(JSON.stringify(good)); badCell.dug = ['9-9'];
  assert.equal(parseDig(JSON.stringify(badCell)), undefined);
  const deepWithoutDug = JSON.parse(JSON.stringify(good));
  deepWithoutDug.deep = ['4-3'];
  assert.equal(parseDig(JSON.stringify(deepWithoutDug)), undefined);
  const badWork = JSON.parse(JSON.stringify(good)); badWork.workLeft = DIG_WORK_DAYS - 1;
  assert.equal(parseDig(JSON.stringify(badWork)), undefined);
  const badAnswer = JSON.parse(JSON.stringify(good)); badAnswer.answerColumn = 7;
  assert.equal(parseDig(JSON.stringify(badAnswer)), undefined);
  const settledNoAnswer = JSON.parse(JSON.stringify(good));
  settledNoAnswer.phase = 'settled';
  assert.equal(parseDig(JSON.stringify(settledNoAnswer)), undefined);
});

test('dig: 合并取较大局号，最佳评级不被覆盖', () => {
  const oldLocal = emptyDig(CHAPTER, 1, 100);
  oldLocal.bestGrade = '甲';
  oldLocal.lastGrade = '甲';
  oldLocal.phase = 'settled';
  oldLocal.workLeft = DIG_WORK_DAYS - 1;
  oldLocal.dug = ['0-0'];
  oldLocal.answerColumn = 0;

  const newer = emptyDig(CHAPTER, 2, 200);
  newer.dug = ['1-1'];
  newer.workLeft = DIG_WORK_DAYS - 1;

  const merged = mergeDig(oldLocal, newer);
  assert.equal(merged.attempt, 2);
  assert.equal(merged.dug.length, 1);
  assert.equal(merged.dug[0], '1-1');
  assert.equal(merged.bestGrade, '甲', '重开换局后历史最佳仍然保留');

  // 同局号按时间戳，但最佳仍取高。
  const a = emptyDig(CHAPTER, 3, 300);
  a.bestGrade = '丙';
  a.dug = ['0-0'];
  a.workLeft = DIG_WORK_DAYS - 1;
  const b = emptyDig(CHAPTER, 3, 400);
  b.bestGrade = '乙';
  b.dug = ['0-1'];
  b.workLeft = DIG_WORK_DAYS - 1;
  const sameAttempt = mergeDig(a, b);
  assert.equal(sameAttempt.dug[0], '0-1', '同局号取较新的那一份');
  assert.equal(sameAttempt.bestGrade, '乙');

  assert.equal(mergeDig(undefined, undefined), undefined);
  assert.deepEqual(mergeDig(undefined, newer), newer);
});

test('dig: 记录 id 与非法章节', () => {
  assert.equal(digRecordId(CHAPTER), 'progress:kaifeng-dig:v1:roam-kf-night');
  assert.throws(() => digRecordId('../bad'));
  assert.throws(() => digRecordId(''));
});

test('dig: 孤石与桥体构件同名同描述，标签不替玩家下结论', () => {
  const wall = DIG_EVIDENCE.find(item => item.id === 'wall-block');
  const deck = DIG_EVIDENCE.find(item => item.id === 'deck-stone');
  const stray = DIG_EVIDENCE.find(item => item.id === 'stray-stone');
  assert.equal(stray.label, wall.label, '孤石必须与桥体构件同名，否则一眼就能排除');
  assert.equal(stray.note, wall.note, '描述也要一致，区别只能靠「同列有没有第二块」');
  assert.equal(deck.label, stray.label, '石板也要有同名干扰，不能靠名称唯一锁定桥列');
  assert.equal(deck.note, stray.note, '不能靠石板的说明排除孤石');
  for (const item of DIG_EVIDENCE) {
    assert.equal(item.note.includes('不能据此'), false, `${item.id} 的说明不该替玩家下结论`);
    assert.equal(item.label.includes('桥'), false, `${item.id} 的标签不该出现「桥」`);
  }
});

test('dig: 叠压局的破坏淤土格见生土，不能当作看见了下层石料', () => {
  const layout = findLayout(candidate => candidate.layered);
  const broken = layout.cells.find(cell => cell.col === layout.column && cell.top === 'silt');
  let state = emptyDig(CHAPTER, 1, 100);
  state = digExcavate(state, layout, broken.col, broken.row).state;
  const deepened = digDeeper(state, layout, broken.col, broken.row);
  assert.match(deepened.message, /生土/);
  state = digAnswerLayered(digAnswerColumn(deepened.state, layout.column), 'layered');
  const verdict = digVerdict(state, layout);
  assert.equal(verdict.sawBridgeBottom, false);
  assert.equal(verdict.correctLayer, false);
  assert.equal(verdict.grade, '丙');
  assert.ok(verdict.reasons.some(reason => reason.includes('只见生土')));
  assert.ok(verdict.reasons.some(reason => reason.includes('破坏淤土格')));
  assert.ok(verdict.reasons.every(reason => !reason.includes('见到下层石料') && !reason.includes('实见另一批石料')),
    '隐藏布局有石料，不等于玩家已看到石料');
  assert.equal(digVerdict(digAnswerLayered(state, 'single'), layout).correctLayer, false,
    '破坏格也不能证明桥体只有一层');
});

test('dig: 孤石与单格命中不支持高评级，未挖过的下层不写成依据', () => {
  const layout = findLayout(candidate => candidate.layered);
  const cell = bridgeCellOf(layout);
  const stray = layout.cells.find(candidate => candidate.top === 'stray-stone');
  let state = emptyDig(CHAPTER, 1, 100);
  state = digExcavate(state, layout, cell.col, cell.row).state;
  state = digDeeper(state, layout, cell.col, cell.row).state;
  state = digAnswerLayered(digAnswerColumn(state, layout.column), 'layered');
  assert.equal(digVerdict(state, layout).correctLayer, true);
  assert.equal(digVerdict(state, layout).grade, '丙', '只见一处上层石料，不能称桥轴证据充分');
  const second = secondBridgeCellOf(layout, cell);
  state = digExcavate(state, layout, second.col, second.row).state;
  assert.equal(digVerdict(state, layout).grade, '甲');

  let isolated = emptyDig(CHAPTER, 1, 100);
  isolated = digExcavate(isolated, layout, stray.col, stray.row).state;
  isolated = digDeeper(isolated, layout, stray.col, stray.row).state;
  isolated = digAnswerLayered(digAnswerColumn(isolated, layout.column), 'layered');
  const verdict = digVerdict(isolated, layout);
  assert.equal(verdict.correctLayer, false);
  assert.equal(verdict.structuralCells, 0);
  assert.ok(verdict.reasons.some(reason => reason.includes(`第 ${stray.col + 1} 列第 ${stray.row + 1} 行已到底`)));
  assert.ok(verdict.reasons.every(reason => !reason.includes('实见另一批石料')));
});

test('dig: 评级字段缺失、未知值和矛盾结算一律拒绝，旧合法评级原样保留', () => {
  const state = emptyDig(CHAPTER, 1, 100);
  for (const name of ['bestGrade', 'lastGrade']) {
    for (const value of [undefined, null, 1, '丁', '甲级']) {
      const invalid = { ...state, [name]: value };
      assert.equal(parseDig(JSON.stringify(invalid)), undefined, `${name}=${String(value)} 不能读成合法存档`);
    }
  }
  assert.equal(parseDig(JSON.stringify({ ...state, phase: 'settled', answerColumn: 1 })), undefined,
    '已结算必须有本局评级');
  assert.equal(parseDig(JSON.stringify({ ...state, bestGrade: '丙', lastGrade: '甲' })), undefined);
  const historical = { ...state, phase: 'settled', answerColumn: 1, bestGrade: '甲', lastGrade: '丙' };
  assert.deepEqual(parseDig(JSON.stringify(historical)), historical,
    '修正判定规则不能回算、降级或清除已经保存的合法历史成绩');
});

test('dig: 同刻局面合并与输入方向无关，旧局的晚时间不冻结新局', () => {
  const a = emptyDig(CHAPTER, 2, 100);
  const b = { ...a, answerColumn: 2, bestGrade: '乙' };
  assert.deepEqual(mergeDig(a, b), mergeDig(b, a));
  const oldAttempt = { ...emptyDig(CHAPTER, 1, 900), bestGrade: '甲' };
  const newerAttempt = mergeDig(oldAttempt, a);
  assert.equal(newerAttempt.attempt, 2);
  assert.equal(newerAttempt.updatedAt, 100, '当前局时钟不能被旧局的历史最佳抬高');
  const edited = { ...a, answerColumn: 3, updatedAt: 200 };
  const continued = mergeDig(newerAttempt, edited);
  assert.equal(continued.answerColumn, 3);
  assert.equal(continued.bestGrade, '甲');
});

test('dig: 工日只有 8 个，五列各挖两格是做不到的', () => {
  // 10 个工日刚好够扫完五列，排除法即可定轴；8 个才逼出取舍。
  assert.equal(DIG_WORK_DAYS, 8);
  assert.ok(DIG_WORK_DAYS < DIG_COLUMNS * 2, '工日必须少于「每列两格」的总量');
  assert.equal(DIG_ACUTE_WORK < DIG_WORK_DAYS, true);
});

test('dig: 证据只有通用类别，不出现窑口、年号、人物', () => {
  const forbidden = ['窑', '年制', '熙宁', '元丰', '徽宗', '苏轼'];
  for (const item of DIG_EVIDENCE) {
    for (const word of forbidden) {
      assert.equal(item.note.includes(word), false, `${item.id} 的说明不该出现「${word}」`);
      assert.equal(item.label.includes(word), false, `${item.id} 的标签不该出现「${word}」`);
    }
  }
  assert.equal(DIG_EVIDENCE.length >= 7, true);
  const key = digCellKey(2, 3);
  assert.equal(key, '2-3');
});
