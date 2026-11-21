// ===== skill-r1 prelude · file 0YyoybGnU1KG0657wdGCPX =====
const R={item:ITEM,created:[],touched:[],removed:[],ann:[],warn:[],info:{}};
const byId=id=>figma.getNodeByIdAsync(id);
async function pageOf(n){ if(typeof n==='string') n=await byId(n); while(n&&n.type!=='PAGE') n=n.parent; return n; }
async function goPage(id){ const pg=await pageOf(id); await figma.setCurrentPageAsync(pg); return pg; }
for(const s of ['Regular','Medium','Semibold','Bold','Heavy']) await figma.loadFontAsync({family:'SF Pro',style:s});
const V={}, VI={}; for(const v of await figma.variables.getLocalVariablesAsync()){ VI[v.id]=v; if(!V[v.name]) V[v.name]=v; }
const COLS={}; for(const c of await figma.variables.getLocalVariableCollectionsAsync()) COLS[c.id]=c;
const TS={}; for(const s of await figma.getLocalTextStylesAsync()) TS[s.name]=s;
const ES={}; for(const s of await figma.getLocalEffectStylesAsync()) ES[s.name]=s;
function rawOf(v){ const c=COLS[v.variableCollectionId]; const m=c.modes[0]; let val=v.valuesByMode[m.modeId], g=0; while(val&&val.type==='VARIABLE_ALIAS'&&g++<6){ const a=VI[val.id]; const ac=COLS[a.variableCollectionId]; val=a.valuesByMode[ac.modes[0].modeId]; } return val&&'r' in val?val:{r:0,g:0,b:0}; }
function PAINT(name){ const v=V[name]; if(!v){ R.warn.push('novar '+name); return {type:'SOLID',color:{r:1,g:0,b:1}}; } const raw=rawOf(v); return figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:raw.r,g:raw.g,b:raw.b}},'color',v); }
const RAW=(hex,op)=>{ const h=hex.replace('#',''); const p={type:'SOLID',color:{r:parseInt(h.slice(0,2),16)/255,g:parseInt(h.slice(2,4),16)/255,b:parseInt(h.slice(4,6),16)/255}}; if(op!=null) p.opacity=op; return p; };
const fillV=(n,k)=>{ n.fills=k?[PAINT(k)]:[]; return n; };
const strokeV=(n,k,w=1,dash)=>{ n.strokes=[PAINT(k)]; n.strokeWeight=w; n.strokeAlign='INSIDE'; if(dash) n.dashPattern=dash; return n; };
function bindR(n,k){ if(!V[k]){ n.cornerRadius=0; return n; } for(const c of ['topLeftRadius','topRightRadius','bottomLeftRadius','bottomRightRadius']) n.setBoundVariable(c,V[k]); return n; }
function bindGap(n,k){ if(V[k]) n.setBoundVariable('itemSpacing',V[k]); return n; }
function bindPad(n,t,r=t,b=t,l=r){ const set=(f,k)=>{ if(typeof k==='string'&&V[k]) n.setBoundVariable(f,V[k]); else n[f]=k; }; set('paddingTop',t); set('paddingRight',r); set('paddingBottom',b); set('paddingLeft',l); return n; }
const texts=n=>!n?[]:(n.type==='TEXT'?[n]:('findAllWithCriteria' in n?n.findAllWithCriteria({types:['TEXT']}):[]));
async function loadFontsOf(t){ if(!t||t.type!=='TEXT') return; for(const s of t.getStyledTextSegments(['fontName'])) await figma.loadFontAsync(s.fontName); }
async function setT(t,s){ if(!t||t.type!=='TEXT'||t.characters===s) return false; await loadFontsOf(t); t.characters=s; R.touched.push(t.id); return true; }
// text with a library style
async function TX(par,s,style,color='ink',o={}){ const t=figma.createText(); t.fontName={family:'SF Pro',style:'Regular'}; if(TS[style]) await t.setTextStyleIdAsync(TS[style].id); else R.warn.push('nostyle '+style); t.characters=s; t.fills=o.raw?[RAW(o.raw)]:[PAINT(color)]; t.name=o.name||s.slice(0,24); if(par){ par.appendChild(t); if(o.fill){ t.layoutSizingHorizontal='FILL'; t.textAutoResize='HEIGHT'; } } if(o.align) t.textAlignHorizontal=o.align; if(o.w){ t.resize(o.w,t.height); t.textAutoResize='HEIGHT'; } R.created.push(t.id); return t; }
function AL(dir,name,o={}){ const f=figma.createAutoLayout(dir); f.name=name; f.fills=o.fill?[typeof o.fill==='string'?PAINT(o.fill):o.fill]:[]; if(o.gap!=null) f.itemSpacing=o.gap; if(o.pad){ const [t,r=t,b=t,l=r]=o.pad; f.paddingTop=t; f.paddingRight=r; f.paddingBottom=b; f.paddingLeft=l; } if(o.r!=null){ if(typeof o.r==='string') bindR(f,o.r); else f.cornerRadius=o.r; } f.counterAxisAlignItems=o.align||'CENTER'; if(o.justify) f.primaryAxisAlignItems=o.justify; if(o.w||o.h){ f.resize(o.w||Math.max(1,f.width),o.h||Math.max(1,f.height)); if(o.w) f.layoutSizingHorizontal='FIXED'; if(o.h) f.layoutSizingVertical='FIXED'; } if(o.clip) f.clipsContent=true; R.created.push(f.id); return f; }
function add(p,c,h,v){ p.appendChild(c); if(h) c.layoutSizingHorizontal=h; if(v) c.layoutSizingVertical=v; return c; }
function RECT(par,w,h,fill,o={}){ const r=figma.createRectangle(); r.resize(w,h); r.fills=fill?[typeof fill==='string'?PAINT(fill):fill]:[]; if(o.r!=null){ if(typeof o.r==='string') bindR(r,o.r); else r.cornerRadius=o.r; } r.name=o.name||'rect'; if(par) par.appendChild(r); if(o.x!=null){ r.x=o.x; r.y=o.y; } R.created.push(r.id); return r; }
function ELL(par,d,fill,o={}){ const e=figma.createEllipse(); e.resize(d,d); e.fills=fill?[typeof fill==='string'?PAINT(fill):fill]:[]; e.name=o.name||'dot'; if(par) par.appendChild(e); if(o.x!=null){ e.x=o.x; e.y=o.y; } R.created.push(e.id); return e; }
function SVG(par,svg,name){ const n=figma.createNodeFromSvg(svg); n.name=name; if(par) par.appendChild(n); R.created.push(n.id); return n; }
const ICON_IDS={back:'9:3',chev:'9:5',down:'9:7',x:'9:9',more:'9:11',search:'9:13',home:'9:15',compass:'9:17',ticket:'9:19',people:'9:21',person:'9:23',bell:'9:25',plus:'9:27',scan:'9:29',qr:'9:31',pin:'9:33',map:'9:35',route:'9:37',check:'9:39','check-c':'9:41',alert:'9:43',info:'9:45',loc:'9:49',camera:'9:51',lock:'9:53',gift:'9:55',chart:'9:57',chat:'9:61',grid:'9:65',wallet:'9:67',share:'9:69',heart:'9:71',flag:'9:73',star:'9:75',cal:'9:77',clock:'9:79',photo:'9:81',refresh:'9:83',gear:'9:85',badge:'9:87',store:'9:89','arrow-up':'9:91',hourglass:'9:93','plus-c':'9:95',edit:'9:99',layers:'9:101',signal:'9:105','loc-fill':'9:111'};
async function IC(par,name,size=20,color='ink',nm){ const m=await byId(ICON_IDS[name]); const i=m.createInstance(); i.resize(size,size); const g=i.findOne(n=>n.type==='TEXT'); if(g){ g.fontSize=Math.round(size*0.8); g.fills=[PAINT(color)]; } i.name=nm||('icon/'+name); if(par) par.appendChild(i); R.created.push(i.id); return i; }
const keyOf=(owner,base)=>Object.keys(owner.componentPropertyDefinitions).find(k=>k.split('#')[0]===base);
const variant=(set,props)=>set.children.find(v=>Object.entries(props).every(([k,val])=>v.name.split(', ').includes(`${k}=${val}`)));
async function topMain(i){ const mc=await i.getMainComponentAsync(); if(!mc) return null; return mc.parent&&mc.parent.type==='COMPONENT_SET'?mc.parent:mc; }
function setProps(inst,map){ const o=inst.componentProperties; const out={}; for(const [k,v] of Object.entries(map)){ const kk=Object.keys(o).find(x=>x.split('#')[0]===k); if(kk) out[kk]=v; } inst.setProperties(out); return inst; }
function tprop(owner,name,def,nodeName){ const key=owner.addComponentProperty(name,'TEXT',def); const kids=owner.type==='COMPONENT_SET'?owner.children:[owner]; let n=0; for(const v of kids) for(const t of v.findAll(x=>x.type==='TEXT'&&x.name===nodeName&&x.characters===def)){ t.componentPropertyReferences={...(t.componentPropertyReferences||{}),characters:key}; n++; } return n; }
function bprop(owner,name,def,nodeName){ const key=owner.addComponentProperty(name,'BOOLEAN',def); const kids=owner.type==='COMPONENT_SET'?owner.children:[owner]; for(const v of kids) for(const t of v.findAll(x=>x.name===nodeName)) t.componentPropertyReferences={...(t.componentPropertyReferences||{}),visible:key}; return key; }
function gridSet(s,cols,gap=24,padding=32){ let x=padding,y=padding,rowH=0,i=0; for(const v of s.children){ if(i&&i%cols===0){ x=padding; y+=rowH+gap; rowH=0; } v.x=x; v.y=y; x+=v.width+gap; rowH=Math.max(rowH,v.height); i++; } const W=Math.max(...s.children.map(v=>v.x+v.width))+padding, H=Math.max(...s.children.map(v=>v.y+v.height))+padding; s.resizeWithoutConstraints(W,H); }
async function SETOF(comps,name,cols,desc,par){ const s=figma.combineAsVariants(comps,par||figma.currentPage); s.name=name; fillV(s,'bg'); s.cornerRadius=16; gridSet(s,cols); if(desc) s.description=desc; R.created.push(s.id); return s; }
// place a node at the bottom of a section, with a doc label above
let _px=null,_py=null,_rowH=0;
async function placeIn(sec,node,label,o={}){ if(_py===null){ _py=Math.max(0,...sec.children.map(c=>c.y+c.height))+160; _px=80; } if(_px+node.width>sec.width-80&&_px>80){ _px=80; _py+=_rowH+120; _rowH=0; } sec.appendChild(node); node.x=_px; node.y=_py+40; const t=await TX(null,label,'t-head','ink-2'); t.fills=[RAW('8E8E93')]; sec.appendChild(t); t.x=_px; t.y=_py; t.name='doc/'+label.slice(0,40); _px+=Math.max(node.width,t.width)+120; _rowH=Math.max(_rowH,node.height+40); const W=Math.max(sec.width,node.x+node.width+80), H=Math.max(sec.height,node.y+node.height+120); sec.resizeWithoutConstraints(W,H); return node; }
function newRow(){ if(_py!==null){ _px=80; _py+=_rowH+120; _rowH=0; } }
// annotations
const CATS=await figma.annotations.getAnnotationCategoriesAsync(); const catId=re=>{ const c=CATS.find(c=>re.test(c.label)); return c?c.id:undefined; };
const CAT={I:catId(/^interaction/i),A:catId(/^accessib/i),D:catId(/^develop/i)};
const keepA=(arr,re)=>(arr||[]).filter(a=>!re.test(a.labelMarkdown||a.label||'')).map(a=>{ const o={}; if(a.labelMarkdown) o.labelMarkdown=a.labelMarkdown; else if(a.label) o.label=a.label; if(a.categoryId) o.categoryId=a.categoryId; if(a.properties&&a.properties.length) o.properties=a.properties; return o; });
function ANN(node,md,cat,re){ try{ const a={labelMarkdown:md}; if(cat&&CAT[cat]) a.categoryId=CAT[cat]; node.annotations=[...keepA(node.annotations,re||/^\u0000/),a]; R.ann.push(node.id); }catch(e){ R.warn.push('ann '+node.id+': '+String(e).slice(0,90)); } }
function SR(node,id,what){ ANN(node,`**skill-r1 ${id}** · ${what}`,'D',new RegExp('^\\*\\*skill-r1 '+id+'\\*\\*')); }
function OWN(node,q,what){ ANN(node,`**Owner default (skill-r1 ${q})** · ${what}`,'D',new RegExp('^\\*\\*Owner default \\(skill-r1 '+q+'\\)')); }
// prototype
const actsOf=r=>(r.actions&&r.actions.length?r.actions:(r.action?[r.action]:[]));
const SPRING={sheet:[273,28.4],push:[195,24.0],press:[439,33.5],result:[224,23.9],moment:[247,17.3]};
const SP=k=>({type:'CUSTOM_SPRING',easingFunctionSpring:{mass:1,stiffness:SPRING[k][0],damping:SPRING[k][1]}});
const DUR={sheet:0.35,push:0.4,press:0.25,result:0.4,moment:0.6};
async function relink(map,scope){ const root=scope||figma.currentPage; let n=0; for(const node of root.findAll(x=>'reactions' in x&&x.reactions&&x.reactions.length>0)){ let ch=false; const rs=node.reactions.map(r=>{ const acts=actsOf(r).map(a=>{ if(a&&a.type==='NODE'&&a.destinationId&&map[a.destinationId]!==undefined){ ch=true; return map[a.destinationId]===null?null:{...a,destinationId:map[a.destinationId]}; } return a; }).filter(Boolean); return {trigger:r.trigger,actions:acts}; }).filter(r=>r.actions.length); if(ch){ await node.setReactionsAsync(rs); n++; } }
 const pg=figma.currentPage; if(!scope){ pg.flowStartingPoints=pg.flowStartingPoints.map(f=>map[f.nodeId]===undefined?f:(map[f.nodeId]===null?null:{nodeId:map[f.nodeId],name:f.name})).filter(Boolean); } return n; }
