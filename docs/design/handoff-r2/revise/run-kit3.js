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
function PROP(owner,name,type,def,nodeName,field){ const key=owner.addComponentProperty(name,type,def); const kids=owner.type==='COMPONENT_SET'?owner.children:[owner]; for(const v of kids){ v.findAll(n=>n.name===nodeName&&!(()=>{let p=n.parent; while(p&&p!==v){ if(p.type==='INSTANCE') return true; p=p.parent;} return false;})()).forEach(n=>{ n.componentPropertyReferences={...(n.componentPropertyReferences||{}),[field]:key}; }); } return key; }
let SEC=page.children.find(n=>n.type==='SECTION'&&n.name.startsWith('Editor · 编辑器组件'));
const out={};
function BOX(par,name,w,h,o={}){ const f=AL('HORIZONTAL',name,{justify:'CENTER',fill:o.fill,r:o.r}); par.appendChild(f); f.resize(w,h); f.primaryAxisSizingMode='FIXED'; f.counterAxisSizingMode='FIXED'; return f; }
// ---- Sheet Header
const hdrs=[]; for(const lead of ['Close','Back','None']) for(const trail of ['Done','None']){
  const root=AL('VERTICAL',`Leading=${lead}, Trailing=${trail}`,{gap:0}); SEC.appendChild(root); root.resize(393,10); root.counterAxisSizingMode='FIXED'; root.primaryAxisSizingMode='AUTO';
  const g=BOX(root,'grabber',393,13); g.counterAxisAlignItems='MAX'; const gr=figma.createRectangle(); gr.name='bar'; gr.resize(36,5); gr.cornerRadius=2.5; F(gr,'mp/sheet-handle'); g.appendChild(gr);
  const bar=AL('HORIZONTAL','bar',{pad:[0,16,0,16],justify:'SPACE_BETWEEN'}); add(root,bar,'FILL'); bar.counterAxisSizingMode='FIXED'; bar.resize(393,52);
  const L=BOX(bar,'leading · hit 44',44,44); L.primaryAxisAlignItems='MIN'; if(lead!=='None'){ const c=BOX(L,'circle 32',32,32,{fill:'mp/btn-secondary',r:16}); I(c,lead==='Close'?'x':'back',16,'ink','glyph'); }
  if(trail==='Done'){ const d=AL('HORIZONTAL','done pill',{pad:[0,18,0,18],fill:'cta',r:22}); bar.appendChild(d); d.counterAxisSizingMode='FIXED'; d.resize(d.width,44); d.primaryAxisSizingMode='AUTO'; await T(d,'完成','MP/body-strong','cta-ink',{name:'done'}); }
  else BOX(bar,'trailing · empty',44,44);
  const tb=AL('VERTICAL','title block',{gap:2,pad:[2,16,12,16]}); add(tb.parent||root,tb); tb.layoutSizingHorizontal='FILL';
  await T(tb,'节点 3 · 第一章','MP/label','ink-3',{name:'eyebrow',align:'CENTER'}); await T(tb,'标题','',  'ink',{name:'title',w:'Bold',size:20,lh:26,align:'CENTER'});
  hdrs.push(MK(root)); }
const SH=SET(hdrs,'Editor/Sheet Header','The one sheet header (CF-11, owner answer Q2 / TE screens): grabber 36×5; round ✕ (32 visual in 44 hit) left, black 完成 pill (44 high) right; title 20 Bold centred below, optional 12 pt eyebrow above. Leading=Back on pushed sub-pages. Trailing=None for pick-one sheets that commit on tap. Result sheets: no ✕. Pinned while the sheet scrolls.',2);
PROP(SH,'title','TEXT','标题','title','characters'); PROP(SH,'eyebrow','TEXT','节点 3 · 第一章','eyebrow','characters'); PROP(SH,'showEyebrow','BOOLEAN',false,'eyebrow','visible');
PROP(SH,'done','TEXT','完成','done','characters'); PROP(SH,'showGrabber','BOOLEAN',true,'grabber','visible'); out.sheetHeader=SH.id;
// ---- Sheet (detent)
const SHdef=SH.children.find(c=>c.name==='Leading=Close, Trailing=Done');
const sheets=[]; for(const [det,h] of [['Fit',null],['Medium',460],['Large',788]]){
  const root=AL('VERTICAL',`Detent=${det}`,{gap:0,fill:'bg'}); SEC.appendChild(root); root.resize(393,h||10); root.counterAxisSizingMode='FIXED'; root.primaryAxisSizingMode=h?'FIXED':'AUTO';
  root.topLeftRadius=24; root.topRightRadius=24; root.clipsContent=true; root.effects=[{type:'DROP_SHADOW',color:{r:0,g:0,b:0,a:0.12},offset:{x:0,y:-4},radius:24,spread:0,visible:true,blendMode:'NORMAL'}];
  const hi=SHdef.createInstance(); root.appendChild(hi); hi.name='header'; hi.layoutSizingHorizontal='FILL';
  const ct=AL('VERTICAL','content',{gap:12,pad:[4,16,34,16],align:'MIN'}); add(root,ct,'FILL'); if(h) ct.layoutSizingVertical='FILL'; ct.clipsContent=true; if(det==='Large') ct.overflowDirection='VERTICAL';
  const card=AL('VERTICAL','content slot',{fill:'surface',r:'mp/radius-md',pad:[16,16,16,16],justify:'CENTER'}); add(ct,card,'FILL'); card.counterAxisAlignItems='CENTER'; card.primaryAxisSizingMode='FIXED'; card.resize(361, det==='Fit'?200:det==='Medium'?280:640);
  await T(card,`内容 · ${det==='Fit'?'.height(content) ≤ 62%':det==='Medium'?'.medium':'.large · 内容可滚动'}`,'MP/label','ink-3',{name:'slot label'});
  const c=MK(root); c.findOne(n=>n.name==='header').isExposedInstance=true; sheets.push(c); }
