await goPage('204:7911');
const pg=figma.currentPage;
const PH={'武康大楼':['382:1055','382:1056'],'梧桐书店':['382:1063','382:1064'],'老麦咖啡馆':['435:4517','435:4518']};
const NOPH=['453:1395','453:1404'];
async function fixDeeds(root){ let fixed=0, nophoto=[], kept=0;
  const all=root.findAllWithCriteria({types:['INSTANCE']}).filter(d=>{ try{ const m=d.mainComponent; return m&&m.parent&&m.parent.id==='381:1401'; }catch(e){ return false; } });
  for(const d of all){ if(d.removed) continue; const mc=d.mainComponent; if(!mc||!mc.parent||mc.parent.id!=='381:1401') continue;
    const p=d.componentProperties; const pk=Object.keys(p).find(k=>k.startsWith('Photo#')); const nk=Object.keys(p).find(k=>k.startsWith('名称#')); if(!pk||!nk) continue;
    if(/State=Unlit/.test(mc.name)){ kept++; continue; }
    const cur=await byId(p[pk].value); const curName=cur?cur.name:''; const name=p[nk].value; const oneByOne=/Ratio=1:1/.test(curName)||/Size=(Mini|Row)/.test(mc.name);
    const people=/not for deeds/.test(curName); const isDefault=/Place=Default/.test(curName); const named=/Place=(武康大楼|梧桐书店|老麦咖啡馆)/.exec(curName);
    let want=null;
    if(PH[name]) want=PH[name][/Ratio=1:1/.test(curName)?1:0];
    else want=NOPH[oneByOne?1:0];
    if(named&&named[1]===name) continue;
    if(!isDefault&&!people&&!named&&!PH[name]&&/No photo/.test(curName)) continue;
    if(!isDefault&&!people&&named&&named[1]!==name&&PH[name]==null){ /* photo of another place on this deed */ }
    d.setProperties({[pk]:want}); fixed++;
    if(!PH[name]){ const cov=d.findOne(n=>n.type==='INSTANCE'&&n.mainComponent&&n.mainComponent.parent&&n.mainComponent.parent.id==='381:993'); if(cov){ try{ setProps(cov,{'地名':name}); }catch(e){ R.warn.push('地名 '+e); } } nophoto.push(name); } }
  return {fixed,nophoto:[...new Set(nophoto)],unlitKept:kept}; }

