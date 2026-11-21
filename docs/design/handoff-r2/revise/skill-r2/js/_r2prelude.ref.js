// ===== r2 prelude · verify-r1 round 2 (batches 4–5) · file 0YyoybGnU1KG0657wdGCPX =====
// Every script: const ITEM='…'; [params]; <prelude>; <body>; return R
const R={item:ITEM,touched:[],created:[],removed:[],archived:[],ann:[],warn:[],info:{}};
const byId=id=>figma.getNodeByIdAsync(id);
async function pageOf(n){ if(typeof n==='string') n=await byId(n); if(!n) return null; while(n&&n.type!=='PAGE') n=n.parent; return n; }
async function goPage(id){ const pg=await pageOf(id); if(!pg) throw new Error('no page for '+id); await figma.setCurrentPageAsync(pg); return pg; }
for(const s of ['Regular','Medium','Semibold','Bold']) await figma.loadFontAsync({family:'SF Pro',style:s});
// ---- variables / paints ----
const V={}, VI={}; for(const v of await figma.variables.getLocalVariablesAsync()){ VI[v.id]=v; if(!V[v.name]) V[v.name]=v; }
const COLS={}; for(const c of await figma.variables.getLocalVariableCollectionsAsync()) COLS[c.id]=c;
function rawOf(v,dark){ const c=COLS[v.variableCollectionId]; if(!c) return null; const re=dark?/MP-Dark|Player-Dark|Dark/i:/MP-Light|Merchant-Light|Light/i; const m=c.modes.find(m=>re.test(m.name))||c.modes[0]; let val=v.valuesByMode[m.modeId], g=0; while(val&&val.type==='VARIABLE_ALIAS'&&g++<6){ const a=VI[val.id]; if(!a) return null; const ac=COLS[a.variableCollectionId]; const am=ac.modes.find(x=>re.test(x.name))||ac.modes[0]; val=a.valuesByMode[am.modeId]; } return val&&'r' in val?val:null; }
// bound paint (never set paint opacity on a bound paint: it reverts to the token alpha)
function PAINT(name,o={}){ const v=V[name]; if(!v){ R.warn.push('novar '+name); return {type:'SOLID',color:o.fallback||{r:0,g:0,b:0}}; } const raw=rawOf(v,o.dark)||o.fallback||{r:0,g:0,b:0}; return figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:raw.r,g:raw.g,b:raw.b}},'color',v); }
const PN=(...ns)=>ns.find(n=>V[n])||ns[ns.length-1];
const RAW=(hex,op)=>{ const h=hex.replace('#',''); const p={type:'SOLID',color:{r:parseInt(h.slice(0,2),16)/255,g:parseInt(h.slice(2,4),16)/255,b:parseInt(h.slice(4,6),16)/255}}; if(op!=null) p.opacity=op; return p; };
function solidOf(n){ if(!n||!('fills' in n)||!Array.isArray(n.fills)) return null; const f=n.fills.find(f=>f.visible!==false&&f.type==='SOLID'); return f?f.color:null; }
const lum=c=>{ const L=x=>x<=0.03928?x/12.92:Math.pow((x+0.055)/1.055,2.4); return 0.2126*L(c.r)+0.7152*L(c.g)+0.0722*L(c.b); };
const isBlue=c=>!!c&&c.b>0.6&&c.r<0.4&&(c.b-c.r)>0.35;
function boundName(paint){ const id=paint&&paint.boundVariables&&paint.boundVariables.color&&paint.boundVariables.color.id; return id&&VI[id]?VI[id].name:null; }
// ---- text ----
async function loadFontsOf(t){ if(!t||t.type!=='TEXT') return; for(const s of t.getStyledTextSegments(['fontName'])) await figma.loadFontAsync(s.fontName); }
async function setT(t,s){ if(!t||t.type!=='TEXT'||t.characters===s) return false; await loadFontsOf(t); t.characters=s; R.touched.push(t.id); return true; }
const texts=n=>!n?[]:(n.type==='TEXT'?[n]:('findAllWithCriteria' in n?n.findAllWithCriteria({types:['TEXT']}):[]));
const findText=(n,re)=>texts(n).find(t=>typeof re==='string'?t.characters===re:re.test(t.characters));
async function TXT(par,s,o={}){ const t=figma.createText(); t.fontName={family:'SF Pro',style:o.w||'Regular'}; t.fontSize=o.size||15; if(o.lh) t.lineHeight={unit:'PIXELS',value:o.lh}; t.characters=s; t.fills=o.raw?[RAW(o.raw)]:[PAINT(o.color||'ink',{dark:o.dark})]; t.name=o.name||s.slice(0,24); if(par){ par.appendChild(t); if(o.fill){ t.layoutSizingHorizontal='FILL'; t.textAutoResize='HEIGHT'; } } if(o.align) t.textAlignHorizontal=o.align; R.created.push(t.id); return t; }
function AL(dir,name,o={}){ const f=figma.createAutoLayout(dir); f.name=name; f.fills=o.fill?[typeof o.fill==='string'?PAINT(o.fill,{dark:o.dark}):o.fill]:[]; if(o.gap!=null) f.itemSpacing=o.gap; if(o.pad){ const [t,r=t,b=t,l=r]=o.pad; f.paddingTop=t; f.paddingRight=r; f.paddingBottom=b; f.paddingLeft=l; } if(o.r!=null) f.cornerRadius=o.r; f.counterAxisAlignItems=o.align||'CENTER'; if(o.justify) f.primaryAxisAlignItems=o.justify; R.created.push(f.id); return f; }
function add(p,c,h,v){ p.appendChild(c); if(h) c.layoutSizingHorizontal=h; if(v) c.layoutSizingVertical=v; return c; }
function SVG(svg,name,size){ const n=figma.createNodeFromSvg(svg); n.name=name; if(size) n.resize(size,size); R.created.push(n.id); return n; }
const ICO={
 chev:c=>`<svg width="8" height="14" viewBox="0 0 8 14" xmlns="http://www.w3.org/2000/svg"><path d="M1 1l6 6-6 6" fill="none" stroke="${c}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
 more:c=>`<svg width="24" height="24" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><circle cx="5" cy="12" r="2" fill="${c}"/><circle cx="12" cy="12" r="2" fill="${c}"/><circle cx="19" cy="12" r="2" fill="${c}"/></svg>`,
 check:c=>`<svg width="20" height="20" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><circle cx="10" cy="10" r="10" fill="${c}"/><path d="M5.5 10.3l3 3 6-6.3" fill="none" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
 lock:c=>`<svg width="16" height="16" viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg"><rect x="3" y="7" width="10" height="8" rx="2" fill="${c}"/><path d="M5 7V5a3 3 0 016 0v2" fill="none" stroke="${c}" stroke-width="1.6"/></svg>`,
 xmark:c=>`<svg width="12" height="12" viewBox="0 0 12 12" xmlns="http://www.w3.org/2000/svg"><path d="M2 2l8 8M10 2l-8 8" stroke="${c}" stroke-width="1.8" stroke-linecap="round"/></svg>`,
 pause:c=>`<svg width="20" height="20" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><rect x="5" y="4" width="3.2" height="12" rx="1" fill="${c}"/><rect x="11.8" y="4" width="3.2" height="12" rx="1" fill="${c}"/></svg>`,
 clock:c=>`<svg width="14" height="14" viewBox="0 0 14 14" xmlns="http://www.w3.org/2000/svg"><circle cx="7" cy="7" r="6" fill="none" stroke="${c}" stroke-width="1.5"/><path d="M7 3.8V7l2.2 1.6" fill="none" stroke="${c}" stroke-width="1.5" stroke-linecap="round"/></svg>`,
};
// ---- components ----
const keyOf=(owner,base)=>Object.keys(owner.componentPropertyDefinitions).find(k=>k.split('#')[0]===base);
const variant=(set,props)=>set.children.find(v=>Object.entries(props).every(([k,val])=>v.name.split(', ').includes(`${k}=${val}`)));
async function topMain(i){ const mc=await i.getMainComponentAsync(); if(!mc) return null; return mc.parent&&mc.parent.type==='COMPONENT_SET'?mc.parent:mc; }
function insideInstance(n,stop){ let p=n.parent; while(p&&p!==stop&&p.type!=='PAGE'){ if(p.type==='INSTANCE') return true; p=p.parent; } return false; }
// put `node` where `old` is (same parent, index, position, size intent); old is hidden or removed
function replaceAt(old,node,o={}){ const par=old.parent; const idx=par.children.indexOf(old); par.insertChild(idx,node); const al=par.layoutMode&&par.layoutMode!=='NONE'&&old.layoutPositioning!=='ABSOLUTE';
 if(al){ if(old.layoutSizingHorizontal==='FILL') node.layoutSizingHorizontal='FILL'; else if(o.keepW) { node.resize(old.width,node.height); } }
 else { node.x=old.x+(o.center?(old.width-node.width)/2:0); node.y=old.y+(o.vcenter?(old.height-node.height)/2:0); if(o.keepW) node.resize(old.width,node.height); }
 if(o.remove!==false){ R.removed.push(old.id); old.remove(); } else old.visible=false; return node; }
