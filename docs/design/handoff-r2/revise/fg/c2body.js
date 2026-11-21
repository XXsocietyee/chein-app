const sec=await byId('238:25434');
// ---- A12 nav on 3 / 3b / 3c
const navSrc=await byId('238:25437'); const navFix=[];
for(const id of ['238:25538','238:25573','238:25615']){ const F=await byId(id); if(!F.children.some(c=>/Nav Bar/.test(c.name))){ const n=navSrc.clone(); const si=F.children.findIndex(c=>c.name==='scrim'); F.insertChild(si>=0?si:F.children.length,n); n.x=0; n.y=0; for(const c of F.children.filter(c=>/^exit/.test(c.name))) c.remove(); for(const c of F.children) if((c.name==='progress'||c.name==='step body')&&c.y<108) c.y+=48; navFix.push(id); } }
out.navFix=navFix;
// 任务完成!
const tdone=await byId('238:25757'); if(tdone&&tdone.type==='TEXT') await setT(tdone,'任务完成');
// ---- in-between frames
function labelOf(F){ return sec.children.find(c=>c.type==='TEXT'&&Math.abs(c.x-F.x)<2&&c.y<F.y); }
async function between(srcId,name){ const src=await byId(srcId); let ex=sec.children.find(c=>c.type==='FRAME'&&c.name===name); if(ex) return ex; const cl=src.clone(); cl.name=name; const x0=src.x+513; for(const c of sec.children) if(c!==cl&&c.x>=x0-1) c.x+=513; cl.x=x0; cl.y=src.y; const lb=labelOf(src); if(lb){ const l2=lb.clone(); sec.appendChild(l2); l2.x=x0; await setT(l2,name);} sec.resizeWithoutConstraints(sec.width+513,sec.height); return cl; }
const P1=await between('238:25538','A12.3· 答题按下（过渡帧 · in-between）');
const P2=await between('238:25573','A12.3b· 对勾绘制中（过渡帧 · in-between）');
const P3=await between('238:25761','A12.5· 奖章放大中（过渡帧 · in-between）');
out.P=[P1.id,P2.id,P3.id];
// P1: pressed tile
const tiles=P1.findAll(n=>(n.type==='FRAME'||n.type==='INSTANCE')&&/option|选项|answer|答案|tile/i.test(n.name)&&n.width>120&&n.height>=36&&n.height<=120);
out.p1tiles=tiles.slice(0,4).map(n=>n.id+' '+n.name+' '+Math.round(n.width)+'x'+Math.round(n.height));
if(tiles.length){ const t=tiles[Math.min(1,tiles.length-1)]; if(t&&!/按下/.test(t.name)){ const cx=t.x+t.width/2, cy=t.y+t.height/2; try{ t.rescale(0.97); if(!(t.parent.layoutMode&&t.parent.layoutMode!=='NONE')){ t.x=cx-t.width/2; t.y=cy-t.height/2; } t.name=t.name+' · 按下 .97'; }catch(e){ out.errors.push('p1 '+e.message);} } }
// P2: verdict overlay mid-rise
const vo=P2.children.find(c=>c.name==='verdict overlay'); if(vo&&!/rising/.test(vo.name)){ vo.y+=24; vo.opacity=0.55; vo.name='verdict overlay · rising'; const ck=vo.findOne(n=>/check|✓|对勾|success|icon/i.test(n.name)); if(ck){ ck.opacity=0.4; out.p2check=ck.id+' '+ck.name; } }
const sc=P2.children.find(c=>c.name==='scrim'); if(sc) sc.opacity=0.6;
// P3: medal mid-scale
const body3=P3.children.find(c=>c.name==='step body'); let medal=body3?body3.findOne(n=>/medal|勋章|奖章|badge|reward|奖励图/i.test(n.name)&&n.width>=40&&n.width<=240):null;
if(!medal&&body3) medal=body3.findOne(n=>n.type!=='TEXT'&&'fills' in n&&Array.isArray(n.fills)&&n.fills.some(f=>f.type==='IMAGE')&&n.width>=40&&n.width<=240);
if(medal&&!/mid/.test(medal.name)){ const cx=medal.x+medal.width/2, cy=medal.y+medal.height/2; try{ medal.rescale(0.6); if(!(medal.parent.layoutMode&&medal.parent.layoutMode!=='NONE')){ medal.x=cx-medal.width/2; medal.y=cy-medal.height/2; } medal.opacity=0.5; medal.name=medal.name+' · mid .6'; out.medal=medal.id+' '+medal.name; }catch(e){ out.errors.push('p3 '+e.message);} } else out.medal='none';
// ---- A12 links
const L=[]; const STAMP={type:'CUSTOM_CUBIC_BEZIER',easingFunctionCubicBezier:{x1:.2,y1:1.4,x2:.5,y2:1}};
for(const [a,b] of [['238:25435','238:25485'],['238:25485','238:25538']]){ const F=await byId(a); L.push(await link(F,{type:'ON_CLICK'},b,PUSH())); L.push(await link(F,{type:'ON_DRAG'},b,PUSH())); }
L.push(await link(await byId('238:25538'),{type:'ON_CLICK'},P1.id,SA(0.08,{type:'EASE_OUT'})));
L.push(await link(P1,{type:'AFTER_TIMEOUT',timeout:0.08},P2.id,SA(0.22,{type:'EASE_OUT'})));
L.push(await link(P2,{type:'AFTER_TIMEOUT',timeout:0.05},'238:25573',SA(0.42,SPR(224,24))));
L.push(await link(await byId('238:25573'),{type:'ON_CLICK'},'238:25709',PUSH()));
L.push(await link(await byId('238:25615'),{type:'ON_CLICK'},'238:25538',{type:'DISSOLVE',easing:{type:'EASE_OUT'},duration:0.24}));
L.push(await link(await byId('238:25654'),{type:'ON_CLICK'},'238:25709',PUSH()));
L.push(await link(await byId('238:25709'),{type:'ON_CLICK'},P3.id,PUSH()));
try{ L.push(await link(P3,{type:'AFTER_TIMEOUT',timeout:0.05},'238:25761',SA(0.6,STAMP))); }catch(e){ L.push(await link(P3,{type:'AFTER_TIMEOUT',timeout:0.05},'238:25761',SA(0.6,{type:'EASE_OUT_BACK'}))); out.errors.push('stamp bezier → EASE_OUT_BACK'); }
L.push(await link(await byId('238:25761'),{type:'ON_CLICK'},'238:25435',{type:'DISSOLVE',easing:{type:'EASE_OUT'},duration:0.3}));
out.links=L;
// ---- CF-60 drag unify + drop line
const DL=await byId('330:911'); const STD=[{type:'DROP_SHADOW',color:{r:0,g:0,b:0,a:0.14},offset:{x:0,y:8},radius:24,spread:0,visible:true,blendMode:'NORMAL'}];
out.drag=[];
for(const [fid,lid] of [['239:19592','239:19634'],['241:21572','241:21657'],['237:33756','237:33800'],['237:42181','237:42237'],['237:50816','237:50911']]){ const F=await byId(fid); const n=await byId(lid); if(!n){ out.errors.push('drag miss '+lid); continue; }
 n.effects=STD; if(n.strokes&&n.strokes.length&&n.strokes[0].type==='SOLID'&&n.strokes[0].color.r<0.2&&n.strokes[0].color.g<0.2) n.strokes=[];
 const par=n.parent; for(const o of par.children.filter(c=>/^Editor\/Drop Line · 落点/.test(c.name))) o.remove();
 const sibs=par.children.filter(c=>c!==n&&c.visible&&c.height>=30&&!/hairline|divider|title|header|label/i.test(c.name));
 let tgt=sibs.find(c=>/第 1 步/.test(c.name)); if(!tgt){ const idx=par.children.indexOf(n); const before=par.children.slice(0,idx).filter(c=>sibs.includes(c)); tgt=before[before.length-1]||sibs[0]; }
 if(!tgt) continue; const d=DL.createInstance(); par.appendChild(d); d.name='Editor/Drop Line · 落点'; if(par.layoutMode&&par.layoutMode!=='NONE') d.layoutPositioning='ABSOLUTE'; d.resize(tgt.width,8); d.x=tgt.x; d.y=tgt.y-6; out.drag.push(fid+' lifted '+lid+' line above '+tgt.name.slice(0,20)); }