// shared C-page pass: SR1-17 (text < 11 → t-cap2, counters → t-cap) + SR1-43 springs
async function cpass(){ const pg=figma.currentPage; let small=0, counters=0, spr=0;
  for(const t of pg.findAllWithCriteria({types:['TEXT']})){ if(t.id.includes(';')||typeof t.fontSize!=='number') continue; if(t.fontSize<11){ await loadFontsOf(t); const fl=t.fills; if(/^\d+\s?\/\s?\d+$/.test(t.characters.trim())){ await t.setTextStyleIdAsync(TS['t-cap'].id); counters++; } else { await t.setTextStyleIdAsync(TS['t-cap2'].id); small++; } t.fills=fl; } }
  for(const n of pg.findAll(x=>'reactions' in x&&x.reactions&&x.reactions.length)){ let ch=false; const rs=n.reactions.map(r=>({trigger:r.trigger,actions:actsOf(r).map(a=>{ if(!a||a.type!=='NODE'||!a.transition||(a.transition.easing&&a.transition.easing.type==='CUSTOM_SPRING')) return a; const t=a.transition; const role=t.type==='PUSH'||/SLIDE/.test(t.type)?'push':(/MOVE/.test(t.type)?'sheet':(t.type==='DISSOLVE'?'sheet':'press')); ch=true; return {...a,transition:{...t,easing:SP(role),duration:DUR[role]}}; })})); if(ch){ try{ await n.setReactionsAsync(rs); spr++; }catch(e){} } }
  return {small,counters,spr}; }