// ---- annotations ----
const CATS=await figma.annotations.getAnnotationCategoriesAsync(); const catId=re=>{ const c=CATS.find(c=>re.test(c.label)); return c?c.id:undefined; };
const CAT={I:catId(/^interaction/i),A:catId(/^accessib/i),D:catId(/^develop/i)};
const keepA=(arr,re)=>(arr||[]).filter(a=>!re.test(a.labelMarkdown||a.label||'')).map(a=>{ const o={}; if(a.labelMarkdown) o.labelMarkdown=a.labelMarkdown; else if(a.label) o.label=a.label; if(a.categoryId) o.categoryId=a.categoryId; if(a.properties&&a.properties.length) o.properties=a.properties; return o; });
function ANN(node,md,cat,re){ try{ const a={labelMarkdown:md}; if(cat&&CAT[cat]) a.categoryId=CAT[cat]; node.annotations=[...keepA(node.annotations,re||/^\u0000/),a]; R.ann.push(node.id); }catch(e){ R.warn.push('ann '+node.id+': '+String(e).slice(0,90)); } }
// owner answers (verify-r1 §5) — all confirmed by the owner on 2026-11-16 (Q2 changed: keep the identity step)
function OWNER(node,q,what){ ANN(node,`**Owner confirmed 2026-11-16 (verify-r1 ${q})** · ${what}`,'D',new RegExp('^\\*\\*Owner (default|confirmed)[^*]*verify-r1 '+q+'\\)')); }
function FIXED(node,id,what){ ANN(node,`**verify-r1 ${id}** · ${what}`,'D',new RegExp('^\\*\\*verify-r1 '+id.replace(/[.]/g,'\\.')+'\\*\\*')); }
// ---- yellow canvas note under a frame (same convention as earlier passes) ----
async function NOTE(frame,text,tag){ const par=frame.parent; const nm=`note:${frame.id}${tag?':'+tag:''}`; for(const o of par.children.filter(c=>c.name===nm)) o.remove();
 const n=figma.createAutoLayout('VERTICAL'); par.appendChild(n); n.name=nm; n.fills=[RAW('FFF4C2')]; n.cornerRadius=6; n.paddingTop=n.paddingBottom=6; n.paddingLeft=n.paddingRight=8; n.counterAxisSizingMode='FIXED'; n.resize(Math.min(frame.width,393),n.height);
 const t=figma.createText(); n.appendChild(t); t.fontName={family:'SF Pro',style:'Regular'}; t.fontSize=11; t.lineHeight={unit:'PIXELS',value:15}; t.characters=text; t.fills=[RAW('40330D')]; t.layoutSizingHorizontal='FILL'; t.textAutoResize='HEIGHT';
 let y=frame.y+frame.height+10; for(const m of par.children.filter(c=>c!==n&&c.name.startsWith(`note:${frame.id}`))) y=Math.max(y,m.y+m.height+6); n.x=frame.x; n.y=y; growSec(n); R.created.push(n.id); return n; }
