// B3c · P · SR1-44 drag fix + N08/N11 overlays, SR1-01 meta, SR1-32 chips + rail, SR1-05/46 hold, SR1-04 covers, SR1-03 edge, SR1-45 scroll + fixed, SR1-08 club covers
await goPage(P);
const pg=figma.currentPage; const ERR={}; async function SETR(n,rs,tag){ try{ await n.setReactionsAsync(rs); return true; }catch(e){ const k=tag+': '+String(e).slice(0,60); ERR[k]=(ERR[k]||0)+1; return false; } }
const chipSet=await byId('384:1218'), deedSet=await byId('381:1401'), coverSet=await byId('381:993'), edge=await byId('384:1344'), pbtn=await byId(PBTN), ccSet=await byId('381:1508');
const inc={}; for(const n of pg.findAll(x=>'reactions' in x&&x.reactions&&x.reactions.length)) for(const r of n.reactions) for(const a of actsOf(r)) if(a&&a.destinationId) (inc[a.destinationId]=inc[a.destinationId]||[]).push(n);
const topFrame=n=>{ let p=n; while(p.parent&&p.parent.type!=='SECTION'&&p.parent.type!=='PAGE') p=p.parent; return p; };
// ---- overlays for N08 / N11 copies + drag on every overlay grabber ----
const osec=pg.children.find(s=>s.type==='SECTION'&&/^Overlays · sheets/.test(s.name));
let ox=Math.max(...osec.children.map(c=>c.x+c.width))+80;
for(const sid of [P_N08,P_N11]){ const S=await byId(sid); const sh=S&&S.children.filter(c=>c.type==='FRAME'&&/sheet/i.test(c.name)).sort((a,b)=>b.height-a.height)[0]; if(!sh){ R.warn.push('no sheet '+sid); continue; }
  const O=figma.createFrame(); osec.appendChild(O); O.name='ovl · '+S.name.split(' · ')[0]+' · '+(S.name.split(' · ')[1]||''); O.resize(393,852); O.fills=[]; O.clipsContent=false; O.x=ox; O.y=120; ox+=473; R.created.push(O.id);
  const out=figma.createRectangle(); O.appendChild(out); out.name='⌖ outside → close'; out.resize(393,Math.max(1,sh.y)); out.fills=[]; await SETR(out,[{trigger:{type:'ON_CLICK'},actions:[{type:'CLOSE'}]}],'close');
  const sc=sh.clone(); O.appendChild(sc); sc.x=sh.x; sc.y=sh.y; const gr=figma.createRectangle(); O.appendChild(gr); gr.name='⌖ grabber · drag down → close'; gr.resize(393,32); gr.y=sh.y; gr.fills=[];
  for(const h of S.children.filter(k=>/^⌖/.test(k.name)&&k.y>=sh.y-4&&!/返回/.test(k.name))){ const hc=h.clone(); O.appendChild(hc); hc.x=h.x; hc.y=h.y; }
  for(const src of (inc[sid]||[])){ const rs=src.reactions.map(r=>({trigger:r.trigger,actions:actsOf(r).map(a=>a&&a.type==='NODE'&&a.destinationId===sid?{type:'NODE',destinationId:O.id,navigation:'OVERLAY',transition:{type:'MOVE_IN',direction:'TOP',matchLayers:false,easing:SP('sheet'),duration:DUR.sheet},resetVideoPosition:false}:a)})); await SETR(src,rs,'overlay'); }
  ANN(O,'**skill-r1 SR1-44** · Sheet as an overlay on the live map (no scrim): sheet spring in, drag the grabber or tap outside to close.','I',/^\*\*skill-r1 SR1-44/); }
