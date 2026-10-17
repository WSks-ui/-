// 本地逻辑验证，不等于 ArkWeb / GPU / 鸿蒙设备验收。仅依赖 Node 内置测试库。
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const Core=require('./core.js');
const GLB=require('./glb.js');

const presets=['yangshao_pottery','miaodigou_rose_basin','guoguo_jade_sword','xiaohan_canyon',
  'erlitou_palace','erlitou_bronze','hanwei_pagoda_base','suitang_yingtianmen','zhengzhou_wall','zhengzhou_ding',
  'dahecun_star_bowl','gongyi_blue_white','kaifeng_pagoda','zhouqiao_stratum','ruyao_celadon','bianjing_scroll',
  'qicheng_altar','puyang_dragon','yellow_river_gate','cangjie_tablet'];

test('任务书与当前20条元数据预设都有对应有限网格，非陶器条目不会落到陶罐',()=>{
  const metadataText=fs.readFileSync(path.resolve(__dirname,'../../../ets/domain/CulturalContent.ts'),'utf8');
  const metadata=[...metadataText.matchAll(/proceduralPreset:\s*['"]([^'"]+)['"]/g)].map(match=>match[1]);
  assert.equal(metadata.length,20);
  for(const proceduralPreset of new Set([...presets,...metadata])){
    const scene=Core.makeScene('relic_inspector',{proceduralPreset});
    assert.equal(scene.hotspots.length,3);assert.ok(scene.meshes.length>0);
    if(metadata.includes(proceduralPreset)&&!proceduralPreset.includes('pottery'))assert.doesNotMatch(scene.meshes[0].name,/陶胎/,proceduralPreset);
    for(const m of scene.meshes){
      assert.ok(m.positions.length>0&&m.positions.length%9===0,proceduralPreset+' '+m.name);
      assert.equal(m.positions.length,m.normals.length);assert.equal(m.uvs.length,m.positions.length/3*2);
      assert.ok(m.positions.every(Number.isFinite));assert.ok(m.normals.every(Number.isFinite));
      assert.ok(m.positions.every(v=>Math.abs(v)<2),proceduralPreset+' 模型超出归一化范围');
      for(let i=0;i<m.normals.length;i+=3)assert.ok(Math.abs(Math.hypot(...m.normals.slice(i,i+3))-1)<1e-6);
    }
  }
});

test('软件投影与 GPU MVP 在旋转、俯视、推拉后的坐标一致',()=>{
  for(const type of Core.SCENES)for(const yaw of [-1.2,0,.7])for(const pitch of [-.2,.65]){
    const view=Core.constrainView({...Core.defaultView(type),yaw,pitch,panX:.3,panY:-.2},type),width=390,height=300;
    const m=Core.matrices(view,width,height).mvp;
    for(const p of [[0,0,0],[1,.6,-.3],[-2,-.4,.8]]){
      const clip=[0,1,2,3].map(row=>m[row]*p[0]+m[4+row]*p[1]+m[8+row]*p[2]+m[12+row]);
      const cpu=Core.project(p,view,width,height);
      assert.ok(Math.abs(cpu.x-(clip[0]/clip[3]+1)*width/2)<.0002);
      assert.ok(Math.abs(cpu.y-(1-clip[1]/clip[3])*height/2)<.0002);
    }
  }
  assert.ok(Core.rotate([0,1,0],{yaw:0,pitch:.6})[2]<0,'正俯角应看到地面上表面');
});

