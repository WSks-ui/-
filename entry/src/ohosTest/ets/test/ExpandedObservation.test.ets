import { abilityDelegatorRegistry, Component, MatchPattern, ON, On } from '@kit.TestKit';
import { describe, expect, it } from '@ohos/hypium';
import { activeRecords } from '../../../main/ets/domain/ArchiveDomain';
import { HERITAGE_SITES } from '../../../main/ets/data/HeritageCatalog';
import { materialStudyForId } from '../../../main/ets/data/MaterialStudyCatalog';
import { materialObservationForSite } from '../../../main/ets/domain/MaterialObservation';
import { ArchiveUiSession } from './ArchiveUiSession';

interface PageArea {
  left: number;
  top: number;
  bottom: number;
}

interface ExpandedObservationScenario {
  siteId: string;
  searchText: string;
  preset: string;
  hotspotIds: string[];
  hotspotLabels: string[];
  finalHotspotId: string;
  body: string;
  tags: string;
  capturePrefix: string;
}

async function pageArea(session: ArchiveUiSession, page: string): Promise<PageArea> {
  const current = await session.driver.findComponent(ON.id(page));
  const bounds = await (current || await session.waitId(page)).getBounds();
  let top = bounds.top + 24;
  let bottom = bounds.bottom - 80;
  if (page === 'explore-scroll' || page === 'archive-scroll') {
    const header = await session.driver.findComponent(ON.id('top-navigation-content'));
    const dock = await session.driver.findComponent(ON.id('tab-0'));
    if (header) top = Math.max(top, (await header.getBounds()).bottom + 24);
    if (dock) bottom = Math.min(bottom, (await dock.getBounds()).top - 24);
  }
  if (bottom - top < 200) throw new Error(`EXPANDED_OBSERVATION_PAGE_TOO_SMALL:${page}`);
  return { left: bounds.left, top, bottom };
}

async function marginSwipe(session: ArchiveUiSession, area: PageArea, towardTop: boolean,
  requestedDistance: number = 700): Promise<void> {
  // 页面左侧余白避开原生画布与预览点击区；短步滚动保留相邻视野，不高速跳过热点或编辑字段。
  const height = area.bottom - area.top;
  const distance = Math.min(700, height * 0.32, requestedDistance);
  const start = area.top + height * (towardTop ? 0.28 : 0.72);
  const x = Math.round(area.left + 12);
  await session.driver.swipe(x, Math.round(start), x,
    Math.round(start + (towardTop ? distance : -distance)), 600);
  await session.driver.delayMs(150);
}

async function inPage(session: ArchiveUiSession, page: string, target: On): Promise<Component> {
  const area = await pageArea(session, page);
  let unknownMoves = 0;
  for (let attempt = 0; attempt <= 12; attempt++) {
    const node = await session.driver.findComponent(target);
    // 当前流程从页首顺着内容向下寻找；目标尚未挂载时先向下，不能先对页首做三次无效上滑。
    let towardTop = unknownMoves >= 3;
    if (node) {
      const bounds = await node.getBounds();
      if (bounds.right > bounds.left && bounds.bottom - bounds.top > 12) {
        const center = (bounds.top + bounds.bottom) / 2;
        if (center >= area.top && center <= area.bottom) return session.wait(target, page);
        towardTop = center < area.top;
      } else unknownMoves++;
    } else unknownMoves++;
    if (attempt < 12) await marginSwipe(session, area, towardTop);
  }
  throw new Error(`EXPANDED_OBSERVATION_TARGET_NOT_EXPOSED:${page}`);
}

async function currentDetailText(session: ArchiveUiSession, id: string): Promise<string> {
  // notice 锚定后从当前详情页的 UiTest 组件树读取其余文案，避免逐项滚动；缺少真实 Text 节点时直接失败，
  // 不以领域对象中的预期文案代替界面断言。
  const node = await session.driver.findComponent(ON.id(id).within(ON.id('detail-scroll')));
  if (!node) throw new Error(`EXPANDED_OBSERVATION_DETAIL_TEXT_NODE_MISSING:${id}`);
  return node.getText();
}

