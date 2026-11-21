const PG=await figma.getNodeByIdAsync('6:3'); await figma.setCurrentPageAsync(PG);
const out={desc:[],errors:[]};
const MK='\n\n— F/G (config batches F, G · 2026-11-16) —\n';
async function D(id,txt){ const n=await figma.getNodeByIdAsync(id); if(!n){out.errors.push('miss '+id);return;} if(n.type!=='COMPONENT'&&n.type!=='COMPONENT_SET'){out.errors.push('type '+id+' '+n.type);return;} let d=n.description||''; const i=d.indexOf(MK); if(i>=0) d=d.slice(0,i); n.description=d+MK+txt; out.desc.push(id+' '+n.name); }
const RM='Interruptible: a tap or scroll jumps to the end state. Reduce Motion: springs become 200 ms cross-fades, loops and shimmer stop, haptics stay.';
await D('276:638','Motion: inline error text fades in 140 ms, border → red 140 ms; haptic .error once per submit. Counter rolls (numericText) and turns red at the limit; haptic .warning once at the limit.\nKeyboard (CF-74): number fields use the number pad with a 完成 accessory; Return moves to the next field (.submitLabel(.next)); on the last item of a list editor Return adds a new item and focuses it (Reminders-style); the sheet 完成 pill stays visible above the keyboard (ToolbarItemGroup(placement: .keyboard)).\nVoiceOver: label = field label; value = text or 「未填写」; error is read as the hint. '+RM);
await D('276:739','Motion: system menu. VoiceOver: label = field label, value = current choice, trait button. '+RM);
await D('276:302','Motion/haptic: system Toggle. VoiceOver: system switch (label from the row).');
await D('278:311','Motion: fields revealed by the switch expand (height + fade) 220 ms ease-out; hide 180 ms. Haptic: none beyond the system switch. VoiceOver: one element, label = label, hint = sub. '+RM);
await D('278:407','Motion: tap pushes the sub-page inside the sheet (slide 350 ms ease-out, no haptic). VoiceOver: label = label, value = grey value, trait button; red dot is read as 「未完成」. '+RM);
await D('278:435','Motion: selection border + check cross-fade 140 ms; haptic .selection. VoiceOver: trait .isSelected on the chosen row.');
await D('278:345','Motion: number rolls 140 ms (contentTransition(.numericText())). Haptic: system. VoiceOver: one adjustable element (accessibilityAdjustableAction) with label from the row and the value; − / ＋ read 「减少」 「增加」.');
await D('278:458','Reorder (CF-60): lift = long-press 180 ms on the row or immediate on the handle; row scales 1.03, shadow 0 8 24 rgba(0,0,0,.14), 140 ms ease-out; haptic .impact(.medium). Move: neighbours slide spring(response .32, damping .82); Editor/Drop Line (2 pt) marks the slot; haptic .selection on each slot change. Drop: spring(response .28, damping .78), shadow fades 140 ms; haptic .impact(.light). Auto-scroll within 60 pt of an edge. Cancel: returns 220 ms, no haptic. Figma: Rest → Lifted → Moved, Smart Animate spring 300/26/1.\nRemove: collapse + fade 180 ms, undo toast; haptic .impact(.rigid).\nVoiceOver: ⋯ = 「更多操作」 (上移, 下移, 复制, 删除); handle = 「调整顺序」 with accessibilityAction(named: 「上移」/「下移」). '+RM);
await D('278:467','Motion: the new row expands from 0 height 220 ms, then focuses its first field; haptic .impact(.light). Limit state: no toast, the count shows N/N. VoiceOver: label 「添加…」 without the ellipsis, e.g. 「添加选项」; at the limit the hint says 「已达上限」.');
await D('276:307','VoiceOver: label 「调整顺序」, actions 「上移」 「下移」. 44 × 44 target. Motion and haptics: see Editor/List Item (CF-60).');
await D('280:410','VoiceOver: ✕ = 「关闭」 (when the sheet is dirty, ✕ and swipe-down show the 放弃修改 / 继续编辑 action sheet; haptic .warning), ‹ = 「返回」, 完成 = 「完成」. Title is a header trait. Push inside the sheet: slide 350 ms ease-out, no haptic.');
await D('280:465','Detents spring(response 0.38, dampingFraction 0.86); present ≈350 ms, dismiss 280 ms; content-height change uses the same spring, fields fade in 180 ms starting 60 ms after the height moves. Haptic .selection when a drag settles on a new detent; none on programmatic growth. '+RM);
await D('280:479','Motion: rises 12 pt + fade 220 ms, stays 2 s, leaves 180 ms. Used only for results of an action elsewhere (never validation or limits). VoiceOver: posted as an announcement; the undo action is reachable via the rotor. '+RM);
await D('280:527','Motion: Loading = skeleton shimmer 1.2 s loop (stops under Reduce Motion); content replaces it with a 180 ms fade. Error copy (CF-70): title 「<对象>没加载出来」, body 「网络没连上，请重试」, button 「重试」. VoiceOver: title is a header; the whole state is one element plus the button.');
await D('280:585','VoiceOver: ‹ = 「返回」, ⋯ = 「更多」, title is a header trait.');
await D('280:593','Motion: press scale .97 80 ms, release 120 ms. Primary is never disabled: with missing data it scrolls to the first error 300 ms, shakes it 3 × 6 pt in 240 ms, haptic .error. Dynamic Type (CF-67): at accessibility sizes the primary stays full width and 保存草稿 / 预览 move into a 「⋯」 secondary beside it. '+RM);
await D('290:20194','Motion: 已存 ↔ 同步中: ↑ arrow, then ✓ draws 220 ms; no haptic (frequent). VoiceOver: label 「保存状态」, value = the state word.');
await D('290:20206','Motion: selection cross-fade 140 ms, haptic .selection. VoiceOver: label = name, trait .isSelected.');
await D('290:20217','Motion: ring cross-fade 140 ms, haptic .selection. VoiceOver: label = colour name (e.g. 「蓝」), trait .isSelected.');
await D('290:20572','Use for CF-77 (unsaved sheet): destructive 「放弃修改」 + 「继续编辑」, haptic .warning when it appears. VoiceOver: focus moves to the dialog title.');
await D('290:20551','Motion: result card rises 24 pt + fade, spring(response .42, damping .8); success haptic .success. Reduce Motion: fade only.');
await D('290:22148','Motion: result card rises 24 pt + fade, spring(response .42, damping .8); success haptic .success. Reduce Motion: fade only.');
await D('290:22102','VoiceOver: the leading control reads 「正确答案，已选中」 / 「设为正确答案」; the option text is the label; collapsed options expose 「展开」.');
await D('290:22123','VoiceOver: label = tool name + state (「已添加」 / 「不可用」); a blocked chip opens its Editor/Popover reason. Motion: fill cross-fade 140 ms, haptic .selection.');
await D('290:16299','Motion: tap scrolls to the card 300 ms ease-out; current item indicator slides 220 ms; haptic .selection. VoiceOver: tab bar trait; error items read 「有错误」.');
await D('290:16320','Motion: expand/collapse height + fade 220 ms ease-out (hide 180 ms). VoiceOver: header button with value 「已收起」/「已展开」; summary is the hint.');
await D('290:6017','Motion: step change slides 350 ms ease-out (.22,.61,.36,1); segment fills 220 ms. VoiceOver: 「第 N 步，共 3 步」.');
await D('291:57324','Motion: Generating = shimmer loop (stops under Reduce Motion); Ready = stations appear staggered 60 ms each, 220 ms fade-up. Haptic .success on Ready, .error on Failed.');
await D('290:22166','Motion: selection cross-fade 140 ms, haptic .selection. VoiceOver: label + trait .isSelected.');
// Drop Line
const sec=await figma.getNodeByIdAsync('276:295');
let dl=sec.findOne(n=>n.type==='COMPONENT'&&n.name==='Editor/Drop Line');
const ink=await figma.variables.getVariableByIdAsync('VariableID:7:12');
const P=()=>figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:0,g:0,b:0}},'color',ink);
if(!dl){ dl=figma.createComponent(); sec.appendChild(dl); dl.name='Editor/Drop Line'; dl.resize(361,8); dl.fills=[];
 const e=figma.createEllipse(); dl.appendChild(e); e.resize(8,8); e.x=0;e.y=0; e.fills=[{type:'SOLID',color:{r:1,g:1,b:1}}]; e.strokes=[P()]; e.strokeWeight=2; e.strokeAlign='INSIDE'; e.name='dot';
 const r=figma.createRectangle(); dl.appendChild(r); r.resize(353,2); r.x=8; r.y=3; r.fills=[P()]; r.name='line'; r.constraints={horizontal:'STRETCH',vertical:'CENTER'};
 let maxY=0; for(const c of sec.children) if(c!==dl) maxY=Math.max(maxY,c.y+c.height); dl.x=40; dl.y=maxY+60; if(dl.y+dl.height+60>sec.height) sec.resizeWithoutConstraints(sec.width,dl.y+dl.height+80); }
