// B3b · P · SR1-43 springs, SR1-44 sheets as overlays + drag, SR1-48 44 pt hotspots, SR1-50 loose ends
await goPage(P);
const pg=figma.currentPage;
// ---------- SR1-44 overlays ----------
const SHEETS=['210:8892','210:9344',P_N88,P_N08,P_N11,P_N18,P_N21,P_N34,'210:10410','345:3309'];
const inc={}; for(const n of pg.findAll(x=>'reactions' in x&&x.reactions&&x.reactions.length)) for(const r of n.reactions) for(const a of actsOf(r)) if(a&&a.destinationId) (inc[a.destinationId]=inc[a.destinationId]||[]).push(n);
let osec=pg.children.find(s=>s.type==='SECTION'&&/^Overlays · sheets/.test(s.name)); if(!osec){ osec=figma.createSection(); osec.name='Overlays · sheets (skill-r1 SR1-44)'; const right=Math.max(...pg.children.filter(c=>c!==osec).map(c=>c.x+c.width)); osec.x=right+400; osec.y=0; R.created.push(osec.id); }
let ox=80; const made=[]; let opened=0;
for(const sid of SHEETS){ const S=await byId(sid); if(!S){ R.warn.push('no sheet '+sid); continue; }
  const sh=S.children.filter(c=>c.type==='FRAME'&&/sheet/i.test(c.name)&&c.y>150).sort((a,b)=>b.height-a.height)[0]; if(!sh){ R.warn.push('no sheet node in '+sid); continue; }
  const isMap=S.findAll(n=>n.type==='INSTANCE'&&n.name==='Map/Base').length>0||/map|地图/i.test(S.name);
  const O=figma.createFrame(); osec.appendChild(O); O.name='ovl · '+S.name.split(' · ')[0]+' · '+S.name.split(' · ')[1]; O.resize(393,852); O.fills=[]; O.clipsContent=false; O.x=ox; O.y=120; ox+=393+80; R.created.push(O.id);
  const out=figma.createRectangle(); O.appendChild(out); out.name='⌖ outside → close'; out.resize(393,Math.max(1,sh.y)); out.x=0; out.y=0; out.fills=isMap?[]:[{...PAINT('scrim')}]; if(!isMap) out.opacity=1; await out.setReactionsAsync([{trigger:{type:'ON_CLICK'},actions:[{type:'CLOSE'}]}]);
  const sc=sh.clone(); O.appendChild(sc); sc.x=sh.x; sc.y=sh.y;
  const gr=figma.createRectangle(); O.appendChild(gr); gr.name='⌖ grabber · drag down → close'; gr.resize(393,32); gr.x=0; gr.y=sh.y; gr.fills=[]; await gr.setReactionsAsync([{trigger:{type:'ON_DRAG'},actions:[{type:'CLOSE'}]}]);
  for(const h of S.children.filter(k=>/^⌖/.test(k.name)&&k.y>=sh.y-4&&!/返回/.test(k.name))){ const hc=h.clone(); O.appendChild(hc); hc.x=h.x; hc.y=h.y; }
  for(const src of (inc[sid]||[])){ if(O.findOne(x=>x===src)) continue; const rs=src.reactions.map(r=>({trigger:r.trigger,actions:actsOf(r).map(a=>a&&a.type==='NODE'&&a.destinationId===sid?{type:'NODE',destinationId:O.id,navigation:'OVERLAY',transition:{type:'MOVE_IN',direction:'TOP',matchLayers:false,easing:SP('sheet'),duration:DUR.sheet},resetVideoPosition:false}:a)})); await src.setReactionsAsync(rs); opened++; }
  ANN(O,'**skill-r1 SR1-44** · Sheet as an overlay: rises with the sheet spring (Figma 273 / 28.4 · SwiftUI response .38, damping .86); drag the grabber or tap outside to close.'+(isMap?' Map stays live: no scrim.':' Scrim 40% sits in the outside area.')+' In the Figma UI set this frame\'s overlay to Bottom centre if you split the scrim out (the Plugin API cannot set overlay position).','I',/^\*\*skill-r1 SR1-44/);
  made.push(sid+'→'+O.id); }
