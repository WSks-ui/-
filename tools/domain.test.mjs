import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { stripTypeScriptTypes } from 'node:module';
import { runInNewContext } from 'node:vm';
import { createHash } from 'node:crypto';
import {
  activeRecords, compareVersions, copySnapshot, emptySnapshot, filterSites,
  mergeRecords, nextTimestamp, parseSnapshot, putRecord, recommendSites,
  MAX_NOTE_TAGS_TEXT_LENGTH, CITIES, ERAS, TYPES
} from '../entry/src/main/ets/domain/ArchiveDomain.ts';
import { HERITAGE_SITES } from '../entry/src/main/ets/data/HeritageCatalog.ts';
import { UnavailableSyncGateway } from '../entry/src/main/ets/sync/SyncGateway.ts';
import { archiveStoreForLaunch, DEFAULT_ARCHIVE_STORE } from '../entry/src/main/ets/platform/ArchiveLaunch.ts';
import { connectionReasons, cultureConnections, cultureTopics, personalCultureSites } from '../entry/src/main/ets/domain/CultureConnections.ts';
import { accountStoreName, changedAccountView, guestAccountView, validateAccountInput, validateAccountSession, validateAccountReply } from '../entry/src/main/ets/domain/AccountSync.ts';
import './memory-journal.test.mjs';
import './journey-routes.test.mjs';

test('account stores isolate account identity and test sessions without changing guest data', () => {
  const accountA = 'a'.repeat(32), accountB = 'b'.repeat(32);
  assert.notEqual(accountStoreName(accountA), accountStoreName(accountB));
  assert.ok(accountStoreName(accountA, 'yunheji_test_ui_run_a').startsWith('yunheji_test_ui_'));
  assert.throws(() => accountStoreName('../yunheji_archive_v1'));
  assert.throws(() => accountStoreName(accountA, 'yunheji_archive_v1'));
  assert.equal(DEFAULT_ARCHIVE_STORE, 'yunheji_archive_v1');
});

test('account authentication and sync responses reject invalid identity and statistics', () => {
  assert.throws(() => validateAccountInput('abc', '1234567890'));
  assert.throws(() => validateAccountInput('valid_name', 'short'));
  validateAccountInput('valid_name', '1234567890');
  const session = { accountId: 'a'.repeat(32), username: 'valid_name', token: 'b'.repeat(64), expiresAt: Date.now() + 60000 };
  assert.equal(validateAccountSession(session).accountId, session.accountId);
  assert.throws(() => validateAccountSession({ ...session, expiresAt: 0 }));
  const reply = { accountId: session.accountId, records: [], otherDevices: 0, conflictCount: 0, serverTime: Date.now() };
  validateAccountReply(reply, session.accountId);
  assert.throws(() => validateAccountReply(reply, 'b'.repeat(32)));
  assert.throws(() => validateAccountReply({ ...reply, otherDevices: -1 }, session.accountId));
});

test('account view never manufactures sync success for a guest or unavailable service', () => {
  const initial = guestAccountView();
  assert.equal(initial.signedIn, false); assert.equal(initial.lastSync, 0); assert.equal(initial.otherDevices, -1);
  const failed = changedAccountView(initial, { message: '连接失败', busy: false });
  assert.equal(failed.lastSync, 0); assert.equal(failed.signedIn, false);
  assert.equal(initial.message, '');
});

const all = { keyword: '', city: '全部城市', era: '全部年代', type: '全部类型' };
const record = (patch = {}) => ({
  id: 'note:a', kind: 'note', siteId: 'ly-erlitou', body: '观察记录', tags: ['研究资料'],
  updatedAt: 100, deviceId: 'device-a', deleted: false, ...patch
});

