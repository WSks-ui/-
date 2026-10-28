import { common, Want } from '@kit.AbilityKit';
import { common2D, drawing, text } from '@kit.ArkGraphics2D';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { formBindingData, formInfo } from '@kit.FormKit';
import { systemShare } from '@kit.ShareKit';
import { PaperWorkV1, paperCells, PAPER_COLUMNS, PAPER_ROWS } from '../domain/PaperJourney';
import type { MarketMemoryContext } from '../domain/MarketMemory';
import {
  clearRoamingCardCache, publishRoamingCardCache, roamingCardBinding, RoamingCardState,
  ROAMING_CONTINUE_FORM, ROAMING_MEMORY_FORM
} from '../roamingform/RoamingCardData';

export {
  defaultRoamingCardPreview, readRoamingCardPreview, RoamingCardPreview, RoamingCardState,
  RoamingLaunchRoute, ROAMING_ROUTE_STORAGE_KEY
} from '../roamingform/RoamingCardData';

// SDK 核验：2026-10-23，HarmonyOS 7 / API 26。
// ShareKit 来自 HMS 的 @hms.collaboration.systemShare；这里只发起真实系统面板，
// show() 完成不代表某个第三方收到内容，也不回写 note、progress 或同步确认。
export function publishRoamingCard(context: common.Context, state: RoamingCardState): Promise<void> {
  return publishRoamingCardCache(context, state);
}

export function clearRoamingCard(context: common.Context, mode?: 'chapter' | 'memory'): Promise<void> {
  return clearRoamingCardCache(context, mode);
}

export function roamingFormWant(mode: 'chapter' | 'memory'): Want {
  return {
    bundleName: 'com.yunheji.archive', abilityName: 'RoamingFormAbility',
    parameters: {
      'ohos.extra.param.key.form_dimension': formInfo.FormDimension.Dimension_2_4,
      'ohos.extra.param.key.form_name': mode === 'memory' ? ROAMING_MEMORY_FORM : ROAMING_CONTINUE_FORM,
      'ohos.extra.param.key.module_name': 'entry',
      'ohos.extra.param.key.form_temporary': false
    }
  };
}

export function roamingFormAddData(context: common.Context, mode: 'chapter' | 'memory'): formBindingData.FormBindingData {
  return roamingCardBinding(context, mode === 'memory' ? ROAMING_MEMORY_FORM : ROAMING_CONTINUE_FORM);
}

const POSTCARD_WIDTH: number = 1080;
const PAPER: string = '#F8F2E6';
const INK: string = '#243F36';
const MUTED: string = '#657568';
let shareSequence: number = 0;
let activeShareController: systemShare.ShareController | undefined = undefined;

interface PostcardText {
  paragraph: text.Paragraph;
  top: number;
}

function postcardColor(hex: string): common2D.Color {
  return {
    alpha: 255,
    red: Number.parseInt(hex.substring(1, 3), 16),
    green: Number.parseInt(hex.substring(3, 5), 16),
    blue: Number.parseInt(hex.substring(5, 7), 16)
  };
}

async function postcardParagraph(value: string, fontSize: number, color: string,
  width: number, bold: boolean = false): Promise<text.Paragraph> {
  const builder = new text.ParagraphBuilder({
    align: text.TextAlign.LEFT,
    lineSpacing: fontSize * 0.28
  }, text.FontCollection.getGlobalInstance());
  builder.pushStyle({
    fontSize,
    color: postcardColor(color),
    fontWeight: bold ? text.FontWeight.W600 : text.FontWeight.W400
  });
  builder.addText(value);
  const paragraph: text.Paragraph = builder.build();
  await paragraph.layout(width);
  return paragraph;
}

function fillPostcardRect(canvas: drawing.Canvas, left: number, top: number,
  right: number, bottom: number, color: string): void {
  const brush = new drawing.Brush();
  brush.setColor(postcardColor(color));
  brush.setAntiAlias(true);
  canvas.attachBrush(brush);
  canvas.drawRect(left, top, right, bottom);
  canvas.detachBrush();
}

