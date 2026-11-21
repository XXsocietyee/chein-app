// N1c · resend verbatim (call 13 was refused by the Starter-plan MCP limit). Finishes the 照片 → 地契 section.
const R={created:[],warn:[],info:{}};
const byId=id=>figma.getNodeByIdAsync(id);
await figma.setCurrentPageAsync(await byId('204:7911'));
const pg=figma.currentPage;
for(const s of ['Regular','Semibold']) await figma.loadFontAsync({family:'SF Pro',style:s});
const TS={}; for(const s of await figma.getLocalTextStylesAsync()) TS[s.name]=s;
const sec=pg.children.find(c=>c.type==='SECTION'&&c.name.startsWith('照片 → 地契'));
const K=['K0','K1','K2','K3'].map(k=>sec.children.find(c=>c.type==='FRAME'&&c.name.startsWith(k+' ')));
R.info.K=K.map(k=>k&&k.id);
try{ const seen=new Set(); const fl=[]; for(const f of pg.flowStartingPoints){ if(seen.has(f.nodeId)) continue; seen.add(f.nodeId); if(f.name!=='xrefs-1 · 照片 → 地契') fl.push(f); } fl.push({nodeId:K[0].id,name:'xrefs-1 · 照片 → 地契'}); pg.flowStartingPoints=fl; R.info.flows=fl.length; }catch(e){ R.warn.push('flow '+String(e).slice(0,120)); }
const n22=await byId('204:26968'); const k3=K[3]; const hp3=k3.findOne(n=>n.name==='hero-photo'); const hp0=K[0].findOne(n=>n.name==='hero-photo');
const D={x:hp3.x,y:hp3.y,w:hp3.width,h:hp3.height}, T={x:hp0.x,y:hp0.y,w:hp0.width,h:hp0.height};
const old=sec.children.find(c=>c.name.startsWith('K · timeline')); if(old) old.remove();
const tl=n22.clone(); sec.appendChild(tl); tl.name='K · timeline (manual keyframes, 1.6 s)'; tl.x=k3.x+393+120; tl.y=k3.y; for(const n of tl.findAll(n=>n.name&&n.name.startsWith('note:'))) n.remove();
const t=figma.createText(); t.fontName={family:'SF Pro',style:'Regular'}; await t.setTextStyleIdAsync(TS['t-head'].id); t.characters='K · timeline · play in Figma motion (1.6 s)'; t.fills=[{type:'SOLID',color:{r:0.557,g:0.557,b:0.576}}]; sec.appendChild(t); t.x=tl.x; t.y=tl.y-40;
const hp=figma.createRectangle(); tl.appendChild(hp); hp.name='hero-photo'; hp.x=D.x; hp.y=D.y; hp.resize(D.w,D.h); hp.fills=JSON.parse(JSON.stringify(hp3.fills)); R.created.push(tl.id,hp.id);
try{
const mi=tl.findOne(n=>n.type==='INSTANCE'&&n.name==='Player/Moment'); const mf=mi.detachInstance(); const st=mf.findOne(n=>n.type==='INSTANCE'&&n.name==='Stage'); const sf=st.detachInstance();
const deed=sf.findOne(n=>n.type==='INSTANCE'&&n.mainComponent&&n.mainComponent.parent&&n.mainComponent.parent.id==='381:1401'); const seal=sf.findOne(n=>n.type==='INSTANCE'&&/seal|Seal/.test(n.name)); const content=mf.findOne(n=>n.name==='content'&&n.type==='FRAME');
const F=v=>({type:'FLOAT',value:v}); const sp=b=>({type:'CUSTOM_SPRING',easingFunctionSpring:{bounce:b}});
const kf=(t,v,e)=>e?{timelinePosition:t,value:v,easing:e}:{timelinePosition:t,value:v};
hp.manualKeyframeTracks={ TRANSLATION_X:{keyframes:[kf(0,F(T.x-D.x)),kf(0.45,F(0),sp(0.14))]}, TRANSLATION_Y:{keyframes:[kf(0,F(T.y-D.y)),kf(0.45,F(0),sp(0.14))]}, WIDTH:{keyframes:[kf(0,F(T.w)),kf(0.45,F(D.w),sp(0.14))]}, HEIGHT:{keyframes:[kf(0,F(T.h)),kf(0.45,F(D.h),sp(0.14))]}, CORNER_RADIUS:{keyframes:[kf(0,F(12)),kf(0.45,F(0),{type:'EASE_OUT'})]} };
deed.manualKeyframeTracks={ OPACITY:{keyframes:[kf(0.25,F(0)),kf(0.6,F(1),{type:'EASE_OUT'})]}, TRANSLATION_Y:{keyframes:[kf(0.25,F(24)),kf(0.67,F(0),sp(0.2))]} };
if(seal) seal.manualKeyframeTracks={ OPACITY:{keyframes:[kf(0.6,F(0)),kf(0.72,F(1),{type:'EASE_OUT'})]}, SCALE_XY:{keyframes:[kf(0.6,{type:'VECTOR',value:{x:1.6,y:1.6}}),kf(0.95,{type:'VECTOR',value:{x:1,y:1}},sp(0.45))]}, ROTATION:{keyframes:[kf(0.6,F(16)),kf(0.95,F(0),sp(0.45))]} };
const chips=content.findOne(n=>n.name==='chips'); let n=0;
for(const c of content.children){ if(!c.visible||c===chips) continue; const t0=/Primary|Secondary/.test(c.name)?1.25:0.95;
c.manualKeyframeTracks={ OPACITY:{keyframes:[kf(t0,F(0)),kf(t0+(t0>=1.25?0.2:0.3),F(1),{type:'EASE_OUT'})]}, TRANSLATION_Y:{keyframes:[kf(t0,F(t0>=1.25?0:12)),kf(t0+0.4,F(0),sp(0.2))]} }; n++; }
if(chips){ const cs=chips.children.filter(c=>c.visible); const D3=[0,0.05,0.09]; cs.forEach((c,i)=>{ const t0=0.95+(D3[i]??0.09); c.manualKeyframeTracks={ OPACITY:{keyframes:[kf(t0,F(0)),kf(t0+0.25,F(1),{type:'EASE_OUT'})]}, TRANSLATION_Y:{keyframes:[kf(t0,F(8)),kf(t0+0.35,F(0),sp(0.2))]} }; n++; }); }
const tls=hp.timelines; if(tls&&tls.length){ try{ hp.setTimelineDuration(tls[0].id,1.6); }catch(e){ R.warn.push('dur '+e); } }
R.info.timeline=hp.timelines; R.info.tracks=n+3; R.info.seal=!!seal;
}catch(e){ R.warn.push('keyframes: '+String(e).slice(0,220)); }
sec.resizeWithoutConstraints(Math.max(sec.width,tl.x+393+120),sec.height);
await sec.screenshot({scale:0.25});
const ip=pg.children.find(c=>c.type==='SECTION'&&c.name.startsWith('原地结果')); await ip.screenshot({scale:0.2});
return R;
