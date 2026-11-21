// B1d · N1 page · SR1-24 (Map/Base Plain/Fog/Territory, Map/Legend), SR1-26 (pin set by shape/badge/size)
await goPage(N1);
const lsec=await byId('204:7912');
// ---------- Map/Base ----------
const ROADS_MAIN=['M0 150 L393 132','M0 478 L393 470','M0 792 L393 806','M72 0 L60 852','M300 0 C290 300 318 560 296 852'];
const ROADS_MINOR=['M0 312 L393 300','M0 640 L393 632','M186 0 L192 852','M0 720 L393 210'];
const svgPaths=(ds,w)=>`<svg width="393" height="852" viewBox="0 0 393 852" xmlns="http://www.w3.org/2000/svg">${ds.map(d=>`<path d="${d}" fill="none" stroke="#888888" stroke-width="${w}" stroke-linecap="round"/>`).join('')}</svg>`;
const LABELS=[['复兴西路',104,124,2.6],['安福路',108,290,1.8],['湖南路',116,458,1.2],['愚园路',214,618,1.2],['武康路',96,584,52.4],['衡山路',318,452,90]];
const FOG=[[-10,625],[47,565],[110,505],[110,425],[110,345],[170,300],[225,220],[110,220],[25,220]];
async function buildBase(c){ for(const k of [...c.children]) k.remove(); c.fills=[PAINT('map-land')]; c.clipsContent=true;
  const base=figma.createFrame(); c.appendChild(base); base.name='base · Shanghai (徐汇)'; base.resize(393,852); base.fills=[]; base.constraints={horizontal:'STRETCH',vertical:'STRETCH'};
  const water=SVG(base,`<svg width="393" height="852" viewBox="0 0 393 852" xmlns="http://www.w3.org/2000/svg"><path d="M350 -20 C372 200 342 420 384 600 S372 800 404 880" fill="none" stroke="#335577" stroke-width="54" stroke-linecap="round"/></svg>`,'water · 黄浦江'); water.x=0; water.y=0; for(const v of water.findAll(n=>n.type==='VECTOR')) v.strokes=[PAINT('map-water')];
  RECT(base,80,120,'map-park',{r:16,name:'park · 襄阳公园',x:205,y:162}); RECT(base,40,110,'map-park',{r:12,name:'park · 徐家汇公园',x:16,y:505});
  const minor=SVG(base,svgPaths(ROADS_MINOR,6),'roads · minor'); minor.x=0; minor.y=0; for(const v of minor.findAll(n=>n.type==='VECTOR')) v.strokes=[PAINT('map-road')];
  const main=SVG(base,svgPaths(ROADS_MAIN,12),'roads · main'); main.x=0; main.y=0; for(const v of main.findAll(n=>n.type==='VECTOR')) v.strokes=[PAINT('map-road')];
  for(const [s,x,y,rot] of LABELS){ const t=await TX(base,s,'t-cap2','ink-3',{name:'street · '+s}); t.x=x; t.y=y; t.rotation=rot; }
  for(const [nm,ic,x,y] of [['武康大楼','star',150,516],['衡山坊','photo',236,392]]){ const g=AL('HORIZONTAL','landmark · '+nm,{gap:4,pad:[3,8,3,4],r:999,fill:'surface'}); base.appendChild(g); await IC(g,ic,14,'ink-2'); await TX(g,nm,'t-cap2','ink-2',{name:'landmark label'}); g.x=x; g.y=y; }
  return base; }
