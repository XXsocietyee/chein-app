const out={};
const SWset=await figma.getNodeByIdAsync('276:302'); const SWon=SWset.children.find(c=>c.name==='State=On');
const HANDLE=await figma.getNodeByIdAsync('276:307');
function ROW(name,w,o={}){ const f=AL('HORIZONTAL',name,{gap:o.gap??12,pad:o.pad||[8,0,8,0],fill:o.fill,r:o.r}); SEC.appendChild(f); f.resize(w,44); f.primaryAxisSizingMode='FIXED'; f.counterAxisSizingMode='AUTO'; f.minHeight=o.minH||44; return f; }
// ---- Switch Row
{ const f=ROW('Editor/Switch Row',329); const col=AL('VERTICAL','text',{gap:2,align:'MIN'}); add(f,col,'FILL'); await T(col,'开关','MP/body','ink',{name:'label',fill:true}); await T(col,'打开后会怎样（一行）','MP/label','ink-3',{name:'sub',fill:true});
  const s=SWon.createInstance(); f.appendChild(s); s.name='switch'; const c=MK(f); s.isExposedInstance=true;
  c.description='Switch row (CF-14): label, optional one-line footnote saying what "on" does, native switch. Min height 44. The nested switch is exposed: set its State on the instance.';
  PROP(c,'label','TEXT','开关','label','characters'); PROP(c,'sub','TEXT','打开后会怎样（一行）','sub','characters'); PROP(c,'showSub','BOOLEAN',false,'sub','visible'); out.switchRow=c.id; }
// ---- Stepper
const steps=[]; for(const st of ['Default','AtMin','AtMax']){ const f=AL('HORIZONTAL',`State=${st}`,{gap:0}); SEC.appendChild(f);
  for(const [nm,ic] of [['minus','minus'],['value',null],['plus','plus']]){ if(!ic){ const t=await T(f,'3','MP/body-strong','ink',{name:'value',align:'CENTER'}); t.textAutoResize='HEIGHT'; t.resize(32,t.height); continue; }
    const h=AL('HORIZONTAL',nm,{justify:'CENTER'}); f.appendChild(h); h.resize(44,44); h.primaryAxisSizingMode='FIXED'; h.counterAxisSizingMode='FIXED';
    const c=AL('HORIZONTAL','circle 32',{justify:'CENTER',fill:'mp/btn-secondary',r:16}); h.appendChild(c); c.resize(32,32); c.primaryAxisSizingMode='FIXED'; c.counterAxisSizingMode='FIXED';
    const dis=(st==='AtMin'&&nm==='minus')||(st==='AtMax'&&nm==='plus'); I(c,ic,16,dis?'mp/disabled':'ink','glyph'); }
  steps.push(MK(f)); }
const STP=SET(steps,'Editor/Stepper','One stepper (CF-15, ref 7): value between the buttons, 32 pt circles inside 44×44 hit areas. Use for small ranges (1–10); larger ranges use Editor/Field Kind=Number with a unit suffix. SwiftUI: native Stepper.');
PROP(STP,'value','TEXT','3','value','characters'); out.stepper=STP.id; const STPdef=STP.children[0];
// ---- Row (picker cell)
const rows=[]; for(const acc of ['Chevron','PopUp','Switch','Stepper','None']){ const f=ROW(`Accessory=${acc}`,361,{gap:10,pad:[6,16,6,16],minH:50,fill:'surface'});
  I(f,'flag',20,'ink-2','icon'); await T(f,'设置项','MP/body','ink',{name:'label'}); const d=figma.createEllipse(); d.name='dot'; d.resize(6,6); F(d,'bad'); f.appendChild(d); SP(f);
  const v=await T(f,'未设置','MP/body',acc==='PopUp'?'ink-2':'ink-3',{name:'value',trunc:true}); v.textAutoResize='WIDTH_AND_HEIGHT';
  if(acc==='Chevron') I(f,'chev',14,'ink-3','chevron'); if(acc==='PopUp') I(f,'down',12,'ink-3','chevron');
  if(acc==='Switch'){ const s=SWon.createInstance(); f.appendChild(s); s.name='switch'; } if(acc==='Stepper'){ const s=STPdef.createInstance(); f.appendChild(s); s.name='stepper'; }
  const dv=figma.createRectangle(); dv.name='divider'; f.appendChild(dv); dv.layoutPositioning='ABSOLUTE'; dv.resize(329,0.5); dv.x=16; dv.y=f.height-0.5; dv.constraints={horizontal:'STRETCH',vertical:'MAX'}; F(dv,'sep');
  const c=MK(f); for(const n of c.findAll(n=>n.name==='switch'||n.name==='stepper')) n.isExposedInstance=true; rows.push(c); }
