// SYNC(pId, srcId, {h, map:{hotspotName:[targetName,...]|null}, add:[[targetName,destId,'PUSH'|'DISSOLVE'|'SMART']], fixed:[names], scroll:true})
function rel(node,root){ const a=node.absoluteBoundingBox, b=root.absoluteBoundingBox; return {x:a.x-b.x,y:a.y-b.y,w:a.width,h:a.height}; }
const TR={PUSH:{type:'PUSH',direction:'LEFT',matchLayers:false,easing:{type:'EASE_OUT'},duration:0.35},DISSOLVE:{type:'DISSOLVE',easing:{type:'EASE_OUT'},duration:0.2},SMART:{type:'SMART_ANIMATE',easing:{type:'EASE_OUT'},duration:0.35}};
async function HOTSPOT(p,name,b,dest,tr){ const r=figma.createRectangle(); p.appendChild(r); r.name='⌖ '+name; r.x=b.x; r.y=b.y; r.resize(Math.max(1,b.w),Math.max(1,b.h)); r.fills=[{type:'SOLID',color:{r:1,g:1,b:1},opacity:0}]; await r.setReactionsAsync([{trigger:{type:'ON_CLICK'},actions:dest==='BACK'?[{type:'BACK'}]:[{type:'NODE',destinationId:dest,navigation:'NAVIGATE',transition:TR[tr||'PUSH'],preserveScrollPosition:false}]}]); return r; }
async function SYNC(pId,srcId,o={}){ const p=await figma.getNodeByIdAsync(pId), s=await figma.getNodeByIdAsync(srcId);
 const hots=p.children.filter(c=>c.name.startsWith('⌖'));
 for(const c of [...p.children]) if(!hots.includes(c)) c.remove();
 p.layoutMode='NONE'; p.fills=JSON.parse(JSON.stringify(s.fills)); p.clipsContent=true;
 for(const c of s.children){ const k=c.clone(); p.appendChild(k); k.x=c.x; k.y=c.y; }
 p.resize(393,o.h||s.height);
 const used={}; const report=[];
 for(const h of hots){ const m=o.map&&(h.name in o.map)?o.map[h.name]:undefined; if(m===null){ h.remove(); report.push('rm '+h.name); continue; }
   if(m){ const list=Array.isArray(m)?m:[m]; const idx=used[h.name]||0; used[h.name]=idx+1; const nm=list[Math.min(idx,list.length-1)]; const t=p.findOne(n=>n.name===nm&&!n.name.startsWith('⌖')); if(t){ const b=rel(t,p); h.x=b.x; h.y=b.y; h.resize(b.w,b.h); report.push('mv '+h.name+'→'+nm); } else report.push('MISS '+nm); }
   p.appendChild(h); }
 for(const [nm,dest,tr,label] of (o.add||[])){ const t=p.findOne(n=>n.name===nm&&!n.name.startsWith('⌖')); if(t){ await HOTSPOT(p,label||('→ '+dest),rel(t,p),dest,tr); report.push('add '+nm); } else report.push('MISS add '+nm); }
 if(o.fixed){ let k=0; const fx=[]; for(const nm of o.fixed){ for(const n of p.children.filter(c=>c.name===nm||(nm==='tabhot'&&c.name.startsWith('⌖ tab')))) fx.push(n); } for(const n of fx) p.appendChild(n); p.numberOfFixedChildren=fx.length; p.overflowDirection='VERTICAL'; report.push('fixed '+fx.length); }
 return report; }
