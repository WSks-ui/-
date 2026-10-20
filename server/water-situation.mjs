import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

// 数据源：水利部黄河水利委员会“黄河实时水情”公开页面。
// 该地址来自公开页面与社区项目 Daily-Yellow-River-Information-Download 的字段说明（仅作参考，
// 不复用其代码）。页面是 IP + 明文 HTTP + ASP.NET 表单，2024 年改版后只稳定提供当天表格；
// 因此抓取、解析与缓存全部留在服务端，App 只读自有 HTTPS 接口，断网时回退到上次快照。
// 地址可能随官网调整；可用 YRCC_WATER_URL 覆盖，不要把抓取放进 HAP。
const PUBLIC_URL = 'http://61.163.88.227:8006/hwsq2.aspx?sr=0nkRxv6s9CTRMlwRgmfFF6jTpJPtAv87';
const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/126.0 Safari/537.36';
const CACHE_FRESH_MS = 10 * 60 * 1000;

function chinaToday(now) {
  return new Date(now + 8 * 3600 * 1000).toISOString().slice(0, 10);
}

function decodeEntities(value) {
  return value
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#(\d+);/g, (_match, code) => String.fromCharCode(Number(code)))
    .replace(/&#x([0-9a-f]+);/gi, (_match, code) => String.fromCharCode(parseInt(code, 16)));
}

function cellText(value) {
  return decodeEntities(value.replace(/<[^>]*>/g, ' ')).replace(/\s+/g, ' ').trim();
}

function parseNumber(value) {
  const text = (value || '').replace(/,/g, '').trim();
  if (!text || text === '-' || text === '--') return null;
  const number = Number(text);
  return Number.isFinite(number) ? number : null;
}

// 页面表头为“河名 / 站名 / 时间 / 水位 / 流量”，当前页面不提供含沙量。
// 只接受 5 列且时间形如 “10-20 08:00” 的数据行，避免把导航表或控件表误当水情。
export function parseWaterHtml(html, pageDate) {
  const rows = [];
  for (const rowMatch of html.matchAll(/<tr\b[^>]*>([\s\S]*?)<\/tr>/gi)) {
    const cells = [...rowMatch[1].matchAll(/<t[dh]\b[^>]*>([\s\S]*?)<\/t[dh]>/gi)]
      .map(match => cellText(match[1]));
    if (cells.length < 5) continue;
    const [river, station, time, level, flow] = cells;
    if (!river || !station || river === '河名' || station === '站名') continue;
    const timeMatch = /^(\d{1,2})-(\d{1,2})\s+(\d{1,2}):(\d{2})$/.exec(time);
    if (!timeMatch) continue;
    const date = pageDate || chinaToday(Date.now());
    const observedAt = `${date} ${timeMatch[3].padStart(2, '0')}:${timeMatch[4]}`;
    rows.push({
      river, station, observedAt,
      waterLevelM: parseNumber(level), flowM3s: parseNumber(flow), sedimentKgM3: null
    });
  }
  if (!rows.length) throw new Error('WATER_PARSE_EMPTY');
  if (!rows.some(row => row.station === '花园口')) throw new Error('WATER_PARSE_NO_HUAYUANKOU');
  return rows;
}

export function extractPageDate(html) {
  const input = html.match(/<input[^>]*TextBox11[^>]*>/i)?.[0] || '';
  return input.match(/value="(20\d{2}-\d{2}-\d{2})"/i)?.[1] ||
    html.match(/value="(20\d{2}-\d{2}-\d{2})"/)?.[1] || '';
}

// 页面首次请求会 302 到 default.aspx 并种下会话 Cookie，再跳回 hwsq2；
// 手动跟随并保留 Cookie，避免 Node fetch 自动重定向时丢掉会话。
export async function fetchWaterHtml(url, fetchImpl = fetch) {
  let current = url;
  let cookie = '';
  for (let hop = 0; hop < 5; hop += 1) {
    const response = await fetchImpl(current, {
      redirect: 'manual',
      headers: {
        'User-Agent': USER_AGENT,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        ...(cookie ? { Cookie: cookie } : {})
      },
      signal: AbortSignal.timeout(10000)
    });
    const setCookie = response.headers.getSetCookie?.()[0] || response.headers.get('set-cookie') || '';
    if (setCookie) cookie = setCookie.split(';')[0];
    const location = response.headers.get('location');
    if (response.status >= 300 && response.status < 400 && location) {
      current = new URL(location, current).toString();
      continue;
    }
    if (!response.ok) throw new Error(`WATER_HTTP_${response.status}`);
    return await response.text();
  }
  throw new Error('WATER_REDIRECT_LOOP');
}

export function createWaterSituationService({
  cacheDir, url = process.env.YRCC_WATER_URL || PUBLIC_URL, fetchImpl = fetch, now = Date.now
} = {}) {
  const cachePath = cacheDir ? join(cacheDir, 'snapshot.json') : '';
  let cached = null;
  let loaded = false;

  async function loadCache() {
    if (loaded || !cachePath) return;
    loaded = true;
    try {
      cached = JSON.parse(await readFile(cachePath, 'utf8'));
    } catch { cached = null; }
  }

  function staleOf(reply) {
    return reply.observedAt.slice(0, 10) !== chinaToday(now());
  }

  async function snapshot() {
    await loadCache();
    if (cached && now() - Date.parse(cached.fetchedAt) < CACHE_FRESH_MS) {
      return { ...cached, stale: staleOf(cached) };
    }
    try {
      const html = await fetchWaterHtml(url, fetchImpl);
      const rows = parseWaterHtml(html, extractPageDate(html));
      const reply = {
        source: '黄河实时水情', sourceUrl: url,
        fetchedAt: new Date(now()).toISOString(),
        observedAt: rows[0].observedAt, stale: false, stations: rows, error: null
      };
      reply.stale = staleOf(reply);
      cached = reply;
      if (cachePath) {
        await mkdir(cacheDir, { recursive: true });
        await writeFile(cachePath, JSON.stringify(reply, null, 2), 'utf8');
      }
      return reply;
    } catch {
      if (cached) return { ...cached, stale: true, error: 'WATER_FETCH_FAILED' };
      return {
        source: '黄河实时水情', sourceUrl: url, fetchedAt: new Date(now()).toISOString(),
        observedAt: '', stale: true, stations: [], error: 'WATER_UNAVAILABLE'
      };
    }
  }

  return { snapshot, describe: () => ({ configured: Boolean(url), hasCache: Boolean(cached) }) };
}