osec.resizeWithoutConstraints(Math.max(osec.width,ox),osec.height);
let drags=0; const ovIn={}; for(const n of pg.findAll(x=>'reactions' in x&&x.reactions&&x.reactions.length)) for(const r of n.reactions) for(const a of actsOf(r)) if(a&&a.navigation==='OVERLAY') ovIn[a.destinationId]=topFrame(n).id;
for(const O of osec.children.filter(c=>c.type==='FRAME')){ const g=O.findOne(n=>/^⌖ grabber/.test(n.name)); const base=ovIn[O.id]; if(!g||!base) continue;
  const ok=await SETR(g,[{trigger:{type:'ON_DRAG'},actions:[{type:'NODE',destinationId:base,navigation:'NAVIGATE',transition:{type:'MOVE_OUT',direction:'BOTTOM',matchLayers:false,easing:SP('sheet'),duration:0.3},resetScrollPosition:false}]}],'drag-moveout')
    ||await SETR(g,[{trigger:{type:'ON_DRAG'},actions:[{type:'NODE',destinationId:base,navigation:'NAVIGATE',transition:{type:'SMART_ANIMATE',easing:SP('sheet'),duration:0.3},resetScrollPosition:false}]}],'drag-smart'); if(ok) drags++; }
R.info.drags=drags;
// ---- SR1-01 Theme Card meta (component Row/Tile + instances on P) ----
const tc=await byId('287:43163'); let mainFix=0; for(const v of tc.children){ if(!/Size=(Row|Tile)/.test(v.name)) continue; for(const m of v.findAll(n=>n.type==='FRAME'&&/meta/i.test(n.name))){ if(m.layoutMode!=='HORIZONTAL'){ m.layoutMode='HORIZONTAL'; } m.itemSpacing=4; m.primaryAxisSizingMode='AUTO'; m.counterAxisAlignItems='CENTER'; for(const k of m.children) if(k.layoutPositioning==='ABSOLUTE') k.layoutPositioning='AUTO'; mainFix++; } }
let instFix=0; const metaLog=[];
for(const i of pg.findAllWithCriteria({types:['INSTANCE']})){ if(i.id.split(';').length>2) continue; let mc=null; try{ mc=await i.getMainComponentAsync(); }catch(e){ continue; } if(!mc||mc.parent!==tc) continue;
  for(const m of i.findAll(n=>/meta/i.test(n.name)&&n.type!=='TEXT')){ const ts=texts(m).filter(t=>t.visible); const before=ts.map(t=>t.characters).join('|'); let fixed=0; const seen={};
    for(const t of ts){ if(/glyph|icon/i.test(t.name)&&t.id.includes(';')){ const mn=await byId(t.id.split(';').pop()); if(mn&&mn.type==='TEXT'&&mn.characters!==t.characters){ let pp=t.parent, lab=null; while(pp&&pp!==m&&!lab){ lab=pp.children&&pp.children.find(c=>c.type==='TEXT'&&c!==t&&c.name==='label'); pp=pp.parent; } if(lab) await setT(lab,t.characters); await setT(t,mn.characters); fixed++; continue; } }
      if(t.name==='label') continue; const k=t.characters.trim(); const key=t.parent.id+'|'+k; if(seen[key]){ t.visible=false; fixed++; } else seen[key]=1; }
    if(fixed){ instFix++; metaLog.push(before.slice(0,40)+' → '+texts(m).filter(t=>t.visible).map(t=>t.characters).join('|').slice(0,40)); } } }
