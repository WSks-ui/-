import { abilityDelegatorRegistry, Component, ON, On } from '@kit.TestKit';
import { describe, expect, it } from '@ohos/hypium';
import { MATERIAL_COMPARISON, MaterialEvidenceSource, materialStudyForId } from '../../../main/ets/data/MaterialStudyCatalog';
import { ArchiveUiSession } from './ArchiveUiSession';

interface PageArea {
  left: number;
  top: number;
  bottom: number;
}

function checkBudget(deadline: number): void {
  if (Date.now() >= deadline) throw new Error('MATERIAL_COMPARISON_CORE_BUDGET_EXCEEDED');
}

async function pageArea(session: ArchiveUiSession, page: string): Promise<PageArea> {
  const current = await session.driver.findComponent(ON.id(page));
  const bounds = await (current || await session.waitId(page)).getBounds();
  let top = bounds.top + 24;
  let bottom = bounds.bottom - 24;
  if (page === 'explore-scroll') {
    const header = await session.driver.findComponent(ON.id('top-navigation-content'));
    const dock = await session.driver.findComponent(ON.id('tab-0'));
    if (header) top = Math.max(top, (await header.getBounds()).bottom + 24);
    if (dock) bottom = Math.min(bottom, (await dock.getBounds()).top - 24);
  }
  if (page === 'detail-scroll') bottom = bounds.bottom - 80;
  if (bottom - top < 200) throw new Error(`MATERIAL_COMPARISON_PAGE_TOO_SMALL:${page}`);
  return { left: bounds.left, top, bottom };
}

async function marginSwipe(session: ArchiveUiSession, area: PageArea, towardTop: boolean,
  requestedDistance: number = 700): Promise<void> {
  // 对照页有独立 Scroll；手势始终落在其左侧 18vp 留白内，不拖动图谱或点击图片、来源按钮。
  // 每步至多 32% 可用高度，保留重叠视野；600 是 px/s，不把速度当时长造成整页过冲。
  const height = area.bottom - area.top;
  const distance = Math.min(700, height * 0.32, requestedDistance);
  const start = area.top + height * (towardTop ? 0.28 : 0.72);
  const x = Math.round(area.left + 12);
  await session.driver.swipe(x, Math.round(start), x, Math.round(start + (towardTop ? distance : -distance)), 600);
  await session.driver.delayMs(150);
}

async function inPage(session: ArchiveUiSession, page: string, target: On, deadline: number,
  unknownTowardTop: boolean = false): Promise<Component> {
  const area = await pageArea(session, page);
  for (let attempt = 0; attempt <= 12; attempt++) {
    checkBudget(deadline);
    const node = await session.driver.findComponent(target);
    let towardTop = unknownTowardTop;
    let distance = 700;
    if (node) {
      const bounds = await node.getBounds();
      if (bounds.right > bounds.left && bounds.bottom - bounds.top > 12) {
        if (bounds.top >= area.top + 24 && bounds.bottom <= area.bottom - 24) {
          const stable = await session.wait(target, `对照叶节点:${page}`);
          const current = await stable.getBounds();
          if (current.right > current.left && current.bottom - current.top > 12 &&
            current.top >= area.top + 24 && current.bottom <= area.bottom - 24) return stable;
        }
        towardTop = bounds.top < area.top + 24;
        distance = Math.max(120, towardTop ? area.top + 48 - bounds.top : bounds.bottom - area.bottom + 48);
      }
    }
    if (attempt < 12) await marginSwipe(session, area, towardTop, distance);
  }
  throw new Error(`MATERIAL_COMPARISON_LEAF_NOT_EXPOSED:${page}`);
}

async function clickDimension(session: ArchiveUiSession, dimensionId: string, deadline: number): Promise<void> {
  checkBudget(deadline);
  const button = await session.waitId(`material-comparison-${dimensionId}`);
  const bounds = await button.getBounds();
  const panel = await (await session.waitId('material-comparison-panel')).getBounds();
  expect(bounds.right > bounds.left && bounds.bottom - bounds.top > 12 &&
    bounds.top > panel.top && bounds.bottom < panel.bottom).assertTrue();
  await button.click();
  await session.waitId(`material-comparison-fact-left-${dimensionId}`);
}

