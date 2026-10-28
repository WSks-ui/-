import { common, Want } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { formBindingData, formInfo, formProvider } from '@kit.FormKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DEBUG } from 'BuildProfile';

export const ROAMING_ROUTE_STORAGE_KEY: string = 'roamingLaunchRoute';
export const ROAMING_CONTINUE_FORM: string = 'RoamingContinue';
export const ROAMING_MEMORY_FORM: string = 'RoamingMemory';
const CARD_STORE: string = 'yunheji_roaming_card_cache_v1';
const DOMAIN: number = 0x0000;

// 这是已保存共享快照的派生显示，不是第二套手账或探索记录。
// 调用方只在正式快照保存 / 读取成功后发布；卡片不根据页面点击自行累加进度。
export interface RoamingCardState {
  mode: 'chapter' | 'memory' | 'empty';
  chapterId: string;
  title: string;
  excerpt: string;
  completedClues: number;
  totalClues: number;
  // 经营卡片仍使用普通2×4卡路由，只显示已落盘的段/批；旧漫游缓存缺省时保持原文案。
  marketCheckpoint?: string;
  noteId?: string;
  // 仅 Debug 独立设备验收可携带；Release 与非白名单值一律不进入卡片路由。
  testStoreName?: string;
}

export interface RoamingLaunchRoute {
  action: 'chapter' | 'memory' | 'home';
  chapterId: string;
  noteId: string;
  requestId: string;
}

interface RegisteredForm {
  id: string;
  name: string;
}

export interface RoamingCardPreview {
  cardLabel: string;
  title: string;
  excerpt: string;
  chapterId: string;
  noteId: string;
  routeAction: string;
  progressLabel: string;
  progressValue: number;
  showProgress: boolean;
  testStoreName: string;
}

interface RegisteredUpdate {
  id: string;
  data: formBindingData.FormBindingData;
}

let routeSequence: number = 0;
let writeTail: Promise<void> = Promise.resolve();

function openCardStore(context: common.Context): preferences.Preferences {
  // FormExtension 与 UIAbility 的生命周期不同，读取前刷新此派生库的进程缓存。
  // 只操作 CARD_STORE，绝不驱逐或清空正式账号档案。
  preferences.removePreferencesFromCacheSync(context, CARD_STORE);
  return preferences.getPreferencesSync(context, { name: CARD_STORE });
}

function emptyBinding(name: string): RoamingCardPreview {
  const memory: boolean = name === ROAMING_MEMORY_FORM;
  return {
    cardLabel: memory ? '最近一页' : '继续这段漫游',
    title: memory ? '等你，留下一页记忆' : '沿河，开启一城故事',
    excerpt: memory ? '亲手保存的摘录与感想，会在这里等你重读。' : '从五座城里选择一段故事，在家也能沿河发现文化线索。',
    chapterId: '', noteId: '', routeAction: memory ? 'memory' : 'home',
    progressLabel: '', progressValue: 0, showProgress: false, testStoreName: ''
  };
}

function bindingForState(state: RoamingCardState, name: string): RoamingCardPreview {
  // 测试卡片冷启动时恢复其独立测试库，仍须经过 EntryAbility 的原有 Debug 校验。
  // 不接受任意账号库名，也不把本机测试上下文带入 Release 或热启动身份切换。
  const testStoreName: string = DEBUG && typeof state.testStoreName === 'string' &&
    /^yunheji_test_ui_[a-z0-9_]{1,80}$/.test(state.testStoreName) ? state.testStoreName : '';
  if (state.mode === 'empty') {
    const empty: RoamingCardPreview = emptyBinding(name);
    empty.testStoreName = testStoreName;
    return empty;
  }
  const memory: boolean = name === ROAMING_MEMORY_FORM;
  const progressValid: boolean = Number.isFinite(state.completedClues) && Number.isFinite(state.totalClues) &&
    Number.isInteger(state.completedClues) && Number.isInteger(state.totalClues) && state.totalClues > 0 &&
    state.completedClues >= 0 && state.completedClues <= state.totalClues;
  return {
    cardLabel: memory ? '最近一页' : state.chapterId.startsWith('night-') ? '继续经营' : '继续这段漫游',
    title: state.title.trim(), excerpt: state.excerpt.trim(), chapterId: state.chapterId,
    noteId: state.noteId ?? '', routeAction: memory ? 'memory' : 'chapter',
    progressLabel: progressValid ? state.chapterId.startsWith('night-') ? state.marketCheckpoint || '回到已保存的街市' : state.chapterId.startsWith('paper-') ?
      state.completedClues > 0 ? '这张纸已亮起，可以继续创作' : '剪口与纸色会随这页保留' :
      `${state.completedClues}/${state.totalClues} 条线索已发现` : '',
    progressValue: progressValid ? state.completedClues / state.totalClues * 100 : 0,
    showProgress: progressValid, testStoreName
  };
}

