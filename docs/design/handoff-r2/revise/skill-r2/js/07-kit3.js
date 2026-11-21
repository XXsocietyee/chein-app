// Batch 2c · Library · SR2-31 / SR2-32 (Map/Base tones, label order, fog, my-cell line, Contrast=Increased; Map/Pin Mine white, Unlit hollow, Level order), SR2-14 (QA glyph opacity)
await goPage(LIB);
{ const all=await figma.listAvailableFontsAsync(); for(const f of all){ if(/^(Noto Sans (JP|SC)|PingFang SC|Inter)$/.test(f.fontName.family)){ try{ await figma.loadFontAsync(f.fontName); }catch(e){} } } }
const B=async(name,fn)=>{ try{ await fn(); R.info[name]='ok'; }catch(e){ R.warn.push(name+': '+String(e).slice(0,160)); } };
const bname=p=>{ const id=p&&p.boundVariables&&p.boundVariables.color&&p.boundVariables.color.id; return id&&VI[id]?VI[id].name:null; };
await B('qaOpacity',async()=>{ const qa=await byId(QA); const out=[]; for(const v of qa.children){ const circ=v.findOne(n=>n.name==='circle'); for(const n of [circ,...circ.findAll(()=>true)]){ if('opacity' in n&&n.opacity<1){ out.push(n.name+':'+n.opacity); n.opacity=1; } if('fills' in n&&Array.isArray(n.fills)&&n.fills.length&&n.type!=='FRAME'){ const f=n.fills.map(p=>p.opacity!=null&&p.opacity<1?{...p,opacity:1}:p); n.fills=f; } } const ic=circ.findOne(n=>n.type==='INSTANCE'); if(ic){ const g=ic.findAll(n=>n.type!=='FRAME'); out.push(v.name+' glyph:'+g.map(n=>n.type+':'+(bname(n.fills&&n.fills[0])||'raw')+':'+(n.fills&&n.fills[0]&&n.fills[0].opacity)).join(',')); } } R.info.qa=out; });
const mb=await byId('387:2721'); const pins=await byId('204:21680');
await B('mapBase',async()=>{ const out=[]; for(const v of mb.children){ const base=v.findOne(n=>/^base/.test(n.name));
    for(const r of v.findAll(n=>/^roads · main/.test(n.name))) for(const s of r.findAll(n=>'fills' in n||'strokes' in n)){ if(Array.isArray(s.fills)&&s.fills.length) s.fills=[PAINT('map-road-major')]; if(Array.isArray(s.strokes)&&s.strokes.length) s.strokes=[PAINT('map-road-major')]; }
    const labels=v.findAll(n=>(n.type==='TEXT'&&/^street/.test(n.name))||/^landmark/.test(n.name));
    const top=figma.createFrame(); top.name='labels'; top.fills=[]; top.resize(v.width,v.height); top.clipsContent=false; v.appendChild(top); if(v.layoutMode&&v.layoutMode!=='NONE') top.layoutPositioning='ABSOLUTE'; top.x=0; top.y=0;
    for(const l of labels){ const ax=sx(l)-sx(v), ay=sy(l)-sy(v); top.appendChild(l); l.x=ax; l.y=ay; if(l.type==='TEXT'){ await styleT(l,'t-cap2'); l.fontName={family:'SF Pro',style:'Medium'}; l.fills=[PAINT('ink-3')]; } }
    for(const c of v.findAll(n=>/^cell/.test(n.name)&&n.type==='RECTANGLE')){ const mine=Array.isArray(c.fills)&&c.fills.length>0; const dn=(c.name.match(/district (\d)/)||[])[1]; if(dn){ c.strokes=[PAINT('district/'+dn)]; c.strokeWeight=1.5; c.strokeAlign='INSIDE'; } if(mine) c.effects=[{type:'INNER_SHADOW',color:{r:1,g:1,b:1,a:1},offset:{x:0,y:0},radius:0,spread:3.5,visible:true,blendMode:'NORMAL'}]; }
    const fog=v.findOne(n=>/fog/i.test(n.name)&&n!==v); if(fog){ out.push(v.name+' fog:'+fog.type+':'+fog.name); if('fills' in fog){ fog.fills=[RAW('000000',0.8)]; fog.strokes=[PAINT('sep')]; fog.strokeWeight=1; } }
    out.push(v.name+' labels '+labels.length); }
  // Contrast=Increased (Territory): 2.5 pt outlines, my cells hatched by a denser inner line
  const terr=mb.children.find(c=>/Territory/.test(c.name)); if(!mb.children.some(c=>/Contrast=Increased/.test(c.name))){ for(const c of mb.children) c.name=c.name+', Contrast=Default'; const inc=terr.clone(); mb.appendChild(inc); inc.name='Layer=Territory, Contrast=Increased'; for(const c of inc.findAll(n=>/^cell/.test(n.name)&&n.type==='RECTANGLE')){ c.strokeWeight=2.5; } gridSet(mb,4,80,80); }
  R.info.mb=out; });
await B('pins',async()=>{ const out=[]; for(const v of pins.children){ const own=(v.name.match(/Owner=([^,]+)/)||[])[1];
    if(own==='Mine'){ const shapes=v.findAll(n=>['ELLIPSE','RECTANGLE','VECTOR','FRAME'].includes(n.type)&&Array.isArray(n.fills)&&n.fills.length); const big=shapes.sort((a,b)=>b.width*b.height-a.width*a.height).find(n=>n.width<=40&&n.width>=16); if(big){ big.fills=[PAINT('me')]; } for(const g of v.findAll(n=>(n.type==='TEXT'||n.type==='VECTOR')&&n!==big&&n.width<=16)){ if(Array.isArray(g.fills)&&g.fills.length) g.fills=[PAINT('ink-inv')]; } if(out.length<2) out.push(tree(v,0,3).join(' / ')); }
    if(own==='Unlit'){ const shapes=v.findAll(n=>['ELLIPSE','RECTANGLE','FRAME'].includes(n.type)&&n.width>=10&&n.width<=40); const big=shapes.sort((a,b)=>b.width*b.height-a.width*a.height)[0]; if(big){ big.fills=[]; big.strokes=[PAINT('ink-3')]; big.strokeWeight=1.5; big.strokeAlign='INSIDE'; } for(const g of v.findAll(n=>n.type==='TEXT')) g.visible=false; }
    if(own==='None'||own==='Other'){ for(const n of v.findAll(n=>Array.isArray(n.strokes)&&n.strokes.length)){ const b=bname(n.strokes[0]); if(b&&/warn|ok|route|gold/.test(b)) n.strokes=[PAINT('ink')]; } } }
  for(const v of pins.children.filter(c=>/Level=0/.test(c.name)).reverse()) pins.insertChild(0,v);
  R.info.pins=out; });
await shot(mb,0.25); await shot(pins,1); await shot(await byId(QA),1.5);
return R;