R.info.meta={mainFix,instFix,log:metaLog.slice(0,8)};
// ---- roam root 210:8322 ----
const roam=await byId('210:8322');
{ const hdr=roam.children.find(c=>c.name==='Player/Root Header'); const row=AL('HORIZONTAL','layer chips · 迷雾 | 领地',{gap:8}); roam.appendChild(row); row.x=16; row.y=(hdr?hdr.y+hdr.height:124)+4;
  const c1=variant(chipSet,{Kind:'Choice',State:'Selected'}).createInstance(); row.appendChild(c1); setProps(c1,{Label:'迷雾'}); const c2=variant(chipSet,{Kind:'Choice',State:'Default'}).createInstance(); row.appendChild(c2); setProps(c2,{Label:'领地'});
  await SETR(c2,[{trigger:{type:'ON_CLICK'},actions:[{type:'NODE',destinationId:P_N07,navigation:'NAVIGATE',transition:{type:'DISSOLVE',easing:SP('press'),duration:DUR.press},resetScrollPosition:false}]}],'chip');
  const pill=AL('HORIZONTAL','city stat pill',{gap:6,pad:[0,12],h:36,r:999,fill:'glass'}); row.appendChild(pill); await IC(pill,'flag',14,'ink'); await TX(pill,'持有 3 / 9 · 今天 +186','t-foot','ink',{name:'city stat'}); await SETR(pill,[{trigger:{type:'ON_CLICK'},actions:[{type:'NODE',destinationId:P_N01,navigation:'NAVIGATE',transition:{type:'PUSH',direction:'LEFT',matchLayers:false,easing:SP('push'),duration:DUR.push},resetScrollPosition:true}]}],'pill');
  SR(roam,'SR1-32','迷雾 | 领地 layer chips and the City stat pill on the roam root (领地 → territory map, pill → CITY board).'); OWN(roam,'Q1','City Monopoly enters from this map; no sixth tab.'); }
// SR1-05 + SR1-46: 走起 as a 52 pt hold button pinned above the 附近 peek, ring drawn at rest; hold = ON_PRESS (reverts on release)
const go=roam.children.find(c=>/走起/.test(c.name)); const near=roam.children.find(c=>/^sheet · 附近/.test(c.name));
let holdFrame=null;
if(go){ const goReacts=(go.reactions||[]).length?go.reactions:(roam.children.find(c=>/^⌖ → consent/.test(c.name))||{reactions:[]}).reactions; const dest=(goReacts.map(r=>actsOf(r)).flat().find(a=>a&&a.destinationId)||{}).destinationId;
  const wrap=AL('VERTICAL','走起 · hold to start (52)',{gap:6,w:361}); roam.appendChild(wrap); wrap.x=16; wrap.y=(near?near.y:620)-12-52-24;
  const ringBox=figma.createFrame(); wrap.appendChild(ringBox); ringBox.name='button + hold ring'; ringBox.resize(361,52); ringBox.fills=[]; ringBox.clipsContent=false;
  const b=variant(pbtn,{Kind:'Primary',Size:'52',State:'Default'}).createInstance(); ringBox.appendChild(b); b.resize(361,52); setProps(b,{Label:'按住 走起'});
  const ring=figma.createRectangle(); ringBox.appendChild(ring); ring.name='hold ring'; ring.resize(369,60); ring.x=-4; ring.y=-4; ring.cornerRadius=30; ring.fills=[]; ring.strokes=[PAINT('ink')]; ring.strokeWeight=2; ring.opacity=0.24;
  const cap=await TX(wrap,'按住 0.8 秒开始漫游','t-foot','ink-2',{name:'caption'}); cap.textAlignHorizontal='CENTER'; cap.layoutSizingHorizontal='FILL';
  go.visible=false;
  // filling state frame: clone of the root with the ring complete
  const sec=roam.parent; holdFrame=roam.clone(); sec.appendChild(holdFrame); holdFrame.name='roam · 走起 按住中 (ring full) · skill-r1 SR1-46'; holdFrame.x=roam.x; holdFrame.y=roam.y+roam.height+120; sec.resizeWithoutConstraints(sec.width,Math.max(sec.height,holdFrame.y+holdFrame.height+80));
  for(const n of holdFrame.findAll(x=>'reactions' in x&&x.reactions&&x.reactions.length)) await SETR(n,[],'clr');
  const hr=holdFrame.findOne(n=>n.name==='hold ring'); if(hr){ hr.opacity=1; hr.strokeWeight=4; hr.strokes=[PAINT('route')]; }
  if(dest) await SETR(holdFrame,[{trigger:{type:'AFTER_TIMEOUT',timeout:0.85},actions:[{type:'NODE',destinationId:dest,navigation:'NAVIGATE',transition:{type:'DISSOLVE',easing:SP('result'),duration:DUR.result},resetScrollPosition:true}]}],'hold-after');
  const hot=figma.createRectangle(); roam.appendChild(hot); hot.name='⌖ 按住 走起 (while pressing)'; hot.resize(361,60); hot.x=16; hot.y=wrap.y-4; hot.fills=[];
  await SETR(hot,[{trigger:{type:'ON_PRESS'},actions:[{type:'NODE',destinationId:holdFrame.id,navigation:'NAVIGATE',transition:{type:'SMART_ANIMATE',easing:{type:'LINEAR'},duration:0.8},resetScrollPosition:false}]}],'hold');
  for(const h of roam.children.filter(c=>/^⌖ → consent/.test(c.name))) h.remove();
  SR(roam,'SR1-05','走起 = Player/Button Primary 52 (361 wide) pinned 12 pt above the 附近 peek, hold ring drawn at rest, caption t-foot.');
  ANN(roam,'**Motion · skill-r1 SR1-46** · Hold: while pressing, the ring fills over 800 ms (linear) → after 0.85 s the walk starts; releasing early springs back (press spring 439 / 33.5). Haptics: impact light at press, rising, success at start. VoiceOver action 开始漫游.','I',/^\*\*Motion · skill-r1 SR1-46/); }