test('all seed cities are covered and stable ids are unique', () => {
  assert.equal(new Set(HERITAGE_SITES.map(s => s.id)).size, HERITAGE_SITES.length);
  assert.equal(new Set(HERITAGE_SITES.map(s => s.city)).size, 5);
  assert.ok(HERITAGE_SITES.every(s => s.reviewStatus === '初稿待校审'));
});
test('empty query returns all records', () => {
  assert.equal(filterSites(HERITAGE_SITES, all).length, HERITAGE_SITES.length);
});
test('city era type and keyword filters intersect', () => {
  assert.deepEqual(filterSites(HERITAGE_SITES, {
    keyword: '  青铜 都城  ', city: '洛阳', era: '夏商', type: '都城遗址'
  }).map(s => s.id), ['ly-erlitou', 'ly-yanshi-shang']);
});
test('impossible combination is empty rather than ignoring filters', () => {
  assert.equal(filterSites(HERITAGE_SITES, { ...all, city: '洛阳', era: '宋' }).length, 0);
});
test('whitespace-only search is empty query', () => {
  assert.equal(filterSites(HERITAGE_SITES, { ...all, keyword: '   ' }).length, HERITAGE_SITES.length);
});
test('active records hide tombstones and sort latest first', () => {
  const records = [record(), record({ id: 'note:b', updatedAt: 200 }), record({ id: 'note:c', deleted: true })];
  assert.deepEqual(activeRecords(records, 'note').map(r => r.id), ['note:b', 'note:a']);
});
test('upsert replaces one logical record', () => {
  assert.equal(putRecord([record()], record({ body: 'new' })).length, 1);
});
test('logical timestamp handles local clock rollback', () => {
  assert.equal(nextTimestamp([record({ updatedAt: 1000 })], 50), 1001);
});
test('latest timestamp wins and losing content is retained', () => {
  const result = mergeRecords([record()], [record({ deviceId: 'device-b', updatedAt: 200, body: 'new' })]);
  assert.equal(result.records[0].body, 'new');
  assert.equal(result.conflicts[0].body, '观察记录');
});
test('same timestamp has deterministic device tie break', () => {
  const a = record(), b = record({ deviceId: 'device-b', body: 'second' });
  assert.deepEqual(mergeRecords([a], [b]).records, mergeRecords([b], [a]).records);
  assert.ok(compareVersions(b, a) > 0);
});
test('semantic equality ignores property insertion order', () => {
  const a = record();
  const b = Object.fromEntries(Object.entries(a).reverse());
  assert.equal(compareVersions(a, b), 0);
});
test('equal timestamp deletion wins over live record', () => {
  const result = mergeRecords([record()], [record({ deleted: true, deviceId: 'device-0' })]);
  assert.equal(result.records[0].deleted, true);
});
test('old offline version cannot resurrect deleted record', () => {
  const deleted = record({ deleted: true, updatedAt: 200 });
  assert.equal(mergeRecords([deleted], [record()]).records[0].deleted, true);
});
test('merge is idempotent and has no conflict for identical records', () => {
  const result = mergeRecords([record()], [record()]);
  assert.equal(result.records.length, 1);
  assert.equal(result.conflicts.length, 0);
});
test('merge is commutative across multiple ids and versions', () => {
  const a = [record(), record({ id: 'note:b' })];
  const b = [record({ updatedAt: 300, deviceId: 'device-b' }), record({ id: 'note:c' })];
  assert.deepEqual(mergeRecords(a, b).records, mergeRecords(b, a).records);
});
test('snapshot copies cannot mutate source tags', () => {
  const data = emptySnapshot('device-a');
  data.records = [record()];
  const copy = copySnapshot(data);
  copy.records[0].tags.push('new');
  assert.deepEqual(data.records[0].tags, ['研究资料']);
});
test('snapshot round trips unicode and timestamps', () => {
  const data = emptySnapshot('device-a');
  data.records = [record()];
  assert.deepEqual(parseSnapshot(JSON.stringify(data)), data);
});
test('corrupt or future snapshots are rejected', () => {
  for (const raw of ['{', 'null', '{}', JSON.stringify({ ...emptySnapshot('a'), schemaVersion: 2 })]) {
    assert.throws(() => parseSnapshot(raw));
  }
});
test('invalid records and duplicate ids are rejected', () => {
  for (const records of [[record({ body: 3 })], [record({ updatedAt: -1 })],
    [record({ tags: [null] })], [record(), record()], [record({ body: 'a'.repeat(4001) })]]) {
    assert.throws(() => parseSnapshot(JSON.stringify({ ...emptySnapshot('a'), records })));
  }
});
test('maximum legal note and tags round trip without truncation', () => {
  const tags = Array.from({ length: 20 }, (_, i) => `${i}`.padEnd(40, '文'));
  assert.equal(tags.join('，').length, MAX_NOTE_TAGS_TEXT_LENGTH);
  const snapshot = { ...emptySnapshot('device-a'), records: [record({ body: '河'.repeat(4000), tags })] };
  assert.deepEqual(parseSnapshot(JSON.stringify(snapshot)), snapshot);
  for (const invalidTags of [tags.concat(['多余']), ['文'.repeat(41)]]) {
    assert.throws(() => parseSnapshot(JSON.stringify({ ...snapshot, records: [record({ tags: invalidTags })] })));
  }
});
test('UI test store is accepted only for a bounded debug-only namespace', () => {
  assert.equal(archiveStoreForLaunch('yunheji_test_ui_123_case', true), 'yunheji_test_ui_123_case');
  assert.equal(archiveStoreForLaunch('yunheji_test_ui_123_case', false), DEFAULT_ARCHIVE_STORE);
  for (const candidate of [undefined, 17, {}, '', 'yunheji_test_ui_', '../snapshot',
    'yunheji_test_ui_/archive', 'yunheji_test_ui_' + 'a'.repeat(81), 'yunheji_archive_v1']) {
    assert.equal(archiveStoreForLaunch(candidate, true), DEFAULT_ARCHIVE_STORE);
  }
});
test('recommendations exclude current and favorites and explain ranking', () => {
  const favorites = [record({ id: 'favorite:ly-erlitou', kind: 'favorite' })];
  const result = recommendSites(HERITAGE_SITES, favorites, 'smx-yangshao');
  assert.equal(result[0].site.id, 'ly-yanshi-shang');
  assert.ok(result[0].reason.includes('夏商'));
  assert.ok(result.every(r => !['ly-erlitou', 'smx-yangshao'].includes(r.site.id)));
});
test('cold start recommendations are deterministic', () => {
  assert.deepEqual(recommendSites(HERITAGE_SITES, []), recommendSites(HERITAGE_SITES.slice().reverse(), []));
});
test('progress is an input to local recommendations', () => {
  const result = recommendSites(HERITAGE_SITES, [record({ kind: 'progress' })], 'ly-erlitou');
  assert.equal(result[0].site.id, 'ly-yanshi-shang');
});
test('landing recommendations do not repeat already viewed content', () => {
  const result = recommendSites(HERITAGE_SITES, [record({ kind: 'progress' })]);
  assert.ok(result.every(r => r.site.id !== 'ly-erlitou'));
});
test('unconfigured sync never claims success', async () => {
  const gateway = new UnavailableSyncGateway();
  assert.equal(gateway.status().lastSuccessfulSync, 0);
  assert.equal(gateway.status().connectedDevices, 0);
  await assert.rejects(gateway.exchange([]), /DISTRIBUTED_SYNC_NOT_CONFIGURED/);
});
test('all catalog illustrations are bundled offline', () => {
  for (const site of HERITAGE_SITES) {
    assert.ok(existsSync(fileURLToPath(new URL(`../entry/src/main/resources/base/media/${site.illustration}`, import.meta.url))));
  }
});
test('light and dark themes contain identical resource keys', () => {
  const colors = path => JSON.parse(readFileSync(new URL(path, import.meta.url), 'utf8')).color.map(x => x.name).sort();
  assert.deepEqual(colors('../entry/src/main/resources/base/element/color.json'),
    colors('../entry/src/main/resources/dark/element/color.json'));
});

