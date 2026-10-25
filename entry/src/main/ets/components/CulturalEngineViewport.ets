import { webview } from '@kit.ArkWeb';
import { MemoryPose, MemoryViewFrame } from '../domain/ArchiveDomain';
import { resolveMemoryReplay } from '../domain/MemoryReplay';
import { materialObservationForPreset } from '../domain/MaterialObservation';
import { CulturalEnginePayload, CulturalSceneType } from '../domain/CulturalEngineContract';
import { needsObjectCanvas } from '../platform/SiteObjectCanvas';
import { CulturalHitTarget, CulturalNativeRenderer } from '../platform/CulturalNativeRenderer';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';

interface EngineCameraReply { yaw: number; pitch: number; distance: number; }
interface EngineViewReply { view: EngineCameraReply; }
interface FocusRequest { hotspotId: string; request: number; }
interface PoseRequest { request: number; }

function needsNativeCultureViewport(): boolean {
  try { return needsObjectCanvas() || !canIUse('SystemCapability.Web.Webview.Core'); }
  catch { return true; }
}

class EngineBridge {
  private select: (id: string, type: string) => void;
  private progress: (id: string, value: number) => void;
  private capture: (value: string) => void;
  private ready: (mode: string) => void;
  private interaction: () => void;
  constructor(select: (id: string, type: string) => void, progress: (id: string, value: number) => void,
    capture: (value: string) => void, ready: (mode: string) => void, interaction: () => void) {
    this.select = select; this.progress = progress; this.capture = capture; this.ready = ready; this.interaction = interaction;
  }
  onNodeSelected(id: string, type: string): void { this.select(id, type); }
  onProgressUnlocked(id: string, progress: number): void { this.progress(id, progress); }
  onCaptureSnapshot(value: string): void { this.capture(value); }
  onReady(mode: string): void { this.ready(mode); }
  onInteraction(): void { this.interaction(); }
}

// ArkUI 管理布局、主题、生命周期与可访问操作；Web 只接收纯数据，不接触账号或存储。
// 已知模拟器 ArkWeb EGL 崩溃属于进程级错误，不能靠 onError 捕获后补救，必须在创建 Web 前选原生画布。
@Component
export struct CulturalEngineViewport {
  @Prop @Watch('reload') sceneType: CulturalSceneType = 'river_sandbox';
  @Prop @Watch('reload') payloadJson: string = '{}';
  @Prop @Watch('syncMotion') active: boolean = true;
  @Prop @Watch('syncMotion') reducedMotion: boolean = false;
  @Prop viewportHeight: number = 300;
  // 留影回调由未来手账入口接收；没有实际接收者时不提供会丢失结果的操作按钮。
  @Prop captureEnabled: boolean = false;
  @Prop rememberEnabled: boolean = false;
  @Prop @Watch('applyMemoryPose') memoryPoseJson: string = '';
  // 详情页/AI 面板用独立请求序号触发聚焦与取景，不依赖 selectedId 是否变化；
  // 同一热点连续请求也能再次聚焦，且不会复用“已回到手账视角”的回放成功文案。
  @Prop @Watch('applyFocusRequest') focusRequestJson: string = '';
  @Prop @Watch('applyPoseRequest') poseRequestJson: string = '';
  @LocalStorageProp('appForeground') @Watch('syncMotion') foreground: boolean = true;
  onNodeSelected: (id: string, type: string) => void = () => {};
  onProgressUnlocked: (id: string, value: number) => void = () => {};
  onCaptureSnapshot: (value: string) => void = () => {};
  onRememberView: (pose: MemoryPose) => void = () => {};
  onReplayResult: (success: boolean, message: string) => void = () => {};
  onRememberFailure: (message: string) => void = () => {};
  @State private native: boolean = needsNativeCultureViewport();
  @State private automatic: boolean = true;
  @State private angleLabel: string = '初始视角';
  @State private captureMessage: string = '';
  @State private frameBackground: ResourceColor = T.canvas;
  private payload: CulturalEnginePayload = { version: 1 };
  private controller: webview.WebviewController = new webview.WebviewController();
  private painter: CulturalNativeRenderer = new CulturalNativeRenderer();
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private hits: CulturalHitTarget[] = [];
  private canvasWidth: number = 320;
  private canvasHeight: number = 300;
  private yaw: number = 0.25;
  private pitch: number = 0.3;
  private zoom: number = 1;
  private startYaw: number = 0;
  private startPitch: number = 0;
  private startZoom: number = 1;
  private phase: number = 0;
  private loaded: boolean = false;
  private canvasReady: boolean = false;
  private visible: boolean = false;
  private disposed: boolean = false;
  private timer: number = -1;
  private themeTimer: number = -1;
  private sceneKey: string = '';
  private pushedScene: string = '';
  private pushedPayload: string = '';
  private restoredPose: MemoryPose | undefined = undefined;
  private pushedMemoryPose: string = '';
  private replayFrame: MemoryViewFrame | undefined = undefined;
  private pendingReplayMessage: string = '';
  private bridge: EngineBridge = new EngineBridge((id: string, type: string) => this.select(id, type),
    (id: string, value: number) => this.acceptProgress(id, value), (value: string) => this.acceptCapture(value),
    (mode: string) => { if (mode === 'unavailable') this.useNative(); }, () => this.pauseAutomatic());

