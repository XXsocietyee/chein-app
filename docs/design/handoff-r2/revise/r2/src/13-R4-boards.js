// 13-R4-boards · page R4 · 5.2 (MR-03: the four state boards leave the screen sections for a spec section, each labelled with Club/Spec Label),
// 4.10 (F-10: retired 227:17672, 227:18612, 182:8521 → Archive page; links to them removed).
const PG=await goPage('221:3542');
const BOARDS=['221:3542','225:10210','227:18300','230:9905'];
const SPEC=await byId('291:61149');
let S=PG.children.find(s=>s.type==='SECTION'&&s.name.startsWith('规格板 · Spec boards'));
const bottom=Math.max(...PG.children.filter(c=>c!==S).map(c=>c.y+c.height));
if(!S){ S=figma.createSection(); S.name='规格板 · Spec boards (MR-03 · not screens)'; S.x=0; S.y=bottom+600; S.resizeWithoutConstraints(2000,1400); R.created.push(S.id); }
const unl=await relink(Object.fromEntries(BOARDS.map(b=>[b,null]))); R.info.unlinked=unl;
let x=S.children.length?Math.max(...S.children.map(c=>c.x+c.width))+120:80; const moved=[];
for(const id of BOARDS){ const B=await byId(id); if(!B||B.parent===S) continue; const from=B.parent.name; const notes=B.parent.children.filter(c=>c.name.startsWith('note:'+id));
  for(const c of B.parent.children.filter(c=>c!==B&&c.type==='TEXT'&&Math.abs(c.x-B.x)<6&&c.y<B.y&&c.y>B.y-90)){ R.removed.push(c.id); c.remove(); }
  S.appendChild(B); B.x=x; B.y=200; B.name=B.name.replace(/^BOARD · /,'');
  // red dashed "not a screen" outline is no longer needed: the section says so
  if(B.strokes&&B.strokes.length&&B.dashPattern&&B.dashPattern.length){ B.strokes=[]; B.dashPattern=[]; }
  const lab=SPEC.type==='COMPONENT_SET'?(SPEC.defaultVariant||SPEC.children[0]).createInstance():SPEC.createInstance(); S.appendChild(lab); lab.x=x; lab.y=200-lab.height-48; R.created.push(lab.id);
  const o=figma.createText(); S.appendChild(o); o.fontName={family:'SF Pro',style:'Regular'}; o.fontSize=13; o.characters=`原位置：${from} · ${id}`; o.fills=[RAW('6B6B6B')]; o.x=x; o.y=200-36; o.name='label:'+id; R.created.push(o.id);
  let ny=B.y+B.height+16; for(const n of notes){ S.appendChild(n); n.x=x; n.y=ny; ny+=n.height+8; }
  x+=Math.max(B.width,lab.width)+120; moved.push(id+' from '+from); }
S.resizeWithoutConstraints(Math.max(S.width,x+40),Math.max(S.height,Math.max(...S.children.map(c=>c.y+c.height))+120));
R.info['5.2']=moved;
await ARCHIVE([await byId('227:17672'),await byId('227:18612'),await byId('182:8521')].filter(Boolean),'R4 · 商家','verify-r1 4.10 / F-10: superseded (edit-mode frames removed by MR-26; 182:8521 superseded twin of 116).');
return R;