async function frameLeaves(session: ArchiveUiSession, upperTarget: On, lowerTarget: On, deadline: number): Promise<void> {
  const area = await pageArea(session, 'material-comparison-scroll');
  // 大面板的中心可见不代表两件对象都可见。截图只接受实际正文或 Image 与图注的上下边，
  // 并留出裁切线内侧的空间，拒绝把被 Scroll 截短后的 bounds 当成完整图片。
  for (let attempt = 0; attempt <= 8; attempt++) {
    checkBudget(deadline);
    const upperNode = await session.driver.findComponent(upperTarget);
    const lowerNode = await session.driver.findComponent(lowerTarget);
    const upper = upperNode ? await upperNode.getBounds() : undefined;
    const lower = lowerNode ? await lowerNode.getBounds() : undefined;
    const hasUpper = upper !== undefined && upper.right > upper.left && upper.bottom - upper.top > 12;
    const hasLower = lower !== undefined && lower.right > lower.left && lower.bottom - lower.top > 12;
    if (hasUpper && hasLower && upper && lower &&
      upper.top >= area.top + 48 && lower.bottom <= area.bottom - 48) {
      const stableUpper = await (await session.wait(upperTarget, '对照截图上缘')).getBounds();
      const stableLower = await (await session.wait(lowerTarget, '对照截图下缘')).getBounds();
      if (stableUpper.top >= area.top + 48 && stableLower.bottom <= area.bottom - 48) {
        console.info(`MATERIAL_COMPARISON_CAPTURE_FRAME:${JSON.stringify({ area, upper: stableUpper, lower: stableLower })}`);
        return;
      }
    }
    if (attempt === 8) break;
    let towardTop = false;
    let distance = 700;
    if (hasUpper && upper && upper.top < area.top + 48) {
      towardTop = true; distance = Math.max(120, area.top + 80 - upper.top);
    } else if (!hasUpper && hasLower) {
      towardTop = true;
    } else if (hasLower && lower && lower.bottom < area.bottom + 24) {
      distance = Math.max(120, lower.bottom - area.bottom + 80);
    }
    await marginSwipe(session, area, towardTop, distance);
  }
  throw new Error('MATERIAL_COMPARISON_CAPTURE_LEAVES_NOT_FRAMED');
}

async function capture(session: ArchiveUiSession, name: string, deadline: number): Promise<void> {
  checkBudget(deadline);
  // 截图来自独立随机离线库，不含私人账号；保留原图与真实布局，仍须主机拉取后人工看图。
  await session.driver.delayMs(250);
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  const image = await delegator.executeShellCommand(`uitest screenCap -p /data/local/tmp/yunheji-observation-comparison-${name}.png`);
  expect(image.exitCode).assertEqual(0);
  const layout = await delegator.executeShellCommand(`uitest dumpLayout -p /data/local/tmp/yunheji-observation-comparison-${name}.json`);
  expect(layout.exitCode).assertEqual(0);
}

function sourceFor(side: string, sourceId: string): MaterialEvidenceSource {
  const study = materialStudyForId(side === 'left' ? MATERIAL_COMPARISON.leftSiteId : MATERIAL_COMPARISON.rightSiteId);
  const source = study?.sources.find((item: MaterialEvidenceSource) => item.id === sourceId);
  if (!source) throw new Error(`MATERIAL_COMPARISON_SOURCE_FIXTURE_MISSING:${side}:${sourceId}`);
  return source;
}

