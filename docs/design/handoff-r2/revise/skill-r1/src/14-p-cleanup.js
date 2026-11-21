// B4a · P · re-clone N87/N90/N91/N36 copies again, SR1-04 home covers (in instances), SR1-07 发布 root, SR1-06 战报, SR1-33 share card, archive P in-betweens
await goPage(P);
const pg=figma.currentPage; const coverSet=await byId('381:993'); const cov=(r,p)=>variant(coverSet,{Ratio:r,Place:p})||variant(coverSet,{Ratio:r,Place:'Default'});
const ERR={}; async function SETR(n,rs,tag){ try{ await n.setReactionsAsync(rs); return true; }catch(e){ const k=tag+': '+String(e).slice(0,60); ERR[k]=(ERR[k]||0)+1; return false; } }
// ---- re-clone changed N1 frames ----
const n1=await byId(N1); await n1.loadAsync(); const N1F={}; for(const s of n1.children.filter(s=>s.type==='SECTION')) for(const f of s.children) if(f.type==='FRAME'){ const m=f.name.match(/^(N\d{2})\s/); if(m&&!N1F[m[1]]) N1F[m[1]]=f; }
const CODES=['N87','N90','N91','N36']; const RE=/\((N\d{2})\)|← (N\d{2})(?![·\d])/; const targets=[];
for(const s of pg.children.filter(s=>s.type==='SECTION')) for(const f of s.children) if(f.type==='FRAME'){ const m=f.name.match(RE); const code=m&&(m[1]||m[2]); if(code&&CODES.includes(code)&&N1F[code]) targets.push({c:f,src:N1F[code]}); }
const isBtn=async n=>{ if(n.type!=='INSTANCE') return false; const mc=await n.getMainComponentAsync(); return !!(mc&&mc.parent&&mc.parent.id===PBTN); };
const map={}; for(const {c,src} of targets){ const par=c.parent; const nc=src.clone(); par.appendChild(nc); nc.x=c.x; nc.y=c.y; nc.name=c.name;
  for(const n of nc.findAll(x=>'reactions' in x&&x.reactions&&x.reactions.length)) if(!/^⌖ flick/.test(n.name)) await SETR(n,[],'strip');
  if(c.reactions&&c.reactions.length) await SETR(nc,c.reactions.map(r=>({trigger:r.trigger,actions:actsOf(r)})),'frame');
  for(const b of c.findAll(x=>x.type==='INSTANCE'&&x.reactions&&x.reactions.length)){ if(!(await isBtn(b))) continue; const L=texts(b).map(t=>t.characters).join(''); for(const nb of nc.findAll(x=>x.type==='INSTANCE')){ if(await isBtn(nb)&&texts(nb).map(t=>t.characters).join('')===L){ await SETR(nb,b.reactions.map(r=>({trigger:r.trigger,actions:actsOf(r)})),'btn'); break; } } }
  for(const h of c.children.filter(k=>/^⌖/.test(k.name))) nc.appendChild(h);
  map[c.id]=nc.id; }
const rel=await relink(map); for(const {c} of targets) c.remove();
// flick on the N36 copy → N37 copy
for(const nc of Object.values(map)){ const f=await byId(nc); const fl=f&&f.findOne(n=>/^⌖ flick/.test(n.name)); if(fl) await SETR(fl,[{trigger:{type:'ON_DRAG'},actions:[{type:'NODE',destinationId:P_N37,navigation:'NAVIGATE',transition:{type:'SMART_ANIMATE',easing:SP('moment'),duration:DUR.moment},resetScrollPosition:false}]}],'flick'); }
R.info.reclone={map,rel};
// ---- SR1-04 home 附近活动 covers inside Theme Card instances ----
{ const home=await byId('210:8239'); let k=0; const nh=home.findAll(x=>x.type==='TEXT'&&/附近活动/.test(x.characters))[0]; const y0=nh?nh.absoluteBoundingBox.y:-1e9;
  for(const n of home.findAll(x=>'fills' in x&&Array.isArray(x.fills)&&x.fills.some(f=>f.type==='IMAGE'))){ if(n.width<60||n.absoluteBoundingBox.y<y0) continue; const img=cov(n.width/n.height>1.3?'16:9':'1:1','Place '+(2+(k%4))).fills.find(f=>f.type==='IMAGE'); try{ n.fills=n.fills.map(f=>f.type==='IMAGE'?{...f,imageHash:img.imageHash}:f); k++; }catch(e){ ERR['cover']=(ERR['cover']||0)+1; } }
  R.info.homeCovers=k; }
