// Batch 3a · N1 · SR2-25 (one cast) SR2-29 (deed Sheet + 420 detent) SR2-30 (N01/N02/N03) SR2-31 (N07) SR2-26/27/28 (dice + moments copy) SR2-37 (N66) SR2-38 (N12) + library: Icon set mode (SR2-14), Mine pin glyphs (SR2-32)
await goPage(N1);
{ const all=await figma.listAvailableFontsAsync(); for(const f of all){ if(/^(Noto Sans (JP|SC)|PingFang SC|Inter)$/.test(f.fontName.family)){ try{ await figma.loadFontAsync(f.fontName); }catch(e){} } } }
const B=async(name,fn)=>{ try{ await fn(); R.info[name]=R.info[name]||'ok'; }catch(e){ R.warn.push(name+': '+String(e).slice(0,160)); } };
const dcol=Object.values(COLS).find(c=>c.name==='District'); const DM={}; for(const m of dcol.modes) DM[m.name]=m.modeId;
const PH={wk:'382:1055',def:'381:987'};
async function deed(i,o){ if(!i) return; const p={}; for(const k of ['名称','街区','等级','编号','持有','租金','租金说明','Show holder','Show coin','Size','State']) if(o[k]!==undefined) p[k]=o[k]; try{ setProps(i,p); }catch(e){ R.warn.push('deed '+i.id+' '+String(e).slice(0,60)); } if(o.photo) try{ setProps(i,{Photo:o.photo}); }catch(e){} if(o.d) try{ i.setExplicitVariableModeForCollection(dcol,DM[String(o.d)]); }catch(e){ R.warn.push('mode '+i.id); } R.touched.push(i.id); }
const ofMain=async(root,setName)=>{ const out=[]; for(const i of root.findAllWithCriteria({types:['INSTANCE']})){ const m=await i.getMainComponentAsync(); if(m&&((m.parent&&m.parent.type==='COMPONENT_SET'&&m.parent.name===setName)||m.name===setName)) out.push(i); } return out; };
const CAST={
 wk:{名称:'武康大楼',街区:'武康路街区',等级:'据点 Lv2',编号:'地契 · No. 07',d:1,photo:PH.wk},
 lm:{名称:'老麦咖啡馆',街区:'武康路街区',等级:'插旗 Lv0',编号:'地契 · No. 12',d:1,photo:PH.def},
 hd:{名称:'转角花店',街区:'安福路街区',等级:'前哨 Lv1',编号:'地契 · No. 04',d:2,photo:PH.def},
 wt:{名称:'梧桐书店',街区:'衡山路街区',等级:'据点 Lv2',编号:'地契 · No. 03',d:3,photo:PH.def},
 af:{名称:'安福路 12 号',街区:'安福路街区',等级:'前哨 Lv1',编号:'地契 · No. 09',d:2,photo:PH.def}};
