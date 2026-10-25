import { abilityDelegatorRegistry, Component, ON, On, Rect } from '@kit.TestKit';
import { UIAbility } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { describe, expect, it } from '@ohos/hypium';
import { ArchiveRecord, ArchiveSnapshot, parseSnapshot } from '../../../main/ets/domain/ArchiveDomain';
import { PAPER_COLUMNS, PAPER_ROWS, createPaperWork } from '../../../main/ets/domain/PaperJourney';
import { paperWorkFromRecords, paperWorkRecordId } from '../../../main/ets/domain/PaperJourneyRecords';
import { LocalArchiveRepository } from '../../../main/ets/data/LocalArchiveRepository';
import { ArchiveUiSession } from './ArchiveUiSession';

const CITY_ID: string = 'paper-kf';
interface LightPixels { width: number; height: number; rgba: Uint8Array; path: string; }
interface LightScenePoint { x: number; y: number; }

// 只启动正式 EntryAbility 的独立游客库。作品必须由真实剪切产生；此类只读磁盘，
// 不调用领域剪切/页面方法，不预填 progress，不把屏幕上“移光”文字当作功能证据。
class PaperLightUiSession extends ArchiveUiSession {
  private paperAbility: UIAbility | undefined = undefined;

  constructor() { super('paper_light'); }

  async start(_resumeAccount: boolean = false): Promise<void> {
    await abilityDelegatorRegistry.getAbilityDelegator().startAbility({ bundleName: 'com.yunheji.archive',
      abilityName: 'EntryAbility', parameters: { yunhejiTestStore: this.name } });
    await this.waitId('paper-journey-home');
    this.paperAbility = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility();
    expect(this.paperAbility.context.abilityInfo.name).assertEqual('EntryAbility');
    this.context = this.paperAbility.context;
    expect(!await this.driver.findComponent(ON.id('login-scroll'))).assertTrue();
    console.info(`PAPER_LIGHT_STORE:${this.name}`);
  }

  async stop(): Promise<void> {
    if (!this.paperAbility) return;
    await this.paperAbility.context.terminateSelf(); this.paperAbility = undefined;
    await this.wait(ON.text('设备回归准备中'));
  }

  async raw(): Promise<string> {
    await preferences.removePreferencesFromCache(this.context, this.name);
    const store = await preferences.getPreferences(this.context, { name: this.name });
    expect(await store.has('snapshot')).assertTrue();
    return await store.get('snapshot', '') as string;
  }

  async read(): Promise<ArchiveSnapshot> {
    const raw = await this.raw();
    const disk = await new LocalArchiveRepository(this.context, this.name).load();
    expect(JSON.stringify(parseSnapshot(raw))).assertEqual(JSON.stringify(disk));
    return disk;
  }

  async run(action: () => Promise<void>, _preserveStore: boolean = false): Promise<void> {
    let failed = false;
    try { await this.start(); await action(); }
    catch (error) {
      failed = true;
      const original = error as Error;
      console.error(`PAPER_LIGHT_ERROR_STACK:${original.stack || original.message}`);
      try {
        const path = `${this.context.cacheDir}/paper-light-${this.name}-failure.png`;
        console.info(`PAPER_LIGHT_FAILURE_CAPTURE:${path}:${await this.driver.screenCap(path)}`);
        await abilityDelegatorRegistry.getAbilityDelegator().executeShellCommand(
          'uitest dumpLayout -p /data/local/tmp/paper-light-failure.json -b com.yunheji.archive');
      } catch (diagnostic) { console.error(`PAPER_LIGHT_DIAGNOSTIC_ERROR:${(diagnostic as Error).stack}`); }
      // 不再 new Error(message)：保留原 UiTest/像素断言的 error stack，清理错误另行记录。
      throw original;
    } finally {
      try { await this.dispose(); }
      catch (cleanup) {
        if (!failed) throw cleanup as Error;
        console.error(`PAPER_LIGHT_CLEANUP_ERROR_STACK:${(cleanup as Error).stack}`);
      }
    }
  }
}

