// note helper: visible canvas annotation under a frame (inside its section)
await figma.loadFontAsync({family:'SF Pro',style:'Regular'}); await figma.loadFontAsync({family:'SF Pro',style:'Semibold'});
async function NOTE(frameId, text, tag){ const f=await figma.getNodeByIdAsync(frameId); const par=f.parent; const old=par.children.find(c=>c.name===`note:${frameId}${tag?':'+tag:''}`); if(old) old.remove();
 const n=figma.createAutoLayout('VERTICAL'); par.appendChild(n); n.name=`note:${frameId}${tag?':'+tag:''}`; n.fills=[{type:'SOLID',color:{r:1,g:0.957,b:0.761}}]; n.cornerRadius=6; n.paddingTop=n.paddingBottom=6; n.paddingLeft=n.paddingRight=8; n.itemSpacing=2; n.counterAxisSizingMode='FIXED'; n.resize(Math.min(f.width,393),n.height);
 const t=figma.createText(); n.appendChild(t); t.fontName={family:'SF Pro',style:'Regular'}; t.fontSize=11; t.lineHeight={unit:'PIXELS',value:15}; t.characters=text; t.fills=[{type:'SOLID',color:{r:0.25,g:0.2,b:0.05}}]; t.layoutSizingHorizontal='FILL'; t.textAutoResize='HEIGHT';
 // stack below existing notes for this frame
 const mine=par.children.filter(c=>c!==n&&c.name.startsWith(`note:${frameId}`)); let y=f.y+f.height+10; for(const m of mine) y=Math.max(y,m.y+m.height+6);
 n.x=f.x; n.y=y; growSec(n); return n.id; }
async function SETTXT(id, s){ const t=await figma.getNodeByIdAsync(id); if(!t||t.type!=='TEXT') return 'miss '+id; for(const seg of t.getStyledTextSegments(['fontName'])) await figma.loadFontAsync(seg.fontName); t.characters=s; return id; }
function growSec(n){ const par=n.parent; if(par&&par.type==='SECTION'&&n.y+n.height+24>par.height) par.resizeWithoutConstraints(par.width,n.y+n.height+40); }
