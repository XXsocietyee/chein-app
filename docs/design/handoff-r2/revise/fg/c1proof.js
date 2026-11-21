out.lines=[]; for(const [fid,sid] of [['237:31986','291:54781'],['237:67490','294:12105'],['237:67711','294:12282'],['239:6450','297:12500']]){ const s=await byId(sid); if(s) out.lines.push(fid+':'+await addLine(s)); }
let mv=FG.children.find(c=>c.type==='FRAME'&&c.name==='B2.3c 拖动排序 · 放下（Moved）');
if(!mv){ const src=await byId('237:31986'); mv=src.clone(); mv.name='B2.3c 拖动排序 · 放下（Moved）'; mv.annotations=[]; const lift=mv.findOne(n=>n.type==='INSTANCE'&&/Lifted/.test(n.name)); const sl=mv.findOne(n=>n.name==='drop slot');
 if(lift&&sl){ try{ const vp={}; for(const [k,v] of Object.entries(lift.componentProperties)) if(v.type==='VARIANT'&&/State/.test(k)) vp[k]='Default'; lift.setProperties(vp);}catch(e){ out.errors.push('mv '+e.message);} lift.rotation=0; moveTo(lift,sl); lift.name='Topic/Chapter Card · 已放下'; sl.remove(); }
 for(const d of mv.findAll(n=>/Drop Line/.test(n.name))) d.remove();
 mv.annotations=[{labelMarkdown:'**Motion · Moved (CF-60)** · drop: the card settles spring(response .28, damping .78), shadow fades 140 ms · .impact(.light). Prototype: Rest 237:31646 → (long-press 180 ms) Lifted 237:31986 → (drag) this frame, Smart Animate spring 300/26/1.',categoryId:CAT_I}];
 await place(mv,'CF-60 Moved · B2.3 章节 · 放下'); }
out.moved=mv.id;
out.mvLink=await link(await byId('237:31986'),{type:'ON_DRAG'},mv.id,SA(0.32,SPR(300,26)));
out.x1=await xxl('237:31646','XXL · B2.1 创作页 (CF-67)');
out.x2=await xxl('238:19720','XXL · B5.1a 节点 sheet (CF-67)');
out.d=[]; for(const [id,nm] of [['238:20393','CF-77 · 节点编辑 · 放弃修改'],['239:24873','CF-77 · 章节设置 · 放弃修改'],['246:5882','CF-77 · 票种编辑器 · 放弃修改'],['239:33587','CF-77 · 文本编辑 · 放弃修改']]) out.d.push(await discard(id,nm));
out.fg=FG.id+' '+Math.round(FG.y)+' '+Math.round(FG.width)+'x'+Math.round(FG.height);
return out;
