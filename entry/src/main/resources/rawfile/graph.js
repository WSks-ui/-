/* Three.js 只绘制此处的本地关联画布，页面、导航、账号和档案操作仍由 ArkUI 承担。
 * 不发网络请求、不读取存储。WebGL2 不可用时明确走 Canvas 2D 降级；两者共用同一布局与点击数据。
 * 发光和流动粒子是图谱装饰，不能称作鸿蒙沉浸光感，也不能表达未核实的历史传播方向。 */
(function () {
  'use strict';
  const host = document.getElementById('graph');
  const layout = new YunhejiGraphLayout(innerWidth, innerHeight);
  const space = new YunhejiGraphSpace();
  const labels = new Map();
  let palette = { bg: '#fdf8f6', surface: '#ffffff', ink: '#2b2225', muted: '#7a6c70',
    accent: '#c4647c', line: '#efe3e0', soft: '#fbeaf0' };
  let active = true, reduced = false, disposed = false, frame = 0, steps = 0, frameTime = 0;
  let renderer, mode = 'canvas2d';
  let projected = new Map();

  function notify(method, value) {
    try { if (window.graphBridge && typeof window.graphBridge[method] === 'function') window.graphBridge[method](value); }
    catch (_) { /* 原生页面退出时桥可能已释放，不重新发起调用。 */ }
  }
  function curve(a, b, phase) {
    const mx = (a.x + b.x) / 2 + (a.y - b.y) * 0.06;
    const my = (a.y + b.y) / 2 + (b.x - a.x) * 0.06;
    const u = 1 - phase;
    return { x: u * u * a.x + 2 * u * phase * mx + phase * phase * b.x,
      y: u * u * a.y + 2 * u * phase * my + phase * phase * b.y };
  }

  function createThreeRenderer() {
    const gpu = new THREE.WebGLRenderer({ alpha: true, antialias: true, powerPreference: 'low-power' });
    gpu.setPixelRatio(Math.min(devicePixelRatio || 1, 2));
    gpu.setClearColor(0x000000, 0);
    host.prepend(gpu.domElement);
    gpu.domElement.addEventListener('webglcontextlost', event => {
      event.preventDefault();
      cancelAnimationFrame(frame); frame = 0;
      disposeRenderer(); renderer = createCanvasRenderer(); mode = 'canvas2d';
      renderer.rebuild(); notify('onReady', mode); requestDraw();
    });
    const scene = new THREE.Scene();
    const camera = new THREE.OrthographicCamera(0, innerWidth, 0, innerHeight, -10, 10);
    camera.position.z = 5;
    let objects = [], nodes = [], edges = [];
    function clear() {
      objects.forEach(object => { scene.remove(object); object.geometry.dispose(); object.material.dispose(); });
      objects = []; nodes = []; edges = [];
    }
    function circle(radius, color, opacity) {
      const mesh = new THREE.Mesh(new THREE.CircleGeometry(radius, 32),
        new THREE.MeshBasicMaterial({ color, transparent: true, opacity, depthTest: false }));
      scene.add(mesh); objects.push(mesh); return mesh;
    }
    return {
      rebuild() {
        clear();
        layout.edges.forEach(edge => {
          const geometry = new THREE.BufferGeometry();
          geometry.setAttribute('position', new THREE.BufferAttribute(new Float32Array(63), 3));
          const material = new THREE.LineBasicMaterial({ color: palette.line, transparent: true, opacity: 0.5, depthTest: false });
          const line = new THREE.Line(geometry, material);
          line.renderOrder = 0; scene.add(line); objects.push(line);
          const particle = circle(2, palette.accent, 0);
          particle.renderOrder = 1;
          edges.push({ edge, line, particle });
        });
        layout.nodes.forEach(node => {
          const glow = circle(25, palette.accent, 0.05);
          const ring = circle(15, palette.surface, 1);
          const dot = circle(9, node.accent, 0.9);
          glow.renderOrder = 2; ring.renderOrder = 3; dot.renderOrder = 4;
          nodes.push({ node, glow, ring, dot });
        });
        this.resize();
      },
      resize() {
        gpu.setSize(layout.width, layout.height);
        camera.right = layout.width; camera.bottom = layout.height; camera.updateProjectionMatrix();
      },
      draw(time, view) {
        const byId = view.byId;
        edges.forEach((item, index) => {
          const a = byId.get(item.edge.source), b = byId.get(item.edge.target);
          const selected = a.id === layout.selectedId || b.id === layout.selectedId;
          const attribute = item.line.geometry.getAttribute('position');
          for (let sample = 0; sample <= 20; sample++) {
            const point = curve(a, b, sample / 20); attribute.setXYZ(sample, point.x, point.y, 0);
          }
          attribute.needsUpdate = true;
          item.line.geometry.computeBoundingSphere();
          item.line.material.color.set(selected ? palette.accent : palette.muted);
          item.line.material.opacity = selected ? 0.62 : 0.13;
          item.particle.material.opacity = selected && !reduced ? 0.8 : 0;
          const point = curve(a, b, ((time / 4800) + index * 0.17) % 1);
          item.particle.position.set(point.x, point.y, 0);
        });
        nodes.forEach(item => {
          const selected = item.node.id === layout.selectedId;
          const pulse = selected && !reduced ? 1 + Math.sin(time / 650) * 0.06 : 1;
          const point = byId.get(item.node.id);
          [item.glow, item.ring, item.dot].forEach((mesh, index) => {
            mesh.position.set(point.x, point.y, 0); mesh.renderOrder = 2 + point.order * 3 + index;
          });
          item.glow.material.opacity = selected ? 0.13 : 0.03;
          item.glow.scale.setScalar((selected ? 1.25 * pulse : 0.8) * point.scale);
          item.ring.scale.setScalar(point.scale);
          item.dot.material.color.set(selected ? palette.accent : item.node.accent);
          item.dot.scale.setScalar((selected ? 1.2 : 0.85) * point.scale);
          item.dot.material.opacity = Math.min(1, point.scale * 0.85);
        });
        gpu.render(scene, camera);
      },
      dispose() { clear(); gpu.dispose(); gpu.domElement.remove(); }
    };
  }

  function createCanvasRenderer() {
    const canvas = document.createElement('canvas'); host.prepend(canvas);
    const context = canvas.getContext('2d', { willReadFrequently: true });
    return {
      rebuild() { this.resize(); },
      resize() {
        const ratio = Math.min(devicePixelRatio || 1, 2);
        canvas.width = layout.width * ratio; canvas.height = layout.height * ratio;
        canvas.style.width = `${layout.width}px`; canvas.style.height = `${layout.height}px`;
        context.setTransform(ratio, 0, 0, ratio, 0, 0);
      },
      draw(time, view) {
        context.clearRect(0, 0, layout.width, layout.height);
        const byId = view.byId;
        layout.edges.forEach((edge, index) => {
          const a = byId.get(edge.source), b = byId.get(edge.target);
          const selected = a.id === layout.selectedId || b.id === layout.selectedId;
          context.beginPath(); context.moveTo(a.x, a.y);
          context.quadraticCurveTo((a.x + b.x) / 2 + (a.y - b.y) * 0.06,
            (a.y + b.y) / 2 + (b.x - a.x) * 0.06, b.x, b.y);
          context.strokeStyle = selected ? palette.accent : palette.muted;
          context.globalAlpha = selected ? 0.68 : Math.min(a.scale, b.scale) * 0.14;
          context.lineWidth = selected ? 1.5 : 0.8; context.stroke();
          if (selected && !reduced) {
            const point = curve(a, b, ((time / 4800) + index * 0.17) % 1);
            context.globalAlpha = 0.8; context.fillStyle = palette.accent;
            context.beginPath(); context.arc(point.x, point.y, 2, 0, Math.PI * 2); context.fill();
          }
        });
        view.sorted.forEach(node => {
          const selected = node.id === layout.selectedId;
          context.globalAlpha = selected ? 0.13 : 0.03; context.fillStyle = palette.accent;
          context.beginPath(); context.arc(node.x, node.y, (selected ? 29 : 20) * node.scale, 0, Math.PI * 2); context.fill();
          context.globalAlpha = 1; context.fillStyle = palette.surface;
          context.beginPath(); context.arc(node.x, node.y, 15 * node.scale, 0, Math.PI * 2); context.fill();
          context.fillStyle = selected ? palette.accent : node.accent;
          context.globalAlpha = Math.min(1, node.scale * 0.88);
          context.beginPath(); context.arc(node.x, node.y, (selected ? 11 : 8) * node.scale, 0, Math.PI * 2); context.fill();
        });
        context.globalAlpha = 1;
      },
      dispose() { canvas.remove(); }
    };
  }
  function disposeRenderer() { if (renderer) renderer.dispose(); }
  // 当前演示以已验证的 Canvas 2D 为基线，不在启动时创建 WebGL 上下文。
  // Three.js 产物和适配保留供支持设备专项验证，不能用探测触发模拟器 EGL 崩溃。
  renderer = createCanvasRenderer();

  function select(id) {
    if (!labels.has(id)) return;
    layout.selectedId = id; requestDraw(); notify('onNodeSelect', id);
  }
  function syncLabels() {
    const ids = new Set(layout.nodes.map(node => node.id));
    labels.forEach((element, id) => { if (!ids.has(id)) { element.remove(); labels.delete(id); } });
    layout.nodes.forEach(node => {
      let element = labels.get(node.id);
      if (!element) {
        element = document.createElement('button'); element.type = 'button'; element.className = 'node';
        element.id = `web-node-${node.id}`;
        const dot = document.createElement('span'); dot.className = 'dot'; dot.setAttribute('aria-hidden', 'true');
        const label = document.createElement('span'); label.className = 'label';
        const city = document.createElement('span'); city.className = 'city';
        element.append(dot, label, city); host.append(element); labels.set(node.id, element);
        // 指针在统一手势出口选择；detail=0 的键盘 / 无障碍激活仍由原生 button 点击处理。
        element.addEventListener('click', event => { if (event.detail === 0) select(node.id); });
      }
      element.querySelector('.label').textContent = node.label;
      element.querySelector('.city').textContent = `${node.city} · ${node.era}`;
      element.setAttribute('aria-label', `${node.label}，${node.city}，${node.era}，查看关联`);
    });
  }
  function draw(time) {
    const sorted = space.frame(layout.nodes, layout.width, layout.height, layout.nodeWidth, layout.fontScale);
    sorted.forEach((node, index) => { node.order = index; });
    const view = { sorted, byId: new Map(sorted.map(node => [node.id, node])) };
    projected = view.byId;
    renderer.draw(time, view);
    sorted.forEach(node => {
      const label = labels.get(node.id);
      // 用实际盒模型承接深度尺寸，不创建动态 CSS transform 合成层。
      // API 26 模拟器的 ArkWeb EGL 图像合成曾在这里崩溃；点击区与绘制仍共用投影。
      const width = node.width;
      label.style.width = `${width}px`;
      label.style.left = `${node.x - width / 2}px`; label.style.top = `${node.y - 16 * node.scale}px`;
      label.style.setProperty('--depth-scale', node.scale);
      label.style.zIndex = String(10 + node.order);
      label.setAttribute('aria-pressed', String(node.id === layout.selectedId));
    });
  }
  const pointers = new Map();
  let gesture = null;
  function centroid() {
    const values = [...pointers.values()];
    return { x: values.reduce((sum, value) => sum + value.x, 0) / values.length,
      y: values.reduce((sum, value) => sum + value.y, 0) / values.length };
  }
  function releaseNode() {
    if (!gesture?.id) return;
    const node = layout.nodes.find(item => item.id === gesture.id);
    const element = labels.get(gesture.id);
    if (element) element.dataset.dragging = 'false';
    if (node) { node.pinned = false; node.anchorX = node.x; node.anchorY = node.y; }
  }
  host.addEventListener('pointerdown', event => {
    if (event.button !== 0 && event.pointerType === 'mouse') return;
    pointers.set(event.pointerId, { x: event.clientX, y: event.clientY });
    host.setPointerCapture(event.pointerId);
    const element = event.target.closest('.node');
    if (pointers.size === 1) {
      if (element) element.suppressClick = false;
      const node = element && layout.nodes.find(item => element.id === `web-node-${item.id}`);
      const point = node && projected.get(node.id);
      gesture = { id: node?.id, kind: node ? 'node' : 'rotate', x: event.clientX, y: event.clientY,
        sx: point?.x, sy: point?.y, nx: node?.x, ny: node?.y, moved: false };
    } else {
      // 第二根手指加入后只转动视角，不能让第一根手指继续拖节点或在松手时误选。
      releaseNode();
      labels.forEach(label => { label.suppressClick = true; });
      gesture = { kind: 'rotate', ...centroid(), moved: true };
    }
  });
  host.addEventListener('pointermove', event => {
    if (!pointers.has(event.pointerId) || !gesture) return;
    pointers.set(event.pointerId, { x: event.clientX, y: event.clientY });
    const point = pointers.size > 1 ? centroid() : { x: event.clientX, y: event.clientY };
    const dx = point.x - gesture.x, dy = point.y - gesture.y;
    if (!gesture.moved && Math.hypot(dx, dy) < 7) return;
    gesture.moved = true;
    if (gesture.kind === 'rotate') {
      space.rotate(dx, dy); gesture.x = point.x; gesture.y = point.y;
    } else if (!reduced) {
      const node = layout.nodes.find(item => item.id === gesture.id);
      const label = labels.get(gesture.id);
      if (!node || !label) return;
      label.suppressClick = true; label.dataset.dragging = 'true';
      const world = space.unproject(gesture.sx + dx, gesture.sy + dy, node.era, layout.width, layout.height);
      const origin = space.unproject(gesture.sx, gesture.sy, node.era, layout.width, layout.height);
      if (world && origin) layout.drag(node.id, gesture.nx + world.x - origin.x, gesture.ny + world.y - origin.y, true);
    }
    // 减少动态模式仍允许主动调整视角，但不启动惯性或持续动画。
    requestDraw();
  });
  const releasePointer = event => {
    if (!pointers.has(event.pointerId)) return;
    if (event.type === 'pointerup' && pointers.size === 1 && gesture?.kind === 'node' && !gesture.moved) {
      select(gesture.id);
      const label = labels.get(gesture.id);
      if (label) label.suppressClick = true;
    }
    pointers.delete(event.pointerId);
    releaseNode();
    if (pointers.size) gesture = { kind: 'rotate', ...centroid(), moved: true };
    else gesture = null;
    steps = 0; requestDraw();
  };
  host.addEventListener('pointerup', releasePointer);
  host.addEventListener('pointercancel', releasePointer);
  host.addEventListener('lostpointercapture', releasePointer);
  document.getElementById('graph-turn').addEventListener('click', () => { space.rotate(48, 0); requestDraw(); });
  document.getElementById('graph-reset').addEventListener('click', () => { space.reset(); requestDraw(); });
  function loop(time) {
    frame = 0;
    if (!active || document.hidden || disposed) return;
    // 物理布局有收敛上限；选中连线仅在画布可见时继续流动。
    if (steps < 180) { layout.step(); steps++; }
    if (time - frameTime >= 30) { draw(time); frameTime = time; }
    if (!reduced) frame = requestAnimationFrame(loop);
  }
  function requestDraw() {
    if (!active || document.hidden || disposed) return;
    if (reduced) { layout.settle(); draw(0); }
    else if (!frame) frame = requestAnimationFrame(loop);
  }
  window.yunhejiGraph = {
    update(payload) {
      if (disposed) return;
      palette = payload.palette;
      Object.entries(palette).forEach(([key, value]) => document.documentElement.style.setProperty(`--${key}`, value));
      document.documentElement.style.setProperty('--font-scale', payload.fontScale);
      reduced = payload.reducedMotion === true;
      active = payload.active !== false;
      if (frame) cancelAnimationFrame(frame); frame = 0;
      layout.setData(payload, payload.fontScale); steps = 0;
      document.documentElement.style.setProperty('--node-width', `${layout.nodeWidth}px`);
      syncLabels(); renderer.rebuild(); draw(0); requestDraw();
      notify('onReady', mode);
    },
    setActive(value) {
      active = value === true;
      if (!active) { cancelAnimationFrame(frame); frame = 0; }
      else requestDraw();
    }
  };
  window.addEventListener('resize', () => {
    layout.resize(innerWidth, innerHeight);
    document.documentElement.style.setProperty('--node-width', `${layout.nodeWidth}px`);
    renderer.resize(); steps = 0; requestDraw();
  });
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) { cancelAnimationFrame(frame); frame = 0; } else requestDraw();
  });
  window.addEventListener('pagehide', () => {
    disposed = true; cancelAnimationFrame(frame); frame = 0; disposeRenderer();
  }, { once: true });
})();
