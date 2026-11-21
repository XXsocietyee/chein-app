// Batch 4a · P (+ N1 / Library / R1 cross-page) · SR2-42 fix, re-clone, SR2-05, SR2-01 thumb, SR2-50, SR2-11, SR2-07, SR2-08, SR2-03, SR2-04, SR2-06
await goPage(P);
{ const all=await figma.listAvailableFontsAsync(); for(const f of all){ if(/^(Noto Sans (JP|SC)|PingFang SC|Inter)$/.test(f.fontName.family)){ try{ await figma.loadFontAsync(f.fontName); }catch(e){} } } }
const B=async(name,fn)=>{ try{ await fn(); R.info[name]=R.info[name]||'ok'; }catch(e){ R.warn.push(name+': '+String(e).slice(0,160)); } };
const ofMain=async(root,setName)=>{ const out=[]; for(const i of root.findAllWithCriteria({types:['INSTANCE']})){ const m=await i.getMainComponentAsync(); if(m&&((m.parent&&m.parent.type==='COMPONENT_SET'&&m.parent.name===setName)||m.name===setName)) out.push(i); } return out; };
const pg=figma.currentPage; let RECLONE={};
// ---- SR2-42 fix: Sheet variant bindings; N08–N12 deeds hug; sheets re-hug ----
await B('sheetBind',async()=>{ const d=await byId(DEED); const key=n=>Object.keys(d.componentPropertyDefinitions).find(k=>k.split('#')[0]===n); const M={name:'名称',district:'街区','deed no':'编号',rent:'租金','rent caption':'租金说明',holder:'持有'}; let n=0;
  for(const v of d.children.filter(v=>/Size=Sheet/.test(v.name))){ for(const t of v.findAll(x=>x.type==='TEXT')){ const k=M[t.name]||(t.name==='level'?'等级':null); if(k&&key(k)){ t.componentPropertyReferences={...(t.componentPropertyReferences||{}),characters:key(k)}; n++; } } }
  for(const id of ['390:3602','390:3637','390:3671','390:3704','390:3729']){ const i=await byId(id); if(!i) continue; try{ i.layoutSizingVertical='HUG'; }catch(e){ i.resize(i.width,176); } const sh=i.parent; if(sh&&sh.name==='sheet'){ sh.primaryAxisSizingMode='AUTO'; sh.y=sh.parent.height-sh.height; } }
  R.info.sheetBind=n+' · '+(await Promise.all(['390:3602','390:3637'].map(async id=>{ const i=await byId(id); return Math.round(i.height)+'/'+Math.round(i.parent.height); }))).join(','); });
// ---- re-clone changed N1 frames into P ----
await B('reclone',async()=>{ const CH=new Set(['N01','N02','N03','N07','N08','N09','N10','N11','N12','N22','N28','N34','N36','N37','N38','N39','N40','N41','N46','N47','N48','N49','N50','N51','N66']);
  const n1=await byId(N1); await n1.loadAsync(); const N1F={}; for(const s of n1.children.filter(s=>s.type==='SECTION')) for(const f of s.children) if(f.type==='FRAME'){ const m=f.name.match(/^(N\d{2})\s/); if(m&&!N1F[m[1]]) N1F[m[1]]=f; }
  const RE=/\((N\d{2})\)|← (N\d{2})(?![·\d])/; const targets=[]; for(const s of pg.children.filter(s=>s.type==='SECTION')) for(const f of s.children) if(f.type==='FRAME'){ const m=f.name.match(RE); if(m){ const code=m[1]||m[2]; if(N1F[code]&&CH.has(code)) targets.push({c:f,src:N1F[code],code}); } }
  const map={}; const log=[]; const pb=await byId(PBTN);
  for(const {c,src,code} of targets){ const par=c.parent; const nc=src.clone(); par.appendChild(nc); nc.x=c.x; nc.y=c.y; nc.name=c.name;
    for(const n of nc.findAll(x=>'reactions' in x&&x.reactions&&x.reactions.length)) await n.setReactionsAsync([]); if(nc.reactions&&nc.reactions.length) await nc.setReactionsAsync([]);
    if(c.reactions&&c.reactions.length) await nc.setReactionsAsync(c.reactions.map(r=>({trigger:r.trigger,actions:actsOf(r)})));
    const btns=[]; for(const n of nc.findAll(x=>x.type==='INSTANCE')){ const mc=await n.getMainComponentAsync(); if(mc&&mc.parent&&mc.parent.id===PBTN) btns.push(n); }
    // carry over reactions set on P's own button instances (by label)
    const oldBtns=[]; for(const n of c.findAll(x=>x.type==='INSTANCE'&&x.reactions&&x.reactions.length)){ const mc=await n.getMainComponentAsync(); if(mc&&mc.parent&&mc.parent.id===PBTN) oldBtns.push(n); }
    for(const ob of oldBtns){ const lab=texts(ob).map(t=>t.characters).join(''); const nb=btns.find(b=>texts(b).map(t=>t.characters).join('')===lab&&!(b.reactions&&b.reactions.length)); if(nb) try{ await nb.setReactionsAsync(ob.reactions.map(r=>({trigger:r.trigger,actions:actsOf(r)}))); }catch(e){} }
    for(const h of c.children.filter(k=>/^⌖/.test(k.name))){ nc.appendChild(h); }
    map[c.id]=nc.id; log.push(code+':'+c.id+'→'+nc.id); }
  RECLONE=map; R.info.relinked=await relink(map); for(const {c} of targets) c.remove(); R.info.reclone=log.join(' '); });
