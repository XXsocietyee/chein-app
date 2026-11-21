// B4c · R3 club · SR1-09 概览 order, SR1-10 workbench bar + project thumbs, SR1-08 Club/Header default cover property
await goPage('91:33');
const ERR={}; const pbtn=await byId(PBTN), stateSet=await byId('287:506'), coverSet=await byId('381:993'), ccSet=await byId('381:1508');
const cov=(r,p)=>variant(coverSet,{Ratio:r,Place:p})||variant(coverSet,{Ratio:r,Place:'Default'});
const INFO={};
// ---- SR1-08 Club/Header: Default cover boolean + exposed Club/Default Cover ----
{ const ch=await byId('291:66013'); const key=ch.addComponentProperty('Default cover','BOOLEAN',false); let n=0; for(const v of ch.children){ const c=v.findOne(x=>x.name==='cover'&&x.type==='FRAME'); if(!c) continue; const i=variant(ccSet,{Type:'旅行组织'}).createInstance(); c.appendChild(i); if(c.layoutMode&&c.layoutMode!=='NONE') i.layoutPositioning='ABSOLUTE'; i.x=0; i.y=0; i.resize(c.width,c.height); i.constraints={horizontal:'STRETCH',vertical:'STRETCH'}; i.name='default cover (by club type)'; i.isExposedInstance=true; i.componentPropertyReferences={visible:key}; n++; } ch.description=(ch.description||'')+' · skill-r1 SR1-08: turn on Default cover to show Club/Default Cover (pick the club type) when the club has no photo; never the shared 一起玩 illustration.'; INFO.header=n; }
// ---- SR1-09 概览: next activity first, members, 贡献榜 empty state, about ----
async function overview(fid){ const f=await byId(fid); if(!f) return 'missing'; const div=f.findOne(n=>n.name==='tab-divider'); const y0=div?div.y+div.height+16:472;
  const card=AL('HORIZONTAL','next activity (skill-r1 SR1-09)',{gap:12,pad:[12,16],r:16,fill:'surface',w:361}); f.appendChild(card); card.x=16; card.y=y0;
  const c=cov('1:1','Place 2').createInstance(); card.appendChild(c); c.resize(56,56);
  const col=add(card,AL('VERTICAL','text',{gap:2,align:'MIN'}),'FILL'); await TX(col,'下一场活动','t-foot','ink-2'); await TX(col,'外滩夜跑 · 城市定向','t-head','ink',{name:'title'}); await TX(col,'11月22日 周六 14:00 · 12 / 20 人','t-foot','ink-2',{name:'meta'});
  const b=variant(pbtn,{Kind:'Secondary',Size:'44',State:'Default'}).createInstance(); card.appendChild(b); setProps(b,{Label:'查看'});
  const dy=card.height+16; for(const s of f.children) if(s!==card&&s.y>=y0-2&&!/Nav Bar|Status Bar/.test(s.name)) s.y+=dy;
  // members: 4 different avatars
  const av=f.findOne(n=>n.name==='member-avatar'); let avs=0; if(av){ const hashes=['dc56ad948a37ae39137e53d787322a01f70d1e9d','bbfa1a523271763eff97628b5af84a8b733e0dee','6b77a30f673d56caef0d95ccb1773b0200f94b1b','21f345c08aa328f8b8161ce36ef1b576c99ac33f']; const stack=AL('HORIZONTAL','Avatar Stack · 4',{gap:-12}); f.appendChild(stack); stack.x=av.x; stack.y=av.y; for(const h of hashes){ const e=figma.createEllipse(); stack.appendChild(e); e.resize(44,44); e.fills=[{type:'IMAGE',imageHash:h,scaleMode:'FILL'}]; e.strokes=[PAINT('bg')]; e.strokeWeight=2; avs++; } av.visible=false; for(const t of f.findAll(n=>n.type==='TEXT'&&/^\+\d$/.test(n.characters.trim()))) t.visible=false; }
  // 贡献榜 empty sentence → Player/State Empty
  const empt=f.findAll(n=>n.type==='TEXT'&&/还没有|暂无/.test(n.characters)&&n.y>(av?av.y:600)).sort((a,b)=>a.y-b.y)[0]; let st=false;
  if(empt&&stateSet){ const v=variant(stateSet,{Kind:'Empty'}); const i=v.createInstance(); f.appendChild(i); i.resize(361,i.height); i.x=16; i.y=empt.y-8; const ts=texts(i).sort((a,b)=>b.fontSize-a.fontSize); if(ts[0]) await setT(ts[0],'还没有贡献记录'); if(ts[1]) await setT(ts[1],'办一次活动，成员到场就会上榜。'); const bt=i.findOne(n=>n.type==='INSTANCE'&&/Button/.test(n.name)); if(bt) try{ setProps(bt,{Label:'发起一次活动'}); }catch(e){} empt.visible=false; const d2=i.height-empt.height; for(const s of f.children) if(s!==i&&s.y>empt.y+4&&!/Nav Bar|Status Bar/.test(s.name)) s.y+=Math.max(0,d2); st=true; }
  f.resize(f.width,Math.max(f.height,Math.max(...f.children.filter(c=>c.visible).map(c=>c.y+c.height))+40));
  SR(f,'SR1-09','概览 answers "what is this club doing next": next activity card first, then members (4 different avatars), 贡献榜 as Player/State Empty with 发起一次活动 (managers only; members see no action), then about.'); return {card:card.id,avs,state:st}; }
INFO.ov1=await overview('204:24899'); INFO.ov2=await overview('204:24850');
// ---- SR1-10 workbench 170:1744 ----
{ const f=await byId('170:1744'); const top=f.findAll(n=>!n.id.includes(';')&&n.y<100&&n.x>260&&n.width<=30&&/qr|gear|码|设置/i.test(n.name)); let hid=0; for(const n of top){ n.visible=false; hid++; }
  const more=AL('HORIZONTAL','more · hit 44 → Club/Row Menu (团码, 设置)',{w:44,h:44,justify:'CENTER'}); f.appendChild(more); more.x=393-16-44; more.y=50; await IC(more,'more',22,'ink');
  let th=0; for(const e of f.findAll(n=>n.type==='ELLIPSE'&&!n.id.includes(';')&&n.width>=32&&n.width<=48&&n.y>500)){ const par=e.parent; const ch=par.children.find(c=>c.type==='TEXT'&&c.characters.trim().length===1&&Math.abs((c.x+c.width/2)-(e.x+e.width/2))<12); if(!ch) continue; const r=figma.createRectangle(); par.insertChild(par.children.indexOf(e),r); if(par.layoutMode&&par.layoutMode!=='NONE'){ r.resize(44,44); } else { r.x=e.x+(e.width-44)/2; r.y=e.y+(e.height-44)/2; r.resize(44,44); } r.cornerRadius=8; r.fills=[{...cov('1:1','Place '+(1+th%5)).fills.find(p=>p.type==='IMAGE')}]; r.name='project cover 44'; e.visible=false; ch.visible=false; th++; }
  INFO.workbench={hid,th}; SR(f,'SR1-10','One 44 pt action (扫码) and a ⋯ menu (团码, 设置) instead of three bare icons; project rows lead with a 44 pt cover (r8) instead of an initial.'); }
R.info=INFO;
await (await byId('204:24899')).screenshot({scale:0.4}); await (await byId('170:1744')).screenshot({scale:0.3});
R.created=R.created.length; R.touched=R.touched.length; R.ann=R.ann.length; return R;
