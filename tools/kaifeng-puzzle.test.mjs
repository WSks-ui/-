import assert from 'node:assert/strict';
import { test } from 'node:test';
import { domainModuleUrl } from './load-domain-module.mjs';

const {
  KAIFENG_BRIDGE_START, KAIFENG_EVIDENCE, KAIFENG_LANTERN_DEFAULT, KAIFENG_BOARD_HEIGHT,
  createKaifengWork, judgeKaifengBridge, kaifengHints, kaifengSpotFor,
  parseKaifengWork, placeKaifengEvidence, serializeKaifengWork, settleKaifengBridge, validKaifengLantern,
  judgeKaifengCrossing, kaifengBoatSpotFor, emptyKaifengLayerSlots, placeKaifengLayer,
  emptyKaifengMotifSlots, placeKaifengMotif, kaifengCoverage, kaifengLight,
  emptyKaifengCity, parseKaifengCity, serializeKaifengCity, kaifengCityRecordId
} = await import(domainModuleUrl('KaifengPuzzle'));
const { mergeKaifengCityProgress } = await import(domainModuleUrl('GameProgressMerge'));

const at = (x, y, angle) => ({ x, y, angle });
const layerState = (placed = []) => ({ placed, lastDistance: 0, lastAligned: false });

test('kaifeng: 桥心落在街口、桥身横跨水面，才算同时接通街路与水路', () => {
  const judge = judgeKaifengBridge(at(500, 1030, 90));
  assert.equal(judge.northLanded, true);
  assert.equal(judge.southLanded, true);
  assert.equal(judge.spansRiver, true);
  assert.equal(judge.streetOpen, true);
  assert.equal(judge.waterOpen, true);
  assert.equal(judge.solved, true);
  assert.equal(judge.verdict, 'solved');
  assert.equal(judge.personStop, undefined);
});

test('kaifeng: 顺河平放在水里会堵住航道，不判完成', () => {
  const judge = judgeKaifengBridge(at(500, 1030, 0));
  assert.equal(judge.solved, false);
  assert.equal(judge.lyingInWater, true);
  assert.equal(judge.waterOpen, false);
  assert.equal(judge.verdict, 'along-river');
  assert.ok(judge.boatStop, '船应停在桥前断点');
  assert.ok(judge.message.includes('船'), '反馈要说明船为什么过不去');
});

test('kaifeng: 开局桥在岸上，不能是已解状态', () => {
  const judge = judgeKaifengBridge(KAIFENG_BRIDGE_START);
  assert.equal(judge.solved, false);
  assert.equal(judge.spansRiver, false);
  assert.equal(judge.streetOpen, false);
  assert.equal(judge.verdict, 'on-bank');
  assert.ok(judge.personStop, '行人要停在断点');
});

test('kaifeng: 桥沿街偏北时只接通北岸，南端还没到对岸', () => {
  const judge = judgeKaifengBridge(at(500, 960, 90));
  assert.equal(judge.northLanded, true);
  assert.equal(judge.southLanded, false);
  assert.equal(judge.solved, false);
  assert.equal(judge.verdict, 'north-only');
  assert.ok(judge.personStop, '行人停在桥南头');
});

test('kaifeng: 跨过河但没对准街口属于部分成立，水路通而街路不通', () => {
  const judge = judgeKaifengBridge(at(262, 1030, 90));
  assert.equal(judge.spansRiver, true);
  assert.equal(judge.waterOpen, true);
  assert.equal(judge.streetOpen, false);
  assert.equal(judge.solved, false);
  assert.equal(judge.verdict, 'offset');
});

test('kaifeng: 接近街心与九十度时吸附，远处不吸', () => {
  assert.deepEqual(settleKaifengBridge(at(514, 1037, 84)), { x: 500, y: 1030, angle: 90 });
  const far = settleKaifengBridge(at(700, 600, 41));
  assert.equal(far.x, 700);
  assert.equal(far.y, 600);
  assert.equal(far.angle, 45);
});

