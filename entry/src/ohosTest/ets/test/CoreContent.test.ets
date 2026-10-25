import { abilityDelegatorRegistry, Component, ON, On } from '@kit.TestKit';
import { describe, expect, it } from '@ohos/hypium';
import { HERITAGE_SITES } from '../../../main/ets/data/HeritageCatalog';
import { materialStudyForId } from '../../../main/ets/data/MaterialStudyCatalog';
import { ArchiveUiSession } from './ArchiveUiSession';

interface DetailArea {
  left: number;
  top: number;
  bottom: number;
}

async function detailArea(session: ArchiveUiSession): Promise<DetailArea> {
  const bounds = await (await session.waitId('detail-scroll')).getBounds();
  return { left: bounds.left, top: bounds.top + 24, bottom: bounds.bottom - 80 };
}

async function marginSwipe(session: ArchiveUiSession, area: DetailArea, towardTop: boolean, distance: number = 700): Promise<void> {
  // 与已验证的详情助手一致，从左侧页面余白发起短步手势，避免拖动画布或点击正文中的按钮。
  // 第五个参数是 px/s；保留相邻视野，不用高速整屏 fling 或追加长等待掩盖错过节点。
  const height = area.bottom - area.top;
  const movement = Math.min(700, height * 0.32, distance);
  const start = area.top + height * (towardTop ? 0.28 : 0.72);
  const x = Math.round(area.left + 12);
  await session.driver.swipe(x, Math.round(start), x, Math.round(start + (towardTop ? movement : -movement)), 600);
  await session.driver.delayMs(150);
}

async function inDetail(session: ArchiveUiSession, target: On): Promise<Component> {
  await session.inScroll('detail-scroll', target);
  const area = await detailArea(session);
  // 事实正文和资料按钮均是具体叶节点。除助手已有的中心可见检查外，再确认上下边
  // 完整进入内容区；不能对被标题栏裁切的按钮直接 click，也不能只读零范围节点的文字。
  for (let attempt = 0; attempt <= 4; attempt++) {
    const node = await session.driver.findComponent(target);
    const bounds = node ? await node.getBounds() : undefined;
    if (node && bounds && bounds.right > bounds.left && bounds.bottom - bounds.top > 12) {
      if (bounds.top >= area.top && bounds.bottom <= area.bottom) return session.wait(target, '精做内容实际可见');
      if (attempt < 4) {
        const towardTop = bounds.top < area.top;
        const distance = towardTop ? area.top + 48 - bounds.top : bounds.bottom - area.bottom + 48;
        await marginSwipe(session, area, towardTop, Math.max(120, distance));
        continue;
      }
    }
    break;
  }
  throw new Error('CORE_CONTENT_LEAF_NOT_EXPOSED');
}

async function frameQuestionAndVisual(session: ArchiveUiSession): Promise<void> {
  const area = await detailArea(session);
  // 问题与约 200vp 原创图能够同屏。必须同时核对问题上边和 Image 下边，
  // Image 若被 Scroll 裁切，其 bottom 仍会贴在视口边缘，不能凭容器中心提前截图。
  for (let attempt = 0; attempt <= 6; attempt++) {
    const question = await session.driver.findComponent(ON.id('material-study-question'));
    const image = await session.driver.findComponent(ON.id('material-study-visual').type('Image'));
    const upper = question ? await question.getBounds() : undefined;
    const lower = image ? await image.getBounds() : undefined;
    const hasUpper = upper !== undefined && upper.right > upper.left && upper.bottom - upper.top > 12;
    const hasLower = lower !== undefined && lower.right > lower.left && lower.bottom - lower.top > 12;
    if (hasUpper && hasLower && upper && lower &&
      upper.top >= area.top + 48 && lower.bottom <= area.bottom - 48) {
      console.info(`CORE_CONTENT_VISUAL_FRAME:${JSON.stringify({ question: upper, image: lower })}`);
      return;
    }
    if (attempt === 6) break;
    let towardTop = false;
    let distance = 700;
    if (hasUpper && upper && upper.top < area.top + 48) {
      towardTop = true;
      distance = Math.max(160, area.top + 80 - upper.top);
    } else if (!hasUpper && hasLower) towardTop = true;
    else if (hasLower && lower && lower.bottom < area.bottom + 24) {
      distance = Math.max(160, lower.bottom - area.bottom + 80);
    }
    await marginSwipe(session, area, towardTop, distance);
  }
  throw new Error('CORE_CONTENT_QUESTION_VISUAL_NOT_FRAMED');
}

async function capture(session: ArchiveUiSession, siteId: string): Promise<void> {
  await session.driver.delayMs(350);
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  const image = await delegator.executeShellCommand(`uitest screenCap -p /data/local/tmp/yunheji-core-content-${siteId}.png`);
  expect(image.exitCode).assertEqual(0);
  const layout = await delegator.executeShellCommand(`uitest dumpLayout -p /data/local/tmp/yunheji-core-content-${siteId}.json`);
  expect(layout.exitCode).assertEqual(0);
}

export default function coreContentTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requested = parameters['class'] || parameters['-s class'] || '';
  if (!requested.includes('CoreContentTest')) return;
  describe('CoreContentTest', () => {
    it('native_three_material_studies_questions_visuals_facts_and_sources', 0, async () => {
      const session = new ArchiveUiSession('core_content');
      await session.run(async () => {
        const started = Date.now();
        const siteIds: string[] = ['smx-miaodigou', 'zz-dahecun', 'zz-duling-fangding'];
        for (const siteId of siteIds) {
          const site = HERITAGE_SITES.find((item) => item.id === siteId);
          const study = materialStudyForId(siteId);
          if (!site || !study || study.sources.length === 0) throw new Error(`CORE_CONTENT_TEST_DATA_MISSING:${siteId}`);
          await session.search(site.name, 1);
          await (await session.inScroll('device-scroll',
            ON.id(`site-row-${siteId}`).within(ON.id('archive-library-grid')))).click();
          await session.waitId('detail-scroll');

          // 目录仅提供预期文案；下列结论全部来自真实窗口的节点和可见范围，不用数据数组代替 UI。
          const question = await inDetail(session, ON.id('material-study-question'));
          expect(await question.getText()).assertEqual(study.question);
          await inDetail(session, ON.id('material-study-visual').type('Image'));
          await frameQuestionAndVisual(session);
          await capture(session, siteId);
          const discovery = await inDetail(session, ON.id('material-study-discovery'));
          expect(await discovery.getText()).assertEqual(study.discovery);
          for (const fact of study.facts) {
            const body = await inDetail(session, ON.id(`material-fact-${fact.id}`));
            expect(await body.getText()).assertEqual(fact.body);
          }

          const sourcesToggle = await inDetail(session, ON.id('material-study-sources-toggle'));
          await sourcesToggle.click();
          const source = study.sources[0];
          const sourceLabel = await inDetail(session, ON.id(`material-source-${source.id}`));
          expect(await sourceLabel.getText()).assertEqual(`〔1〕${source.publisher} · ${source.title}`);
          console.info(`CORE_CONTENT_UI_VERIFIED:${siteId}:${Date.now() - started}`);
          await session.driver.pressBack();
          await session.waitId('device-scroll');
        }
        console.info(`CORE_CONTENT_PATH_MS:${Date.now() - started}`);
      });
    });
  });
}
