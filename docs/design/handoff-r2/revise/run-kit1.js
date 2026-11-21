const page=await figma.getNodeByIdAsync('6:3'); await figma.setCurrentPageAsync(page);
const V={}; for(const v of await figma.variables.getLocalVariablesAsync()) if(!V[v.name]) V[v.name]=v;
const TS={}; for(const s of await figma.getLocalTextStylesAsync()) TS[s.name]=s;
for(const s of ['Regular','Medium','Semibold','Bold']) await figma.loadFontAsync({family:'SF Pro',style:s});
const P=(n,op)=>{ const p=figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:0,g:0,b:0}},'color',V[n]); return op!=null?{...p,opacity:op}:p; };
const F=(n,k,op)=>{n.fills=k?[P(k,op)]:[]; return n;};
const S=(n,k,w=1,dash)=>{n.strokes=[P(k)]; n.strokeWeight=w; n.strokeAlign='INSIDE'; if(dash) n.dashPattern=dash; return n;};
const R=(n,k)=>{ if(typeof k==='number'){n.cornerRadius=k;} else for(const c of ['topLeftRadius','topRightRadius','bottomLeftRadius','bottomRightRadius']) n.setBoundVariable(c,V[k]); return n;};
function AL(dir,name,o={}){ const f=figma.createAutoLayout(dir); f.name=name; f.fills=[]; if(o.gap!=null) f.itemSpacing=o.gap; if(o.pad){ const [t,r=t,b=t,l=r]=o.pad; f.paddingTop=t; f.paddingRight=r; f.paddingBottom=b; f.paddingLeft=l;} if(o.fill) F(f,o.fill,o.op); if(o.r!=null) R(f,o.r); f.counterAxisAlignItems=o.align||'CENTER'; if(o.justify) f.primaryAxisAlignItems=o.justify; return f; }
function add(p,c,h,v){ p.appendChild(c); if(h) c.layoutSizingHorizontal=h; if(v) c.layoutSizingVertical=v; return c; }
async function T(par,chars,style,color='ink',o={}){ const t=figma.createText(); if(par) par.appendChild(t); if(style) await t.setTextStyleIdAsync(TS[style].id); else { t.fontName={family:'SF Pro',style:o.w||'Regular'}; t.fontSize=o.size||14; if(o.lh) t.lineHeight={unit:'PIXELS',value:o.lh}; } t.characters=chars; F(t,color); t.name=o.name||'label'; if(o.fill&&par){ t.layoutSizingHorizontal='FILL'; t.textAutoResize='HEIGHT'; } if(o.align) t.textAlignHorizontal=o.align; if(o.trunc){ t.textTruncation='ENDING'; t.maxLines=1; } return t; }
const ICON={}; for(const n of page.findAllWithCriteria({types:['COMPONENT']})) if(n.name.startsWith('Icon/')) ICON[n.name.slice(5)]=n;
function I(par,name,size=20,color='ink',nm){ const i=ICON[name].createInstance(); if(par) par.appendChild(i); i.resize(size,size); const g=i.findOne(n=>n.type==='TEXT'); g.fontSize=Math.round(size*0.82); g.fills=[P(color)]; i.name=nm||('icon/'+name); return i; }
function SP(par){ const s=figma.createFrame(); s.name='spacer'; s.fills=[]; par.appendChild(s); s.resize(1,1); s.layoutSizingHorizontal='FILL'; return s; }
function hit(par,w=44,h=44,name='hit 44'){ const f=AL('HORIZONTAL',name,{justify:'CENTER'}); par.appendChild(f); f.resize(w,h); f.primaryAxisSizingMode='FIXED'; f.counterAxisSizingMode='FIXED'; return f; }
function MK(frame){ return figma.createComponentFromNode(frame); }
function SET(comps,name,desc,cols){ const s=figma.combineAsVariants(comps,SEC); s.name=name; s.description=desc||''; const g=24; let x=g,y=g,rowH=0,c=0; for(const v of s.children){ if(cols&&c===cols){ x=g; y+=rowH+g; rowH=0; c=0; } v.x=x; v.y=y; x+=v.width+g; rowH=Math.max(rowH,v.height); c++; } s.resizeWithoutConstraints(Math.max(...s.children.map(v=>v.x+v.width))+g, Math.max(...s.children.map(v=>v.y+v.height))+g); F(s,'bg'); s.cornerRadius=16; S(s,'sep',1,[6,4]); return s; }
function PROP(owner,name,type,def,nodeName,field){ const key=owner.addComponentProperty(name,type,def); const kids=owner.type==='COMPONENT_SET'?owner.children:[owner]; for(const v of kids){ v.findAll(n=>n.name===nodeName).forEach(n=>{ n.componentPropertyReferences={...(n.componentPropertyReferences||{}),[field]:key}; }); } return key; }
let SEC=page.children.find(n=>n.type==='SECTION'&&n.name.startsWith('Editor · 编辑器组件'));
if(!SEC){ SEC=figma.createSection(); page.appendChild(SEC); SEC.name='Editor · 编辑器组件 (CF-10–19 · config revision)'; SEC.x=12000; SEC.y=200; SEC.resizeWithoutConstraints(3000,4000);
  const cols=await figma.variables.getLocalVariableCollectionsAsync(); const C=n=>cols.find(c=>c.name===n);
  SEC.setExplicitVariableModeForCollection(C('Color'),'81:1'); SEC.setExplicitVariableModeForCollection(C('Spacing'),'81:2'); SEC.setExplicitVariableModeForCollection(C('Radius'),'81:3'); }
