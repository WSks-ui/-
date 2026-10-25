import { abilityDelegatorRegistry, Component, MatchPattern, ON, On } from '@kit.TestKit';
import { UIAbility } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { formInfo, formProvider } from '@kit.FormKit';
import { KeyCode } from '@kit.InputKit';
import { describe, expect, it } from '@ohos/hypium';
import { ArchiveRecord, ArchiveSnapshot, activeRecords, compareVersions, parseSnapshot } from '../../../main/ets/domain/ArchiveDomain';
import { PAPER_COLUMNS, PAPER_ROWS, PaperWorkV1, copyPaperWork, createPaperWork } from '../../../main/ets/domain/PaperJourney';
import { paperWorkFromRecords } from '../../../main/ets/domain/PaperJourneyRecords';
import { PAPER_CITIES, PaperCity } from '../../../main/ets/data/PaperJourneyCatalog';
import { LocalArchiveRepository } from '../../../main/ets/data/LocalArchiveRepository';
import { createRoamingPostcard, readRoamingCardPreview } from '../../../main/ets/platform/RoamingSystem';
import { ROAMING_CONTINUE_FORM, ROAMING_MEMORY_FORM } from '../../../main/ets/roamingform/RoamingCardData';
import { ArchiveUiSession } from './ArchiveUiSession';

const BUNDLE: string = 'com.yunheji.archive';
const CARD_CACHE: string = 'yunheji_roaming_card_cache_v1';
const BODY: string = '我在纸面上留下自己的光窗，分享或从桌面回来都不应改变这一剪和这句话。';

interface RegisteredPaperForm { id: string; name: string; }
interface PaperPixels { width: number; height: number; rgba: Uint8Array; }

function city(): PaperCity {
  const selected = PAPER_CITIES.find(item => item.id === 'paper-kf');
  if (!selected) throw new Error('PAPER_SYSTEM_CITY_MISSING');
  return selected;
}

// 正式EntryAbility+独立游客库；测试不直接保存作品或note，只读回真实UI提交结果。
class PaperSystemUiSession extends ArchiveUiSession {
  private paperAbility: UIAbility | undefined = undefined;
  readonly addedForms: RegisteredPaperForm[] = [];
  readonly generatedUris: string[] = [];

  constructor(scenario: string) { super(scenario); }

  async start(_resumeAccount: boolean = false): Promise<void> {
    await abilityDelegatorRegistry.getAbilityDelegator().startAbility({ bundleName: BUNDLE, abilityName: 'EntryAbility',
      parameters: { yunhejiTestStore: this.name } });
    await this.waitId('paper-journey-home');
    await this.adoptAbility();
    expect(!await this.driver.findComponent(ON.id('login-scroll'))).assertTrue();
    console.info(`PAPER_SYSTEM_STORE:${this.name}`);
  }

  async adoptAbility(): Promise<void> {
    this.paperAbility = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility();
    expect(this.paperAbility.context.abilityInfo.name).assertEqual('EntryAbility');
    this.context = this.paperAbility.context;
    const store = await preferences.getPreferences(this.context, { name: this.name });
    expect(await store.has('snapshot')).assertTrue();
  }