function fillPostcardPath(canvas: drawing.Canvas, path: drawing.Path, color: string): void {
  const brush = new drawing.Brush();
  brush.setColor(postcardColor(color));
  brush.setAntiAlias(true);
  canvas.attachBrush(brush);
  canvas.drawPath(path);
  canvas.detachBrush();
}

function drawOriginalRiver(canvas: drawing.Canvas): void {
  // 原创装饰图景不对应具体遗址地形，不复用或冒称用户保存的旧 pose 截图。
  fillPostcardRect(canvas, 0, 122, POSTCARD_WIDTH, 386, '#E2E9D9');
  const far = new drawing.Path();
  far.moveTo(0, 295);
  far.cubicTo(90, 245, 160, 285, 245, 210);
  far.cubicTo(330, 142, 425, 241, 520, 164);
  far.cubicTo(650, 65, 760, 216, 850, 155);
  far.cubicTo(945, 99, 1025, 159, 1080, 119);
  far.lineTo(1080, 386);
  far.lineTo(0, 386);
  far.close();
  fillPostcardPath(canvas, far, '#B8CEB4');

  const near = new drawing.Path();
  near.moveTo(0, 340);
  near.cubicTo(124, 266, 240, 364, 348, 284);
  near.cubicTo(464, 201, 560, 328, 658, 266);
  near.cubicTo(814, 173, 965, 312, 1080, 230);
  near.lineTo(1080, 386);
  near.lineTo(0, 386);
  near.close();
  fillPostcardPath(canvas, near, '#7FA78C');

  const river = new drawing.Path();
  river.moveTo(0, 321);
  river.cubicTo(150, 356, 233, 305, 368, 322);
  river.cubicTo(510, 340, 535, 390, 692, 346);
  river.cubicTo(842, 306, 965, 345, 1080, 292);
  river.lineTo(1080, 337);
  river.cubicTo(948, 386, 848, 345, 705, 382);
  river.lineTo(521, 386);
  river.cubicTo(400, 345, 240, 365, 0, 356);
  river.close();
  fillPostcardPath(canvas, river, '#D4DEC5');

  const current = new drawing.Path();
  current.moveTo(0, 338);
  current.cubicTo(150, 373, 234, 319, 365, 338);
  current.cubicTo(506, 358, 544, 398, 698, 364);
  current.cubicTo(841, 328, 960, 365, 1080, 311);
  const pen = new drawing.Pen();
  pen.setColor(postcardColor('#F7EDC9'));
  pen.setAntiAlias(true);
  pen.setStrokeWidth(3);
  canvas.attachPen(pen);
  canvas.drawPath(current);
  canvas.detachPen();

  const brush = new drawing.Brush();
  brush.setColor(postcardColor('#DFC08C'));
  brush.setAntiAlias(true);
  canvas.attachBrush(brush);
  canvas.drawCircle(899, 193, 36);
  canvas.detachBrush();
}

function drawSavedPaper(canvas: drawing.Canvas, work: PaperWorkV1): void {
  // 分享的是这一页实际保存的剪口；不拿一张通用“已完成作品”替代用户创作。
  // 平面展开图与应用中的纸景使用同一mask，原生绘制后生成真实PNG供系统分享。
  fillPostcardRect(canvas, 0, 120, POSTCARD_WIDTH, 790, '#102630');
  const sheetWidth: number = 470;
  const cell: number = sheetWidth / PAPER_COLUMNS;
  const left: number = (POSTCARD_WIDTH - sheetWidth) / 2;
  const top: number = 165;
  const cells = paperCells(work.mask);
  fillPostcardRect(canvas, left + 7, top + 8, left + sheetWidth + 7, top + cell * PAPER_ROWS + 8, '#091B23');
  fillPostcardRect(canvas, left, top, left + sheetWidth, top + cell * PAPER_ROWS, work.paper);
  for (let row = 0; row < PAPER_ROWS; row++) {
    let col = 0;
    while (col < PAPER_COLUMNS) {
      if (cells[row * PAPER_COLUMNS + col] === 0) { col++; continue; }
      const start = col;
      while (col < PAPER_COLUMNS && cells[row * PAPER_COLUMNS + col] === 1) col++;
      fillPostcardRect(canvas, left + start * cell, top + row * cell,
        left + col * cell, top + (row + 1) * cell, work.light ? '#F4D493' : '#204E4B');
    }
  }
}

