import { abilityDelegatorRegistry, Component, ON, PointerMatrix, Rect } from '@kit.TestKit';
import { UIAbility } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { describe, expect, it } from '@ohos/hypium';
import { ArchiveRecord, ArchiveSnapshot, activeRecords, parseSnapshot } from '../../../main/ets/domain/ArchiveDomain';
import { PAPER_COLUMNS, PAPER_ROWS, PaperWorkV1, createPaperWork } from '../../../main/ets/domain/PaperJourney';
import { paperWorkFromRecords, paperWorkRecordId } from '../../../main/ets/domain/PaperJourneyRecords';
import { LocalArchiveRepository } from '../../../main/ets/data/LocalArchiveRepository';
import { ArchiveUiSession } from './ArchiveUiSession';

const CITY: string = 'paper-smx';
const PERF_FLAG: string = 'paperScenePerfEnabled';
const CUT_STEPS: number = 48;
const LIGHT_STEPS: number = 64;
interface RiverPerfPoint { x: number; y: number; }

// 只向正式EntryAbility传独立测试库名，作品全部由原生手势产生。
// AppStorage开关请求不等于采集成功；启动Want同时请求由DEBUG入口在目标Ability运行时开启，
// 实际PAPER_SCENE_PERF仍必须由运行方另行收集并确认。
class RiverPaperPerfUiSession extends ArchiveUiSession {
  private paperAbility: UIAbility | undefined = undefined;
  private opened: boolean = false;

  constructor() { super('river_paper_perf'); }

  async start(_resumeAccount: boolean = false): Promise<void> {
    AppStorage.setOrCreate<boolean>(PERF_FLAG, true);
    expect(AppStorage.get<boolean>(PERF_FLAG) === true).assertTrue();
    console.info('RIVER_PAPER_PERF_DEBUG:requested=true;actualSceneTelemetryMustBeCollectedSeparately=true');
    const delegator = abilityDelegatorRegistry.getAbilityDelegator();
    await delegator.startAbility({ bundleName: 'com.yunheji.archive', abilityName: 'EntryAbility',
      parameters: { yunhejiTestStore: this.name, yunhejiPaperPerf: true } });
    await this.waitId('native-dock'); await this.waitId('river-market-home');
    this.paperAbility = await delegator.getCurrentTopAbility();
    expect(this.paperAbility.context.abilityInfo.name).assertEqual('EntryAbility');
    this.context = this.paperAbility.context; this.opened = true;
    expect(!await this.driver.findComponent(ON.id('login-scroll'))).assertTrue();
    console.info(`RIVER_PAPER_PERF_STORE:${this.name}`);
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
      failed = true; const original = error as Error;
      console.error(`RIVER_PAPER_PERF_ERROR:${original.stack || original.message}`);
      throw original;
    } finally {
      try {
        // 先退出场景，让其汇总最后一段统计，再关闭调试；清理只触及本次独立库。
        if (this.opened) await this.dispose(); else await this.stop();
      } catch (cleanup) {
        if (!failed) throw cleanup as Error;
        console.error(`RIVER_PAPER_PERF_CLEANUP_ERROR:${(cleanup as Error).stack}`);
      } finally {
        AppStorage.setOrCreate<boolean>(PERF_FLAG, false);
        console.info(`RIVER_PAPER_PERF_DEBUG:requested=false;testStore=${this.name}`);
      }
    }
  }
}

async function homeTarget(session: RiverPaperPerfUiSession, scrollId: string, id: string): Promise<Component> {
  const target = ON.id(id);
  for (let attempt = 0; attempt < 12; attempt++) {
    if (!await session.driver.findComponent(target)) {
      await (await session.waitId(scrollId)).scrollSearch(target, true, 100); continue;
    }
    const bounds = await (await session.wait(target, '原生纸景入口')).getBounds();
    const viewport = await (await session.waitId(scrollId)).getBounds();
    let top = viewport.top + 18; let bottom = viewport.bottom - 18;
    if (scrollId === 'river-market-home') {
      const header = await (await session.waitId('top-navigation-content')).getBounds();
      const dock = await (await session.waitId('tab-0')).getBounds();
      top = Math.max(top, header.bottom + 18); bottom = Math.min(bottom, dock.top - 18);
    }
    const center = (bounds.top + bounds.bottom) * 0.5;
    if (bounds.bottom > bounds.top && center >= top && center <= bottom) return session.wait(target);
    const lower = center > bottom; const start = lower ? bottom - 30 : top + 30;
    const distance = Math.min((bottom - top) * 0.4,
      Math.max(100, lower ? center - bottom + 50 : top - center + 50));
    await session.driver.swipe(Math.round(viewport.left + 10), Math.round(start),
      Math.round(viewport.left + 10), Math.round(start + (lower ? -distance : distance)), 600);
  }
  throw new Error(`RIVER_PAPER_PERF_HOME_TARGET_COVERED:${id}`);
}