// ---- CF-66
const ink=await figma.variables.getVariableByIdAsync('VariableID:7:12'); const ink3=await figma.variables.getVariableByIdAsync('VariableID:7:14'); const okV=await figma.variables.getVariableByIdAsync('VariableID:7:19');
const BP=(v,c)=>figma.variables.setBoundVariableForPaint({type:'SOLID',color:c},'color',v);
const lum=c=>{const f=v=>v<=0.03928?v/12.92:Math.pow((v+0.055)/1.055,2.4);return 0.2126*f(c.r)+0.7152*f(c.g)+0.0722*f(c.b);};
const wr=await byId('238:25705'); if(wr) wr.fills=[{type:'SOLID',color:{r:1,g:0.42,b:0.42}}];
const ap=await byId('241:21009'); if(ap) ap.fills=[BP(ink,{r:0,g:0,b:0})];
let un=0; for(const id of ['237:73731','237:73983','237:74256']){ const F=await byId(id); for(const t of F.findAllWithCriteria({types:['TEXT']})){ if(typeof t.fills==='symbol'||!t.fills.length||t.fills[0].type!=='SOLID') continue; const L0=lum(t.fills[0].color)*(t.fills[0].opacity??1)+(1-(t.fills[0].opacity??1)); if(L0>0.262&&L0<0.85){ t.fills=[BP(ink3,{r:.42,g:.42,b:.42})]; un++; } } }
out.unavail=un;
const fs=await byId('239:22803'); const yb=fs?fs.findAllWithCriteria({types:['TEXT']}).filter(t=>/已标好/.test(t.characters)):[]; out.ybh=[];
for(const t of yb){ const par=t.parent; if(par.children.some(c=>/icon\/check · status/.test(c.name))) continue; const ic=(await byId('9:39')).createInstance(); ic.name='icon/check · status'; ic.resize(14,14); const g=ic.findOne(n=>n.type==='TEXT'); if(g){ g.fontSize=12; g.fills=[BP(okV,{r:.04,g:.48,b:.34})]; } if(par.layoutMode&&par.layoutMode!=='NONE'){ par.insertChild(par.children.indexOf(t),ic); } else { par.appendChild(ic); ic.x=t.x; ic.y=t.y+(t.height-14)/2; t.x+=18; } out.ybh.push(t.id); }
const sk=await byId('237:72184'); if(sk){ const p=sk.parent; out.sikan={text:JSON.stringify(sk.boundVariables||{}).slice(0,80), par:p.name+' '+JSON.stringify(p.boundVariables||{}).slice(0,120)}; }
// ---- CF-71
const c71=[]; for(const f of FRAMES) for(const t of f.findAllWithCriteria({types:['TEXT']})){ const c=t.characters;
 if(/（从上到下就是答案）/.test(c)){ await setT(t,c.replace('（从上到下就是答案）','')); c71.push(t.id+' strip'); }
 else if(/^选项 · 点圆圈设为正确答案$/.test(c)){ await setT(t,'选项'); c71.push(t.id+' 选项'); }
 else if(/^10% ?至 ?90%，默认 ?45%$/.test(c)||/^20–100，步长 ?5$/.test(c)||/^0 表示不限，最多 10 次$/.test(c)){ c71.push(t.id+' rm '+c); t.remove(); } }
