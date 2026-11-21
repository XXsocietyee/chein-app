// B1b · Library 6:3 · SR1-04 (photos into Media/Cover), SR1-33 (Moment/Art), SR1-30 (City/Odds Bar), SR1-25 (Moment/Stage, Player/Moment)
await goPage(LIB);
const sec=await byId(PKIT);
// --- photos: collect place photos already in the file ---
const coverSet=await byId('381:993'); const seen=new Set(coverSet.children.map(c=>c.fills&&c.fills[0]&&c.fills[0].imageHash).filter(Boolean)); const photos=[];
for(const sid of ['123:1497','287:43163','287:43165','204:26961','204:26968','204:33946']){ const s=await byId(sid); if(!s) continue; const all=[s,...('findAll' in s?s.findAll(()=>true):[])];
  for(const n of all){ if(!('fills' in n)||!Array.isArray(n.fills)) continue; const f=n.fills.find(f=>f.type==='IMAGE'&&f.visible!==false); if(!f||seen.has(f.imageHash)||/memoji|avatar|头像|profile|people|person/i.test(n.name)) continue; seen.add(f.imageHash); photos.push({h:f.imageHash,name:n.name,src:sid,w:Math.round(n.width),hh:Math.round(n.height)}); } }
R.info.photos=photos.slice(0,12);
const add16=[],add11=[]; const PL=photos.slice(0,6);
for(let i=0;i<PL.length;i++) for(const ratio of ['16:9','1:1']){ const w=ratio==='16:9'?320:160,h=ratio==='16:9'?180:160; const c=figma.createComponent(); c.name=`Ratio=${ratio}, Place=Place ${i+1}`; c.resize(w,h); c.clipsContent=true; c.fills=[{type:'IMAGE',imageHash:PL[i].h,scaleMode:'FILL'}]; coverSet.appendChild(c); R.created.push(c.id); }
const order=c=>(c.name.includes('16:9')?0:100)+(c.name.includes('Default')?50:parseInt((c.name.match(/Place (\d)/)||[0,0])[1]));
[...coverSet.children].sort((a,b)=>order(a)-order(b)).forEach((c,i)=>coverSet.insertChild(i,c)); gridSet(coverSet,PL.length+1);
const cov=(ratio,place)=>variant(coverSet,{Ratio:ratio,Place:place})||variant(coverSet,{Ratio:ratio,Place:'Default'});
// swap the deed photos to Place 1 now that it exists
const deedSet=await byId('381:1401'); let sw=0; if(PL.length) for(const v of deedSet.children) for(const ph of v.findAll(n=>n.type==='INSTANCE'&&n.name==='photo')){ const mc=await ph.getMainComponentAsync(); const r=mc.name.includes('16:9')?'16:9':'1:1'; const w=ph.width,h=ph.height; ph.swapComponent(cov(r,'Place 1')); if(ph.parent.layoutMode==='NONE'||ph.layoutSizingHorizontal!=='FILL') ph.resize(w,h); sw++; }
R.info.deedPhotos=sw;
// sync section layout cursor
_py=null;
// --- Moment/Art (SR1-33 · Q8): the Badge/Art language for every moment object ---
const badge=await byId(BADGE); const shapes={};
for(const v of badge.children){ if(!/Lit=On/.test(v.name)) continue; const s=v.children.find(c=>/^shape/.test(c.name)); if(s&&!shapes[s.name]) shapes[s.name]=s; }
const SN=Object.keys(shapes); R.info.shapes=SN; const shield=shapes[SN.find(n=>/shield/.test(n))||SN[0]], hexa=shapes[SN.find(n=>/hex/.test(n))||SN[1]], medal=shapes[SN.find(n=>/medal|circle|round|ribbon/.test(n))||SN[2]];
function d20svg(a,b,line){ return `<svg width="100" height="100" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${a}"/><stop offset="1" stop-color="${b}"/></linearGradient></defs><polygon points="50,3 91,26.5 91,73.5 50,97 9,73.5 9,26.5" fill="url(#g)"/><g fill="none" stroke="${line}" stroke-width="1.6" stroke-linejoin="round"><polygon points="50,3 91,26.5 91,73.5 50,97 9,73.5 9,26.5"/><polygon points="50,22 76,67 24,67"/><path d="M50,3 L50,22 M91,26.5 L76,67 M9,26.5 L24,67 M50,97 L24,67 M50,97 L76,67 M91,73.5 L76,67 M9,73.5 L24,67 M9,26.5 L50,22 M91,26.5 L50,22"/></g><path d="M18,24 Q50,8 82,24" fill="none" stroke="#FFFFFF" stroke-opacity=".45" stroke-width="3" stroke-linecap="round"/></svg>`; }
async function art(kind,size){ const c=figma.createComponent(); c.name=`Kind=${kind}`; c.resize(size,size); c.fills=[]; R.created.push(c.id);
  const put=(src)=>{ const s=src.clone(); c.appendChild(s); s.rescale(size/96); s.x=(size-s.width)/2; s.y=(size-s.height)/2; s.name='shape'; return s; };
  const glyph=async(name,gs)=>{ const g=await IC(c,name,gs,'on-solid','emblem'); g.x=(size-gs)/2; g.y=(size-gs)/2; const t=g.findOne(n=>n.type==='TEXT'); if(t) t.fills=[RAW('FFFFFF')]; return g; };
  if(kind==='Flag'){ put(shield); await glyph('flag',Math.round(size*0.36)); }
  else if(kind==='Shield'){ put(shield); await glyph('check',Math.round(size*0.36)); }
  else if(kind==='Seal'){ put(hexa); const t=await TX(c,'已圈下','t-3','on-solid',{name:'seal text'}); t.fills=[RAW('FFFFFF')]; t.fontSize=Math.round(size*0.2); t.x=(size-t.width)/2; t.y=(size-t.height)/2; }
  else if(kind==='Coin'){ put(hexa); const t=await TX(c,'积','t-hero','on-solid',{name:'coin glyph'}); t.fills=[RAW('FFFFFF')]; t.fontSize=Math.round(size*0.36); t.x=(size-t.width)/2; t.y=(size-t.height)/2; }
  else if(kind==='Level'){ put(medal); await glyph('arrow-up',Math.round(size*0.36)); }
  else if(kind==='Die'||kind==='Die · Lost'){ const lost=kind!=='Die'; const d=SVG(c,d20svg(lost?'#8E8E93':'#FFD86B',lost?'#48484A':'#D99A12',lost?'#C7C7CC':'#FFF1C4'),'d20'); d.rescale(size/100); d.x=0; d.y=0; const t=await TX(c,'17','t-hero','on-solid',{name:'face'}); t.fills=[RAW(lost?'F2F2F7':'3A2A00')]; t.fontSize=Math.round(size*0.2); t.x=(size-t.width)/2; t.y=size*0.52-t.height/2; }
  return c; }