function growSec(n){ const par=n.parent; if(par&&par.type==='SECTION'){ const w=Math.max(par.width,n.x+n.width+80), h=Math.max(par.height,n.y+n.height+80); if(w!==par.width||h!==par.height) par.resizeWithoutConstraints(w,h); } }
// ---- prototype helpers ----
const actsOf=r=>(r.actions&&r.actions.length?r.actions:(r.action?[r.action]:[]));
async function relink(map,scope){ const root=scope||figma.currentPage; let n=0; for(const node of root.findAll(x=>'reactions' in x&&x.reactions&&x.reactions.length>0)){ let ch=false; const rs=node.reactions.map(r=>{ const acts=actsOf(r).map(a=>{ if(a&&a.type==='NODE'&&a.destinationId&&map[a.destinationId]!==undefined){ ch=true; return map[a.destinationId]===null?null:{...a,destinationId:map[a.destinationId]}; } return a; }).filter(Boolean); return {trigger:r.trigger,actions:acts}; }).filter(r=>r.actions.length); if(ch){ await node.setReactionsAsync(rs); n++; } }
 const pg=figma.currentPage; if(!scope){ const f=pg.flowStartingPoints.map(f=>map[f.nodeId]===undefined?f:(map[f.nodeId]===null?null:{nodeId:map[f.nodeId],name:f.name})).filter(Boolean); pg.flowStartingPoints=f; } return n; }
