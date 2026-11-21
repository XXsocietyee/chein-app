// shared: verify-r1 5.7 (CF-15) · touch-target census on a C page. Every control needs a 44 × 44 hit area (visual size may be smaller).
// Kit components without one get an invisible 'hit 44' child in the main component; raw text links and raw small buttons get a 'hit 44' sibling.
const CTRL=/^(Editor\/(Switch|Handle|Stepper|Add Row|Option Row|List Item|Row|Sheet Header|Bottom Bar|Tool Chip|Swatch|Sample Tile|Section Bar|Field|PopUp|Answer Option|Card|Card Footer|Segmented|Save Chip|Nav Bar|Step Bar|Confirm Dialog|Result)|Story\/Seam|Topic\/Chapter Card|Map\/(Locate|Search)|Rule\/Sentence|Node\/Gameplay Card|Player\/Button)/;
const LINK=/(›|>)\s*$|^(去修改|修改|查看.*|阅读.*|编辑|添加.*|＋.*|\+ .*|删除.*|重试|撤销|换一个|全部.*|更多|管理|去设置|去处理|复制)$/;
const hasHit=n=>n.findAll?n.findAll(x=>/^hit/i.test(x.name)&&x.width>=43.5&&x.height>=43.5).length>0:false;
function addHit(n,w,h){ const par=n.parent; if(!par||par.type==='INSTANCE'||insideInstance(n,null)) return false; if(par.children.some(c=>c.name==='hit 44'&&Math.abs((c.x+c.width/2)-(n.x+n.width/2))<4&&Math.abs((c.y+c.height/2)-(n.y+n.height/2))<4)) return 'exists';
  const f=figma.createFrame(); f.name='hit 44'; f.fills=[]; f.resize(w,h); par.appendChild(f); if(par.layoutMode&&par.layoutMode!=='NONE') f.layoutPositioning='ABSOLUTE'; f.x=Math.round(n.x+n.width/2-w/2); f.y=Math.round(n.y+n.height/2-h/2); R.created.push(f.id); return true; }
async function census(tag,opt={}){ const pg=figma.currentPage; const SKIP=/组件|component|kit|素材|asset|F\/G|规格|spec/i;
  const comp={}, raw={links:0,linkFixed:0,small:0,smallFixed:0,ex:[]}, mcCache={};
  const frames=[]; for(const s of pg.children.filter(s=>s.type==='SECTION'&&!SKIP.test(s.name))) for(const f of s.children) if(f.type==='FRAME'&&f.width>=360&&f.height>=480&&!/^(note|label)/.test(f.name)) frames.push(f);
  for(const F of frames){
    for(const i of F.findAllWithCriteria({types:['INSTANCE']})){ if(insideInstance(i,F)) continue; let mc=mcCache[i.id]; const m=await i.getMainComponentAsync(); if(!m) continue; const top=m.parent&&m.parent.type==='COMPONENT_SET'?m.parent:m; const nm=top.name; if(!CTRL.test(nm)) continue;
      const c=comp[nm]||(comp[nm]={name:nm,id:top.id,n:0,minW:1e9,minH:1e9,hit:false,variantsNoHit:new Set()}); c.n++; c.minW=Math.min(c.minW,Math.round(i.width)); c.minH=Math.min(c.minH,Math.round(i.height));
      if(!(m.width>=44&&m.height>=44)&&!hasHit(m)) c.variantsNoHit.add(m.id); }
    for(const t of texts(F)){ if(!t.visible||insideInstance(t,F)) continue; const s=t.characters.trim(); if(!LINK.test(s)||s.length>14) continue; raw.links++;
      let ok=false, p=t.parent; for(let d=0;d<3&&p&&p!==F;d++,p=p.parent){ if(p.height>=44&&p.width<=t.width+200) { ok=true; break; } if(hasHit(p)) { ok=true; break; } }
      if(!ok){ const r=addHit(t,Math.max(44,Math.round(t.width+16)),44); if(r===true){ raw.linkFixed++; if(raw.ex.length<25) raw.ex.push(F.name.slice(0,24)+' · '+s); } else if(r==='exists') {} else raw.small++; } }
    for(const b of F.findAll(n=>(n.type==='FRAME'||n.type==='GROUP')&&!insideInstance(n,F)&&/button|btn|pill|chip|close|✕|back|‹|more|⋯|删除|移除/i.test(n.name)&&(n.width<44||n.height<44)&&n.width<=200)){ if(hasHit(b)||(b.parent&&hasHit(b.parent))) continue; raw.small++; if(b.type==='FRAME'&&addHit(b,Math.max(44,Math.round(b.width)),44)===true) raw.smallFixed++; } }
  // component fixes: one invisible 44 target per variant that is visually smaller
  const compFix=[];
  for(const c of Object.values(comp)){ for(const vid of c.variantsNoHit){ const v=await byId(vid); if(!v||hasHit(v)) continue; const h=figma.createFrame(); h.name='hit 44'; h.fills=[]; const w=Math.max(44,v.width), hh=Math.max(44,v.height); h.resize(w,hh); v.appendChild(h); if(v.layoutMode&&v.layoutMode!=='NONE') h.layoutPositioning='ABSOLUTE'; h.x=Math.round((v.width-w)/2); h.y=Math.round((v.height-hh)/2); v.clipsContent=false; compFix.push(c.name+' / '+v.name); } c.fixedVariants=c.variantsNoHit.size; delete c.variantsNoHit; }
  R.info['5.7 '+tag]={frames:frames.length,components:Object.values(comp).sort((a,b)=>b.n-a.n),raw,compFix}; }