// ---- SR1-07 / SR1-04 发布 root: last draft first, then two entries, then templates ----
{ const f=await byId('210:8374'); const old=f.children.filter(c=>c.type==='FRAME'&&Math.abs(c.y-178)<8)[0];
  if(old){ const blk=AL('VERTICAL','发布 · 继续 + 入口 (skill-r1 SR1-07)',{gap:12,w:361,align:'MIN'}); f.appendChild(blk); blk.x=16; blk.y=old.y;
    const d=AL('HORIZONTAL','draft card · 继续上次的草稿',{gap:12,pad:[12,16],r:16,fill:'surface'}); blk.appendChild(d); d.layoutSizingHorizontal='FILL'; const c=cov('1:1','Place 3').createInstance(); d.appendChild(c); c.resize(56,56);
    const col=add(d,AL('VERTICAL','text',{gap:2,align:'MIN'}),'FILL'); await TX(col,'继续上次的草稿','t-foot','ink-2'); await TX(col,'苏州河夜行 · 七座桥','t-head','ink',{name:'title'}); await TX(col,'3 天前 · 还差 2 项','t-foot','ink-2',{name:'meta'}); await IC(d,'chev',16,'ink-3');
    const row=AL('HORIZONTAL','entries',{gap:16}); blk.appendChild(row); row.layoutSizingHorizontal='FILL';
    for(const [t,s,ic] of [['新主题','路线、章节、地点','route'],['新玩法','问答、拍照、竞速','grid']]){ const e=AL('VERTICAL','entry · '+t,{gap:6,pad:[16,16],r:16,fill:'surface',align:'MIN',h:120}); row.appendChild(e); e.layoutSizingHorizontal='FILL'; await IC(e,ic,24,'ink'); add(e,AL('VERTICAL','spacer'),'FILL','FILL'); await TX(e,t,'t-head','ink'); await TX(e,s,'t-foot','ink-2'); }
    const tpl=await TX(blk,'从模板开始','t-3','ink',{name:'templates header'});
    const dy=blk.height-old.height; for(const s of f.children) if(s!==blk&&s.y>old.y+4&&!/Tab Bar|Status Bar|Root Header|Scroll Edge/.test(s.name)) s.y+=dy;
    const hs=f.children.filter(k=>/^⌖ → tenew/.test(k.name)); for(const h of hs){ await SETR(row.children[0],h.reactions.map(r=>({trigger:r.trigger,actions:actsOf(r)})),'entry'); }
    old.remove(); const fx=f.children.filter(c=>/Status Bar|Root Header|Tab Bar|Scroll Edge/.test(c.name)); for(const c of fx) f.appendChild(c); f.numberOfFixedChildren=fx.length;
    SR(f,'SR1-07','The tab opens on what the creator was doing: 继续上次的草稿, then two entry cards (新主题 / 新玩法), then templates. The empty hero box is gone (SR1-04).'); OWN(f,'Q5','Tab name stays 发布; only what the root shows first changed.'); } else R.warn.push('发布: no block at y 178'); }
// ---- SR1-06 / SR1-13 战报 ----
{ const f=await byId('204:15044'); if(f){ let hid=0; for(const i of f.findAll(n=>n.type==='INSTANCE'&&n.name.includes('Stat Tile'))){ const v=texts(i).map(t=>t.characters).join(' '); if(/0\/6|—|本局不计分/.test(v)){ i.visible=false; hid++; } }
  const title=f.findAll(n=>n.type==='TEXT'&&!n.id.includes(';')).sort((a,b)=>b.fontSize-a.fontSize)[0]; if(title&&title.parent.layoutMode&&title.parent.layoutMode!=='NONE'){ const s=await TX(null,'本局不计分','t-foot','ink-2',{name:'subtitle'}); title.parent.insertChild(title.parent.children.indexOf(title)+1,s); }
  let ch=0; for(const t of f.findAll(n=>n.type==='TEXT'&&!n.id.includes(';')&&/\s?→\s*$/.test(n.characters))){ await setT(t,t.characters.replace(/\s?→\s*$/,'')); const par=t.parent; if(par.layoutMode==='HORIZONTAL'){ const i=await IC(null,'chev',16,'ink-3','icon/chev'); par.insertChild(par.children.indexOf(t)+1,i); } ch++; }
  R.info.zhanbao={hid,ch}; SR(f,'SR1-06','Only tiles with a value; 本局不计分 said once under the title; rows end in a chevron (SR1-13).'); } }
