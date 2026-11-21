// Batch 4b · P cleanup after the re-clone error; deed Sheet height (library)
await goPage(P);
const B=async(name,fn)=>{ try{ await fn(); R.info[name]=R.info[name]||'ok'; }catch(e){ R.warn.push(name+': '+String(e).slice(0,160)); } };
const pg=figma.currentPage;
await B('dups',async()=>{ const map={}; const out=[]; for(const s of pg.children.filter(s=>s.type==='SECTION')){ const by={}; for(const f of s.children.filter(c=>c.type==='FRAME')){ const k=f.name+'@'+Math.round(f.x)+','+Math.round(f.y); (by[k]=by[k]||[]).push(f); }
    for(const [k,arr] of Object.entries(by)){ if(arr.length<2) continue; const idn=f=>f.id.split(':').map(Number); arr.sort((a,b)=>{ const A=idn(a),Bb=idn(b); return A[0]-Bb[0]||A[1]-Bb[1]; }); const keep=arr[arr.length-1]; for(const o of arr.slice(0,-1)){ map[o.id]=keep.id; out.push(o.id+'→'+keep.id); } } }
  // relink anything still pointing at the old twins, then flows (deduplicated), then remove
  let n=0; for(const node of pg.findAll(x=>'reactions' in x&&x.reactions&&x.reactions.length>0)){ let ch=false; const rs=node.reactions.map(r=>({trigger:r.trigger,actions:actsOf(r).map(a=>{ if(a&&a.type==='NODE'&&map[a.destinationId]){ ch=true; return {...a,destinationId:map[a.destinationId]}; } return a; })})); if(ch){ try{ await node.setReactionsAsync(rs); n++; }catch(e){} } }
  const seen=new Set(); pg.flowStartingPoints=pg.flowStartingPoints.map(f=>({nodeId:map[f.nodeId]||f.nodeId,name:f.name})).filter(f=>{ if(seen.has(f.nodeId)) return false; seen.add(f.nodeId); return true; });
  for(const id of Object.keys(map)){ const o=await byId(id); if(o) o.remove(); }
  R.info.dups=out.length; R.info.dupMap=out.join(' '); R.info.relinked=n; R.info.flows=pg.flowStartingPoints.map(f=>f.name.slice(0,14)+':'+f.nodeId).join(' | '); });
await B('sheetH',async()=>{ const d=await byId(DEED); const v=d.children.find(c=>c.name==='Size=Sheet, State=Mine'); R.info.sheetTree=tree(v,0,3).join('\n');
  for(const s of d.children.filter(c=>/Size=Sheet/.test(c.name))){ s.minHeight=null; s.layoutMode='VERTICAL'; s.primaryAxisSizingMode='AUTO'; for(const c of s.children){ if(c.layoutMode&&c.layoutMode!=='NONE'){ try{ c.layoutSizingVertical='HUG'; }catch(e){} } } const body=s.findOne(n=>n.name==='body'); if(body){ for(const c of body.children){ if(c.visible===false) continue; if(c.layoutMode&&c.layoutMode!=='NONE') try{ c.layoutSizingVertical='HUG'; }catch(e){} } } }
  R.info.sheetH=d.children.filter(c=>/Size=Sheet/.test(c.name)).map(c=>Math.round(c.height)).join(','); gridSet(d,7,24,32); });
// N1 property sheets: deed hugs, sheet hugs
await B('n1sheets',async()=>{ const out=[]; for(const id of ['390:3602','390:3637','390:3671','390:3704','390:3729']){ const i=await byId(id); if(!i) continue; try{ i.layoutSizingVertical='HUG'; }catch(e){} const sh=i.parent; if(sh&&sh.name==='sheet'){ sh.primaryAxisSizingMode='AUTO'; sh.y=sh.parent.height-sh.height; out.push(Math.round(i.height)+'/'+Math.round(sh.height)); } } R.info.n1sheets=out.join(' ');
  // same on the P copies (re-cloned from N1 before this fix)
  for(const f of pg.findAll(n=>n.type==='FRAME'&&/\((N0[89]|N1[012])\)|← N(0[89]|1[012])/.test(n.name))){ const sh=f.children.find(c=>c.name==='sheet'); if(!sh) continue; for(const i of sh.findAll(n=>n.type==='INSTANCE'&&n.name==='City/Deed Card')) try{ i.layoutSizingVertical='HUG'; }catch(e){} sh.primaryAxisSizingMode='AUTO'; sh.y=f.height-sh.height; } });
await shot(await byId('204:23542'),0.45);
{ const f=pg.findAll(n=>n.type==='FRAME'&&/← N09|\(N09\)/.test(n.name))[0]; if(f) await shot(f,0.45); }
return R;