function fogLayer(c){ const r=figma.createRectangle(); r.resize(433,892); r.x=-20; r.y=-20; const holes=FOG.map(([x,y])=>{ const e=figma.createEllipse(); e.resize(150,150); e.x=x; e.y=y; return e; }); c.appendChild(r); holes.forEach(h=>c.appendChild(h)); const sub=figma.subtract([r,...holes],c); sub.name='fog · unexplored (bg 62%)'; sub.fills=[PAINT('bg')]; sub.opacity=0.62; sub.effects=[{type:'LAYER_BLUR',blurType:'NORMAL',radius:24,visible:true}]; R.created.push(sub.id); return sub; }
const CELLS=[[0,0,1,'mine'],[1,0,1,'other'],[0,1,2,'mine'],[1,1,2,'none'],[0,2,3,'other'],[1,2,3,'mine'],[2,1,4,'none']];
const XS=[72,186,300,393], YS=[150,312,478,640];
function territoryLayer(c){ const g=figma.createFrame(); c.appendChild(g); g.name='territory · cells'; g.resize(393,852); g.fills=[]; g.constraints={horizontal:'STRETCH',vertical:'STRETCH'};
  for(const [i,j,d,kind] of CELLS){ const r=RECT(g,XS[i+1]-XS[i]-14,YS[j+1]-YS[j]-14,kind==='mine'?`district/${d}-soft`:null,{r:8,name:`cell · district ${d} · ${kind}`,x:XS[i]+7,y:YS[j]+7}); r.strokes=[PAINT(`district/${d}`)]; r.strokeWeight=1.5; r.strokeAlign='INSIDE'; if(kind==='none') r.dashPattern=[4,3]; } return g; }