// ---- SR2-01 · card 3 thumbnail (no people) ----
await B('clubThumb',async()=>{ const c=await byId('422:20163'); if(c) setProps(c,{Thumb:'381:990'}); });
// ---- SR2-05 · MP/Nav Bar → status bar + Player/Nav Bar ----
await B('nav',async()=>{ const navSet=await byId('384:1342'); const back=variant(navSet,{Leading:'Back',Title:'None',Trailing:'None'}); const sbMain=await (await byId('290:21314')).getMainComponentAsync(); let n=0, root=0;
  for(const i of pg.findAllWithCriteria({types:['INSTANCE']})){ if(i.id.includes(';')||!/nav|Nav/.test(i.name)) continue; const m=await i.getMainComponentAsync(); if(!m) continue; const nm=m.parent&&m.parent.type==='COMPONENT_SET'?m.parent.name:m.name; if(nm!=='MP/Nav Bar') continue;
    const isRoot=/Type=Root/.test(m.name); const w=figma.createFrame(); w.name=isRoot?'status · (root)':'nav · Player/Nav Bar'; w.fills=[]; w.resize(393,isRoot?54:100); const par=i.parent; par.insertChild(par.children.indexOf(i),w); if(par.layoutMode&&par.layoutMode!=='NONE'&&i.layoutPositioning!=='ABSOLUTE'){ w.layoutSizingHorizontal='FILL'; } else { w.x=i.x; w.y=i.y; }
    const sb=sbMain.createInstance(); w.appendChild(sb); sb.x=0; sb.y=0; if(!isRoot){ const nb=back.createInstance(); w.appendChild(nb); nb.x=0; nb.y=54; nb.resize(393,46); } if(isRoot){ root++; w.resize(393,54); }
    if(i.reactions&&i.reactions.length) try{ await w.setReactionsAsync(i.reactions.map(r=>({trigger:r.trigger,actions:actsOf(r)}))); }catch(e){} i.remove(); n++; }
  R.info.nav=n+' (root '+root+')'; });
// ---- SR2-50 · flows, small hotspots, scrims ----
await B('flows',async()=>{ const nm={'210:8322':'04a 漫游 · 开始','397:4607':'04b 漫游 · 按住走起','401:4953':'03b 游玩 · HUD 与队伍频道'}; pg.flowStartingPoints=pg.flowStartingPoints.map(f=>nm[f.nodeId]?{nodeId:f.nodeId,name:nm[f.nodeId]}:f);
  let h=0; for(const r of pg.findAll(n=>n.type==='RECTANGLE'&&/^⌖/.test(n.name)&&(n.width<44||n.height<44))){ const cx=r.x+r.width/2, cy=r.y+r.height/2; r.resize(Math.max(44,r.width),Math.max(44,r.height)); r.x=cx-r.width/2; r.y=cy-r.height/2; h++; }
  for(const n of pg.findAll(n=>n.type==='FRAME'&&n.reactions&&n.reactions.length&&(n.height<44)&&n.height>=24&&n.width>=24&&n.parent&&n.parent.layoutMode)){ const d=Math.ceil((44-n.height)/2); n.paddingTop=(n.paddingTop||0)+d; n.paddingBottom=(n.paddingBottom||0)+d; h++; }
  R.info.hotspots=h;
  const ov=await byId('396:4368'); let s=0; for(const f of ov.children.filter(c=>c.type==='FRAME')){ const out=f.children.find(c=>/outside/.test(c.name)); if(out){ out.fills=[PAINT('scrim')]; s++; } const sh=f.children.find(c=>c.type==='FRAME'&&/sheet/i.test(c.name)); if(sh) sh.fills=[PAINT('surface-2')]; ANN(f,'**skill-r2 SR2-50** · Overlay: set Background → scrim 40% in the prototype panel (the Plugin API cannot). Sheet surface-2, rows surface-3.','I'); } R.info.scrims=s; });