const arts=[]; for(const k of ['Flag','Die','Die · Lost','Shield','Coin','Seal','Level']) arts.push(await art(k,160));
const artSet=await SETOF(arts,'Moment/Art',7,'skill-r1 SR1-33 · Owner default Q8: every moment object is drawn in the Badge/Art language (gloss, three shapes, SF glyph). Flag = claim, Die = challenge (d20; Die · Lost for a lost roll, grey, never red), Shield = defence, Coin = rent (积分 only), Seal = stamp 已圈下, Level = attribute up. Scale freely.',sec);
await placeIn(sec,artSet,'Moment/Art · Kind (skill-r1 SR1-33 · Q8)'); OWN(artSet,'Q8','Badge/Art style adopted for all moments.');
const A=k=>variant(artSet,{Kind:k});
// --- City/Odds Bar (SR1-30) ---
const ob=figma.createComponent(); ob.name='City/Odds Bar'; ob.layoutMode='VERTICAL'; ob.primaryAxisSizingMode='AUTO'; ob.counterAxisSizingMode='FIXED'; ob.resize(329,10); ob.itemSpacing=10; ob.fills=[]; ob.counterAxisAlignItems='MIN'; R.created.push(ob.id);
{ const top=add(ob,AL('HORIZONTAL','target row',{gap:4}),'FILL'); await TX(top,'需要掷出 ≥ 9','t-2','ink',{name:'target'}); add(top,AL('HORIZONTAL','spacer'),'FILL'); const hit=AL('HORIZONTAL','info · hit 44',{w:44,h:44,justify:'CENTER'}); top.appendChild(hit); await IC(hit,'info',22,'ink-2');
  const bar=add(ob,AL('HORIZONTAL','bar · 20 faces',{gap:3}),'FILL'); for(let k=0;k<20;k++){ const s=RECT(bar,13,12,k>=8?'ink':'fill',{r:3,name:k>=8?'face win':'face lose'}); s.layoutGrow=1; }
  await TX(ob,'20 面骰 · 12 个面能赢 (60%)','t-foot','ink-2',{name:'caption'});
  const mods=add(ob,AL('HORIZONTAL','modifiers',{gap:8}),'FILL'); for(const m of ['任务 +2','洞察 +1']){ const ch=AL('HORIZONTAL','modifier',{pad:[4,10],r:999,fill:'surface-2'}); mods.appendChild(ch); await TX(ch,m,'t-foot','ink',{name:'modifier label'}); } }