const fogC=await byId(MAP); const oldName=fogC.name; await buildBase(fogC); fogLayer(fogC); fogC.name='Layer=Fog';
const plain=figma.createComponent(); lsec.appendChild(plain); plain.resize(393,852); await buildBase(plain); plain.name='Layer=Plain'; R.created.push(plain.id);
const terr=figma.createComponent(); lsec.appendChild(terr); terr.resize(393,852); await buildBase(terr); territoryLayer(terr); terr.name='Layer=Territory'; R.created.push(terr.id);
const mapSet=figma.combineAsVariants([plain,fogC,terr],lsec); mapSet.name='Map/Base'; mapSet.fills=[PAINT('bg')]; mapSet.cornerRadius=16; gridSet(mapSet,3,32,32); R.created.push(mapSet.id);
mapSet.description='skill-r1 SR1-24. One base map that looks like Shanghai at night: map-land ground, map-road at two widths, map-water (黄浦江), map-park, street labels t-cap2 11 Medium ink-3 (复兴西路, 安福路, 湖南路, 愚园路, 武康路, 衡山路), two landmarks. Layer=Fog: bg at 62% with a 24 pt soft edge over the unexplored part, so explored shows the real map. Layer=Territory: cells outlined 1.5 pt in district/n, my cells filled district/n-soft. Used by roam, fog and territory screens alike.';
// ---------- Pins (SR1-26) ----------
const pinSet=await byId(PIN);
const RENAME={'State=我的':['Mine','None','1'],'State=他人':['Other','None','1'],'State=保护中':['Other','Shield','1'],'State=可占领':['None','None','1'],'State=未知':['Unlit','None','1'],'State=风化':['Mine','Hourglass','1']};
const WANT=[['Mine','None','0'],['Mine','None','1'],['Mine','None','2'],['Mine','Shield','1'],['Mine','Hourglass','1'],['Other','None','0'],['Other','None','1'],['Other','None','2'],['Other','Shield','1'],['Other','Hourglass','1'],['None','None','1'],['Unlit','None','1'],['Cluster','None','1']];
const vname=([o,b,l])=>`Owner=${o}, Badge=${b}, Level=${l}`;
for(const v of [...pinSet.children]){ const m=RENAME[v.name]; if(m) v.name=vname(m); }
for(const w of WANT){ if(!pinSet.children.find(v=>v.name===vname(w))){ const c=pinSet.children[0].clone(); pinSet.appendChild(c); c.name=vname(w); R.created.push(c.id); } }
async function drawPin(v){ const [o,b,l]=['Owner','Badge','Level'].map(k=>(v.name.match(new RegExp(k+'=([^,]+)'))||[])[1]); const S={'0':36,'1':44,'2':52}[l]; const H=Math.max(44,S);
  for(const k of [...v.children]) k.remove(); v.layoutMode='NONE'; v.resize(H,H); v.fills=[]; v.strokes=[]; v.effects=[]; v.clipsContent=false;
  const halo=ELL(v,S+16,'district/1-soft',{name:'halo (selected)',x:(H-S-16)/2,y:(H-S-16)/2});
  const cx=(H-S)/2;
  if(o==='Mine'){ const e=ELL(v,S,'me',{name:'pin · mine (filled)',x:cx,y:cx}); e.strokes=[PAINT('on-solid')]; e.strokeWeight=2; const g=await IC(v,'flag',Math.round(S*0.5),'on-solid','glyph · flag'); g.x=(H-g.width)/2; g.y=(H-g.height)/2; }
  else if(o==='Other'){ const e=ELL(v,S,'surface',{name:'pin · other (outline)',x:cx,y:cx}); e.strokes=[PAINT('ink')]; e.strokeWeight=2.5; const g=await IC(v,'flag',Math.round(S*0.5),'ink','glyph · flag'); g.x=(H-g.width)/2; g.y=(H-g.height)/2; }
  else if(o==='None'){ const e=ELL(v,S,'surface',{name:'pin · none (dashed)',x:cx,y:cx}); e.strokes=[PAINT('ink-2')]; e.strokeWeight=2; e.dashPattern=[4,3]; const g=await IC(v,'plus',Math.round(S*0.5),'ink-2','glyph · plus'); g.x=(H-g.width)/2; g.y=(H-g.height)/2; }
  else if(o==='Unlit'){ const d=Math.round(S*0.5); const e=ELL(v,d,'surface',{name:'pin · unlit (hollow dot)',x:(H-d)/2,y:(H-d)/2}); e.strokes=[PAINT('ink-3')]; e.strokeWeight=2; const t=await TX(v,'?','role/pin-label','ink-3',{name:'glyph · ?'}); t.x=(H-t.width)/2; t.y=(H-t.height)/2; }
  else { const e=ELL(v,S,'surface-3',{name:'cluster',x:cx,y:cx}); e.strokes=[PAINT('ink-2')]; e.strokeWeight=1.5; const t=await TX(v,'5','t-head','ink',{name:'count'}); t.x=(H-t.width)/2; t.y=(H-t.height)/2; }
  if(b!=='None'){ const bd=AL('HORIZONTAL','badge · '+b,{w:18,h:18,r:999,fill:'surface',justify:'CENTER'}); v.appendChild(bd); bd.strokes=[PAINT('bg')]; bd.strokeWeight=1.5; await IC(bd,b==='Shield'?'lock':'hourglass',12,b==='Shield'?'ink':'warn'); bd.x=cx+S-14; bd.y=cx-4; }
  const lab=AL('HORIZONTAL','name label (selected)',{pad:[2,8],r:999,fill:'surface'}); v.appendChild(lab); await TX(lab,'武康大楼','role/pin-label','ink',{name:'name'}); lab.x=(H-lab.width)/2; lab.y=H+4; }
