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
