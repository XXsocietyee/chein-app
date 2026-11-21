// B1c · Library 6:3 · SR1-36 (Player/Chip, Player/Nav Bar), SR1-03 (Chrome/Scroll Edge), SR1-11 (Quick Action Emphasis), SR1-38 (glass + Reduce Transparency), SR1-41 (status tag anatomy)
await goPage(LIB);
const sec=await byId(PKIT);
function glassFx(){ return {type:'GLASS',visible:true,lightIntensity:0.5,lightAngle:-45,refraction:0.35,depth:10,dispersion:0.1,radius:6}; }
function applyGlass(n){ try{ n.effects=[...n.effects.filter(e=>e.type!=='GLASS'&&e.type!=='BACKGROUND_BLUR'),glassFx()]; return 'glass'; }catch(e){ try{ n.effectStyleId=ES['material/glass-20'].id; return 'blur'; }catch(e2){ R.warn.push('glass '+n.name+': '+String(e).slice(0,80)); return 'none'; } } }
// ---- Player/Chip ----
const chips=[];
for(const kind of ['Choice','Filter']) for(const st of ['Default','Selected']){ const c=figma.createComponent(); c.name=`Kind=${kind}, State=${st}`; c.layoutMode='HORIZONTAL'; c.primaryAxisSizingMode='AUTO'; c.counterAxisSizingMode='FIXED'; c.resize(60,44); c.fills=[]; c.counterAxisAlignItems='CENTER'; R.created.push(c.id);
  const pill=AL('HORIZONTAL','pill',{pad:[0,14],gap:4,h:36,r:999,fill:st==='Selected'?'ink':'fill'}); c.appendChild(pill);
  await TX(pill,'全部','role/chip',st==='Selected'?'ink-inv':'ink',{name:'label'}); if(kind==='Filter') await IC(pill,'down',14,st==='Selected'?'ink-inv':'ink-2','icon/down');
  chips.push(c); }
const chipSet=await SETOF(chips,'Player/Chip',4,'skill-r1 SR1-36. Choice and filter chips for the player theme: 36 high pill inside a 44 hit area, role/chip 15 Medium. Selected = ink fill. Replaces MP/Chip on N1 and P.',sec);
tprop(chipSet,'Label','全部','label');
newRow(); await placeIn(sec,chipSet,'Player/Chip · Kind × State (skill-r1 SR1-36)');
// ---- Player/Nav Bar ----
async function circleBtn(par,icon,name){ const hit=AL('HORIZONTAL',name+' · hit 44',{w:44,h:44,justify:'CENTER'}); par.appendChild(hit); const c=AL('HORIZONTAL','glass circle',{w:36,h:36,r:999,fill:'glass',justify:'CENTER'}); hit.appendChild(c); applyGlass(c); await IC(c,icon,18,'ink'); return hit; }
const navs=[];
for(const lead of ['Back','Close']) for(const title of ['None','Inline']) for(const trail of ['None','One','Two']){ const c=figma.createComponent(); c.name=`Leading=${lead}, Title=${title}, Trailing=${trail}`; c.resize(393,52); c.fills=[]; R.created.push(c.id);
  const L=await circleBtn(c,lead==='Back'?'back':'x','leading'); L.x=8; L.y=4;
  if(title==='Inline'){ const t=await TX(c,'赛季榜','t-head','ink',{name:'title'}); t.textAlignHorizontal='CENTER'; t.resize(220,t.height); t.x=(393-220)/2; t.y=(52-t.height)/2; t.constraints={horizontal:'CENTER',vertical:'CENTER'}; }
  if(trail!=='None'){ const tr=AL('HORIZONTAL','trailing',{gap:0}); c.appendChild(tr); if(trail==='Two') await circleBtn(tr,'share','action 2'); await circleBtn(tr,'more','action 1'); tr.x=393-8-tr.width; tr.y=4; tr.constraints={horizontal:'MAX',vertical:'MIN'}; }
  navs.push(c); }
