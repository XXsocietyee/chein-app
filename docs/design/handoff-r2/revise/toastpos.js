const page=await figma.getNodeByIdAsync(PAGEID); await figma.setCurrentPageAsync(page);
const out=[];
for(const i of page.findAllWithCriteria({types:['INSTANCE']}).filter(i=>i.name==='Editor/Toast')){ const par=i.parent; if(par.layoutMode&&par.layoutMode!=='NONE'&&i.layoutPositioning!=='ABSOLUTE') continue;
  const H=par.height; const obs=par.children.filter(c=>c!==i&&c.visible&&/bottom.?bar|Tab Bar|Bottom Bar|composer|suggestions|cta|next/i.test(c.name)&&c.y>H*0.6).map(c=>c.y);
  const floor=obs.length?Math.min(...obs):H-34; const y=floor-12-i.height; if(Math.abs(i.y-y)>1){ i.y=y; i.x=(par.width-i.width)/2; let t=i; while(t.parent&&t.parent.type!=='SECTION') t=t.parent; out.push(t.id); } }
return out.join(' ');
