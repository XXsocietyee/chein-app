// shared: 4.9 / F-13 · top scrim under a white status bar on a photo hero (HIG Status bars: keep it readable)
async function scrim(fid){ const F=await byId(fid); if(!F) return fid+' missing'; for(const o of F.children.filter(c=>c.name==='status scrim')) o.remove();
  const sb=F.findAll(n=>/status ?bar|statusbar|状态栏/i.test(n.name)).sort((a,b)=>a.absoluteTransform[1][2]-b.absoluteTransform[1][2])[0];
  const r=figma.createRectangle(); r.name='status scrim'; r.resize(F.width,120);
  r.fills=[{type:'GRADIENT_LINEAR',gradientTransform:[[0,1,0],[-1,0,1]],gradientStops:[{position:0,color:{r:0,g:0,b:0,a:0.45}},{position:1,color:{r:0,g:0,b:0,a:0}}]}];
  let where;
  if(sb&&sb.parent===F){ F.insertChild(F.children.indexOf(sb),r); where='below status bar (direct child)'; }
  else { const top=sb?(()=>{ let p=sb; while(p.parent!==F) p=p.parent; return p; })():null; // container that holds the status bar (e.g. the hero instance)
    if(top&&top.type==='INSTANCE'){ // status bar lives inside a component (e.g. Player/Detail Hero): put the scrim in the main component, behind its status bar
      const mc=await top.getMainComponentAsync(); const msb=mc&&mc.findAll(n=>/status ?bar|statusbar|状态栏/i.test(n.name))[0];
      if(mc&&msb&&!mc.findOne(n=>n.name==='status scrim')){ let p=msb; while(p.parent!==mc) p=p.parent; mc.insertChild(mc.children.indexOf(p),r); r.x=0; r.y=0; r.resize(mc.width,120); r.constraints={horizontal:'STRETCH',vertical:'MIN'}; R.created.push(r.id); FIXED(F,'4.9','Top scrim added inside '+mc.name+' (behind its status bar) — every hero gets it (F-13).'); return fid+': scrim in main component '+mc.name+' '+mc.id; }
      r.remove(); return fid+': status bar inside '+top.name+'; main component already has a scrim or no status bar there'; }
    else if(top){ F.insertChild(F.children.indexOf(top)+1,r); where='above '+top.name; } else { F.appendChild(r); where='top (no status bar found)'; } }
  if(F.layoutMode&&F.layoutMode!=='NONE') r.layoutPositioning='ABSOLUTE'; r.x=0; r.y=0; r.constraints={horizontal:'STRETCH',vertical:'MIN'}; R.created.push(r.id);
  FIXED(F,'4.9','Top scrim (black 45% → 0 over 120 pt) under the white status bar keeps it readable on a pale photo (F-13, HIG Status bars).'); return fid+': '+where; }