  aboutToAppear(): void { this.disposed = false; this.reload(); this.applyMemoryPose(); }
  aboutToDisappear(): void {
    this.disposed = true; this.stop();
    if (this.themeTimer >= 0) clearTimeout(this.themeTimer);
    if (this.loaded) this.js('window.engineDispose()');
    this.loaded = false;
  }
  onWillApplyTheme(_theme: Theme): void {
    if (this.themeTimer >= 0) clearTimeout(this.themeTimer);
    this.themeTimer = setTimeout(() => { if (!this.disposed) { this.draw(); this.push(); } }, 0);
  }
  private dark(): boolean {
    try {
      const color = this.getUIContext().getHostContext()?.resourceManager.getColorByNameSync('canvas') || 0xFAF6F0;
      return ((color >> 16) & 255) + ((color >> 8) & 255) + (color & 255) < 384;
    } catch { return false; }
  }
  private reload(): void {
    const oldSelection = this.payload.selectedId || '';
    try {
      const parsed = JSON.parse(this.payloadJson) as CulturalEnginePayload;
      if (!parsed || parsed.version !== 1) throw new Error('Unsupported viewport payload');
      this.payload = parsed;
    }
    catch { this.payload = { version: 1 }; this.captureMessage = '观察资料暂不能读取'; }
    // 精细场景与旧版示意保持独立修订，重返旧手账时不能悄悄替换其几何。
    const nextKey = `${this.sceneType}|${this.payload.itemId || ''}|${this.payload.proceduralPreset || ''}|${this.payload.sceneRevision || 1}`;
    const changed = this.sceneKey !== nextKey;
    if (this.payload.sceneRevision === 2 && !this.native) this.useNative();
    if (changed) {
      // 物件和模式切换采用各自初始镜头；不继承上个沙盘的极端旋转或双指放大。
      this.sceneKey = nextKey; this.yaw = 0.25; this.pitch = this.sceneType === 'river_sandbox' ? 0.42 : 0.3;
      this.zoom = 1; this.phase = 0;
      // 河谷和精细观察保持静止，避免无意义地持续重绘；只有文化切片 / 图谱保留缓慢动态。
      this.automatic = this.payload.sceneRevision !== 2 && this.sceneType !== 'river_sandbox';
      this.angleLabel = ''; this.captureMessage = '';
    } else if (oldSelection !== (this.payload.selectedId || '')) {
      this.automatic = false;
    }
    // 新场景的 id 不能先发给仍承载旧数据的 Web；由本次 engineLoadScene 一并应用。
    // 页面下方部位按钮通过 payload 更换选择，同样属于用户主动聚焦。
    // 初次载入保留初始状态；后续切换则清除旧回放取景并更新“已聚焦”，不能仍显示初始 / 已恢复。
    if (changed || oldSelection !== (this.payload.selectedId || '')) {
      this.focus(this.payload.selectedId || '', !changed, false);
    }
    if (changed && this.memoryPoseJson) this.applyMemoryPose();
    this.push(true); this.syncMotion();
  }
  private displayActive(): boolean { return !this.disposed && this.active && this.foreground && this.visible; }
  private useNative(): void {
    if (this.disposed || this.native) return;
    this.stop(); this.native = true; this.loaded = false; this.canvasReady = false; this.hits = [];
  }
  private js(source: string): void {
    this.controller.runJavaScript(source).catch(() => {
      if (!this.disposed) this.useNative();
    });
  }
  private push(reloadScene: boolean = false): void {
    if (!this.loaded || this.native || this.disposed) return;
    let source = `window.engineSetTheme(${this.dark()});window.engineSetReducedMotion(${this.reducedMotion});window.engineSetAutomatic(${this.automatic});`;
    if (reloadScene || this.pushedScene !== this.sceneType || this.pushedPayload !== this.payloadJson) {
      this.pushedScene = this.sceneType; this.pushedPayload = this.payloadJson;
      source += `window.engineLoadScene(${JSON.stringify(this.sceneType)},${JSON.stringify(this.payloadJson)});`;
    }
    // 主题、前后台和减少动态变化只推设置，不重载场景，因此保留用户的取景。
    source += `window.engineSetActive(${this.displayActive()});`;
    if (this.restoredPose && this.pushedMemoryPose !== this.memoryPoseJson) {
      const pose = this.restoredPose;
      source += `window.engineSetAutomatic(false);window.engineSetView(${JSON.stringify({ yaw: pose.yaw,
        pitch: pose.pitch, distance: 4.8 / pose.zoom, panX: 0, panY: 0 })});`;
      this.pushedMemoryPose = this.memoryPoseJson;
    }
    this.js(source);
  }

