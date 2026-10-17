import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { HERITAGE_SITES } from '../entry/src/main/ets/data/HeritageCatalog.ts';
import { encodeExplorationProgressRecord } from '../entry/src/main/ets/domain/ExplorationProgress.ts';

// ArkTS 使用无扩展名的相对导入；测试仅把路径换成真实 TS 文件 URL，执行同一领域源码。
let source = readFileSync(new URL('../entry/src/main/ets/domain/JourneyRoutes.ts', import.meta.url), 'utf8');
for (const name of ['ArchiveDomain', 'ExplorationProgress', 'MemoryJournal']) {
  source = source.replaceAll(`'./${name}'`, `'${new URL(`../entry/src/main/ets/domain/${name}.ts`, import.meta.url).href}'`);
}
const { JOURNEY_ROUTES, journeyForId, journeyProgress, unlockedJourneySiteIds } =
  await import(`data:text/javascript,${encodeURIComponent(stripTypeScriptTypes(source))}`);

const postcard = (siteId, patch = {}) => ({
  id: `note:journey-${siteId}`, kind: 'note', siteId, body: '沿着线索留下一页记忆',
  tags: [], updatedAt: 1, deviceId: 'journey-test', deleted: false, stampType: '河洛拾遗', ...patch
});
const sections = (siteId, count) => ['overview', 'archaeology', 'history', 'poetry-travel']
  .slice(0, count).map((sectionId, index) => encodeExplorationProgressRecord(siteId, sectionId, index + 1, 'journey-test'));

test('three reading journeys refer only to current catalog IDs and retain their themed order', () => {
  const ids = new Set(HERITAGE_SITES.map((site) => site.id));
  assert.equal(JOURNEY_ROUTES.length, 3);
  assert.deepEqual(JOURNEY_ROUTES.map((route) => route.title), ['寻夏记', '泥火成器', '折叠的都城']);
  for (const route of JOURNEY_ROUTES) {
    assert.ok(route.siteIds.every((id) => ids.has(id)));
    assert.equal(new Set(route.siteIds).size, route.siteIds.length);
    assert.equal(journeyForId(route.id), route);
  }
  assert.deepEqual(JOURNEY_ROUTES[1].siteIds, ['smx-miaodigou', 'zz-dahecun', 'zz-duling-fangding', 'kf-iron-pagoda']);
  assert.equal(journeyForId('unknown'), undefined);
});

test('nodes require at least 75 percent exploration or an active supported postcard', () => {
  const route = JOURNEY_ROUTES[0]; const siteId = route.siteIds[0];
  const ordinary = postcard(siteId, { stampType: undefined });
  assert.equal(journeyProgress([ordinary], route).completedCount, 0);
  assert.equal(journeyProgress(sections(siteId, 2), route).completedCount, 0);
  const explored = journeyProgress(sections(siteId, 3), route);
  assert.deepEqual(explored.completedSiteIds, [siteId]);
  assert.equal(explored.nextSiteId, route.siteIds[1]);
  assert.equal(explored.percent, 20);
  assert.equal(journeyProgress([postcard(siteId)], route).completedCount, 1);
  assert.equal(journeyProgress([postcard(siteId, { deleted: true })], route).completedCount, 0);
});

test('route badges and graph nodes derive from complete live records and retract after a tombstone', () => {
  const route = JOURNEY_ROUTES[0];
  const records = route.siteIds.map((id) => postcard(id));
  const complete = journeyProgress(records, route);
  assert.equal(complete.unlocked, true);
  assert.equal(complete.percent, 100);
  assert.equal(complete.nextSiteId, '');
  assert.deepEqual(unlockedJourneySiteIds(records), route.siteIds);
  const deleted = { ...records[0], updatedAt: 2, deleted: true };
  const afterDelete = journeyProgress([...records, deleted], route);
  assert.equal(afterDelete.unlocked, false);
  assert.equal(afterDelete.completedCount, 4);
  assert.equal(afterDelete.nextSiteId, route.siteIds[0]);
  assert.deepEqual(unlockedJourneySiteIds([...records, deleted]), []);
});

test('completed journeys share nodes without duplicating graph unlocks', () => {
  const siteIds = [...new Set(JOURNEY_ROUTES.flatMap((route) => route.siteIds))];
  const unlocked = unlockedJourneySiteIds(siteIds.map((id) => postcard(id)));
  assert.deepEqual(unlocked, siteIds);
  assert.equal(new Set(unlocked).size, unlocked.length);
});