out.c71=c71;
const rf=[]; for(const id of ['237:14274','237:43689']){ const F=await byId(id); const nums=F.findAllWithCriteria({types:['TEXT']}).filter(t=>/^[1-3１-３①-③][\.、．]?\s/.test(t.characters)||/^[①②③]/.test(t.characters)); rf.push(id+': '+nums.map(t=>t.id+' "'+t.characters.slice(0,22)+'" par='+t.parent.id).join(' | ')); }
out.resultLines=rf;
// ---- CF-73 covers + chip icon
const ab=await byId('284:63794'); const routeImg=ab?ab.findAll(n=>'fills' in n&&Array.isArray(n.fills)&&n.fills.some(f=>f.type==='IMAGE')).map(n=>({n,name:n.name})):[];
out.assets=routeImg.map(r=>r.n.id+' '+r.name).slice(0,12);
const rc=routeImg.find(r=>/route|路线|city|城市/i.test(r.name)); let cov=[];
if(rc){ const img=rc.n.fills.find(f=>f.type==='IMAGE'); const tf=['238:15346','238:15290','238:16088','238:16196']; const s2=await byId('239:20808'); for(const f of s2.children) if(f.type==='FRAME'&&f.width>=360) tf.push(f.id);
 for(const id of tf){ const F=await byId(id); if(!F) continue; for(const n of F.findAll(n=>(n.type==='RECTANGLE'||n.type==='FRAME')&&n.width>=40&&n.height>=40&&Array.isArray(n.fills)&&n.fills.length===1&&n.fills[0].type==='SOLID')){ const c=n.fills[0].color; if(c.b>c.r+0.12&&c.b>c.g+0.2&&c.r>0.3){ n.fills=[{type:'IMAGE',imageHash:img.imageHash,scaleMode:'FILL'}]; cov.push(id+':'+n.id); } } } }
