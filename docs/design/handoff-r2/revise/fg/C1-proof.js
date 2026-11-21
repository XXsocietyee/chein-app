const PG=await figma.getNodeByIdAsync('237:14642'); await figma.setCurrentPageAsync(PG);
const CAT_I='164:1', CAT_A='164:2', CAT_D='164:0', CAT_C='164:3';
for(const s of ['Regular','Medium','Semibold']) await figma.loadFontAsync({family:'SF Pro',style:s});
const ROW={
 press:'Press (buttons, pills, tiles): scale .97, 80 ms ease-out; release 120 ms · no haptic',
 sheet:'Sheet (§3): present ≈350 ms system spring, dismiss 280 ms; detents spring(response .38, damping .86) · .selection when a drag settles; dirty sheet: swipe-down rubber-bands → 放弃修改 / 继续编辑 · .warning',
 push:'Push inside the sheet (row tap): slide 350 ms ease-out · no haptic',
 sw:'Switch: system toggle + haptic · fields it reveals expand height + fade 220 ms ease-out, hide 180 ms',
 pop:'Pop-up button: system menu + system haptic',
 sel:'Chip / segmented / tile select: fill cross-fade 140 ms, thumb slides 220 ms · .selection',
 add:'Add row (＋ 添加): new row expands from 0 height 220 ms, then focuses its first field · .impact(.light)',
 rm:'Remove row (⋯ → 删除, or swipe): collapse + fade 180 ms, undo toast · .impact(.rigid)',
 reorder:'Reorder (CF-60): long-press 180 ms or handle → lift scale 1.03 + shadow 0 8 24 /.14 in 140 ms · .impact(.medium); neighbours spring(.32, .82), 2 pt Editor/Drop Line at the slot · .selection per slot change; drop spring(.28, .78), shadow fades 140 ms · .impact(.light); auto-scroll within 60 pt of an edge; cancel returns 220 ms, no haptic',
 err:'Inline error: text fades in 140 ms, field border → red 140 ms · .error once per submit',
 jump:'Primary with missing data: scroll to the first error 300 ms, shake 3 × 6 pt in 240 ms · .error',
 counter:'Counter near limit: number rolls (numericText), turns red at the limit · .warning once',
 upload:'Image upload: blurred thumbnail + ring progress, sharpens 220 ms when done · .success',
 slider:'Slider: live value, preview updates each frame · .selection at ticks',
 step:'Stepper: number rolls 140 ms · system haptic',
 save:'Save chip: ↑ then ✓ draws 220 ms · no haptic (frequent)',
 publish:'Result card: rises 24 pt + fade, spring(response .42, damping .8) · .success',
 leave:'Leave with changes (back / swipe-down): action sheet 放弃修改 / 继续编辑 · .warning',
 compass:'Compass capture (取值): dial settles (CF-50) · .impact(.medium)',
 map:'Map pin drop (pan end): pin lifts while panning, drops 180 ms (CF-31) · .impact(.light)',
 toast:'Toast: rises 12 pt + fade 220 ms, stays 2 s, leaves 180 ms · no haptic · VoiceOver announcement',
 load:'Loading: skeleton shimmer 1.2 s loop; content fades in 180 ms',
 seam:'Seam ＋: expands to the block-type tiles, height + fade 220 ms ease-out · .selection',
};
const RMX='CF-65 · Interruptible: a tap or scroll jumps to the end state. Reduce Motion: springs → 200 ms cross-fades; shimmer and preview loops stop; haptics stay.';
function kinds(f){
 const names=f.findAllWithCriteria({types:['INSTANCE']}).map(i=>i.name); const has=re=>names.some(n=>re.test(n)); const fn=f.name; const k=['press'];
 if(has(/Sheet Header/)||/弹层|sheet|抽屉|选择|设置时间/i.test(fn)&&has(/Sheet/)) k.push('sheet');
 if(k.includes('sheet')&&has(/Editor\/Row/)) k.push('push');
 if(has(/Switch/)) k.push('sw');
 if(has(/PopUp|dropdown/i)) k.push('pop');
 if(has(/Segment|Chip|Swatch|Sample Tile|Preview Tile|Option Row|Section Bar|Tool Chip/)) k.push('sel');
 if(has(/Add Row/)) k.push('add');
 if(has(/Editor\/List Item|Editor\/Handle|Chapter Card|Rule\/Sentence|Answer Option/)) k.push('rm','reorder');
 if(/拖动|排序中|Lifted|抬起|drag/i.test(fn)&&!k.includes('reorder')) k.push('reorder');
 if(has(/Editor\/Field/)) k.push('err');
 if(/错误|校验|报错|未填|缺少|还没|阻断|error|无效|为空|重复/i.test(fn)){ if(!k.includes('err')) k.push('err'); k.push('jump'); }
 if(has(/Bottom Bar/)&&!k.includes('jump')) k.push('jump');
 if(has(/Stepper|Number Row|Card Footer/)) k.push('step');
 if(has(/Save Chip/)) k.push('save');
 if(has(/Editor\/Result/)||/成功|结果面板|已发布|已提交/.test(fn)) k.push('publish');
 if(/离开|放弃|仍要返回|未保存/.test(fn)) k.push('leave');
 if(/罗盘|compass/i.test(fn)) k.push('compass');
 if(/地图|选点|map/i.test(fn)) k.push('map');
 if(has(/Toast/)) k.push('toast');
 if(/加载中|skeleton|骨架|生成中|检查中|加载更多/i.test(fn)) k.push('load');
 if(has(/Seam/)) k.push('seam');
 if(/上传|封面|cover/i.test(fn)) k.push('upload');
 if(/滑块|slider|比例/i.test(fn)) k.push('slider');
 if(/名称|标题|字数/.test(fn)&&has(/Field/)) k.push('counter');
 return [...new Set(k)];
}
const keepA=(arr,re)=>arr.filter(a=>!re.test(a.labelMarkdown||a.label||'')).map(a=>{const o={}; if(a.labelMarkdown) o.labelMarkdown=a.labelMarkdown; else if(a.label) o.label=a.label; if(a.categoryId) o.categoryId=a.categoryId; if(a.properties&&a.properties.length) o.properties=a.properties; return o;});
function annotate(node,md,cat,re){ node.annotations=[...keepA(node.annotations,re),{labelMarkdown:md,categoryId:cat}]; }
const SKIP_SEC=/组件|素材|asset|G6|component|F\/G/i;
const FRAMES=[]; for(const s of PG.children){ if(s.type!=='SECTION'||SKIP_SEC.test(s.name)) continue; for(const f of s.children) if(f.type==='FRAME'&&!/^(note|label)/.test(f.name)&&f.width>=360&&f.height>=480) FRAMES.push(f); }
function motionPass(SPECIAL){ let n=0; for(const f of FRAMES){ const lines=[...(SPECIAL[f.id]||[]),...kinds(f).map(k=>ROW[k])]; annotate(f,'**Motion · 动效与触感 (CF-64)**\n'+lines.map(l=>'- '+l).join('\n')+'\n\n'+RMX,CAT_I,/^\*\*Motion/); n++; } return n; }
async function setT(t,s){ if(t.characters===s) return false; try{ for(const seg of t.getStyledTextSegments(['fontName'])) await figma.loadFontAsync(seg.fontName); t.characters=s; return true;}catch(e){ return false; } }
function copyRule(c,id){ let s=c;
 let m;
 if((m=s.match(/^网络暂时不可用，(.+)$/))){ s=(/内容已保留/.test(m[1]))?'网络没连上，'+m[1]:'网络没连上，请重试'; }
 else if(s==='网络暂时不可用') s='网络没连上';
 else if((m=s.match(/^(.+)加载失败，请重试$/))) s=(id&&/;280:503$/.test(id))?'网络没连上，请重试':m[1]+'没加载出来，请重试';
 else if(/^.+加载失败$/.test(s)) s=s.replace(/加载失败$/,'没加载出来');
 if(s==='重新加载') s='重试'; if(s==='去登录') s='登录'; if(s==='确定') s='完成';
 if(/任务完成[!！]$/.test(s)) s=s.replace(/[!！]$/,'');
 if(s.length>1&&/[^…：（「(:]…$/.test(s)) s=s.slice(0,-1);
 if(s.length>3&&/[^.：（「(:]\.\.\.$/.test(s)) s=s.slice(0,-3);
 return s; }
async function copyPass(){ const ch=[]; for(const f of FRAMES) for(const t of f.findAllWithCriteria({types:['TEXT']})){ const s=copyRule(t.characters,t.id); if(s!==t.characters){ const old=t.characters; if(await setT(t,s)) ch.push(t.id+' '+old.slice(0,16)+'→'+s.slice(0,16)); } } return ch; }
const EO={type:'CUSTOM_CUBIC_BEZIER',easingFunctionCubicBezier:{x1:.22,y1:.61,x2:.36,y2:1}};
const SPR=(k,d)=>({type:'CUSTOM_SPRING',easingFunctionSpring:{mass:1,stiffness:k,damping:d}});
const SA=(d,e=EO)=>({type:'SMART_ANIMATE',easing:e,duration:d});
const PUSH=(d=0.35)=>({type:'PUSH',direction:'LEFT',matchLayers:false,easing:EO,duration:d});
async function link(node,trigger,dest,trans,nav='NAVIGATE'){ if(!node) return 'nonode>'+dest; const keep=node.reactions.filter(x=>!(x.trigger&&x.trigger.type===trigger.type)).map(x=>({trigger:x.trigger,actions:x.actions})); await node.setReactionsAsync([...keep,{trigger,actions:[{type:'NODE',destinationId:dest,navigation:nav,transition:trans,resetScrollPosition:false}]}]); return node.id+'>'+dest; }
function flows(list){ const ex=PG.flowStartingPoints.filter(f=>!f.name.startsWith('F · ')).map(f=>({nodeId:f.nodeId,name:f.name})); const have=new Set(ex.map(f=>f.nodeId)); const add=[]; for(const f of list) if(!have.has(f.nodeId)){ have.add(f.nodeId); add.push(f);} PG.flowStartingPoints=[...ex,...add]; return {kept:ex.length,added:add.length}; }
const byId=id=>figma.getNodeByIdAsync(id);
const inst=(f,re,i=0)=>f.findAllWithCriteria({types:['INSTANCE']}).filter(n=>re.test(n.name))[i]||null;
const out={errors:[]};
const ink3v=await figma.variables.getVariableByIdAsync('VariableID:7:14');
function fgSection(){ let s=PG.children.find(c=>c.type==='SECTION'&&/^F\/G ·/.test(c.name)); if(s) return s; let maxY=0; for(const c of PG.children) maxY=Math.max(maxY,c.y+c.height); s=figma.createSection(); PG.appendChild(s); s.name='F/G · 动效原型与无障碍证明 (config batches F, G)'; s.x=0; s.y=maxY+240; s.resizeWithoutConstraints(1200,1240); return s; }
const FG=fgSection(); let slot=FG.children.filter(c=>c.type==='FRAME').length;
async function place(node,label){ const ex=FG.children.find(c=>c.type==='FRAME'&&c.name===node.name&&c!==node); if(ex){ node.remove(); return ex; } FG.appendChild(node); node.x=80+slot*513; node.y=120; const t=figma.createText(); FG.appendChild(t); t.fontName={family:'SF Pro',style:'Medium'}; t.fontSize=13; t.characters=label; t.x=node.x; t.y=92; t.fills=[{type:'SOLID',color:{r:.25,g:.25,b:.25}}]; t.name='label · '+label.slice(0,30); slot++; const w=80+slot*513+40; if(w>FG.width) FG.resizeWithoutConstraints(w,FG.height); return node; }
async function loadFonts(root){ const fs=new Set(); for(const t of root.findAllWithCriteria({types:['TEXT']})) for(const s of t.getStyledTextSegments(['fontName'])) fs.add(JSON.stringify(s.fontName)); for(const f of fs){ try{ await figma.loadFontAsync(JSON.parse(f)); }catch(e){} } }
async function xxl(srcId,name){ const src=await byId(srcId); if(FG.children.some(c=>c.name===name)) return FG.children.find(c=>c.name===name); const cl=src.clone(); cl.name=name; if(cl.height>852) cl.resize(393,852); cl.clipsContent=true; await loadFonts(cl); const r={txt:0,stack:0,wrap:0,bar:0};
 for(const t of cl.findAllWithCriteria({types:['TEXT']})){ try{ if(typeof t.fontSize==='number'){ t.fontSize=Math.round(t.fontSize*1.35); } else { for(const s of t.getStyledTextSegments(['fontSize'])) t.setRangeFontSize(s.start,s.end,Math.round(s.fontSize*1.35)); } if(t.lineHeight&&t.lineHeight.unit==='PIXELS') t.lineHeight={unit:'PIXELS',value:Math.round(t.lineHeight.value*1.35)}; if(t.textTruncation&&t.textTruncation!=='DISABLED') t.textTruncation='DISABLED'; if(t.maxLines) t.maxLines=null; r.txt++; }catch(e){} }
 for(const f of cl.findAll(n=>n.type==='FRAME'&&n.layoutMode==='HORIZONTAL'&&n.children.length===2&&n.children.every(c=>c.type!=='TEXT'&&c.width>=120))){ try{ f.layoutMode='VERTICAL'; f.itemSpacing=Math.max(f.itemSpacing,8); for(const c of f.children){ try{ c.layoutSizingHorizontal='FILL'; }catch(e){} } r.stack++; }catch(e){} }
 for(const f of cl.findAll(n=>n.type==='FRAME'&&n.layoutMode==='HORIZONTAL'&&n.children.length>=3&&n.width>=280&&n.children.every(c=>c.height<=48))){ try{ f.layoutWrap='WRAP'; f.counterAxisSpacing=8; r.wrap++; }catch(e){} }
 for(const t of cl.findAllWithCriteria({types:['TEXT']})){ try{ const p=t.parent; if(p&&p.layoutMode==='VERTICAL'&&t.textAutoResize==='WIDTH_AND_HEIGHT'){ t.layoutSizingHorizontal='FILL'; t.textAutoResize='HEIGHT'; } }catch(e){} }
 const bb=cl.findAllWithCriteria({types:['INSTANCE']}).find(i=>/Bottom Bar/.test(i.name)); if(bb){ const set={}; for(const k in bb.componentProperties){ if(/^showMiddle/.test(k)) set[k]=false; if(/^showLeft/.test(k)) set[k]=true; if(/^left/.test(k)&&bb.componentProperties[k].type==='TEXT') set[k]='⋯'; } try{ bb.setProperties(set); r.bar=1; }catch(e){ r.barErr=e.message; } }
 cl.annotations=[{labelMarkdown:'**Dynamic Type proof (CF-67)** · text at xxxLarge ×1.35 (accessibility sizes behave the same way, larger). Two-column grids stack to one column; chip rows wrap; labels wrap to two lines instead of truncating; the bottom bar keeps the primary full width and moves 保存草稿 / 预览 into 「⋯」. Content scrolls; 44 pt minimums use @ScaledMetric. SwiftUI: ViewThatFits / dynamicTypeSize.isAccessibilitySize.',categoryId:CAT_A}];
 await place(cl,'XXL · '+src.name.slice(0,40)); r.id=cl.id; return r; }
const CD=await byId('290:20572'); const CDV=CD.type==='COMPONENT_SET'?(CD.children.find(c=>/Destructive=true/.test(c.name))||CD.children[0]):CD;
async function discard(srcId,name){ if(FG.children.some(c=>c.name===name)) return FG.children.find(c=>c.name===name).id; const src=await byId(srcId); const cl=src.clone(); cl.name=name; cl.annotations=[]; const sc=figma.createRectangle(); cl.appendChild(sc); sc.name='scrim · 20%'; sc.resize(cl.width,cl.height); sc.x=0; sc.y=0; sc.fills=[{type:'SOLID',color:{r:0,g:0,b:0},opacity:0.2}];
 const d=CDV.createInstance(); cl.appendChild(d); d.name='Editor/Confirm Dialog · 放弃修改 (CF-77)'; const set={}; for(const [k,v] of Object.entries(d.componentProperties)){ if(v.type==='TEXT'){ if(/^title/.test(k)) set[k]='要放弃这次修改吗？'; else if(/^message/.test(k)) set[k]='刚才的改动还没保存。'; else if(/^action2/.test(k)) set[k]=''; else if(/^action/.test(k)) set[k]='放弃修改'; else if(/^cancel/.test(k)) set[k]='继续编辑'; } if(v.type==='BOOLEAN'&&/^showAction2/.test(k)) set[k]=false; if(v.type==='VARIANT'&&/Destructive/.test(k)) set[k]='true'; } try{ d.setProperties(set);}catch(e){ out.errors.push('cd '+e.message); }
 d.x=Math.round((cl.width-d.width)/2); d.y=d.width>=340?Math.round(Math.min(cl.height,852)-d.height-34):Math.round((Math.min(cl.height,852)-d.height)/2);
 cl.annotations=[{labelMarkdown:'**Unsaved changes (CF-77)** · ✕ or swipe-down on a dirty sheet: the sheet rubber-bands and this action sheet appears · 放弃修改 (red, discards and closes) / 继续编辑 (default) · haptic .warning · SwiftUI .interactiveDismissDisabled(isDirty) + .confirmationDialog',categoryId:CAT_I}];
 await place(cl,'CF-77 放弃修改 · '+src.name.slice(0,34)); const hd=src.findAllWithCriteria({types:['INSTANCE']}).find(i=>/Sheet Header/.test(i.name)); if(hd) await link(hd,{type:'ON_CLICK'},cl.id,{type:'DISSOLVE',easing:{type:'EASE_OUT'},duration:0.2}); return cl.id; }
function moveTo(n,target){ const a=n.absoluteBoundingBox, b=target.absoluteBoundingBox; n.x+=b.x-a.x; n.y+=b.y-a.y; }
async function addLine(slotN){ const par=slotN.parent; for(const o of par.children.filter(c=>c.name==='Editor/Drop Line · 落点'&&Math.abs(c.y-(slotN.y+slotN.height/2-4))<2)) o.remove(); const d=(await byId('330:911')).createInstance(); par.appendChild(d); d.name='Editor/Drop Line · 落点'; if(par.layoutMode&&par.layoutMode!=='NONE') d.layoutPositioning='ABSOLUTE'; d.resize(slotN.width,8); d.x=slotN.x; d.y=Math.round(slotN.y+slotN.height/2-4); return d.id; }
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