// ---- SR2-25 · cast on every deed ----
await B('cast',async()=>{
  const by=async id=>byId(id);
  await deed(await by('389:3547'),{...CAST.wk,租金:'+58',租金说明:'今天 · 每次 +12'});
  await deed(await by('389:3563'),{...CAST.af,租金:'+0',租金说明:'风化 · 9 天未到'});
  await deed(await by('389:3581'),{...CAST.lm,租金:'+12',租金说明:'今天 · 第 1 天'});
  await deed(await by('390:3602'),{...CAST.lm,等级:'无人持有','Show holder':false,租金:'+12',Size:'Sheet'});
  await deed(await by('390:3637'),{...CAST.wt,持有:'阿兰 持有 · 保护到 今天 21:30','Show holder':true,Size:'Sheet'});
  await deed(await by('390:3671'),{...CAST.hd,持有:'小李 持有 · 风化中',Size:'Sheet'});
  await deed(await by('390:3704'),{...CAST.lm,持有:'你持有 · 第 1 天',Size:'Sheet'});
  await deed(await by('390:3729'),{名称:'未点亮的地点',等级:'—',Size:'Sheet'});
  for(const fid of ['205:8376','205:8475','205:8580','205:8686','205:8786','205:8866']){ const f=await by(fid); const ds=f.findAll(n=>n.type==='INSTANCE'&&n.name==='City/Deed Card'); if(ds[0]) await deed(ds[0],{...CAST.wk,租金:'+58',租金说明:'今天 · 每次 +12'}); if(ds[1]) await deed(ds[1],{...CAST.lm,租金:'+12',租金说明:'今天 · 第 1 天'}); if(ds[2]) await deed(ds[2],{...CAST.af,租金:'+0',租金说明:'风化 · 9 天未到'}); }
  // moments + strips: nested deeds
  const sets=[['204:26968','lm','你持有 · 第 1 天'],['204:34407','hd','你持有 · 第 1 天'],['204:34476','wk','林小舟 持有 · 第 1 天'],['204:34510','wk','你持有 · 第 3 天']];
  for(const [fid,k,h] of sets){ const f=await by(fid); if(!f) continue; for(const d of await ofMain(f,'City/Deed Card')) await deed(d,{...CAST[k],持有:h,等级:k==='hd'?'插旗 Lv0':CAST[k].等级}); }
  const strips=await by('399:4429'); for(const fr of strips.children.filter(c=>c.type==='FRAME')){ const k=/^claim/.test(fr.name)?'lm':/^roll-win/.test(fr.name)?'hd':/^taken/.test(fr.name)?'wk':null; if(!k) continue; for(const d of await ofMain(fr,'City/Deed Card')) await deed(d,{...CAST[k],持有:k==='wk'?'林小舟 持有 · 第 1 天':'你持有 · 第 1 天',等级:k==='hd'?'插旗 Lv0':CAST[k].等级}); }
});
// moment copy: one subject per flow
await B('copy',async()=>{ let n=0; const rep=async(root,from,to)=>{ for(const t of root.findAll(x=>x.type==='TEXT'&&x.characters.includes(from))){ if(t.id.includes(';')) continue; await setT(t,t.characters.split(from).join(to)); n++; } for(const i of await ofMain(root,'Player/Moment')){ const p=i.componentProperties; const o={}; for(const [k,v] of Object.entries(p)) if(v.type==='TEXT'&&String(v.value).includes(from)) o[k.split('#')[0]]=String(v.value).split(from).join(to); if(Object.keys(o).length){ setProps(i,o); n++; } } };
  for(const id of ['204:26968','204:26708','204:26816','204:26924']) { const f=await byId(id); if(f) await rep(f,'武康大楼','老麦咖啡馆'); }
  for(const id of ['204:34407','204:34440','204:34340','204:34369']) { const f=await byId(id); if(f) await rep(f,'武康大楼','转角花店'); }
  const strips=await byId('399:4429'); for(const fr of strips.children.filter(c=>c.type==='FRAME')){ if(/^claim/.test(fr.name)) await rep(fr,'武康大楼','老麦咖啡馆'); if(/^roll/.test(fr.name)) await rep(fr,'武康大楼','转角花店'); }
  R.info.copy=n; });
// ---- SR2-26 / 27 / 28 · dice ----
await B('dice',async()=>{ const face=async(fid,v)=>{ const f=await byId(fid); for(const a of await ofMain(f,'Moment/Art')){ try{ setProps(a,{Face:v}); }catch(e){} } };
  await face('204:34340','20'); await face('204:34369',' '); await face('204:34407','14'); await face('204:34440','5');
  const strips=await byId('399:4429'); for(const fr of strips.children.filter(c=>c.type==='FRAME')){ if(/^roll-win-[45]|roll-win · /.test(fr.name)) for(const a of await ofMain(fr,'Moment/Art')) try{ setProps(a,{Face:'14'}); }catch(e){} if(/^roll-win-[12]|^roll-lose-[12]/.test(fr.name)) for(const a of await ofMain(fr,'Moment/Art')) try{ setProps(a,{Face:fr.name.includes('-1')?'20':' '}); }catch(e){} if(/^roll-lose-[345]|roll-lose · /.test(fr.name)) for(const a of await ofMain(fr,'Moment/Art')) try{ setProps(a,{Face:'5'}); }catch(e){} }
  const n36=await byId('204:34340'); const m36=(await ofMain(n36,'Player/Moment'))[0]; if(m36) setProps(m36,{Line:'把骰子甩出去，或点「掷骰」。','Chip 1':'你 洞察 Lv14 · 对手 前哨 Lv1','Show chip 2':false,'Show chip 3':false});
  OWN(n36,'Q2','Flick the die or tap 掷骰; no shake (the system undo gesture, needs motion access). A 20 pt drag hint (arc + arrowhead, ink-3) shows beside the die on first use only.');
  const n37=await byId('204:34369'); const m37=(await ofMain(n37,'Player/Moment'))[0]; if(m37){ const pri=m37.findOne(n=>n.name==='Primary'); if(pri) pri.visible=false; }
  ANN(n37,'**skill-r2 SR2-28** · No button while rolling: the die is the indicator; chip 需要 ≥ 9 stays. VoiceOver: announce 正在掷骰; on the result announce headline + line.','A');
  const n38=await byId('204:34407'); const m38=(await ofMain(n38,'Player/Moment'))[0]; if(m38) setProps(m38,{Line:'掷出 14，加成 +3，合计 17。转角花店归你了。'});
  SR(n38,'SR2-26','Die shows the face 14; the total 17 = 14 + 2 + 1 lives in the line and chips.'); });
