// 06-R1-PL10 · page R1 · item 5.5 (PL-10): old-kit twins → Player/* instances (Button, State, Toast, Status Tag). DRY=true reports what would change.
const PG=await goPage('169:3833');
const FR=['169:3833','169:4120','169:6068','169:6155','169:9621','169:9760','169:9899','169:9973'];
const PB=await byId('285:20238'), PST=await byId('285:20260'), PTO=await byId('285:20279'), PSTATE=await byId('287:506');
const KEEP=/^(Player|Icon|Club|Editor|Merchant|Badge|Wizard|Member|Roam|G6|OPT|R6|System)\b|status ?bar|Status Bar|Home Indicator|Tab Bar|Nav Bar|Keyboard|Map|map/i;
const txtOf=n=>texts(n).filter(t=>t.visible&&t.characters.trim()).map(t=>t.characters.trim());
function kindOf(n){ const s=solidOf(n)||(()=>{ const k=n.findAll(x=>'fills' in x&&solidOf(x)&&x.width>=n.width*0.8)[0]; return k?solidOf(k):null; })(); if(!s) return 'Text'; const L=lum(s); return L>0.6?'Primary':'Secondary'; }
function stateKind(ts){ const s=ts.join(' '); if(/网络|连不上|离线|offline/i.test(s)) return 'Offline'; if(/权限|定位|相机|允许/.test(s)) return 'Permission'; if(/失败|出错|没加载|错误/.test(s)) return 'Error'; if(/加载中|正在/.test(s)) return 'Loading'; return 'Empty'; }
const plan=[];
for(const fid of FR){ const F=await byId(fid); if(!F){ plan.push({fid,missing:true}); continue; }
  for(const n of F.findAll(x=>(x.type==='INSTANCE'||x.type==='FRAME')&&!insideInstance(x,F))){ if(n===F) continue; let mc=null, nm=n.name;
    if(n.type==='INSTANCE'){ mc=await topMain(n); nm=mc?mc.name:n.name; if(KEEP.test(nm)) continue; }
    const ts=txtOf(n); let to=null;
    if(/button|btn|pill|Button|Pill/.test(nm)&&ts.length>=1&&(n.type==='INSTANCE'?ts.length<=2:ts.length===1)&&n.height>=28&&n.height<=60){ to={c:'Player/Button',Kind:kindOf(n),Size:n.height>=50?'52':'44',label:ts[0]}; }
    else if(n.type==='INSTANCE'&&/(^|\/)(State|Empty|Error)\b|K\/State/.test(nm)){ to={c:'Player/State',Kind:stateKind(ts),texts:ts}; }
    else if(n.type==='INSTANCE'&&/Toast/i.test(nm)){ to={c:'Player/Toast',text:ts.join(' ')}; }
    else if(n.type==='INSTANCE'&&/(^|\/)(Tag|Chip|Badge Status|Status)\b/.test(nm)&&ts.length===1&&n.height<=32){ to={c:'Player/Status Tag',text:ts[0]}; }
    if(to) plan.push({fid,id:n.id,type:n.type,from:nm,h:Math.round(n.height),w:Math.round(n.width),...to}); } }
R.info.plan=plan;
if(DRY) return R;
const pk=(set,base)=>keyOf(set,base);
const done=[];
for(const p of plan){ if(p.missing) continue; const n=await byId(p.id); if(!n||n.removed) continue; try{
  let inst=null;
  if(p.c==='Player/Button'){ const v=variant(PB,{Kind:p.Kind,Size:p.Size,State:'Default'})||variant(PB,{Kind:p.Kind})||PB.defaultVariant; inst=v.createInstance(); const lk=Object.keys(inst.componentProperties).find(k=>inst.componentProperties[k].type==='TEXT'); if(lk) inst.setProperties({[lk]:p.label}); else { const t=texts(inst)[0]; if(t) await setT(t,p.label); } replaceAt(n,inst,{keepW:p.w>=200}); }
  else if(p.c==='Player/State'){ const v=variant(PSTATE,{Kind:p.Kind})||variant(PSTATE,{State:p.Kind})||PSTATE.defaultVariant; inst=v.createInstance(); const tks=Object.keys(inst.componentProperties).filter(k=>inst.componentProperties[k].type==='TEXT'); const vals={}; tks.forEach((k,i)=>{ if(p.texts[i]) vals[k]=p.texts[i]; }); if(Object.keys(vals).length) inst.setProperties(vals); replaceAt(n,inst,{keepW:true}); }
  else if(p.c==='Player/Toast'){ const v=PTO.type==='COMPONENT_SET'?(variant(PTO,{Kind:'Info'})||variant(PTO,{Type:'Info'})||PTO.defaultVariant):PTO; inst=v.createInstance(); const tk=Object.keys(inst.componentProperties).find(k=>inst.componentProperties[k].type==='TEXT'); if(tk) inst.setProperties({[tk]:p.text}); replaceAt(n,inst,{center:true}); }
  else if(p.c==='Player/Status Tag'){ const v=PST.type==='COMPONENT_SET'?(variant(PST,{State:'Neutral'})||variant(PST,{Kind:'Neutral'})||PST.defaultVariant):PST; inst=v.createInstance(); const tk=Object.keys(inst.componentProperties).find(k=>inst.componentProperties[k].type==='TEXT'); if(tk) inst.setProperties({[tk]:p.text}); replaceAt(n,inst,{}); }
  if(inst){ inst.name=p.c; R.created.push(inst.id); done.push(p.id+' → '+p.c+(p.Kind?' '+p.Kind:'')); }
 }catch(e){ R.warn.push(p.id+': '+String(e).slice(0,120)); } }
for(const fid of FR){ const F=await byId(fid); if(F) FIXED(F,'5.5','Old-kit buttons, states, toasts and tags swapped to Player/* (PL-10).'); }
R.info.done=done; R.info.plan=plan.length;
return R;
