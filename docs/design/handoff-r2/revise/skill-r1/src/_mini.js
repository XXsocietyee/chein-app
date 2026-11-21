const R={item:ITEM,created:[],touched:[],removed:[],ann:[],warn:[],info:{}};
const byId=id=>figma.getNodeByIdAsync(id);
async function goPage(id){ let pg=await byId(id); while(pg.type!=='PAGE') pg=pg.parent; await figma.setCurrentPageAsync(pg); return pg; }
for(const s of ['Regular','Medium','Semibold','Bold']) await figma.loadFontAsync({family:'SF Pro',style:s});
const V={}, VI={}; for(const v of await figma.variables.getLocalVariablesAsync()){ VI[v.id]=v; if(!V[v.name]) V[v.name]=v; }
const COLS={}; for(const c of await figma.variables.getLocalVariableCollectionsAsync()) COLS[c.id]=c;
const TS={}; for(const s of await figma.getLocalTextStylesAsync()) TS[s.name]=s;
function rawOf(v){ const c=COLS[v.variableCollectionId]; const m=c.modes[0]; let val=v.valuesByMode[m.modeId], g=0; while(val&&val.type==='VARIABLE_ALIAS'&&g++<6){ const a=VI[val.id]; const ac=COLS[a.variableCollectionId]; val=a.valuesByMode[ac.modes[0].modeId]; } return val&&'r' in val?val:{r:0,g:0,b:0}; }
function PAINT(name){ const v=V[name]; if(!v){ R.warn.push('novar '+name); return {type:'SOLID',color:{r:1,g:0,b:1}}; } const raw=rawOf(v); return figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:raw.r,g:raw.g,b:raw.b}},'color',v); }
const texts=n=>!n?[]:(n.type==='TEXT'?[n]:('findAllWithCriteria' in n?n.findAllWithCriteria({types:['TEXT']}):[]));
async function loadFontsOf(t){ for(const s of t.getStyledTextSegments(['fontName'])) await figma.loadFontAsync(s.fontName); }
async function setT(t,s){ if(!t||t.characters===s) return; await loadFontsOf(t); t.characters=s; R.touched.push(t.id); }
async function TX(par,s,style,color,o={}){ const t=figma.createText(); t.fontName={family:'SF Pro',style:'Regular'}; await t.setTextStyleIdAsync(TS[style].id); t.characters=s; t.fills=[PAINT(color)]; t.name=o.name||s.slice(0,24); if(par) par.appendChild(t); R.created.push(t.id); return t; }
const variant=(set,props)=>set.children.find(v=>Object.entries(props).every(([k,val])=>v.name.split(', ').includes(`${k}=${val}`)));
const CATS=await figma.annotations.getAnnotationCategoriesAsync(); const DCAT=(CATS.find(c=>/^develop/i.test(c.label))||{}).id;
function SR(node,id,what){ if(!node) return; try{ node.annotations=[...(node.annotations||[]).filter(a=>!(a.labelMarkdown||'').startsWith('**skill-r1 '+id)).map(a=>{ const o={labelMarkdown:a.labelMarkdown||a.label}; if(a.categoryId) o.categoryId=a.categoryId; return o; }),{labelMarkdown:`**skill-r1 ${id}** · ${what}`,categoryId:DCAT}]; R.ann.push(node.id); }catch(e){ R.warn.push('ann '+String(e).slice(0,60)); } }
const actsOf=r=>(r.actions&&r.actions.length?r.actions:(r.action?[r.action]:[]));
const SPRING={sheet:[273,28.4],push:[195,24.0],press:[439,33.5],result:[224,23.9],moment:[247,17.3]};
const SP=k=>({type:'CUSTOM_SPRING',easingFunctionSpring:{mass:1,stiffness:SPRING[k][0],damping:SPRING[k][1]}});
const DUR={sheet:0.35,push:0.4,press:0.25,result:0.4,moment:0.6};
