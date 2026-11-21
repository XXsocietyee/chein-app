const page=await figma.getNodeByIdAsync(PAGEID); await figma.setCurrentPageAsync(page);
for(const s of ['Regular','Medium','Semibold','Bold']) await figma.loadFontAsync({family:'SF Pro',style:s});
const TO=await figma.getNodeByIdAsync('280:479'); const tk=Object.keys(TO.componentPropertyDefinitions).find(k=>k.startsWith('text'));
const inInst=n=>{let p=n.parent; while(p&&p.type!=='PAGE'){ if(p.type==='INSTANCE'||p.type==='COMPONENT') return true; p=p.parent;} return false;};
const out=[];
for(const f of page.findAll(n=>n.type==='FRAME'&&/^toast/i.test(n.name)&&!inInst(n))){ const ts=f.findAll(n=>n.type==='TEXT'&&n.visible); if(!ts.length) continue; const text=ts.map(t=>t.characters).join(' · ');
  const icon=f.findOne(n=>/check/.test(n.name))?'success':f.findOne(n=>/alert|info/.test(n.name))?'info':'none';
  const par=f.parent; const idx=par.children.indexOf(f); const cx=f.x+f.width/2, by=f.y+f.height;
  const inst=TO.children.find(c=>c.name===`Icon=${icon}`).createInstance(); par.insertChild(idx,inst); inst.name='Editor/Toast'; inst.setProperties({[tk]:text});
  if(par.layoutMode&&par.layoutMode!=='NONE'&&f.layoutPositioning!=='ABSOLUTE'){ /* keep flow */ } else { if(par.layoutMode&&par.layoutMode!=='NONE') inst.layoutPositioning='ABSOLUTE';
    if(inst.width>329){ const t=inst.findOne(n=>n.type==='TEXT'); t.textAutoResize='HEIGHT'; t.resize(329-32-(icon==='none'?0:26),t.height); }
    const W=par.width||393; inst.x=Math.max(16,Math.min(W-16-inst.width,cx-inst.width/2)); inst.y=by-inst.height; }
  f.remove(); let top=inst; while(top.parent&&top.parent.type!=='SECTION') top=top.parent; out.push(top.id); }
return {n:out.length, frames:[...new Set(out)].join(' ')};
