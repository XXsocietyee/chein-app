for(const id of ['237:62463','237:62925','237:63387']){ const t=await byId(id); if(t&&t.type==='TEXT') await setT(t,'网络没连上，内容已保留，请重试'); }
const op=await byId('I238:15742;280:467'); if(op&&op.type==='TEXT') await setT(op,'选项没加载出来，请重试');
const P1=await byId('334:23538'); const body=P1.children.find(c=>c.name==='step body'); const cand=body?body.findAll(n=>(n.type==='FRAME'||n.type==='INSTANCE')&&n.width>=240&&n.height>=40&&n.height<=110&&n.findAll&&n.findAll(x=>x.type==='TEXT').length>0&&!/progress|pager/.test(n.name)):[];
out.cand=cand.slice(0,6).map(n=>n.id+' '+n.name.slice(0,24)+' '+Math.round(n.width)+'x'+Math.round(n.height)+' y'+Math.round(n.y));
const tile=cand.find(n=>/按下/.test(n.name))||cand[Math.min(1,cand.length-1)];
if(tile&&!/按下/.test(tile.name)){ const cx=tile.x+tile.width/2, cy=tile.y+tile.height/2; try{ tile.rescale(0.97); if(!(tile.parent.layoutMode&&tile.parent.layoutMode!=='NONE')){ tile.x=cx-tile.width/2; tile.y=cy-tile.height/2; } tile.name=tile.name+' · 按下 .97'; out.tile=tile.id; }catch(e){ out.errors.push('tile '+e.message); } }
let mv=FG.children.find(c=>c.type==='FRAME'&&c.name==='A4.11c 排序 · 放下（Moved）');
if(!mv){ const src=await byId('239:19592'); mv=src.clone(); mv.name='A4.11c 排序 · 放下（Moved）'; mv.annotations=[]; const lift=mv.findOne(n=>n.name==='list item/第 3 步'); const first=lift?lift.parent.children.find(c=>/第 1 步/.test(c.name)):null;
 for(const d of mv.findAll(n=>/Drop Line/.test(n.name))) d.remove();
 if(lift&&first){ lift.effects=[]; const par=lift.parent; if(par.layoutMode&&par.layoutMode!=='NONE'){ par.insertChild(par.children.indexOf(first),lift); } else { const y0=first.y; for(const m of par.children.filter(c=>c!==lift&&c.y>=first.y&&c.y<lift.y)) m.y+=lift.height+8; lift.y=y0; } lift.name='list item/第 3 步 · 已放到第 1 位'; out.mvOk=true; }
 mv.annotations=[{labelMarkdown:'**Motion · Moved (CF-60)** · drop: the row settles spring(response .28, damping .78), shadow fades 140 ms · .impact(.light); step numbers re-count after the drop. Prototype: Rest 239:19531 → (long-press) Lifted 239:19592 → (drag) this frame, Smart Animate spring 300/26/1.',categoryId:CAT_I}];
 await place(mv,'CF-60 Moved · A4.11 排序 · 放下'); }
out.moved=mv.id;
const rest=await byId('239:19531'); const r3=rest?rest.findOne(n=>/第 3 步/.test(n.name)&&n.type!=='TEXT'):null;
out.links=[await link(r3||rest,{type:'MOUSE_DOWN',delay:0.18},'239:19592',SA(0.14)), await link(await byId('239:19592'),{type:'ON_DRAG'},mv.id,SA(0.32,SPR(300,26)))];
out.x1=await xxl('237:43689','XXL · A1.7 玩法编辑器 首屏 (CF-67)');
out.d=[]; for(const [id,nm] of [['237:64911','CF-77 · 列表工具 sheet · 放弃修改'],['238:12643','CF-77 · 扫完回复 · 放弃修改']]) out.d.push(await discard(id,nm));
out.flows=flows([{nodeId:'239:19531',name:'F · 拖动排序 · 步骤 (CF-60)'}]);
out.fg=FG.id+' '+Math.round(FG.y)+' '+Math.round(FG.width)+'x'+Math.round(FG.height);
return out;
