// B3a · P · re-clone every N1-derived frame from the updated N1 (kit swap, type, deed, map, moments), keeping P's hotspots and incoming links
await goPage(P);
const n1=await byId(N1); await n1.loadAsync();
const N1F={}; for(const s of n1.children.filter(s=>s.type==='SECTION')) for(const f of s.children) if(f.type==='FRAME'){ const m=f.name.match(/^(N\d{2}(?:·[a-z]|·XXL)?)\s/); if(m&&!N1F[m[1]]) N1F[m[1]]=f; }
const RE=/\((N\d{2})\)|← (N\d{2})(?![·\d])/;
const targets=[]; for(const s of figma.currentPage.children.filter(s=>s.type==='SECTION')) for(const f of s.children) if(f.type==='FRAME'){ const m=f.name.match(RE); if(m){ const code=m[1]||m[2]; if(N1F[code]) targets.push({c:f,src:N1F[code],code}); } }
const map={}; const log=[]; let moved=0, rebound=0, stripped=0;
const isBtn=async n=>{ if(n.type!=='INSTANCE') return false; const mc=await n.getMainComponentAsync(); return !!(mc&&mc.parent&&mc.parent.id===PBTN); };
for(const {c,src,code} of targets){ const par=c.parent; const nc=src.clone(); par.appendChild(nc); nc.x=c.x; nc.y=c.y; nc.name=c.name; R.created.push(nc.id);
  for(const n of nc.findAll(x=>'reactions' in x&&x.reactions&&x.reactions.length)){ await n.setReactionsAsync([]); stripped++; } if(nc.reactions&&nc.reactions.length){ await nc.setReactionsAsync([]); }
  if(c.reactions&&c.reactions.length) await nc.setReactionsAsync(c.reactions.map(r=>({trigger:r.trigger,actions:actsOf(r)})));
  const btns=[]; for(const n of nc.findAll(x=>x.type==='INSTANCE')) if(await isBtn(n)) btns.push(n);
  const hs=c.children.filter(k=>/^⌖/.test(k.name));
  for(const h of hs){ const back=/返回|✕|close|outside/.test(h.name); const fwd=!back&&h.reactions&&h.reactions.some(r=>actsOf(r).some(a=>a&&a.type==='NODE'));
    if(fwd&&btns.length){ const cy=h.y+h.height/2; let best=null,bd=1e9; for(const b of btns){ const bb=b.absoluteBoundingBox, fb=nc.absoluteBoundingBox; const by=bb.y-fb.y+bb.height/2; const d=Math.abs(by-cy); if(d<bd){ bd=d; best=b; } } if(best&&bd<260&&!(best.reactions&&best.reactions.length)){ try{ await best.setReactionsAsync(h.reactions.map(r=>({trigger:r.trigger,actions:actsOf(r)}))); rebound++; continue; }catch(e){} } }
    nc.appendChild(h); moved++; }
  for(const k of par.children.filter(k=>k.name.startsWith('note:'+c.id))) k.name=k.name.replace(c.id,nc.id);
  map[c.id]=nc.id; log.push(code+' '+c.id+'→'+nc.id); }
const relinked=await relink(map);
for(const {c} of targets){ R.removed.push(c.id); c.remove(); }
R.info={count:targets.length,relinked,moved,rebound,stripped,map,log:log.slice(0,60)};
const s4=await byId('204:9672'); await s4.screenshot({scale:0.08});
R.created=R.created.length; R.removed=R.removed.length; return R;
