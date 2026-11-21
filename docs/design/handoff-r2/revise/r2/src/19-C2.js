// 19-C2 · page C2 · 4.10 / F-12 (sheet frames in A3, A5, A8, A10, A11, A12: the page drawn under the scrim is re-cloned from the current editor page),
// Q6 check, 5.7 (census). DRY=true reports bases and sources only.
const PG=await goPage('235:178');
const SECRE=/^A(3|5|8|10|11|12)\b/;
const secs=PG.children.filter(s=>s.type==='SECTION'&&SECRE.test(s.name));
const isScrim=n=>/scrim|遮罩|dim|蒙层|overlay/i.test(n.name)||(n.type==='RECTANGLE'&&n.fills&&n.fills.some(f=>f.type==='SOLID'&&lum(f.color)<0.05&&(f.opacity??1)<0.8));
const plan=[];
for(const s of secs){ const pages=s.children.filter(f=>f.type==='FRAME'&&f.findOne(n=>n.name==='section bar (sticky)')&&!f.children.some(isScrim));
  for(const S of s.children.filter(f=>f.type==='FRAME'&&f.children.some(isScrim))){ const si=S.children.findIndex(isScrim); const base=S.children.slice(0,si).filter(c=>c.width>=380&&c.height>=600).sort((a,b)=>b.width*b.height-a.width*a.height)[0];
    if(!base) { plan.push({sec:s.name,sheet:S.id,name:S.name,base:null,kids:S.children.slice(0,6).map(c=>c.name)}); continue; }
    const stale=!base.findOne(n=>n.name==='section bar (sticky)');
    const lcp=(a,b)=>{ let i=0; while(i<a.length&&a[i]===b[i]) i++; return i; }; const src=pages.slice().sort((a,b)=>lcp(b.name,S.name)-lcp(a.name,S.name))[0];
    plan.push({sec:s.name,sheet:S.id,name:S.name,base:base.id,baseName:base.name,stale,src:src?src.id:null,srcName:src?src.name:null}); } }
R.info.plan=plan;
if(!DRY){ const done=[];
  for(const p of plan){ if(!p.base||!p.stale||!p.src) continue; const S=await byId(p.sheet), base=await byId(p.base), src=await byId(p.src);
    const c=src.clone(); S.insertChild(S.children.indexOf(base),c); if(S.layoutMode&&S.layoutMode!=='NONE') c.layoutPositioning='ABSOLUTE'; c.x=base.x; c.y=base.y; c.name='base · clone of '+src.id+' ('+src.name.slice(0,30)+')'; c.annotations=[];
    for(const n of [c,...c.findAll(x=>'reactions' in x&&x.reactions&&x.reactions.length)]) if(n.reactions&&n.reactions.length) await n.setReactionsAsync([]);
    c.clipsContent=true; if(Math.abs(c.height-base.height)>1) c.resize(c.width,base.height);
    R.removed.push(base.id); base.remove(); R.created.push(c.id); done.push(p.sheet+' ← '+p.src); }
  R.info.recloned=done; }
if(DRY) return R;
{ const out=[]; for(const s of PG.children.filter(s=>s.type==='SECTION')) for(const F of s.children){ if(F.type!=='FRAME') continue; const ext=/外部|外链|第三方|小游戏|external/i.test(F.name)||texts(F).some(t=>/外部游戏|第三方游戏|外部玩法/.test(t.characters)); if(!ext) continue;
    let hit=0; for(const t of texts(F)){ if(/^[\d,，]+\s?积分(起)?$/.test(t.characters.trim())&&t.visible){ t.visible=false; hit++; R.touched.push(t.id); } }
    if(hit){ OWNER(F,'Q6','External-game price hidden until the 积分 conversion rule exists.'); out.push(F.id+' ×'+hit); } } R.info.Q6=out; }
await census('C2');
return R;
