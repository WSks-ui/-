import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createWaterSituationService, extractPageDate, parseWaterHtml } from './water-situation.mjs';

const HTML = `<!DOCTYPE html><html><head><meta charset="UTF-8"></head><body>
<input name="ctl00$ContentLeft$menuDate1$TextBox11" value="2026-10-20" />
<table>
<tr><td>河名</td><td>站名</td><td>时间</td><td>水位</td><td>流量</td></tr>
<tr><td>黄河</td><td>花园口</td><td>10-20 08:00</td><td>88.94</td><td>911</td></tr>
<tr><td>黄河</td><td>高村</td><td>10-20 08:00</td><td>57.38</td><td>816</td></tr>
<tr><td>黄河</td><td>三门峡水库</td><td>10-20 08:00</td><td>311.93</td><td>-</td></tr>
</table></body></html>`;

function responseOf(body, status = 200, headers = {}) {
  return {
    status, ok: status >= 200 && status < 300,
    headers: {
      get: name => headers[name.toLowerCase()] || null,
      getSetCookie: () => []
    },
    text: async () => body
  };
}

test('water parser reads five columns, keeps missing flow null and joins page date', () => {
  assert.equal(extractPageDate(HTML), '2026-10-20');
  const rows = parseWaterHtml(HTML, '2026-10-20');
  assert.equal(rows.length, 3);
  assert.deepEqual(rows[0], {
    river: '黄河', station: '花园口', observedAt: '2026-10-20 08:00',
    waterLevelM: 88.94, flowM3s: 911, sedimentKgM3: null
  });
  assert.equal(rows[2].flowM3s, null);
  assert.equal(rows[2].sedimentKgM3, null);
});

test('water parser rejects pages without target station', () => {
  assert.throws(() => parseWaterHtml('<table><tr><td>黄河</td><td>兰州</td><td>10-20 08:00</td><td>1</td><td>2</td></tr></table>', '2026-10-20'),
    /WATER_PARSE_NO_HUAYUANKOU/);
});

test('water service caches the last good snapshot and marks it stale after failure', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'yunheji-water-'));
  let fail = false;
  let now = Date.parse('2026-10-20T06:00:00Z');
  const service = createWaterSituationService({
    cacheDir: dir, url: 'http://example.test/water',
    fetchImpl: async () => { if (fail) throw new Error('down'); return responseOf(HTML); },
    now: () => now
  });
  try {
    const first = await service.snapshot();
    assert.equal(first.stale, false);
    assert.equal(first.stations.length, 3);
    assert.equal(first.stations[0].station, '花园口');
    fail = true;
    now += 11 * 60 * 1000;
    const second = await service.snapshot();
    assert.equal(second.stale, true);
    assert.equal(second.error, 'WATER_FETCH_FAILED');
    assert.equal(second.stations[0].flowM3s, 911);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});