test('五城锚点有序，主题切片保持传入 ids，图谱只保留实际有效关联',()=>{
  const river=Core.makeScene('river_sandbox',{});
  assert.deepEqual(river.hotspots.map(h=>h.id),Core.CITIES);
  assert.ok(river.hotspots.every((h,i,arr)=>!i||h.position[0]>arr[i-1].position[0]));
  const layers=[{id:'overview',label:'概览'},{id:'archaeology',label:'考古'},{id:'history',label:'故事'},{id:'poetry-travel',label:'诗词与在地'}];
  const stratum=Core.makeScene('stratum_slice',{layers});
  assert.deepEqual(stratum.hotspots.map(h=>h.id),layers.map(l=>l.id));
  assert.equal(Core.progress(stratum.hotspots,['overview','overview','missing']),25);
  const graph=Core.makeScene('constellation_graph',{nodes:[{id:'a',label:'A',city:'洛阳'},{id:'a',label:'重复'},{id:'b',label:'B',city:'开封',era:'宋'}],
    edges:[{source:'a',target:'b'},{source:'b',target:'a'},{source:'a',target:'missing'},{source:'a',target:'a'}]});
  assert.equal(graph.hotspots.length,2);assert.equal(graph.edges.length,1);
  assert.ok(graph.hotspots[0].position[0]<graph.hotspots[1].position[0]);
});

test('输入边界拒绝畸形 JSON、外网模型与路径穿越，视角不会被 NaN 破坏',()=>{
  assert.throws(()=>Core.payload('{'),/JSON/);assert.throws(()=>Core.payload('[]'),/对象/);
  assert.throws(()=>Core.payload({version:2}),/版本/);
  assert.throws(()=>Core.makeScene('unknown',{}),/不支持/);
  for(const modelPath of ['https://example.com/a.glb','../../a.glb','../models/../a.glb','../models/a.glb?token=x'])assert.equal(Core.localModelPath({modelPath}),'');
  assert.equal(Core.localModelPath({itemId:'ly-erlitou'}),'../models/ly-erlitou.glb');
  const constrained=Core.constrainView({yaw:Infinity,pitch:NaN,distance:-1,panX:100,panY:-100},'relic_inspector');
  assert.ok(Object.values(constrained).every(Number.isFinite));assert.ok(constrained.distance>=2.5);assert.ok(constrained.panX<=1);
  const clean=Core.payload({nodes:[null,{id:'a',x:NaN,y:Infinity}]});assert.equal(clean.nodes[0].x,undefined);
});

function makeGlb(patch){
  const positions=new Float32Array([0,0,0,1,0,0,0,1,0]),bin=Buffer.from(positions.buffer);
  const json={asset:{version:'2.0'},buffers:[{byteLength:bin.length}],bufferViews:[{buffer:0,byteOffset:0,byteLength:bin.length}],
    accessors:[{bufferView:0,componentType:5126,count:3,type:'VEC3'}],meshes:[{primitives:[{attributes:{POSITION:0}}]}],nodes:[{mesh:0}],scenes:[{nodes:[0]}],scene:0};
  if(patch)patch(json);
  const string=Buffer.from(JSON.stringify(json)),padded=Buffer.alloc(Math.ceil(string.length/4)*4,0x20);string.copy(padded);
  const out=Buffer.alloc(12+8+padded.length+8+bin.length);out.writeUInt32LE(0x46546C67);out.writeUInt32LE(2,4);out.writeUInt32LE(out.length,8);
  out.writeUInt32LE(padded.length,12);out.writeUInt32LE(0x4E4F534A,16);padded.copy(out,20);
  const offset=20+padded.length;out.writeUInt32LE(bin.length,offset);out.writeUInt32LE(0x004E4942,offset+4);bin.copy(out,offset+8);return out;
}

test('真实 GLB 静态三角面经过节点变换后居中，明确只报告几何预览',()=>{
  const result=GLB.parse(makeGlb(j=>{j.nodes[0].translation=[13,20,2];j.nodes[0].scale=[2,3,1];}));
  assert.equal(result.triangles,1);assert.equal(result.meshes.length,1);assert.match(result.message,/纹理与动画尚未接入/);
  const m=result.meshes[0];assert.ok(m.positions.every(v=>Math.abs(v)<=1.125+.00001));
  assert.ok(m.normals.every(Number.isFinite));
});