// ---- SR1-33 share card 210:10082: the earned badge on the navy field ----
{ const f=await byId('210:10082'), src=await byId('210:10045'), badge=await byId(BADGE); if(f&&badge){ const yellow=n=>{ const p=('fills' in n)&&Array.isArray(n.fills)?n.fills.find(x=>x.type==='SOLID'&&x.visible!==false):null; return p&&p.color.r>0.6&&p.color.g>0.45&&p.color.b<0.4; };
  const tile=f.findAll(n=>!n.id.includes(';')&&(n.type==='FRAME'||n.type==='RECTANGLE')&&n.width>=120&&yellow(n)).sort((a,b)=>b.width*b.height-a.width*a.height)[0];
  if(tile){ const navy=src&&src.findAll(n=>'fills' in n&&Array.isArray(n.fills)&&n.width>300&&n.fills.some(p=>p.type==='SOLID'&&p.color.b>p.color.r+0.1)).map(n=>n.fills)[0]; tile.fills=navy||[RAW('1B2A4A')]; const art=variant(badge,{Badge:'初次漫游',Lit:'On'})||badge.children[0]; const i=art.createInstance(); const host=tile.type==='FRAME'?tile:tile.parent; host.appendChild(i); i.rescale(Math.min(tile.width,tile.height)*0.6/96); if(host.layoutMode&&host.layoutMode!=='NONE') i.layoutPositioning='ABSOLUTE'; i.x=(tile.type==='FRAME'?0:tile.x)+(tile.width-i.width)/2; i.y=(tile.type==='FRAME'?0:tile.y)+(tile.height-i.height)/2; R.info.share='tile '+tile.name; SR(f,'SR1-33','The share card shows the badge the player earned (Badge/Art) on the navy field of the celebration.'); OWN(f,'Q8','Badge/Art language for all moments.'); } else R.warn.push('share: no mustard tile'); } }
// ---- archive P in-betweens ----
{ let arch=figma.root.children.find(p=>p.name==='Archive · 已退役'); await arch.loadAsync(); let asec=arch.children.find(s=>s.type==='SECTION'&&s.name==='P · skill-r1'); if(!asec){ asec=figma.createSection(); arch.appendChild(asec); asec.name='P · skill-r1'; asec.x=0; asec.y=Math.max(0,...arch.children.filter(c=>c!==asec).map(c=>c.y+c.height))+200; asec.resizeWithoutConstraints(1800,1100); }
  const RET=['298:23194','298:23226','298:23258']; const m={}; for(const id of RET) m[id]=null; const u=await relink(m); let ax=80; for(const id of RET){ const n=await byId(id); if(!n) continue; const nm=n.name; asec.appendChild(n); n.x=ax; n.y=150; const l=await TX(asec,`${nm}\n来自 P · ${id}\nskill-r1 SR1-46: superseded by Moments · 分镜 on N1`,'t-foot','ink-2',{name:'label:'+id}); l.fills=[RAW('6B6B6B')]; l.x=ax; l.y=40; ax+=n.width+80; R.removed.push(id); } asec.resizeWithoutConstraints(Math.max(asec.width,ax),1100); R.info.archUnlinked=u; }
R.info.ERR=ERR;
await (await byId('210:8374')).screenshot({scale:0.4}); await (await byId('210:10082')).screenshot({scale:0.4}); await (await byId('204:15044')).screenshot({scale:0.4});
R.created=R.created.length; R.touched=R.touched.length; R.ann=R.ann.length; return R;