function readForms(store: preferences.Preferences): RegisteredForm[] {
  try {
    const parsed = JSON.parse(store.getSync('forms', '[]') as string) as RegisteredForm[];
    if (!Array.isArray(parsed)) return [];
    return parsed.filter((item: RegisteredForm) => typeof item.id === 'string' && item.id.length > 0 &&
      (item.name === ROAMING_CONTINUE_FORM || item.name === ROAMING_MEMORY_FORM));
  } catch {
    // 仅登记表损坏时等待系统下一次 onAddForm 重建，不修改正式快照。
    hilog.warn(DOMAIN, 'RoamingForm', 'Derived form registry could not be read.');
    return [];
  }
}

function readBinding(store: preferences.Preferences, name: string): RoamingCardPreview {
  const key: string = name === ROAMING_MEMORY_FORM ? 'memory' : 'chapter';
  const value: string = store.getSync(key, '') as string;
  if (value.length === 0) return emptyBinding(name);
  try {
    const state = JSON.parse(value) as RoamingCardState;
    if (typeof state.title !== 'string' || typeof state.excerpt !== 'string' ||
      typeof state.chapterId !== 'string' ||
      (state.mode !== 'chapter' && state.mode !== 'memory' && state.mode !== 'empty')) return emptyBinding(name);
    if (state.mode !== 'empty' && ((name === ROAMING_MEMORY_FORM && state.mode !== 'memory') ||
      (name === ROAMING_CONTINUE_FORM && state.mode !== 'chapter'))) return emptyBinding(name);
    return bindingForState(state, name);
  } catch {
    // 缓存失效只展示诚实空态。原有手账 / 进度没有在这里读取，也不会被清空。
    return emptyBinding(name);
  }
}

export function roamingCardBinding(context: common.Context, name: string): formBindingData.FormBindingData {
  return formBindingData.createFormBindingData(readBinding(openCardStore(context), name));
}

export function defaultRoamingCardPreview(mode: 'chapter' | 'memory'): RoamingCardPreview {
  return emptyBinding(mode === 'memory' ? ROAMING_MEMORY_FORM : ROAMING_CONTINUE_FORM);
}

export function readRoamingCardPreview(context: common.Context, mode: 'chapter' | 'memory'): RoamingCardPreview {
  return readBinding(openCardStore(context), mode === 'memory' ? ROAMING_MEMORY_FORM : ROAMING_CONTINUE_FORM);
}

export function emptyRoamingCardBinding(want: Want): formBindingData.FormBindingData {
  const formName: Object | undefined = want.parameters?.[formInfo.FormParam.NAME_KEY];
  return formBindingData.createFormBindingData(emptyBinding(
    formName === ROAMING_MEMORY_FORM ? ROAMING_MEMORY_FORM : ROAMING_CONTINUE_FORM));
}

export function registerRoamingForm(context: common.Context, want: Want): formBindingData.FormBindingData {
  const identity: Object | undefined = want.parameters?.[formInfo.FormParam.IDENTITY_KEY];
  const formName: Object | undefined = want.parameters?.[formInfo.FormParam.NAME_KEY];
  const name: string = formName === ROAMING_MEMORY_FORM ? ROAMING_MEMORY_FORM : ROAMING_CONTINUE_FORM;
  const id: string = typeof identity === 'string' ? identity : '';
  const store = openCardStore(context);
  if (id.length > 0) {
    const forms: RegisteredForm[] = readForms(store).filter((item: RegisteredForm) => item.id !== id);
    forms.push({ id, name });
    store.putSync('forms', JSON.stringify(forms));
    store.flushSync();
  }
  return formBindingData.createFormBindingData(readBinding(store, name));
}

export function unregisterRoamingForm(context: common.Context, formId: string): void {
  const store = openCardStore(context);
  store.putSync('forms', JSON.stringify(readForms(store).filter((item: RegisteredForm) => item.id !== formId)));
  store.flushSync();
}