const SHT=SET(sheets,'Editor/Sheet','Resizable scrollable sheet (CF-13, section 3, owner Kavsoft reference). Opens at its smallest detent that shows the content; drag grows it; content scrolls only at Large (overflow vertical only there). Spring between detents: spring(response 0.38, dampingFraction 0.86) — Figma Smart Animate spring stiffness 290, damping 27, mass 1. Present ≈350 ms, dismiss 280 ms. Content-height change: same spring, fields fade in 180 ms after a 60 ms delay. Haptic .selection when a drag settles on a new detent. Reduce Motion: 200 ms cross-fade. Scrim 40% under Large. Header pinned; grabber hidden on single-detent sheets. Dirty sheets cannot be swiped away (放弃修改？ dialog). Never a sheet on a sheet: sub-editors push with Leading=Back.');
out.sheet=SHT.id;
// ---- Toast
const toasts=[]; for(const ic of ['none','success','info']){ const f=AL('HORIZONTAL',`Icon=${ic}`,{gap:8,pad:[11,16,11,16],fill:'ink',r:22}); SEC.appendChild(f); f.maxWidth=329;
  if(ic!=='none') I(f,ic==='success'?'check-c':'info',18,'ink-inv','icon');
  const t=await T(f,'已移到待编排 · 撤销','MP/body-strong','ink-inv',{name:'text'}); t.textAutoResize='WIDTH_AND_HEIGHT'; toasts.push(MK(f)); }
const TO=SET(toasts,'Editor/Toast','The one toast (CF-16): pill, optional icon, bottom-anchored 12 above the bottom bar, 2 s, max width 329 (wraps to two lines). Only for results of an action elsewhere — never for validation or limits. Colours are ink / ink-inv, so it is a dark pill on light pages and a light pill on dark pages automatically (no Theme variant needed).');
PROP(TO,'text','TEXT','已移到待编排 · 撤销','text','characters'); out.toast=TO.id;
// ---- State
const stdef={Loading:['',''],Empty:['还没有内容','添加后会显示在这里'],Error:['内容没加载出来','检查网络后再试一次'],SignedOut:['登录后继续创作','草稿会保存在你的账号里'],NoPermission:['你没有编辑权限','只有创建者和合作者可以编辑']};
const acts={Empty:'添加',Error:'重试',SignedOut:'去登录',NoPermission:'去模板广场选用'}; const icons={Empty:'doc',Error:'wifi-off',SignedOut:'person',NoPermission:'lock'};
const states=[]; for(const k of Object.keys(stdef)){ const f=AL('VERTICAL',`Kind=${k}`,{gap:8,pad:[24,16,24,16]}); SEC.appendChild(f); f.resize(361,10); f.counterAxisSizingMode='FIXED'; f.primaryAxisSizingMode='AUTO';
  if(k==='Loading'){ f.counterAxisAlignItems='MIN'; for(const [w,h,r] of [[329,88,12],[260,14,7],[329,14,7],[200,14,7],[329,88,12]]){ const s=figma.createRectangle(); s.name='skeleton'; s.resize(w,h); s.cornerRadius=r; F(s,'skel'); f.appendChild(s); } }
  else { const tile=BOX(f,'icon tile 64',64,64,{fill:'mp/input-filled',r:16}); I(tile,icons[k],28,'ink-2','icon'); const sp=figma.createFrame(); sp.name='gap'; sp.fills=[]; sp.resize(1,4); f.appendChild(sp);
    await T(f,stdef[k][0],'MP/card-title','ink',{name:'title',align:'CENTER'}); await T(f,stdef[k][1],'','ink-3',{name:'body',size:13,lh:18,align:'CENTER'});
    const b=AL('HORIZONTAL','button',{pad:[0,18,0,18],fill:'mp/btn-secondary',r:18}); f.appendChild(b); b.counterAxisSizingMode='FIXED'; b.resize(b.width,36); b.primaryAxisSizingMode='AUTO'; await T(b,acts[k],'MP/body-strong','ink',{name:'action'}); }
  states.push(MK(f)); }