test('kaifeng: 角度归一到 0~180，拖出竖幅会被夹回画面内', () => {
  assert.equal(settleKaifengBridge(at(400, 700, 7.4)).angle, 7.4);
  const clamped = settleKaifengBridge(at(-40, 2400, 179));
  assert.equal(clamped.x, 90);
  assert.equal(clamped.y, KAIFENG_BOARD_HEIGHT - 120);
});

test('kaifeng: 提示逐级展开，演示自带“不算独立解出”的标注', () => {
  assert.equal(kaifengHints(0).text, '');
  assert.equal(kaifengHints(1).highlight, 'street');
  assert.equal(kaifengHints(2).highlight, 'pad');
  const demo = kaifengHints(3);
  assert.equal(demo.demo, true);
  assert.ok(demo.text.includes('不算你独立解出'));
});

test('kaifeng: 四片材料里只有三片能解释同址多期，灯事记载会被拒绝并说明原因', () => {
  assert.equal(KAIFENG_EVIDENCE.length, 4);
  assert.equal(KAIFENG_EVIDENCE.filter(item => item.relevant).length, 3);
  const wrong = placeKaifengEvidence(layerState(), 'lantern-record', 8);
  assert.equal(wrong.aligned, false, '对得再准也不能收下不相关的材料');
  assert.deepEqual(wrong.placed, []);
  assert.ok(wrong.message.includes('层位'), '拒绝要说清为什么不相关');
});

test('kaifeng: 锚点没对上就不算叠合，对上后按顺序留下', () => {
  const failed = placeKaifengEvidence(layerState(), 'song-base', 180);
  assert.equal(failed.aligned, false);
  assert.deepEqual(failed.placed, []);
  assert.ok(failed.message.includes('锚点'));

  const first = placeKaifengEvidence(layerState(), 'song-base', 20);
  assert.equal(first.aligned, true);
  assert.deepEqual(first.placed, ['song-base']);

  const third = placeKaifengEvidence(layerState(['song-base', 'ming-deck']), 'burial-silt', 12);
  assert.deepEqual(third.placed, ['song-base', 'ming-deck', 'burial-silt']);
  assert.ok(third.message.includes('同一位置'));
  assert.ok(third.message.includes('不是同一年'));
});

test('kaifeng: 同一份材料重复放下不会产生重复层', () => {
  const again = placeKaifengEvidence(layerState(['song-base']), 'song-base', 10);
  assert.deepEqual(again.placed, ['song-base']);
});

test('kaifeng: 灯位由落点最近的一处决定，不用按钮选', () => {
  assert.equal(kaifengSpotFor(500, 1030, 350, 970), 'bridge');
  assert.equal(kaifengSpotFor(500, 1030, 700, 1150), 'water');
  assert.equal(kaifengSpotFor(500, 1030, 620, 700), 'street');
});

test('kaifeng: 作品快照可往返，并过滤掉不属于这一组的材料', () => {
  const work = createKaifengWork(at(500, 1030, 90), ['song-base', 'not-mine', 'ming-deck'],
    KAIFENG_LANTERN_DEFAULT, true);
  const parsed = parseKaifengWork(serializeKaifengWork(work));
  assert.equal(parsed.version, 1);
  assert.deepEqual(parsed.bridge, { x: 500, y: 1030, angle: 90 });
  assert.deepEqual(parsed.evidence, ['song-base', 'ming-deck']);
  assert.equal(parsed.independent, true);
  assert.equal(parsed.lantern.spot, 'bridge');
});