async function frameCanvas(session: ArchiveUiSession, page: string, canvasId: string,
  titleTarget?: On): Promise<void> {
  // 详情观察画布位于已知页首。用真实 Scroll 的回顶操作返回确定位置，避免读完长说明后
  // 再用多轮试探滑动搜寻离屏 Canvas；仍检查真实节点与完整边缘，不直接改变页面状态。
  // 画廊仍按卡片标题锚定，沿用相邻短步取景，不能把超长卡片按页首假设处理。
  if (page === 'detail-scroll' && !titleTarget) {
    await (await session.waitId(page)).scrollToTop(40000);
    const anchor = await session.wait(ON.id('engine-mode-relic'), '详情真实回顶后的观察模式');
    console.info(`EXPANDED_OBSERVATION_DETAIL_CANVAS_ANCHOR:${JSON.stringify(await anchor.getBounds())}`);
  }
  const area = await pageArea(session, page);
  // Canvas 被 Scroll 裁切时取到的可能只是可见片段；边缘须移入实际留白后才截图。
  for (let attempt = 0; attempt <= 8; attempt++) {
    const canvasNode = await session.driver.findComponent(ON.id(canvasId).type('Canvas'));
    const titleNode = titleTarget ? await session.driver.findComponent(titleTarget) : undefined;
    const canvas = canvasNode ? await canvasNode.getBounds() : undefined;
    const title = titleNode ? await titleNode.getBounds() : undefined;
    const hasCanvas = canvas !== undefined && canvas.right > canvas.left && canvas.bottom - canvas.top > 120;
    const hasTitle = title !== undefined && title.right > title.left && title.bottom - title.top > 12;
    const titleVisible = !titleTarget || (hasTitle && title !== undefined &&
      title.top >= area.top + 80 && title.bottom <= area.bottom - 80);
    if (hasCanvas && canvas && canvas.top >= area.top + 80 && canvas.bottom <= area.bottom - 80 && titleVisible) {
      console.info(`EXPANDED_OBSERVATION_CAPTURE_FRAME:${canvasId}:${JSON.stringify({ page, area, canvas, title })}`);
      return;
    }
    if (attempt === 8) break;
    let towardTop = false;
    let distance = 700;
    if (hasTitle && title && title.top < area.top + 80) {
      towardTop = true; distance = Math.max(160, area.top + 112 - title.top);
    } else if (hasCanvas && canvas && canvas.top < area.top + 80) {
      towardTop = true; distance = Math.max(160, area.top + 112 - canvas.top);
    } else if (hasCanvas && canvas && canvas.bottom < area.bottom + 24) {
      distance = Math.max(160, canvas.bottom - area.bottom + 112);
    }
    await marginSwipe(session, area, towardTop, distance);
  }
  throw new Error(`EXPANDED_OBSERVATION_CANVAS_NOT_FRAMED:${page}:${canvasId}`);
}

async function capture(session: ArchiveUiSession, name: string, canvasId: string): Promise<void> {
  // 每个捕获使用独立 Preferences 的离线演示画面；wrapper 据配对截图核对真实 Canvas 像素变化。
  await session.driver.delayMs(250);
  const canvas = await session.driver.findComponent(ON.id(canvasId).type('Canvas'));
  if (!canvas) throw new Error(`EXPANDED_OBSERVATION_CAPTURE_CANVAS_MISSING:${name}`);
  console.info(`EXPANDED_OBSERVATION_CAPTURE_BOUNDS:${name}:${JSON.stringify(await canvas.getBounds())}`);
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  const image = await delegator.executeShellCommand(
    `uitest screenCap -p /data/local/tmp/yunheji-observation-${name}.png`);
  expect(image.exitCode).assertEqual(0);
  const layout = await delegator.executeShellCommand(
    `uitest dumpLayout -p /data/local/tmp/yunheji-observation-${name}.json`);
  expect(layout.exitCode).assertEqual(0);
}

