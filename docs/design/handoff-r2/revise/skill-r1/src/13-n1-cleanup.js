// B2e · N1 · N1 brief (captions ≥ 12, body ≥ 15, MP census), SR1-02 play HUD, SR1-04 chat tiles, archive superseded in-betweens
await goPage(N1);
const pg=figma.currentPage; const LSEC='204:7912', LA='208:2662', MOM='399:4429'; const coverSet=await byId('381:993');
const cov=(r,p)=>variant(coverSet,{Ratio:r,Place:p})||variant(coverSet,{Ratio:r,Place:'Default'});
const SID={}; for(const s of Object.values(TS)) SID[s.id]=s.name;
const frames=[]; for(const s of pg.children.filter(s=>s.type==='SECTION'&&s.id!==LSEC&&s.id!==LA)) for(const f of s.children) if(f.type==='FRAME') frames.push(f);
// ---- captions ≥ 12 · body ≥ 15 ----
let up=0; for(const f of frames) for(const t of f.findAllWithCriteria({types:['TEXT']})){ if(t.id.includes(';')||typeof t.fontSize!=='number') continue; const st=SID[t.textStyleId]||'';
  if(st==='t-cap2'||(!st&&t.fontSize<12)){ await loadFontsOf(t); const fl=t.fills; await t.setTextStyleIdAsync(TS['t-cap'].id); t.fills=fl; up++; }
  else if(!st&&t.fontSize>=13.5&&t.fontSize<15){ await loadFontsOf(t); const fl=t.fills; await t.setTextStyleIdAsync(TS['t-sub'].id); t.fills=fl; up++; } }
// ---- SR1-02 play HUD (N87 209:14900 + its XXL proof keeps) ----
{ const f=await byId('209:14900'); if(f){ const c=cov('16:9','Place 1').createInstance(); f.insertChild(0,c); c.resize(393,300); c.x=0; c.y=0; c.name='chapter cover (skill-r1 SR1-02)';
  const fade=figma.createRectangle(); f.insertChild(1,fade); fade.name='media-shade · bottom 120'; fade.resize(393,180); fade.x=0; fade.y=120; const bg=rawOf(V['bg']); fade.fills=[{type:'GRADIENT_LINEAR',gradientTransform:[[0,1,0],[-1,0,1]],gradientStops:[{position:0,color:{...bg,a:0}},{position:1,color:{...bg,a:1}}]}];
  const dist=f.findAll(n=>n.type==='TEXT'&&!n.id.includes(';')&&/\d(\.\d)?\s?(km|公里|米|m)\b/.test(n.characters))[0]; if(dist){ await loadFontsOf(dist); await dist.setTextStyleIdAsync(TS['role/stat'].id); const par=dist.parent; const ar=await IC(null,'arrow-up',28,'ink','heading arrow · follows compass (15° steps)'); ar.rotation=-35; if(par.layoutMode==='HORIZONTAL') par.insertChild(par.children.indexOf(dist),ar); else { par.appendChild(ar); ar.x=dist.x-36; ar.y=dist.y; } }
  for(const t of f.findAll(n=>n.type==='TEXT'&&!n.id.includes(';')&&/^(第.章|Chapter|章节)/.test(n.characters))){ t.fills=[PAINT('on-media')]; }
  SR(f,'SR1-02','The chapter leads: 393×300 cover with a bottom fade behind the title; 下一站 distance in role/stat with a heading arrow (follows the compass in 15° steps).');
  ANN(f,'**Motion · skill-r1 SR1-02** · Heading arrow rotates with the compass, spring press (439 / 33.5), 15° steps; the distance rolls with numericText.','I',/^\*\*Motion · skill-r1 SR1-02/); } }
// ---- SR1-04 chat tiles 图片 1/2/3 (N90, N91) ----
let tiles=0; for(const fid of ['209:15118','209:15194']){ const f=await byId(fid); if(!f) continue; let k=0; for(const t of f.findAll(n=>n.type==='TEXT'&&!n.id.includes(';')&&/^图片\s?\d$/.test(n.characters))){ const tile=t.parent; if(!tile||!('fills' in tile)) continue; const img=cov('1:1','Place '+(1+(k++%5))).fills.find(p=>p.type==='IMAGE'); if(img){ tile.fills=[{...img}]; t.visible=false; try{ tile.cornerRadius=12; }catch(e){} tiles++; } } if(k) SR(f,'SR1-04','Chat tiles show place photos (Media/Cover 1:1), not 图片 1 / 2 / 3 placeholders.'); }
// ---- archive superseded in-betweens (replaced by Moments · 分镜) ----
let arch=figma.root.children.find(p=>p.name==='Archive · 已退役'); await arch.loadAsync();
let asec=arch.children.find(s=>s.type==='SECTION'&&s.name==='N1 · skill-r1'); if(!asec){ asec=figma.createSection(); arch.appendChild(asec); asec.name='N1 · skill-r1'; asec.x=0; asec.y=Math.max(0,...arch.children.filter(c=>c!==asec).map(c=>c.y+c.height))+200; asec.resizeWithoutConstraints(2200,1100); }
const RET=['298:2524','298:2564','298:2604','298:2634']; const map={}; for(const id of RET) map[id]=null; const unl=await relink(map);
let ax=80; for(const id of RET){ const n=await byId(id); if(!n) continue; const nm=n.name; asec.appendChild(n); n.x=ax; n.y=150; const l=await TX(asec,`${nm}\n来自 N1 · ${id}\nskill-r1 SR1-46: superseded by the five-beat strips in Moments · 分镜`,'t-foot','ink-2',{name:'label:'+id}); l.fills=[RAW('6B6B6B')]; l.x=ax; l.y=40; ax+=n.width+80; R.removed.push(id); }
asec.resizeWithoutConstraints(Math.max(asec.width,ax),1100);
// ---- census ----
const cen={mp:{},small:0,body14:0,unstyled:0,texts:0};
for(const f of frames){ for(const i of f.findAllWithCriteria({types:['INSTANCE']}).filter(x=>!x.id.includes(';'))){ let mc=null; try{ mc=await i.getMainComponentAsync(); }catch(e){} const top=mc&&(mc.parent&&mc.parent.type==='COMPONENT_SET'?mc.parent:mc); if(top&&/^MP\//.test(top.name)) cen.mp[top.name]=(cen.mp[top.name]||0)+1; }
  for(const t of f.findAllWithCriteria({types:['TEXT']})){ if(t.id.includes(';')||typeof t.fontSize!=='number') continue; cen.texts++; if(t.fontSize<12) cen.small++; if(t.fontSize<=14) cen.body14++; if(!t.textStyleId) cen.unstyled++; } }
R.info={up,tiles,unlinked:unl,cen};
await (await byId('209:14900')).screenshot({scale:0.4});
R.created=R.created.length; R.ann=R.ann.length; return R;