test('GLB 拒绝越界 accessor、压缩扩展、外部缓冲和循环节点，不伪报成功',()=>{
  assert.throws(()=>GLB.parse(makeGlb(j=>j.accessors[0].count=9999)),/越界/);
  assert.throws(()=>GLB.parse(makeGlb(j=>j.accessors[0].byteOffset=-3)),/偏移/);
  assert.throws(()=>GLB.parse(makeGlb(j=>j.extensionsRequired=['KHR_draco_mesh_compression'])),/扩展/);
  assert.throws(()=>GLB.parse(makeGlb(j=>j.buffers[0].uri='https://example.com/a.bin')),/内嵌/);
  assert.throws(()=>GLB.parse(makeGlb(j=>j.nodes[0].children=[0])),/节点树/);
  const bad=makeGlb();bad.writeUInt32LE(99999999,12);assert.throws(()=>GLB.parse(bad),/分块范围/);
});

function harness(){
  let rafId=0,fills=0,blits=0,now=0;const frames=new Map(),calls=[],styles={},elements=new Map();
  function context2d(){return new Proxy({measureText:s=>({width:String(s).length*7}),createRadialGradient:()=>({addColorStop(){}})},
    {get(o,k){if(k in o)return o[k];return (...args)=>{if(k==='fill')fills++;if(k==='drawImage')blits++;};},set(o,k,v){o[k]=v;return true;}});}
  function element(id){
    const events=new Map(),ctx=context2d();
    return {id,events,width:360,height:300,style:{setProperty(k,v){styles[k]=v;}},textContent:'',
      getContext:type=>type==='2d'?ctx:null,getBoundingClientRect:()=>({width:360,height:300,left:0,top:0}),setAttribute(){},
      addEventListener(k,v){events.set(k,v);},removeEventListener(k){events.delete(k);},setPointerCapture(){},toDataURL:()=> 'data:image/png;base64,TEST'};
  }
  ['viewport','gpu','surface','caption','disclosure'].forEach(id=>elements.set(id,element(id)));
  const document={visibilityState:'visible',documentElement:element('html'),getElementById:id=>elements.get(id),createElement:()=>element('offscreen'),
    addEventListener(){},removeEventListener(){}};
  const sandbox={console,Math,JSON,Map,Set,Float32Array,Uint8Array,DataView,TextDecoder,Promise,document,innerWidth:360,innerHeight:300,devicePixelRatio:1,
    location:{search:'?renderer=canvas2d'},CulturalEngineCore:Core,CulturalEngineGLB:GLB,
    EngineBridge:{onNodeSelected(...args){calls.push(['select',...args]);},onProgressUnlocked(...args){calls.push(['progress',...args]);},
      onCaptureSnapshot(...args){calls.push(['capture',...args]);},onReady(...args){calls.push(['ready',...args]);},onStatus(...args){calls.push(['status',...args]);}},
    matchMedia:()=>({matches:false,addEventListener(){},removeEventListener(){}}),addEventListener(){},removeEventListener(){},
    requestAnimationFrame(cb){frames.set(++rafId,cb);return rafId;},cancelAnimationFrame(id){frames.delete(id);}};
  sandbox.window=sandbox;sandbox.globalThis=sandbox;
  vm.createContext(sandbox);vm.runInContext(fs.readFileSync(path.join(__dirname,'renderer.js'),'utf8'),sandbox);
  vm.runInContext(fs.readFileSync(path.join(__dirname,'engine.js'),'utf8'),sandbox);
  return {api:sandbox,calls,frames,elements,styles,document,get fills(){return fills;},get blits(){return blits;},
    flush(count=5){for(let i=0;i<count&&frames.size;i++){const pending=[...frames.values()];frames.clear();now+=60;pending.forEach(cb=>cb(now));}}};
}

test('热点/切片聚焦不产生进度，只有显式完成命令去重回调',()=>{
  const h=harness();h.api.engineSetReducedMotion(true);h.api.engineLoadScene('stratum_slice',JSON.stringify({itemId:'demo',exploredIds:['overview']}));h.flush();
  assert.equal(h.api.engineFocusHotspot('archaeology'),true);h.flush();assert.equal(h.calls.filter(c=>c[0]==='progress').length,0);
  assert.equal(h.api.engineCompleteExploration('archaeology'),true);assert.equal(h.api.engineCompleteExploration('archaeology'),false);
  assert.deepEqual(h.calls.find(c=>c[0]==='progress'),['progress','demo',50]);
  assert.equal(h.api.engineCompleteExploration('missing'),false);
  h.api.engineSetActive(false);assert.equal(h.api.engineCompleteExploration('history'),false);assert.equal(h.frames.size,0);
});

