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
function copyRule(c){ let s=c;
 if(/^.+加载失败，请重试$/.test(s)) s='网络没连上，请重试';
 else if(/^网络暂时不可用/.test(s)) s='网络没连上，请重试';
 else if(/^.+加载失败$/.test(s)) s=s.replace(/加载失败$/,'没加载出来');
 if(s==='重新加载') s='重试'; if(s==='去登录') s='登录'; if(s==='确定') s='完成';
 if(/任务完成[!！]$/.test(s)) s=s.replace(/[!！]$/,'');
 if(s.length>1&&/[^…：（「(:]…$/.test(s)) s=s.slice(0,-1);
 if(s.length>3&&/[^.：（「(:]\.\.\.$/.test(s)) s=s.slice(0,-3);
 return s; }
async function copyPass(){ const ch=[]; for(const f of FRAMES) for(const t of f.findAllWithCriteria({types:['TEXT']})){ const s=copyRule(t.characters); if(s!==t.characters){ const old=t.characters; if(await setT(t,s)) ch.push(t.id+' '+old.slice(0,16)+'→'+s.slice(0,16)); } } return ch; }
const EO={type:'CUSTOM_CUBIC_BEZIER',easingFunctionCubicBezier:{x1:.22,y1:.61,x2:.36,y2:1}};
const SPR=(k,d)=>({type:'CUSTOM_SPRING',easingFunctionSpring:{mass:1,stiffness:k,damping:d}});
const SA=(d,e=EO)=>({type:'SMART_ANIMATE',easing:e,duration:d});
const PUSH=(d=0.35)=>({type:'PUSH',direction:'LEFT',matchLayers:false,easing:EO,duration:d});
async function link(node,trigger,dest,trans,nav='NAVIGATE'){ if(!node) return 'nonode>'+dest; const keep=node.reactions.filter(x=>!(x.trigger&&x.trigger.type===trigger.type)).map(x=>({trigger:x.trigger,actions:x.actions})); await node.setReactionsAsync([...keep,{trigger,actions:[{type:'NODE',destinationId:dest,navigation:nav,transition:trans,resetScrollPosition:false}]}]); return node.id+'>'+dest; }
function flows(list){ const ex=PG.flowStartingPoints.filter(f=>!f.name.startsWith('F · ')).map(f=>({nodeId:f.nodeId,name:f.name})); const have=new Set(ex.map(f=>f.nodeId)); const add=[]; for(const f of list) if(!have.has(f.nodeId)){ have.add(f.nodeId); add.push(f);} PG.flowStartingPoints=[...ex,...add]; return {kept:ex.length,added:add.length}; }
const byId=id=>figma.getNodeByIdAsync(id);
const inst=(f,re,i=0)=>f.findAllWithCriteria({types:['INSTANCE']}).filter(n=>re.test(n.name))[i]||null;
const out={errors:[]};
// ---- CF-75 popup previews
const POP=['238:11777','238:11850','238:11923','238:11999','238:12075','238:12156'];
const STY=['星尘','纸本','末世','夜城'];
const W=(o)=>({type:'SOLID',color:{r:1,g:1,b:1},opacity:o});
out.pop=[];
for(let i=0;i<POP.length;i++){ const F=await byId(POP[i]); const ctrl=F.children.find(c=>c.name==='preview controls');
 const title=F.children.find(c=>c.type==='TEXT'&&/ · /.test(c.characters)); const selStyle=title?title.characters.split(' · ')[0]:'纸本';
 let cols=[]; let selCol=0;
 if(ctrl){ const ells=ctrl.findAll(n=>n.type==='ELLIPSE'); cols=ells.map(e=>({fill:JSON.parse(JSON.stringify(e.fills)),name:(e.parent.children.find(c=>c.type==='TEXT')||{characters:''}).characters, sel:(e.strokes&&e.strokes.length>0)||(e.parent.strokes&&e.parent.strokes.length>0)})); const k=cols.findIndex(c=>c.sel); selCol=k>=0?k:0; ctrl.remove(); }
 const oldStrip=F.children.find(c=>/^preview strip/.test(c.name)); if(!cols.length&&oldStrip){ cols=oldStrip.children.filter(h=>/^color · /.test(h.name)).map(h=>{const e=h.children[0]; return {fill:JSON.parse(JSON.stringify(e.fills)),name:h.name.replace(/^color · /,'').replace(' (选中)',''),sel:/选中/.test(h.name)};}); const k=cols.findIndex(c=>c.sel); selCol=k>=0?k:0; }
 for(const c of F.children.filter(c=>/^preview (strip|dots)/.test(c.name))) c.remove();
 const card=F.children.find(c=>/^pop-up card/.test(c.name))||F.children.filter(c=>c.type==='FRAME'&&!/close|status/.test(c.name)).sort((a,b)=>b.width*b.height-a.width*a.height)[0];
 if(card) card.y=Math.round(410-card.height/2);
 const strip=figma.createAutoLayout('HORIZONTAL',{name:'preview strip · 风格 + 配色 (CF-75)',itemSpacing:4}); F.appendChild(strip);
 strip.fills=[W(0.12)]; strip.cornerRadius=26; strip.paddingLeft=strip.paddingRight=10; strip.paddingTop=strip.paddingBottom=4; strip.counterAxisAlignItems='CENTER'; strip.clipsContent=true;
 for(const s of STY){ const on=s===selStyle; const p=figma.createAutoLayout('HORIZONTAL',{name:'style · '+s+(on?' (选中)':'')}); strip.appendChild(p); p.fills=[W(on?1:0.14)]; p.cornerRadius=18; p.paddingLeft=p.paddingRight=10; p.primaryAxisAlignItems='CENTER'; p.counterAxisAlignItems='CENTER'; 
  const t=figma.createText(); p.appendChild(t); t.fontName={family:'SF Pro',style:'Medium'}; t.fontSize=13; t.characters=s; t.fills=[{type:'SOLID',color:on?{r:0,g:0,b:0}:{r:1,g:1,b:1}}]; p.counterAxisSizingMode='FIXED'; p.resize(p.width,36); p.primaryAxisSizingMode='AUTO'; p.minWidth=44; }
 const dv=figma.createRectangle(); strip.appendChild(dv); dv.resize(1,24); dv.fills=[W(0.3)]; dv.name='divider';
 cols.forEach((c,j)=>{ const h=figma.createFrame(); strip.appendChild(h); h.name='color · '+c.name+(j===selCol?' (选中)':''); h.resize(40,44); h.fills=[]; const e=figma.createEllipse(); h.appendChild(e); e.resize(26,26); e.x=7; e.y=9; e.fills=c.fill; if(j===selCol){ e.strokes=[{type:'SOLID',color:{r:1,g:1,b:1}}]; e.strokeWeight=2; e.strokeAlign='OUTSIDE'; } else { e.strokes=[W(0.35)]; e.strokeWeight=1; e.strokeAlign='INSIDE'; } });
 strip.primaryAxisSizingMode='FIXED'; strip.resize(361,52); strip.x=16; strip.y=852-34-52-6;
 const dots=figma.createAutoLayout('HORIZONTAL',{name:'preview dots · 阶段 '+(i+1)+'/6',itemSpacing:8}); F.appendChild(dots); dots.fills=[];
 for(let j=0;j<6;j++){ const d=figma.createEllipse(); dots.appendChild(d); d.resize(6,6); d.fills=[W(j===i?1:0.35)]; d.name='dot '+(j+1); }
 dots.x=Math.round((393-dots.width)/2); dots.y=strip.y-20;
 out.pop.push(F.id+' style='+selStyle+' cols='+cols.length+' sel='+selCol+' card='+(card&&card.id));
}
for(let i=0;i<POP.length;i++){ const F=await byId(POP[i]); await link(F,{type:'ON_DRAG'},POP[(i+1)%POP.length],PUSH()); }
// 章节闸 copy
const cg=await byId('249:35830'); if(cg&&cg.type==='TEXT') await setT(cg,'第一章 · 共三章');
// ---- CF-66: 系统键盘 labels → ink-2
const ink2=await figma.variables.getVariableByIdAsync('VariableID:7:13'); let kb=0;
for(const f of FRAMES) for(const t of f.findAllWithCriteria({types:['TEXT']})) if(t.characters==='系统键盘'){ t.fills=[figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:.25,g:.25,b:.25}},'color',ink2)]; kb++; }
out.kb=kb;
// ---- copy pass
out.copy=await copyPass();
// ---- motion annotations
const POPMD=['Popup preview (CF-75): 阶段 is a swipe pager (TabView(.page)); page slide 350 ms ease-out (.22,.61,.36,1); the popup replays its entrance on each page (scale .92 → 1 + fade, spring(.38, .86)) · no haptic','Bottom strip (风格 | 配色): selection cross-fade 140 ms · .selection; the strip scrolls sideways; every target 44 pt'];
const SPECIAL={}; for(const id of POP) SPECIAL[id]=POPMD;
SPECIAL['249:35825']=['Chapter gate (player): card fades up 24 pt, spring(response .42, damping .8); the three progress segments fill 220 ms in turn; tap anywhere continues (轻点继续) · no haptic; Reduce Motion: fade only'];
out.motion=motionPass(SPECIAL);
// ---- CF-68 / CF-74 targeted annotations
const a11y=[]; const B2=await byId('237:31646'); const seg=inst(B2,/Segment/); if(seg){ annotate(seg,'**VoiceOver (CF-68)** · segmented 「显示方式」, values 列表 / 地图; the chosen one has trait .isSelected',CAT_A,/^\*\*VoiceOver/); a11y.push(seg.id); }
for(const id of ['237:51859','237:65700','237:51424']){ const f=await byId(id); const sm=inst(f,/Seam/); if(sm){ annotate(sm,'**VoiceOver (CF-68)** · seam ＋ = 「在这里插入」; expanded tiles read their block type (文字, 图片, 节点 …)',CAT_A,/^\*\*VoiceOver/); a11y.push(sm.id); } }
for(const id of ['237:31986','237:67490']){ const f=await byId(id); const h=inst(f,/Handle|Chapter Card|List Item/); if(h){ annotate(h,'**VoiceOver (CF-68)** · handle = 「调整顺序」 with actions 「上移」 「下移」; ⋯ = 「更多操作」; while dragging the row announces 「移到第 N 位」',CAT_A,/^\*\*VoiceOver/); a11y.push(h.id);} }
for(const id of ['239:33463','239:33587']){ const f=await byId(id); if(f){ annotate(f,'**Keyboard (CF-74)** · the sheet sits on the keyboard and grows with the text (.height(200) → .large); the 完成 pill stays visible above the keyboard; Return inserts a line in 剧情 / 描述, and commits in 名称',CAT_D,/^\*\*Keyboard/); a11y.push(f.id);} }
out.a11y=a11y;
// page components (C1-local)
const pc={'290:23460':'VoiceOver (CF-68): seam ＋ = 「在这里插入」; tiles read the block type. Motion: expand height + fade 220 ms ease-out · .selection.','290:23403':'VoiceOver (CF-68): card = chapter name + summary; ⋯ = 「更多操作」; handle = 「调整顺序」 (actions 上移 / 下移). Motion: see Editor/List Item (CF-60).','290:23581':'VoiceOver (CF-68): the sentence is read as one element; unset tokens read 「未设置」; ⋯ = 「更多操作」; handle = 「调整顺序」.','290:23583':'VoiceOver (CF-68): 「搜索地点」 search field.','290:23587':'VoiceOver (CF-68): 「定位到我」. Haptic .impact(.light) when the map recentres.','290:23504':'VoiceOver (CF-68): label = gameplay name, value = 已设置 / 未设置 / 有错误.','290:23405':'VoiceOver (CF-68): label = block type.'};
out.pc=[]; for(const [id,t] of Object.entries(pc)){ const n=await byId(id); if(n&&(n.type==='COMPONENT'||n.type==='COMPONENT_SET')){ let d=n.description||''; const i=d.indexOf('\n\n— F/G'); if(i>=0) d=d.slice(0,i); n.description=d+'\n\n— F/G —\n'+t; out.pc.push(id);} }
// ---- prototypes (CF-64 most-seen)
const L=[];
L.push(await link(await byId('249:40292'),{type:'ON_DRAG'},'239:24873',SA(0.38,SPR(290,27))));
L.push(await link(await byId('239:24873'),{type:'ON_DRAG'},'249:40292',SA(0.38,SPR(290,27))));
const B7=await byId('239:31923'); const t7=B7.findAllWithCriteria({types:['TEXT']}).find(t=>t.characters==='画面风格'); let row=t7; while(row&&row.parent!==B7&&!(row.type==='INSTANCE'&&/Row/.test(row.name))) row=row.parent;
L.push(await link(row&&row!==B7?row:null,{type:'ON_CLICK'},'241:1680',PUSH()));
const B72=await byId('241:1680'); const hd=inst(B72,/Sheet Header/); if(hd){ await hd.setReactionsAsync([{trigger:{type:'ON_CLICK'},actions:[{type:'BACK'}]}]); L.push(hd.id+'>BACK'); }
L.push(await link(inst(await byId('238:10642'),/Add Row/),{type:'ON_CLICK'},'238:10960',SA(0.22)));
L.push(await link(inst(await byId('237:31646'),/Chapter Card/,1),{type:'MOUSE_DOWN',delay:0.18},'237:31986',SA(0.14)));
L.push(await link(inst(await byId('237:65700'),/Seam/),{type:'ON_CLICK'},'237:51859',SA(0.22)));
out.links=L;
out.flows=flows([{nodeId:'249:40292',name:'F · 抽屉高度 · 章节设置 (§3)'},{nodeId:'239:31923',name:'F · 推入子页 · 主题详情 → 画面风格'},{nodeId:'238:10642',name:'F · 添加一行 · 分支'},{nodeId:'237:31646',name:'F · 拖动排序 · 章节 (CF-60)'},{nodeId:'237:65700',name:'F · 展开插入缝 · 故事流'},{nodeId:'238:11777',name:'F · 弹窗预览 (CF-75)'}]);
return out;