const navSet=await SETOF(navs,'Player/Nav Bar',3,'skill-r1 SR1-36. Pushed / presented nav for the player theme: 52 high, 44 hit circles on glass (Liquid Glass effect, Reduce Transparency → opaque), inline title t-head 17 Semibold centred. Back for push, Close for modal. Replaces MP/Nav Bar on N1 and P.',sec);
tprop(navSet,'Title','赛季榜','title');
await placeIn(sec,navSet,'Player/Nav Bar · Leading × Title × Trailing (skill-r1 SR1-36)');
// ---- Chrome/Scroll Edge ----
const se=figma.createComponent(); se.name='Chrome/Scroll Edge'; se.resize(393,120); R.created.push(se.id);
{ const bg=V['bg']; const raw=rawOf(bg); const stops=[{position:0,color:{...raw,a:0}},{position:0.45,color:{...raw,a:0.85}},{position:1,color:{...raw,a:1}}]; let p={type:'GRADIENT_LINEAR',gradientTransform:[[0,1,0],[-1,0,1]],gradientStops:stops};
  try{ p={...p,gradientStops:stops.map(s=>({...s,boundVariables:{color:{type:'VARIABLE_ALIAS',id:bg.id}}}))}; se.fills=[p]; R.info.edgeBound=true; }catch(e){ se.fills=[{type:'GRADIENT_LINEAR',gradientTransform:[[0,1,0],[-1,0,1]],gradientStops:stops}]; R.info.edgeBound=String(e).slice(0,80); } }
se.description='skill-r1 SR1-03. Bottom-pinned fade under the floating tab bar: transparent → bg over 120 pt (32 pt soft edge + bar zone). Place under the tab bar instance, constraints bottom + stretch. Pair with 96 pt bottom inset on the scroll content.';
await placeIn(sec,se,'Chrome/Scroll Edge (skill-r1 SR1-03)');
// ---- SR1-38 glass on chrome components + Reduce Transparency ----
const glassed=[];
async function rtSwitch(owner,targets){ const key=owner.addComponentProperty('Reduce Transparency','BOOLEAN',false); for(const n of targets){ if(!('children' in n)) continue; const r=figma.createRectangle(); n.insertChild(0,r); if(n.layoutMode&&n.layoutMode!=='NONE') r.layoutPositioning='ABSOLUTE'; r.x=0; r.y=0; r.resize(n.width,n.height); r.constraints={horizontal:'STRETCH',vertical:'STRETCH'}; r.name='opaque (Reduce Transparency)'; r.fills=[PAINT('surface-2')]; r.cornerRadius=typeof n.cornerRadius==='number'?n.cornerRadius:16; r.componentPropertyReferences={visible:key}; R.created.push(r.id); } }
for(const id of [TOPPILL,'285:20279']){ const o=await byId(id); if(!o) continue; const vs=o.type==='COMPONENT_SET'?o.children:[o]; const tg=[];
  for(const v of vs){ const cand=[v,...v.findAll(n=>n.type==='FRAME'&&n.fills&&n.fills.some&&n.fills.some(f=>f.boundVariables&&f.boundVariables.color&&VI[f.boundVariables.color.id]&&/glass|hud|surface/.test(VI[f.boundVariables.color.id].name)))]; const t=cand.find(n=>n!==v)||v; glassed.push(t.name+':'+applyGlass(t)); tg.push(t); }
  await rtSwitch(o,tg); }