  async stop(): Promise<void> {
    if (!this.paperAbility) return;
    console.info('PAPER_SYSTEM_STOP_STEP:TERMINATE_ENTRY_ABILITY');
    await this.paperAbility.context.terminateSelf();
    this.paperAbility = undefined;
    console.info('PAPER_SYSTEM_STOP_STEP:TERMINATE_REQUEST_FINISHED');
    // 由桌面卡启动的EntryAbility结束后，调用方是桌面，不保证Hypium宿主回到前台。
    // 因此只确认本应用页面确实消失；随后仍由实际桌面卡点击走onCreate，
    // 不能再等待宿主“设备回归准备中”，也不能把Home后台动作当成结束Ability。
    const pageIds: string[] = ['paper-journey-page', 'paper-memory-page', 'roaming-system-back',
      'paper-journey-home', 'paper-memory', 'paper-profile', 'paper-library'];
    let absentSamples = 0;
    let remainingIds: string[] = [];
    for (let attempt = 0; attempt < 40; attempt++) {
      remainingIds = [];
      for (const id of pageIds) if (await this.driver.findComponent(ON.id(id))) remainingIds.push(id);
      absentSamples = remainingIds.length === 0 ? absentSamples + 1 : 0;
      if (absentSamples >= 3) {
        console.info(`PAPER_SYSTEM_STOP_STEP:ENTRY_PAGES_GONE:${JSON.stringify({ absentSamples, attempt })}`);
        return;
      }
      await this.driver.delayMs(150);
    }
    console.error(`PAPER_SYSTEM_STOP_PAGES_REMAIN:${JSON.stringify(remainingIds)}`);
    throw new Error('PAPER_SYSTEM_ENTRY_ABILITY_PAGES_DID_NOT_DISAPPEAR');
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
}

async function scrollTarget(session: PaperSystemUiSession, scrollId: string, target: On,
  reachedPageId: string = ''): Promise<Component> {
  // 第二轮已确认scrollSearch的默认起点会落到HDS浮动Dock：profile切走后再次查它必然失败。
  // 根页禁用自动scrollSearch。每次只按当前页的真实安全视口中线滑动，再重新找目标；
  // 不持有旧Scroll，也不用页面左边缘手势。第一页查不到就逐屏向下，再反向检查上方。
  for (let attempt = 0; attempt < 18; attempt++) {
    if (reachedPageId && await session.driver.findComponent(ON.id(reachedPageId))) {
      console.info(`PAPER_SYSTEM_SCROLL_DESTINATION_REACHED:${reachedPageId}`);
      return session.waitId(reachedPageId);
    }
    const viewport = await (await session.waitId(scrollId)).getBounds();
    let top = viewport.top + 28;
    let bottom = viewport.bottom - 32;
    if (['paper-journey-home', 'paper-memory', 'paper-profile'].includes(scrollId)) {
      top = Math.max(top, (await (await session.waitId('top-navigation-content')).getBounds()).bottom + 28);
      bottom = Math.min(bottom, (await (await session.waitId('tab-0')).getBounds()).top - 32);
    }
    if (viewport.right <= viewport.left || bottom - top < 160) throw new Error(`PAPER_SYSTEM_NO_SAFE_SCROLL_RECT:${scrollId}`);
    let lower = attempt < 8;
    let distance = (bottom - top) * 0.45;
    const component = await session.driver.findComponent(target);
    if (component) {
      const bounds = await component.getBounds();
      if (bounds.bottom > bounds.top && bounds.right > bounds.left) {
        const center = (bounds.top + bounds.bottom) / 2;
        if (center >= top && center <= bottom) {
          const stable = await session.wait(target, scrollId);
          const current = await stable.getBounds();
          const currentCenter = (current.top + current.bottom) / 2;
          if (current.bottom > current.top && currentCenter >= top && currentCenter <= bottom) return stable;
          continue;
        }
        lower = center > bottom;
        distance = Math.min(distance, Math.max(100, lower ? center - bottom + 55 : top - center + 55));
      }
    }
    const x = Math.round((viewport.left + viewport.right) / 2);
    const start = lower ? bottom - (bottom - top) * 0.15 : top + (bottom - top) * 0.15;
    const end = start + (lower ? -distance : distance);
    console.info(`PAPER_SYSTEM_SAFE_SCROLL:${JSON.stringify({ scrollId, attempt, viewport, top, bottom, x, start, end })}`);
    await session.driver.swipe(x, Math.round(start), x, Math.round(end), 600);
    await session.driver.delayMs(180);
  }
  throw new Error(`PAPER_SYSTEM_TARGET_COVERED:${scrollId}`);
}

async function waitDisk(session: PaperSystemUiSession, matches: (snapshot: ArchiveSnapshot) => boolean): Promise<ArchiveSnapshot> {
  for (let attempt = 0; attempt < 60; attempt++) {
    const snapshot = await session.read();
    if (matches(snapshot)) return snapshot;
    await session.driver.delayMs(150);
  }
  throw new Error('PAPER_SYSTEM_DISK_NOT_CONFIRMED');
}

async function openCity(session: PaperSystemUiSession): Promise<void> {
  await (await session.waitId('paper-journey-home')).scrollToTop(2000);
  await (await scrollTarget(session, 'paper-journey-home', ON.id(`paper-home-city-${city().id}`))).click();
  await (await scrollTarget(session, 'paper-journey-home', ON.id('paper-home-start'))).click();
  await session.waitId('paper-journey-page');
}

async function cut(session: PaperSystemUiSession, row: number): Promise<PaperWorkV1> {
  const old = paperWorkFromRecords((await session.read()).records, city().id)?.mask || createPaperWork(city().id, 0).mask;
  const canvas = await session.wait(ON.id('paper-journey-scene').within(ON.id('paper-play-scene')));
  const bounds = await canvas.getBounds();
  const width = bounds.right - bounds.left;
  const height = bounds.bottom - bounds.top;
  const scale = Math.min(width / 1000, height / 1200);
  expect(scale > 0).assertTrue();
  // API26 getBounds是px；与Scene整张展开时的contain及纸面位置一致，不用全屏坐标。
  const left = bounds.left + (width - 1000 * scale) / 2;
  const top = bounds.top + (height - 1200 * scale) / 2;
  const x1 = Math.round(left + (110 + 9.5 / PAPER_COLUMNS * 780) * scale);
  const x2 = Math.round(left + (110 + 15.5 / PAPER_COLUMNS * 780) * scale);
  const y = Math.round(top + (105 + (row + 0.5) / PAPER_ROWS * 936) * scale);
  await session.driver.swipe(x1, y, x2, y, 350);
  const saved = await waitDisk(session, snapshot => {
    const work = paperWorkFromRecords(snapshot.records, city().id); return !!work && work.mask !== old;
  });
  const work = paperWorkFromRecords(saved.records, city().id);
  if (!work) throw new Error('PAPER_SYSTEM_WORK_MISSING');
  return copyPaperWork(work);
}

async function saveNote(session: PaperSystemUiSession): Promise<ArchiveRecord> {
  await (await session.waitId('paper-keep')).click();
  await (await session.waitId('paper-memory-body')).inputText(BODY);
  expect(await (await session.waitId('paper-memory-body')).getText()).assertEqual(BODY);
  await session.driver.pressBack();
  await (await session.waitId('paper-memory-save')).click();
  const saved = await waitDisk(session, snapshot => activeRecords(snapshot.records, 'note').some(note => note.body === BODY));
  const note = activeRecords(saved.records, 'note').find(record => record.body === BODY);
  if (!note || !note.paperContext) throw new Error('PAPER_SYSTEM_UI_NOTE_MISSING');
  expect(note.paperContext.work.mask !== createPaperWork(city().id, 0).mask).assertTrue();
  expect(JSON.stringify(note.paperContext.sources)).assertEqual(JSON.stringify(city().sources));
  await (await session.waitId('paper-back')).click();
  await (await session.waitId('tab-2')).click();
  await (await scrollTarget(session, 'paper-memory', ON.id(`memory-open-${note.id}`))).click();
  await session.waitId('paper-memory-page');
  return note;
}

async function decodePostcard(session: PaperSystemUiSession, work: PaperWorkV1): Promise<PaperPixels> {
  // 使用同标题/正文/出处与相同纸色，只让真实UI的mask不同；解码像素，不以PNG文件头或文件名判成功。
  const uri = await createRoamingPostcard(session.context, city().title, BODY, city().culture,
    city().sources.map(source => `${source.title}\n${source.quote}\n${source.url}`).join('\n\n'), work);
  session.generatedUris.push(uri);
  const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
  const source = image.createImageSource(file.fd);
  let pixelMap: image.PixelMap | undefined = undefined;
  try {
    const info = await source.getImageInfo();
    expect(info.mimeType).assertEqual('image/png');
    expect(info.size.width).assertEqual(1080);
    expect(info.size.height >= 1320).assertTrue();
    pixelMap = await source.createPixelMap({ desiredPixelFormat: image.PixelMapFormat.RGBA_8888 });
    const pixels = new ArrayBuffer(pixelMap.getPixelBytesNumber());
    expect(pixels.byteLength).assertEqual(info.size.width * info.size.height * 4);
    await pixelMap.readPixelsToBuffer(pixels);
    return { width: info.size.width, height: info.size.height, rgba: new Uint8Array(pixels) };
  } finally {
    if (pixelMap) await pixelMap.release();
    await source.release();
    fileIo.closeSync(file);
  }
}

async function comparePostcards(session: PaperSystemUiSession, first: PaperWorkV1, second: PaperWorkV1): Promise<void> {
  const a = await decodePostcard(session, first);
  const b = await decodePostcard(session, second);
  expect(a.width).assertEqual(b.width); expect(a.height).assertEqual(b.height);
  let changedPaperPixels = 0;
  let changedTextPixels = 0;
  for (let index = 0; index < a.rgba.length; index += 4) {
    if (a.rgba[index] === b.rgba[index] && a.rgba[index + 1] === b.rgba[index + 1] &&
      a.rgba[index + 2] === b.rgba[index + 2] && a.rgba[index + 3] === b.rgba[index + 3]) continue;
    const row = Math.floor(index / 4 / a.width);
    if (row >= 120 && row < 790) changedPaperPixels++; else changedTextPixels++;
  }
  expect(changedPaperPixels > 100).assertTrue();
  expect(changedTextPixels).assertEqual(0);
  console.info(`PAPER_SYSTEM_PNG_PIXELS:${JSON.stringify({ width: a.width, height: a.height,
    changedPaperPixels, changedTextPixels, decodedRgbaBytes: a.rgba.length })}`);
}

async function registeredForms(session: PaperSystemUiSession): Promise<RegisteredPaperForm[]> {
  await preferences.removePreferencesFromCache(session.context, CARD_CACHE);
  const store = await preferences.getPreferences(session.context, { name: CARD_CACHE });
  return JSON.parse(await store.get('forms', '[]') as string) as RegisteredPaperForm[];
}

async function waitCardCache(session: PaperSystemUiSession, note: ArchiveRecord): Promise<void> {
  for (let attempt = 0; attempt < 60; attempt++) {
    const chapter = readRoamingCardPreview(session.context, 'chapter');
    const memory = readRoamingCardPreview(session.context, 'memory');
    if (chapter.chapterId === city().id && memory.noteId === note.id &&
      chapter.testStoreName === session.name && memory.testStoreName === session.name) return;
    await session.driver.delayMs(150);
  }
  throw new Error('PAPER_SYSTEM_CARD_CACHE_NOT_READY');
}

async function openCardSettings(session: PaperSystemUiSession): Promise<void> {
  // 精确目的页已经出现才允许直接返回；这不是跳过失败，而是避免在Navigation已经
  // 接受真实入口动作后，再向被移走的profile页读bounds或重复点一次入口。
  if (await session.driver.findComponent(ON.id('roaming-system-back'))) {
    await session.waitId('roaming-system-back');
    return;
  }
  console.info('PAPER_SYSTEM_SETTINGS_STEP:OPEN_PROFILE');
  await (await session.waitId('tab-3')).click();
  await session.waitId('paper-profile');
  console.info('PAPER_SYSTEM_SETTINGS_STEP:PROFILE_VISIBLE');
  const target = await scrollTarget(session, 'paper-profile', ON.id('profile-system-cards'), 'roaming-system-back');
  if (await session.driver.findComponent(ON.id('roaming-system-back'))) {
    await session.waitId('roaming-system-back');
    console.info('PAPER_SYSTEM_SETTINGS_STEP:SYSTEM_PAGE_ALREADY_VISIBLE');
    return;
  }
  const actualId = await target.getId();
  if (actualId === 'profile-system-cards') {
    // 定位函数返回后再次核对目的页，若Navigation已完成就不再触碰旧入口Component。
    if (!await session.driver.findComponent(ON.id('roaming-system-back'))) {
      console.info('PAPER_SYSTEM_SETTINGS_STEP:CLICK_SYSTEM_ENTRY');
      await (await session.waitId('profile-system-cards')).click();
    }
  } else expect(actualId).assertEqual('roaming-system-back');
  await session.waitId('roaming-system-back');
  console.info('PAPER_SYSTEM_SETTINGS_STEP:SYSTEM_PAGE_VISIBLE');
}

async function addCard(session: PaperSystemUiSession, mode: 'chapter' | 'memory'): Promise<RegisteredPaperForm> {
  const before = await registeredForms(session);
  const scroll = await session.wait(ON.type('Scroll').isAfter(ON.id('roaming-system-back')), '桌面卡片页滚动容器');
  const button = await scroll.scrollSearch(ON.id(`roaming-add-${mode}`), true, 90);
  if (!button) throw new Error(`PAPER_SYSTEM_ADD_BUTTON_MISSING:${mode}`);
  await button.click();
  await (await session.waitText(mode === 'chapter' ? '添加这张漫游卡片' : '添加这张记忆卡片')).click();
  const name = mode === 'chapter' ? ROAMING_CONTINUE_FORM : ROAMING_MEMORY_FORM;
  for (let attempt = 0; attempt < 60; attempt++) {
    const added = (await registeredForms(session)).find(form => form.name === name && !before.some(old => old.id === form.id));
    if (added) {
      // FormExtension真实onAddForm登记后，再向FormKit核对系统返回的桌面卡片身份。
      session.addedForms.push(added);
      const published = await formProvider.getPublishedRunningFormInfoById(added.id);
      expect(published.formId).assertEqual(added.id);
      expect(published.formName).assertEqual(name);
      expect(published.bundleName).assertEqual(BUNDLE);
      expect(published.dimension).assertEqual(formInfo.FormDimension.Dimension_2_4);
      expect(published.formLocation).assertEqual(formInfo.FormLocation.DESKTOP);
      console.info(`PAPER_SYSTEM_FORM_ADDED:${JSON.stringify(added)}`);
      return added;
    }
    // 本机API26曾直接完成添加；只有识别到系统确认标题与明确“添加”按钮时才确认。
    const title = await session.driver.findComponent(ON.text('添加到桌面').type('Text'));
    const confirm = await session.driver.findComponent(ON.text('添加').type('Button'));
    if (title && confirm) await confirm.click();
    await session.driver.delayMs(150);
  }
  throw new Error(`PAPER_SYSTEM_FORM_NOT_ADDED:${mode}`);
}

async function desktopCard(session: PaperSystemUiSession, form: RegisteredPaperForm): Promise<Component> {
  await session.driver.triggerKey(KeyCode.KEYCODE_HOME);
  const workspace = await session.waitId('GridSwiper_Stack_Swiper');
  const id = `FormItem_${BUNDLE}_${form.id}column`;
  // 用系统实际formId构造已核对的原生launcher节点，不点固定屏幕位置，也不拿同名旧卡充数。
  // 卡片可能被放到相邻桌面页，手势只在已识别Swiper的真实bounds内查找。
  for (const direction of [1, -1]) {
    for (let page = 0; page < 5; page++) {
      const candidate = await session.driver.findComponent(ON.id(id));
      if (candidate) {
        const bounds = await candidate.getBounds();
        if (bounds.right > bounds.left && bounds.bottom > bounds.top) {
          await session.wait(ON.text(form.name === ROAMING_MEMORY_FORM ? '最近一页' : '继续这段漫游').within(ON.id(id)));
          await session.wait(ON.text(city().title).within(ON.id(id)));
          return session.waitId(id);
        }
      }
      const bounds = await workspace.getBounds();
      const width = bounds.right - bounds.left;
      const y = Math.round(bounds.top + (bounds.bottom - bounds.top) * 0.6);
      const x1 = bounds.left + width * (direction > 0 ? 0.82 : 0.18);
      const x2 = bounds.left + width * (direction > 0 ? 0.18 : 0.82);
      await session.driver.swipe(Math.round(x1), y, Math.round(x2), y, 1000);
      await session.driver.delayMs(180);
    }
  }
  const known = await session.driver.findComponents(ON.id(`FormItem_${BUNDLE}_`, MatchPattern.STARTS_WITH));
  const visibleIds: string[] = [];
  for (const component of known) visibleIds.push(await component.getId());
  console.error(`PAPER_SYSTEM_FORM_LOOKUP_FAILED:${JSON.stringify({ expected: id, visibleIds })}`);
  throw new Error('PAPER_SYSTEM_OWN_DESKTOP_FORM_NOT_FOUND');
}

async function assertCardRoute(session: PaperSystemUiSession, form: RegisteredPaperForm, note: ArchiveRecord,
  work: PaperWorkV1, cold: boolean): Promise<void> {
  // cold仅指EntryAbility已结束后走onCreate；整个Hypium宿主仍在，不能冒称进程force-stop验收。
  if (cold) await session.stop();
  await (await desktopCard(session, form)).click();
  await session.waitId(form.name === ROAMING_MEMORY_FORM ? 'paper-memory-page' : 'paper-journey-page');
  await session.adoptAbility();
  if (form.name === ROAMING_MEMORY_FORM) {
    expect(await (await scrollTarget(session, 'paper-memory-page', ON.id('paper-note-body'))).getText()).assertEqual(note.body);
  } else expect(await (await session.waitId('paper-goal')).getText()).assertEqual(city().goal);
  const snapshot = await session.read();
  const currentNote = snapshot.records.find(record => record.id === note.id);
  if (!currentNote) throw new Error('PAPER_SYSTEM_CARD_NOTE_MISSING');
  expect(compareVersions(currentNote, note)).assertEqual(0);
  expect(JSON.stringify(currentNote)).assertEqual(JSON.stringify(note));
  expect(JSON.stringify(paperWorkFromRecords(snapshot.records, city().id))).assertEqual(JSON.stringify(work));
  console.info(`PAPER_SYSTEM_CARD_ROUTE:${JSON.stringify({ formId: form.id, formName: form.name,
    mode: cold ? 'ability-cold-onCreate' : 'ability-hot-onNewWant', cityId: city().id, noteId: note.id,
    testStore: session.name, maskPreserved: true, frozenNotePreserved: true })}`);
}

async function removeOwnCards(session: PaperSystemUiSession): Promise<void> {
  for (const form of session.addedForms) {
    const card = await desktopCard(session, form);
    await card.longClick();
    let remove = await session.driver.findComponent(ON.text('移除卡片'));
    if (!remove) remove = await session.driver.findComponent(ON.text('移除').type('MenuItem'));
    if (!remove) remove = await session.driver.findComponent(ON.text('移除').type('Text'));
    if (!remove) throw new Error(`PAPER_SYSTEM_OWN_FORM_REMOVE_MENU_UNKNOWN:${form.id}`);
    await remove.click();
    let removed = false;
    for (let attempt = 0; attempt < 50; attempt++) {
      if (!(await registeredForms(session)).some(item => item.id === form.id)) { removed = true; break; }
      // 长按的是本轮新建的精确formId，确认也只接受“移除”而不操作应用卸载或其他卡片。
      const confirm = await session.driver.findComponent(ON.text('移除').type('Button'));
      if (confirm) await confirm.click();
      await session.driver.delayMs(150);
    }
    if (!removed) throw new Error(`PAPER_SYSTEM_OWN_FORM_NOT_REMOVED:${form.id}`);
  }
}

async function runCase(session: PaperSystemUiSession, action: () => Promise<void>): Promise<void> {
  let failed = false;
  try { await session.start(); await action(); }
  catch (error) {
    failed = true;
    // 只截独立测试库的已知应用页；未知系统分享面板可能显示联系人，仍不截图。
    try {
      const privatePage = !!await session.driver.findComponent(ON.id('login-scroll')) ||
        !!await session.driver.findComponent(ON.id('account-panel')) || !!await session.driver.findComponent(ON.id('profile-scroll')) ||
        !!await session.driver.findComponent(ON.id('share_card'));
      const knownPage = !!await session.driver.findComponent(ON.id('paper-profile')) ||
        !!await session.driver.findComponent(ON.id('paper-memory')) || !!await session.driver.findComponent(ON.id('paper-journey-home')) ||
        !!await session.driver.findComponent(ON.id('paper-journey-page')) || !!await session.driver.findComponent(ON.id('roaming-system-back'));
      if (!privatePage && knownPage) {
        const delegator = abilityDelegatorRegistry.getAbilityDelegator();
        await delegator.executeShellCommand('uitest dumpLayout -p /data/local/tmp/paper-system-failure.json -b com.yunheji.archive');
        await delegator.executeShellCommand('uitest screenCap -p /data/local/tmp/paper-system-failure.png');
      }
    } catch (captureError) { console.error(`PAPER_SYSTEM_FAILURE_CAPTURE:${(captureError as Error).message}`); }
    // 保留真正失败的原始stack。首轮重新new Error曾把定位丢到runCase，妨碍区分
    // 是旧Scroll失效、页面切换还是系统Form错误；日志与Hypium均保留原Error对象。
    if (error instanceof Error) {
      console.error(`PAPER_SYSTEM_CASE_ERROR:${error.message}\n${error.stack || ''}`);
      throw error;
    }
    throw new Error('PAPER_SYSTEM_NON_ERROR_FAILURE');
  }
  finally {
    // 不在未知系统分享界面截图；失败也不选择收件人、图库、复制或其他外部操作。
    try {
      if (session.addedForms.length > 0) await removeOwnCards(session);
      for (const uri of session.generatedUris) {
        const path = new fileUri.FileUri(uri).path;
        if (!path.startsWith(session.context.cacheDir + '/yunheji-roaming-postcard-')) throw new Error('PAPER_SYSTEM_CACHE_PATH_MISMATCH');
        fileIo.unlinkSync(path);
      }
      await session.dispose();
    } catch (error) {
      if (!failed) {
        if (error instanceof Error) throw error;
        throw new Error('PAPER_SYSTEM_NON_ERROR_CLEANUP_FAILURE');
      }
      console.error(`PAPER_SYSTEM_CLEANUP_AFTER_FAILURE:${(error as Error).message}`);
    }
  }
}

export default function paperSystemTest() {
  const parameters = abilityDelegatorRegistry.getArguments().parameters;
  const requested = parameters['class'] || parameters['-s class'] || '';
  if (!requested.includes('PaperSystemTest')) return;
  describe('PaperSystemTest', () => {
    it('native_paper_share_cancel_preserves_note_and_png_contains_real_cut_pixels', 0, async () => {
      const session = new PaperSystemUiSession('paper_native_share');
      await runCase(session, async () => {
        expect((await session.read()).records.length).assertEqual(0);
        await openCity(session);
        const first = await cut(session, 14);
        const second = await cut(session, 30);
        expect(first.mask !== second.mask).assertTrue();
        await comparePostcards(session, first, second);
        const note = await saveNote(session);
        expect(note.paperContext?.work.mask).assertEqual(second.mask);
        const before = await session.raw();
        await (await scrollTarget(session, 'paper-memory-page', ON.id('paper-note-share'))).click();
        const panel = await session.waitId('share_card');
        await session.wait(ON.id('slot_label').text('保存至图库'), '原生分享面板操作标签');
        console.info(`PAPER_SYSTEM_NATIVE_SHARE:${JSON.stringify({ panelId: await panel.getId(),
          bounds: await panel.getBounds(), noteId: note.id, receiverSelected: false })}`);
        // 取消前重新定位系统分享面板，避免向已变化的未知页面发送返回。
        expect(!!await session.driver.findComponent(ON.id('share_card'))).assertTrue();
        await session.driver.pressBack();
        await session.waitId('paper-memory-page');
        for (let attempt = 0; attempt < 40 && await session.driver.findComponent(ON.id('share_card')); attempt++) {
          await session.driver.delayMs(150);
        }
        expect(!await session.driver.findComponent(ON.id('share_card'))).assertTrue();
        expect(await session.raw()).assertEqual(before);
        const after = (await session.read()).records.find(record => record.id === note.id);
        if (!after) throw new Error('PAPER_SYSTEM_NOTE_LOST_AFTER_SHARE_CANCEL');
        expect(compareVersions(after, note)).assertEqual(0);
        expect(JSON.stringify(after)).assertEqual(JSON.stringify(note));
        expect(await (await scrollTarget(session, 'paper-memory-page', ON.id('paper-note-body'))).getText()).assertEqual(BODY);
        console.info('PAPER_SYSTEM_SHARE_CANCEL_RESULT:wholeSnapshotIdentical=true;noteVersionIdentical=true;receiverSelected=false');
      });
    });

    it('native_desktop_forms_reopen_paper_city_and_exact_note_cold_and_hot', 0, async () => {
      const session = new PaperSystemUiSession('paper_native_forms');
      await runCase(session, async () => {
        expect((await session.read()).records.length).assertEqual(0);
        await openCity(session);
        await cut(session, 19);
        const note = await saveNote(session);
        const work = paperWorkFromRecords((await session.read()).records, city().id);
        if (!work) throw new Error('PAPER_SYSTEM_CARD_WORK_MISSING');
        await session.driver.pressBack();
        await session.waitId('paper-memory');
        await waitCardCache(session, note);
        await openCardSettings(session);
        const chapter = await addCard(session, 'chapter');
        const memory = await addCard(session, 'memory');
        await assertCardRoute(session, chapter, note, work, true);
        await assertCardRoute(session, memory, note, work, false);
        await assertCardRoute(session, memory, note, work, true);
        await assertCardRoute(session, chapter, note, work, false);
      });
    });
  });
}