const out={};
// ---- Switch
const sw=[]; for(const st of ['On','Off']){ const f=AL('HORIZONTAL',`State=${st}`,{pad:[2,2,2,2],fill: st==='On'?'mp/switch-on':'surface-3',r:15.5, justify: st==='On'?'MAX':'MIN'}); SEC.appendChild(f); f.resize(51,31); f.primaryAxisSizingMode='FIXED'; f.counterAxisSizingMode='FIXED';
  const k=figma.createEllipse(); k.name='knob'; k.resize(27,27); F(k,'ink-inv'); k.effects=[{type:'DROP_SHADOW',color:{r:0,g:0,b:0,a:0.15},offset:{x:0,y:3},radius:8,spread:0,visible:true,blendMode:'NORMAL'}]; f.appendChild(k); sw.push(MK(f)); }
const SW=SET(sw,'Editor/Switch','iOS switch, native size 51×31 (CF-14). The only switch in C1–C3. Place in a row ≥ 44 high; the row is the hit area. On colour = mp/switch-on.'); out.switch=SW.id;
// ---- Handle
{ const f=AL('VERTICAL','Editor/Handle',{gap:4,justify:'CENTER'}); SEC.appendChild(f); f.resize(44,44); f.primaryAxisSizingMode='FIXED'; f.counterAxisSizingMode='FIXED';
  for(let i=0;i<3;i++){ const r=figma.createRectangle(); r.name='bar'; r.resize(18,2); r.cornerRadius=1; F(r,'ink-3'); f.appendChild(r); }
  const c=MK(f); c.description='Drag handle (≡). Always trailing in a list item. 44×44 hit area, 18×10 glyph (CF-15, CF-33).'; out.handle=c.id; }
// ---- Field
const fields=[];
for(const surf of ['OnCard','OnGrey']) for(const kind of ['Line','Area','Number']) for(const st of ['Empty','Filled','Focus','Error','Disabled']){
  const root=AL('VERTICAL',`Kind=${kind}, State=${st}, Surface=${surf}`,{gap:6,align:'MIN'}); SEC.appendChild(root); root.resize(329,10); root.counterAxisSizingMode='FIXED';
  const head=AL('HORIZONTAL','head',{gap:2}); add(root,head,'FILL');
  await T(head,'标签','MP/label','ink-2',{name:'label'}); await T(head,'*','MP/label','bad',{name:'required'}); SP(head); await T(head,'0/30','MP/label','ink-3',{name:'counter'});
  const box=AL('HORIZONTAL','box',{gap:6,pad:[0,14,0,14],fill: surf==='OnCard'?'mp/input-filled':'surface', r:'mp/radius-md'}); root.appendChild(box);
  if(kind==='Number'){ box.resize(132,44); box.primaryAxisSizingMode='FIXED'; box.counterAxisSizingMode='FIXED'; } else { box.layoutSizingHorizontal='FILL'; box.counterAxisSizingMode='FIXED'; box.resize(box.width,kind==='Area'?88:44); }
  if(kind==='Area'){ box.counterAxisAlignItems='MIN'; box.paddingTop=box.paddingBottom=11; box.clipsContent=true; }
  if(st==='Focus') S(box,'ink',1.5); if(st==='Error') S(box,'bad',1.5);
  const v=await T(box,'请输入','MP/body', st==='Empty'?'mp/placeholder':st==='Disabled'?'mp/disabled':'ink',{name:'value'}); v.layoutSizingHorizontal='FILL'; v.textAutoResize='HEIGHT'; if(kind!=='Area'){ v.textTruncation='ENDING'; v.maxLines=1; } if(kind==='Number') v.textAlignHorizontal='RIGHT';
  await T(box,'分','MP/body','ink-3',{name:'suffix'});
  await T(root,'提示文字','MP/label', st==='Error'?'bad':'ink-3',{name:'help',fill:true});
  fields.push(MK(root)); }