async function homeTarget(session: PaperLightUiSession, id: string): Promise<Component> {
  const target = ON.id(id);
  for (let attempt = 0; attempt < 12; attempt++) {
    if (!await session.driver.findComponent(target)) {
      await (await session.waitId('paper-journey-home')).scrollSearch(target, true, 100);
      continue;
    }
    // 每次 wait/scroll 后重新定位，不持有先前 Scroll 或 Component 跨页面重建使用。
    const bounds = await (await session.wait(target, '纸景首页实际入口')).getBounds();
    const viewport = await (await session.waitId('paper-journey-home')).getBounds();
    const header = await (await session.waitId('top-navigation-content')).getBounds();
    const dock = await (await session.waitId('tab-0')).getBounds();
    const top = Math.max(viewport.top, header.bottom) + 18;
    const bottom = Math.min(viewport.bottom, dock.top) - 18;
    const center = (bounds.top + bounds.bottom) * 0.5;
    if (bounds.bottom > bounds.top && center >= top && center <= bottom) return session.wait(target);
    const lower = center > bottom;
    const start = lower ? bottom - 30 : top + 30;
    const distance = Math.min((bottom - top) * 0.4, Math.max(100, lower ? center - bottom + 50 : top - center + 50));
    await session.driver.swipe(Math.round(viewport.left + 10), Math.round(start),
      Math.round(viewport.left + 10), Math.round(start + (lower ? -distance : distance)), 600);
  }
  throw new Error(`PAPER_LIGHT_HOME_TARGET_COVERED:${id}`);
}

async function sceneBounds(session: PaperLightUiSession): Promise<Rect> {
  const canvas = await session.wait(ON.id('paper-journey-scene').within(ON.id('paper-play-scene')),
    '当前可操作Canvas');
  const bounds = await canvas.getBounds();
  expect(bounds.right > bounds.left && bounds.bottom > bounds.top).assertTrue();
  return bounds;
}

function scenePoint(bounds: Rect, x: number, y: number): LightScenePoint {
  const width = bounds.right - bounds.left; const height = bounds.bottom - bounds.top;
  const unit = Math.min(width / 1000, height / 1200);
  return { x: Math.round(bounds.left + (width - 1000 * unit) / 2 + x * unit),
    y: Math.round(bounds.top + (height - 1200 * unit) / 2 + y * unit) };
}

async function panScene(session: PaperLightUiSession, x1: number, y1: number,
  x2: number, y2: number): Promise<void> {
  // UiTest getBounds/swipe 都使用 px。由当前Canvas contain映射，不以整屏分辨率推算。
  const bounds = await sceneBounds(session);
  const start = scenePoint(bounds, x1, y1); const end = scenePoint(bounds, x2, y2);
  console.info(`PAPER_LIGHT_REAL_PAN:${JSON.stringify({ bounds, start, end })}`);
  await session.driver.swipe(start.x, start.y, end.x, end.y, 350);
}

async function cut(session: PaperLightUiSession, col1: number, row: number, col2: number): Promise<void> {
  await panScene(session, 110 + (col1 + 0.5) / PAPER_COLUMNS * 780,
    105 + (row + 0.5) / PAPER_ROWS * 936, 110 + (col2 + 0.5) / PAPER_COLUMNS * 780,
    105 + (row + 0.5) / PAPER_ROWS * 936);
}

function progress(snapshot: ArchiveSnapshot): ArchiveRecord {
  const record = snapshot.records.find(item => item.id === paperWorkRecordId(CITY_ID) && !item.deleted);
  if (!record || !paperWorkFromRecords(snapshot.records, CITY_ID)) throw new Error('PAPER_LIGHT_WORK_MISSING');
  return record;
}