osec.resizeWithoutConstraints(Math.max(ox,800),1100);
R.info.overlays=made; R.info.overlayActions=opened;
// ---------- SR1-43 springs ----------
const topFrame=n=>{ let p=n; while(p.parent&&p.parent.type!=='SECTION'&&p.parent.type!=='PAGE') p=p.parent; return p; };
const C={push:0,sheet:0,press:0,moment:0,result:0};
for(const n of pg.findAll(x=>'reactions' in x&&x.reactions&&x.reactions.length)){ let ch=false; const tf=topFrame(n); const rs=n.reactions.map(r=>({trigger:r.trigger,actions:actsOf(r).map(a=>{ if(!a||a.type!=='NODE'||!a.transition) return a; const t=a.transition; let role;
  if(/N22·|N37·|N68·|cok-|roll-|moment|分镜/i.test(tf.name)||(r.trigger.type==='AFTER_TIMEOUT'&&t.type==='SMART_ANIMATE')) role='moment';
  else if(t.type==='PUSH'||t.type==='SLIDE_IN'||t.type==='SLIDE_OUT') role='push';
  else if(t.type==='MOVE_IN'||t.type==='MOVE_OUT') role='sheet';
  else if(t.type==='DISSOLVE') role=/tab/.test(n.name)?'press':(/成功|已创建|已提交|result|结果|完成/.test(n.name)?'result':'sheet');
  else role='press';
  if(t.easing&&t.easing.type==='CUSTOM_SPRING') return a; ch=true; C[role]++; return {...a,transition:{...t,easing:SP(role),duration:DUR[role]}}; })}));
  if(ch) await n.setReactionsAsync(rs); }
R.info.springs=C;
// ---------- SR1-48 hotspots under 44 ----------
let hits=0; for(const n of pg.findAll(x=>'reactions' in x&&x.reactions&&x.reactions.length&&x.type!=='FRAME'||false)){ if(n.removed||n.id.includes(';')) continue; if(n.width>=44&&n.height>=44) continue; if(n.parent.type==='SECTION'||n.parent.type==='PAGE') continue;
  if(n.type==='RECTANGLE'&&(!n.fills.length||n.fills.every(f=>f.visible===false||f.opacity===0))){ const cx=n.x+n.width/2, cy=n.y+n.height/2; const w=Math.max(44,n.width), h=Math.max(44,n.height); n.resize(w,h); n.x=cx-w/2; n.y=cy-h/2; hits++; continue; }
  const par=n.parent; const r=figma.createRectangle(); r.name='⌖ hit 44 · '+n.name.slice(0,20); r.fills=[]; const w=Math.max(44,n.width), h=Math.max(44,n.height); r.resize(w,h); par.appendChild(r); if(par.layoutMode&&par.layoutMode!=='NONE') r.layoutPositioning='ABSOLUTE'; r.x=n.x+n.width/2-w/2; r.y=n.y+n.height/2-h/2; await r.setReactionsAsync(n.reactions.map(x=>({trigger:x.trigger,actions:actsOf(x)}))); await n.setReactionsAsync([]); hits++; }
R.info.hits=hits;
// ---------- SR1-50 loose ends ----------
async function hot(frameId,name,x,y,w,h,dest,trig,tr){ const f=await byId(frameId); if(!f) { R.warn.push('no '+frameId); return; } const r=figma.createRectangle(); f.appendChild(r); r.name=name; r.resize(w,h); r.x=x; r.y=y; r.fills=[]; await r.setReactionsAsync([{trigger:trig||{type:'ON_CLICK'},actions:[{type:'NODE',destinationId:dest,navigation:'NAVIGATE',transition:tr||{type:'SMART_ANIMATE',easing:SP('press'),duration:DUR.press},resetScrollPosition:true}]}]); R.created.push(r.id); return r; }
{ const lobby=await byId('204:15032'); if(lobby){ const rs=(lobby.reactions||[]).filter(r=>r.trigger.type!=='AFTER_TIMEOUT').map(r=>({trigger:r.trigger,actions:actsOf(r)})); rs.push({trigger:{type:'AFTER_TIMEOUT',timeout:1.2},actions:[{type:'NODE',destinationId:'289:2730',navigation:'NAVIGATE',transition:{type:'SMART_ANIMATE',easing:SP('result'),duration:DUR.result},resetScrollPosition:false}]}); await lobby.setReactionsAsync(rs); } }
await hot('289:2730','⌖ 按住开始 → hold',16,700,361,80,'289:2804',{type:'ON_PRESS'});
await hot(P_PLAY,'⌖ 断网 → playerr (demo)',337,54,44,44,'210:9379');
{ const f=await byId(P_PLAY); if(f) ANN(f,'**skill-r1 SR1-50** · The 断网 hotspot (top right, 44) opens the offline state `210:9379` for the demo; in the app it appears on its own when the connection drops.','I',/^\*\*skill-r1 SR1-50/); }
pg.flowStartingPoints=pg.flowStartingPoints.map(f=>f.name==='Flow 1'?{nodeId:f.nodeId,name:'11 俱乐部 · 创建'}:f);
R.info.flows=pg.flowStartingPoints.map(f=>f.name);
await osec.screenshot({scale:0.15});
R.created=R.created.length; R.ann=R.ann.length; return R;
