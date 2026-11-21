// Batch 4c · P (+ Library, N1 cross-page) · SR2-06 photos, SR2-10 hold buttons, SR2-05 N1 chevrons, SR2-50 type map on P + flow name
await goPage(P);
{ const all=await figma.listAvailableFontsAsync(); for(const f of all){ if(/^(Noto Sans (JP|SC)|PingFang SC|Inter)$/.test(f.fontName.family)){ try{ await figma.loadFontAsync(f.fontName); }catch(e){} } } }
const B=async(name,fn)=>{ try{ await fn(); R.info[name]=R.info[name]||'ok'; }catch(e){ R.warn.push(name+': '+String(e).slice(0,160)); } };
const ofMain=async(root,setName)=>{ const out=[]; for(const i of root.findAllWithCriteria({types:['INSTANCE']})){ const m=await i.getMainComponentAsync(); if(m&&((m.parent&&m.parent.type==='COMPONENT_SET'&&m.parent.name===setName)||m.name===setName)) out.push(i); } return out; };
const pg=figma.currentPage;
// ---- SR2-06 · Media/Cover by place ----
let NEWPH={};
await B('photos',async()=>{ const cov=await byId(COVER); const src=await byId('204:26791'); const img=src&&Array.isArray(src.fills)?src.fills.filter(f=>f.type==='IMAGE'):[];
  for(const v of cov.children){ v.name=v.name.replace('Place=Place 1','Place=武康大楼').replace('Place=Place 5','Place=梧桐书店').replace('Place=Place 2','Place=老街人群 (not for deeds)').replace('Place=Place 4','Place=咖啡馆人像 (not for deeds)').replace('Place=Place 3','Place=一起玩海报'); }
  if(img.length&&!cov.children.some(v=>/老麦咖啡馆/.test(v.name))){ for(const r of ['16:9','1:1']){ const base=cov.children.find(v=>v.name===`Ratio=${r}, Place=武康大楼`); const c=base.clone(); cov.appendChild(c); c.name=`Ratio=${r}, Place=老麦咖啡馆`; const tgt=[c,...c.findAll(()=>true)].filter(n=>Array.isArray(n.fills)&&n.fills.some(f=>f.type==='IMAGE')); for(const t of tgt) t.fills=img.map(f=>({...f,scaleMode:'FILL'})); NEWPH[r]=c.id; } }
  const rows=[...new Set(cov.children.map(v=>v.y))].length; gridSet(cov,7,24,24); R.info.photos=cov.children.map(v=>v.name.replace('Ratio=','').slice(0,30)+':'+v.id).join(' | ');
  const lm=NEWPH['16:9']||(cov.children.find(v=>v.name==='Ratio=16:9, Place=老麦咖啡馆')||{}).id; const wt=(cov.children.find(v=>v.name==='Ratio=16:9, Place=梧桐书店')||{}).id; R.info.lm=lm; R.info.wt=wt;
  // set deed photos on N1 by name
  const n1=await byId(N1); await n1.loadAsync(); let n=0; for(const i of n1.findAllWithCriteria({types:['INSTANCE']})){ if(i.name!=='City/Deed Card') continue; const p=i.componentProperties; const nm=(Object.entries(p).find(([k])=>k.startsWith('名称'))||[])[1]; const v=nm&&nm.value; const ph=v==='老麦咖啡馆'?lm:v==='梧桐书店'?wt:null; if(ph){ try{ setProps(i,{Photo:ph}); n++; }catch(e){} } }
  for(const i of pg.findAllWithCriteria({types:['INSTANCE']})){ if(i.name!=='City/Deed Card') continue; const p=i.componentProperties; const nm=(Object.entries(p).find(([k])=>k.startsWith('名称'))||[])[1]; const v=nm&&nm.value; const ph=v==='老麦咖啡馆'?lm:v==='梧桐书店'?wt:null; if(ph){ try{ setProps(i,{Photo:ph}); n++; }catch(e){} } }
  R.info.deedPhotos=n; });