  private applyMemoryPose(): void {
    if (!this.memoryPoseJson) {
      this.restoredPose = undefined; this.replayFrame = undefined; this.pendingReplayMessage = '';
      this.frameBackground = T.canvas;
      this.draw();
      return;
    }
    try {
      const pose = JSON.parse(this.memoryPoseJson) as MemoryPose;
      const resolution = resolveMemoryReplay(this.payload.itemId || '', pose);
      if (!resolution.canReplay || pose.sceneType !== this.sceneType) {
        this.captureMessage = resolution.canReplay ? '保存场景与当前观察不一致' : resolution.message;
        this.pendingReplayMessage = ''; this.onReplayResult(false, this.captureMessage); return;
      }
      // 本机重建与画廊共用 Native 配置；旧视角也明确标作旧版，不把 Web 相机换算当像素一致。
      if (!this.native) this.useNative();
      this.payload.proceduralPreset = resolution.proceduralPreset;
      this.payload.sceneRevision = resolution.sceneRevision;
      this.payload.selectedId = this.sceneType === 'relic_inspector' ? pose.hotspotId : pose.sectionId;
      this.restoredPose = pose;
      this.pauseAutomatic(); this.yaw = pose.yaw; this.pitch = pose.pitch;
      this.zoom = pose.zoom; this.phase = 0;
      this.replayFrame = resolution.state === 'ready' ? resolution.viewFrame : undefined;
      this.frameBackground = this.replayFrame ? (this.replayFrame.dark ? '#171311' : '#FAF6F0') : T.canvas;
      this.captureMessage = '';
      this.pendingReplayMessage = resolution.state === 'ready' ? '已回到手账视角' : resolution.message;
      this.angleLabel = '正在重建保存画面'; this.draw(); this.push();
    } catch {
      this.captureMessage = '这张手账的视角数据暂不能读取';
      this.pendingReplayMessage = ''; this.onReplayResult(false, this.captureMessage);
    }
  }

