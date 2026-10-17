/* 两种渲染驱动共享 core.js 的网格、相机与命中坐标。
 * WebGL2 使用真实 GLSL 光照/材质；Canvas 只声明软件三维投影，不冒充 GPU 或原生光感。 */
(function(root){
  'use strict';
  const Core=root.CulturalEngineCore;
  const vertex=`#version 300 es
    precision highp float;
    in vec3 aPosition; in vec3 aNormal;
    uniform mat4 uMvp; uniform mat4 uView; uniform float uOffset;
    out vec3 vPosition; out vec3 vNormal; out vec3 vView;
    void main(){
      vec3 position=aPosition+vec3(0.,uOffset,0.);
      vPosition=position; vNormal=mat3(uView)*aNormal;
      vView=(uView*vec4(position,1.)).xyz;
      gl_Position=uMvp*vec4(position,1.);
    }`;
  const fragment=`#version 300 es
    precision highp float;
    in vec3 vPosition; in vec3 vNormal; in vec3 vView;
    uniform vec4 uColor; uniform vec3 uBackground; uniform float uTime;
    uniform float uMaterial; uniform float uDark;
    out vec4 outColor;
    float grain(vec3 p){return fract(sin(dot(p,vec3(12.9898,78.233,37.719)))*43758.5453);}
    void main(){
      vec3 n=normalize(vNormal),eye=normalize(-vView),light=normalize(vec3(-.55,.85,.8));
      if(dot(n,eye)<0.)n=-n;
      vec3 base=uColor.rgb;
      float polish=.18,rough=grain(floor(vPosition*95.));
      if(uMaterial<.5){
        float angle=atan(vPosition.z,vPosition.x);
        float band=1.-smoothstep(.025,.045,abs(fract((vPosition.y+.82)*2.7)-.5));
        float petal=smoothstep(.87,.96,cos(angle*8.+sin(vPosition.y*13.)*.8));
        float motif=petal*(1.-smoothstep(.1,.3,abs(vPosition.y-.12)));
        base=mix(base,vec3(.21,.15,.12),max(band*.85,motif*.7));
        base*=.96+rough*.08;polish=.1;
      } else if(uMaterial<1.5){
        float patina=sin(vPosition.x*24.+sin(vPosition.z*20.))*sin(vPosition.y*17.);
        base=mix(base,vec3(.3,.52,.43),smoothstep(.12,.7,patina)*.46);
        float relief=smoothstep(.85,.96,abs(sin(vPosition.x*27.)*cos(vPosition.y*24.)));
        base+=vec3(.13,.11,.04)*relief;polish=.42;
      } else if(uMaterial<2.5){
        float crack=abs(sin(vPosition.x*36.+sin(vPosition.z*26.))*sin(vPosition.y*33.+vPosition.z*19.));
        base*=.94+.06*rough; base=mix(base,base*.7,(1.-smoothstep(.0,.035,crack))*.23);polish=.55;
      } else if(uMaterial<3.5){
        float contour=1.-smoothstep(.02,.07,abs(fract(vPosition.y*28.+vPosition.x*.16)-.5));
        float grid=(1.-smoothstep(.012,.025,abs(fract(vPosition.x*2.)-.5)))*.08;
        base=mix(base,base*.72,contour*.18+grid);polish=.05;
      } else if(uMaterial<4.5){
        float flow=sin(vPosition.x*12.-uTime*1.4+vPosition.z*15.);
        base=mix(vec3(.78,.54,.29),vec3(.77,.35,.42),flow*.18+.26);
        base+=vec3(.18,.12,.06)*pow(max(0.,flow),12.);polish=.65;
      } else if(uMaterial<5.5){base*=1.06;polish=.55;}
      float diffuse=max(0.,dot(n,light));
      float spec=pow(max(0.,dot(n,normalize(light+eye))),28.);
      float rim=pow(1.-max(0.,dot(n,eye)),3.)*.1;
      vec3 lit=base*(.38+diffuse*.62+uDark*.05)+vec3(spec*polish+rim);
      if(uMaterial>3.5&&uMaterial<5.5)lit+=base*.11;
      float fog=smoothstep(9.,29.,-vView.z)*.28;
      outColor=vec4(mix(lit,uBackground,fog),uColor.a);
    }`;
  function layerStyle(mesh,state){
    if(mesh.cityId)return {offset:0,opacity:mesh.cityId===state.selectedId?1:0};
    if(!mesh.layerId)return {offset:0,opacity:mesh.opacity};
    return {offset:mesh.layerId===state.selectedId?.35:0,
      opacity:mesh.opacity*(state.selectedId&&mesh.layerId!==state.selectedId?.35:1)};
  }
  function shader(gl,type,source){
    const result=gl.createShader(type);if(!result)throw new Error('无法创建 shader');
    gl.shaderSource(result,source);gl.compileShader(result);
    if(!gl.getShaderParameter(result,gl.COMPILE_STATUS)){const message=gl.getShaderInfoLog(result);gl.deleteShader(result);throw new Error(message||'Shader 编译失败');}
    return result;
  }
  function gpu(canvas,onLost){
    const gl=canvas.getContext('webgl2',{alpha:false,antialias:true,powerPreference:'low-power',preserveDrawingBuffer:false});
    if(!gl)throw new Error('设备未提供 WebGL2');
    let program,vs,fs,objects=[],width=1,height=1,disposed=false;
    try{
      vs=shader(gl,gl.VERTEX_SHADER,vertex);fs=shader(gl,gl.FRAGMENT_SHADER,fragment);program=gl.createProgram();
      gl.attachShader(program,vs);gl.attachShader(program,fs);gl.linkProgram(program);
      if(!gl.getProgramParameter(program,gl.LINK_STATUS))throw new Error(gl.getProgramInfoLog(program)||'Shader 链接失败');
    }catch(error){if(program)gl.deleteProgram(program);if(vs)gl.deleteShader(vs);if(fs)gl.deleteShader(fs);throw error;}
    gl.deleteShader(vs);gl.deleteShader(fs);
    const loc={};['uMvp','uView','uOffset','uColor','uBackground','uTime','uMaterial','uDark'].forEach(name=>loc[name]=gl.getUniformLocation(program,name));
    const position=gl.getAttribLocation(program,'aPosition'),normal=gl.getAttribLocation(program,'aNormal');
    const lost=event=>{event.preventDefault();if(!disposed)onLost();};canvas.addEventListener('webglcontextlost',lost);
    function clear(){objects.forEach(o=>{gl.deleteBuffer(o.p);gl.deleteBuffer(o.n);gl.deleteVertexArray(o.vao);});objects=[];}
    return {mode:'webgl2',
      rebuild(scene){
        clear();scene.meshes.forEach(mesh=>{
          const vao=gl.createVertexArray(),p=gl.createBuffer(),n=gl.createBuffer();gl.bindVertexArray(vao);
          gl.bindBuffer(gl.ARRAY_BUFFER,p);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array(mesh.positions),gl.STATIC_DRAW);
          gl.enableVertexAttribArray(position);gl.vertexAttribPointer(position,3,gl.FLOAT,false,0,0);
          gl.bindBuffer(gl.ARRAY_BUFFER,n);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array(mesh.normals),gl.STATIC_DRAW);
          gl.enableVertexAttribArray(normal);gl.vertexAttribPointer(normal,3,gl.FLOAT,false,0,0);
          const center=[0,0,0];for(let i=0;i<mesh.positions.length;i++)center[i%3]+=mesh.positions[i]/(mesh.positions.length/3);
          objects.push({mesh,vao,p,n,center});
        });gl.bindVertexArray(null);
      },
      resize(w,h,dpr){width=w;height=h;canvas.width=Math.max(1,Math.round(w*dpr));canvas.height=Math.max(1,Math.round(h*dpr));gl.viewport(0,0,canvas.width,canvas.height);},
      draw(state){
        if(disposed)return;
        const bg=Core.color(state.palette.bg),mat=Core.matrices(state.view,width,height);
        gl.clearColor(...bg,1);gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);gl.enable(gl.DEPTH_TEST);
        gl.enable(gl.BLEND);gl.blendFunc(gl.SRC_ALPHA,gl.ONE_MINUS_SRC_ALPHA);gl.useProgram(program);
        gl.uniformMatrix4fv(loc.uMvp,false,mat.mvp);gl.uniformMatrix4fv(loc.uView,false,mat.view);
        gl.uniform3fv(loc.uBackground,bg);gl.uniform1f(loc.uTime,state.time);gl.uniform1f(loc.uDark,state.dark?1:0);
        // 透明切片只做排序混合，不能把这一实现称作具有顺序无关透明或真实体积成像。
        const sorted=objects.slice().sort((a,b)=>{
          const sa=layerStyle(a.mesh,state),sb=layerStyle(b.mesh,state),oa=sa.opacity>.98,ob=sb.opacity>.98;
          if(oa!==ob)return oa?-1:1;
          const ca=a.center.slice(),cb=b.center.slice();ca[1]+=sa.offset;cb[1]+=sb.offset;
          return Core.rotate(cb,state.view)[2]-Core.rotate(ca,state.view)[2];
        });
        sorted.forEach(o=>{
          const style=layerStyle(o.mesh,state);if(style.opacity<=.01)return;gl.depthMask(style.opacity>.98);
          gl.uniform1f(loc.uOffset,style.offset);gl.uniform4fv(loc.uColor,[...o.mesh.color,style.opacity]);gl.uniform1f(loc.uMaterial,o.mesh.material);
          gl.bindVertexArray(o.vao);gl.drawArrays(gl.TRIANGLES,0,o.mesh.positions.length/3);
        });gl.bindVertexArray(null);gl.depthMask(true);
      },
      dispose(){if(disposed)return;disposed=true;canvas.removeEventListener('webglcontextlost',lost);clear();gl.deleteProgram(program);}
    };
  }
  function software(canvas){
    const destination=canvas.getContext('2d'),backing=document.createElement('canvas'),ctx=backing.getContext('2d',{alpha:false});
    if(!ctx||!destination)throw new Error('软件画布不可用');
    let width=1,height=1,dpr=1,scene,cacheKey='';
    return {mode:'canvas2d',
      rebuild(next){scene=next;cacheKey='';},
      resize(w,h,ratio){width=w;height=h;dpr=ratio;backing.width=Math.max(1,Math.round(w*ratio));backing.height=Math.max(1,Math.round(h*ratio));cacheKey='';},
      draw(state){
        // 软件网格只在视角、主题或选择改变时重绘。流动粒子由上层画布单独更新，
        // 不为呼吸点在每一帧重新投影数千个陶器/蚌壳三角面，也不把静态水面称作 shader。
        const nextKey=JSON.stringify([state.view,state.dark,state.selectedId]);
        if(nextKey===cacheKey){destination.setTransform(1,0,0,1,0,0);destination.drawImage(backing,0,0);return;}
        cacheKey=nextKey;
        ctx.setTransform(dpr,0,0,dpr,0,0);ctx.globalAlpha=1;ctx.fillStyle=state.palette.bg;ctx.fillRect(0,0,width,height);
        if(!scene)return;
        const faces=[],light=[-.42,.7,-.58];
        scene.meshes.forEach(mesh=>{
          const style=layerStyle(mesh,state),p=mesh.positions,n=mesh.normals;
          if(style.opacity<=.01)return;
          for(let i=0;i<p.length;i+=9){
            const pts=[0,3,6].map(k=>Core.project([p[i+k],p[i+k+1]+style.offset,p[i+k+2]],state.view,width,height));
            if(pts.some(v=>!v)||pts.every(v=>v.x<0)||pts.every(v=>v.x>width)||pts.every(v=>v.y<0)||pts.every(v=>v.y>height))continue;
            const nn=Core.rotate([(n[i]+n[i+3]+n[i+6])/3,(n[i+1]+n[i+4]+n[i+7])/3,(n[i+2]+n[i+5]+n[i+8])/3],state.view);
            if(style.opacity>.98&&nn[2]>.12)continue;
            const lum=.39+Math.max(0,nn.reduce((sum,v,k)=>sum+v*light[k],0))*.61;
            const tint=mesh.color.slice();
            if(mesh.material===4){const flow=Math.sin((p[i]+p[i+3]+p[i+6])*4);tint[0]=.76+flow*.04;tint[1]=.5-flow*.06;tint[2]=.32+flow*.04;}
            if(mesh.material===1){const patina=Math.sin(p[i]*21+p[i+1]*11)*.045;tint[1]+=patina;}
            const highlight=mesh.material===1||mesh.material===2?Math.pow(Math.max(0,lum-.1),18)*.15:0;
            faces.push({pts,depth:(pts[0].depth+pts[1].depth+pts[2].depth)/3,
              fill:'rgb('+tint.map(v=>Math.round(Core.clamp(v*lum+highlight,0,1)*255)).join(',')+')',alpha:style.opacity});
          }
        });
        faces.sort((a,b)=>b.depth-a.depth).forEach(face=>{
          ctx.globalAlpha=face.alpha;ctx.fillStyle=face.fill;ctx.beginPath();ctx.moveTo(face.pts[0].x,face.pts[0].y);
          ctx.lineTo(face.pts[1].x,face.pts[1].y);ctx.lineTo(face.pts[2].x,face.pts[2].y);ctx.closePath();ctx.fill();
        });ctx.globalAlpha=1;destination.setTransform(1,0,0,1,0,0);destination.drawImage(backing,0,0);
      },dispose(){scene=null;}
    };
  }
  root.CulturalEngineRenderer={gpu,software,layerStyle};
})(typeof globalThis!=='undefined'?globalThis:this);