async function waitMaskChange(session: PaperLightUiSession, before: string): Promise<ArchiveSnapshot> {
  for (let attempt = 0; attempt < 60; attempt++) {
    const snapshot = await session.read(); const work = paperWorkFromRecords(snapshot.records, CITY_ID);
    if (work && work.mask !== before) {
      await session.wait(ON.text('已保存在本机').id('paper-save-state'), '剪口保存回执');
      return session.read();
    }
    await session.driver.delayMs(150);
  }
  throw new Error('PAPER_LIGHT_REAL_CUT_NOT_SAVED');
}

async function screenshot(session: PaperLightUiSession, phase: string): Promise<LightPixels> {
  const path = `${session.context.cacheDir}/paper-light-${session.name}-${phase}.png`;
  // 本机API26 Driver.screenCap保存真实屏幕PNG到本应用沙箱，ImageKit再解码RGBA。
  // 截图只含独立游客纸景，不进入账号页；原PNG保留在cache供主机取证，不拿PNG字节头充像素。
  expect(await session.driver.screenCap(path)).assertTrue();
  const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
  const source = image.createImageSource(file.fd); let pixelMap: image.PixelMap | undefined = undefined;
  try {
    const info = await source.getImageInfo(); expect(info.mimeType).assertEqual('image/png');
    pixelMap = await source.createPixelMap({ desiredPixelFormat: image.PixelMapFormat.RGBA_8888 });
    const buffer = new ArrayBuffer(pixelMap.getPixelBytesNumber());
    expect(buffer.byteLength).assertEqual(info.size.width * info.size.height * 4);
    await pixelMap.readPixelsToBuffer(buffer);
    console.info(`PAPER_LIGHT_PNG:${JSON.stringify({ phase, path, width: info.size.width, height: info.size.height })}`);
    return { width: info.size.width, height: info.size.height, rgba: new Uint8Array(buffer), path };
  } finally {
    if (pixelMap) await pixelMap.release(); await source.release(); fileIo.closeSync(file);
  }
}

function assertProjectionChanged(left: LightPixels, right: LightPixels, bounds: Rect): void {
  expect(left.width).assertEqual(right.width); expect(left.height).assertEqual(right.height);
  // 只比纸下承光面1050..1185，不包含状态时钟、按钮文字、移动的光源圆标及其附近光晕。
  // 因而“只换文案/只挪光点、真实mask投影没变”的退化不能让这条断言通过。
  const a = scenePoint(bounds, 150, 1050); const b = scenePoint(bounds, 850, 1185);
  const x0 = Math.max(0, Math.min(left.width - 1, a.x)); const x1 = Math.min(left.width, b.x);
  const y0 = Math.max(0, Math.min(left.height - 1, a.y)); const y1 = Math.min(left.height, b.y);
  const area = Math.max(0, x1 - x0) * Math.max(0, y1 - y0); expect(area > 0).assertTrue();
  let changed = 0;
  for (let y = y0; y < y1; y++) {
    for (let x = x0; x < x1; x++) {
      const i = (y * left.width + x) * 4;
      const difference = Math.abs(left.rgba[i] - right.rgba[i]) +
        Math.abs(left.rgba[i + 1] - right.rgba[i + 1]) + Math.abs(left.rgba[i + 2] - right.rgba[i + 2]);
      if (difference > 18) changed++;
    }
  }
  console.info(`PAPER_LIGHT_PROJECTED_PIXELS:${JSON.stringify({ bounds, x0, y0, x1, y1, area, changed,
    leftPng: left.path, rightPng: right.path })}`);
  expect(changed > Math.max(40, Math.floor(area * 0.003))).assertTrue();
}