out.covers=cov;
const tagRef=(await byId('237:43689')).findAllWithCriteria({types:['INSTANCE']}).find(i=>/tag/i.test(i.name)); out.tagRef=tagRef?tagRef.id+' '+tagRef.name:'none';
let sw=0; if(tagRef){ const tm=await tagRef.getMainComponentAsync(); for(const f of FRAMES) for(const i of f.findAllWithCriteria({types:['INSTANCE']})){ if(!/star/i.test(i.name)) continue; let a=i.parent,ok=false; for(let k=0;k<3&&a;k++,a=a.parent) if(/chip|类别|category/i.test(a.name)){ok=true;break;} if(ok&&tm){ const w=i.width,h=i.height; i.swapComponent(tm); i.resize(w,h); sw++; } } }
out.starSwap=sw;
// ---- copy + motion
out.copy=await copyPass();
const STEP='Preview step change (CF-63, game tier): horizontal slide 350 ms ease-out (.22,.61,.36,1); the five-segment progress fills 220 ms; swipe also pages; every moment is skippable by tap · no haptic';
const SPECIAL={'238:25435':[STEP,'Arrival card rises 24 pt + fade, spring(response .42, damping .8)'],'238:25485':[STEP,'Story beats reveal one by one (fade-up 12 pt, 220 ms, 120 ms apart)'],
 '238:25538':[STEP,'Answer press: tile scale .97, 80 ms · correct: border → green + check draws 220 ms · .success · wrong: tile shakes 3 × 6 pt in 240 ms · .error'],
 '238:25573':['Result card rises 24 pt + fade, spring(response .42, damping .8); check draws 220 ms · .success'],'238:25615':['Failure: tile shake 3 × 6 pt 240 ms · .error; tap 再试一次 returns to the question (dissolve 240 ms)'],
 '238:25709':[STEP,'Result card rises 24 pt + fade, spring(.42, .8); copy 任务完成 (no exclamation mark)'],'238:25761':[STEP,'Reward: medal scales .6 → 1 with the stamp curve (.2,1.4,.5,1), 600 ms; flies to its slot · .impact(.heavy) at the peak. Reduce Motion: fade only, haptic kept'],'238:25821':[STEP]};
out.motion=motionPass(SPECIAL);
const PB={[P1.id]:'In-between (CF-63): answer tile pressed at scale .97 (80 ms ease-out). Next: check draws (after 80 ms).',[P2.id]:'In-between (CF-63): result card mid-rise (+24 pt, 55% opacity), check half drawn. Spring(response .42, damping .8) to A12.3b.',[P3.id]:'In-between (CF-63): medal at scale .6, 50% opacity. Stamp curve (.2,1.4,.5,1) 600 ms to A12.5; .impact(.heavy) at the peak.'};
for(const [id,md] of Object.entries(PB)){ const n=await byId(id); n.annotations=[{labelMarkdown:'**Motion · 动效与触感 (CF-63)**\n- '+md+'\n\n'+RMX,categoryId:CAT_I}]; }
out.flows=flows([{nodeId:'238:25435',name:'F · 玩家视角预览 (CF-63)'}]);
return out;
