/* ArkWeb 局部视口控制器。原生页面负责导航、可访问按钮、正文和个人数据落盘。
 * 这里不写 localStorage、不合成同步状态；取消后台帧与异步模型旧响应是生命周期底线。 */
(function(){
  'use strict';
  const Core=window.CulturalEngineCore,Drivers=window.CulturalEngineRenderer;
  const host=document.getElementById('viewport'),gpuCanvas=document.getElementById('gpu'),surface=document.getElementById('surface');
  const caption=document.getElementById('caption'),disclosure=document.getElementById('disclosure');
  const overlay=surface.getContext('2d',{alpha:true});
  const motionQuery=window.matchMedia?window.matchMedia('(prefers-reduced-motion: reduce)'):null;
  let dark=false,palette=Core.TOKENS.light,active=true,visible=true,reduced=!!(motionQuery&&motionQuery.matches),automatic=true,disposed=false;
  let width=1,height=1,dpr=1,frame=0,lastFrame=0,time=0,dirty=true,renderer=null,modelToken=0;
  let scene=Core.makeScene('river_sandbox',{}),view={...scene.defaultView},targetView=null;
  let selectedId='',modelState='procedural',modelMessage='程序化学习示意',hitTargets=[],lastRender=-Infinity,modelRequest=null;
  const visitedByItem=new Map(),pointers=new Map();
  let gesture=null,observer=null,resizeObserver=null;
  function notify(method,...args){
    try{const bridge=window.EngineBridge;if(bridge&&typeof bridge[method]==='function')bridge[method](...args);}
    catch(_){/* 页面退栈后代理可先于本地 JS 释放，不重复调用、不在后台重试。 */}
  }
  function status(){return {renderer:renderer?renderer.mode:'unavailable',sceneType:scene.type,modelState,modelMessage,
    selectedId,active:canRender(),reducedMotion:reduced,automatic};}
  function report(){notify('onStatus',JSON.stringify(status()));}
  function canRender(){return active&&visible&&!disposed&&!!renderer&&document.visibilityState!=='hidden';}
  function cancelFrame(){if(frame)cancelAnimationFrame(frame);frame=0;lastFrame=0;}
  function requestDraw(){dirty=true;if(canRender()&&!frame)frame=requestAnimationFrame(tick);}
  function animated(){return !reduced&&(!!targetView||automatic&&(scene.type==='river_sandbox'||scene.type==='constellation_graph'||scene.type==='relic_inspector'));}
  function captionText(){
    const names={river_sandbox:'五城河洛 · 黄河流光沙盘',relic_inspector:'器物凝视 · 形制与纹样',stratum_slice:'文化主题 · 分层探索',constellation_graph:'文明连线 · 时空网络'};
    caption.textContent=scene.payload.title||names[scene.type];
    disclosure.textContent=scene.type==='stratum_slice'?'四个阅读主题的学习示意 · 非实际考古地层复原':
      (modelState==='loaded'?'本地 GLB 几何预览 · 纹理与动画尚未接入':'程序化学习示意 · 非文物或遗址复原');
    surface.setAttribute('aria-label',caption.textContent+'。'+disclosure.textContent+'。拖动旋转，双指缩放；热点也可由下方原生按钮选择。');
  }
  function fallback(reason){
    if(disposed)return;if(renderer)renderer.dispose();
    gpuCanvas.style.display='none';renderer=Drivers.software(surface);renderer.rebuild(scene);
    resize();notify('onReady','canvas2d');modelMessage=reason?'软件三维投影 · '+reason:modelMessage;report();requestDraw();
  }
  function createRenderer(){
    // 已知 EGL 不可用的模拟器由原生组件直接使用 ArkUI Canvas。此查询参数另外允许支持
    // Web 的设备明确跳过 WebGL 上下文创建；try/catch 不能保护驱动进程的原生 EGL 崩溃。
    const forceCanvas=/(?:[?&])renderer=canvas2d(?:&|$)/.test(location.search||'');
    if(!forceCanvas){try{renderer=Drivers.gpu(gpuCanvas,()=>fallback('WebGL 上下文已释放'));renderer.rebuild(scene);return;}catch(_){}}
    gpuCanvas.style.display='none';renderer=Drivers.software(surface);renderer.rebuild(scene);
  }
  function resize(){
    if(disposed)return;
    const rect=host.getBoundingClientRect();width=Math.max(1,rect.width||innerWidth);height=Math.max(1,rect.height||innerHeight);
    // 软件路径限制像素比，避免兼容设备为装饰画布持续分配过大缓冲。
    dpr=Math.min(window.devicePixelRatio||1,renderer&&renderer.mode==='webgl2'?2:1.5);
    surface.width=Math.max(1,Math.round(width*dpr));surface.height=Math.max(1,Math.round(height*dpr));
    if(renderer)renderer.resize(width,height,dpr);requestDraw();
  }
  function currentVisited(){
    const key=scene.payload.itemId||'__'+scene.type;
    if(!visitedByItem.has(key))visitedByItem.set(key,new Set());return visitedByItem.get(key);
  }
  function moveTo(next){
    const constrained=Core.constrainView(next,scene.type);
    // 跨越 2π 时取最近角度，连续点击旋转不会绕相反方向多转一圈。
    const angleDelta=constrained.yaw-view.yaw;
    if(Math.abs(angleDelta)>Math.PI)constrained.yaw=view.yaw+((angleDelta+Math.PI)%(Math.PI*2)+Math.PI*2)%(Math.PI*2)-Math.PI;
    if(reduced){view=constrained;targetView=null;}else targetView=constrained;
    requestDraw();
  }
  function select(id,emit=true){
    const hot=scene.hotspots.find(h=>h.id===id);if(!hot)return false;
    const changed=selectedId!==id;selectedId=id;
    let next={...view};
    if(scene.type==='relic_inspector')next={...next,yaw:hot.yaw,pitch:hot.pitch,distance:id==='pattern'?3.5:4.2,panX:0,panY:id==='story'?-.12:0};
    else if(scene.type==='river_sandbox')next={...next,panX:Core.clamp(hot.position[0]*.55,-2.4,2.4),distance:8.5,pitch:.67};
    else if(scene.type==='stratum_slice')next={...next,panY:hot.position[1]*.18,distance:4.5};
    else next={...next,panX:hot.position[0]*.42,panY:hot.position[1]*.35,distance:8.4};
    moveTo(next);
    // 相机选择不等于完成阅读。只有显式完成命令才回调 progress；聚焦不会偷偷写探索记录。
    if(emit&&changed)notify('onNodeSelected',hot.id,hot.type);report();return true;
  }
  function complete(id){
    const hot=scene.hotspots.find(h=>h.id===id&&h.type==='layer');
    if(!hot||!scene.payload.itemId||!canRender())return false;
    const visited=currentVisited();if(visited.has(id))return false;
    visited.add(id);requestDraw();notify('onProgressUnlocked',scene.payload.itemId,Core.progress(scene.hotspots,visited));return true;
  }
  async function loadModel(data,token){
    const path=Core.localModelPath(data);if(!path)return;
    const request=typeof AbortController!=='undefined'?new AbortController():null;modelRequest=request;
    modelState='checking';modelMessage='正在检查随包本地模型';report();
    try{
      const result=await window.CulturalEngineGLB.load(path,request?request.signal:undefined);
      if(disposed||token!==modelToken)return;
      scene.meshes=result.meshes;renderer.rebuild(scene);modelState='loaded';modelMessage=result.message;
    }catch(error){
      if(disposed||token!==modelToken)return;
      modelState='procedural';modelMessage='使用程序化示意；本地 GLB 未提供或不支持：'+String(error&&error.message||error).slice(0,160);
    }finally{if(modelRequest===request)modelRequest=null;}
    captionText();report();requestDraw();
  }
  function loadScene(type,json){
    if(disposed||!renderer)return false;
    let next;try{next=Core.makeScene(type,json);}catch(error){notify('onStatus',JSON.stringify({...status(),modelMessage:String(error.message||error)}));return false;}
    const keepView=scene.type===next.type&&scene.payload.itemId===next.payload.itemId&&selectedId===next.payload.selectedId&&scene.payload.proceduralPreset===next.payload.proceduralPreset;
    const previousView={...view},previousTarget=targetView?{...targetView}:null;
    modelToken++;if(modelRequest)modelRequest.abort();modelRequest=null;scene=next;selectedId='';
    view=keepView?previousView:{...next.defaultView};targetView=keepView?previousTarget:null;if(!keepView)time=0;
    modelState='procedural';modelMessage='程序化学习示意';
    const visited=currentVisited();scene.payload.exploredIds.forEach(id=>visited.add(id));
    renderer.rebuild(scene);captionText();
    if(keepView)selectedId=scene.payload.selectedId;else if(scene.payload.selectedId)select(scene.payload.selectedId,false);
    report();requestDraw();if(type==='relic_inspector')loadModel(scene.payload,modelToken);return true;
  }
  function roundedRect(ctx,x,y,w,h,r){
    r=Math.min(r,w/2,h/2);ctx.beginPath();ctx.moveTo(x+r,y);ctx.lineTo(x+w-r,y);ctx.quadraticCurveTo(x+w,y,x+w,y+r);
    ctx.lineTo(x+w,y+h-r);ctx.quadraticCurveTo(x+w,y+h,x+w-r,y+h);ctx.lineTo(x+r,y+h);ctx.quadraticCurveTo(x,y+h,x,y+h-r);
    ctx.lineTo(x,y+r);ctx.quadraticCurveTo(x,y,x+r,y);ctx.closePath();
  }
  function drawEdge(a,b,index,highlighted){
    const selected=a.id===selectedId||b.id===selectedId,alpha=highlighted?.74:(selected?.48:.16);
    const middle={x:(a.x+b.x)/2+(a.y-b.y)*.14,y:(a.y+b.y)/2-(a.x-b.x)*.14};
    overlay.strokeStyle=highlighted?palette.ochre:(selected?palette.rose:palette.jade);overlay.globalAlpha=alpha;overlay.lineWidth=highlighted?2.5:(selected?1.5:.8);
    overlay.beginPath();overlay.moveTo(a.x,a.y);overlay.quadraticCurveTo(middle.x,middle.y,b.x,b.y);overlay.stroke();
    if(!reduced){
      const t=(time*.1+index*.193)%1,u=1-t,x=u*u*a.x+2*u*t*middle.x+t*t*b.x,y=u*u*a.y+2*u*t*middle.y+t*t*b.y;
      overlay.globalAlpha=selected?.8:.35;overlay.fillStyle=palette.ochre;overlay.beginPath();overlay.arc(x,y,selected?2.2:1.5,0,Math.PI*2);overlay.fill();
    }overlay.globalAlpha=1;
  }
  function drawRiverFlow(){
    overlay.save();
    for(let i=0;i<40;i++){
      const t=(i/40+(reduced?0:time*.025))%1,x=-4.2+t*8.4,z=Core.riverCenter(x)+(i%3-1)*.05;
      const p=Core.project([x,-.265,z],view,width,height);if(!p)continue;
      overlay.globalAlpha=.25+Math.sin(t*Math.PI)*.45;overlay.fillStyle=i%3?palette.ochre:palette.rose;
      overlay.beginPath();overlay.ellipse(p.x,p.y,2.3,1,0,0,Math.PI*2);overlay.fill();
    }overlay.restore();
  }
  function labelText(text,maxWidth){
    if(overlay.measureText(text).width<=maxWidth)return text;
    let result=text;while(result&&overlay.measureText(result+'…').width>maxWidth)result=result.slice(0,-1);return result+'…';
  }
  function drawOverlay(){
    hitTargets=[];overlay.setTransform(dpr,0,0,dpr,0,0);overlay.globalAlpha=1;
    if(renderer.mode==='webgl2')overlay.clearRect(0,0,width,height);
    // 装饰性晕影仅属于局部场景，不是 HarmonyOS 沉浸光感或系统材质。
    const shade=overlay.createRadialGradient(width*.45,height*.35,20,width*.5,height*.5,Math.max(width,height)*.7);
    shade.addColorStop(0,dark?'rgba(224,122,138,.025)':'rgba(255,255,255,.07)');shade.addColorStop(1,dark?'rgba(23,19,17,.2)':'rgba(250,246,240,.2)');
    overlay.fillStyle=shade;overlay.fillRect(0,0,width,height);
    const projected=scene.hotspots.map(h=>{
      const position=h.position.slice();if(h.type==='layer'&&selectedId===h.id)position[1]+=.35;
      const p=Core.project(position,view,width,height);return p?{...h,...p}:null;
    }).filter(Boolean).sort((a,b)=>b.depth-a.depth);
    const byId=new Map(projected.map(p=>[p.id,p]));
    if(scene.type==='constellation_graph')scene.edges.forEach((e,i)=>{const a=byId.get(e.source),b=byId.get(e.target);if(a&&b)drawEdge(a,b,i,e.highlighted);});
    if(scene.type==='river_sandbox')drawRiverFlow();
    const occupied=[];overlay.font='11px "HarmonyOS Sans SC",sans-serif';
    projected.forEach((p,index)=>{
      if(p.x<6||p.x>width-6||p.y<25||p.y>height-25)return;
      const selected=p.id===selectedId,explored=p.type==='layer'?currentVisited().has(p.id):p.explored;
      const pulse=reduced?1:1+Math.sin(time*1.9+index)*.12,paint=p.highlighted?(explored?palette.ochre:palette.rose):(selected?palette.rose:(explored?palette.ochre:p.color||palette.jade));
      const radius=p.type==='city'?5:(p.type==='layer'?4:3.5);
      overlay.save();overlay.globalAlpha=selected?.15:.07;overlay.fillStyle=paint;overlay.beginPath();overlay.arc(p.x,p.y,(selected?20:14)*pulse,0,Math.PI*2);overlay.fill();
      overlay.globalAlpha=1;overlay.strokeStyle=p.highlighted?palette.ochre:paint;overlay.lineWidth=p.highlighted?2.3:(selected?1.7:1);overlay.beginPath();overlay.arc(p.x,p.y,radius+3,0,Math.PI*2);overlay.stroke();
      overlay.fillStyle=paint;overlay.beginPath();overlay.arc(p.x,p.y,radius,0,Math.PI*2);overlay.fill();overlay.restore();
      const maxText=scene.type==='river_sandbox'?50:100;
      const text=labelText(p.label,maxText),tw=Math.ceil(overlay.measureText(text).width),bw=tw+14,bh=23;
      let x=Core.clamp(p.x-bw/2,6,width-bw-6),y=p.y+12;
      if(scene.type==='stratum_slice'){x=Core.clamp(p.x+12,6,width-bw-6);y=p.y-11;}
      if(y+bh>height-27)y=p.y-bh-12;
      for(let attempt=0;attempt<3&&occupied.some(r=>x<r.x+r.w+3&&x+bw>r.x-3&&y<r.y+r.h+2&&y+bh>r.y-2);attempt++)y=Core.clamp(p.y-35-attempt*24,28,height-52);
      const collision=occupied.some(r=>x<r.x+r.w&&x+bw>r.x&&y<r.y+r.h&&y+bh>r.y);
      const show=selected||scene.type!=='constellation_graph'||(!collision&&occupied.length<9);
      if(show){
        occupied.push({x,y,w:bw,h:bh});overlay.save();overlay.globalAlpha=dark?.94:.91;overlay.fillStyle=palette.card;
        roundedRect(overlay,x,y,bw,bh,10);overlay.fill();overlay.globalAlpha=selected?.7:.28;overlay.strokeStyle=paint;overlay.lineWidth=.8;overlay.stroke();
        overlay.globalAlpha=1;overlay.fillStyle=selected?palette.rose:palette.ink;overlay.textAlign='center';overlay.textBaseline='middle';overlay.fillText(text,x+bw/2,y+bh/2);overlay.restore();
      }
      hitTargets.push({id:p.id,x:p.x,y:p.y,radius:17,label:show?{x,y,w:bw,h:bh}:null,depth:p.depth});
    });
    if(scene.type==='constellation_graph'&&!scene.hotspots.length){overlay.fillStyle=palette.body;overlay.textAlign='center';overlay.fillText('尚无可展示的关联档案',width/2,height/2);}
  }
  function render(){
    if(!canRender()||!renderer)return;
    renderer.draw({view,palette,dark,time,selectedId});drawOverlay();dirty=false;
  }
  function tick(now){
    frame=0;if(!canRender())return;
    const elapsed=lastFrame?Math.min(.08,(now-lastFrame)/1000):0;lastFrame=now;
    if(!reduced&&automatic)time+=elapsed;
    if(!reduced&&automatic&&scene.type==='relic_inspector'&&!targetView){view.yaw+=elapsed*.1;dirty=true;}
    if(targetView){
      let remaining=0;
      Object.keys(view).forEach(key=>{const delta=targetView[key]-view[key];view[key]+=delta*(reduced?1:Math.min(1,elapsed*7+.08));remaining+=Math.abs(delta);});
      if(remaining<.006||reduced){view={...targetView};targetView=null;}dirty=true;
    }
    // 动态帧分别限到 GPU 30 / 软件 20 FPS。减少动态下仅输入、主题和尺寸改变触发单帧。
    if((dirty||animated())&&now-lastRender>=(renderer.mode==='webgl2'?32:48)){render();lastRender=now;}
    if(canRender()&&(dirty||animated()))frame=requestAnimationFrame(tick);
  }
  function capture(){
    if(!canRender())return '';
    try{
      render();const out=document.createElement('canvas');out.width=surface.width;out.height=surface.height;
      const ctx=out.getContext('2d');if(!ctx)return '';
      ctx.fillStyle=palette.bg;ctx.fillRect(0,0,out.width,out.height);
      if(renderer.mode==='webgl2')ctx.drawImage(gpuCanvas,0,0,out.width,out.height);
      ctx.drawImage(surface,0,0);
      // 截图直接写明示意边界，避免分享到手账后失去文物复原/实际地层的限定语。
      const scale=out.width/width;ctx.setTransform(scale,0,0,scale,0,0);ctx.fillStyle=palette.body;ctx.font='10px sans-serif';ctx.textAlign='center';
      ctx.fillText(scene.type==='stratum_slice'?'阅读主题分层学习示意 · 非实际考古地层':'云河纪 · '+(modelState==='loaded'?'本地模型几何预览':'程序化学习示意'),width/2,height-11);
      const data=out.toDataURL('image/png');notify('onCaptureSnapshot',data);return data;
    }catch(error){notify('onStatus',JSON.stringify({...status(),modelMessage:'当前设备截图不可用：'+String(error.message||error).slice(0,100)}));return '';}
  }
  function point(event){const r=host.getBoundingClientRect();return {x:event.clientX-r.left,y:event.clientY-r.top};}
  function hit(p){
    return hitTargets.slice().sort((a,b)=>a.depth-b.depth).find(h=>Math.hypot(h.x-p.x,h.y-p.y)<=h.radius||h.label&&p.x>=h.label.x&&p.x<=h.label.x+h.label.w&&p.y>=h.label.y&&p.y<=h.label.y+h.label.h);
  }
  function pointerDown(event){
    if(!canRender())return;event.preventDefault();const p=point(event);pointers.set(event.pointerId,p);
    if(surface.setPointerCapture)try{surface.setPointerCapture(event.pointerId);}catch(_){}
    if(pointers.size===1)gesture={start:p,last:p,view:{...view},moved:false,multi:false};
    else if(pointers.size===2){const pts=[...pointers.values()];gesture={...gesture,multi:true,pinch:Math.hypot(pts[0].x-pts[1].x,pts[0].y-pts[1].y),view:{...view},center:{x:(pts[0].x+pts[1].x)/2,y:(pts[0].y+pts[1].y)/2}};}
    targetView=null;automatic=false;notify('onInteraction');requestDraw();
  }
  function pointerMove(event){
    if(!pointers.has(event.pointerId)||!gesture||!canRender())return;event.preventDefault();const p=point(event);pointers.set(event.pointerId,p);
    if(pointers.size>=2){
      const pts=[...pointers.values()],distance=Math.hypot(pts[0].x-pts[1].x,pts[0].y-pts[1].y),center={x:(pts[0].x+pts[1].x)/2,y:(pts[0].y+pts[1].y)/2};
      if(gesture.pinch>1)view={...gesture.view,distance:gesture.view.distance*gesture.pinch/Math.max(1,distance),
        panX:gesture.view.panX-(center.x-gesture.center.x)*view.distance/(height*1.28),panY:gesture.view.panY+(center.y-gesture.center.y)*view.distance/(height*1.28)};
    }else if(!gesture.multi){
      const dx=p.x-gesture.start.x,dy=p.y-gesture.start.y;
      if(Math.hypot(dx,dy)>6)gesture.moved=true;
      if(scene.type==='river_sandbox')view={...gesture.view,panX:gesture.view.panX-dx*.012,pitch:gesture.view.pitch+dy*.003};
      else view={...gesture.view,yaw:gesture.view.yaw+dx*.009,pitch:gesture.view.pitch+(scene.type==='stratum_slice'?0:dy*.006)};
    }
    view=Core.constrainView(view,scene.type);gesture.last=p;requestDraw();
  }
  function pointerUp(event){
    if(!pointers.has(event.pointerId))return;const p=point(event),g=gesture;pointers.delete(event.pointerId);
    if(!g)return;
    if(!g.multi&&canRender()){
      const dx=p.x-g.start.x,dy=p.y-g.start.y;
      if(!g.moved&&Math.hypot(dx,dy)<8){const found=hit(p);if(found)select(found.id);}
      else if(scene.type==='stratum_slice'&&Math.abs(dy)>35&&Math.abs(dy)>Math.abs(dx)*1.3){
        const index=Math.max(0,scene.hotspots.findIndex(h=>h.id===selectedId)),next=Core.clamp(index+(dy<0?1:-1),0,scene.hotspots.length-1);if(scene.hotspots[next])select(scene.hotspots[next].id);
      }
    }
    if(!pointers.size)gesture=null;requestDraw();
  }
  function pointerCancel(event){pointers.delete(event.pointerId);if(!pointers.size)gesture=null;}
  function wheel(event){if(!canRender())return;event.preventDefault();targetView=null;automatic=false;notify('onInteraction');view=Core.constrainView({...view,distance:view.distance*Math.exp(Core.clamp(event.deltaY,-150,150)*.002)},scene.type);requestDraw();}
  function reset(){moveTo(scene.defaultView);return true;}
  function visibility(){if(!canRender()){cancelFrame();pointers.clear();gesture=null;}else requestDraw();report();}
  function setReduced(value){reduced=!!value;if(reduced&&targetView){view={...targetView};targetView=null;}cancelFrame();requestDraw();report();}
  function setTheme(value){
    dark=!!value;palette=dark?Core.TOKENS.dark:Core.TOKENS.light;
    document.documentElement.style.setProperty('--bg',palette.bg);document.documentElement.style.setProperty('--ink',palette.ink);
    document.documentElement.style.setProperty('--muted',palette.muted);document.documentElement.style.colorScheme=dark?'dark':'light';requestDraw();return true;
  }
  function dispose(){
    if(disposed)return;disposed=true;modelToken++;if(modelRequest)modelRequest.abort();modelRequest=null;cancelFrame();pointers.clear();gesture=null;
    if(observer)observer.disconnect();if(resizeObserver)resizeObserver.disconnect();
    document.removeEventListener('visibilitychange',visibility);window.removeEventListener('resize',resize);window.removeEventListener('pagehide',dispose);
    surface.removeEventListener('pointerdown',pointerDown);surface.removeEventListener('pointermove',pointerMove);surface.removeEventListener('pointerup',pointerUp);
    surface.removeEventListener('pointercancel',pointerCancel);surface.removeEventListener('wheel',wheel);surface.removeEventListener('dblclick',reset);
    if(motionQuery&&motionQuery.removeEventListener)motionQuery.removeEventListener('change',motionChanged);
    if(renderer)renderer.dispose();renderer=null;visitedByItem.clear();hitTargets=[];
  }
  function motionChanged(event){setReduced(event.matches);}
  window.engineSetTheme=setTheme;
  window.engineLoadScene=loadScene;
  window.engineFocusHotspot=id=>disposed?false:select(String(id));
  window.engineCompleteExploration=id=>disposed?false:complete(String(id));
  window.engineSetActive=value=>{active=!!value;visibility();return true;};
  window.engineSetReducedMotion=value=>{setReduced(value);return true;};
  window.engineSetAutomatic=value=>{if(disposed)return false;automatic=!!value;cancelFrame();requestDraw();report();return true;};
  window.engineSetView=json=>{try{const next=typeof json==='string'?JSON.parse(json):json;if(!next||typeof next!=='object')return false;moveTo({...view,...next});return true;}catch(_){return false;}};
  window.engineCaptureSnapshot=capture;
  window.engineGetState=()=>JSON.stringify({...status(),view,exploredIds:[...currentVisited()]});
  window.engineCommand=(command,value)=>{
    if(disposed)return false;
    if(command==='reset')return reset();
    if(command==='capture')return capture();
    if(command==='complete')return complete(String(value));
    const amount=typeof value==='number'&&Number.isFinite(value)?value:1;
    const next=targetView||view;
    if(command==='turn'){automatic=false;notify('onInteraction');moveTo({...next,yaw:next.yaw+amount*.35});return true;}
    if(command==='zoom'){automatic=false;notify('onInteraction');moveTo({...next,distance:next.distance*Math.pow(.85,amount)});return true;}return false;
  };
  window.engineDispose=dispose;
  try{
    if(!overlay)throw new Error('离线画布不可用');createRenderer();resize();captionText();
    surface.addEventListener('pointerdown',pointerDown);surface.addEventListener('pointermove',pointerMove);surface.addEventListener('pointerup',pointerUp);
    surface.addEventListener('pointercancel',pointerCancel);surface.addEventListener('wheel',wheel,{passive:false});surface.addEventListener('dblclick',reset);
    document.addEventListener('visibilitychange',visibility);window.addEventListener('resize',resize);window.addEventListener('pagehide',dispose);
    if(motionQuery&&motionQuery.addEventListener)motionQuery.addEventListener('change',motionChanged);
    if(window.ResizeObserver){resizeObserver=new ResizeObserver(resize);resizeObserver.observe(host);}
    if(window.IntersectionObserver){observer=new IntersectionObserver(entries=>{visible=entries.some(e=>e.isIntersecting);visibility();},{threshold:.01});observer.observe(host);}
    notify('onReady',renderer.mode);report();requestDraw();
  }catch(error){caption.textContent='视口暂不可用，请使用下方原生探索按钮';disclosure.textContent='当前设备未成功创建离线画布';notify('onReady','unavailable');modelMessage=String(error.message||error);report();}
})();
