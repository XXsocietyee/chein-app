const V={}; for(const v of await figma.variables.getLocalVariablesAsync()) if(!V[v.name]) V[v.name]=v;
const TS={}; for(const s of await figma.getLocalTextStylesAsync()) TS[s.name]=s;
for(const s of ['Regular','Medium','Semibold','Bold']) await figma.loadFontAsync({family:'SF Pro',style:s});
const P=(n,op)=>{ const p=figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:0,g:0,b:0}},'color',V[n]); return op!=null?{...p,opacity:op}:p; };
const F=(n,k,op)=>{n.fills=k?[P(k,op)]:[]; return n;};
const S=(n,k,w=1)=>{n.strokes=[P(k)]; n.strokeWeight=w; n.strokeAlign='INSIDE'; return n;};
function AL(dir,name,o={}){ const f=figma.createAutoLayout(dir); f.name=name; f.fills=[]; if(o.gap!=null) f.itemSpacing=o.gap; if(o.pad){ const [t,r=t,b=t,l=r]=o.pad; f.paddingTop=t; f.paddingRight=r; f.paddingBottom=b; f.paddingLeft=l;} if(o.fill) F(f,o.fill,o.op); if(o.r!=null) f.cornerRadius=o.r; f.counterAxisAlignItems=o.align||'CENTER'; if(o.justify) f.primaryAxisAlignItems=o.justify; return f; }
function add(p,c,h,v){ p.appendChild(c); if(h) c.layoutSizingHorizontal=h; if(v) c.layoutSizingVertical=v; return c; }
async function T(par,chars,style,color='ink',o={}){ const t=figma.createText(); if(par) par.appendChild(t); if(style) await t.setTextStyleIdAsync(TS[style].id); else { t.fontName={family:'SF Pro',style:o.w||'Regular'}; t.fontSize=o.size||14; } t.characters=chars; F(t,color); t.name=o.name||'label'; if(o.fill&&par){ t.layoutSizingHorizontal='FILL'; t.textAutoResize='HEIGHT'; } if(o.align) t.textAlignHorizontal=o.align; return t; }
const LIB=await figma.getNodeByIdAsync('6:3');
const ICON={}; for(const n of (await figma.getNodeByIdAsync('9:2')).findAllWithCriteria({types:['COMPONENT']})) ICON[n.name.slice(5)]=n;
function I(par,name,size=20,color='ink',nm){ const i=ICON[name].createInstance(); if(par) par.appendChild(i); i.resize(size,size); const g=i.findOne(n=>n.type==='TEXT'); g.fontSize=Math.round(size*0.82); g.fills=[P(color)]; i.name=nm||('icon/'+name); return i; }
function box(par,w,h,name,o={}){ const f=AL('HORIZONTAL',name,{justify:'CENTER',...o}); par.appendChild(f); f.resize(w,h); f.primaryAxisSizingMode='FIXED'; f.counterAxisSizingMode='FIXED'; return f; }
const pk=(set,pre)=>Object.keys(set.componentPropertyDefinitions).find(k=>k.split('#')[0]===pre);
const C={}; for(const [k,id] of Object.entries({btn:'285:20238',tag:'285:20260',pstate:'287:506',stat:'285:20262',field:'276:638',popup:'276:739',swRow:'278:311',erow:'278:407',sw:'276:302',step:'291:61016',opt:'291:61054',row:'291:61114',arow:'291:61126',menu:'291:61128',spec:'291:61149',header:'291:66013',cons:'291:66015',roster:'291:66095',req:'291:66097',order:'291:66210',bart:'291:70467',btile:'291:70507',confirm:'290:20572',result:'290:20551'})) C[k]=await figma.getNodeByIdAsync(id);
const V_=(set,q)=>set.type==='COMPONENT_SET'?(set.children.find(c=>Object.entries(q).every(([k,v])=>c.name.split(', ').includes(`${k}=${v}`)))||set.defaultVariant):set;
function inst(key,q={},props={}){ const set=C[key]; const i=V_(set,q).createInstance(); const pp={}; for(const [k,v] of Object.entries(props)){ const kk=pk(set,k); if(kk) pp[kk]=v; } if(Object.keys(pp).length) i.setProperties(pp); return i; }
function btn(par,kind,label,state='Default',size='44'){ const b=inst('btn',{Kind:kind,Size:size,State:state},{Label:label}); par.appendChild(b); b.name='button/'+kind.toLowerCase(); return b; }
function tag(par,state,label){ const t=inst('tag',{State:state},{Label:label}); par.appendChild(t); return t; }
function clearBelow(fr,y0,keep=[]){ for(const c of [...fr.children]) if(c.y>=y0 && !keep.includes(c.id)) c.remove(); }
function shift(fr,y0,dy,except=[]){ for(const c of fr.children) if(c.y>=y0 && !except.includes(c.id)) c.y+=dy; }
async function NOTE(fr, text, tag='', color='y'){ const par=fr.parent; const nm=`note:${fr.id}${tag?':'+tag:''}`; const old=par.children.find(c=>c.name===nm); if(old) old.remove();
 const n=figma.createAutoLayout('VERTICAL'); par.appendChild(n); n.name=nm; n.fills=[{type:'SOLID',color:color==='b'?{r:0.89,g:0.94,b:1}:color==='g'?{r:0.87,g:0.97,b:0.88}:{r:1,g:0.957,b:0.761}}]; n.cornerRadius=6; n.paddingTop=n.paddingBottom=6; n.paddingLeft=n.paddingRight=8; n.counterAxisSizingMode='FIXED'; n.resize(Math.min(fr.width,393),n.height);
 const t=figma.createText(); n.appendChild(t); t.fontName={family:'SF Pro',style:'Regular'}; t.fontSize=11; t.lineHeight={unit:'PIXELS',value:15}; t.characters=text; t.fills=[{type:'SOLID',color:color==='b'?{r:0.08,g:0.2,b:0.45}:color==='g'?{r:0.05,g:0.3,b:0.1}:{r:0.25,g:0.2,b:0.05}}]; t.layoutSizingHorizontal='FILL'; t.textAutoResize='HEIGHT';
 const mine=par.children.filter(c=>c!==n&&c.name.startsWith(`note:${fr.id}`)); let y=fr.y+fr.height+10; for(const m of mine) y=Math.max(y,m.y+m.height+6); n.x=fr.x; n.y=y;
 if(par.type==='SECTION'&&n.y+n.height+24>par.height) par.resizeWithoutConstraints(par.width,n.y+n.height+40); return n.id; }
async function setTxt(t,s){ for(const seg of t.getStyledTextSegments(['fontName'])) await figma.loadFontAsync(seg.fontName); t.characters=s; }
function bottomBar(fr,o={}){ const bb=AL('VERTICAL','bottom bar',{pad:[12,16,34,16],gap:8,fill:'bg'}); fr.appendChild(bb); bb.resize(393,10); bb.counterAxisSizingMode='FIXED'; bb.primaryAxisSizingMode='AUTO'; bb.x=0; return bb; }
function pinBottom(fr,bb){ bb.y=fr.height-bb.height; bb.constraints={horizontal:'STRETCH',vertical:'MAX'}; }
