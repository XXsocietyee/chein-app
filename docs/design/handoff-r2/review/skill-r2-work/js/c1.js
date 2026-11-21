const PAGE='237:14642', IDS=['239:31923','237:31646','238:20393','249:16773'], SECS=['246:5535'], SCALE=0.72;
const pg=await figma.getNodeByIdAsync(PAGE); await figma.setCurrentPageAsync(pg);
const out={page:pg.name.slice(0,24)};
const topFrame=n=>{ let p=n; while(p.parent&&p.parent.type!=='SECTION'&&p.parent.type!=='PAGE') p=p.parent; return p; };
const vis=n=>{ let p=n; let g=0; while(p&&p.type!=='PAGE'&&g++<40){ if(p.visible===false) return false; p=p.parent; } return true; };
const tx=pg.findAllWithCriteria({types:['TEXT']}); const sizes={}; let unst=0, n=0; const coll=[], small=[];
for(const t of tx){ const fs=typeof t.fontSize==='number'?t.fontSize:-1; if(!t.id.includes(';')){ n++; sizes[fs]=(sizes[fs]||0)+1; if(!t.textStyleId) unst++; }
 if(fs>0&&fs<11&&small.length<8&&vis(t)){ small.push(`${fs}|${t.characters.slice(0,10)}|${topFrame(t).id}`); }
 if(t.width<=6&&t.characters.trim().length>=2&&vis(t)){ const f=topFrame(t); coll.push(`${f.id}|${f.name.slice(0,16)}|${t.characters.slice(0,10)}`); } }
out.text={n,unst,sizes:Object.entries(sizes).sort((a,b)=>b[1]-a[1]).slice(0,12).map(([k,v])=>k+':'+v).join(' ')}; out.small=small; out.collapsedN=coll.length; out.collapsed=coll.slice(0,16);
const cnt={}; let ni=0;
for(const i of pg.findAllWithCriteria({types:['INSTANCE']})){ if(i.id.includes(';')) continue; if(ni++>6000) break; const m=await i.getMainComponentAsync(); if(!m) continue; const nm=m.parent&&m.parent.type==='COMPONENT_SET'?m.parent.name:m.name; cnt[nm]=(cnt[nm]||0)+1; }
out.instances=Object.entries(cnt).sort((a,b)=>b[1]-a[1]).slice(0,28).map(([k,v])=>`${k}:${v}`).join(' | ');
const frames=pg.findAll(x=>x.type==='FRAME'&&x.parent.type==='SECTION'); out.frames=frames.length; out.opt=frames.filter(f=>/优化/.test(f.name)).length; out.dev=frames.filter(f=>f.devStatus&&f.devStatus.type==='READY_FOR_DEV').length;
let ease={}, trig={};
for(const x of pg.findAll(x=>'reactions' in x&&x.reactions&&x.reactions.length>0)){ for(const r of x.reactions){ const tt=r.trigger?r.trigger.type:'?'; trig[tt]=(trig[tt]||0)+1; for(const a of (r.actions&&r.actions.length?r.actions:(r.action?[r.action]:[]))){ if(a&&a.transition){ const e=a.transition.easing?a.transition.easing.type:'none'; ease[e]=(ease[e]||0)+1; } } } }
out.proto={ease,trig};
const shots=[];
for(const id of IDS){ const f=await figma.getNodeByIdAsync(id); if(f&&f.type!=='PAGE'){ shots.push(f); } else out['missing_'+id]=1; }
for(const sid of SECS){ const s=await figma.getNodeByIdAsync(sid); if(!s) continue; const fr=s.children.filter(c=>c.type==='FRAME'&&c.width<500&&c.height>=600&&!/^note/.test(c.name)); if(!fr.length) continue; fr.sort((a,b)=>{ const pa=a.id.split(':').map(Number), pb=b.id.split(':').map(Number); return pb[0]-pa[0]||pb[1]-pa[1]; }); const o=fr.find(f=>/优化/.test(f.name)); shots.push(o||fr[0]); }
out.shots=[];
for(const f of shots){ out.shots.push(`${f.id}|${f.name.slice(0,44)}|${Math.round(f.width)}x${Math.round(f.height)}`); await f.screenshot({scale:f.height>1400?SCALE*0.7:SCALE}); }
return out;