tprop(ob,'Target','需要掷出 ≥ 9','target'); tprop(ob,'Caption','20 面骰 · 12 个面能赢 (60%)','caption');
ob.description='skill-r1 SR1-30. The decision as a picture: target in t-2, 20 faces with the winning faces filled (ink), the chance as a caption, modifiers as chips; ⓘ opens the full rules sheet. Same bar on N34 and N36.';
newRow(); await placeIn(sec,ob,'City/Odds Bar (skill-r1 SR1-30)');
// --- Moment/Stage (SR1-25): the stage objects, 393×440 ---
const DEED=(s,st)=>variant(deedSet,{Size:s,State:st});
async function stage(kind){ const c=figma.createComponent(); c.name=`Kind=${kind}`; c.resize(393,440); c.fills=[]; c.clipsContent=false; R.created.push(c.id);
  const inst=(comp,x,y,rot,scale)=>{ const i=comp.createInstance(); c.appendChild(i); if(scale) i.rescale(scale); i.x=x; i.y=y; if(rot) i.rotation=rot; R.created.push(i.id); return i; };
  if(kind==='Claim'){ inst(DEED('Full','Mine'),32,10); const s=inst(A('Seal'),262,-10,-8,0.6); s.name='seal 已圈下'; }
  else if(kind==='Ready'){ inst(A('Die'),116,20); const o=ob.createInstance(); c.appendChild(o); o.x=32; o.y=230; }
  else if(kind==='Rolling'){ const d=inst(A('Die'),76,60,14,1.5); d.name='die 240'; }
  else if(kind==='Won'){ const dd=inst(DEED('Full','Mine'),32,10); const d=inst(A('Die'),250,300,10,0.7); d.name='die resting'; }
  else if(kind==='Lost roll'){ inst(A('Die · Lost'),96,60,0,1.25); }
  else if(kind==='Place lost'){ const d=inst(DEED('Full','Other'),52,40,6,0.88); d.opacity=0.72; }
  else if(kind==='Defended'){ inst(DEED('Full','Mine'),32,10); const s=inst(A('Shield'),262,-10,0,0.6); s.name='shield badge'; }
  else if(kind==='Rent'){ inst(A('Coin'),96,40,0,1.25); }
  else if(kind==='Level'){ inst(A('Level'),96,40,0,1.25); }
  return c; }
