/* 本地 GLB 2.0 的静态几何接入点。支持非压缩 TRIANGLES、节点矩阵/TRS 和基础材质色。
 * 不加载外链、不把纹理/动画/压缩扩展伪称完成；不支持的必要数据会明确返回程序化示意。
 * 当前只预览几何与近似材质；它不是完整 glTF/PBR 渲染器，也不会调用远程解码服务。 */
(function(root,factory){
  'use strict';
  const api=factory(typeof module==='object'&&module.exports?require('./core.js'):root.CulturalEngineCore);
  if(typeof module==='object'&&module.exports)module.exports=api;else root.CulturalEngineGLB=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(Core){
  'use strict';
  const LIMIT_BYTES=16*1024*1024,LIMIT_VERTICES=180000,LIMIT_TRIANGLES=60000;
  const identity=()=>[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1];
  function integer(v,fallback=0){return Number.isSafeInteger(v)&&v>=0?v:fallback;}
  function byteOffset(v){if(v===undefined)return 0;if(!Number.isSafeInteger(v)||v<0)throw new Error('GLB 字节偏移无效');return v;}
  function mult(a,b){
    const o=new Array(16).fill(0);
    for(let c=0;c<4;c++)for(let r=0;r<4;r++)for(let k=0;k<4;k++)o[c*4+r]+=a[k*4+r]*b[c*4+k];return o;
  }
  function nodeMatrix(node){
    if(node.matrix!==undefined){
      if(Array.isArray(node.matrix)&&node.matrix.length===16&&node.matrix.every(Number.isFinite))return node.matrix.slice();
      throw new Error('GLB 节点矩阵无效');
    }
    const t=node.translation||[0,0,0],s=node.scale||[1,1,1],q=node.rotation||[0,0,0,1];
    if(t.length!==3||s.length!==3||q.length!==4||![...t,...s,...q].every(Number.isFinite))throw new Error('GLB 节点变换无效');
    const [x,y,z,w]=q,xx=x*x,yy=y*y,zz=z*z,xy=x*y,xz=x*z,yz=y*z,wx=w*x,wy=w*y,wz=w*z;
    return [(1-2*(yy+zz))*s[0],2*(xy+wz)*s[0],2*(xz-wy)*s[0],0,
      2*(xy-wz)*s[1],(1-2*(xx+zz))*s[1],2*(yz+wx)*s[1],0,
      2*(xz+wy)*s[2],2*(yz-wx)*s[2],(1-2*(xx+yy))*s[2],0,t[0],t[1],t[2],1];
  }
  function transform(p,m){return [m[0]*p[0]+m[4]*p[1]+m[8]*p[2]+m[12],m[1]*p[0]+m[5]*p[1]+m[9]*p[2]+m[13],m[2]*p[0]+m[6]*p[1]+m[10]*p[2]+m[14]];}
  function transformNormal(p,m){
    // 非均匀缩放不能直接乘原矩阵。用三列叉乘构造逆转置，保证本地模型光照方向正确。
    const a=[m[0],m[1],m[2]],b=[m[4],m[5],m[6]],c=[m[8],m[9],m[10]];
    const cross=(u,v)=>[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]];
    const cols=[cross(b,c),cross(c,a),cross(a,b)],det=a.reduce((n,v,i)=>n+v*cols[0][i],0);
    if(Math.abs(det)<1e-12)throw new Error('GLB 节点缩放退化');
    const out=[0,1,2].map(i=>(cols[0][i]*p[0]+cols[1][i]*p[1]+cols[2][i]*p[2])/det),length=Math.hypot(...out)||1;
    return out.map(v=>v/length);
  }
  function parse(input){
    const bytes=input instanceof Uint8Array?input:new Uint8Array(input);
    if(bytes.byteLength<28||bytes.byteLength>LIMIT_BYTES)throw new Error('GLB 文件大小不受支持');
    const view=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);
    if(view.getUint32(0,true)!==0x46546C67||view.getUint32(4,true)!==2||view.getUint32(8,true)!==bytes.length)throw new Error('不是有效 GLB 2.0 文件');
    let json,bin=null,offset=12;
    while(offset<bytes.length){
      if(offset+8>bytes.length)throw new Error('GLB 分块头不完整');
      const length=view.getUint32(offset,true),type=view.getUint32(offset+4,true);offset+=8;
      if(length%4!==0||offset+length>bytes.length)throw new Error('GLB 分块范围无效');
      const chunk=bytes.subarray(offset,offset+length);
      if(type===0x4E4F534A){if(json)throw new Error('GLB JSON 分块重复');json=JSON.parse(new TextDecoder().decode(chunk).replace(/\0+$/,''));}
      else if(type===0x004E4942){if(bin)throw new Error('GLB BIN 分块重复');bin=chunk;}
      offset+=length;
    }
    if(!json||!bin||!json.asset||json.asset.version!=='2.0')throw new Error('GLB 缺少有效 JSON/BIN 数据');
    const buffers=json.buffers||[];
    if(buffers.length!==1||buffers[0].uri||integer(buffers[0].byteLength,Infinity)>bin.length)throw new Error('GLB 需要完整内嵌几何缓冲');
    if((json.extensionsRequired||[]).some(name=>!['KHR_materials_unlit'].includes(name)))throw new Error('GLB 必需扩展尚未接入');
    const types={SCALAR:1,VEC2:2,VEC3:3,VEC4:4},component={5120:[1,'getInt8'],5121:[1,'getUint8'],5122:[2,'getInt16'],5123:[2,'getUint16'],5125:[4,'getUint32'],5126:[4,'getFloat32']};
    const cache=new Map();
    function accessor(index,expected){
      const acc=(json.accessors||[])[index];
      if(!acc||acc.sparse||!component[acc.componentType]||!types[acc.type]||(expected&&acc.type!==expected))throw new Error('GLB accessor 类型尚未支持');
      if(expected==='SCALAR'&&(![5121,5123,5125].includes(acc.componentType)||acc.normalized))throw new Error('GLB 索引必须为无符号整数');
      if(expected==='VEC3'&&acc.componentType!==5126)throw new Error('GLB 顶点必须为未量化浮点数据');
      if(cache.has(index))return cache.get(index);
      const bv=(json.bufferViews||[])[acc.bufferView];
      if(!bv||bv.buffer!==0||(bv.extensions&&bv.extensions.EXT_meshopt_compression))throw new Error('GLB 缓冲视图无效或已压缩');
      const count=integer(acc.count,Infinity),size=types[acc.type],info=component[acc.componentType],element=size*info[0];
      const stride=bv.byteStride===undefined?element:integer(bv.byteStride,Infinity),base=byteOffset(bv.byteOffset)+byteOffset(acc.byteOffset);
      const byteLength=integer(bv.byteLength,-1),used=count?(count-1)*stride+element:0;
      if(count>LIMIT_VERTICES||stride<element||base+used>bin.length||byteOffset(acc.byteOffset)+used>byteLength)throw new Error('GLB accessor 越界或过大');
      const dv=new DataView(bin.buffer,bin.byteOffset,bin.byteLength),items=new Array(count);
      for(let i=0;i<count;i++){
        const row=[];
        for(let k=0;k<size;k++){
          let value=dv[info[1]](base+i*stride+k*info[0],true);
          if(acc.normalized&&acc.componentType!==5126){const signed=acc.componentType===5120||acc.componentType===5122;
            const maximum=Math.pow(2,info[0]*8-(signed?1:0))-1;value=Math.max(signed?-1:0,value/maximum);}
          if(!Number.isFinite(value))throw new Error('GLB 几何包含非法数值');row.push(value);
        }
        items[i]=row;
      }
      cache.set(index,items);return items;
    }
    const meshes=[],nodes=json.nodes||[],active=new Set();let triangles=0,visited=0;
    if(nodes.length>512)throw new Error('GLB 节点超出移动视口限制');
    function visit(index,parent,depth){
      const node=nodes[index];
      if(!node||depth>64||active.has(index)||++visited>1024)throw new Error('GLB 节点树无效或过大');
      if(node.skin!==undefined||node.weights)throw new Error('GLB 蒙皮或形态动画尚未接入');
      active.add(index);const matrix=mult(parent,nodeMatrix(node));
      if(node.mesh!==undefined){
        const model=(json.meshes||[])[node.mesh];if(!model||!Array.isArray(model.primitives)||model.primitives.length>128)throw new Error('GLB mesh 无效或过大');
        model.primitives.forEach(primitive=>{
          if((primitive.mode===undefined?4:primitive.mode)!==4||primitive.targets||(primitive.extensions&&primitive.extensions.KHR_draco_mesh_compression))throw new Error('GLB 仅支持未压缩静态三角网格');
          const attrs=primitive.attributes||{},positions=accessor(attrs.POSITION,'VEC3'),normals=attrs.NORMAL===undefined?null:accessor(attrs.NORMAL,'VEC3');
          const indices=primitive.indices===undefined?positions.map((_,i)=>[i]):accessor(primitive.indices,'SCALAR');
          if(indices.length%3!==0||normals&&normals.length!==positions.length)throw new Error('GLB 三角索引或法线数量无效');
          triangles+=indices.length/3;if(triangles>LIMIT_TRIANGLES)throw new Error('GLB 三角面超出移动视口限制');
          const material=(json.materials||[])[primitive.material]||{},pbr=material.pbrMetallicRoughness||{},factor=pbr.baseColorFactor||[.65,.7,.65,1];
          if(!Array.isArray(factor)||factor.length!==4||!factor.every(Number.isFinite))throw new Error('GLB 材质色无效');
          const out=Core.mesh(node.name||model.name||'本地 GLB 几何',pbr.metallicFactor>.4?1:2,'#FFFFFF',Core.clamp(factor[3],.08,1));out.color=factor.slice(0,3).map(v=>Core.clamp(v,0,1));
          for(let i=0;i<indices.length;i+=3){
            const ids=indices.slice(i,i+3).map(v=>v[0]);
            if(ids.some(id=>!Number.isSafeInteger(id)||id<0||id>=positions.length))throw new Error('GLB 三角索引越界');
            const pts=ids.map(id=>transform(positions[id],matrix)),ns=normals?ids.map(id=>transformNormal(normals[id],matrix)):[];
            Core.triangle(out,...pts,...ns);
          }
          if(out.positions.length)meshes.push(out);
        });
      }
      (node.children||[]).forEach(child=>visit(child,matrix,depth+1));active.delete(index);
    }
    const scene=(json.scenes||[])[json.scene||0];
    const children=new Set(nodes.flatMap(node=>node.children||[]));
    const roots=scene&&Array.isArray(scene.nodes)?scene.nodes:nodes.map((_,i)=>i).filter(i=>!children.has(i));
    roots.forEach(index=>visit(index,identity(),0));
    if(!meshes.length)throw new Error('GLB 没有可渲染三角面');
    Core.normalizeMeshes(meshes);
    return {meshes,triangles,message:'本地 GLB 几何预览 · 纹理与动画尚未接入'};
  }
  async function load(path,signal){
    if(!/^\.\.\/models\/[A-Za-z0-9_-]{1,120}\.glb$/.test(path))throw new Error('只接受随包本地 models GLB');
    let bytes;
    try{
      const response=await fetch(path,{cache:'no-store',redirect:'error',credentials:'omit',signal});
      if(!response.ok&&response.status!==0)throw new Error('尚无对应本地模型');
      const length=Number(response.headers.get('content-length')||0);if(length>LIMIT_BYTES)throw new Error('本地模型超出大小限制');
      bytes=await response.arrayBuffer();
    }catch(error){
      if(signal&&signal.aborted)throw new Error('本地模型读取已取消');
      // 部分 ArkWeb 的 rawfile/file 环境不为 fetch 开放本地协议，但可通过原生
      // Web 资源拦截读取 XHR。这里只重试同一个受限本地路径，不改用外网地址。
      if(typeof XMLHttpRequest==='undefined')throw error;
      bytes=await new Promise((resolve,reject)=>{
        const request=new XMLHttpRequest(),abort=()=>{request.abort();reject(new Error('本地模型读取已取消'));};
        function cleanup(){if(signal)signal.removeEventListener('abort',abort);}
        request.open('GET',path,true);request.responseType='arraybuffer';request.timeout=5000;
        request.onload=()=>{cleanup();if((request.status===0||request.status>=200&&request.status<300)&&request.response)resolve(request.response);else reject(new Error('尚无对应本地模型'));};
        request.onerror=()=>{cleanup();reject(new Error('本地模型资源不可读'));};
        request.ontimeout=()=>{cleanup();reject(new Error('本地模型读取超时'));};
        request.onabort=()=>{cleanup();reject(new Error('本地模型读取已取消'));};
        if(signal){if(signal.aborted){abort();return;}signal.addEventListener('abort',abort,{once:true});}
        request.send();
      });
    }
    if(signal&&signal.aborted)throw new Error('本地模型读取已取消');return parse(bytes);
  }
  return {parse,load,LIMIT_BYTES,LIMIT_TRIANGLES};
});