const FS=SET(fields,'Editor/Field','The one text field (CF-10). Surface=OnCard → #EFEFEF field inside a white card; Surface=OnGrey → white field on the grey sheet or inside a #F3F4F4 list-item panel. Kind=Number: short, right-aligned, unit as suffix, number pad. One slot under the field: hint or error, never both (help). Live counter 12/30 (CF-28). 44 high (88 for Area).',5);
PROP(FS,'label','TEXT','标签','label','characters'); PROP(FS,'showLabel','BOOLEAN',true,'head','visible'); PROP(FS,'required','BOOLEAN',false,'required','visible');
PROP(FS,'counter','TEXT','0/30','counter','characters'); PROP(FS,'showCounter','BOOLEAN',false,'counter','visible');
PROP(FS,'value','TEXT','请输入','value','characters'); PROP(FS,'suffix','TEXT','分','suffix','characters'); PROP(FS,'showSuffix','BOOLEAN',false,'suffix','visible');
PROP(FS,'help','TEXT','提示文字','help','characters'); PROP(FS,'showHelp','BOOLEAN',false,'help','visible');
out.field=FS.id;
// ---- PopUp
const pops=[];
for(const surf of ['OnCard','OnGrey']) for(const st of ['Empty','Filled','Open','Error','Disabled']){
  const root=AL('VERTICAL',`State=${st}, Surface=${surf}`,{gap:6,align:'MIN'}); SEC.appendChild(root); root.resize(329,10); root.counterAxisSizingMode='FIXED';
  const head=AL('HORIZONTAL','head',{gap:2}); add(root,head,'FILL'); await T(head,'标签','MP/label','ink-2',{name:'label'}); await T(head,'*','MP/label','bad',{name:'required'});
  const box=AL('HORIZONTAL','box',{gap:6,pad:[0,12,0,14],fill: surf==='OnCard'?'mp/input-filled':'surface', r:'mp/radius-md'}); add(root,box,'FILL'); box.counterAxisSizingMode='FIXED'; box.resize(box.width,44);
  if(st==='Open') S(box,'ink',1.5); if(st==='Error') S(box,'bad',1.5);
  const v=await T(box,'请选择','MP/body', st==='Empty'?'mp/placeholder':st==='Disabled'?'mp/disabled':'ink',{name:'value'}); v.layoutSizingHorizontal='FILL'; v.textAutoResize='HEIGHT'; v.textTruncation='ENDING'; v.maxLines=1;
  I(box,'down',14, st==='Disabled'?'mp/disabled':'ink-3','chevron');
  await T(root,'提示文字','MP/label', st==='Error'?'bad':'ink-3',{name:'help',fill:true});
  pops.push(MK(root)); }
const PS=SET(pops,'Editor/PopUp','Pop-up button (native Picker .menu) for 4+ options or long labels (ref 4, section 2). Value ≤ 10 characters; explanation goes in help. The system menu supplies the check mark and animation; Open shows the focused state only.',5);
PROP(PS,'label','TEXT','标签','label','characters'); PROP(PS,'showLabel','BOOLEAN',true,'head','visible'); PROP(PS,'required','BOOLEAN',false,'required','visible');
PROP(PS,'value','TEXT','请选择','value','characters'); PROP(PS,'help','TEXT','提示文字','help','characters'); PROP(PS,'showHelp','BOOLEAN',false,'help','visible');
out.popup=PS.id;
return out;
