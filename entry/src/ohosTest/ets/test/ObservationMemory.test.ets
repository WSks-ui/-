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
  if (bottom - top < 200) throw new Error(`OBSERVATION_PAGE_TOO_SMALL:${page}`);
  return { left: bounds.left, top, bottom };
}

async function marginSwipe(session: ArchiveUiSession, area: PageArea, towardTop: boolean,
  requestedDistance: number = 700): Promise<void> {
  // 页面左侧余白避开原生画布及预览点击区；每步保留相邻视野，600 的单位为 px/s。
  // 不在画布中央 scrollSearch，不用高速整页 fling 跳过热点或短编辑字段。
  const height = area.bottom - area.top;
  const distance = Math.min(700, height * 0.32, requestedDistance);
  const start = area.top + height * (towardTop ? 0.28 : 0.72);
  const x = Math.round(area.left + 12);
  await session.driver.swipe(x, Math.round(start), x, Math.round(start + (towardTop ? distance : -distance)), 600);
  await session.driver.delayMs(150);
}

async function inPage(session: ArchiveUiSession, page: string, target: On): Promise<Component> {
  const area = await pageArea(session, page);
  let unknownMoves = 0;
  for (let attempt = 0; attempt <= 12; attempt++) {
    const node = await session.driver.findComponent(target);
    let towardTop = unknownMoves < 3;
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
  throw new Error(`OBSERVATION_TARGET_NOT_EXPOSED:${page}`);
}

async function frameCanvas(session: ArchiveUiSession, page: string, canvasId: string,
  titleTarget?: On): Promise<void> {
  const area = await pageArea(session, page);
  // Canvas 被 Scroll 裁切时 getBounds 可能只剩可见片段；上下边须离开裁切线进入真实留白。
  // 画廊只要求卡片标题与预览主体完整可见，不要求超长手账的正文、时间和页脚同时入屏。
  for (let attempt = 0; attempt <= 8; attempt++) {
    const canvasNode = await session.driver.findComponent(ON.id(canvasId).type('Canvas'));
    const titleNode = titleTarget ? await session.driver.findComponent(titleTarget) : undefined;
    const canvas = canvasNode ? await canvasNode.getBounds() : undefined;
    const title = titleNode ? await titleNode.getBounds() : undefined;
    const hasCanvas = canvas !== undefined && canvas.right > canvas.left && canvas.bottom - canvas.top > 120;
    const hasTitle = title !== undefined && title.right > title.left && title.bottom - title.top > 12;
    const titleVisible = !titleTarget || (hasTitle && title !== undefined && title.top >= area.top + 80 && title.bottom <= area.bottom - 80);
    if (hasCanvas && canvas && canvas.top >= area.top + 80 && canvas.bottom <= area.bottom - 80 && titleVisible) {
      console.info(`OBSERVATION_CAPTURE_FRAME:${canvasId}:${JSON.stringify({ page, area, canvas, title })}`);
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
  throw new Error(`OBSERVATION_CANVAS_NOT_FRAMED:${page}:${canvasId}`);
}

async function capture(session: ArchiveUiSession, name: string, canvasId: string): Promise<void> {
  // 随机离线库不含私人账号。原图和 dumpLayout 成对保留，主机依据 Canvas bounds 比较像素，
  // 不把文案“已重建”或截图命令成功当作画面一致的证明。
  await session.driver.delayMs(250);
  const canvas = await session.driver.findComponent(ON.id(canvasId).type('Canvas'));
  if (!canvas) throw new Error(`OBSERVATION_CAPTURE_CANVAS_MISSING:${name}`);
  console.info(`OBSERVATION_CAPTURE_BOUNDS:${name}:${JSON.stringify(await canvas.getBounds())}`);
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  const image = await delegator.executeShellCommand(`uitest screenCap -p /data/local/tmp/yunheji-observation-${name}.png`);
  expect(image.exitCode).assertEqual(0);
  const layout = await delegator.executeShellCommand(`uitest dumpLayout -p /data/local/tmp/yunheji-observation-${name}.json`);
  expect(layout.exitCode).assertEqual(0);
}

export default function observationMemoryTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requested = parameters['class'] || parameters['-s class'] || '';
  // 仅由明确的样板验证选择启用，不追加到既有默认全量回归，也不提高原 240 秒时限。
  if (!requested.includes('ObservationMemoryTest')) return;
  describe('ObservationMemoryTest', () => {
    it('native_dahecun_hotspots_recorded_frame_gallery_and_replay', 0, async () => {
      const session = new ArchiveUiSession('observation_memory');
      await session.run(async () => {
        const started = Date.now();
        const siteId = 'zz-dahecun';
        const site = HERITAGE_SITES.find(item => item.id === siteId);
        const study = materialStudyForId(siteId);
        const observation = materialObservationForSite(siteId);
        if (!site || !study || !observation) throw new Error('OBSERVATION_TEST_CONTENT_MISSING');
        const body = '两只壶的腹部原来相通，换个角度再看通口。';
        const expectedYaw = 0.34 + Math.PI / 8;
        const canvasId = 'engine-native-relic_inspector';

        await session.search(site.name, 1);
        await (await inPage(session, 'explore-scroll',
          ON.id(`site-row-${siteId}`).within(ON.id('explore-site-grid')))).click();
        await session.waitId('detail-scroll');
        for (const id of ['mouth', 'paint', 'opening']) {
          const detail = observation.hotspots.find(item => item.id === id);
          const fact = study.facts.find(item => item.id === detail?.factId);
          if (!detail || !fact) throw new Error(`OBSERVATION_TEST_FACT_MISSING:${id}`);
          await (await inPage(session, 'detail-scroll', ON.id(`observation-hotspot-${id}`))).click();
          const selected = await inPage(session, 'detail-scroll', ON.id('observation-selected-detail'));
          expect(await selected.getText()).assertEqual(`正在观察 · ${detail.label}`);
          const visibleDetail = await inPage(session, 'detail-scroll', ON.id('observation-visible-detail'));
          expect(await visibleDetail.getText()).assertEqual(detail.visibleDetail);
          const reading = await inPage(session, 'detail-scroll', ON.id('engine-hotspot-reading'));
          expect(await reading.getText()).assertEqual(fact.body);
          await frameCanvas(session, 'detail-scroll', canvasId);
          await capture(session, id, canvasId);
        }
        console.info(`OBSERVATION_HOTSPOTS_MS:${Date.now() - started}`);

        // 显式右转一次，避免只保存预设镜头而掩盖相机参数未真正读回的问题。
        await (await inPage(session, 'detail-scroll', ON.id('engine-right'))).click();
        const angle = await inPage(session, 'detail-scroll', ON.id('engine-angle'));
        expect((await angle.getText()).includes(`视角 ${Math.round(expectedYaw * 180 / Math.PI)}°`)).assertTrue();
        await frameCanvas(session, 'detail-scroll', canvasId);
        await capture(session, 'source-frame', canvasId);
        await (await inPage(session, 'detail-scroll', ON.id('engine-remember-view'))).click();
        await session.waitId('note-editor-scroll');
        await session.wait(ON.id('memory-draft-preview-status').text('已恢复当时视角'), '草稿已实际绘制');
        const draftCanvas = await session.wait(ON.id('memory-draft-preview-canvas').type('Canvas'), '真实草稿预览画布');
        const draftBounds = await draftCanvas.getBounds();
        expect(draftBounds.right - draftBounds.left > 120 && draftBounds.bottom - draftBounds.top > 120).assertTrue();
        expect(await (await inPage(session, 'note-editor-scroll', ON.id('memory-draft-preview-status'))).getText())
          .assertEqual('已恢复当时视角');
        await (await inPage(session, 'note-editor-scroll', ON.id('note-body')))
          .inputText(body, { paste: true, addition: true });
        await (await inPage(session, 'note-editor-scroll', ON.id('note-tags')))
          .inputText('双连壶，腹部通口', { paste: true, addition: true });
        await session.driver.pressBack();
        await (await session.waitId('save-note')).click();
        await session.editorClosed();

        // read 会先 removePreferencesFromCache，再以真实页面 Context 打开独立库；不注入记录。
        const saved = await session.read();
        expect(saved.schemaVersion).assertEqual(1);
        const notes = activeRecords(saved.records, 'note');
        expect(notes.length).assertEqual(1);
        const note = notes[0];
        const opening = study.facts.find(item => item.id === 'dahecun-opening');
        if (!opening) throw new Error('OBSERVATION_OPENING_FACT_MISSING');
        expect(note.siteId).assertEqual(siteId);
        expect(note.body).assertEqual(body);
        expect(note.tags.join('|')).assertEqual('双连壶|腹部通口');
        expect(note.quotedPoemOrFact).assertEqual(opening.body);
        const pose = note.snapshot3DPose;
        if (!pose) throw new Error('OBSERVATION_SAVED_POSE_MISSING');
        expect(pose.version).assertEqual(1);
        expect(pose.sceneType).assertEqual('relic_inspector');
        expect(pose.proceduralPreset).assertEqual('dahecun_pottery');
        expect(pose.sceneRevision).assertEqual(2);
        expect(pose.rendererProfile).assertEqual('native-raster-v1');
        expect(pose.hotspotId).assertEqual('opening');
        expect(pose.sectionId).assertEqual('');
        expect(Math.abs(pose.yaw - expectedYaw) < 0.0001).assertTrue();
        expect(Math.abs(pose.pitch - 0.14) < 0.0001).assertTrue();
        expect(Math.abs(pose.zoom - 0.98) < 0.0001).assertTrue();
        const frame = pose.viewFrame;
        if (!frame) throw new Error('OBSERVATION_SAVED_FRAME_MISSING');
        expect(Number.isFinite(frame.width) && frame.width > 0 && Number.isFinite(frame.height) && frame.height > 0).assertTrue();
        expect(frame.textDensity !== undefined && Number.isFinite(frame.textDensity) && frame.textDensity > 0).assertTrue();
        expect(typeof frame.dark === 'boolean').assertTrue();
        console.info(`OBSERVATION_SAVED:${JSON.stringify(note)}`);
        console.info(`OBSERVATION_SAVED_MS:${Date.now() - started}`);

        await session.driver.pressBack();
        await session.waitId('explore-scroll');
        await (await session.waitId('tab-1')).click();
        await session.waitId('archive-scroll');
        await (await inPage(session, 'archive-scroll', ON.id('memory-view-gallery'))).click();
        const previewId = `memory-preview-${note.id}`;
        const previewStatus = ON.id(`${previewId}-status`).within(ON.id('archive-scroll'));
        await inPage(session, 'archive-scroll', previewStatus);
        await session.wait(ON.id(`${previewId}-status`).text('已恢复当时视角').within(ON.id('archive-scroll')), '画廊已实际绘制');
        const previewCanvasId = `${previewId}-canvas`;
        await frameCanvas(session, 'archive-scroll', previewCanvasId,
          ON.text(site.name).within(ON.id(`memory-card-${note.id}`)));
        await capture(session, 'gallery', previewCanvasId);

        // 点击已完整显示的预览 Canvas，走正式 onPose 路由；不直接启动详情或塞入回放参数。
        await (await session.wait(ON.id(previewCanvasId).type('Canvas').within(ON.id('archive-scroll')), '画廊观察画面')).click();
        await session.waitId('detail-scroll');
        await session.wait(ON.id('engine-angle').text('已回到手账视角', MatchPattern.CONTAINS), '回放实际绘制完成');
        const replayAngle = await inPage(session, 'detail-scroll', ON.id('engine-angle'));
        expect((await replayAngle.getText()).includes('已回到手账视角')).assertTrue();
        const selected = await inPage(session, 'detail-scroll', ON.id('observation-selected-detail'));
        expect(await selected.getText()).assertEqual('正在观察 · 腹部通口');
        const replayReading = await inPage(session, 'detail-scroll', ON.id('engine-hotspot-reading'));
        expect(await replayReading.getText()).assertEqual(opening.body);
        await frameCanvas(session, 'detail-scroll', canvasId);
        await capture(session, 'replay', canvasId);
        console.info(`OBSERVATION_CORE_PATH_MS:${Date.now() - started}`);
      });
    });
  });
}