export default function materialComparisonTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requested = parameters['class'] || parameters['-s class'] || '';
  // 只启用这一条必要对照主线，沿用脚本的 240 秒上限，不并入默认图谱或外观套件。
  if (!requested.includes('MaterialComparisonTest')) return;
  describe('MaterialComparisonTest', () => {
    it('native_three_dimensions_sources_original_visuals_and_dahecun_observation', 0, async () => {
      const started = Date.now();
      // 225 秒停止继续推进，为既有 session.run 的退出与独立库清理保留时间，不提高总超时。
      const deadline = started + 225000;
      const storeName = `yunheji_test_ui_${Date.now()}_comparison_${Math.floor(Math.random() * 1000000)}`;
      const session = new ArchiveUiSession('material_comparison', storeName);
      await session.run(async () => {
        await (await inPage(session, 'explore-scroll', ON.id('culture-atlas-entry'), deadline)).click();
        await session.waitId('culture-atlas-scroll');
        await (await inPage(session, 'culture-atlas-scroll', ON.id('culture-material-comparison-open'), deadline)).click();
        await session.waitId('material-comparison-panel');
        await session.waitId('material-comparison-scroll');

        // Catalog 仅提供预期；每一项都读取真实 Text，且上下边已进入本面板的 Scroll 内侧。
        for (const dimension of MATERIAL_COMPARISON.dimensions) {
          await clickDimension(session, dimension.id, deadline);
          const leftTarget = ON.id(`material-comparison-fact-left-${dimension.id}`);
          const rightTarget = ON.id(`material-comparison-fact-right-${dimension.id}`);
          const left = await inPage(session, 'material-comparison-scroll', leftTarget, deadline);
          expect(await left.getText()).assertEqual(dimension.left);
          const right = await inPage(session, 'material-comparison-scroll', rightTarget, deadline);
          expect(await right.getText()).assertEqual(dimension.right);
          if (dimension.id === 'body') {
            await frameLeaves(session, leftTarget, rightTarget, deadline);
            await capture(session, 'body', deadline);
          }
          const limit = await inPage(session, 'material-comparison-scroll', ON.id(`material-comparison-limit-${dimension.id}`), deadline);
          expect(await limit.getText()).assertEqual(dimension.limit);
          console.info(`MATERIAL_COMPARISON_DIMENSION_VERIFIED:${dimension.id}:${Date.now() - started}`);
        }

        await clickDimension(session, 'body', deadline);
        const body = MATERIAL_COMPARISON.dimensions.find((dimension) => dimension.id === 'body');
        if (!body) throw new Error('MATERIAL_COMPARISON_BODY_FIXTURE_MISSING');
        for (const side of ['left', 'right']) {
          const toggle = ON.id(`material-comparison-sources-${side}`);
          await (await inPage(session, 'material-comparison-scroll', toggle, deadline)).click();
          const source = sourceFor(side, side === 'left' ? body.leftSourceIds[0] : body.rightSourceIds[0]);
          const label = await inPage(session, 'material-comparison-scroll',
            ON.id(`material-comparison-source-${side}-${source.id}`), deadline);
          expect(await label.getText()).assertEqual(`${source.publisher} · ${source.title}`);
          expect(source.publisher).assertEqual('河南博物院');
          // 核对后关闭本侧来源，避免长网址把后续双图截图挤进超长展开区。
          await (await inPage(session, 'material-comparison-scroll', toggle, deadline, true)).click();
        }

        for (const side of ['left', 'right']) {
          const study = materialStudyForId(side === 'left' ? MATERIAL_COMPARISON.leftSiteId : MATERIAL_COMPARISON.rightSiteId);
          if (!study) throw new Error(`MATERIAL_COMPARISON_VISUAL_FIXTURE_MISSING:${side}`);
          const imageTarget = ON.id(`material-comparison-visual-${side}`).type('Image');
          await inPage(session, 'material-comparison-scroll', imageTarget, deadline);
          const captionTarget = ON.text(study.visualCaption).type('Text');
          await frameLeaves(session, imageTarget, captionTarget, deadline);
          const image = await session.wait(imageTarget, `双方原创 Image:${side}`);
          const bounds = await image.getBounds();
          // 两张源 SVG 都是 1000×600。原生 Image 的完整高宽比例与内侧边界一起防止截图只见半张。
          expect(bounds.right - bounds.left > 160 && bounds.bottom - bounds.top > 120).assertTrue();
          expect(Math.abs((bounds.right - bounds.left) / (bounds.bottom - bounds.top) - 5 / 3) < 0.12).assertTrue();
          const caption = await inPage(session, 'material-comparison-scroll', captionTarget, deadline);
          expect(await caption.getText()).assertEqual(study.visualCaption);
          console.info(`MATERIAL_COMPARISON_ORIGINAL_IMAGE:${side}:${JSON.stringify(bounds)}`);
          await capture(session, `visuals-${side}`, deadline);
        }

        await (await inPage(session, 'material-comparison-scroll', ON.id('material-comparison-observe-left'), deadline, true)).click();
        await session.waitId('detail-scroll');
        const study = materialStudyForId(MATERIAL_COMPARISON.leftSiteId);
        if (!study) throw new Error('MATERIAL_COMPARISON_DAHECUN_FIXTURE_MISSING');
        const question = await inPage(session, 'detail-scroll',
          ON.id('material-study-question').within(ON.id(`material-study-${MATERIAL_COMPARISON.leftSiteId}`)), deadline);
        expect(await question.getText()).assertEqual(study.question);
        expect(!await session.driver.findComponent(ON.id('material-comparison-panel'))).assertTrue();
        checkBudget(deadline);
        console.info(`MATERIAL_COMPARISON_CORE_PATH_MS:${Date.now() - started}`);
      });
    });
  });
}