// ---- SR2-10 · one hold button ----
await B('hold',async()=>{ const pk=await byId(PKIT); const hs=pk.findOne(n=>n.type==='COMPONENT_SET'&&n.name==='Player/Hold Button'); let n=0; const out=[];
  for(const [fid,st,lab] of [['204:15032','Rest','按住 0.8 秒开局'],['289:2730','Rest','按住 0.8 秒开局'],['289:2804','Holding','松手取消'],['301:3116','Holding','松手取消']]){ const f=await byId(fid); if(!f) continue; const t=f.findAll(x=>x.type==='TEXT'&&/按住|松手取消|长按/.test(x.characters)).filter(x=>!x.id.includes(';'))[0]; if(!t){ out.push(fid+':notext'); continue; } let a=t.parent; while(a&&a!==f&&!(a.width>=300&&a.height<=100)) a=a.parent; if(!a||a===f){ out.push(fid+':noanc'); continue; }
    const h=variant(hs,{State:st}).createInstance(); const par=a.parent; par.insertChild(par.children.indexOf(a),h); if(par.layoutMode&&par.layoutMode!=='NONE'&&a.layoutPositioning!=='ABSOLUTE'){ h.layoutSizingHorizontal='FILL'; } else { h.x=a.x+(a.width-h.width)/2; h.y=a.y+(a.height-h.height)/2; }
    setProps(h,{Label:lab}); if(a.reactions&&a.reactions.length) try{ await h.setReactionsAsync(a.reactions.map(r=>({trigger:r.trigger,actions:actsOf(r)}))); }catch(e){} a.remove(); n++; out.push(fid+':'+h.id); }
  R.info.hold=out.join(' '); });
// ---- SR2-05 · N1 loose chevrons → Player/Nav Bar ----
await B('n1nav',async()=>{ const n1=await byId(N1); const navSet=await byId('384:1342'); const back=variant(navSet,{Leading:'Back',Title:'None',Trailing:'None'}); let n=0;
  for(const sec of n1.children.filter(s=>s.type==='SECTION')) for(const f of sec.children.filter(c=>c.type==='FRAME')){ const nav=f.children.find(c=>c.name==='nav'&&c.type==='FRAME'); if(!nav) continue; const bar=nav.children.find(c=>c.name==='bar'&&c.type==='FRAME'); if(!bar) continue; const ic=bar.findOne(x=>x.type==='INSTANCE'&&/back/i.test(x.name)); if(!ic) continue;
    const nb=back.createInstance(); nav.insertChild(nav.children.indexOf(bar),nb); if(nav.layoutMode&&nav.layoutMode!=='NONE'){ nb.layoutSizingHorizontal='FILL'; nb.resize(nb.width,46); } else { nb.x=bar.x; nb.y=bar.y; nb.resize(bar.width,46); } bar.remove(); n++; }
  R.info.n1nav=n; });
// ---- SR2-50 · type map on P (MP styles → ramp; loose text by size) ----
await B('ptype',async()=>{ const MAP={'MP/body':'t-sub','MP/body-strong':'t-sub','MP/caption':'t-foot','MP/micro':'t-cap2','MP/tag':'role/tag','MP/label':'t-cap','MP/card-title':'t-head','MP/section-title':'t-3','MP/sheet-title':'t-2','MP/feed-title':'t-2','MP/page-title':'t-1','MP/display':'t-1','MP/data-xl':'t-large','MP/data-2xl':'t-hero','MP/button':'role/button-md','MP/button-secondary':'role/button-md'};
  const byIdS={}; for(const s of Object.values(TS)) byIdS[s.id]=s.name; const size=s=>s>=34?'t-large':s>=28?'t-1':s>=22?'t-2':s>=20?'t-3':s>=17?'t-head':s>=16?'t-callout':s>=15?'t-sub':s>=13?'t-foot':s>=12?'t-cap':'t-cap2'; let a=0,b=0;
  for(const t of pg.findAllWithCriteria({types:['TEXT']})){ if(t.id.includes(';')||typeof t.fontSize!=='number') continue; let p=t.parent, inst=false; while(p&&p.type!=='SECTION'&&p.type!=='PAGE'){ if(p.type==='INSTANCE'){ inst=true; break; } p=p.parent; } if(inst) continue;
    const cur=t.textStyleId&&typeof t.textStyleId==='string'?byIdS[t.textStyleId]:null; let to=null; if(cur&&MAP[cur]) { to=MAP[cur]; a++; } else if(!t.textStyleId){ if(t.parent&&t.parent.type==='SECTION') continue; to=size(t.fontSize); b++; } if(!to||!TS[to]) continue; const fl=t.fills; await styleT(t,to); t.fills=fl; }
  R.info.ptype='MP→ramp '+a+', loose '+b;
  pg.flowStartingPoints=pg.flowStartingPoints.map(f=>f.name==='Flow 7'?{nodeId:f.nodeId,name:'03b 游玩 · HUD 与队伍频道'}:f); });
await shot(await byId('204:23542'),0.4); await shot(await byId('204:15032'),0.4); await shot(await byId('205:8376'),0.4); await shot(await byId('204:15044'),0.4);
return R;