test('culture graph explains shared era and content without inventing links', () => {
  const links = cultureConnections(HERITAGE_SITES, 'ly-erlitou');
  assert.equal(links[0].site.id, 'ly-yanshi-shang');
  assert.ok(links[0].reasons.includes('同属夏商时期'));
  assert.ok(links[0].reasons.includes('同为都城遗址'));
  assert.ok(links.some(link => link.site.id === 'zz-shang' && link.reasons.includes('同属夏商时期')));
  assert.deepEqual(connectionReasons(HERITAGE_SITES[0], HERITAGE_SITES[3]), []);
});

test('expanded catalog covers 20 entries, valid filters and unchanged original identities', () => {
  assert.equal(HERITAGE_SITES.length, 20);
  assert.deepEqual(HERITAGE_SITES.slice(0, 5).map(site => site.id),
    ['smx-yangshao', 'ly-erlitou', 'zz-shang', 'kf-iron-pagoda', 'py-qicheng']);
  assert.deepEqual(CITIES.slice(1).map(city => HERITAGE_SITES.filter(site => site.city === city).length), [4, 4, 4, 4, 4]);
  for (const site of HERITAGE_SITES) {
    assert.ok(ERAS.includes(site.era) && TYPES.includes(site.type));
    assert.match(site.id, /^(smx|ly|zz|kf|py)-[a-z]+(?:-[a-z]+)*$/);
    assert.equal(site.reviewStatus, '初稿待校审');
    assert.ok(typeof site.source.title === 'string' && site.source.title.length > 0 && /^https?:\/\//.test(site.source.url));
    for (const field of ['summary', 'overview', 'archaeology', 'history', 'poetry', 'travel']) {
      assert.ok(typeof site[field] === 'string' && site[field].length > 0, `${site.id}: ${field}`);
    }
    assert.equal(filterSites(HERITAGE_SITES, { ...all, keyword: site.name })[0].id, site.id);
  }
});

// Node 的类型擦除不补全 ArkTS 的无扩展名依赖；只在测试加载时解析到实际同一份规则源文件。
const graphSource = readFileSync(new URL('../entry/src/main/ets/domain/CultureGraphData.ts', import.meta.url), 'utf8')
  .replace("from './CultureConnections'", `from '${new URL('../entry/src/main/ets/domain/CultureConnections.ts', import.meta.url).href}'`);
const { cultureGraphData } = await import(`data:text/javascript,${encodeURIComponent(stripTypeScriptTypes(graphSource))}`);
const layoutContext = {};
runInNewContext(readFileSync(new URL('../entry/src/main/resources/rawfile/graph-layout.js', import.meta.url), 'utf8'), layoutContext);
const GraphLayout = layoutContext.YunhejiGraphLayout;
runInNewContext(readFileSync(new URL('../entry/src/main/resources/rawfile/graph-space.js', import.meta.url), 'utf8'), layoutContext);
const GraphSpace = layoutContext.YunhejiGraphSpace;
const { siteObjectShape } = await import('../entry/src/main/ets/domain/SiteObjectGeometry.ts');
const { objectFaceLight, objectRasterFrame, rotateObjectPoint } = await import('../entry/src/main/ets/domain/SiteObjectRaster.ts');

test('native and offline web graph math share checked generated sources', () => {
  for (const [source, asset] of [['CultureGraphLayout', 'graph-layout'], ['CultureGraphSpace', 'graph-space']]) {
    const content = readFileSync(new URL(`../entry/src/main/ets/domain/${source}.ts`, import.meta.url), 'utf8').replace(/\r\n/g, '\n');
    const hash = createHash('sha256').update(content).digest('hex');
    const generated = readFileSync(new URL(`../entry/src/main/resources/rawfile/${asset}.js`, import.meta.url), 'utf8');
    assert.ok(generated.startsWith(`/* Generated from ${source}.ts; source-sha256: ${hash} */`));
  }
});

test('era projection has real depth, centered rotation and reversible node dragging', () => {
  const space = new GraphSpace();
  const near = space.project({ x: 164, y: 240, era: '仰韶' }, 328, 480);
  const far = space.project({ x: 164, y: 240, era: '宋' }, 328, 480);
  assert.ok(near.depth < far.depth && near.scale > far.scale);
  assert.equal(space.depth('未知年代'), 0);
  for (const era of ['仰韶', '龙山', '夏商', '周', '汉唐', '宋', '未知年代']) {
    for (const [dx, dy] of [[0, 0], [60, 35], [-110, -50]]) {
      space.reset(); space.rotate(dx, dy);
      const node = { x: 170, y: 255, era };
      const screen = space.project(node, 328, 480);
      const world = space.unproject(screen.x, screen.y, era, 328, 480);
      assert.ok(world && Math.abs(world.x - node.x) < 1e-8 && Math.abs(world.y - node.y) < 1e-8);
    }
  }
});

test('rotated graph keeps narrow-screen and large-text node targets inside the viewport', () => {
  for (const [width, height, fontScale] of [[328, 448, 1], [328, 658, 1.5], [600, 364, 1]]) {
    const layout = new GraphLayout(width, height);
    layout.setData(cultureGraphData(HERITAGE_SITES, 'ly-erlitou'), fontScale); layout.settle();
    const space = new GraphSpace();
    for (const [dx, dy] of [[0, 0], [2000, 2000], [-4000, -4000]]) {
      space.rotate(dx, dy);
      for (const node of layout.nodes) {
        const point = space.project(node, width, height, layout.nodeWidth, fontScale);
        assert.ok(Object.values(point).every(Number.isFinite));
        assert.ok(point.x - layout.nodeWidth * point.scale / 2 >= 0);
        assert.ok(point.x + layout.nodeWidth * point.scale / 2 <= width);
        assert.ok(point.y >= 52 && point.y + 40 * fontScale * point.scale < height);
      }
    }
    space.reset(); assert.equal(space.yaw, 0.24); assert.equal(space.pitch, -0.13);
  }
});

test('projected labels avoid each other at standard and enlarged font sizes', () => {
  for (const [width, height, fontScale] of [[328, 448, 1], [328, 658, 1.5], [600, 364, 1]]) {
    const layout = new GraphLayout(width, height);
    layout.setData(cultureGraphData(HERITAGE_SITES, 'ly-erlitou'), fontScale); layout.settle();
    const space = new GraphSpace();
    for (const [dx, dy] of [[0, 0], [48, 0], [-60, 20]]) {
      space.reset(); space.rotate(dx, dy);
      const points = space.frame(layout.nodes, width, height, layout.nodeWidth, fontScale);
      for (let i = 0; i < points.length; i++) {
        const a = points[i];
        assert.ok(a.x - a.width / 2 >= 0 && a.x + a.width / 2 <= width);
        assert.ok(a.centerY - a.boxHeight / 2 >= 50 && a.centerY + a.boxHeight / 2 < height);
        for (const b of points.slice(i + 1)) {
          assert.ok(Math.abs(a.x - b.x) >= (a.width + b.width) / 2 - 0.5 ||
            Math.abs(a.centerY - b.centerY) >= (a.boxHeight + b.boxHeight) / 2 - 0.5,
          `${width}/${fontScale}: projected labels overlap: ${a.id}, ${b.id}`);
        }
      }
    }
  }
});

test('manual graph dragging takes precedence over the readable-row packing fallback', () => {
  const layout = new GraphLayout(328, 448), space = new GraphSpace();
  layout.setData(cultureGraphData(HERITAGE_SITES, 'ly-erlitou')); layout.settle();
  const node = layout.nodes.find(item => item.id === 'smx-yangshao');
  layout.drag(node.id, node.x + 35, node.y + 20, true);
  const expected = space.project(node, 328, 448, layout.nodeWidth, 1);
  const moved = space.frame(layout.nodes, 328, 448, layout.nodeWidth, 1).find(point => point.id === node.id);
  assert.equal(moved.x, expected.x);
  node.pinned = false; node.anchorX = node.x; node.anchorY = node.y;
  layout.setData(cultureGraphData(HERITAGE_SITES, 'zz-shang'));
  assert.equal(layout.nodes.find(item => item.id === node.id).anchorX, node.x);
  assert.ok(layout.nodes.find(item => item.id === node.id).dragged);
});

test('six procedural object types produce bounded meshes with valid indices and unit normals', () => {
  const counts = { '聚落遗址': 1, '都城遗址': 3, '城址': 1, '古建筑': 6, '墓葬群': 1, '窑址': 1 };
  for (const [type, count] of Object.entries(counts)) {
    const shape = siteObjectShape(type);
    assert.equal(shape.meshes.length, count);
    assert.ok(shape.title.length > 0);
    for (const part of shape.meshes) {
      assert.ok(part.vertices.length > 0 && part.vertices.length < 5000);
      assert.equal(part.vertices.length, part.normals.length);
      assert.equal(part.indices.length % 3, 0);
      assert.ok(part.indices.every(index => Number.isInteger(index) && index >= 0 && index < part.vertices.length));
      assert.ok(part.vertices.every(point => Object.values(point).every(value => Number.isFinite(value) && Math.abs(value) < 2)));
      assert.ok(part.normals.every(point => Math.abs(Math.hypot(point.x, point.y, point.z) - 1) < 1e-8));
    }
  }
  const ring = siteObjectShape('城址').meshes[0];
  assert.ok(ring.vertices.every(point => Math.hypot(point.x, point.z) >= 0.5));
  const mound = siteObjectShape('墓葬群').meshes[0];
  assert.ok(mound.vertices.every(point => point.y >= -0.24));
});

test('object polygon faces have nondegenerate winding and agree with GPU triangle indices', () => {
  for (const type of ['聚落遗址', '都城遗址', '城址', '古建筑', '墓葬群', '窑址']) {
    for (const part of siteObjectShape(type).meshes) {
      const triangles = [];
      for (const face of part.faces) {
        assert.ok(face.indices.length >= 3);
        const points = face.indices.map(index => part.vertices[index]);
        const light = objectFaceLight(points);
        assert.ok(Math.abs(Math.hypot(...Object.values(light.normal)) - 1) < 1e-8, `${type}/${part.name}`);
        for (let i = 1; i < face.indices.length - 1; i++) triangles.push(face.indices[0], face.indices[i], face.indices[i + 1]);
      }
      assert.deepEqual(triangles, part.indices);
    }
  }
});

test('Lambert lighting separates terrace top front side and unlit faces', () => {
  const origin = { x: 0, y: 0, z: 0 };
  const x = { x: 1, y: 0, z: 0 }, y = { x: 0, y: 1, z: 0 }, z = { x: 0, y: 0, z: 1 };
  const top = objectFaceLight([origin, z, x]);
  const front = objectFaceLight([origin, x, y]);
  const side = objectFaceLight([origin, y, z]);
  const back = objectFaceLight([origin, y, x]);
  assert.ok(top.brightness > front.brightness && front.brightness > side.brightness);
  assert.equal(back.brightness, 0.3);
  assert.equal(back.specular, 0);
  const turned = objectFaceLight([origin, x, y].map(point => rotateObjectPoint(point, Math.PI, 0)));
  assert.ok(turned.brightness < front.brightness);
});

test('directional gloss peaks toward the specified highlight and remains bounded', () => {
  const length = Math.hypot(0.4, 0.8, 1);
  const normal = { x: 0.4 / length, y: 0.8 / length, z: 1 / length };
  const edge = { x: normal.y, y: -normal.x, z: 0 };
  const other = { x: -normal.z * edge.y, y: normal.z * edge.x, z: normal.x * edge.y - normal.y * edge.x };
  const origin = { x: 0, y: 0, z: 0 };
  const peak = objectFaceLight([origin, edge, other]);
  assert.ok(Math.abs(peak.specular - 0.28) < 1e-8);
  const away = objectFaceLight([origin, edge, other].map(point => rotateObjectPoint(point, Math.PI / 2, 0)));
  assert.ok(away.specular < peak.specular / 10);
  assert.ok(peak.brightness <= 0.85 && peak.brightness >= 0.3);
});

test('pottery has three continuous twenty-four-sector bands without coplanar overlay faces', () => {
  const part = siteObjectShape('聚落遗址').meshes[0];
  const bands = part.faces.filter(face => face.tone < 1);
  assert.equal(bands.length, 3 * 24);
  const levels = new Set(bands.map(face => Math.min(...face.indices.map(index => part.vertices[index].y)).toFixed(8)));
  assert.equal(levels.size, 3);
  const signatures = part.faces.map(face => face.indices.map(index => Object.values(part.vertices[index]).map(v => v.toFixed(8)).join(',')).sort().join('|'));
  assert.equal(new Set(signatures).size, part.faces.length);
});

test('city wall has outward outer walls inward inner walls and a horizontal crown', () => {
  const part = siteObjectShape('城址').meshes[0];
  const counts = { outer: 0, inner: 0, top: 0, bottom: 0 };
  for (const face of part.faces) {
    const points = face.indices.map(index => part.vertices[index]);
    const { normal } = objectFaceLight(points);
    if (normal.y > 0.9) counts.top++;
    else if (normal.y < -0.9) counts.bottom++;
    else {
      const radial = normal.x * points[0].x + normal.z * points[0].z;
      counts[radial > 0 ? 'outer' : 'inner']++;
    }
  }
  assert.deepEqual(counts, { outer: 24, inner: 24, top: 24, bottom: 24 });
});

test('chamfered terrace faces point outward and supply the same hard normals to GPU', () => {
  for (const mesh of siteObjectShape('都城遗址').meshes) {
    const centerY = (Math.min(...mesh.vertices.map(p => p.y)) + Math.max(...mesh.vertices.map(p => p.y))) / 2;
    for (const face of mesh.faces) {
      const points = face.indices.map(i => mesh.vertices[i]);
      const normal = objectFaceLight(points).normal;
      const center = points.reduce((sum, p) => ({ x: sum.x + p.x / points.length,
        y: sum.y + (p.y - centerY) / points.length, z: sum.z + p.z / points.length }), { x: 0, y: 0, z: 0 });
      assert.ok(normal.x * center.x + normal.y * center.y + normal.z * center.z > 0);
      assert.ok(face.indices.every(index => Math.hypot(mesh.normals[index].x - normal.x,
        mesh.normals[index].y - normal.y, mesh.normals[index].z - normal.z) < 1e-8));
    }
  }
});

test('object raster culls backfaces and keeps all five shapes inside rotated viewports', () => {
  for (const site of HERITAGE_SITES) {
    const shape = siteObjectShape(site.type);
    for (const width of [160, 330]) for (const pitch of [-0.65, 0.22, 0.65]) {
      for (let step = 0; step < 16; step++) {
        const frame = objectRasterFrame(shape, site.accent, width, 210, step * Math.PI / 8, pitch);
        assert.ok(frame.faces.length > 0 && frame.culledFaces > 0);
        assert.equal(frame.totalFaces, frame.faces.length + frame.culledFaces);
        for (const [index, face] of frame.faces.entries()) {
          assert.ok(face.points.every(point => Number.isFinite(point.x + point.y) && point.x >= 11.99 && point.x <= width - 11.99 && point.y >= 15.99 && point.y <= 180.01));
          assert.ok(face.light.brightness >= 0.3 && face.light.brightness <= 0.85 + 1e-8);
          if (index > 0) assert.ok(face.depth >= frame.faces[index - 1].depth);
        }
        assert.ok(frame.shadowY <= 198 && frame.shadowRadius > 0);
      }
    }
  }
  assert.equal(objectRasterFrame(siteObjectShape('城址'), '#677448', 0, 210, 0, 0).faces.length, 0);
});

test('graph edges have real reasons, no duplicates and all selected connections', () => {
  const graph = cultureGraphData(HERITAGE_SITES, 'ly-erlitou');
  assert.equal(graph.nodes.length, HERITAGE_SITES.length);
  assert.equal(new Set(graph.edges.map(edge => [edge.source, edge.target].sort().join('|'))).size, graph.edges.length);
  for (const edge of graph.edges) {
    const left = HERITAGE_SITES.find(site => site.id === edge.source);
    const right = HERITAGE_SITES.find(site => site.id === edge.target);
    assert.ok(left && right && left.id !== right.id);
    assert.ok(edge.reasons.length > 0);
    assert.ok(edge.reasons.every(reason => connectionReasons(left, right).includes(reason)));
  }
  for (const link of cultureConnections(HERITAGE_SITES, 'ly-erlitou')) {
    assert.ok(graph.edges.some(edge => [edge.source, edge.target].includes('ly-erlitou') &&
      [edge.source, edge.target].includes(link.site.id)));
  }
});

test('personal graph has only known live nodes and handles an absent selection', () => {
  const records = [record(), record({ id: 'favorite:zz-shang', kind: 'favorite', siteId: 'zz-shang' }),
    record({ id: 'note:deleted', siteId: 'kf-iron-pagoda', deleted: true })];
  const sites = personalCultureSites(HERITAGE_SITES, records);
  const graph = cultureGraphData(sites, 'smx-yangshao', records);
  assert.deepEqual(graph.nodes.map(node => node.id), ['ly-erlitou', 'zz-shang']);
  assert.equal(graph.selectedId, 'ly-erlitou');
  assert.equal(graph.edges.length, 1);
  assert.deepEqual(cultureGraphData([], 'missing'), { nodes: [], edges: [], selectedId: '' });
});

test('force layout settles expanded nodes inside narrow and large-text viewports', () => {
  for (const [width, height, scale] of [[328, 448, 1], [328, 658, 1.5], [600, 364, 1]]) {
    const layout = new GraphLayout(width, height);
    layout.setData(cultureGraphData(HERITAGE_SITES, 'ly-erlitou'), scale);
    layout.settle();
    for (const node of layout.nodes) {
      assert.ok(Number.isFinite(node.x) && Number.isFinite(node.y));
      assert.ok(node.x >= layout.nodeWidth / 2 + 4 && node.x <= width - layout.nodeWidth / 2 - 4);
      assert.ok(node.y >= 22 && node.y <= height - 42 * scale);
      assert.equal(node.vx, 0); assert.equal(node.vy, 0);
    }
    for (let left = 0; left < layout.nodes.length; left++) {
      for (let right = left + 1; right < layout.nodes.length; right++) {
        const a = layout.nodes[left], b = layout.nodes[right];
        assert.ok(Math.abs(a.x - b.x) >= layout.nodeWidth - 8 || Math.abs(a.y - b.y) >= 52 * scale,
          `${width}/${scale}: overlapping ${a.id}, ${b.id}`);
      }
    }
  }
});

// 将本轮新增的进度与离线引擎规则纳入现有统一测试入口，不绕过已要求的 tools/test.ps1。
await import('./cultural-content.test.mjs');
await import('../entry/src/main/resources/rawfile/engine/engine.test.cjs');

const nativeSceneSource = readFileSync(new URL('../entry/src/main/ets/domain/CulturalNativeScene.ts', import.meta.url), 'utf8')
  .replace("from './SiteObjectGeometry'", `from '${new URL('../entry/src/main/ets/domain/SiteObjectGeometry.ts', import.meta.url).href}'`);
const { nativeCulturalScene } = await import(`data:text/javascript,${encodeURIComponent(stripTypeScriptTypes(nativeSceneSource))}`);

test('native fallback creates a visible river with five valid city selection anchors', () => {
  const scene = nativeCulturalScene('river_sandbox', { version: 1,
    nodes: CITIES.slice(1).map(city => ({ id: city, label: city })) });
  assert.equal(scene.anchors.length, 5);
  assert.deepEqual(scene.anchors.map(anchor => anchor.id), CITIES.slice(1));
  assert.ok(scene.anchors.every((anchor, index) => index === 0 || anchor.point.x > scene.anchors[index - 1].point.x));
  const frame = objectRasterFrame(scene.shape, '#C88A4B', 330, 260, 0.25, 0.3);
  assert.ok(frame.faces.length > 50 && new Set(frame.faces.map(face => face.color)).size > 5);
});

test('native learning slices expose four explicit themes and keep selection separate from progress', () => {
  const layers = ['overview', 'archaeology', 'history', 'poetry-travel'].map(id => ({ id, label: id }));
  const scene = nativeCulturalScene('stratum_slice', { version: 1, layers, selectedId: 'history' });
  assert.equal(scene.anchors.length, 4);
  assert.equal(scene.anchors[2].id, 'history');
  assert.ok(scene.shape.meshes.some(mesh => mesh.name === 'history' && mesh.opacity === 1));
  const frame = objectRasterFrame(scene.shape, '#C88A4B', 330, 300, 0.25, 0.3);
  assert.ok(frame.faces.length > 0);
  assert.ok(frame.faces.every(face => face.opacity > 0 && face.opacity <= 1));
});

test('native procedural presets preserve distinct silhouettes and bounded finite geometry', () => {
  const presets = ['yangshao_pottery', 'erlitou_bronze', 'duling_fangding', 'kaifeng_pagoda', 'xishuipo_site'];
  const signatures = presets.map(proceduralPreset => {
    const scene = nativeCulturalScene('relic_inspector', { version: 1, proceduralPreset });
    assert.equal(scene.anchors.length, 3);
    assert.ok(scene.shape.meshes.every(mesh => mesh.vertices.every(point => Object.values(point).every(Number.isFinite))));
    const frame = objectRasterFrame(scene.shape, '#C88A4B', 330, 300, 0.25, 0.3);
    assert.ok(frame.faces.length > 0);
    return scene.shape.meshes.map(mesh => mesh.vertices.length).join(',');
  });
  assert.equal(new Set(signatures).size, presets.length);
});

test('force layout preserves existing nodes and bounds drag and resize', () => {
  const layout = new GraphLayout(328, 448);
  layout.setData(cultureGraphData(HERITAGE_SITES, 'ly-erlitou'));
  layout.settle();
  const before = layout.nodes.find(node => node.id === 'ly-erlitou');
  const position = [before.x, before.y];
  layout.setData(cultureGraphData(HERITAGE_SITES, 'zz-shang'));
  const after = layout.nodes.find(node => node.id === 'ly-erlitou');
  assert.deepEqual([after.x, after.y], position);
  layout.drag('ly-erlitou', -1000, 10000, true);
  assert.ok(after.x >= 44 && after.y <= 406);
  layout.resize(600, 364); layout.settle();
  assert.ok(layout.nodes.every(node => Number.isFinite(node.x) && node.x <= 556 && node.y <= 322));
});

test('personal graph derives only from live known favorites and notes', () => {
  const records = [record(), record({ id: 'favorite:a', kind: 'favorite', siteId: 'ly-erlitou' }),
    record({ id: 'note:b', siteId: 'kf-iron-pagoda' }),
    record({ id: 'note:c', siteId: 'smx-yangshao', deleted: true }),
    record({ id: 'note:d', siteId: 'not-in-catalog' })];
  assert.deepEqual(personalCultureSites(HERITAGE_SITES, records).map(s => s.id), ['ly-erlitou', 'kf-iron-pagoda']);
});

test('custom note topic creates a real personal connection and removes with deleted note', () => {
  const records = [record({ siteId: 'smx-yangshao', tags: ['我的专题'] }),
    record({ id: 'note:b', siteId: 'kf-iron-pagoda', tags: ['我的专题'] })];
  assert.deepEqual(cultureTopics(records), ['我的专题']);
  assert.equal(personalCultureSites(HERITAGE_SITES, records, '我的专题').length, 2);
  assert.deepEqual(connectionReasons(HERITAGE_SITES[0], HERITAGE_SITES[3], records), ['我的专题：我的专题']);
  records[1].deleted = true;
  assert.deepEqual(connectionReasons(HERITAGE_SITES[0], HERITAGE_SITES[3], records), []);
  assert.equal(personalCultureSites(HERITAGE_SITES, records, '我的专题').length, 1);
});