async function runExpandedObservation(scenario: ExpandedObservationScenario): Promise<void> {
  // ArchiveUiSession 默认生成随机库名；每条核心路径写入并在 finally 中删除自己的 Preferences。
  const session = new ArchiveUiSession(`expanded_${scenario.capturePrefix.replace(/-/g, '_')}`);
  const started = Date.now();
  await session.run(async () => {
    const site = HERITAGE_SITES.find(item => item.id === scenario.siteId);
    const study = materialStudyForId(scenario.siteId);
    const observation = materialObservationForSite(scenario.siteId);
    if (!site || !study || !observation) throw new Error('EXPANDED_OBSERVATION_CONTENT_MISSING');
    expect(observation.sceneRevision).assertEqual(2);
    expect(observation.proceduralPreset).assertEqual(scenario.preset);
    expect(study.facts.length >= scenario.hotspotIds.length).assertTrue();
    const canvasId = 'engine-native-relic_inspector';
    const finalDetail = observation.hotspots.find(item => item.id === scenario.finalHotspotId);
    if (!finalDetail) throw new Error(`EXPANDED_OBSERVATION_FINAL_HOTSPOT_MISSING:${scenario.finalHotspotId}`);
    const finalFact = study.facts.find(item => item.id === finalDetail.factId);
    if (!finalFact) throw new Error('EXPANDED_OBSERVATION_FINAL_FACT_MISSING');

    await session.search(scenario.searchText, 1);
    await (await inPage(session, 'explore-scroll',
      ON.id(`site-row-${scenario.siteId}`).within(ON.id('explore-site-grid')))).click();
    await session.waitId('detail-scroll');

    // 三处热点必须各自指向资料事实与具体可见提示；逐帧留图供 wrapper 验证选中标记真的变化。
    for (let index = 0; index < scenario.hotspotIds.length; index++) {
      const id = scenario.hotspotIds[index];
      const detail = observation.hotspots.find(item => item.id === id);
      const fact = study.facts.find(item => item.id === detail?.factId);
      if (!detail || !fact) throw new Error(`EXPANDED_OBSERVATION_FACT_MISSING:${id}`);
      expect(detail.label).assertEqual(scenario.hotspotLabels[index]);
      await (await inPage(session, 'detail-scroll', ON.id(`observation-hotspot-${id}`))).click();
      // 首个热点在详情加载时已默认选中，重复点击同一 id 不一定触发 payload 更新；
      // 后续热点才要求状态明确进入已聚焦，首项仍由名称、提示、事实和实际截图覆盖。
      if (index > 0) {
        expect((await currentDetailText(session, 'engine-angle')).includes('已聚焦')).assertTrue();
      }
      // 只滚动锚定一次底部说明，再从当前详情组件树核对真实 UI 文案，避免每条长文本各自驱动滚动。
      const notice = await inPage(session, 'detail-scroll', ON.id('site-object-notice'));
      expect(await notice.getText()).assertEqual(observation.notice);
      expect(await currentDetailText(session, 'observation-selected-detail'))
        .assertEqual(`正在观察 · ${detail.label}`);
      expect(await currentDetailText(session, 'observation-visible-detail')).assertEqual(detail.visibleDetail);
      expect(await currentDetailText(session, 'engine-hotspot-reading')).assertEqual(fact.body);
      await frameCanvas(session, 'detail-scroll', canvasId);
      await capture(session, `${scenario.capturePrefix}-${id}`, canvasId);
    }

    // 演示视角锁定到指定末尾热点，再真实转动一次；保存角度必须包含这次手动转动。
    await (await inPage(session, 'detail-scroll', ON.id(`observation-hotspot-${scenario.finalHotspotId}`))).click();
    const finalNotice = await inPage(session, 'detail-scroll', ON.id('site-object-notice'));
    expect(await finalNotice.getText()).assertEqual(observation.notice);
    expect(await currentDetailText(session, 'observation-selected-detail'))
      .assertEqual(`正在观察 · ${finalDetail.label}`);
    expect(await currentDetailText(session, 'observation-visible-detail')).assertEqual(finalDetail.visibleDetail);
    expect(await currentDetailText(session, 'engine-hotspot-reading')).assertEqual(finalFact.body);
    await frameCanvas(session, 'detail-scroll', canvasId);
    const yawBeforeTurn = finalDetail.yaw;
    const expectedYaw = yawBeforeTurn + Math.PI / 8;
    const expectedAngle = Math.round(expectedYaw * 180 / Math.PI) % 360;
    await (await inPage(session, 'detail-scroll', ON.id('engine-right'))).click();
    expect((await currentDetailText(session, 'engine-angle')).includes(`视角 ${expectedAngle}°`)).assertTrue();
    await capture(session, `${scenario.capturePrefix}-source`, canvasId);

    await (await inPage(session, 'detail-scroll', ON.id('engine-remember-view'))).click();
    await session.waitId('note-editor-scroll');
    await session.wait(ON.id('memory-draft-preview-status').text('已恢复当时视角'), '草稿画布已实际重绘');
    const draftCanvas = await session.wait(ON.id('memory-draft-preview-canvas').type('Canvas'), '真实草稿预览画布');
    const draftBounds = await draftCanvas.getBounds();
    expect(draftBounds.right - draftBounds.left > 120 && draftBounds.bottom - draftBounds.top > 120).assertTrue();
    expect(await (await inPage(session, 'note-editor-scroll', ON.id('memory-draft-preview-status'))).getText())
      .assertEqual('已恢复当时视角');
    expect((await (await inPage(session, 'note-editor-scroll', ON.id('memory-draft-pose'))).getText())
      .includes(finalDetail.label)).assertTrue();
    await (await inPage(session, 'note-editor-scroll', ON.id('note-body')))
      .inputText(scenario.body, { paste: true, addition: true });
    await (await inPage(session, 'note-editor-scroll', ON.id('note-tags')))
      .inputText(scenario.tags, { paste: true, addition: true });
    await session.driver.pressBack();
    await (await session.waitId('save-note')).click();
    await session.editorClosed();

    // 先从真实页面 Context 清缓存再读独立 Preferences，确认写盘内容及完整 revision 2 画幅。
    const saved = await session.read();
    expect(saved.schemaVersion).assertEqual(1);
    const notes = activeRecords(saved.records, 'note');
    expect(notes.length).assertEqual(1);
    const note = notes[0];
    expect(note.siteId).assertEqual(scenario.siteId);
    expect(note.body).assertEqual(scenario.body);
    expect(note.tags.join('|')).assertEqual(scenario.tags.split(/[，,]/).map(tag => tag.trim()).join('|'));
    expect(note.quotedPoemOrFact).assertEqual(finalFact.body);
    const pose = note.snapshot3DPose;
    if (!pose) throw new Error('EXPANDED_OBSERVATION_SAVED_POSE_MISSING');
    expect(pose.version).assertEqual(1);
    expect(pose.sceneType).assertEqual('relic_inspector');
    expect(pose.proceduralPreset).assertEqual(scenario.preset);
    expect(pose.sceneRevision).assertEqual(2);
    expect(pose.rendererProfile).assertEqual('native-raster-v1');
    expect(pose.hotspotId).assertEqual(scenario.finalHotspotId);
    expect(pose.sectionId).assertEqual('');
    expect(Math.abs(pose.yaw - expectedYaw) < 0.0001).assertTrue();
    expect(Math.abs(pose.pitch - finalDetail.pitch) < 0.0001).assertTrue();
    expect(Math.abs(pose.zoom - finalDetail.zoom) < 0.0001).assertTrue();
    const frame = pose.viewFrame;
    if (!frame) throw new Error('EXPANDED_OBSERVATION_SAVED_FRAME_MISSING');
    expect(Number.isFinite(frame.width) && frame.width > 24 && Number.isFinite(frame.height) && frame.height > 46)
      .assertTrue();
    expect(frame.textDensity !== undefined && Number.isFinite(frame.textDensity) && frame.textDensity > 0).assertTrue();
    expect(typeof frame.dark === 'boolean').assertTrue();
    console.info(`EXPANDED_OBSERVATION_SAVED:${JSON.stringify(note)}`);

    await session.driver.pressBack();
    await session.waitId('explore-scroll');
    await (await session.waitId('tab-1')).click();
    await session.waitId('archive-scroll');
    await (await inPage(session, 'archive-scroll', ON.id('memory-view-gallery'))).click();
    const previewId = `memory-preview-${note.id}`;
    await inPage(session, 'archive-scroll', ON.id(`${previewId}-status`).text('已恢复当时视角')
      .within(ON.id('archive-scroll')));
    await session.wait(ON.id(`${previewId}-status`).text('已恢复当时视角').within(ON.id('archive-scroll')),
      '画廊预览已实际绘制');
    const previewCanvasId = `${previewId}-canvas`;
    await frameCanvas(session, 'archive-scroll', previewCanvasId,
      ON.text(site.name).within(ON.id(`memory-card-${note.id}`)));
    await capture(session, `${scenario.capturePrefix}-gallery`, previewCanvasId);

    // 点击完整显示的 Canvas 预览，沿 MemoryPostcardItem.onPose → openMemory → SiteDetail 正式恢复。
    await (await session.wait(ON.id(previewCanvasId).type('Canvas').within(ON.id('archive-scroll')), '画廊观察画面'))
      .click();
    await session.waitId('detail-scroll');
    const replayAngle = await session.wait(ON.id('engine-angle').text('已回到手账视角', MatchPattern.CONTAINS),
      '回放 Canvas 已真实绘制完成');
    expect((await replayAngle.getText()).includes('已回到手账视角')).assertTrue();
    const replayNotice = await inPage(session, 'detail-scroll', ON.id('site-object-notice'));
    expect(await replayNotice.getText()).assertEqual(observation.notice);
    expect(await currentDetailText(session, 'observation-selected-detail'))
      .assertEqual(`正在观察 · ${finalDetail.label}`);
    expect(await currentDetailText(session, 'observation-visible-detail')).assertEqual(finalDetail.visibleDetail);
    expect(await currentDetailText(session, 'engine-hotspot-reading')).assertEqual(finalFact.body);
    await frameCanvas(session, 'detail-scroll', canvasId);
    await capture(session, `${scenario.capturePrefix}-replay`, canvasId);

    // 回放绘制成功后再右转一步，确认恢复的 yaw 已成为视口当前相机，而非只显示成功文案。
    const yawAfterReplayTurn = pose.yaw + Math.PI / 8;
    const replayTurnAngle = Math.round(yawAfterReplayTurn * 180 / Math.PI) % 360;
    await (await inPage(session, 'detail-scroll', ON.id('engine-right'))).click();
    expect((await currentDetailText(session, 'engine-angle')).includes(`视角 ${replayTurnAngle}°`)).assertTrue();

  });
  const elapsed = Date.now() - started;
  console.info(`EXPANDED_OBSERVATION_CORE_PATH_MS:${scenario.siteId}:${elapsed}`);
}

