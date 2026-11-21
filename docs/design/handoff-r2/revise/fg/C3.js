const PG=await figma.getNodeByIdAsync('235:13237'); await figma.setCurrentPageAsync(PG);
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
// ---- copy
out.copy=await copyPass();
// ---- CF-66
const bad=await figma.variables.getVariableByIdAsync('VariableID:7:23');
const lum=c=>{const f=v=>v<=0.03928?v/12.92:Math.pow((v+0.055)/1.055,2.4);return 0.2126*f(c.r)+0.7152*f(c.g)+0.0722*f(c.b);};
function solidAnc(n){ let a=n.parent; while(a&&a.type!=='SECTION'&&a.type!=='PAGE'){ if('fills' in a&&Array.isArray(a.fills)){ const s=a.fills.filter(f=>f.visible!==false&&f.type==='SOLID'&&(f.opacity??1)>0.9).pop(); if(s) return {a,c:s.color}; if(a.fills.some(f=>f.type==='IMAGE')) return null; } a=a.parent; } return null; }
const isRed=c=>Math.abs(c.r-0.898)<0.03&&Math.abs(c.g-0.282)<0.04&&Math.abs(c.b-0.302)<0.04;
const isGrey4d=c=>Math.abs(c.r-0.302)<0.02&&Math.abs(c.g-0.302)<0.02&&Math.abs(c.b-0.302)<0.02;
const cf66=[];
for(const f of FRAMES) for(const t of f.findAllWithCriteria({types:['TEXT']})){ if(typeof t.fills==='symbol'||!t.fills.length||t.fills[0].type!=='SOLID') continue; const fc=t.fills[0].color; const bg=solidAnc(t); if(!bg) continue;
 if(isRed(fc)&&lum(bg.c)<0.1){ if(isGrey4d(bg.c)){ const p=bg.a.fills.map(x=>x.type==='SOLID'&&isGrey4d(x.color)?{type:'SOLID',color:{r:.173,g:.173,b:.18}}:x); try{ bg.a.fills=p; }catch(e){} } t.fills=[{type:'SOLID',color:{r:1,g:0.42,b:0.42}}]; cf66.push(t.id); }
 else if(fc.r>0.95&&fc.g>0.95&&isRed(bg.c)){ bg.a.fills=[figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:.70,g:.15,b:.12}},'color',bad)]; cf66.push('bg '+bg.a.id); } }
const ph=await byId('243:26338'); if(ph&&ph.type==='TEXT'){ ph.fills=[{type:'SOLID',color:{r:.69,g:.69,b:.69}}]; cf66.push(ph.id); }
for(const id of ['322:18311']){ const t=await byId(id); if(t){ const bg=solidAnc(t); if(bg&&isGrey4d(bg.c)){ bg.a.fills=bg.a.fills.map(x=>x.type==='SOLID'&&isGrey4d(x.color)?{type:'SOLID',color:{r:.173,g:.173,b:.18}}:x); cf66.push('bg '+bg.a.id); } } }
out.cf66=cf66;
// ---- motion (specials for step bar / AI / install)
const SPECIAL={};
for(const f of FRAMES){ const names=f.findAllWithCriteria({types:['INSTANCE']}).map(i=>i.name); const l=[];
 if(names.some(n=>/Step Bar/.test(n))) l.push('Step change (CF-58): content slides 350 ms ease-out (.22,.61,.36,1); the step segment fills 220 ms · no haptic');
 if(names.some(n=>/AI Draft Card/.test(n))||/AI|起草|生成/.test(f.name)) l.push('AI draft (CF-59): generating = shimmer loop (stops under Reduce Motion); stations appear staggered 60 ms, 220 ms fade-up · .success when ready, .error on failure');
 if(/确认导入|确认更新|安装/.test(f.name)) l.push('Install (CF-62): the confirm pill fills left-to-right as progress, then the game row slides into the library (220 ms ease-out) · .success');
 if(/左滑|删除确认/.test(f.name)) l.push('Swipe to delete: row follows the finger, red 删除 revealed at 88 pt; full swipe deletes with collapse 180 ms · .impact(.rigid); confirm dialog for games with saves');
 if(l.length) SPECIAL[f.id]=l; }
out.motion=motionPass(SPECIAL);
// ---- CF-68 targeted
const a11y=[];
const ai=await byId('239:24018'); if(ai){ const sb=ai.findAll(n=>(n.type==='INSTANCE'||n.type==='FRAME')&&/send|发送|arrow|submit/i.test(n.name)&&n.width<=60).pop(); annotate(sb||ai,'**VoiceOver (CF-68)** · send button = 「发送」; while generating it becomes 「停止生成」',CAT_A,/^\*\*VoiceOver/); a11y.push((sb||ai).id+' '+(sb?sb.name:'frame')); }
const sh=await byId('244:16367'); if(sh){ const s2=sh.findAll(n=>(n.type==='INSTANCE'||n.type==='FRAME')&&/share|分享/i.test(n.name)&&n.width<=60).pop(); annotate(s2||sh,'**VoiceOver (CF-68)** · share icon = 「分享」 (opens the system share sheet)',CAT_A,/^\*\*VoiceOver/); a11y.push((s2||sh).id+' '+(s2?s2.name:'frame')); }
const lib=await byId('247:17370'); if(lib){ const plus=lib.findAll(n=>(n.type==='INSTANCE'||n.type==='FRAME')&&/plus|＋|add|more|⋯/i.test(n.name)&&n.width<=60); for(const p of plus.slice(0,2)){ annotate(p,'**VoiceOver (CF-68)** · '+(/more|⋯/i.test(p.name)?'「更多」 (提交审核, 我的提交)':'「导入游戏」 (链接导入, 扫码导入, 从文件导入)'),CAT_A,/^\*\*VoiceOver/); a11y.push(p.id+' '+p.name); } }
out.a11y=a11y;
// ---- prototype: jump to first error
const s1=await byId('237:59431'); const bb=s1?s1.findAllWithCriteria({types:['INSTANCE']}).find(i=>/Bottom Bar/.test(i.name)):null;
out.links=[await link(bb,{type:'ON_CLICK'},'237:59532',SA(0.3))];
out.flows=flows([{nodeId:'237:59431',name:'F · 跳到第一个错误 · 发布活动 (CF-17)'}]);
// ---- CF-77 frame
out.d=[await discard('247:17464','CF-77 · 导入外部游戏 · 放弃修改')];
out.fg=FG.id+' '+Math.round(FG.y)+' '+Math.round(FG.width)+'x'+Math.round(FG.height);
return out;