const stages=[]; for(const k of ['Claim','Ready','Rolling','Won','Lost roll','Place lost','Defended','Rent','Level']) stages.push(await stage(k));
const stageSet=await SETOF(stages,'Moment/Stage',5,'skill-r1 SR1-25. The object a moment is about, staged in the top 56% of Player/Moment. Built only from City/Deed Card, Moment/Art and City/Odds Bar instances.',sec);
newRow(); await placeIn(sec,stageSet,'Moment/Stage · Kind (skill-r1 SR1-25)');
// --- Player/Moment (393×852) ---
const pbtn=await byId(PBTN); const BTN=(kind,size)=>variant(pbtn,{Kind:kind,Size:size,State:'Default'});
const pm=figma.createComponent(); pm.name='Player/Moment'; pm.layoutMode='VERTICAL'; pm.primaryAxisSizingMode='FIXED'; pm.counterAxisSizingMode='FIXED'; pm.resize(393,852); pm.itemSpacing=0; pm.paddingTop=54; pm.paddingBottom=34; fillV(pm,'bg'); pm.counterAxisAlignItems='CENTER'; R.created.push(pm.id);
{ const st=variant(stageSet,{Kind:'Claim'}).createInstance(); pm.appendChild(st); st.name='Stage'; st.isExposedInstance=true;
  const body=add(pm,AL('VERTICAL','content',{pad:[24,24,0,24],gap:8,align:'MIN'}),'FILL','FILL');
  const h=await TX(body,'圈下了','t-1','ink',{name:'headline',fill:true});
  const l=await TX(body,'武康大楼现在是你的。每个到访的人都会给你留下 12 积分。','t-sub','ink-2',{name:'line',fill:true});
  const chips=add(body,AL('HORIZONTAL','chips',{gap:8}),'FILL'); chips.layoutWrap='WRAP'; chips.counterAxisSpacing=8; chips.paddingTop=8;
  const cl=['−120 积分','保护到 明天 14:20','探索 +30']; for(let k=0;k<3;k++){ const ch=AL('HORIZONTAL','chip '+(k+1),{pad:[8,12],r:999,fill:'surface-2'}); chips.appendChild(ch); await TX(ch,cl[k],'role/chip','ink',{name:'chip '+(k+1)+' label'}); }
  add(body,AL('VERTICAL','spacer'),'FILL','FILL');
  const p=BTN('Primary','52').createInstance(); body.appendChild(p); p.layoutSizingHorizontal='FILL'; p.name='Primary'; p.isExposedInstance=true; setProps(p,{Label:'去看看我的地盘'});
  const s=BTN('Text','44').createInstance(); body.appendChild(s); s.layoutSizingHorizontal='FILL'; s.name='Secondary'; s.isExposedInstance=true; setProps(s,{Label:'分享地契'}); }
tprop(pm,'Headline','圈下了','headline'); tprop(pm,'Line','武康大楼现在是你的。每个到访的人都会给你留下 12 积分。','line');
tprop(pm,'Chip 1','−120 积分','chip 1 label'); tprop(pm,'Chip 2','保护到 明天 14:20','chip 2 label'); tprop(pm,'Chip 3','探索 +30','chip 3 label');
const k2=pm.addComponentProperty('Show chip 2','BOOLEAN',true), k3=pm.addComponentProperty('Show chip 3','BOOLEAN',true); pm.findOne(n=>n.name==='chip 2').componentPropertyReferences={visible:k2}; pm.findOne(n=>n.name==='chip 3').componentPropertyReferences={visible:k3};
pm.description='skill-r1 SR1-25. One layout for every game moment: Stage (Moment/Stage, top 56%), headline t-1 28 Bold, one line t-sub 15, at most three delta chips, one primary (52), one text link. Motion: Stage object enters with the moment spring (response .40, damping .55 → Figma spring 247/17.3); chips count in 220 ms. Tap anywhere skips to the settled frame. Reduce Motion: cross-fade 200 ms, haptics kept.';
await placeIn(sec,pm,'Player/Moment (skill-r1 SR1-25)');
ANN(pm,'**Motion · 动效与触感 (skill-r1 SR1-25 / SR1-47)**\n- Stage: moment spring (Figma stiffness 247, damping 17.3 · SwiftUI response .40, damping .55)\n- Headline + line: fade up 12 pt, 250 ms after the stage lands\n- Chips: numericText roll 220 ms\n- Haptic per verb from the Motion & Haptics board (Library 02 Patterns)\n- Tap anywhere → settled frame. Reduce Motion → 200 ms cross-fade.','I',/^\*\*Motion/);
await stageSet.screenshot({scale:0.35}); await pm.screenshot({scale:0.4});
R.info.ids={coverSet:coverSet.id,artSet:artSet.id,odds:ob.id,stageSet:stageSet.id,moment:pm.id};
R.created=R.created.length; return R;
