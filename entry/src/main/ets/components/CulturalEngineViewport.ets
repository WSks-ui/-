import { webview } from '@kit.ArkWeb';
import { CulturalEnginePayload, CulturalSceneType } from '../domain/CulturalEngineContract';
import { needsObjectCanvas } from '../platform/SiteObjectCanvas';
import { CulturalHitTarget, CulturalNativeRenderer } from '../platform/CulturalNativeRenderer';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';

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
  @LocalStorageProp('appForeground') @Watch('syncMotion') foreground: boolean = true;
  onNodeSelected: (id: string, type: string) => void = () => {};
  onProgressUnlocked: (id: string, value: number) => void = () => {};
  onCaptureSnapshot: (value: string) => void = () => {};
  @State private native: boolean = needsNativeCultureViewport();
  @State private automatic: boolean = true;
  @State private angleLabel: string = '初始视角';
  @State private captureMessage: string = '';
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
  private bridge: EngineBridge = new EngineBridge((id: string, type: string) => this.select(id, type),
    (id: string, value: number) => this.acceptProgress(id, value), (value: string) => this.acceptCapture(value),
    (mode: string) => { if (mode === 'unavailable') this.useNative(); }, () => this.pauseAutomatic());

  aboutToAppear(): void { this.disposed = false; this.reload(); }
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
    catch { this.payload = { version: 1 }; }
    const nextKey = `${this.sceneType}|${this.payload.itemId || ''}`;
    const changed = this.sceneKey !== nextKey;
    if (changed) {
      // 物件和模式切换采用各自初始镜头；不继承上个沙盘的极端旋转或双指放大。
      this.sceneKey = nextKey; this.yaw = 0.25; this.pitch = this.sceneType === 'river_sandbox' ? 0.42 : 0.3;
      this.zoom = 1; this.phase = 0; this.automatic = true; this.angleLabel = '初始视角'; this.captureMessage = '';
    } else if (oldSelection !== (this.payload.selectedId || '')) {
      this.automatic = false;
    }
    // 新场景的 id 不能先发给仍承载旧数据的 Web；由本次 engineLoadScene 一并应用。
    if (changed || oldSelection !== (this.payload.selectedId || '')) this.focus(this.payload.selectedId || '', false, false);
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
    this.js(source);
  }
  private draw(): void {
    if (!this.native || !this.canvasReady || !this.displayActive()) return;
    this.hits = this.painter.draw(this.context, this.sceneType, this.payload, this.canvasWidth, this.canvasHeight,
      this.yaw, this.pitch, this.zoom, this.dark(), this.phase, this.getUIContext().fp2px(1));
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
    const allowed = this.sceneType === 'relic_inspector' && type === 'hotspot' ? ['form', 'pattern', 'story'].includes(id) :
      this.sceneType === 'stratum_slice' && type === 'layer' ? (this.payload.layers || []).some(layer => layer.id === id) :
        ((this.sceneType === 'river_sandbox' && type === 'city') || (this.sceneType === 'constellation_graph' && type === 'site')) &&
          (this.payload.nodes || []).some(node => node.id === id);
    if (!allowed) return;
    this.focus(id); this.onNodeSelected(id, type);
  }
  private focus(id: string, manual: boolean = true, sendToWeb: boolean = true): void {
    this.payload.selectedId = id;
    if (this.sceneType === 'relic_inspector' && id) {
      const index = ['form', 'pattern', 'story'].indexOf(id);
      if (index >= 0) { this.yaw = [0.3, 0.95, -0.7][index]; this.pitch = [0.22, 0.1, 0.4][index]; }
    }
    if (manual) { this.pauseAutomatic(); this.angleLabel = '已聚焦'; }
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
    this.pauseAutomatic(); this.yaw += delta; this.captureMessage = '';
    this.angleLabel = `视角 ${Math.round(this.yaw * 180 / Math.PI) % 360}°`; this.draw();
    // Web turn 的 value 是 0.35 弧度步数，原生按钮使用真实弧度，必须换算再发送。
    if (this.loaded && !this.native) this.js(`window.engineCommand('turn',${delta / 0.35})`);
  }
  private reset(): void {
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
      this.context.fillText(this.sceneType === 'stratum_slice' ? '阅读主题学习示意 · 非实际考古地层' : '云河纪 · 程序化学习示意',
        this.canvasWidth / 2, this.canvasHeight - 10);
      this.context.restore();
      // 本机 API 26 声明核验：CanvasRenderingContext2D.toDataURL 自 API 8 提供。
      // 该接口有内存复制成本，只在用户按“留影”时调用一次。
      this.acceptCapture(this.context.toDataURL('image/png')); this.draw();
    } catch { this.captureMessage = '当前暂不能留影'; this.draw(); }
  }
  build() {
    Column({ space: 12 }) {
      Stack() {
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
      }.width('100%').height(this.viewportHeight).borderRadius(20).clip(true).backgroundColor(T.canvas)
        .id(`engine-viewport-${this.sceneType}`)
        .accessibilityText(this.sceneType === 'stratum_slice' ? '四个阅读主题的空间学习示意' : '可拖动旋转、双指缩放的文化示意视口')
        .onVisibleAreaChange([0, 0.1], (visible: boolean, ratio: number) => { this.visible = visible && ratio > 0; this.syncMotion(); })
      Row({ space: 8 }) {
        Button('左转').id('engine-left').onClick(() => this.turn(-Math.PI / 8))
          .layoutWeight(1).height(40).borderRadius(12).fontSize(F.caption).fontColor(T.accent).backgroundColor(T.soft)
        Button('右转').id('engine-right').onClick(() => this.turn(Math.PI / 8))
          .layoutWeight(1).height(40).borderRadius(12).fontSize(F.caption).fontColor(T.accent).backgroundColor(T.soft)
        Button('复位').id('engine-reset').onClick(() => this.reset())
          .layoutWeight(1).height(40).borderRadius(12).fontSize(F.caption).fontColor(T.accent).backgroundColor(T.soft)
        if (!this.reducedMotion) {
          Button(this.automatic ? '暂停' : '自动').id('engine-motion').onClick(() => this.toggleAutomatic())
            .layoutWeight(1).height(40).borderRadius(12).fontSize(F.caption).fontColor(T.accent).backgroundColor(T.soft)
            .accessibilityText(this.automatic ? '暂停视口自动动态' : '继续视口自动动态')
        }
      }.width('100%')
      Row({ space: 12 }) {
        Text(this.captureMessage || `${this.angleLabel} · ${this.reducedMotion ? '已减少动态' : '拖动旋转 · 双指缩放'}`)
          .fontSize(F.caption).fontColor(T.muted).id('engine-angle').layoutWeight(1)
        if (this.captureEnabled) {
          Button('留影').id('engine-capture').onClick(() => this.capture())
            .height(36).padding({ left: 12, right: 12 }).borderRadius(12).fontSize(F.caption).fontColor(T.accent).backgroundColor(T.soft)
        }
      }.width('100%')
    }.width('100%')
  }
}