// ---- SR2-29 · property sheets at the 420 detent ----
await B('sheets',async()=>{ const out=[]; for(const fid of ['204:23400','204:23542','204:23691','204:23832','204:23956']){ const f=await byId(fid); const sh=f.children.find(c=>c.name==='sheet'&&c.type==='FRAME'); if(!sh){ out.push(fid+':nosheet'); continue; }
    const inset=sh.findOne(n=>n.name==='inset'&&n.type==='FRAME'); if(inset){ const kv=inset.children.filter(c=>c.visible!==false); for(const r of kv.slice(2)) r.remove(); }
    for(const t of sh.findAll(n=>n.type==='TEXT'&&/后结束|11:42/.test(n.characters))) await setT(t,'保护到 今天 21:30');
    if(fid==='204:23832') for(const t of sh.findAll(n=>n.type==='TEXT'&&/升到/.test(n.characters))) await setT(t,t.characters.replace(/据点\s*Lv\s*2/,'前哨 Lv1'));
    for(const t of sh.findAll(n=>n.type==='TEXT'&&/^(阿兰|小李)\s*·/.test(n.characters))){ const row=t.parent; if(row&&row!==sh&&row.height<90) row.remove(); else t.remove(); }
    sh.primaryAxisSizingMode='AUTO'; sh.y=f.height-sh.height; out.push(fid+':'+Math.round(sh.height));
    OWN(f,'Q3','Property sheet at a 420 pt detent with the compact deed (Size=Sheet) and the map live behind; the full deed on expand. SwiftUI: .presentationDetents([.height(420), .large]) + .presentationBackgroundInteraction(.enabled(upThrough: .height(420))); no scrim.'); }
  R.info.sheets=out; });
// ---- SR2-30 · N01 / N02 / N03 ----
await B('n01',async()=>{ const c=await byId('204:21813'); const h=await byId('204:21778'); const deeds=await byId('389:3546'); if(h&&deeds){ c.insertChild(c.children.indexOf(deeds),h); await setT(h,'我的地盘 · 3'); }
  const need=await byId('389:3526'); for(const t of need.findAll(n=>n.type==='TEXT'&&n.characters.includes('武康大楼'))) await setT(t,t.characters.replace('武康大楼','安福路 12 号'));
  for(const tg of await ofMain(need,'Player/Status Tag')) setProps(tg,{State:'Warning'});
  const mod=await byId('389:3435'); const pill=mod.findOne(n=>/stat|pill/i.test(n.name)&&n.type!=='INSTANCE'&&n.parent===mod); if(pill){ pill.x=12; pill.y=mod.height-pill.height-12; }
  for(const p of mod.children.filter(n=>/pin/i.test(n.name)||n.type==='INSTANCE'&&/Map\/Pin/.test(n.name))){ if(p.y<56) p.y=60; }
  SR(await byId('204:21814'),'SR2-30','Order: map → today strip → 需要你处理 (amber Warning tags) → 我的地盘 · 3 → 街区 → 更多. One state per place (安福路 12 号 weathered). Stat pill bottom-left; pins out of the top 56 pt.'); });
await B('n02',async()=>{ const c=await byId('204:21841'); for(const k of [...c.children]) k.remove(); c.itemSpacing=12; c.paddingLeft=16; c.paddingRight=16; for(const h of [220,60,52,52,72,72,72]){ const r=figma.createRectangle(); r.resize(361,h); r.cornerRadius=16; r.fills=[PAINT('skel')]; r.name='skeleton '+h; c.appendChild(r); r.layoutSizingHorizontal='FILL'; } SR(await byId('204:21842'),'SR2-30','Skeleton mirrors N01: map 220 · today 60 · 需要你处理 2×52 · deeds 3×72.'); });
await B('n03',async()=>{ const st=await byId('204:21887'); if(st) st.remove(); const c=await byId('204:21888'); const btn=await byId('389:3674'); const t=await TX(null,'走到真实地点，拍一张照片，通过定位校验，就能圈下它。','t-sub','ink-2',{name:'how'}); c.insertChild(c.children.indexOf(btn)+1,t); t.layoutSizingHorizontal='FILL'; t.textAutoResize='HEIGHT';
  const pb=await byId(PBTN); const tv=variant(pb,{Kind:'Text',Size:'44',State:'Default'}); const link=tv.createInstance(); c.insertChild(c.children.indexOf(t)+1,link); setProps(link,{Label:'看看玩法规则'}); link.layoutSizingHorizontal='FILL';
  SR(await byId('204:21889'),'SR2-30','One primary (去圈第一块地), one line of help, 看看玩法规则 as a text link; the old empty state and its second white primary are gone.'); });