export async function refreshRoamingForm(context: common.Context, formId: string): Promise<void> {
  const store = openCardStore(context);
  const registered: RegisteredForm | undefined = readForms(store).find((item: RegisteredForm) => item.id === formId);
  if (registered === undefined) return;
  await formProvider.updateForm(formId, formBindingData.createFormBindingData(readBinding(store, registered.name)));
}

async function updateRegisteredForms(context: common.Context, changedName: string): Promise<void> {
  const store = openCardStore(context);
  const forms: RegisteredForm[] = readForms(store);
  // 在第一次 await 前冻结全部显示，避免另一 Ability 刷新 Preferences 缓存后
  // 继续持有已驱逐实例；卡片宿主等待也不会混入下一次保存的正文。
  const pending: RegisteredUpdate[] = forms
    .filter((registered: RegisteredForm) => changedName.length === 0 || registered.name === changedName)
    .map((registered: RegisteredForm): RegisteredUpdate => ({
      id: registered.id,
      data: formBindingData.createFormBindingData(readBinding(store, registered.name))
    }));
  let failed: number = 0;
  for (const update of pending) {
    try {
      await formProvider.updateForm(update.id, update.data);
    } catch {
      // 卡片宿主暂不可用不能回滚已保存的档案，也不伪报卡片已刷新。
      // 保留 formId，供系统 onUpdateForm 或下一次真实保存重试。
      failed++;
    }
  }
  if (failed > 0) throw new Error('ROAMING_CARD_REFRESH_PENDING');
}

export function publishRoamingCardCache(context: common.Context, state: RoamingCardState): Promise<void> {
  // 把调用时的派生值冻结；排队期间页面切换不能把新账号内容写入旧的一次刷新。
  const frozen: string = JSON.stringify(state);
  const operation = writeTail.catch(() => {}).then(async (): Promise<void> => {
    const store = openCardStore(context);
    const next = JSON.parse(frozen) as RoamingCardState;
    if (next.mode === 'empty') {
      store.deleteSync('chapter');
      store.deleteSync('memory');
    } else {
      store.putSync(next.mode === 'memory' ? 'memory' : 'chapter', frozen);
    }
    store.flushSync();
    await updateRegisteredForms(context, next.mode === 'empty' ? '' :
      next.mode === 'memory' ? ROAMING_MEMORY_FORM : ROAMING_CONTINUE_FORM);
  });
  writeTail = operation;
  return operation;
}

export function clearRoamingCardCache(context: common.Context, mode?: 'chapter' | 'memory'): Promise<void> {
  if (mode === undefined) {
    return publishRoamingCardCache(context, {
      mode: 'empty', chapterId: '', title: '', excerpt: '', completedClues: 0, totalClues: 0
    });
  }
  const operation = writeTail.catch(() => {}).then(async (): Promise<void> => {
    const store = openCardStore(context);
    // 删除最后一页只清正文与对象 ID，保留已经核验的 Debug 测试库上下文。
    // 这样空卡片冷启动仍回同一独立库；退出账号的无 mode 清理则移除两类全部缓存。
    const previous = readBinding(store, mode === 'memory' ? ROAMING_MEMORY_FORM : ROAMING_CONTINUE_FORM);
    // 兼容旧版已删掉单类缓存的情况：另一张卡仍能给出同轮已保存的测试上下文。
    const scope: string = previous.testStoreName ||
      readBinding(store, mode === 'memory' ? ROAMING_CONTINUE_FORM : ROAMING_MEMORY_FORM).testStoreName;
    const empty: RoamingCardState = {
      mode: 'empty', chapterId: '', title: '', excerpt: '', completedClues: 0, totalClues: 0,
      testStoreName: scope
    };
    store.putSync(mode, JSON.stringify(empty));
    store.flushSync();
    await updateRegisteredForms(context, mode === 'memory' ? ROAMING_MEMORY_FORM : ROAMING_CONTINUE_FORM);
  });
  writeTail = operation;
  return operation;
}

export function roamingRouteFromWant(want: Want): string {
  const rawAction: Object | undefined = want.parameters?.['roamingAction'];
  const action: string = typeof rawAction === 'string' ? rawAction : '';
  if (action !== 'chapter' && action !== 'memory' && action !== 'home') return '';
  const chapter: Object | undefined = want.parameters?.['roamingChapterId'];
  const note: Object | undefined = want.parameters?.['roamingNoteId'];
  const route: RoamingLaunchRoute = {
    action, chapterId: typeof chapter === 'string' ? chapter : '',
    noteId: typeof note === 'string' ? note : '', requestId: `${Date.now()}-${++routeSequence}`
  };
  return JSON.stringify(route);
}
