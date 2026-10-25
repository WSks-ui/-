/* 云河纪离线几何与投影核。只计算三维数据，不读取平台、网络或个人档案。
 * 所有轮廓均为程序化学习示意；参数变化只影响交互模型，不代表测绘或考古结论。 */
(function (root, factory) {
  'use strict';
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.CulturalEngineCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  const PI = Math.PI, TAU = PI * 2;
  const SCENES = ['river_sandbox', 'relic_inspector', 'stratum_slice', 'constellation_graph'];
  const TOKENS = {
    light: { bg: '#FAF6F0', card: '#FFFFFF', subtle: '#F4ECE4', rose: '#C45A6A', ochre: '#C88A4B',
      jade: '#5B8E8A', ink: '#2B211D', body: '#5C4D46', muted: '#96847B' },
    dark: { bg: '#171311', card: '#241E1C', subtle: '#2E2623', rose: '#E07A8A', ochre: '#C88A4B',
      jade: '#5B8E8A', ink: '#F5ECE6', body: '#C2B2A8', muted: '#85756C' }
  };
  const CITIES = ['三门峡', '洛阳', '郑州', '开封', '濮阳'];
  const HOTSPOTS = [
    { id: 'form', label: '观形制', position: [-0.86, 0.5, 0.12], yaw: -0.45, pitch: 0.22 },
    { id: 'pattern', label: '察纹样', position: [0.82, 0.04, -0.15], yaw: 0.62, pitch: 0.14 },
    { id: 'story', label: '读线索', position: [0.13, -0.75, 0.35], yaw: -0.9, pitch: 0.5 }
  ];
  const clamp = (v, min, max) => Math.max(min, Math.min(max, v));
  const finite = (v, fallback) => typeof v === 'number' && Number.isFinite(v) ? v : fallback;
  const text = (v, fallback, max = 100) => typeof v === 'string' ? v.slice(0, max) : fallback;
  const vec = (x = 0, y = 0, z = 0) => [x, y, z];
  const norm = a => { const n = Math.hypot(...a) || 1; return a.map(v => v / n); };
  const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
  const sub = (a, b) => a.map((v, i) => v - b[i]);
  function color(hex) {
    const value = /^#[0-9a-f]{6}$/i.test(hex || '') ? hex.slice(1) : 'C88A4B';
    return [0, 2, 4].map(i => parseInt(value.slice(i, i + 2), 16) / 255);
  }
  function payload(value) {
    let source = value;
    if (typeof value === 'string') {
      if (value.length > 262144) throw new Error('场景数据超出离线视口限制');
      try { source = JSON.parse(value); } catch (_) { throw new Error('场景数据不是有效 JSON'); }
    }
    if (!source || typeof source !== 'object' || Array.isArray(source)) throw new Error('场景数据需要对象');
    if(source.version!==undefined&&source.version!==1)throw new Error('场景数据版本尚未支持');
    const nodes = [], nodeIds = new Set();
    (Array.isArray(source.nodes) ? source.nodes : []).slice(0, 64).forEach(node => {
      if (!node || typeof node !== 'object') return;
      const id = text(node.id, '', 120);
      if (!id || nodeIds.has(id)) return;
      nodeIds.add(id);
      nodes.push({ id, label: text(node.label, id, 48), city: text(node.city, '', 20), era: text(node.era, '', 40),
        type: text(node.type, 'site', 24), accent: /^#[0-9a-f]{6}$/i.test(node.accent || '') ? node.accent : '#5B8E8A',
        explored: node.explored === true, highlighted: node.highlighted === true,
        x: finite(node.x, undefined), y: finite(node.y, undefined), z: finite(node.z, undefined) });
    });
    const edges = [], edgeIds = new Set();
    (Array.isArray(source.edges) ? source.edges : []).slice(0, 160).forEach(edge => {
      if (!edge || !nodeIds.has(edge.source) || !nodeIds.has(edge.target) || edge.source === edge.target) return;
      const key = [edge.source, edge.target].sort().join('|');
      if (!edgeIds.has(key)) { edges.push({ source: edge.source, target: edge.target, highlighted: edge.highlighted === true }); edgeIds.add(key); }
    });
    const layerIds = new Set(), layers = [];
    (Array.isArray(source.layers) ? source.layers : []).slice(0, 12).forEach(layer => {
      if (!layer || typeof layer !== 'object') return;
      const id = text(layer.id, '', 120);
      if (id && !layerIds.has(id)) { layers.push({ id, label: text(layer.label, id, 36), summary: text(layer.summary, '', 160) }); layerIds.add(id); }
    });
    const exploredIds = [...new Set((Array.isArray(source.exploredIds) ? source.exploredIds : [])
      .filter(id => typeof id === 'string').slice(0, 64).map(id => id.slice(0, 120)))];
    return { version: 1, itemId: text(source.itemId, '', 120), title: text(source.title, '', 80),
      proceduralPreset: text(source.proceduralPreset, 'yangshao_pottery', 64), selectedId: text(source.selectedId, '', 120),
      modelPath: text(source.modelPath, '', 200), exploredIds, nodes, edges, layers };
  }
  function mesh(name, material, tint, opacity = 1) {
    return { name, material, color: color(tint), opacity, positions: [], normals: [], uvs: [] };
  }
  function triangle(out, a, b, c, na, nb, nc, uv) {
    const n = norm(cross(sub(b, a), sub(c, a)));
    if (!Number.isFinite(n[0]) || Math.hypot(...cross(sub(b, a), sub(c, a))) < 1e-8) return;
    out.positions.push(...a, ...b, ...c); out.normals.push(...(na || n), ...(nb || n), ...(nc || n));
    out.uvs.push(...(uv || [0, 0, 1, 0, 1, 1]));
  }
  function quad(out, a, b, c, d) { triangle(out, a, b, c); triangle(out, a, c, d); }
  function box(name, center, size, tint, material = 3, opacity = 1) {
    const out = mesh(name, material, tint, opacity), [x, y, z] = center, [w, h, d] = size.map(v => v / 2);
    const p = [[x-w,y-h,z-d],[x+w,y-h,z-d],[x+w,y+h,z-d],[x-w,y+h,z-d],
      [x-w,y-h,z+d],[x+w,y-h,z+d],[x+w,y+h,z+d],[x-w,y+h,z+d]];
    [[0,3,2,1],[4,5,6,7],[0,4,7,3],[1,2,6,5],[3,7,6,2],[0,1,5,4]].forEach(f => quad(out, ...f.map(i => p[i])));
    return out;
  }
  function lathe(name, profile, tint, material = 0, segments = 48, offset = [0, 0, 0]) {
    const out = mesh(name, material, tint), vertices = [], normals = [];
    profile.forEach((p, row) => {
      const before = profile[Math.max(0, row - 1)], after = profile[Math.min(profile.length - 1, row + 1)];
      const dr = after[0] - before[0], dy = after[1] - before[1];
      for (let k = 0; k <= segments; k++) {
        const angle = k / segments * TAU, c = Math.cos(angle), s = Math.sin(angle);
        vertices.push([p[0] * c + offset[0], p[1] + offset[1], p[0] * s + offset[2]]);
        normals.push(norm([dy*c, -dr, dy*s]));
      }
    });
    for (let row = 0; row < profile.length - 1; row++) {
      for (let k = 0; k < segments; k++) {
        const a = row * (segments + 1) + k, b = a + segments + 1;
        [ [a, b, b + 1], [a, b + 1, a + 1] ].forEach(f => triangle(out, ...f.map(i => vertices[i]), ...f.map(i => normals[i])));
      }
    }
    return out;
  }
  function torus(name, center, radius, tube, tint, scale = [1, 1, 1], material = 1) {
    const out = mesh(name, material, tint), at = (a, b) => [center[0] + Math.cos(a) * (radius + Math.cos(b)*tube)*scale[0],
      center[1] + Math.sin(a) * (radius + Math.cos(b)*tube)*scale[1], center[2] + Math.sin(b)*tube*scale[2]];
    for (let i=0;i<32;i++) for (let j=0;j<8;j++) quad(out, at(i/32*TAU,j/8*TAU), at((i+1)/32*TAU,j/8*TAU),
      at((i+1)/32*TAU,(j+1)/8*TAU), at(i/32*TAU,(j+1)/8*TAU));
    return out;
  }
  function sphere(name, center, radius, tint, material = 5, segments = 12) {
    const profile = [];
    for(let i=0;i<=8;i++) { const a=i/8*PI; profile.push([Math.sin(a)*radius, -Math.cos(a)*radius]); }
    return lathe(name, profile, tint, material, segments, center);
  }
  function normalizeMeshes(meshes, size = 2.25) {
    const min=[Infinity,Infinity,Infinity], max=[-Infinity,-Infinity,-Infinity];
    meshes.forEach(m => { for(let i=0;i<m.positions.length;i++) { const axis=i%3; min[axis]=Math.min(min[axis],m.positions[i]); max[axis]=Math.max(max[axis],m.positions[i]); } });
    const extent=Math.max(...max.map((v,i)=>v-min[i]));
    if (!Number.isFinite(extent) || extent<1e-8) throw new Error('模型没有有效几何范围');
    const center=max.map((v,i)=>(v+min[i])/2), scale=size/extent;
    meshes.forEach(m => { for(let i=0;i<m.positions.length;i++) m.positions[i]=(m.positions[i]-center[i%3])*scale; });
    return meshes;
  }
  function pottery(preset) {
    const bowl=/basin|bowl|ruyao|gongyi/.test(preset), celadon=/ruyao/.test(preset), tint=celadon?'#85B1AC':'#BA704D';
    const profile=bowl?[[0,-.63],[.24,-.63],[.27,-.58],[.31,-.5],[.53,-.3],[.74,.1],[.89,.46],[.9,.51],[.85,.53],[.8,.43],[.66,.04],[.43,-.3],[.2,-.46],[0,-.46]]:
      [[0,-1],[.12,-.97],[.31,-.68],[.62,-.28],[.76,.22],[.7,.52],[.48,.75],[.28,.86],[.27,1],[.3,1.05],[.3,1.11],[.23,1.11],[.22,.88],[.2,.82]];
    const body=lathe('车削陶胎学习轮廓', profile,tint,celadon?2:0,64);
    const result=[body];
    // 独立窄纹带使软件兼容模式也有可见结构；复杂鱼纹/花瓣仅是着色器装饰，不作纹饰鉴定。
    if(!celadon) [-.12,.17,.4].forEach((y,i)=>{
      const segment=profile.findIndex((p,k)=>k<profile.length-1&&p[1]<=y&&profile[k+1][1]>y);
      const a=profile[Math.max(0,segment)],b=profile[Math.max(0,segment)+1];
      const radius=a[0]+(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+.002;
      result.push(lathe('黑彩装饰带'+i,[[radius,y],[radius+.003,y+.026]],'#49372F',6,64));
    });
    if (/gongyi/.test(preset)) result.push(torus('执壶提梁示意',[.64,.13,0],.4,.065,'#697E91',[.8,1.1,1],2));
    return result;
  }
  function bronze(ding) {
    const tint='#66867A', result=[];
    if(ding) {
      result.push(box('方鼎深腹', [0,.1,0], [1.35,1.05,1.05],tint,1));
      result.push(box('鼎口厚沿',[0,.66,0],[1.48,.12,1.17],'#A09B6C',1));
      [-1,1].forEach(x=>[-1,1].forEach(z=>result.push(box('四足',[x*.48,-.85,z*.34],[.19,.9,.19],tint,1))));
      [-1,1].forEach(x=>result.push(torus('双立耳',[x*.5,.98,0],.23,.075,tint,[.65,1,1],1)));
      [-1,1].forEach(x=>result.push(box('兽面中脊',[x*.32,.09,-.538],[.055,.7,.04],'#A6A274',1)));
    } else {
      result.push(lathe('爵腹',[ [.05,-.3],[.25,-.28],[.4,.05],[.48,.5],[.5,.63],[.44,.65],[.37,.15],[.15,-.19] ],tint,1,48));
      for(let i=0;i<3;i++) {
        const a=i/3*TAU;
        result.push(lathe('三足'+i,[[.02,-.95],[.08,-.88],[.075,-.25],[.06,-.18]],tint,1,12,[Math.cos(a)*.3,0,Math.sin(a)*.3]));
      }
      const spout=mesh('流与尾的抽象轮廓',1,tint);
      quad(spout,[-.34,.5,-.28],[.34,.5,-.28],[.18,.69,-1],[-.18,.69,-1]);
      quad(spout,[-.13,.5,.35],[.13,.5,.35],[.07,.7,.78],[-.07,.7,.78]);
      result.push(spout,torus('爵鋬',[.48,.16,0],.24,.06,tint,[.7,1.25,1],1));
      [-1,1].forEach(x=>result.push(lathe('双柱',[[.055,.57],[.045,.85],[.09,.86],[.095,.89]],'#B5A66A',1,12,[x*.3,0,-.32])));
    }
    return result;
  }
  function pagoda(baseOnly) {
    const result=[], levels=baseOnly?3:13;
    for(let i=0;i<levels;i++) {
      const y=-1+i*(2/levels), r=.52*(1-i/(levels+3));
      result.push(lathe('八角塔身'+i,[[r,y],[r,y+1.38/levels],[r*1.04,y+1.4/levels]],'#9D7655',3,8));
      result.push(lathe('逐层收分檐'+i,[[r*.97,y+1.33/levels],[r*1.25,y+1.38/levels],[r*.9,y+1.85/levels]],'#6B6556',3,8));
    }
    result.push(lathe('塔刹',[[.13,1],[.11,1.11],[.055,1.15],[.045,1.4],[0,1.52]],'#C39558',1,12));
    return result;
  }
  function palace(preset) {
    const result=[], wall=/wall/.test(preset), altar=/altar|stratum/.test(preset);
    for(let i=0;i<3;i++)result.push(box('层叠台基'+i,[0,-.8+i*.2,0],[2.1-i*.28,.2,1.55-i*.16],'#C49663',3));
    if(wall) {
      [-1,1].forEach(z=>result.push(box('有厚度的城垣',[0,-.05,z*.62],[2.05,.9,.18],'#B58B5C',3)));
      [-1,1].forEach(x=>result.push(box('城门两翼',[x*.82,-.05,0],[.26,.9,1.1],'#C49B68',3)));
    } else if(!altar) {
      for(let x=-1;x<=1;x++)[-1,1].forEach(z=>result.push(lathe('柱网',[[.06,-.3],[.06,.45]],'#985C4F',3,12,[x*.64,0,z*.39])));
      result.push(box('殿檐',[0,.43,0],[2,.13,1.25],'#6D7870',3));
      const roof=mesh('屋顶几何示意',3,'#67766E');
      quad(roof,[-1.06,.5,-.72],[1.06,.5,-.72],[.9,.9,0],[-.9,.9,0]);
      quad(roof,[-.9,.9,0],[.9,.9,0],[1.06,.5,.72],[-1.06,.5,.72]);result.push(roof);
    }
    return result;
  }
  function shellDragon() {
    const result=[box('考古探方学习底板',[0,-.38,0],[2.35,.15,1.8],'#C6A17D',3)];
    // 蚌壳位置由曲线构造，只表达拼塑材料与轮廓，不复制墓葬位置、尺寸或出土平面。
    for(let i=0;i<62;i++) {
      const t=i/61, a=t*PI*2.25, r=.13+t*.65;
      const x=Math.cos(a)*r, z=Math.sin(a)*r*.83;
      result.push(sphere('蚌壳'+i,[x,-.25+Math.sin(t*PI)*.035,z],.043,'#EDE3CA',2,6));
      if(i%2===0)result.push(sphere('并列蚌壳'+i,[x+.075,-.25,z+.04],.039,'#E9DDC3',2,6));
    }
    result.push(sphere('龙首学习轮廓',[.62,-.2,.48],.15,'#EFE7D3',2,12));
    [-1,1].forEach(s=>result.push(box('角状示意',[.62+s*.11,-.17,.38],[.04,.08,.26],'#E7DAC1',2)));
    return result;
  }
  function neutralSite(preset) {
    // 元数据以既有稳定条目为准。没有条目级测绘/造像资料时使用中性空间轮廓，
    // 不把所有遗址、纪念馆或墓地误兜底成陶罐，也不臆造洞窟造像和出土平面。
    const out=[];
    if(/bridge/.test(preset)) {
      out.push(box('桥梁桥面学习轮廓',[0,.16,0],[2.3,.2,.78],'#C5A781',3));
      [-.8,0,.8].forEach(x=>out.push(box('桥墩学习轮廓',[x,-.35,0],[.23,.85,.59],'#AB8B6A',3)));
      [-1,1].forEach(z=>out.push(box('桥侧轮廓',[0,.39,z*.35],[2.3,.1,.08],'#D3BE9C',3)));
    } else if(/cliff/.test(preset)) {
      out.push(box('崖壁学习轮廓',[0,.15,.13],[2.2,1.4,.58],'#BBA58B',3),box('崖壁基座',[0,-.65,0],[2.4,.22,1.05],'#C8B392',3));
      [-.7,0,.7].forEach(x=>out.push(box('无造像洞窟轮廓',[x,.12,-.172],[.39,.72,.025],'#766E62',6)));
    } else if(/tomb/.test(preset)) {
      out.push(box('墓葬观察学习底板',[0,-.25,0],[2.3,.2,1.7],'#C3A27D',3));
      [-.68,0,.68].forEach(x=>out.push(box('中性遗存观察框',[x,-.12,0],[.43,.08,.97],'#A48463',3)));
    } else if(/settlement/.test(preset)) {
      out.push(box('聚落观察学习底板',[0,-.35,0],[2.3,.18,1.7],'#C4A37B',3));
      for(let i=0;i<6;i++)out.push(box('聚落布局学习符号'+i,[(i%3-1)*.62,-.12,(Math.floor(i/3)-.5)*.69],[.42,.29,.4],i%2?'#AD7857':'#D3B08B',3));
    } else if(/shells/.test(preset)) {
      out.push(box('蚌壳观察学习底板',[0,-.2,0],[2.25,.16,1.55],'#C2A17E',3));
      for(let i=0;i<30;i++)out.push(sphere('中性蚌壳观察点'+i,[(i%6-2.5)*.29,-.07,(Math.floor(i/6)-2)*.24],.055,'#EEE4D0',2,8));
    } else {
      out.push(box('纪念空间学习台基',[0,-.62,0],[1.8,.18,1.1],'#C4A682',3),
        box('无铭文纪念轮廓',[0,.03,0],[.69,1.2,.23],'#A9947A',3),box('中性观察基座',[0,-.44,0],[1.04,.2,.51],'#B69E7D',3));
    }
    return normalizeMeshes(out);
  }
  function relic(preset) {
    if(preset==='generic_site_study') {
      // 与原生端同为三张抽象资料卡，不套用城址、窑炉或文物轮廓。
      // 后续独立场景必须保留本预设的 revision 1 和旧手账解析，不能替换这组学习几何。
      return normalizeMeshes([
        box('study-overview-card',[-.48,.12,-.18],[.72,1,.07],'#E6D3BB',3),
        box('study-observation-card',[0,0,0],[.72,1,.07],'#C88A4B',3),
        box('study-history-card',[.48,-.12,.18],[.72,1,.07],'#5B8E8A',3)
      ]);
    }
    const aliases={miaodigou_pottery:'miaodigou_rose_basin',dahecun_pottery:'dahecun_star_bowl',
      duling_fangding:'zhengzhou_ding',qicheng_site:'qicheng_altar',yanshi_city:'erlitou_palace',
      hanwei_city:'hanwei_palace',zhenghan_city:'zhengzhou_wall',xishuipo_site:'excavation_shells'};
    preset=aliases[preset]||preset;
    if(/tomb|settlement|cliff|bridge|memorial|shells/.test(preset))return neutralSite(preset);
    if(/ding/.test(preset))return normalizeMeshes(bronze(true));
    if(/bronze/.test(preset))return normalizeMeshes(bronze(false));
    if(/dragon/.test(preset))return normalizeMeshes(shellDragon());
    if(/pagoda/.test(preset))return normalizeMeshes(pagoda(/base|fanta/.test(preset)));
    if(/palace|yingtianmen|wall|altar|stratum/.test(preset))return normalizeMeshes(palace(preset));
    if(/sword|tablet/.test(preset)) {
      const result=[box('器形轮廓学习示意',[0,.05,0],[.38,1.7,.12],'#8CA397',1),
        box('柄与基座',[0,-.89,0],[.67,.22,.27],'#B69A66',1)];return normalizeMeshes(result);
    }
    if(/canyon|gate|scroll/.test(preset))return normalizeMeshes(river().meshes);
    if(/pottery|basin|bowl|ruyao|gongyi/.test(preset))return normalizeMeshes(pottery(preset));
    return neutralSite('unknown');
  }
  function riverCenter(x) { return Math.sin(x*.9)*.34+Math.sin(x*1.8+.5)*.1; }
  function river() {
    const terrain=mesh('河谷高度场',3,'#D2B692'), water=mesh('黄河流线',4,'#C88A4B');
    const point=(x,z)=>[x,-.38+Math.max(0,Math.abs(z-riverCenter(x))-.19)*.12+Math.sin(x*1.3+z*.9)*.055,z];
    for(let i=0;i<64;i++) for(let j=0;j<16;j++) {
      const x=-4.3+i/64*8.6, nx=-4.3+(i+1)/64*8.6, z=-1.35+j/16*2.7,nz=z+2.7/16;
      quad(terrain,point(x,z),point(x,nz),point(nx,nz),point(nx,z));
    }
    for(let i=0;i<112;i++) {
      const x=-4.3+i/112*8.6,nx=-4.3+(i+1)/112*8.6;
      quad(water,[x,-.292,riverCenter(x)-.16],[x,-.292,riverCenter(x)+.16],
        [nx,-.292,riverCenter(nx)+.16],[nx,-.292,riverCenter(nx)-.16]);
    }
    return { meshes:[terrain,water], hotspots:[] };
  }
  function eraDepth(era) {
    const entries=[[/仰韶|史前/,-1.4],[/龙山/,-.9],[/夏|商/,-.4],[/周|春秋/,.1],[/汉|魏/,.5],[/唐|隋/,.9],[/宋/,1.4]];
    const match=entries.find(e=>e[0].test(era));return match?match[1]:0;
  }
  function makeScene(type, data) {
    const p=payload(data), result={ type, payload:p, meshes:[], hotspots:[], edges:[], defaultView:defaultView(type) };
    if(!SCENES.includes(type)) throw new Error('不支持的文化场景');
    if(type==='river_sandbox') {
      result.meshes=river().meshes;
      const nodes=p.nodes.length?p.nodes:CITIES.map(id=>({id,label:id,city:id}));
      nodes.forEach((node,i)=>{
        const x=finite(node.x,-3.7+i/(Math.max(2,nodes.length)-1)*7.4),z=riverCenter(x);
        const tint=i%2?'#5B8E8A':'#C45A6A';
        result.meshes.push(lathe('五城锚点'+node.id,[[.16,-.28],[.16,-.18],[.075,-.15],[.075,.3],[.03,.42]],tint,5,12,[x,0,z]));
        // 选城后才显示对应主题微缩轮廓。它们沿用程序化器形而非真实地标测绘，
        // 不为未选城市重复绘制复杂几何，也不把微缩图当作实际河岸位置。
        const mini=i%5===0?pottery('yangshao_pottery'):(i%5===1?palace('suitang_yingtianmen'):
          (i%5===2?bronze(true):(i%5===3?pagoda(false):palace('qicheng_altar'))));
        normalizeMeshes(mini,.62).forEach(m=>{
          for(let k=0;k<m.positions.length;k+=3){m.positions[k]+=x;m.positions[k+1]+=.025;m.positions[k+2]+=z+.55;}
          m.cityId=node.id;result.meshes.push(m);
        });
        result.hotspots.push({id:node.id,label:node.label,type:'city',position:[x,.48,z],color:tint});
      });
    } else if(type==='relic_inspector') {
      result.meshes=relic(p.proceduralPreset);
      // 资料学习沿用稳定热点 ID，但名称只表达阅读层级，不暗示已有器形与纹饰模型。
      const studyLabels=['概览','遗存','线索'];
      const studyPositions=[[-.48,.12,-.12],[0,0,.06],[.48,-.12,.24]];
      result.hotspots=HOTSPOTS.map((h,i)=>({...h,type:'hotspot',
        label:p.proceduralPreset==='generic_site_study'?studyLabels[i]:h.label,
        position:p.proceduralPreset==='generic_site_study'?studyPositions[i]:h.position.slice(),color:'#C45A6A'}));
      result.meshes.push(lathe('中性展示基座',[[.83,-1.25],[.94,-1.18],[.94,-1.14],[.83,-1.1]],'#C9B79E',3,48));
    } else if(type==='stratum_slice') {
      const layers=p.layers.length?p.layers:[
        {id:'overview',label:'概览主题'},{id:'archaeology',label:'考古主题'},
        {id:'history',label:'器物与故事'},{id:'poetry-travel',label:'诗词与在地'}];
      layers.forEach((layer,i)=>{
        const y=.75-i*1.5/Math.max(1,layers.length-1),tints=['#BDA58A','#C5817D','#A9AA88','#A46D50'];
        const tint=tints[i%4],m=box('学习切片'+layer.id,[0,y,0],[1.95,.28,1.35],tint,3,.82);
        m.layerId=layer.id;result.meshes.push(m);
        const landmark=box('切片内部符号'+layer.id,[0,y+.23,0],[.64,.16,.47],i%2?'#6F928A':'#D1B073',3,.95);
        landmark.layerId=layer.id;result.meshes.push(landmark);
        result.hotspots.push({id:layer.id,label:layer.label,summary:layer.summary,type:'layer',position:[.96,y+.12,.5],color:tint});
      });
    } else {
      p.nodes.forEach((node,i)=>{
        const cityIndex=CITIES.indexOf(node.city), category=/诗|文旅|poem|travel/.test(node.type)?-.62:(/器|文物|relic/.test(node.type)?.05:.65);
        const x=clamp(finite(node.x,(cityIndex<0?i%5:cityIndex)*1.65-3.3+(i%3-1)*.2),-6,6);
        const y=clamp(finite(node.y,category+(i%2)*.17),-2.5,2.5),z=clamp(finite(node.z,eraDepth(node.era)+(i%3)*.23),-3,3);
        const tint=node.explored?'#C88A4B':(node.highlighted?'#C45A6A':node.accent);
        result.meshes.push(sphere('档案节点'+node.id,[x,y,z],node.explored?.105:.08,tint,5,12));
        result.hotspots.push({id:node.id,label:node.label,type:'site',position:[x,y,z],color:tint,explored:node.explored,highlighted:node.highlighted});
      });
      result.edges=p.edges;
    }
    return result;
  }
  function defaultView(type) {
    return {yaw:type==='relic_inspector'?-.35:-.12,pitch:type==='river_sandbox'?.66:(type==='stratum_slice'?.25:.2),
      distance:type==='river_sandbox'?10.5:(type==='constellation_graph'?10.5:4.8),panX:0,panY:0};
  }
  function constrainView(view,type) {
    const fallback=defaultView(type),big=type==='river_sandbox'||type==='constellation_graph';
    return {yaw:finite(view.yaw,fallback.yaw)%TAU,pitch:clamp(finite(view.pitch,fallback.pitch),-.65,1.1),
      distance:clamp(finite(view.distance,fallback.distance),big?5.3:2.5,big?18:9),
      panX:clamp(finite(view.panX,0),big?-3:-1,big?3:1),panY:clamp(finite(view.panY,0),-1.5,1.5)};
  }
  function rotate(point,view) {
    const c=Math.cos(view.yaw),s=Math.sin(view.yaw),cp=Math.cos(view.pitch),sp=Math.sin(view.pitch);
    const x=point[0]*c+point[2]*s,z=-point[0]*s+point[2]*c;
    // 正俯角表示从上方观察：地面法线朝向相机，远处河道投影到屏幕上方。
    return [x,point[1]*cp+z*sp,-point[1]*sp+z*cp];
  }
  function project(point,view,width,height) {
    const p=rotate(point,view),depth=p[2]+view.distance;
    if(depth<=.12) return null;
    const focal=height*1.28;
    return {x:width/2+(p[0]-view.panX)*focal/depth,y:height/2-(p[1]-view.panY)*focal/depth,depth,scale:focal/depth};
  }
  function multiply(a,b) {
    const out=new Float32Array(16);
    for(let c=0;c<4;c++)for(let r=0;r<4;r++)for(let k=0;k<4;k++)out[c*4+r]+=a[k*4+r]*b[c*4+k];
    return out;
  }
  function matrices(view,width,height) {
    const c=Math.cos(view.yaw),s=Math.sin(view.yaw),cp=Math.cos(view.pitch),sp=Math.sin(view.pitch);
    const v=new Float32Array([c,-sp*s,cp*s,0,0,cp,sp,0,s,sp*c,-cp*c,0,-view.panX,-view.panY,-view.distance,1]);
    const f=2.56,near=.1,far=100,aspect=width/Math.max(1,height);
    const p=new Float32Array([f/aspect,0,0,0,0,f,0,0,0,0,(far+near)/(near-far),-1,0,0,2*far*near/(near-far),0]);
    return {view:v,mvp:multiply(p,v)};
  }
  function progress(hotspots,visited) {
    const ids=new Set(hotspots.filter(h=>h.type==='layer').map(h=>h.id));
    const count=[...new Set(visited)].filter(id=>ids.has(id)).length;
    return ids.size?Math.round(count/ids.size*100):0;
  }
  function localModelPath(data) {
    const path=data.modelPath || (data.itemId?'../models/'+data.itemId+'.glb':'');
    return /^\.\.\/models\/[A-Za-z0-9_-]{1,120}\.glb$/.test(path)?path:'';
  }
  return {TOKENS,CITIES,HOTSPOTS,SCENES,clamp,color,payload,mesh,triangle,box,lathe,sphere,normalizeMeshes,
    riverCenter,makeScene,defaultView,constrainView,rotate,project,matrices,progress,localModelPath};
});