for(const v of pinSet.children) await drawPin(v);
const selKey=pinSet.addComponentProperty('Selected','BOOLEAN',false); const nameKey=pinSet.addComponentProperty('Name','TEXT','武康大楼');
for(const v of pinSet.children){ for(const n of v.findAll(x=>/\(selected\)/.test(x.name))) n.componentPropertyReferences={visible:selKey}; const t=v.findOne(x=>x.type==='TEXT'&&x.name==='name'); if(t) t.componentPropertyReferences={characters:nameKey}; }
pinSet.name='Map/Pin'; gridSet(pinSet,6,24,24);
pinSet.description='skill-r1 SR1-26. Ownership by shape (Mine filled + flag, Other outline + flag, None dashed + plus, Unlit hollow dot + ?), condition by badge (Shield = protected, Hourglass = weathering), level by size (36 / 44 / 52), name and halo on Selected. Cluster shows a count. Every variant sits in a ≥ 44 hit frame. One colour for ? (ink-3). Colour is never the only signal.';
// ---------- Map/Legend ----------
const lg=figma.createComponent(); lsec.appendChild(lg); lg.name='Map/Legend'; lg.layoutMode='HORIZONTAL'; lg.primaryAxisSizingMode='AUTO'; lg.counterAxisSizingMode='AUTO'; lg.itemSpacing=12; lg.paddingLeft=lg.paddingRight=12; lg.paddingTop=lg.paddingBottom=8; lg.cornerRadius=999; lg.fills=[PAINT('glass')]; lg.counterAxisAlignItems='CENTER'; R.created.push(lg.id);
try{ lg.effects=[{type:'GLASS',visible:true,lightIntensity:0.5,lightAngle:-45,refraction:0.35,depth:10,dispersion:0.1,radius:6}]; }catch(e){}
for(const [lab,o] of [['我的','Mine'],['别人的','Other'],['可圈','None'],['未点亮','Unlit']]){ const it=AL('HORIZONTAL','item · '+lab,{gap:4}); lg.appendChild(it); const p=variant(pinSet,{Owner:o,Badge:'None',Level:o==='Mine'||o==='Other'?'0':'1'}).createInstance(); it.appendChild(p); p.rescale(0.5); await TX(it,lab,'t-foot','ink',{name:'label'}); }
lg.description='skill-r1 SR1-24 / SR1-26. One legend for every map (territory and roam). Marks are the Map/Pin shapes, so 别人的 always means the outline pin.';
// place map set and legend inside the local section
const others=lsec.children.filter(c=>c!==mapSet&&c!==lg&&c!==pinSet); mapSet.x=40; mapSet.y=Math.max(...others.map(c=>c.y+c.height),0)+80; pinSet.x=mapSet.x+mapSet.width+80; pinSet.y=mapSet.y; lg.x=pinSet.x; lg.y=pinSet.y+pinSet.height+60;
lsec.resizeWithoutConstraints(Math.max(lsec.width,lg.x+Math.max(lg.width,pinSet.width)+80,mapSet.x+mapSet.width+80),Math.max(lsec.height,mapSet.y+mapSet.height+80));
// ---------- use: territory frames get Layer=Territory; legends replaced ----------
let terrSet=0, legends=0; const frames=[];
for(const s of figma.currentPage.children.filter(s=>s.type==='SECTION'&&s!==lsec)) for(const f of s.children) if(f.type==='FRAME') frames.push(f);
for(const f of frames){ const isT=/领地图层|地产卡/.test(f.name);
  for(const i of f.findAllWithCriteria({types:['INSTANCE']}).filter(x=>!x.id.includes(';'))){ let mc=null; try{ mc=await i.getMainComponentAsync(); }catch(e){ continue; } if(!mc||mc.parent!==mapSet) continue; if(isT&&mc!==terr){ i.swapComponent(terr); terrSet++; } }
  if(f.id==='204:23260'){ const old=f.findOne(n=>/legend|图例/i.test(n.name)&&n.type!=='TEXT'); const L=lg.createInstance(); f.appendChild(L); if(old){ L.x=old.x; L.y=old.y; old.remove(); } else { L.x=16; L.y=f.height-200; } legends++; } }
R.info={oldMapName:oldName,mapSet:mapSet.id,plain:plain.id,fog:fogC.id,terr:terr.id,pinSet:pinSet.id,pinVariants:pinSet.children.length,legend:lg.id,terrSwapped:terrSet,legends};
await mapSet.screenshot({scale:0.3}); await pinSet.screenshot({scale:1});
const n07=await byId('204:23260'); await n07.screenshot({scale:0.5});
R.created=R.created.length; return R;