test('kaifeng: 残缺或不认识的快照不会被补成一份看似正常的作品', () => {
  assert.equal(parseKaifengWork(''), undefined);
  assert.equal(parseKaifengWork('not json'), undefined);
  assert.equal(parseKaifengWork(JSON.stringify({ version: 2, bridge: { x: 500, y: 1030, angle: 90 } })), undefined);
  assert.equal(parseKaifengWork(JSON.stringify({ version: 1 })), undefined);
  assert.equal(parseKaifengWork(JSON.stringify({ version: 1, bridge: { x: 'a', y: 1, angle: 0 } })), undefined);
  assert.equal(parseKaifengWork(JSON.stringify({
    version: 1, bridge: { x: 500, y: 1030, angle: 90 }, evidence: [],
    lantern: { frame: 'nope', paper: 'rice', wish: 'x', spot: 'bridge' }
  })), undefined);
});

test('kaifeng: 灯的组合只校验是否属于原创模型的选项，不规定唯一审美', () => {
  assert.equal(validKaifengLantern(KAIFENG_LANTERN_DEFAULT), true);
  assert.equal(validKaifengLantern({ frame: 'round', paper: 'rice', wish: 'w', spot: 'moon' }), false);
});

// —— 幕一：史料版州桥 ——

test('kaifeng: 北宋州桥是低平平桥，拱桥会让车驾停在坡下', () => {
  const flat = judgeKaifengCrossing(at(500, 1030, 90), 'flat', { x: 720, y: 1150, spot: 'mooring' });
  assert.equal(flat.solved, true);
  assert.equal(flat.verdict, 'crossing');
  assert.ok(flat.message.includes('不通舟船'));

  const arch = judgeKaifengCrossing(at(500, 1030, 90), 'arch', { x: 720, y: 1150, spot: 'mooring' });
  assert.equal(arch.solved, false);
  assert.equal(arch.verdict, 'arch-blocks-cart');
  assert.ok(arch.message.includes('车驾'));
  assert.ok(arch.message.includes('低平'));
  assert.ok(arch.cartStop, '拱桥要指出车驾停在哪里');
});

test('kaifeng: 桥低平但船还在桥前或桥下时不算成立', () => {
  const front = judgeKaifengCrossing(at(500, 1030, 90), 'flat', { x: 760, y: 1010, spot: 'front' });
  assert.equal(front.solved, false);
  assert.equal(front.verdict, 'boat-at-bridge');
  assert.ok(front.message.includes('不通舟船'));

  const under = judgeKaifengCrossing(at(500, 1030, 90), 'flat', { x: 500, y: 1030, spot: 'under' });
  assert.equal(under.solved, false);
  assert.equal(under.verdict, 'boat-under');
  assert.ok(under.message.includes('不能从这里过'));
});

test('kaifeng: 桥位不成立时先报桥位问题，不被桥型覆盖', () => {
  assert.equal(judgeKaifengCrossing(at(262, 1030, 90), 'arch',
    { x: 720, y: 1150, spot: 'mooring' }).verdict, 'offset');
  assert.equal(judgeKaifengCrossing(at(500, 960, 90), 'flat',
    { x: 720, y: 1150, spot: 'mooring' }).verdict, 'north-only');
});

test('kaifeng: 桥位落岸边界保持原判定', () => {
  assert.equal(judgeKaifengBridge(at(500, 972, 90)).solved, true);
  assert.equal(judgeKaifengBridge(at(500, 971.5, 90)).verdict, 'north-only');
  assert.equal(judgeKaifengBridge(at(500, 1088, 90)).solved, true);
  assert.equal(judgeKaifengBridge(at(500, 1088.5, 90)).verdict, 'south-only');
});

test('kaifeng: 船位由落点决定，泊位、桥下、桥前与漂移互不混淆', () => {
  assert.equal(kaifengBoatSpotFor(720, 1150, 500, 1030), 'mooring');
  assert.equal(kaifengBoatSpotFor(500, 1030, 500, 1030), 'under');
  assert.equal(kaifengBoatSpotFor(760, 1010, 500, 1030), 'front');
  assert.equal(kaifengBoatSpotFor(200, 700, 500, 1030), 'adrift');
});

// —— 幕二：层位与石语 ——