// ---- SR2-11 · 附近 tiles, 俱乐部已创建 seal ----
await B('sheets11',async()=>{ const nb=await byId('396:4648'); if(nb) for(const row of nb.children.filter(c=>c.type==='FRAME'&&c.height>60)){ row.fills=[PAINT('surface-3')]; row.cornerRadius=12; for(const t of row.findAll(n=>(n.type==='FRAME'||n.type==='RECTANGLE')&&n.width>=36&&n.width<=64&&Array.isArray(n.fills)&&n.fills.some(f=>f.type&&f.type.startsWith('GRADIENT')))){ t.fills=[PAINT('surface-2')]; } }
  const icon=await byId('396:4693'); if(icon){ const art=await byId('382:1118'); const seal=variant(art,{Kind:'Seal'}); const i=seal.createInstance(); icon.parent.insertChild(icon.parent.children.indexOf(icon),i); i.resize(96,96); i.x=icon.x-16; i.y=icon.y-16; icon.remove(); } });
// ---- SR2-07 · 战报 / 结算 ----
await B('report',async()=>{ const f=await byId('204:15044'); for(const t of f.findAll(n=>n.type==='TEXT'&&n.characters.trim()==='本局不计分'&&n.name!=='subtitle')){ let p=t.parent; if(p&&p!==f&&p.width<200) p.visible=false; else t.visible=false; }
  for(const t of f.findAll(n=>n.type==='TEXT'&&/→\s*$/.test(n.characters))) await setT(t,t.characters.replace(/\s*→\s*$/,' ›'));
  const s=await byId('204:15096'); const ticks=await byId('291:57395'); if(ticks){ const art=await byId('382:1118'); const seal=variant(art,{Kind:'Seal'}).createInstance(); const par=ticks.parent; par.insertChild(par.children.indexOf(ticks),seal); seal.resize(96,96); if(par.layoutMode&&par.layoutMode!=='NONE'){} else { seal.x=(par.width-96)/2; seal.y=ticks.y-30; } ticks.visible=false; }
  SR(f,'SR2-07','本局不计分 once (subtitle); row arrows → ›. 结算 opens with the Moment/Art seal over 6 / 6. Podium third seat: empty outline (todo in code: dashed ink-3 ring, —).'); });
// ---- SR2-08 · share cards ----
await B('share',async()=>{ const f=await byId('210:10082'); const art=(await byId('295:17368')); if(art){ const i=art.findOne(n=>n.type==='INSTANCE'); if(i){ const cx=i.x+i.width/2, cy=i.y+i.height/2; i.resize(144,144); i.x=cx-72; i.y=cy-72; } }
  const dots=await byId('295:17375'); if(dots) for(const d of [...dots.children]){ const b=d.fills&&d.fills[0]&&d.fills[0].boundVariables&&d.fills[0].boundVariables.color; const nm=b&&VI[b.id]?VI[b.id].name:''; const c=d.fills&&d.fills[0]&&d.fills[0].color; if(/gold|rare|mustard/.test(nm)||(c&&c.r>0.7&&c.g>0.5&&c.b<0.3)) d.remove(); }
  const sw=[]; for(const id of ['185:6705']){ const fr=await byId(id); if(fr) sw.push(...fr.findAll(n=>/switch · on/.test(n.name))); } for(const s of pg.findAll(n=>/switch · on/.test(n.name))) sw.push(s);
  for(const s of sw){ const track=s.type==='FRAME'||s.type==='RECTANGLE'?s:null; if(track){ track.fills=[RAW('FFFFFF',0.32)]; } for(const k of s.findAll(n=>n.type==='ELLIPSE')) k.fills=[RAW('FFFFFF')]; }
  R.info.switches=sw.length; OWN(f,'Q11','Status is never a hue on the deed band or the map; share-card palette without mustard.'); });