const ROWS=SET(rows,'Editor/Row','Settings / picker cell (CF-26, CF-27, ref 6): icon, label, red dot when required and empty, current value in grey, accessory. No verb pills. Grouped inset list inside a white card; min height 50 (mp/cell-min-h). Accessory=PopUp opens a native menu; Chevron pushes a sub-page.',1);
PROP(ROWS,'label','TEXT','设置项','label','characters'); PROP(ROWS,'value','TEXT','未设置','value','characters'); PROP(ROWS,'showValue','BOOLEAN',true,'value','visible');
PROP(ROWS,'showIcon','BOOLEAN',false,'icon','visible'); { const k=ROWS.addComponentProperty('icon','INSTANCE_SWAP',(await figma.getNodeByIdAsync('9:73')).id); for(const v of ROWS.children) v.findAll(n=>n.name==='icon').forEach(n=>n.componentPropertyReferences={...(n.componentPropertyReferences||{}),mainComponent:k}); }
PROP(ROWS,'showDot','BOOLEAN',false,'dot','visible'); PROP(ROWS,'showDivider','BOOLEAN',true,'divider','visible'); out.row=ROWS.id;
// ---- Option Row
const opts=[]; for(const style of ['List','Card']) for(const sel of ['true','false']){
  const f= style==='List'? ROW(`Style=${style}, Selected=${sel}`,361,{gap:12,pad:[10,16,10,16],minH:50,fill:'surface'}) : ROW(`Style=${style}, Selected=${sel}`,329,{gap:12,pad:[12,14,12,14],minH:56,fill:'surface',r:'mp/radius-md'});
  const col=AL('VERTICAL','text',{gap:2,align:'MIN'}); add(f,col,'FILL'); await T(col,'选项','MP/body-strong','ink',{name:'label',fill:true}); await T(col,'一行说明','MP/label','ink-3',{name:'sub',fill:true});
  if(style==='List'){ const ck=I(f,'check',18,'ink','check'); if(sel==='false') ck.opacity=0; }
  else { if(sel==='true'){ S(f,'ink',1.5); I(f,'check-c',22,'ink','check'); } else { S(f,'sep',1); const sp=figma.createFrame(); sp.name='check slot'; sp.fills=[]; sp.resize(22,22); f.appendChild(sp); } }
  opts.push(MK(f)); }
const OPT=SET(opts,'Editor/Option Row','Choice row (CF-34, section 2). Style=List: multi- or single-select list row with a trailing check mark. Style=Card: visual choice card; selected = 1.5 px black border + filled black check. No radios, no square checkboxes, no green tint.',2);
PROP(OPT,'label','TEXT','选项','label','characters'); PROP(OPT,'sub','TEXT','一行说明','sub','characters'); PROP(OPT,'showSub','BOOLEAN',true,'sub','visible'); out.option=OPT.id;
// ---- List Item header
const lis=[]; for(const st of ['Default','Lifted']){ const f=ROW(`State=${st}`,329,{gap:4,pad:[0,0,0,14],fill: st==='Lifted'?'surface':null, r: st==='Lifted'?'mp/radius-md':null}); f.minHeight=44;
  if(st==='Lifted') f.effects=[{type:'DROP_SHADOW',color:{r:0,g:0,b:0,a:0.14},offset:{x:0,y:6},radius:18,spread:0,visible:true,blendMode:'NORMAL'}];
  const t=await T(f,'选项 1','MP/body-strong','ink',{name:'title',trunc:true}); t.layoutSizingHorizontal='FILL'; await T(f,'已设置','MP/label','ink-3',{name:'meta'});
  const m=AL('HORIZONTAL','more ⋯',{justify:'CENTER'}); f.appendChild(m); m.resize(44,44); m.primaryAxisSizingMode='FIXED'; m.counterAxisSizingMode='FIXED'; I(m,'more',20,'ink-2','glyph');
  const h=HANDLE.createInstance(); f.appendChild(h); h.name='handle'; lis.push(MK(f)); }
const LI=SET(lis,'Editor/List Item','List item header (CF-33): title · meta · "⋯" pull-down (上移 / 下移 / 复制 / 删除 red last) · trailing drag handle. Swipe-to-delete is the shortcut. Content of the item sits below in a #F3F4F4 panel with OnGrey fields. Lifted = while dragging.');
PROP(LI,'title','TEXT','选项 1','title','characters'); PROP(LI,'meta','TEXT','已设置','meta','characters'); PROP(LI,'showMeta','BOOLEAN',false,'meta','visible'); PROP(LI,'showMore','BOOLEAN',true,'more ⋯','visible'); PROP(LI,'showHandle','BOOLEAN',true,'handle','visible'); out.listItem=LI.id;
// ---- Add Row
const ars=[]; for(const st of ['Default','Limit']){ const f=ROW(`State=${st}`,329,{gap:6,pad:[0,14,0,14],r:'mp/radius-md'}); f.primaryAxisAlignItems='CENTER'; f.counterAxisSizingMode='FIXED'; f.resize(329,44); S(f,'sep-strong',1,[4,3]);
  await T(f,'＋ 添加','MP/body-strong',st==='Limit'?'mp/disabled':'ink-2',{name:'label'}); await T(f,'12/12','MP/label','ink-3',{name:'count'}); ars.push(MK(f)); }
const AR=SET(ars,'Editor/Add Row','One dashed add row, 44 high, at the end of its list (section 2). Limit: greyed with the count (12/12) instead of a toast (CF-16).');
PROP(AR,'label','TEXT','＋ 添加','label','characters'); PROP(AR,'count','TEXT','12/12','count','characters'); PROP(AR,'showCount','BOOLEAN',false,'count','visible'); out.addRow=AR.id;
return out;