// ---- SR2-31 · N07 ----
await B('n07',async()=>{ const f=await byId('204:23260'); const card=await byId('204:23155'); for(const r of card.findAll(n=>n.type==='FRAME'&&texts(n).some(t=>t.characters==='别人的')&&texts(n).some(t=>t.characters==='我的'))){ r.remove(); break; }
  const gb=await byId('204:23152'), un=await byId('204:23154'); if(gb){ gb.y=600; } if(un){ un.y=594; }
  SR(f,'SR2-31','One legend (Map/Legend); the chat button sits 12 pt above it. Camera: on a successful claim the map zooms to the cell while the sheet leaves (spring 0.45 / 0.86, 0.6 s).');
  OWN(f,'Q1','Mine = white pins and a white inner line on my cells; districts keep their hue; status is a badge shape, never a hue on the map.'); OWN(f,'Q5','Map in code = MapKit with a muted dark style; cells and fog as overlays. These tones are a stand-in.'); });
// ---- SR2-37 · N66 rows ----
await B('n66',async()=>{ const pb=await byId(PBTN); const sec=variant(pb,{Kind:'Secondary',Size:'44',State:'Default'}); const NAMES=[['严谨的核查员','通关《外滩钟声》真结局'],['街坊','城识 Lv10'],['细节控','洞察 Lv10'],['迷雾行者','探索 Lv10']]; let k=0;
  for(const rid of ['207:2138','207:2152','207:2158','207:2164']){ const row=await byId(rid); if(!row) continue; const btn=row.findOne(n=>n.type==='INSTANCE'&&n.width>300); if(!btn){ k++; continue; } btn.remove();
    const col=AL('VERTICAL','text',{gap:2,align:'MIN'}); row.appendChild(col); col.layoutSizingHorizontal='FILL'; col.layoutGrow=1; await TX(col,NAMES[k][0],'t-head','ink',{name:'title',fill:true}); await TX(col,NAMES[k][1],'t-foot','ink-3',{name:'condition',fill:true});
    const b=sec.createInstance(); row.appendChild(b); setProps(b,{Label:'佩戴'}); b.resize(72,44); row.counterAxisAlignItems='CENTER'; row.itemSpacing=12; k++; }
  const n66=await byId('207:2181'); for(const t of n66.findAll(n=>n.type==='TEXT'&&/洞察 Lv25 · 还差 2 级/.test(n.characters))) await setT(t,'探索 Lv25 · 还差 2 级');
  R.info.n66=k; });
// ---- SR2-38 · N12 neutral band handled by Unlit Sheet ----
// ---- library: Icon set mode (SR2-14) + Mine pin glyphs (SR2-32) ----
await B('iconMode',async()=>{ const ic=await byId('9:29'); const out=[]; let p=ic; while(p&&p.type!=='PAGE'){ const em=p.explicitVariableModes||{}; if(Object.keys(em).length){ out.push(p.name.slice(0,20)+':'+JSON.stringify(em)); if(p.type==='COMPONENT_SET'||p.type==='COMPONENT'){ for(const cid of Object.keys(em)){ const c=await figma.variables.getVariableCollectionByIdAsync(cid); p.clearExplicitVariableModeForCollection(c); } } } p=p.parent; }
  for(const n of ic.findAll(()=>true)){ const em=n.explicitVariableModes||{}; if(Object.keys(em).length){ out.push('child '+n.name+':'+JSON.stringify(em)); for(const cid of Object.keys(em)){ const c=await figma.variables.getVariableCollectionByIdAsync(cid); n.clearExplicitVariableModeForCollection(c); } } }
  const g=ic.findOne(n=>n.type==='TEXT'); if(g) out.push('glyph fills '+JSON.stringify(g.fills).slice(0,160)+' op '+g.opacity);
  R.info.iconMode=out; });
await B('pinGlyph',async()=>{ const pins=await byId('204:21680'); let n=0; for(const v of pins.children.filter(c=>/Owner=Mine/.test(c.name))){ for(const t of v.findAll(x=>x.type==='TEXT'||x.type==='VECTOR')){ let p=t.parent, badge=false; while(p&&p!==v){ if(/badge/i.test(p.name)) badge=true; p=p.parent; } if(!badge&&Array.isArray(t.fills)&&t.fills.length){ t.fills=[PAINT('ink-inv')]; n++; } } } R.info.pinGlyph=n; });
await shot(await byId('204:21814'),0.4); await shot(await byId('204:23542'),0.5); await shot(await byId('204:34340'),0.45); await shot(await byId('207:2181'),0.5); await shot(await byId('204:21889'),0.4);
return R;