R.info.glassed=glassed;
// ---- SR1-11 Merchant/Quick Action · Emphasis=Primary ----
const qa=await byId('316:6040'); if(qa){ let set=qa; if(qa.type==='COMPONENT'&&qa.parent.type!=='COMPONENT_SET'){ const base=qa; const prim=base.clone(); base.name='Emphasis=Default'; prim.name='Emphasis=Primary'; const par=base.parent; set=figma.combineAsVariants([base,prim],par); set.name='Merchant/Quick Action'; set.x=base.x; set.y=base.y; gridSet(set,2,16,16); R.created.push(set.id); } else if(qa.type==='COMPONENT_SET'){ const base=qa.children[0]; const prim=base.clone(); qa.appendChild(prim); for(const v of qa.children) if(!/Emphasis=/.test(v.name)) v.name=v.name+', Emphasis=Default'; prim.name=prim.name.replace('Emphasis=Default','Emphasis=Primary'); gridSet(qa,qa.children.length,16,16); }
  const prim=(set.type==='COMPONENT_SET'?set.children:[]).find(v=>/Emphasis=Primary/.test(v.name));
  if(prim){ const circ=prim.findAll(n=>(n.type==='ELLIPSE'||n.type==='FRAME'||n.type==='RECTANGLE')&&n.width>=40&&n.width<=72&&Math.abs(n.width-n.height)<2).sort((a,b)=>b.width-a.width)[0]; if(circ){ circ.fills=[PAINT('cta')]; circ.strokes=[]; } for(const t of prim.findAll(n=>n.type==='TEXT')){ const inCirc=circ&&(circ.findOne?circ.findOne(x=>x===t):null); if(inCirc||(circ&&t.parent===circ)||(t.parent&&t.parent.parent===circ)) t.fills=[PAINT('cta-ink')]; } R.info.qa={set:set.id,prim:prim.id,circle:circ?circ.name:null}; }
  set.description=(set.description||'')+' · skill-r1 SR1-11: Emphasis=Primary (cta fill, cta-ink glyph) for 扫码, the merchant\'s first job.'; }
// ---- SR1-41 status tag anatomy: 24 high, role/tag 12 Semibold, 12 pt glyph, pad 8, pill ----
const tagSets=[await byId(STAT_TAG)]; const msec=await byId(MKIT); const mt=msec&&msec.findOne(n=>n.type==='COMPONENT_SET'&&n.name==='Merchant/Status Tag'); if(mt) tagSets.push(mt); let tagsFixed=0;
for(const s of tagSets) for(const v of s.children){ if(!v.layoutMode||v.layoutMode==='NONE') continue; v.paddingLeft=v.paddingRight=8; v.paddingTop=v.paddingBottom=0; v.counterAxisSizingMode='FIXED'; v.resize(v.width,24); v.primaryAxisSizingMode='AUTO'; v.cornerRadius=999; v.counterAxisAlignItems='CENTER';
  for(const t of v.findAll(n=>n.type==='TEXT')){ if(t.parent.type==='INSTANCE'||t.id.includes(';')) continue; await t.setTextStyleIdAsync(TS['role/tag'].id); } for(const i of v.findAll(n=>n.type==='INSTANCE'&&/icon/i.test(n.name))){ i.resize(12,12); const g=i.findOne(n=>n.type==='TEXT'); if(g) g.fontSize=11; } tagsFixed++; }
R.info.tagsFixed=tagsFixed;
// read for later: Editor/Confirm Dialog anatomy
const cd=await byId('290:20572'); R.info.confirm=cd?[cd.type,cd.name,Math.round(cd.width)+'x'+Math.round(cd.height),...(cd.type==='COMPONENT_SET'?cd.children.map(c=>c.name):[]),...(cd.type==='COMPONENT_SET'?cd.children[0]:cd).findAll(()=>true).slice(0,30).map(n=>n.type[0]+' '+n.name+(n.type==='TEXT'?'«'+n.characters+'»':'')+' '+Math.round(n.width)+'x'+Math.round(n.height))]:null;
await chipSet.screenshot({scale:1}); await navSet.screenshot({scale:0.5});
R.info.ids={chipSet:chipSet.id,navSet:navSet.id,edge:se.id};
R.created=R.created.length; return R;