// ---- home 210:8239: rail 我的地盘, real covers ----
const home=await byId('210:8239'); const content=home.children.find(c=>c.name==='content');
{ const cov=(r,p)=>variant(coverSet,{Ratio:r,Place:p})||variant(coverSet,{Ratio:r,Place:'Default'}); let sw=0, k=0;
  const nh=home.findAll(x=>x.type==='TEXT'&&/附近活动/.test(x.characters))[0]; const y0=nh?nh.absoluteBoundingBox.y:-1e9; for(const n of home.findAll(x=>!x.id.includes(';')&&'fills' in x&&Array.isArray(x.fills)&&x.fills.some(f=>f.type==='IMAGE'))){ if(n.width<60||n.absoluteBoundingBox.y<y0) continue; const hash=cov(n.width/n.height>1.3?'16:9':'1:1','Place '+(2+(k++%4))).fills.find(f=>f.type==='IMAGE'); if(hash){ n.fills=n.fills.map(f=>f.type==='IMAGE'?{...f,imageHash:hash.imageHash}:f); sw++; } }
  R.info.homeCovers=sw; SR(home,'SR1-04','附近活动 covers are place photos from Media/Cover (no stock café photos).'); OWN(home,'Q10','In-file place photos replace the stock photos; no stock photos of people.'); }
if(content&&content.layoutMode&&content.layoutMode!=='NONE'){ const kids=content.children; let idx=kids.findIndex(c=>texts(c).some(t=>/附近活动/.test(t.characters))); if(idx<0) idx=Math.min(2,kids.length);
  const rail=AL('VERTICAL','rail · 我的地盘',{gap:10,pad:[8,0,8,0],align:'MIN'}); content.insertChild(idx,rail); rail.layoutSizingHorizontal='FILL';
  const h=AL('HORIZONTAL','rail header',{pad:[0,16]}); rail.appendChild(h); h.layoutSizingHorizontal='FILL'; await TX(h,'我的地盘 · 今天 +186','t-2','ink',{name:'title'}); add(h,AL('HORIZONTAL','spacer'),'FILL'); const all=AL('HORIZONTAL','全部 · hit 44',{h:44,gap:2}); h.appendChild(all); await TX(all,'全部','t-sub','ink-2'); await IC(all,'chev',14,'ink-3'); await SETR(all,[{trigger:{type:'ON_CLICK'},actions:[{type:'NODE',destinationId:P_N01,navigation:'NAVIGATE',transition:{type:'PUSH',direction:'LEFT',matchLayers:false,easing:SP('push'),duration:DUR.push},resetScrollPosition:true}]}],'rail');
  const row=AL('HORIZONTAL','deeds · mini',{gap:12,pad:[0,16]}); rail.appendChild(row); for(const [st,nm,d] of [['Mine','武康大楼',1],['Weathered','安福路 12 号',2],['Mine','愚园路 1088 弄',3]]){ const m=variant(deedSet,{Size:'Mini',State:st}).createInstance(); row.appendChild(m); setProps(m,{'名称':nm}); for(const b of m.findAll(x=>x.name==='band')) b.fills=[PAINT('district/'+d)]; for(const t of m.findAll(x=>x.type==='TEXT'&&x.name==='district')) await setT(t,['武康路','安福路','愚园路'][d-1]); }
  SR(home,'SR1-32','我的地盘 rail (three City/Deed Card Mini, 全部 → CITY board) between 编辑精选 and 附近活动.'); }