  private applyFocusRequest(): void {
    if (!this.focusRequestJson) return;
    try {
      const request = JSON.parse(this.focusRequestJson) as FocusRequest;
      if (this.sceneType !== 'relic_inspector' || this.disposed) return;
      const observation = materialObservationForPreset(this.payload.proceduralPreset || '', this.payload.sceneRevision || 1);
      const detail = observation?.hotspots.find(item => item.id === request.hotspotId);
      if (!detail) return;
      // 无论 selectedId 是否变化都执行一次真实聚焦；手动聚焦清除旧回放取景和“已回到手账视角”文案。
      this.focus(request.hotspotId, true, true);
      this.angleLabel = `已聚焦 · ${detail.label}`;
      this.captureMessage = '';
      this.draw();
    } catch {}
  }

  private applyPoseRequest(): void {
    if (!this.poseRequestJson) return;
    // AI 草稿采纳发生在视口下方，画布可能已滚出屏幕；取景只读当前相机参数，不要求此刻可见。
    this.rememberView(true);
  }

  private async rememberView(force: boolean = false): Promise<void> {
    // 用户已经点“留住此刻”时，画布可能因页面滚动只露出一部分；
    // 相机和原画幅仍然有效，不能因为不可见就静默丢弃这次保存。
    if (this.disposed) return;
    this.pauseAutomatic();
    if (this.native && (!this.canvasReady || !this.painter.hasFrame)) {
      this.captureMessage = '观察画面正在生成，请稍后再试';
      this.onRememberFailure(this.captureMessage); return;
    }
    // 手账保存相机参数而非大图；同一程序化模型可重建视角，账号同步无需传输截图。
    // Web 使用自身当前相机回读，不能拿原生分支的未更新变量冒充用户刚操作的视角。
    if (!this.native) {
      if (!this.loaded) {
        this.captureMessage = '观察画面尚未就绪，请稍后再试';
        this.onRememberFailure(this.captureMessage); return;
      }
      try {
        let raw = await this.controller.runJavaScript('window.engineGetState()');
        if (raw.startsWith('"')) raw = JSON.parse(raw) as string;
        const state = JSON.parse(raw) as EngineViewReply;
        this.yaw = state.view.yaw; this.pitch = state.view.pitch;
        this.zoom = Math.max(0.7, Math.min(1.6, 4.8 / state.view.distance));
      } catch {
        this.captureMessage = '暂未取到视角，请稍后再试';
        this.onRememberFailure(this.captureMessage); return;
      }
    }
    const selected = this.payload.selectedId || '';
    // 通用几何展示的是资料页，保存名称不能把它写成实际器物观察；切片和已有预设沿用原文案。
    const sceneLabel: string = this.sceneType === 'stratum_slice' ? '主题切片' :
      (this.payload.proceduralPreset === 'generic_site_study' ? '资料观察' : '器物凝视');
    const pose: MemoryPose = { version: 1, sceneType: this.sceneType, yaw: this.yaw, pitch: this.pitch,
      zoom: this.zoom, hotspotId: this.sceneType === 'relic_inspector' ? selected : '',
      sectionId: this.sceneType === 'stratum_slice' ? selected : '',
      label: `${sceneLabel} · ${Math.round(this.yaw * 180 / Math.PI)}°` };
    if (this.native) {
      pose.proceduralPreset = this.payload.proceduralPreset;
      pose.sceneRevision = this.payload.sceneRevision || 1;
      pose.rendererProfile = 'native-raster-v1';
      // 保留实际参与投影的虚拟画幅；卡片和另一尺寸设备按同一画幅等比重建，不重新取景。
      pose.viewFrame = this.replayFrame ? { width: this.replayFrame.width, height: this.replayFrame.height,
        textDensity: this.replayFrame.textDensity, dark: this.replayFrame.dark } :
        { width: this.canvasWidth, height: this.canvasHeight, textDensity: this.getUIContext().fp2px(1), dark: this.dark() };
    }
    const observation = materialObservationForPreset(this.payload.proceduralPreset || '', this.payload.sceneRevision || 1);
    const detail = observation?.hotspots.find(item => item.id === selected);
    if (detail) pose.label = `${detail.label} · ${Math.round(this.yaw * 180 / Math.PI)}°`;
    console.info(`OBSERVATION_SAVED_VIEW:${JSON.stringify({ siteId: this.payload.itemId, pose })}`);
    this.onRememberView(pose);
  }
  private draw(): void {
    if (!this.native || !this.canvasReady || !this.displayActive()) return;
    const width = this.replayFrame?.width || this.canvasWidth;
    const height = this.replayFrame?.height || this.canvasHeight;
    const scale = Math.min(this.canvasWidth / width, this.canvasHeight / height);
    const left = (this.canvasWidth - width * scale) / 2;
    const top = (this.canvasHeight - height * scale) / 2;
    this.context.clearRect(0, 0, this.canvasWidth, this.canvasHeight);
    this.context.save(); this.context.translate(left, top); this.context.scale(scale, scale);
    const targets = this.painter.draw(this.context, this.sceneType, this.payload, width, height,
      this.yaw, this.pitch, this.zoom, this.replayFrame?.dark ?? this.dark(), this.phase,
      this.replayFrame?.textDensity || this.getUIContext().fp2px(1));
    this.context.restore();
    this.hits = targets.map((hit: CulturalHitTarget): CulturalHitTarget => ({ id: hit.id, type: hit.type,
      x: left + hit.x * scale, y: top + hit.y * scale, radius: hit.radius * scale }));
    if (this.pendingReplayMessage) {
      const message = this.pendingReplayMessage; this.pendingReplayMessage = '';
      if (this.painter.hasFrame) {
        this.angleLabel = message;
        console.info(`MEMORY_REPLAY_FRAME:${JSON.stringify({ siteId: this.payload.itemId, sceneType: this.sceneType,
          proceduralPreset: this.payload.proceduralPreset, sceneRevision: this.payload.sceneRevision,
          selectedId: this.payload.selectedId, yaw: this.yaw, pitch: this.pitch, zoom: this.zoom, width, height })}`);
        this.onReplayResult(true, message);
      }
      else { this.captureMessage = '保存的场景暂不能绘制'; this.onReplayResult(false, this.captureMessage); }
    }
  }
  private stop(): void { if (this.timer >= 0) clearInterval(this.timer); this.timer = -1; }
  private syncMotion(): void {
    this.stop();
    if (this.disposed) return;
    if (!this.native) {
      this.push();
      return;
    }
    // 恢复可见后先补一帧。暂停或减少动态不应导致后台收到的新 payload 一直显示旧画面。
    this.draw();
    if (!this.canvasReady || !this.displayActive() || this.reducedMotion || !this.automatic) return;
    this.timer = setInterval(() => {
      if (!this.displayActive() || this.reducedMotion || !this.automatic) { this.stop(); return; }
      this.phase += 0.07;
      if (this.sceneType === 'relic_inspector') this.yaw += 0.005;
      this.draw();
    }, 50);
  }
  private select(id: string, type: string): void {
    if (!this.displayActive()) return;
    const observation = materialObservationForPreset(this.payload.proceduralPreset || '', this.payload.sceneRevision || 1);
    const allowed = this.sceneType === 'relic_inspector' && type === 'hotspot' ?
      (observation ? observation.hotspots.some(item => item.id === id) : ['form', 'pattern', 'story'].includes(id)) :
      this.sceneType === 'stratum_slice' && type === 'layer' ? (this.payload.layers || []).some(layer => layer.id === id) :
        ((this.sceneType === 'river_sandbox' && type === 'city') || (this.sceneType === 'constellation_graph' && type === 'site')) &&
          (this.payload.nodes || []).some(node => node.id === id);
    if (!allowed) return;
    this.focus(id); this.onNodeSelected(id, type);
  }
  private focus(id: string, manual: boolean = true, sendToWeb: boolean = true): void {
    this.payload.selectedId = id;
    const observation = materialObservationForPreset(this.payload.proceduralPreset || '', this.payload.sceneRevision || 1);
    if (this.sceneType === 'relic_inspector' && id) {
      const detail = observation?.hotspots.find(item => item.id === id);
      if (detail) { this.yaw = detail.yaw; this.pitch = detail.pitch; this.zoom = detail.zoom; }
      else {
        const index = ['form', 'pattern', 'story'].indexOf(id);
        if (index >= 0) { this.yaw = [0.3, 0.95, -0.7][index]; this.pitch = [0.22, 0.1, 0.4][index]; }
      }
    }
    if (manual) {
      this.pendingReplayMessage = ''; this.replayFrame = undefined; this.frameBackground = T.canvas;
      this.pauseAutomatic(); this.captureMessage = ''; this.angleLabel = '已聚焦';
    }
    this.draw();
    if (sendToWeb && this.loaded && !this.native) this.js(`window.engineFocusHotspot(${JSON.stringify(id)})`);
  }
  private pauseAutomatic(): void {
    if (this.disposed) return;
    this.automatic = false; this.stop();
    if (this.loaded && !this.native && !this.disposed) this.js('window.engineSetAutomatic(false)');
  }
  private toggleAutomatic(): void {
    if (this.reducedMotion || !this.displayActive()) return;
    this.automatic = !this.automatic; this.angleLabel = this.automatic ? '自动浏览' : '已暂停'; this.syncMotion();
  }
  private turn(delta: number): void {
    this.pendingReplayMessage = '';
    this.pauseAutomatic(); this.yaw += delta; this.captureMessage = '';
    this.angleLabel = `视角 ${Math.round(this.yaw * 180 / Math.PI) % 360}°`; this.draw();
    // Web turn 的 value 是 0.35 弧度步数，原生按钮使用真实弧度，必须换算再发送。
    if (this.loaded && !this.native) this.js(`window.engineCommand('turn',${delta / 0.35})`);
  }
  private reset(): void {
    this.pendingReplayMessage = ''; this.replayFrame = undefined; this.frameBackground = T.canvas;
    this.pauseAutomatic(); this.yaw = 0.25; this.pitch = this.sceneType === 'river_sandbox' ? 0.42 : 0.3; this.zoom = 1;
    this.angleLabel = '初始视角'; this.captureMessage = ''; this.draw();
    if (this.loaded && !this.native) this.js("window.engineCommand('reset')");
  }
  private acceptProgress(id: string, value: number): void {
    // 仅转发显式 complete 的下一档进度。热点选择、相机聚焦都没有完成写入语义；
    // 调用方仍必须先保存自己的领域记录，再通过 exploredIds 发布持久化状态。
    if (!this.displayActive() || this.sceneType !== 'stratum_slice' || id !== this.payload.itemId ||
      !/^[A-Za-z0-9_-]{1,120}$/.test(id) || !Number.isFinite(value) || value < 0 || value > 100 || value % 25 !== 0) return;
    const layerIds = (this.payload.layers || []).map(layer => layer.id);
    if (layerIds.length !== 4 || new Set<string>(layerIds).size !== 4) return;
    const completed = new Set<string>((this.payload.exploredIds || []).filter(section => layerIds.includes(section))).size;
    if (value !== (completed + 1) * 25) return;
    this.onProgressUnlocked(id, value);
  }
  private acceptCapture(value: string): void {
    if (!this.displayActive()) return;
    // 大图只按需回调，不写入笔记 body、Preferences 或同步请求。
    if (/^data:image\/png;base64,[A-Za-z0-9+/=]+$/.test(value) && value.length < 8 * 1024 * 1024) {
      this.captureMessage = '视角留影已生成'; this.onCaptureSnapshot(value);
    } else this.captureMessage = '当前暂不能留影';
  }
  private capture(): void {
    if (!this.displayActive()) return;
    this.captureMessage = '';
    if (!this.native) { if (this.loaded) this.js('window.engineCaptureSnapshot()'); return; }
    if (!this.canvasReady) return;
    try {
      this.draw(); this.context.save();
      this.context.fillStyle = this.dark() ? '#171311' : '#FAF6F0';
      this.context.fillRect(0, this.canvasHeight - 25, this.canvasWidth, 25);
      this.context.fillStyle = this.dark() ? '#C2B2A8' : '#5C4D46';
      this.context.font = '10px sans-serif'; this.context.textAlign = 'center';
      this.context.fillText(this.sceneType === 'stratum_slice' ? '阅读主题' : '云河纪 · 观察',
        this.canvasWidth / 2, this.canvasHeight - 10);
      this.context.restore();
      // 本机 API 26 声明核验：CanvasRenderingContext2D.toDataURL 自 API 8 提供。
      // 该接口有内存复制成本，只在用户按“留影”时调用一次。
      this.acceptCapture(this.context.toDataURL('image/png')); this.draw();
    } catch { this.captureMessage = '当前暂不能留影'; this.draw(); }
  }
  private cameraHint(): string {
    return this.reducedMotion ? '已减少动态' : '拖动旋转 · 双指缩放';
  }