function sourcesTo(ids,scope){ const set=new Set(ids); const out=[]; for(const node of (scope||figma.currentPage).findAll(x=>'reactions' in x&&x.reactions&&x.reactions.length>0)) for(const r of node.reactions) for(const a of actsOf(r)) if(a&&a.destinationId&&set.has(a.destinationId)) out.push({src:node.id,name:node.name,to:a.destinationId}); return out; }
const EASE={type:'EASE_OUT'};
const PUSH=(dir='LEFT')=>({type:'PUSH',direction:dir,matchLayers:false,easing:EASE,duration:0.35});
const SHEET_IN={type:'MOVE_IN',direction:'TOP',matchLayers:false,easing:EASE,duration:0.35};
async function link(src,dest,transition,trigger){ const rs=(src.reactions||[]).filter(r=>!actsOf(r).some(a=>a&&a.type==='NODE'&&a.navigation==='NAVIGATE')).map(r=>({trigger:r.trigger,actions:actsOf(r)})); rs.push({trigger:trigger||{type:'ON_CLICK'},actions:[dest==='BACK'?{type:'BACK'}:{type:'NODE',destinationId:dest,navigation:'NAVIGATE',transition:transition||null,resetScrollPosition:true}]}); await src.setReactionsAsync(rs); }
// ---- archive (verify-r1 4.10 / F-10): retired frames leave their page; links to them are removed ----
async function ARCHIVE(nodes,origin,reason){ nodes=nodes.filter(Boolean); if(!nodes.length) return; const map={}; for(const n of nodes) map[n.id]=null; R.info.unlinked=(R.info.unlinked||0)+await relink(map);
 let arch=figma.root.children.find(p=>p.name==='Archive · 已退役'); if(!arch){ arch=figma.createPage(); arch.name='Archive · 已退役'; R.info.archivePage=arch.id; } else await arch.loadAsync();
 let sec=arch.children.find(s=>s.type==='SECTION'&&s.name===origin); if(!sec){ sec=figma.createSection(); arch.appendChild(sec); sec.name=origin; const others=arch.children.filter(c=>c!==sec); sec.x=0; sec.y=others.length?Math.max(...others.map(c=>c.y+c.height))+200:0; sec.resizeWithoutConstraints(1200,1100); }
 let x=sec.children.length?Math.max(...sec.children.map(c=>c.x+c.width))+80:80; let maxH=0;
 for(const n of nodes){ const oid=n.id, nm=n.name; const par=n.parent;
  if(par&&par.children) for(const c of [...par.children]){ if(c===n) continue; const att=c.name.startsWith('note:'+oid)||c.name==='label:'+oid||(c.type==='TEXT'&&Math.abs(c.x-n.x)<6&&c.y<n.y&&c.y>n.y-90)||(c.type==='FRAME'&&/^label/i.test(c.name)&&Math.abs(c.x-n.x)<6&&c.y<n.y&&c.y>n.y-90); if(att){ R.removed.push(c.id); c.remove(); } }
  n.opacity=1; sec.appendChild(n); n.x=x; n.y=150; maxH=Math.max(maxH,n.height);
  const l=figma.createText(); sec.appendChild(l); l.fontName={family:'SF Pro',style:'Regular'}; l.fontSize=13; l.lineHeight={unit:'PIXELS',value:18}; l.characters=`${nm}\n来自 ${origin} · ${oid}\n${reason}`; l.fills=[RAW('6B6B6B')]; l.name='label:'+oid; l.x=x; l.y=60; l.resize(Math.max(200,n.width),l.height); l.textAutoResize='HEIGHT';
  x+=n.width+80; R.archived.push(oid); }
 sec.resizeWithoutConstraints(Math.max(sec.width,x+40),Math.max(sec.height,150+maxH+120)); }
// ---- motion notes → native Interaction annotations (verify-r1 5.8) ----
const MOTION_RE=/motion|动效|spring|弹簧|haptic|触感|\.success|\.selection|\.impact|\.warning|Reduce Motion|\d+\s?ms\b|smart animate|过渡|slide|fade|淡入|淡出|缩放|scale/i;