await B('deeds',async()=>{ R.info.deedsN1=await fixDeeds(pg); });
const abs=(n,f)=>{ const a=n.absoluteBoundingBox, b=f.absoluteBoundingBox; return {x:a.x-b.x,y:a.y-b.y,w:a.width,h:a.height}; };
const primaryOf=f=>f.findAll(n=>n.type==='INSTANCE'&&n.mainComponent&&n.mainComponent.parent&&n.mainComponent.parent.id==='285:20238').find(b=>/Kind=Primary/.test(b.mainComponent.name));
async function setBtn(f,state,label){ const b=primaryOf(f); if(!b) return 'nobtn'; const cur=b.mainComponent.name; const want=cur.replace(/State=\w+/,'State='+state); const set=b.mainComponent.parent; const v=set.children.find(c=>c.name===want); if(v) b.swapComponent(v); setProps(b,{Label:label}); return b.id; }
let Y0=Math.max(...pg.children.map(c=>c.y+c.height))+240;
async function SECTION(name,lede){ const old=pg.children.find(c=>c.type==='SECTION'&&c.name===name); if(old) old.remove(); const s=figma.createSection(); pg.appendChild(s); s.name=name; s.x=0; s.y=Y0; s.resizeWithoutConstraints(2000,1400); const t=await TX(null,lede,'t-head','ink-2',{w:1800}); t.fills=[RAW('8E8E93')]; s.appendChild(t); t.x=80; t.y=40; R.created.push(s.id); return s; }
const cap=async(s,f,text)=>{ const t=await TX(null,text,'t-head','ink',{w:393}); t.fills=[RAW('8E8E93')]; s.appendChild(t); t.x=f.x; t.y=f.y-40; };
// A · in-place results
await B('inplace',async()=>{
  const s=await SECTION('原地结果 · in-place results (xrefs-1 B.0 · C2)','The result changes the control the player pressed — it never opens a new screen. One capsule: Default → Loading (spinner + 正在…, label stays) → Done (check + 已…). Press dips 0.97 (spring/press); width spring/standard; label cross-fade 200 ms; check scale 0.25 → 1 + blur 4 → 0 in 300 ms; success haptic at Done; sheets close 600 ms after Done with the row behind already updated. Reduce Motion: cross-fades only. Flow 2 on Patterns › Motion choreography.');
  const rows=[['204:26924','N21 → 圈地 · 校验',[['Loading','校验中'],['Done','校验通过']],'Claim: N18 → camera → this sheet. Loading is N21 itself; Done hands the photo to the deed (section 照片 → 地契).'],
    ['204:34263','N34 挑战确认',[['Loading','正在扣 90 积分…'],['Done','挑战已开始']],'Done holds 600 ms, then the task screen N35 pushes (spring/hero).'],
    ['205:8475','N47 开护盾',[['Loading','正在开护盾…'],['Done','护盾已开 · 到明天 02:20']],'Balance rolls 1,286 → 1,226 at Done; the −60 chip fades; sheet closes after 600 ms.'],
    ['205:8580','N48 升级地盘',[['Loading','正在升级…'],['Done','已升级']],'Sheet closes after 600 ms; the row\'s level pips already show the new level.']];
  let x=80; const made=[];
  for(const [fid,label,states,note] of rows){ const src=await byId(fid);
    for(const [st,lab] of states){ const c=src.clone(); s.appendChild(c); c.x=x; c.y=200; c.name=`${label} · ${st} (in place)`; const r=await setBtn(c,st,lab);
      for(const n of c.findAll(n=>n.name&&n.name.startsWith('note:'))) n.remove();
      if(st==='Done'){ for(const ch of c.findAll(n=>n.name==='delta chip (fades after the roll)')) ch.visible=false; }
      await cap(s,c,`${label} · ${st}${st==='Done'?' · '+note:''}`); x+=393+60; made.push(c.id+' '+r); }
    x+=140; }
  s.resizeWithoutConstraints(x+80,200+852+200); R.info.inplace=made; R.info.inplaceSec=s.id; Y0=s.y+s.height+240;
});
// B · claim photo → deed continuity (Smart Animate + keyframes)
await B('continuity',async()=>{
  const s=await SECTION('照片 → 地契 · continuity (xrefs-1 B.0 · C1 · Adopt 1)','The claim photo is the hero. K0 → K3 are Smart Animate frames (layer "hero-photo" matches across them); K · timeline is the same moment as manual keyframes (1.6 s). Origin: the 64 pt thumbnail in the 校验中 sheet. Lead: hero-photo, 0 → 450 ms, spring/hero 0.45 / 0.86 (Figma 195 / 24.02). Followers hooked to the lead: deed band + body from +250 ms (spring/moment), seal +600 (spring/seal, heavy haptic at contact ≈ 780, success +150), headline +950, chips 0 / 50 / 90 ms, actions +1250 (fade 200). Stays still: map, status bar. Interruptible: a tap jumps to K3; Back during flight returns the photo to the thumbnail on the same spring. Reduce Motion: 200 ms cross-fade K0 → K3, haptics stay. SwiftUI: .matchedTransitionSource(id: place.id, in: ns) on the thumbnail + .navigationTransition(.zoom(sourceID:in:)) (iOS 18), else matchedGeometryEffect inside one ZStack.');
  const n21=await byId('204:26924'), n22=await byId('204:26968');
  const thumb=n21.findOne(n=>n.name==='img/现场照片'); const T=abs(thumb,n21); const img=JSON.parse(JSON.stringify(thumb.fills));
  const K=[]; const names=['K0 · 0 ms · 校验通过 (source)','K1 · 200 ms · photo in flight','K2 · 450 ms · photo landed, band rising','K3 · 1,250 ms · settled'];
  const k0=n21.clone(); s.appendChild(k0); K.push(k0); await setBtn(k0,'Done','校验通过');
  for(let i=1;i<4;i++){ const c=n22.clone(); s.appendChild(c); K.push(c); }
  let x=80; for(let i=0;i<4;i++){ const c=K[i]; c.name=names[i]; c.x=x; c.y=200; x+=393+80; for(const n of c.findAll(n=>n.name&&n.name.startsWith('note:'))) n.remove(); await cap(s,c,names[i]); }
  const cover=n22.findOne(n=>n.type==='INSTANCE'&&n.mainComponent&&n.mainComponent.parent&&n.mainComponent.parent.id==='381:993'); const D=abs(cover,n22); R.info.slot=D; R.info.thumb=T;
  const lerp=(a,b,t)=>a+(b-a)*t; const P=[T,{x:lerp(T.x,D.x,0.72),y:lerp(T.y,D.y,0.72),w:lerp(T.w,D.w,0.72),h:lerp(T.h,D.h,0.72)},D,D]; const RAD=[12,6,0,0];
  for(let i=0;i<4;i++){ const c=K[i]; const r=figma.createRectangle(); c.appendChild(r); r.name='hero-photo'; r.x=P[i].x; r.y=P[i].y; r.resize(P[i].w,P[i].h); r.cornerRadius=RAD[i]; r.fills=img; R.created.push(r.id);
    if(i===0){ thumb.visible=true; }
    if(i>0){ const m=c.findOne(n=>n.type==='INSTANCE'&&n.name==='Player/Moment'); const stage=m.findOne(n=>n.name==='Stage'); const deed=stage.findOne(n=>n.type==='INSTANCE'&&n.mainComponent&&n.mainComponent.parent&&n.mainComponent.parent.id==='381:1401'); const seal=stage.findOne(n=>n.type==='INSTANCE'&&/seal|Seal/.test(n.name)); const content=m.findOne(n=>n.name==='content'&&n.type==='FRAME');
      if(i===1){ deed.opacity=0; if(seal) seal.opacity=0; content.opacity=0; }
      if(i===2){ deed.opacity=0.6; if(seal) seal.opacity=0; content.opacity=0; }
    } }
  // Smart Animate chain
  const spr=(k,d)=>({type:'CUSTOM_SPRING',easingFunctionSpring:{mass:1,stiffness:k,damping:d}});
  const link=async(a,b,t,dur,ease)=>{ await a.setReactionsAsync([{trigger:{type:'AFTER_TIMEOUT',timeout:t},actions:[{type:'NODE',destinationId:b.id,navigation:'NAVIGATE',transition:{type:'SMART_ANIMATE',easing:ease,duration:dur},resetScrollPosition:false}]},{trigger:{type:'ON_CLICK'},actions:[{type:'NODE',destinationId:K[3].id,navigation:'NAVIGATE',transition:{type:'DISSOLVE',easing:{type:'EASE_OUT'},duration:0.2},resetScrollPosition:false}]}]); };
  await link(K[0],K[1],0.4,0.2,spr(195,24.02)); await link(K[1],K[2],0.01,0.25,spr(195,24.02)); await link(K[2],K[3],0.01,0.8,spr(223.8,23.94));
  pg.flowStartingPoints=[...pg.flowStartingPoints.filter(f=>f.name!=='xrefs-1 · 照片 → 地契'),{nodeId:K[0].id,name:'xrefs-1 · 照片 → 地契'}];
  R.info.K=K.map(k=>k.id);
  // keyframe timeline
  const tl=n22.clone(); s.appendChild(tl); tl.name='K · timeline (manual keyframes, 1.6 s)'; tl.x=x+80; tl.y=200; for(const n of tl.findAll(n=>n.name&&n.name.startsWith('note:'))) n.remove(); await cap(s,tl,'K · timeline · play in Figma motion (1.6 s)');
  const hp=figma.createRectangle(); tl.appendChild(hp); hp.name='hero-photo'; hp.x=D.x; hp.y=D.y; hp.resize(D.w,D.h); hp.fills=img; R.created.push(hp.id);
  try{
    const mi=tl.findOne(n=>n.type==='INSTANCE'&&n.name==='Player/Moment'); const mf=mi.detachInstance(); const st=mf.findOne(n=>n.type==='INSTANCE'&&n.name==='Stage'); const sf=st.detachInstance();
    const deed=sf.findOne(n=>n.type==='INSTANCE'&&n.mainComponent&&n.mainComponent.parent&&n.mainComponent.parent.id==='381:1401'); const seal=sf.findOne(n=>n.type==='INSTANCE'&&/seal|Seal/.test(n.name)); const content=mf.findOne(n=>n.name==='content'&&n.type==='FRAME');
    const F=v=>({type:'FLOAT',value:v}); const sp=b=>({type:'CUSTOM_SPRING',easingFunctionSpring:{bounce:b}});
    const kf=(t,v,e)=>e?{timelinePosition:t,value:v,easing:e}:{timelinePosition:t,value:v};
    hp.manualKeyframeTracks={ TRANSLATION_X:{keyframes:[kf(0,F(T.x-D.x)),kf(0.45,F(0),sp(0.14))]}, TRANSLATION_Y:{keyframes:[kf(0,F(T.y-D.y)),kf(0.45,F(0),sp(0.14))]}, WIDTH:{keyframes:[kf(0,F(T.w)),kf(0.45,F(D.w),sp(0.14))]}, HEIGHT:{keyframes:[kf(0,F(T.h)),kf(0.45,F(D.h),sp(0.14))]}, CORNER_RADIUS:{keyframes:[kf(0,F(12)),kf(0.45,F(0),{type:'EASE_OUT'})]} };
    deed.manualKeyframeTracks={ OPACITY:{keyframes:[kf(0.25,F(0)),kf(0.6,F(1),{type:'EASE_OUT'})]}, TRANSLATION_Y:{keyframes:[kf(0.25,F(24)),kf(0.67,F(0),sp(0.2))]} };
    if(seal) seal.manualKeyframeTracks={ OPACITY:{keyframes:[kf(0.6,F(0)),kf(0.72,F(1),{type:'EASE_OUT'})]}, SCALE_XY:{keyframes:[kf(0.6,{type:'VECTOR',value:{x:1.6,y:1.6}}),kf(0.95,{type:'VECTOR',value:{x:1,y:1}},sp(0.45))]}, ROTATION:{keyframes:[kf(0.6,F(16)),kf(0.95,F(0),sp(0.45))]} };
    const kids=content.children; const chips=content.findOne(n=>n.name==='chips'); let delays={};
    for(const c of kids){ if(!c.visible) continue; let t0=0.95; if(/Primary|Secondary/.test(c.name)) t0=1.25; if(c===chips) continue;
      c.manualKeyframeTracks={ OPACITY:{keyframes:[kf(t0,F(0)),kf(t0+(t0>=1.25?0.2:0.3),F(1),{type:'EASE_OUT'})]}, TRANSLATION_Y:{keyframes:[kf(t0,F(t0>=1.25?0:12)),kf(t0+0.4,F(0),sp(0.2))]} }; }
    if(chips){ const cs=chips.children.filter(c=>c.visible); const D3=[0,0.05,0.09]; cs.forEach((c,i)=>{ const t0=0.95+(D3[i]??0.09); c.manualKeyframeTracks={ OPACITY:{keyframes:[kf(t0,F(0)),kf(t0+0.25,F(1),{type:'EASE_OUT'})]}, TRANSLATION_Y:{keyframes:[kf(t0,F(8)),kf(t0+0.35,F(0),sp(0.2))]} }; }); }
    const tls=hp.timelines; if(tls&&tls.length) hp.setTimelineDuration(tls[0].id,1.6); R.info.timeline=(hp.timelines||[]).map(t=>t.durationSeconds||t.duration);
  }catch(e){ R.warn.push('keyframes: '+String(e).slice(0,200)); }
  s.resizeWithoutConstraints(tl.x+393+120,200+852+200); R.info.contSec=s.id; R.info.tl=tl.id;
});
return R;
