/* Generated from CultureGraphLayout.ts; source-sha256: f9dc1b1689cff13c5212ce55a129172a3b58e4da8200f1a8cafb7579e0bc164c */
(function(root) {
'use strict';

                                                   
                                               
                                                                      
 

function layoutClamp(value        , min        , max        )         {
  return Math.max(min, Math.min(max, value));
}

// ArkUI Canvas 与离线 ArkWeb 的共同数学源。Web 产物由 entry/scripts/compile-graph.mjs
// 从此文件擦除类型生成，不能分别修改两份规则；本地测试核对产物的来源哈希。
class GraphLayout {
  width        ; height        ;
  nodes                   = [];
  edges                     = [];
  fontScale         = 1;
  selectedId         = '';
  energy         = 0;
  nodeWidth         = 84;

  constructor(width         = 320, height         = 460) { this.width = width; this.height = height; }

  setData(data                  , fontScale         = 1)       {
    const previous = new Map                        ();
    this.nodes.forEach(node => previous.set(node.id, node));
    this.fontScale = layoutClamp(fontScale, 1, 1.5);
    this.nodes = data.nodes.map((node                  )                 => {
      const old = previous.get(node.id);
      return { id: node.id, label: node.label, city: node.city, era: node.era, accent: node.accent,
        x: old?.x || 0, y: old?.y || 0, vx: old?.vx || 0, vy: old?.vy || 0,
        anchorX: old?.anchorX || 0, anchorY: old?.anchorY || 0, pinned: false, dragged: old?.dragged || false };
    });
    const ids = new Set        (this.nodes.map(node => node.id));
    this.edges = data.edges.filter(edge => edge.source !== edge.target && ids.has(edge.source) && ids.has(edge.target));
    this.selectedId = ids.has(data.selectedId) ? data.selectedId : (this.nodes[0]?.id || '');
    this.place(previous);
  }

  place(previous                              = new Map                        ())       {
    const count = this.nodes.length;
    const columns = count <= 2 ? Math.max(count, 1) : (this.width >= 560 ? 4 : 3);
    const rows = Math.ceil(count / columns) || 1;
    const cellWidth = this.width / columns;
    this.nodeWidth = Math.min(84 * this.fontScale, cellWidth - 12);
    const cellHeight = (this.height - 26 * this.fontScale) / rows;
    this.nodes.forEach((node                , index        ) => {
      const row = Math.floor(index / columns), inRow = Math.min(columns, count - row * columns);
      if (!node.dragged) {
        node.anchorX = this.width / 2 + ((index % columns) - (inRow - 1) / 2) * cellWidth;
        node.anchorY = (row + 0.5) * cellHeight;
      }
      if (!previous.has(node.id)) { node.x = node.anchorX + (index % 2 ? 6 : -6); node.y = node.anchorY - 5; }
      this.bound(node);
    });
    this.energy = 1;
  }

  resize(width        , height        )       {
    if (!(width > 0 && height > 0)) return;
    this.width = width; this.height = height; this.place();
  }

  bound(node                )       {
    const half = Math.min(this.nodeWidth / 2 + 4, this.width / 2);
    node.x = layoutClamp(node.x, half, this.width - half);
    node.y = layoutClamp(node.y, 22, this.height - 42 * this.fontScale);
  }

  step()         {
    const byId = new Map                        ();
    this.nodes.forEach(node => byId.set(node.id, node));
    for (let i = 0; i < this.nodes.length; i++) {
      const a = this.nodes[i];
      for (let j = i + 1; j < this.nodes.length; j++) {
        const b = this.nodes[j];
        let dx = b.x - a.x, dy = b.y - a.y;
        if (Math.abs(dx) + Math.abs(dy) < 0.01) dx = i % 2 ? -1 : 1;
        const distance2 = Math.max(400, dx * dx + dy * dy), distance = Math.sqrt(distance2);
        const strength = 1350 / distance2;
        a.vx -= strength * dx / distance; a.vy -= strength * dy / distance;
        b.vx += strength * dx / distance; b.vy += strength * dy / distance;
        const ox = this.nodeWidth + 8 - Math.abs(dx), oy = 62 * this.fontScale - Math.abs(dy);
        if (ox > 0 && oy > 0) {
          if (ox < oy) { const push = Math.sign(dx || 1) * ox * 0.08; a.vx -= push; b.vx += push; }
          // 窄屏从七行增至八行后，边界会压缩可用行距；原 0.08 的分离力会与锚点 / 连边
          // 在仍重叠的位置抵消。只增强垂直碰撞响应，不改节点尺寸、边界或横向拖动规则。
          else { const push = Math.sign(dy || 1) * oy * 0.25; a.vy -= push; b.vy += push; }
        }
      }
    }
    this.edges.forEach(edge => {
      const a = byId.get(edge.source), b = byId.get(edge.target);
      if (!a || !b) return;
      const dx = b.x - a.x, dy = b.y - a.y, distance = Math.hypot(dx, dy) || 1;
      const force = layoutClamp((distance - 118 * this.fontScale) * 0.0025, -0.25, 0.25);
      a.vx += force * dx / distance; a.vy += force * dy / distance;
      b.vx -= force * dx / distance; b.vy -= force * dy / distance;
    });
    this.energy = 0;
    this.nodes.forEach(node => {
      if (node.pinned) { node.vx = 0; node.vy = 0; return; }
      node.vx = layoutClamp((node.vx + (node.anchorX - node.x) * 0.035) * 0.72, -5, 5);
      node.vy = layoutClamp((node.vy + (node.anchorY - node.y) * 0.035) * 0.72, -5, 5);
      node.x += node.vx; node.y += node.vy; this.bound(node);
      this.energy += Math.abs(node.vx) + Math.abs(node.vy);
    });
    return this.energy;
  }

  settle()       {
    for (let tick = 0; tick < 180; tick++) this.step();
    this.nodes.forEach(node => { node.vx = 0; node.vy = 0; }); this.energy = 0;
  }

  drag(id        , x        , y        , pinned         )       {
    const node = this.nodes.find(item => item.id === id);
    if (!node) return;
    node.x = x; node.y = y; node.pinned = pinned; node.dragged = true; node.vx = 0; node.vy = 0;
    this.bound(node); this.energy = 1;
  }
}

root.YunhejiGraphLayout = GraphLayout;
})(globalThis);