test('kaifeng: 层位按年代从下到上，错层会被退回并说明原因', () => {
  const empty = emptyKaifengLayerSlots();
  const siltLow = placeKaifengLayer(empty, 'burial-silt', 'lower', 20);
  assert.equal(siltLow.aligned, false);
  assert.ok(siltLow.message.includes('淤埋'));
  assert.ok(siltLow.message.includes('之下'));

  const songTop = placeKaifengLayer(empty, 'song-base', 'upper', 20);
  assert.equal(songTop.aligned, false);
  assert.ok(songTop.message.includes('宋代桥基'));
  assert.ok(songTop.message.includes('最下面'));

  const lantern = placeKaifengLayer(empty, 'lantern-record', 'middle', 8);
  assert.equal(lantern.aligned, false);
  assert.ok(lantern.message.includes('层位'));

  const song = placeKaifengLayer(empty, 'song-base', 'lower', 20);
  const mid = placeKaifengLayer(song.slots, 'ming-deck', 'middle', 20);
  const top = placeKaifengLayer(mid.slots, 'burial-silt', 'upper', 20);
  assert.equal(top.complete, true);
  assert.ok(top.message.includes('明末淤埋'));
});

test('kaifeng: 同一层位不能被两份材料占用', () => {
  const first = placeKaifengLayer(emptyKaifengLayerSlots(), 'song-base', 'lower', 10);
  const second = placeKaifengLayer(first.slots, 'ming-deck', 'lower', 10);
  assert.equal(second.aligned, false);
  assert.ok(second.message.includes('已经有材料'));
});

test('kaifeng: 石壁残纹按一马双鹤祥云合拢，错位退回', () => {
  const empty = emptyKaifengMotifSlots();
  const wrong = placeKaifengMotif(empty, 'horse', 'bottom');
  assert.equal(wrong.aligned, false);
  assert.ok(wrong.message.includes('海马'));
  assert.ok(wrong.message.includes('祥云'));

  const center = placeKaifengMotif(empty, 'horse', 'center');
  const left = placeKaifengMotif(center.slots, 'crane-a', 'left');
  const right = placeKaifengMotif(left.slots, 'crane-b', 'right');
  const cloud = placeKaifengMotif(right.slots, 'cloud', 'bottom');
  assert.equal(cloud.complete, true);
  assert.ok(cloud.message.includes('祥云'));

  const again = placeKaifengMotif(cloud.slots, 'horse', 'center');
  assert.equal(again.aligned, true);
  assert.equal(again.complete, true);
});

// —— 幕三：州桥夜市 ——

test('kaifeng: 三盏灯照三处摊，两盏时可用中点覆盖', () => {
  const all = kaifengCoverage([
    { id: 'l1', x: 430, y: 620 }, { id: 'l2', x: 570, y: 900 }, { id: 'l3', x: 430, y: 1200 }
  ]);
  assert.equal(all.covered.length, 3);
  assert.equal(all.verdict, 'lit');

  // 一盏放两摊之间 (500,850)：到水饭、爊肉各在 250 内；
  // 第二盏故意放在远处，验证“两盏也能通过、但只记半明”。
  const two = kaifengCoverage([{ id: 'l1', x: 500, y: 850 }, { id: 'l2', x: 120, y: 300 }]);
  assert.equal(two.covered.length, 2);
  assert.equal(two.verdict, 'half');
  assert.equal(two.passed, true);

  assert.equal(kaifengCoverage([{ id: 'l1', x: 430, y: 620 }]).passed, false);
  assert.equal(kaifengCoverage([]).verdict, 'dark');
});

test('kaifeng: 灯火只由真实动作产生并封顶三盏', () => {
  assert.equal(kaifengLight({ bridge: false, layers: false, lantern: false,
    bridgeIndependent: false, note: false }), 0);
  assert.equal(kaifengLight({ bridge: true, layers: true, lantern: false,
    bridgeIndependent: false, note: false }), 2);
  assert.equal(kaifengLight({ bridge: true, layers: true, lantern: false,
    bridgeIndependent: true, note: false }), 3);
  assert.equal(kaifengLight({ bridge: true, layers: true, lantern: true,
    bridgeIndependent: true, note: true }), 3);
});