function drawSavedMarket(canvas: drawing.Canvas, memory: MarketMemoryContext): void {
  // 只读这篇note冻结的六处铺位与灯火，不从当前经营存档取图。分享后的新开局、改建
  // 或另一端更新都不能把这一夜的布置换掉；这是原创纪行图，不称历史复原或现场照片。
  fillPostcardRect(canvas, 0, 120, POSTCARD_WIDTH, 640, '#102C32');
  const street = new drawing.Path();
  street.moveTo(0, 310); street.lineTo(1080, 200); street.lineTo(1080, 497);
  street.lineTo(0, 608); street.close(); fillPostcardPath(canvas, street, '#9D946B');
  const river = new drawing.Path();
  river.moveTo(0, 598); river.lineTo(1080, 487); river.lineTo(1080, 640);
  river.lineTo(0, 640); river.close(); fillPostcardPath(canvas, river, '#1C5559');
  for (const stall of memory.layout.stalls) {
    const zone = Math.floor(stall.lotId / 2);
    const left = 112 + zone * 310 + stall.lotId % 2 * 38;
    const top = 272 - zone * 32 + stall.lotId % 2 * 170;
    fillPostcardRect(canvas, left - 68, top, left + 94, top + 72, '#455D4A');
    if (!stall.type) continue;
    const roof = new drawing.Path();
    roof.moveTo(left - 86, top + 3); roof.lineTo(left - 4, top - 48);
    roof.lineTo(left + 107, top - 4); roof.lineTo(left + 90, top + 15);
    roof.lineTo(left - 73, top + 23); roof.close();
    fillPostcardPath(canvas, roof, stall.type === 'tea' ? '#70A18D' : stall.type === 'meat' ? '#BC7F60' :
      stall.type === 'lantern' ? '#D4A85F' : '#C7B47E');
    fillPostcardRect(canvas, left - 46, top + 23, left + 70, top + 54, '#D5C497');
    if (stall.type === 'lantern') {
      const lanternBrush = new drawing.Brush(); lanternBrush.setAntiAlias(true);
      lanternBrush.setColor(postcardColor('#F4C374')); canvas.attachBrush(lanternBrush);
      for (let lamp = 0; lamp < 3; lamp++) canvas.drawCircle(left - 25 + lamp * 32, top + 31, 9);
      canvas.detachBrush();
    }
    for (let worker = 0; worker < stall.workers; worker++) {
      fillPostcardRect(canvas, left - 30 + worker * 22, top + 42, left - 19 + worker * 22, top + 65, '#F1DCAD');
    }
  }
  // 灯位与巡茶属于这页冻结布置，空铺也不能使整条街的灯从分享图消失。
  // 原生PNG与页内缩图同样读取layout，不从当前继续经营的state借人手或照明。
  for (let zone = 0; zone < 3; zone++) {
    const x = 258 + zone * 310; const y = 338 - zone * 32;
    fillPostcardRect(canvas, x - 3, y - 64, x + 3, y + 42, '#5A6955');
    const brush = new drawing.Brush(); brush.setAntiAlias(true);
    brush.setColor(postcardColor(memory.layout.lamps[zone] ? '#F6CE81' : '#756B4C'));
    canvas.attachBrush(brush); canvas.drawCircle(x, y - 54, 12); canvas.detachBrush();
  }
  if (memory.layout.tourZone >= 0) {
    const x = 156 + memory.layout.tourZone * 310; const y = 410 - memory.layout.tourZone * 32;
    const brush = new drawing.Brush(); brush.setAntiAlias(true); brush.setColor(postcardColor('#ECD2A0'));
    canvas.attachBrush(brush); canvas.drawCircle(x, y - 15, 10); canvas.detachBrush();
    fillPostcardRect(canvas, x - 9, y - 5, x + 9, y + 28, '#78A88F');
    fillPostcardRect(canvas, x + 17, y, x + 31, y + 22, '#D9E4BD');
    fillPostcardRect(canvas, x + 21, y - 8, x + 27, y + 1, '#D9E4BD');
  }
}