async function openCity(session: RiverPaperPerfUiSession): Promise<void> {
  // 当前首页先走夜市下的真实旧纸景入口；不从Want或页面变量直接切进作品。
  // 新独立库进入纸景默认三门峡，重进保留同一实际已存城市。
  if (!await session.driver.findComponent(ON.id('paper-journey-home'))) {
    await (await session.waitId('river-market-home')).scrollToTop(2000);
    await (await homeTarget(session, 'river-market-home', 'market-home-paper')).click();
    await session.waitId('paper-journey-home');
  }
  await (await session.waitId('paper-journey-home')).scrollToTop(2000);
  await (await homeTarget(session, 'paper-journey-home', 'paper-home-start')).click();
  await session.waitId('paper-journey-page');
}

async function sceneBounds(session: RiverPaperPerfUiSession): Promise<Rect> {
  const scene = await session.wait(ON.id('paper-journey-scene').within(ON.id('paper-play-scene')), '交互纸面');
  const bounds = await scene.getBounds();
  expect(bounds.right > bounds.left && bounds.bottom > bounds.top).assertTrue(); return bounds;
}

function scenePoint(bounds: Rect, x: number, y: number): RiverPerfPoint {
  const width = bounds.right - bounds.left; const height = bounds.bottom - bounds.top;
  const unit = Math.min(width / 1000, height / 1200);
  return { x: Math.round(bounds.left + (width - 1000 * unit) / 2 + x * unit),
    y: Math.round(bounds.top + (height - 1200 * unit) / 2 + y * unit) };
}

async function injectPath(session: RiverPaperPerfUiSession, artPoints: RiverPerfPoint[],
  phase: string, speed: number): Promise<void> {
  // 本机API26 PointerMatrix允许一根手指的多步轨迹；一次注入保持同一按下/抬起周期，
  // 而不是把48个点拆成48次Tap或直接调用页面onStroke。全部屏幕px由当前contain映射获得。
  const bounds = await sceneBounds(session); const matrix = PointerMatrix.create(1, artPoints.length);
  for (let step = 0; step < artPoints.length; step++) {
    matrix.setPoint(0, step, scenePoint(bounds, artPoints[step].x, artPoints[step].y));
  }
  console.info(`RIVER_PAPER_PERF_PATH:${JSON.stringify({ phase, steps: artPoints.length, speed, bounds })}`);
  expect(await session.driver.injectMultiPointerAction(matrix, speed)).assertTrue();
}

function cutPath(row: number, reverse: boolean): RiverPerfPoint[] {
  const points: RiverPerfPoint[] = [];
  for (let step = 0; step < CUT_STEPS; step++) {
    const t = step / (CUT_STEPS - 1); const col = reverse ? 30 - 21 * t : 9 + 21 * t;
    const wavedRow = row + Math.sin(t * Math.PI * 3) * 0.65;
    points.push({ x: 110 + (col + 0.5) / PAPER_COLUMNS * 780,
      y: 105 + (wavedRow + 0.5) / PAPER_ROWS * 936 });
  }
  return points;
}

function lightPath(reverse: boolean): RiverPerfPoint[] {
  const points: RiverPerfPoint[] = [];
  for (let step = 0; step < LIGHT_STEPS; step++) {
    const t = step / (LIGHT_STEPS - 1);
    points.push({ x: reverse ? 780 - 560 * t : 220 + 560 * t,
      y: 400 + Math.sin(t * Math.PI * 2) * 100 });
  }
  return points;
}

function progress(snapshot: ArchiveSnapshot): ArchiveRecord {
  const record = snapshot.records.find(item => item.id === paperWorkRecordId(CITY) && !item.deleted);
  if (!record || !paperWorkFromRecords(snapshot.records, CITY)) throw new Error('RIVER_PAPER_PERF_PROGRESS_MISSING');
  return record;
}