export default function paperLightTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requested = parameters['class'] || parameters['-s class'] || '';
  if (!requested.includes('PaperLightTest')) return;
  describe('PaperLightTest', () => {
    it('native_light_pan_changes_mask_projection_without_editing_work_then_cut_resumes', 0, async () => {
      const session = new PaperLightUiSession();
      await session.run(async () => {
        expect((await session.read()).records.length).assertEqual(0);
        await (await session.waitId('paper-journey-home')).scrollToTop(2000);
        await (await homeTarget(session, `paper-home-city-${CITY_ID}`)).click();
        await (await homeTarget(session, 'paper-home-start')).click();
        await session.waitId('paper-journey-page');
        expect(paperWorkFromRecords((await session.read()).records, CITY_ID) === undefined).assertTrue();
        await cut(session, 9, 12, 15);
        const first = await waitMaskChange(session, createPaperWork(CITY_ID, 0).mask);
        const firstWork = paperWorkFromRecords(first.records, CITY_ID);
        if (!firstWork) throw new Error('PAPER_LIGHT_FIRST_CUT_MISSING');
        await cut(session, 25, 32, 31);
        await waitMaskChange(session, firstWork.mask);
        const rawBefore = await session.raw(); const snapshotBefore = parseSnapshot(rawBefore);
        const recordBefore = progress(snapshotBefore); const bodyBefore = recordBefore.body;
        const workBefore = paperWorkFromRecords(snapshotBefore.records, CITY_ID);
        if (!workBefore) throw new Error('PAPER_LIGHT_BASELINE_MISSING');
        expect(workBefore.history.length).assertEqual(2); expect(workBefore.light).assertFalse();
        // 每次正式提交同时保存作品和最近城市位置，不能把位置记录误报成额外作品。
        expect(snapshotBefore.records.length).assertEqual(2);
        expect(snapshotBefore.records.filter(record => record.id === 'progress:paper-position:v1').length).assertEqual(1);

        await (await session.waitId('paper-observe-light')).click();
        expect(await (await session.waitId('paper-observe-light')).getText()).assertEqual('回到剪纸');
        await panScene(session, 500, 350, 250, 350);
        const leftBounds = await sceneBounds(session); const left = await screenshot(session, 'left');
        expect(await session.raw()).assertEqual(rawBefore);
        await panScene(session, 250, 350, 760, 350);
        const rightBounds = await sceneBounds(session); const right = await screenshot(session, 'right');
        expect(JSON.stringify(rightBounds)).assertEqual(JSON.stringify(leftBounds));
        assertProjectionChanged(left, right, rightBounds);
        const rawAfterLight = await session.raw(); const afterLight = parseSnapshot(rawAfterLight);
        const recordAfterLight = progress(afterLight);
        expect(rawAfterLight).assertEqual(rawBefore);
        expect(recordAfterLight.body).assertEqual(bodyBefore);
        expect(recordAfterLight.updatedAt).assertEqual(recordBefore.updatedAt);
        expect(paperWorkFromRecords(afterLight.records, CITY_ID)!.mask).assertEqual(workBefore.mask);
        expect(paperWorkFromRecords(afterLight.records, CITY_ID)!.updatedAt).assertEqual(workBefore.updatedAt);

        await (await session.waitId('paper-observe-light')).click();
        expect(await (await session.waitId('paper-observe-light')).getText()).assertEqual('移光看纸景');
        expect(await session.raw()).assertEqual(rawBefore);
        await cut(session, 18, 23, 23);
        const resumed = await waitMaskChange(session, workBefore.mask);
        const resumedRecord = progress(resumed); const resumedWork = paperWorkFromRecords(resumed.records, CITY_ID)!;
        expect(resumedRecord.body !== bodyBefore).assertTrue();
        expect(resumedRecord.updatedAt > recordBefore.updatedAt).assertTrue();
        expect(resumedWork.mask !== workBefore.mask && resumedWork.updatedAt > workBefore.updatedAt).assertTrue();
        expect(resumedWork.history.length).assertEqual(3); expect(resumedWork.light).assertFalse();
        expect(resumed.records.length).assertEqual(2);
        console.info(`PAPER_LIGHT_RESULT:${JSON.stringify({ rawUnchangedWhileObserving: true,
          bodyUnchanged: true, timestampUnchanged: true, maskUnchanged: true, actualProjectionChanged: true,
          cutResumedAndSaved: true, beforeUpdatedAt: recordBefore.updatedAt, resumedUpdatedAt: resumedRecord.updatedAt })}`);
      });
    });
  });
}