// 独立导出供原生演示测试核对实际 PNG。生成物只进应用 cacheDir，
// 不改档案格式、不调用浏览器，也不自动写入相册或把分享动作算作探索完成。
export async function createRoamingPostcard(context: common.Context, title: string, body: string,
  excerpt: string, sourceText: string, paperWork?: PaperWorkV1, marketMemory?: MarketMemoryContext): Promise<string> {
  const content: PostcardText[] = [];
  const textWidth: number = POSTCARD_WIDTH - 144;
  let top: number = marketMemory ? 700 : paperWork ? 830 : 432;
  const titleParagraph = await postcardParagraph(title.trim(), 50, INK, textWidth, true);
  content.push({ paragraph: titleParagraph, top });
  top += titleParagraph.getHeight() + 30;

  if (excerpt.trim().length > 0) {
    const quoteLabel = await postcardParagraph('我想留住的片段', 23, MUTED, textWidth);
    content.push({ paragraph: quoteLabel, top });
    top += quoteLabel.getHeight() + 14;
    const quote = await postcardParagraph(`「${excerpt.trim()}」`, 34, '#3D715E', textWidth);
    content.push({ paragraph: quote, top });
    top += quote.getHeight() + 34;
  }
  if (body.trim().length > 0) {
    const bodyLabel = await postcardParagraph('我的一页', 23, MUTED, textWidth);
    content.push({ paragraph: bodyLabel, top });
    top += bodyLabel.getHeight() + 14;
    const thought = await postcardParagraph(body.trim(), 32, INK, textWidth);
    content.push({ paragraph: thought, top });
    top += thought.getHeight() + 38;
  }

  const sourceLabel = await postcardParagraph('资料出处', 22, MUTED, textWidth, true);
  content.push({ paragraph: sourceLabel, top });
  top += sourceLabel.getHeight() + 12;
  const sources = await postcardParagraph(sourceText.trim().length > 0 ? sourceText.trim() :
    '本页未附文化出处；文字为用户个人感想。', 22, MUTED, textWidth);
  content.push({ paragraph: sources, top });
  top += sources.getHeight() + 38;
  const identity = await postcardParagraph(marketMemory ? '云河纪 · 个人文化记忆\n本页确认保存的原创街市布置，经营参数为游戏规则' : paperWork ? '云河纪 · 个人文化记忆\n本页保存的原创纸景展开图，非文物复原或非遗工序' :
    '云河纪 · 个人文化记忆\n原创河流图景，非实景照片或原取景截图',
    20, MUTED, textWidth);
  content.push({ paragraph: identity, top });
  const height: number = Math.ceil(Math.max(1320, top + identity.getHeight() + 68));
  const pixels: ArrayBuffer = new ArrayBuffer(POSTCARD_WIDTH * height * 4);
  const pixelMap: image.PixelMap = await image.createPixelMapFromPixels(pixels, {
    size: { width: POSTCARD_WIDTH, height }, editable: true,
    srcPixelFormat: image.PixelMapFormat.RGBA_8888,
    pixelFormat: image.PixelMapFormat.RGBA_8888
  });
  const packer: image.ImagePacker = image.createImagePacker();
  let output: fileIo.File | undefined = undefined;
  const path: string = `${context.cacheDir}/yunheji-roaming-postcard-${Date.now()}-${++shareSequence}.png`;
  try {
    const canvas = new drawing.Canvas(pixelMap);
    fillPostcardRect(canvas, 0, 0, POSTCARD_WIDTH, height, PAPER);
    if (marketMemory) drawSavedMarket(canvas, marketMemory);
    else if (paperWork) drawSavedPaper(canvas, paperWork); else drawOriginalRiver(canvas);
    if (marketMemory) {
      for (const stall of marketMemory.layout.stalls) {
        if (!stall.type) continue;
        const names: string[] = ['rice', 'meat', 'tea', 'lantern'];
        const labels: string[] = ['水饭铺', '肉食铺', '茶饮铺', '灯棚'];
        const label = await postcardParagraph(labels[names.indexOf(stall.type)] || '铺子', 20, '#F6E7C5', 170, true);
        label.paint(canvas, 48 + Math.floor(stall.lotId / 2) * 310 + stall.lotId % 2 * 38,
          225 - Math.floor(stall.lotId / 2) * 32 + stall.lotId % 2 * 170);
      }
      const summary = await postcardParagraph(`接待${marketMemory.summary.served}/${marketMemory.summary.arrivals}客  ·  余钱${marketMemory.summary.cash}`,
        24, MUTED, textWidth);
      summary.paint(canvas, 72, 654);
    }
    const brand = await postcardParagraph('云 河 纪', 28, '#3D715E', textWidth, true);
    brand.paint(canvas, 72, 48);
    const caption = await postcardParagraph(marketMemory ? '开封三夜 · 留下我的一夜' : paperWork ? '纸上生城 · 留下我的一剪' : '沿河漫游 · 留下我的一页', 21, MUTED, 530);
    caption.paint(canvas, 525, 54);
    for (const item of content) item.paragraph.paint(canvas, 72, item.top);
    output = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    await packer.packToFile(pixelMap, output.fd, { format: 'image/png', quality: 100 });
  } finally {
    if (output !== undefined) fileIo.closeSync(output);
    await packer.release();
    await pixelMap.release();
  }
  return fileUri.getUriFromPath(path);
}