dl.description='CF-60 insertion line: 2 pt black line with a leading ring, shown at the landing slot while a row is lifted. Width follows the list (constraints stretch). Appears with a 140 ms fade; moves with the slot spring(response .32, damping .82); haptic .selection each time the slot changes. VoiceOver: not an element (the moving row announces 「移到第 N 位」).';
out.dropLine=dl.id;
// List Item Lifted
const li=await figma.getNodeByIdAsync('278:458'); out.liType=li.type;
const lifted=li.type==='COMPONENT_SET'?li.children.find(c=>/Lifted/.test(c.name)):null;
if(lifted){ out.liftedBefore={fx:lifted.effects.map(e=>e.type+':'+(e.radius||'')+':'+(e.offset?e.offset.y:'')+':'+(e.color?e.color.a.toFixed(2):'')), strokes:lifted.strokes.length, sw:lifted.strokeWeight};
 lifted.effects=[{type:'DROP_SHADOW',color:{r:0,g:0,b:0,a:0.14},offset:{x:0,y:8},radius:24,spread:0,visible:true,blendMode:'NORMAL'}];
 if(lifted.strokes.length&&lifted.strokes[0].type==='SOLID'&&lifted.strokes[0].color.r<0.2) lifted.strokes=[]; out.lifted=lifted.id; }
// kit annotation on Editor/Field (CF-74)
const fld=await figma.getNodeByIdAsync('276:638');
try{ const keep=(fld.annotations||[]).filter(a=>!((a.labelMarkdown||a.label||'').startsWith('**Keyboard'))); fld.annotations=[...keep,{labelMarkdown:'**Keyboard (CF-74)** · number fields → number pad + 完成 accessory · Return → next field (`.submitLabel(.next)`, `.onSubmit`) · last list item: Return adds a new item · sheet 完成 pill stays above the keyboard',categoryId:'164:0'}]; out.anno='ok'; }catch(e){ out.anno='fail '+e.message; }
out.tag=PG.findAllWithCriteria({types:['COMPONENT']}).filter(c=>/(^|\/|\b)(tag|tags|标签)\b/i.test(c.name)&&c.width<=32).slice(0,8).map(c=>c.id+' '+c.name);
out.slider=PG.findAllWithCriteria({types:['COMPONENT','COMPONENT_SET']}).filter(c=>/slider|滑块/i.test(c.name)).slice(0,5).map(c=>c.id+' '+c.name);
out.icon9=['9:5','9:19','9:73','9:75'].map(i=>i);
return out;
