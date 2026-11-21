const CAT_A='164:2'; const byId=id=>figma.getNodeByIdAsync(id); const out={r:[]};
async function loadFonts(root){ const fs=new Set(); for(const t of root.findAllWithCriteria({types:['TEXT']})) for(const s of t.getStyledTextSegments(['fontName'])) fs.add(JSON.stringify(s.fontName)); for(const f of fs){ try{ await figma.loadFontAsync(JSON.parse(f)); }catch(e){} } }
async function rebuild(srcId,oldId){ const old=await byId(oldId); const src=await byId(srcId); const cl=src.clone(); old.parent.appendChild(cl); cl.x=old.x; cl.y=old.y; cl.name=old.name; const ann=old.annotations.map(a=>({labelMarkdown:a.labelMarkdown||a.label,categoryId:a.categoryId})); old.remove(); if(cl.height>852) cl.resize(393,852); cl.clipsContent=true; await loadFonts(cl);
 const r={id:cl.id,txt:0,fail:0,err:[],stack:0,wrap:0,bar:0};
 for(const t of cl.findAllWithCriteria({types:['TEXT']})){ try{
   const segs=t.getStyledTextSegments(['fontSize']);
   try{ if(t.textStyleId&&typeof t.textStyleId==='string') await t.setTextStyleIdAsync(''); }catch(e){}
   try{ if(t.boundVariables&&t.boundVariables.fontSize) t.setBoundVariable('fontSize',null); }catch(e){}
   try{ if(t.boundVariables&&t.boundVariables.lineHeight) t.setBoundVariable('lineHeight',null); }catch(e){}
   for(const s of segs) t.setRangeFontSize(s.start,s.end,Math.round(s.fontSize*1.35));
   if(t.lineHeight&&t.lineHeight!==figma.mixed&&t.lineHeight.unit==='PIXELS') t.lineHeight={unit:'PIXELS',value:Math.round(t.lineHeight.value*1.35)};
   if(t.textTruncation&&t.textTruncation!=='DISABLED') t.textTruncation='DISABLED'; r.txt++;
 }catch(e){ r.fail++; if(r.err.length<3) r.err.push(t.id+': '+e.message.slice(0,90)); } }
 for(const f of cl.findAll(n=>n.type==='FRAME'&&n.layoutMode==='HORIZONTAL'&&n.children.length===2&&n.children.every(c=>c.type!=='TEXT'&&c.width>=120))){ try{ f.layoutMode='VERTICAL'; f.itemSpacing=Math.max(f.itemSpacing,8); for(const c of f.children){ try{ c.layoutSizingHorizontal='FILL'; }catch(e){} } r.stack++; }catch(e){} }
 for(const f of cl.findAll(n=>n.type==='FRAME'&&n.layoutMode==='HORIZONTAL'&&n.children.length>=3&&n.width>=280&&n.children.every(c=>c.height<=48))){ try{ f.layoutWrap='WRAP'; f.counterAxisSpacing=8; r.wrap++; }catch(e){} }
 for(const t of cl.findAllWithCriteria({types:['TEXT']})){ try{ const p=t.parent; if(p&&p.layoutMode==='VERTICAL'&&t.textAutoResize==='WIDTH_AND_HEIGHT'){ t.layoutSizingHorizontal='FILL'; t.textAutoResize='HEIGHT'; } }catch(e){} }
 const bb=cl.findAllWithCriteria({types:['INSTANCE']}).find(i=>/Bottom Bar/.test(i.name)); if(bb){ const set={}; for(const k in bb.componentProperties){ if(/^showMiddle/.test(k)) set[k]=false; if(/^showLeft/.test(k)) set[k]=true; if(/^left/.test(k)&&bb.componentProperties[k].type==='TEXT') set[k]='⋯'; } try{ bb.setProperties(set); r.bar=1; }catch(e){ r.barErr=e.message; } }
 cl.annotations=ann; return r; }