test('减少动态只按需绘制，后台与销毁取消帧；软件网格缓存避免重复三角投影',()=>{
  const h=harness();h.api.engineSetReducedMotion(true);h.flush(10);assert.equal(h.frames.size,0);
  const stillFills=h.fills;h.flush(10);assert.equal(h.fills,stillFills);
  h.api.engineSetReducedMotion(false);h.flush(1);const cachedFills=h.fills,cachedBlits=h.blits;h.flush(2);
  assert.ok(h.blits>cachedBlits);assert.equal(h.fills-cachedFills<500,true,'动态点的填充数不应包含数千个网格面');
  h.api.engineSetAutomatic(false);h.flush(10);assert.equal(h.frames.size,0);
  h.api.engineSetAutomatic(true);h.flush(1);assert.ok(h.frames.size>0);
  h.api.engineSetActive(false);assert.equal(h.frames.size,0);const pausedFills=h.fills;h.api.engineSetTheme(true);h.flush();assert.equal(h.fills,pausedFills);
  assert.equal(h.styles['--bg'],'#171311');
  h.api.engineSetActive(true);h.flush(1);assert.ok(h.fills>pausedFills);
  h.api.engineDispose();assert.equal(h.frames.size,0);assert.equal(h.elements.get('surface').events.size,0);assert.equal(h.api.engineCommand('turn',1),false);
});

test('原生旋转/缩放/复位/截图命令可达，截图回调包含数据 URL',()=>{
  const h=harness();h.api.engineSetReducedMotion(true);h.api.engineLoadScene('relic_inspector','{}');h.flush();
  const before=JSON.parse(h.api.engineGetState()).view;
  assert.equal(h.api.engineCommand('turn',1),true);assert.ok(JSON.parse(h.api.engineGetState()).view.yaw>before.yaw);
  assert.equal(h.api.engineCommand('zoom',1),true);assert.ok(JSON.parse(h.api.engineGetState()).view.distance<before.distance);
  h.api.engineCommand('reset');
  const resetView=JSON.parse(h.api.engineGetState()).view,expectedView=Core.defaultView('relic_inspector');
  assert.deepEqual(Object.keys(resetView).sort(),Object.keys(expectedView).sort());
  Object.keys(expectedView).forEach(key=>assert.ok(Math.abs(resetView[key]-expectedView[key])<1e-10,'复位维度 '+key+' 不匹配'));
  assert.match(h.api.engineCaptureSnapshot(),/^data:image\/png;base64,/);assert.equal(h.calls.filter(c=>c[0]==='capture').length,1);
  h.api.engineSetActive(false);assert.equal(h.api.engineCaptureSnapshot(),'');
});

test('异步旧模型加载结果不会覆盖新场景，释放后不重建资源',async()=>{
  const h=harness(),pending=[];h.api.CulturalEngineGLB={load:()=>new Promise(resolve=>pending.push(resolve))};
  h.api.engineLoadScene('relic_inspector',JSON.stringify({itemId:'first'}));
  h.api.engineLoadScene('relic_inspector',JSON.stringify({itemId:'second'}));
  pending[0]({meshes:[],message:'旧结果'});await Promise.resolve();assert.equal(JSON.parse(h.api.engineGetState()).modelState,'checking');
  h.api.engineLoadScene('stratum_slice',JSON.stringify({itemId:'second'}));
  pending[1]({meshes:[],message:'迟到结果'});await Promise.resolve();assert.equal(JSON.parse(h.api.engineGetState()).modelState,'procedural');
  h.api.engineLoadScene('relic_inspector',JSON.stringify({itemId:'third'}));h.api.engineDispose();
  pending[2]({meshes:[],message:'已退出'});await Promise.resolve();assert.equal(h.frames.size,0);
});