// ---- SR2-03 · 漫游 root ----
await B('roam',async()=>{ const f=await byId('210:8322'); const hdr=await byId('290:21323'); setProps(hdr,{Subtitle:'持有 3 / 9 · 今天 +186','Show subtitle':true}); await go(hdr,RECLONE[P_N01]||P_N01);
  const pill=await byId('397:4596'); if(pill) pill.remove();
  const ctr=await byId('290:21335'); if(ctr) ctr.y=286; const hm=await byId('290:21405'); if(hm) hm.y=286;
  const sheet=await byId('290:21343'); const old=await byId('397:4601'); const pk=await byId(PKIT); const hs=pk.findOne(n=>n.type==='COMPONENT_SET'&&n.name==='Player/Hold Button');
  if(sheet&&hs&&old){ for(const c of sheet.children) if(c.name!=='grabber') c.y+=84; sheet.y=sheet.y-84; sheet.resize(393,sheet.height+84); const h=variant(hs,{State:'Rest'}).createInstance(); sheet.insertChild(1,h); h.x=12; h.y=20; setProps(h,{Label:'按住 0.8 秒开始漫游'}); old.remove(); const hot=await byId('397:4786'); if(hot){ hot.x=12; hot.y=sheet.y+20; hot.resize(369,60); } }
  const legacy=await byId('290:21340'); if(legacy) legacy.remove();
  SR(f,'SR2-03','Stat moved into the header subtitle (→ N01); hold button docked in the 附近 sheet on surface; map controls above the sheet; map = Map/Base Fog. Café photo with people in the first 附近 row: replace in the Theme Card cover (SR2-06).');
  OWN(f,'Q9','The 漫游 tab root is the map; the shipped list (走起 + 漫游护照) is superseded.');
  const r1=await byId('169:4853'); if(r1&&!/superseded/.test(r1.name)){ r1.name='010 · superseded by P 210:8322'; ANN(r1,'**Superseded** · skill-r2 Q8: P 210:8322 is the source of truth for the 漫游 root.','D'); } });
// ---- SR2-04 · play HUD ----
await B('hud',async()=>{ const f=await byId('401:4731'); const card=await byId('401:4746'); for(const t of card.findAll(n=>n.type==='TEXT'&&/1\.2\s*km/.test(n.characters))){ let p=t.parent; while(p&&p.parent!==card&&p.parent!==f) p=p.parent; if(p&&p.parent&&p!==card) p.visible=false; else t.visible=false; }
  const bar=await byId('401:4764'); const hint=await byId('211:5141'); const pb=await byId(PBTN); if(bar){ const row=figma.createAutoLayout('HORIZONTAL'); row.name='play bar · 提示 + 队伍 + 背包'; row.fills=[]; row.itemSpacing=12; row.counterAxisAlignItems='CENTER'; f.appendChild(row); row.x=16; row.y=bar.y; row.resize(361,52); row.primaryAxisSizingMode='FIXED';
    const b=variant(pb,{Kind:'Secondary',Size:'44',State:'Default'}).createInstance(); row.appendChild(b); setProps(b,{Label:'提示'}); b.layoutSizingHorizontal='FILL'; if(hint&&hint.reactions) await b.setReactionsAsync(hint.reactions.map(r=>({trigger:r.trigger,actions:actsOf(r)})));
    for(const [ic,lab] of [['people','队伍'],['grid','背包']]){ const c=AL('HORIZONTAL',lab+' · 44',{w:44,h:44,r:999,fill:'glass',justify:'CENTER'}); row.appendChild(c); await IC(c,ic,20,'ink'); ANN(c,'**skill-r2 SR2-04** · accessibilityLabel "'+lab+'"','A'); }
    bar.remove(); if(hint) hint.remove(); }
  const cover=await byId('401:4732'); if(cover){ try{ setProps(cover,{Place:'Place 5'}); }catch(e){} const sh=figma.createRectangle(); sh.name='top shade · bg 60% → 0'; sh.resize(393,96); const raw=rawOf(V['bg']); sh.fills=[{type:'GRADIENT_LINEAR',gradientTransform:[[0,1,0],[-1,0,1]],gradientStops:[{position:0,color:{r:raw.r,g:raw.g,b:raw.b,a:0.6}},{position:1,color:{r:raw.r,g:raw.g,b:raw.b,a:0}}]}]; f.insertChild(f.children.indexOf(cover)+1,sh); sh.x=0; sh.y=0; }
  SR(f,'SR2-04','One distance (180 m) — the 1.2 km tile is gone; one primary; 提示 Secondary + two 44 pt glass circles (队伍, 背包) with labels; 96 pt top shade under the status bar. Heading arrow rotates to bearing in 15° steps (.rotationEffect with the push spring).'); });
// ---- SR2-06 · 发布 root placeholders ----
await B('publish',async()=>{ const cov=await byId(COVER); const p5=variant(cov,{Ratio:'16:9',Place:'Place 5'}), p1=variant(cov,{Ratio:'16:9',Place:'Place 1'}); let n=0; for(const [id,v] of [['291:7674',p5],['291:7692',p1]]){ const o=await byId(id); if(!o||!v) continue; const i=v.createInstance(); o.parent.insertChild(o.parent.children.indexOf(o),i); i.resize(o.width,o.height); i.x=o.x; i.y=o.y; i.cornerRadius=12; i.name='cover · Media/Cover'; o.remove(); n++; } R.info.publish=n; });
await shot(await byId('210:8322'),0.45); await shot(await byId('401:4731'),0.45); await shot(await byId('204:15044'),0.45); await shot(await byId('210:8374'),0.45);
return R;