export default function expandedObservationTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requested = parameters['class'] || parameters['-s class'] || '';
  if (!requested.includes('ExpandedObservationTest')) return;
  describe('ExpandedObservationTest', () => {
    it('native_miaodigou_observe_save_gallery_replay', 0, async () => {
      await runExpandedObservation({
        siteId: 'smx-miaodigou', searchText: '庙底沟遗址', preset: 'miaodigou_pottery',
        hotspotIds: ['living', 'kilns', 'ditches'],
        hotspotLabels: ['居住遗存', '西部陶窑', '东西壕沟'], finalHotspotId: 'kilns',
        body: '把居住遗存和陶窑放回西部的空间关系里看，示意位置值得沿现场方向继续核对。',
        tags: '庙底沟遗址，陶窑，空间观察', capturePrefix: 'expanded-miaodigou'
      });
    });
    it('native_duling_observe_save_gallery_replay', 0, async () => {
      await runExpandedObservation({
        siteId: 'zz-duling-fangding', searchText: '杜岭二号方鼎', preset: 'duling_fangding',
        hotspotIds: ['centers', 'corners', 'frame'],
        hotspotLabels: ['壁面正中', '四个折角', '乳钉边框'], finalHotspotId: 'corners',
        body: '沿鼎腹转一圈，壁面正中和四个折角各有一组兽面纹，乳钉纹带另作边框。',
        tags: '杜岭二号方鼎，兽面纹，乳钉纹带', capturePrefix: 'expanded-duling'
      });
    });
  });
}