// —— 养成：城市快照 ——

test('kaifeng: 城市快照往返、记录 id 与合并语义', () => {
  const city = emptyKaifengCity('roam-kf-night', 100);
  city.acts.bridge = true;
  city.acts.layers = true;
  city.layers = { lower: 'song-base', middle: 'ming-deck', upper: 'burial-silt' };
  city.motif = { center: 'horse', left: 'crane-a', right: 'crane-b', bottom: 'cloud' };
  city.lights = [{ id: 'l1', x: 430, y: 620 }];
  const parsed = parseKaifengCity(serializeKaifengCity(city));
  assert.deepEqual(parsed, city);
  assert.ok(serializeKaifengCity(city).length <= 750);
  assert.equal(kaifengCityRecordId('roam-kf-night'), 'progress:kaifeng-city:v1:roam-kf-night');
  assert.throws(() => kaifengCityRecordId('../bad'));

  const local = emptyKaifengCity('roam-kf-night', 100);
  local.acts.bridge = true;
  const incoming = emptyKaifengCity('roam-kf-night', 200);
  incoming.acts.layers = true;
  incoming.layers = { lower: 'song-base', middle: '', upper: '' };
  const merged = mergeKaifengCityProgress(local, incoming);
  assert.equal(merged.acts.bridge, true, '两端的幕完成状态取并集');
  assert.equal(merged.acts.layers, true);
  assert.equal(merged.layers.lower, 'song-base', '较新一端的空槽不会覆盖已放好的层');
  assert.equal(merged.updatedAt, 200);
});

test('kaifeng: 重走换边放置的仙鹤不会合并出两片相同的鹤', () => {
  // 旧记录左 crane-a、右 crane-b；重走后只在左侧重新放 crane-b。
  // 按槽位直并会把两只合成 crane-b x2，结果无法被正式解析器读回。
  const local = emptyKaifengCity('roam-kf-night', 100);
  local.motif = { center: 'horse', left: 'crane-a', right: 'crane-b', bottom: 'cloud' };
  const replay = emptyKaifengCity('roam-kf-night', 200);
  replay.motif = { center: 'horse', left: 'crane-b', right: '', bottom: 'cloud' };
  const merged = mergeKaifengCityProgress(local, replay);
  assert.ok(merged, '去重合并必须产出可读城市');
  assert.equal(merged.motif.left, 'crane-a');
  assert.equal(merged.motif.right, 'crane-b');
  assert.deepEqual(parseKaifengCity(serializeKaifengCity(merged)), merged,
    '合并结果要能被正式解析器往返读回');
});

test('kaifeng: 残缺城市快照不会被补成看似正常的城', () => {
  const base = emptyKaifengCity('roam-kf-night', 100);
  const good = JSON.parse(serializeKaifengCity(base));
  assert.equal(parseKaifengCity('not json'), undefined);
  assert.equal(parseKaifengCity(''), undefined);
  const badVersion = JSON.parse(JSON.stringify(good)); badVersion.version = 2;
  assert.equal(parseKaifengCity(JSON.stringify(badVersion)), undefined);
  const badKind = JSON.parse(JSON.stringify(good)); badKind.bridgeKind = 'nope';
  assert.equal(parseKaifengCity(JSON.stringify(badKind)), undefined);
  const badLayer = JSON.parse(JSON.stringify(good)); badLayer.layers = { lower: 'burial-silt', middle: '', upper: '' };
  assert.equal(parseKaifengCity(JSON.stringify(badLayer)), undefined);
  const badLights = JSON.parse(JSON.stringify(good));
  badLights.lights = [{ id: 'a', x: 1, y: 1 }, { id: 'b', x: 2, y: 2 }, { id: 'c', x: 3, y: 3 }, { id: 'd', x: 4, y: 4 }];
  assert.equal(parseKaifengCity(JSON.stringify(badLights)), undefined);
});