const ST=SET(states,'Editor/State','Page and sheet states (CF-18): Loading = skeleton mirroring the final layout (no scrim, no card, shown after 200 ms); Empty / Error / SignedOut / NoPermission = icon tile 64, title 16 Semibold, body 13, one button; centred at 40% height. In a sheet list, use skeleton rows. Copy is per variant: edit the text layers on the instance. SwiftUI: ContentUnavailableView, .redacted(.placeholder).');
PROP(ST,'showBody','BOOLEAN',true,'body','visible'); PROP(ST,'showAction','BOOLEAN',true,'button','visible'); out.state=ST.id;
// ---- Nav Bar
const SB=await figma.getNodeByIdAsync('10:23'); const sbv=SB.type==='COMPONENT_SET'?SB.children[0]:SB; out.sbv=sbv.name;
const navs=[]; for(const tr of ['None','More','Action']){ const root=AL('VERTICAL',`Trailing=${tr}`,{gap:0}); SEC.appendChild(root); root.resize(393,100); root.counterAxisSizingMode='FIXED'; root.primaryAxisSizingMode='FIXED';
  const sb=sbv.createInstance(); root.appendChild(sb); sb.name='Status Bar'; sb.layoutSizingHorizontal='FILL';
  const row=AL('HORIZONTAL','row',{pad:[0,16,0,16],justify:'SPACE_BETWEEN'}); add(root,row,'FILL'); row.counterAxisSizingMode='FIXED'; row.resize(393,46);
  const b=BOX(row,'back · hit 44',44,44,{fill:'surface',r:22}); I(b,'back',20,'ink','glyph');
  const t=await T(row,'编辑玩法模板','',  'ink',{name:'title',w:'Semibold',size:17,lh:22,align:'CENTER'}); t.layoutPositioning='ABSOLUTE'; t.textAutoResize='HEIGHT'; t.resize(240,22); t.x=(393-240)/2; t.y=12; t.constraints={horizontal:'CENTER',vertical:'CENTER'};
  if(tr==='More'){ const m=BOX(row,'more · hit 44',44,44,{fill:'surface',r:22}); I(m,'more',20,'ink','glyph'); }
  else if(tr==='Action'){ const a=AL('HORIZONTAL','action slot',{pad:[0,4,0,4]}); row.appendChild(a); a.counterAxisSizingMode='FIXED'; a.resize(a.width,44); a.primaryAxisSizingMode='AUTO'; await T(a,'预览','MP/body-strong','ink',{name:'action'}); }
  else BOX(row,'trailing · empty',44,44);
  navs.push(MK(root)); }
const NV=SET(navs,'Editor/Nav Bar','Creation-page nav (CF-19, handbook N3): back chevron in a 44 pt circle, centred 17 Semibold title once, no large title. Trailing: ⋯ menu (清空本地草稿 etc.) or one text action. Titles match the entry: AI 快速创建 · 编辑玩法模板 · 发布活动 · 票务设置. 393×100 incl. status bar, same footprint as MP/Nav Bar.');
PROP(NV,'title','TEXT','编辑玩法模板','title','characters'); PROP(NV,'action','TEXT','预览','action','characters'); out.nav=NV.id;
// ---- Bottom Bar
{ const root=AL('HORIZONTAL','Editor/Bottom Bar',{gap:10,pad:[10,16,34,16],fill:'surface'}); SEC.appendChild(root); root.resize(393,88); root.primaryAxisSizingMode='FIXED'; root.counterAxisSizingMode='AUTO';
  root.strokes=[P('sep')]; root.strokeTopWeight=0.5; root.strokeBottomWeight=0; root.strokeLeftWeight=0; root.strokeRightWeight=0; root.strokeAlign='INSIDE';
  for(const [nm,txt,pri] of [['left','保存草稿',0],['middle','查看预览',0],['primary','发布玩法',1]]){ const b=AL('HORIZONTAL',nm,{justify:'CENTER',fill:pri?'cta':'mp/btn-secondary',r:22}); add(root,b,'FILL'); b.counterAxisSizingMode='FIXED'; b.resize(b.width,44); await T(b,txt,pri?'MP/button':'MP/button-secondary',pri?'cta-ink':'ink',{name:'label'}); }
  const c=MK(root); c.description='Editor bottom bar (section 2 Primary): one black primary pill per screen, secondaries grey. 44 high buttons, 34 home-indicator inset. The primary is never disabled (CF-17): tapping it with missing data scrolls to the first error.';
  const k1=c.addComponentProperty('left','TEXT','保存草稿'), k2=c.addComponentProperty('middle','TEXT','查看预览'), k3=c.addComponentProperty('primary','TEXT','发布玩法'), k4=c.addComponentProperty('showLeft','BOOLEAN',true), k5=c.addComponentProperty('showMiddle','BOOLEAN',true);
  const L=c.findOne(n=>n.name==='left'), M=c.findOne(n=>n.name==='middle'), Pm=c.findOne(n=>n.name==='primary');
  L.componentPropertyReferences={visible:k4}; M.componentPropertyReferences={visible:k5}; L.findOne(n=>n.type==='TEXT').componentPropertyReferences={characters:k1}; M.findOne(n=>n.type==='TEXT').componentPropertyReferences={characters:k2}; Pm.findOne(n=>n.type==='TEXT').componentPropertyReferences={characters:k3};
  out.bottomBar=c.id; }
return out;
