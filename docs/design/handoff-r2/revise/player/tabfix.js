const page=await figma.getNodeByIdAsync(PAGE); await figma.setCurrentPageAsync(page);
const ink=await figma.variables.getVariableByIdAsync('VariableID:7:12');
const P=(op)=>{const p=figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:1,g:1,b:1}},'color',ink); return op!=null?{...p,opacity:op}:p;};
for(const s of ['Regular','Medium','Semibold']) await figma.loadFontAsync({family:'SF Pro',style:s});
const white=f=>f&&f.type==='SOLID'&&f.visible!==false&&(f.opacity??1)>0.9&&f.color.r>0.9&&f.color.g>0.9&&f.color.b>0.9;
const tabs=page.findAll(n=>n.type==='FRAME'&&/^tab\//.test(n.name));
const fixed=[];
for(const t of tabs){
  let sel=false; let how='';
  if(Array.isArray(t.fills)&&t.fills.some(white)){ sel=true; t.fills=[P(0.12)]; how='frame'; }
  const pill=t.children.find(c=>c.name==='selected pill'&&c.visible);
  if(pill&&Array.isArray(pill.fills)&&pill.fills.some(white)){ sel=true; pill.fills=[P(0.12)]; how='pill'; }
  if(!sel) continue;
  for(const x of t.findAll(n=>n.type==='TEXT')){
    const fn=x.fontName; if(fn===figma.mixed) continue; await figma.loadFontAsync(fn);
    x.fills=[P()];
    if(x.name!=='glyph'&&fn.family==='SF Pro') x.fontName={family:'SF Pro',style:'Semibold'};
  }
  for(const v of t.findAll(n=>n.type==='VECTOR')) if(Array.isArray(v.fills)&&v.fills.length) v.fills=[P()];
  let top=t; while(top.parent&&top.parent.type!=='SECTION'&&top.parent.type!=='PAGE') top=top.parent;
  fixed.push(`${t.id} ${how} @${top.id}`);
}
return {count:fixed.length, fixed};