export async function shareRoamingMemory(context: common.UIAbilityContext, title: string, body: string,
  excerpt: string, sourceText: string, anchorId?: string, paperWork?: PaperWorkV1, marketMemory?: MarketMemoryContext): Promise<void> {
  const uri: string = await createRoamingPostcard(context, title, body, excerpt, sourceText, paperWork, marketMemory);
  const fullText: string = `${title.trim()}\n\n${excerpt.trim().length > 0 ? `摘录：${excerpt.trim()}\n\n` : ''}` +
    `${body.trim()}\n\n资料出处：\n${sourceText.trim().length > 0 ? sourceText.trim() : '本页未附文化出处。'}` +
    (marketMemory ? '\n\n云河纪 · 本页确认保存的原创街市布置，经营参数为游戏规则。' : paperWork ? '\n\n云河纪 · 本页保存的原创纸景展开图，非文物复原或非遗工序。' :
      '\n\n云河纪 · 原创河流图景，非实景照片或原取景截图。');
  const data = new systemShare.SharedData({
    utd: uniformTypeDescriptor.UniformDataType.PNG,
    uri, title, description: fullText, label: 'IMAGE'
  });
  // 单选模式让用户选择原生明信片或完整文字；PNG 同样完整绘制正文与出处，
  // 不依赖目标应用是否读取 description 才能保留文化材料的来源。
  data.addRecord({
    utd: uniformTypeDescriptor.UniformDataType.PLAIN_TEXT,
    content: fullText, title: '文字与完整出处', label: 'TEXT'
  });
  const controller = new systemShare.ShareController(data);
  const dismiss = (): void => {
    if (activeShareController === controller) activeShareController = undefined;
    controller.off('dismiss', dismiss);
  };
  controller.on('dismiss', dismiss);
  activeShareController = controller;
  const options: systemShare.ShareControllerOptions = {
    selectionMode: systemShare.SelectionMode.SINGLE,
    previewMode: systemShare.SharePreviewMode.DETAIL
  };
  if (anchorId !== undefined && anchorId.length > 0) options.anchor = anchorId;
  try {
    // 唯一启动面板的位置。调用方必须来自用户明确点按，不能在保存或打开详情时自动调用。
    await controller.show(context, options);
  } catch (error) {
    controller.off('dismiss', dismiss);
    if (activeShareController === controller) activeShareController = undefined;
    if (error instanceof Error) throw error;
    throw new Error('ROAMING_SHARE_UNAVAILABLE');
  }
}
