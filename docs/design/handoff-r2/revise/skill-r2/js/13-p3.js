// Batch 4d · P · retries: deed photos, P type map (mixed fills), lobby + R6 hold buttons
await goPage(P);
{ const all=await figma.listAvailableFontsAsync(); for(const f of all){ if(/^(Noto Sans (JP|SC)|PingFang SC|Inter)$/.test(f.fontName.family)){ try{ await figma.loadFontAsync(f.fontName); }catch(e){} } } }
const B=async(name,fn)=>{ try{ await fn(); R.info[name]=R.info[name]||'ok'; }catch(e){ R.warn.push(name+': '+String(e).slice(0,160)); } };
const pg=figma.currentPage;
await B('photos',async()=>{ const lm='435:4517', wt='382:1063'; let n=0; const n1=await byId(N1); await n1.loadAsync();
  for(const root of [n1,pg]){ const ids=root.findAllWithCriteria({types:['INSTANCE']}).filter(i=>i.name==='City/Deed Card'&&!i.id.includes(';')).map(i=>i.id);
    for(const id of ids){ const i=await byId(id); if(!i) continue; const p=i.componentProperties; const nm=(Object.entries(p).find(([k])=>k.startsWith('名称'))||[])[1]; const v=nm&&nm.value; const ph=v==='老麦咖啡馆'?lm:v==='梧桐书店'?wt:null; if(ph){ try{ setProps(i,{Photo:ph}); n++; }catch(e){} } } }
  R.info.photos=n; });
await B('ptype',async()=>{ const MAP={'MP/body':'t-sub','MP/body-strong':'t-sub','MP/caption':'t-foot','MP/micro':'t-cap2','MP/tag':'role/tag','MP/label':'t-cap','MP/card-title':'t-head','MP/section-title':'t-3','MP/sheet-title':'t-2','MP/feed-title':'t-2','MP/page-title':'t-1','MP/display':'t-1','MP/data-xl':'t-large','MP/data-2xl':'t-hero','MP/button':'role/button-md','MP/button-secondary':'role/button-md'};
  const byIdS={}; for(const s of Object.values(TS)) byIdS[s.id]=s.name; const size=s=>s>=34?'t-large':s>=28?'t-1':s>=22?'t-2':s>=20?'t-3':s>=17?'t-head':s>=16?'t-callout':s>=15?'t-sub':s>=13?'t-foot':s>=12?'t-cap':'t-cap2'; let a=0,b=0,e=0;
  for(const t of pg.findAllWithCriteria({types:['TEXT']})){ if(t.id.includes(';')||typeof t.fontSize!=='number') continue; let p=t.parent, inst=false; while(p&&p.type!=='SECTION'&&p.type!=='PAGE'){ if(p.type==='INSTANCE'){ inst=true; break; } p=p.parent; } if(inst) continue;
    const cur=t.textStyleId&&typeof t.textStyleId==='string'?byIdS[t.textStyleId]:null; let to=null; if(cur&&MAP[cur]) to=MAP[cur]; else if(!t.textStyleId){ if(t.parent&&t.parent.type==='SECTION') continue; to=size(t.fontSize); } if(!to||!TS[to]) continue;
    try{ const fl=t.fills; await styleT(t,to); if(fl!==figma.mixed) t.fills=fl; if(cur) a++; else b++; }catch(err){ e++; } }
  R.info.ptype='MP→ramp '+a+', loose '+b+', skipped '+e; });
await B('hold',async()=>{ const pk=await byId(PKIT); const hs=pk.findOne(n=>n.type==='COMPONENT_SET'&&n.name==='Player/Hold Button'); const out=[];
  const f=await byId('204:15032'); if(f){ const b=f.findAll(x=>x.type==='INSTANCE'&&texts(x).some(t=>/按住/.test(t.characters))).sort((a,b)=>b.width-a.width)[0]; if(b){ const h=variant(hs,{State:'Rest'}).createInstance(); const par=b.parent; par.insertChild(par.children.indexOf(b),h); if(par.layoutMode&&par.layoutMode!=='NONE'&&b.layoutPositioning!=='ABSOLUTE') h.layoutSizingHorizontal='FILL'; else { h.x=b.x+(b.width-h.width)/2; h.y=b.y+(b.height-h.height)/2; } setProps(h,{Label:'按住 0.8 秒开局'}); if(b.reactions&&b.reactions.length) await h.setReactionsAsync(b.reactions.map(r=>({trigger:r.trigger,actions:actsOf(r)}))); b.remove(); out.push('lobby:'+h.id); } }
  const r6=await byId('301:3116'); if(r6){ const t=r6.findAll(x=>x.type==='TEXT'&&/按住|松手|长按|走起/.test(x.characters))[0]; let a=t&&t.parent; while(a&&a!==r6&&!(a.width>=240&&a.height<=140)) a=a.parent; if(a&&a!==r6){ const h=variant(hs,{State:'Holding'}).createInstance(); const par=a.parent; par.insertChild(par.children.indexOf(a),h); if(par.layoutMode&&par.layoutMode!=='NONE'&&a.layoutPositioning!=='ABSOLUTE') h.layoutSizingHorizontal='FILL'; else { h.x=a.x+(a.width-h.width)/2; h.y=a.y+(a.height-h.height)/2; } a.remove(); out.push('r6:'+h.id); } else out.push('r6:'+(t?t.characters.slice(0,10):'notext')); }
  R.info.hold=out.join(' '); });
await shot(await byId('204:15032'),0.4); await shot(await byId('204:23542'),0.4);
return R;
