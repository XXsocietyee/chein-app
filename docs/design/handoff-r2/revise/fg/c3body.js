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