function work(snapshot: ArchiveSnapshot): PaperWorkV1 {
  const current = paperWorkFromRecords(snapshot.records, CITY);
  if (!current) throw new Error('RIVER_PAPER_PERF_WORK_MISSING'); return current;
}

async function waitMaskChange(session: RiverPaperPerfUiSession, before: string): Promise<ArchiveSnapshot> {
  for (let attempt = 0; attempt < 60; attempt++) {
    const snapshot = await session.read(); const current = paperWorkFromRecords(snapshot.records, CITY);
    if (current && current.mask !== before) {
      await session.wait(ON.text('已保存在本机').id('paper-save-state'), '真实剪口落盘回执');
      return session.read();
    }
    await session.driver.delayMs(150);
  }
  throw new Error('RIVER_PAPER_PERF_CUT_NOT_SAVED');
}

export default function riverPaperPerfTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requested = parameters['class'] || parameters['-s class'] || '';
  if (!requested.includes('RiverPaperPerfTest')) return;
  describe('RiverPaperPerfTest', () => {
    it('native_continuous_cut_light_pan_and_resumed_cut_preserve_real_saved_work', 0, async () => {
      const session = new RiverPaperPerfUiSession();
      await session.run(async () => {
        expect((await session.read()).records.length).assertEqual(0);
        await openCity(session);
        expect(paperWorkFromRecords((await session.read()).records, CITY) === undefined).assertTrue();
        let previous = createPaperWork(CITY, 0).mask;
        // 三笔曲线各有48个真实输入位置；逐笔只等保存，曲线内部没有delay、读盘或控件定位。
        for (let stroke = 0; stroke < 3; stroke++) {
          await injectPath(session, cutPath(12 + stroke * 10, stroke % 2 === 1), `cut-${stroke + 1}`, 700);
          const saved = await waitMaskChange(session, previous);
          expect(work(saved).history.length).assertEqual(stroke + 1); previous = work(saved).mask;
          expect(activeRecords(saved.records, 'note').length).assertEqual(0);
        }
        const rawBeforeLight = await session.raw(); const beforeLight = parseSnapshot(rawBeforeLight);
        const frozenProgress = JSON.stringify(progress(beforeLight));
        await (await session.waitId('paper-observe-light')).click();
        expect(await (await session.waitId('paper-observe-light')).getText()).assertEqual('回到剪纸');
        for (let pan = 0; pan < 4; pan++) {
          await injectPath(session, lightPath(pan % 2 === 1), `light-${pan + 1}`, 900);
        }
        // 观察动作绝不写progress、位置或timestamp；比较完整原始snapshot，而不是只看mask。
        expect(await session.raw()).assertEqual(rawBeforeLight);
        expect(JSON.stringify(progress(await session.read()))).assertEqual(frozenProgress);
        await (await session.waitId('paper-observe-light')).click();
        expect(await (await session.waitId('paper-observe-light')).getText()).assertEqual('移光看纸景');
        await injectPath(session, cutPath(42, true), 'resumed-cut', 700);
        const final = await waitMaskChange(session, previous); const finalWork = work(final);
        expect(finalWork.history.length).assertEqual(4);
        expect(finalWork.updatedAt > work(beforeLight).updatedAt).assertTrue();
        expect(finalWork.mask !== work(beforeLight).mask).assertTrue();
        expect(activeRecords(final.records, 'note').length).assertEqual(0);
        const frozenFinal = JSON.stringify(finalWork);
        // 离开再进入只回读实际落盘作品，确保合帧缓存没有成为未保存的唯一作品来源。
        await (await session.waitId('paper-back')).click(); await session.waitId('paper-journey-home');
        await openCity(session);
        expect(JSON.stringify(work(await session.read()))).assertEqual(frozenFinal);
        await session.waitId('paper-observe-light'); await session.waitId('paper-undo');
        console.info(`RIVER_PAPER_PERF_RESULT:${JSON.stringify({ nativeCutGestures: 4, cutStepsPerGesture: CUT_STEPS,
          nativeLightGestures: 4, lightStepsPerGesture: LIGHT_STEPS, maskSaved: true,
          fullSnapshotUnchangedWhileObserving: true, resumedCutSaved: true, reopenedWorkIdentical: true,
          notesNotAutoCreated: true, fpsThresholdApplied: false, telemetryMustBeCollectedSeparately: true })}`);
      });
    });
  });
}