// ---- clubs 210:8452: three different default covers ----
{ const cl=await byId('210:8452'); let k=0; const types=['旅行组织','兴趣社群','校园社团','内容创作团队']; for(const n of cl.findAll(x=>!x.id.includes(';')&&'fills' in x&&Array.isArray(x.fills)&&x.fills.some(f=>f.type==='IMAGE')&&x.width>200)){ const cc=variant(ccSet,{Type:types[k%types.length]}).createInstance(); const par=n.parent; const idx=par.children.indexOf(n); par.insertChild(idx,cc); if(par.layoutMode&&par.layoutMode!=='NONE'){ cc.layoutSizingHorizontal=n.layoutSizingHorizontal==='FILL'?'FILL':'FIXED'; } else { cc.x=n.x; cc.y=n.y; } cc.resize(n.width,n.height); try{ cc.topLeftRadius=n.topLeftRadius; cc.topRightRadius=n.topRightRadius; }catch(e){} n.remove(); k++; } R.info.clubCovers=k; SR(cl,'SR1-08','Each club wears its own Club/Default Cover (type glyph + initial), not the shared 一起玩 illustration.'); }
// ---- SR1-03 scroll edge + SR1-45 scroll & fixed layers ----
const SCROLL=['210:8239','210:8322','210:8374','210:8452','210:8603','210:8708','210:9137',P_N01,P_N56];
const fixedLog={};
for(const id of SCROLL){ const f=await byId(id); if(!f) continue; const tab=f.children.find(c=>/Tab Bar/.test(c.name));
  if(tab&&!f.children.some(c=>c.name==='Chrome/Scroll Edge')){ const e=edge.createInstance(); f.appendChild(e); e.x=0; e.y=f.height-120; }
  if(f.height>852){ f.resize(393,852); } f.clipsContent=true; f.overflowDirection='VERTICAL';
  const fx=f.children.filter(c=>/Status Bar|Root Header|Tab Bar|Sticky Bar|Scroll Edge|^nav$|^bar$|^map top|hold to start|layer chips/.test(c.name));
  const order=['Chrome/Scroll Edge']; fx.sort((a,b)=>(a.name==='Chrome/Scroll Edge'?-1:0)-(b.name==='Chrome/Scroll Edge'?-1:0)); for(const c of fx) f.appendChild(c); f.numberOfFixedChildren=fx.length; fixedLog[id]=fx.map(c=>c.name.slice(0,14)).join(','); }
R.info.fixed=fixedLog;
for(const id of SCROLL.slice(0,5)) SR(await byId(id),'SR1-45','Scrolls vertically; status bar, header and tab bar fixed; Chrome/Scroll Edge fades content under the floating tab bar (SR1-03).');
R.info.ERR=ERR;
await roam.screenshot({scale:0.4}); await home.screenshot({scale:0.4}); await (await byId('210:8452')).screenshot({scale:0.4});
R.created=R.created.length; R.touched=R.touched.length; R.ann=R.ann.length; return R;