  build() {
    Column({ space: 12 }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        if (this.native) {
          Canvas(this.context).width('100%').height('100%').id(`engine-native-${this.sceneType}`)
            .onReady(() => { this.canvasReady = true; this.syncMotion(); })
            .onAreaChange((_old: Area, area: Area) => { this.canvasWidth = Number(area.width); this.canvasHeight = Number(area.height); this.draw(); })
            .onClick((event: ClickEvent) => {
              const target = this.hits.slice().reverse().find(hit => Math.hypot(hit.x - event.x, hit.y - event.y) <= hit.radius);
              if (target) this.select(target.id, target.type);
            })
            .gesture(GestureGroup(GestureMode.Exclusive,
              PinchGesture().onActionStart(() => { this.startZoom = this.zoom; this.pauseAutomatic(); })
                .onActionUpdate((event: GestureEvent) => { this.zoom = Math.max(0.7, Math.min(1.6, this.startZoom * event.scale)); this.draw(); }),
              PanGesture({ direction: PanDirection.Horizontal, distance: 6 })
                .onActionStart(() => { this.startYaw = this.yaw; this.startPitch = this.pitch; this.pauseAutomatic(); })
                .onActionUpdate((event: GestureEvent) => {
                  this.yaw = this.startYaw + event.offsetX * 0.01;
                  this.pitch = Math.max(-0.5, Math.min(0.8, this.startPitch + event.offsetY * 0.004));
                  this.angleLabel = `视角 ${Math.round(this.yaw * 180 / Math.PI) % 360}°`; this.draw();
                })))
        } else {
          Web({ src: $rawfile('engine/index.html'), controller: this.controller })
            .width('100%').height('100%').backgroundColor(T.canvas).javaScriptAccess(true)
            .javaScriptProxy({ object: this.bridge, name: 'EngineBridge',
              methodList: ['onNodeSelected', 'onProgressUnlocked', 'onCaptureSnapshot', 'onReady', 'onInteraction'], controller: this.controller })
            .domStorageAccess(false).databaseAccess(false).fileAccess(false).onlineImageAccess(false)
            .geolocationAccess(false).mixedMode(MixedMode.None).zoomAccess(false)
            .onOverrideUrlLoading((request: WebResourceRequest): boolean => !request.getRequestUrl().startsWith('resource://rawfile/engine/index.html'))
            .onPageEnd(() => { if (!this.disposed && !this.native) { this.loaded = true; this.push(true); } })
            .onErrorReceive((event: OnErrorReceiveEvent) => { if (event.request.isMainFrame()) this.useNative(); })
            .onRenderExited(() => this.useNative())
        }
        // 河谷沙盘只保留拖动 / 双指缩放和下方城市按钮，不再放左转、右转、复位一排工具。
        // 精细观察仍保留小胶囊，因为热点注释需要精确转角和复位；它不再占据整行。
        if (this.sceneType === 'river_sandbox') {
          Row({ space: 7 }) {
            Text('西').fontSize(10).fontColor(T.tertiary)
            Row().width(34).height(1).backgroundColor(T.line)
            Text('东').fontSize(10).fontColor(T.tertiary)
          }.width('100%').justifyContent(FlexAlign.Center)
            .position({ x: 0, y: this.viewportHeight - 26 }).hitTestBehavior(HitTestMode.None)
        }
        if (this.sceneType !== 'river_sandbox') {
          Row({ space: 2 }) {
            Button({ type: ButtonType.Circle }) {
              Text('‹').fontSize(20).fontColor(T.accent).fontWeight(FontWeight.Medium)
            }.width(30).height(30).backgroundColor(T.surface).id('engine-left')
              .accessibilityText('左转视角').onClick(() => this.turn(-Math.PI / 8))
            Button({ type: ButtonType.Circle }) {
              Text('›').fontSize(20).fontColor(T.accent).fontWeight(FontWeight.Medium)
            }.width(30).height(30).backgroundColor(T.surface).id('engine-right')
              .accessibilityText('右转视角').onClick(() => this.turn(Math.PI / 8))
            Button({ type: ButtonType.Circle }) {
              Text('↺').fontSize(16).fontColor(T.accent)
            }.width(30).height(30).backgroundColor(T.surface).id('engine-reset')
              .accessibilityText('复位视角').onClick(() => this.reset())
            if (!this.reducedMotion) {
              Button({ type: ButtonType.Circle }) {
                Text(this.automatic ? 'Ⅱ' : '▷').fontSize(14).fontColor(T.accent)
              }.width(30).height(30).backgroundColor(T.surface).id('engine-motion')
                .accessibilityText(this.automatic ? '暂停自动动态' : '继续自动动态')
                .onClick(() => this.toggleAutomatic())
            }
          }.padding(3).margin({ bottom: 10, right: 10 }).backgroundColor(T.surface)
            .border({ width: 1, color: T.line, radius: 19 }).borderRadius(19).opacity(0.94)
        }
      }.width('100%').height(this.viewportHeight).borderRadius(20).clip(true).backgroundColor(this.frameBackground)
        .id(`engine-viewport-${this.sceneType}`)
        .accessibilityText(this.sceneType === 'stratum_slice' ? '四个阅读主题的空间学习示意' : '可拖动旋转、双指缩放的文化示意视口')
        .onVisibleAreaChange([0, 0.1], (visible: boolean, ratio: number) => { this.visible = visible && ratio > 0; this.syncMotion(); })
      Row({ space: 12 }) {
        Text(this.captureMessage || (this.sceneType === 'river_sandbox' ? '拖动查看河谷 · 点选城市' :
          (this.angleLabel ? `${this.angleLabel} · ${this.cameraHint()}` : this.cameraHint())))
          .fontSize(F.caption).fontColor(T.muted).id('engine-angle').layoutWeight(1)
        if (this.captureEnabled) {
          Button('留影').id('engine-capture').onClick(() => this.capture())
            .height(36).padding({ left: 12, right: 12 }).borderRadius(12).fontSize(F.caption).fontColor(T.accent).backgroundColor(T.soft)
        }
      }.width('100%')
      if (this.rememberEnabled) {
        // 主操作统一成实心主色按钮：原来是浅色整条 + 居中文字，像网页横幅。
        Button('留住此刻 · 写一页手账').id('engine-remember-view').width('100%').height(46)
          .borderRadius(10).fontSize(14).fontColor(T.onAccent).backgroundColor(T.accent)
          .onClick(() => this.rememberView())
      }
    }.width('100%')
  }
}
