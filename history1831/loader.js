'use strict';
const VERSION='classroom-6';
const originalFetch=window.fetch.bind(window);
const byId=id=>document.getElementById(id);
let manifest,engine,cachePromise,firstReceived=0,firstTotal=0;
let secondaryPromise=null,secondaryData=null,secondaryReceived=0;
let lastTap=0;
window.warsawPackState='idle';
window.warsawSceneState='idle';
window.firstSceneReady=false;
let secondaryForeground=false;
const activeGestures=new Set();let lastGestureEnd=-Infinity;
byId('canvas').addEventListener('pointerdown',event=>activeGestures.add(event.pointerId),{passive:true});
for(const type of ['pointerup','pointercancel'])window.addEventListener(type,event=>{activeGestures.delete(event.pointerId);lastGestureEnd=performance.now();},{passive:true});
window.addEventListener('blur',()=>{activeGestures.clear();lastGestureEnd=performance.now();});
async function waitForIdleDownload(){while(!secondaryForeground&&(activeGestures.size>0||performance.now()-lastGestureEnd<600))await new Promise(resolve=>setTimeout(resolve,100));}
window.beginWarsawTransition=function(){byId('transition').hidden=false;byId('fullscreen').hidden=true;window.warsawSceneState='building';};
window.setWarsawTransitionProgress=function(label,value){if(window.warsawSceneState==='building'){byId('transitionStatus').textContent=label;byId('transitionProgress').value=value;}};
window.completeWarsawTransition=function(){window.warsawSceneState='ready';byId('transitionProgress').value=1;requestAnimationFrame(()=>requestAnimationFrame(()=>{byId('transition').hidden=true;byId('fullscreen').hidden=false;}));};
function abortWarsawTransition(){window.warsawSceneState='error';byId('transition').hidden=true;byId('fullscreen').hidden=false;}
const CACHE='history1831-verified-parts-v2';
const pool={active:0,queue:[],limit:3,async run(task){if(this.active>=this.limit)await new Promise(resolve=>this.queue.push(resolve));this.active++;try{return await task();}finally{this.active--;this.queue.shift()?.();}}};
function setStatus(text){byId('status').textContent=text;}
function progress(part,phase){
 if(phase==='first'){firstReceived+=part.bytes;byId('progress').value=firstReceived;setStatus(`正在准备第一幕 ${Math.min(100,Math.round(firstReceived/firstTotal*100))}%`);}
 else {secondaryReceived+=part.bytes;const total=manifest.secondary['warsaw.pck'].compressedBytes;byId('transitionProgress').value=Math.min(0.75,secondaryReceived/total*0.75);byId('transitionStatus').textContent=`正在准备第二幕 ${Math.min(100,Math.round(secondaryReceived/total*100))}%`;}
}
async function storageCache(){
 if(!cachePromise)cachePromise=(async()=>{try{return await caches.open(CACHE);}catch{return null;}})();
 return cachePromise;
}
async function digest(data){return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',data))).map(x=>x.toString(16).padStart(2,'0')).join('');}
async function partBytes(part,phase){
 return pool.run(async()=>{
  const url=new URL(part.file,location.href);url.searchParams.set('v',part.sha256);
  const cache=await storageCache();let data;
  if(cache){try{const response=await cache.match(url.href);if(response){const stored=await response.arrayBuffer();if(stored.byteLength===part.bytes&&await digest(stored)===part.sha256)data=stored;else await cache.delete(url.href);}}catch{}}
  if(!data){
   let last;
   for(let attempt=0;attempt<3;attempt++){
    try{
     const response=await originalFetch(url.href,{cache:'force-cache',signal:AbortSignal.timeout(45000)});
     if(!response.ok)throw Error(`资源下载失败 (${response.status})`);
     data=await response.arrayBuffer();
     if(data.byteLength!==part.bytes||await digest(data)!==part.sha256)throw Error('资源校验未通过');
     if(cache){try{await cache.put(url.href,new Response(data,{headers:{'Content-Type':'application/octet-stream'}}));}catch{}}
     break;
    }catch(error){last=error;data=null;if(attempt<2)await new Promise(resolve=>setTimeout(resolve,500*(attempt+1)));}
   }
   if(!data)throw last;
  }
  progress(part,phase);return data;
 });
}
function decompressedStream(file,phase){
 // A sliding window limits both simultaneous connections and buffered mobile memory.
 let next=0;const pending=new Map();
 function schedule(index){if(index<file.parts.length&&!pending.has(index))pending.set(index,partBytes(file.parts[index],phase).then(data=>({data}),error=>({error})));}
 for(let index=0;index<3;index++)schedule(index);
 const compressed=new ReadableStream({async pull(controller){try{if(next>=file.parts.length){controller.close();return;}const result=await pending.get(next);if(result.error)throw result.error;const data=result.data;pending.delete(next);next++;schedule(next+2);controller.enqueue(new Uint8Array(data));}catch(error){controller.error(error);}}});
 return compressed.pipeThrough(new DecompressionStream('gzip'));
}
async function getManifest(){
 if(!manifest){const response=await originalFetch(`manifest.json?v=${VERSION}`,{cache:'no-cache'});if(!response.ok)throw Error('场景清单未能下载');manifest=await response.json();}
 return manifest;
}
window.fetch=async function(input,init){
 const url=typeof input==='string'?input:input.url;
 const name=new URL(url,location.href).pathname.split('/').pop();
 if(manifest?.files[name])return new Response(decompressedStream(manifest.files[name],'first'),{headers:{'Content-Type':name.endsWith('.wasm')?'application/wasm':'application/octet-stream'}});
 return originalFetch(input,init);
};
window.prepareWarsawPack=async function(background=false){
 if(!background){secondaryForeground=true;window.beginWarsawTransition();}
 if(window.warsawPackState==='ready')return;
 if(!secondaryPromise){
  window.warsawPackState='loading';secondaryReceived=0;
  secondaryPromise=(async()=>{
   await getManifest();
   // Cache the compressed pieces in the background, then decode only at the scene transition.
   const file=manifest.secondary['warsaw.pck'];
   for(const part of file.parts){if(background)await waitForIdleDownload();await partBytes(part,'second');}
   return true;
  })().catch(error=>{window.warsawPackState='error';secondaryPromise=null;byId('transitionStatus').textContent='第二幕下载未完成，点击出口可以重试。';if(!background)abortWarsawTransition();throw error;});
 }
 try{
  await secondaryPromise;
  if(background)return;
  if(!secondaryData)secondaryData=await new Response(decompressedStream(manifest.secondary['warsaw.pck'],'second')).arrayBuffer();
  engine.copyToFS('/warsaw.pck',secondaryData);
  secondaryData=null;window.warsawPackState='ready';byId('transitionStatus').textContent='正在打开华沙场景';byId('transitionProgress').value=0.75;
 }catch(error){window.warsawPackState='error';if(!background)abortWarsawTransition();console.error(error);}
};
async function fullscreen(){
 try{
  if(document.fullscreenElement||document.webkitFullscreenElement){await(document.exitFullscreen?.()||document.webkitExitFullscreen?.());}
  else {const root=document.documentElement;const request=root.requestFullscreen||root.webkitRequestFullscreen;if(!request){showMessage('此浏览器暂不支持系统全屏；画面已铺满可用区域。');return;}await request.call(root);}
 }catch{showMessage('全屏未开启，请再次点击全屏按钮。');}
}
function showMessage(text){byId('message').textContent=text;byId('message').hidden=false;setTimeout(()=>byId('message').hidden=true,4000);}
byId('fullscreen').addEventListener('click',fullscreen);
byId('coverFullscreen').addEventListener('click',fullscreen);
function viewportSize(){const view=window.visualViewport;return {width:Math.round(view?.width||innerWidth),height:Math.round(view?.height||innerHeight),left:view?.offsetLeft||0,top:view?.offsetTop||0};}
window.classroomViewportInsets=function(){const view=viewportSize(),style=getComputedStyle(byId('safeInsets'));return [parseFloat(style.paddingLeft)||0,parseFloat(style.paddingTop)||0,parseFloat(style.paddingRight)||0,parseFloat(style.paddingBottom)||0,view.width,view.height].join(',');};
function sizeCanvas(){
 const view=viewportSize(),scale=Math.min(window.devicePixelRatio||1,2,2560/Math.max(view.width,view.height),Math.sqrt(3200000/(view.width*view.height))),canvas=byId('canvas');
 canvas.style.width=view.width+'px';canvas.style.height=view.height+'px';canvas.style.left=view.left+'px';canvas.style.top=view.top+'px';
 const width=Math.round(view.width*scale),height=Math.round(view.height*scale);if(canvas.width!==width)canvas.width=width;if(canvas.height!==height)canvas.height=height;
 document.documentElement.style.setProperty('--usable-height',view.height+'px');
 byId('fullscreen').textContent=document.fullscreenElement||document.webkitFullscreenElement?'退出全屏':'全屏';
}
sizeCanvas();window.addEventListener('resize',sizeCanvas);window.visualViewport?.addEventListener('resize',sizeCanvas);window.visualViewport?.addEventListener('scroll',sizeCanvas);document.addEventListener('fullscreenchange',sizeCanvas);document.addEventListener('webkitfullscreenchange',sizeCanvas);
byId('start').addEventListener('click',async()=>{
 if(engine)return;
 const button=byId('start');button.disabled=true;byId('precache').disabled=true;firstReceived=0;byId('progress').hidden=false;
 try{
  const missing=Engine.getMissingFeatures({threads:false});if(missing.length)throw Error('请使用支持三维场景的新版浏览器');
  await getManifest();firstTotal=Object.values(manifest.files).reduce((sum,file)=>sum+file.compressedBytes,0);byId('progress').max=firstTotal;
  sizeCanvas();engine=new Engine({executable:'index',canvas:byId('canvas'),canvasResizePolicy:0,focusCanvas:true,args:[],fileSizes:{'index.pck':manifest.files['index.pck'].bytes,'index.wasm':manifest.files['index.wasm'].bytes},onPrint:console.log,onPrintError:console.error});
  window.gameEngine=engine;await engine.startGame();setStatus('正在准备清晰场景画面…');while(!window.firstSceneReady)await new Promise(resolve=>setTimeout(resolve,50));byId('cover').hidden=true;byId('fullscreen').hidden=false;byId('canvas').focus();window.gameReady=true;console.log('HISTORY_CLASSROOM_READY');
  setTimeout(()=>window.prepareWarsawPack(true),2500);
 }catch(error){setStatus(`加载未完成：${error.message}\n已下载的部分会保留，点击重试即可继续。`);engine=null;button.disabled=false;byId('precache').disabled=false;}
});
byId('precache').addEventListener('click',async()=>{
 byId('precache').disabled=true;byId('start').disabled=true;byId('progress').hidden=false;firstReceived=0;
 try{
  await getManifest();const all=[...Object.values(manifest.files),...Object.values(manifest.secondary)];firstTotal=all.reduce((sum,file)=>sum+file.compressedBytes,0);byId('progress').max=firstTotal;
  for(const file of all){await Promise.all(file.parts.map(part=>partBytes(part,'first')));}
  setStatus('课前缓存已完成。请保留浏览器数据，上课时点击“开始体验”。');
 }catch(error){setStatus(`缓存未完成：${error.message}。已完成的部分会保留，可以重试。`);}
 finally{byId('precache').disabled=false;byId('start').disabled=false;}
});
