// B1a · Library 6:3 · SR1-22 (district vars, City/Deed Card), SR1-04 (Media/Cover), SR1-08 (Club/Default Cover), SR1-29 (info-ink), SR1-31 (me), SR1-47a (Motion collection), SR1-42 (button-radius)
await goPage(LIB);
const colC=Object.values(COLS).find(c=>c.name==='Color');
const isLight=m=>/Light/.test(m.name);
function hex(h,a=1){ h=h.replace('#',''); return {r:parseInt(h.slice(0,2),16)/255,g:parseInt(h.slice(2,4),16)/255,b:parseInt(h.slice(4,6),16)/255,a}; }
function mkVar(name,col,type,scopes,vals,syntax){ let v=Object.values(VI).find(x=>x.name===name&&x.variableCollectionId===col.id); if(!v){ v=figma.variables.createVariable(name,col,type); R.created.push(v.id); } v.scopes=scopes; for(const m of col.modes){ const val=typeof vals==='function'?vals(m):vals; v.setValueForMode(m.modeId,val); } if(syntax){ v.setVariableCodeSyntax('iOS',syntax); v.setVariableCodeSyntax('WEB',`var(--${name.replace(/\//g,'-')})`); } V[name]=v; VI[v.id]=v; return v; }
// districts: Shanghai enamel street-sign blue first; hues kept away from status colours by place (band, cells, chip only · Q2)
const D=[['武康路','2F6BD8','4F86EA'],['安福路','1E9E86','35B39A'],['愚园路','E07F24','F0954A'],['湖南路','C9468A','DC6AA4'],['复兴西路','7B5CD6','9479E6'],['衡山路','A26F35','BC8A50']];
D.forEach(([nm,light,dark],i)=>{ const n=i+1;
  mkVar(`district/${n}`,colC,'COLOR',['FRAME_FILL','SHAPE_FILL','STROKE_COLOR'],m=>hex(isLight(m)?light:dark),`Color.district${n}`).description=`District ${n} (${nm}). Only on the deed band, map cells and the district chip (skill-r1 Q2).`;
  mkVar(`district/${n}-soft`,colC,'COLOR',['FRAME_FILL','SHAPE_FILL'],m=>hex(isLight(m)?light:dark,isLight(m)?0.14:0.22),`Color.district${n}Soft`).description=`District ${n} soft fill: my cells, outline deeds.`; });
mkVar('info-ink',colC,'COLOR',['TEXT_FILL'],m=>hex(isLight(m)?'1F5FCC':'8FB6FF'),'Color.infoInk').description='Tag label on info-soft (5.7:1). skill-r1 SR1-29.';
{ const me=mkVar('me',colC,'COLOR',['FRAME_FILL','SHAPE_FILL','STROKE_COLOR','TEXT_FILL'],m=>hex('000000'),'Color.me'); for(const m of colC.modes) me.setValueForMode(m.modeId,{type:'VARIABLE_ALIAS',id:V['info'].id}); me.description='Me: my pins, my cells outline, my position. One hue, nothing else (skill-r1 SR1-31).'; }
// Motion collection (FLOAT, hidden from pickers)
let colM=Object.values(COLS).find(c=>c.name==='Motion'); if(!colM){ colM=figma.variables.createVariableCollection('Motion'); colM.renameMode(colM.modes[0].modeId,'Value'); R.created.push(colM.id); COLS[colM.id]=colM; }
const MV=[['duration/press',80],['duration/quick',250],['duration/sheet',350],['duration/push',400],['duration/moment',600],
 ['spring/sheet-response',.38],['spring/sheet-damping',.86],['spring/push-response',.45],['spring/push-damping',.86],['spring/press-response',.30],['spring/press-damping',.80],['spring/result-response',.42],['spring/result-damping',.80],['spring/moment-response',.40],['spring/moment-damping',.55],
 ['figma/sheet-stiffness',273],['figma/sheet-damping',28.4],['figma/push-stiffness',195],['figma/push-damping',24.0],['figma/press-stiffness',439],['figma/press-damping',33.5],['figma/result-stiffness',224],['figma/result-damping',23.9],['figma/moment-stiffness',247],['figma/moment-damping',17.3]];
for(const [n,v] of MV) mkVar(n,colM,'FLOAT',[],v,'Motion.'+n.replace(/[\/-](\w)/g,(a,b)=>b.toUpperCase()));
// button-radius per role (Q4: no visual change; one value switches it in round 2)
let colS=Object.values(COLS).find(c=>c.name==='Role Shape'); if(!colS){ colS=figma.variables.createVariableCollection('Role Shape'); colS.renameMode(colS.modes[0].modeId,'Player'); colS.addMode('Merchant'); colS.addMode('Editor'); R.created.push(colS.id); COLS[colS.id]=colS; }
const br=mkVar('button-radius',colS,'FLOAT',['CORNER_RADIUS'],m=>m.name==='Merchant'?12:999,'Shape.buttonRadius'); br.description='skill-r1 SR1-42 / Q4: Player 999, Merchant 12, Editor 999. Round 2 can set Merchant to 999 (capsule) with one change.';
const modeOf=n=>colS.modes.find(m=>m.name===n).modeId; let bound=0;
const bindBtn=n=>{ for(const c of ['topLeftRadius','topRightRadius','bottomLeftRadius','bottomRightRadius']) n.setBoundVariable(c,br); bound++; };
const pbtn=await byId(PBTN); for(const v of pbtn.children) if(v.type==='COMPONENT') bindBtn(v); pbtn.setExplicitVariableModeForCollection(colS,modeOf('Player'));
const mbtn=await byId('316:4734'); if(mbtn){ for(const v of (mbtn.type==='COMPONENT_SET'?mbtn.children:[mbtn])) if(v.type==='COMPONENT'&&v.cornerRadius>0) bindBtn(v); mbtn.setExplicitVariableModeForCollection(colS,modeOf('Merchant')); }
const ebar=await byId('280:593'); if(ebar){ for(const v of (ebar.type==='COMPONENT_SET'?ebar.children:[ebar])){ for(const b of v.findAll(x=>(x.type==='FRAME'||x.type==='RECTANGLE')&&x.cornerRadius>=18&&x.height>=40&&x.height<=56)) bindBtn(b); } ebar.setExplicitVariableModeForCollection(colS,modeOf('Editor')); }
R.info.buttonRadiusBound=bound;
// ---------- Media/Cover (SR1-04): place photos already in the file ----------
const sec=await byId(PKIT);
const src=await byId('123:1497'); const photos=[]; const seen=new Set();
if(src){ for(const n of src.findAll(n=>'fills' in n&&Array.isArray(n.fills)&&n.fills.some(f=>f.type==='IMAGE'&&f.visible!==false))){ const f=n.fills.find(f=>f.type==='IMAGE'); if(seen.has(f.imageHash)||n.width<120) continue; seen.add(f.imageHash); photos.push({h:f.imageHash,name:n.name}); } }
R.info.photoSource=src?src.name:'missing'; R.info.photoNames=photos.map(p=>p.name).slice(0,20);
const PLACES=photos.slice(0,6).map((p,i)=>({key:'Place '+(i+1),h:p.h,src:p.name}));
const covers=[];
for(const ratio of ['16:9','1:1']) for(const pl of [...PLACES,{key:'Default',h:null}]){
  const w=ratio==='16:9'?320:160, h=ratio==='16:9'?180:160; const c=figma.createComponent(); c.name=`Ratio=${ratio}, Place=${pl.key}`; c.resize(w,h); c.clipsContent=true;
  if(pl.h){ c.fills=[{type:'IMAGE',imageHash:pl.h,scaleMode:'FILL'}]; const sh=RECT(c,w,Math.round(h*0.45),null,{name:'media-shade',x:0,y:h-Math.round(h*0.45)}); sh.fills=[{type:'GRADIENT_LINEAR',gradientTransform:[[0,1,0],[-1,0,1]],gradientStops:[{position:0,color:{r:0,g:0,b:0,a:0}},{position:1,color:{r:0,g:0,b:0,a:0.35}}]}]; sh.constraints={horizontal:'STRETCH',vertical:'MAX'}; }
  else { fillV(c,'surface-2'); const g=await IC(null,'map',ratio==='16:9'?40:32,'ink-3','glyph'); c.appendChild(g); g.x=(w-g.width)/2; g.y=(h-g.height)/2; g.constraints={horizontal:'CENTER',vertical:'CENTER'}; }
  covers.push(c); R.created.push(c.id); }
const coverSet=await SETOF(covers,'Media/Cover',PLACES.length+1,'skill-r1 SR1-04 / Q10. Place photos already in this file (no stock photos of people). Ratio 16:9 for heroes and deeds, 1:1 for rows, rails and chat tiles. Place=Default when no photo exists. Resize freely: the image fills.',sec);
await placeIn(sec,coverSet,'Media/Cover · Ratio × Place (skill-r1 SR1-04)');
const cov=(ratio,place)=>variant(coverSet,{Ratio:ratio,Place:place})||variant(coverSet,{Ratio:ratio,Place:'Default'});
// ---------- City/Deed Card (SR1-22) ----------
newRow();
const STATES=['Mine','Other','Protected','Challengeable','Claimable','Weathered','Unlit'];
const tagSet=await byId(STAT_TAG);
async function tag(par,state,label){ const v=variant(tagSet,{State:state})||tagSet.children[0]; const i=v.createInstance(); par.appendChild(i); setProps(i,{Label:label}); i.name='status'; R.created.push(i.id); return i; }
async function pips(par,lv,onSolid){ const r=AL('HORIZONTAL','pips',{gap:4}); par.appendChild(r); for(let k=0;k<3;k++){ const e=ELL(r,6,k<lv?(onSolid?'on-solid':'ink'):null,{name:k<lv?'pip on':'pip off'}); if(k>=lv) strokeV(e,onSolid?'on-solid':'ink-3',1); } return r; }
async function coin(par,size){ const c=AL('HORIZONTAL','coin',{w:size,h:size,r:size/2,fill:'gold',justify:'CENTER'}); par.appendChild(c); const t=await TX(c,'积','role/badge-count','on-solid',{name:'coin glyph'}); t.fontSize=Math.round(size*0.58); return c; }
const HOLD={Mine:['你持有 · 第 3 天',null],Other:['林小舟 持有',null],Protected:['林小舟 持有',['Neutral','保护 · 11:42 后结束']],Challengeable:['林小舟 持有',['Live','可挑战']],Weathered:['你持有',['Warning','风化 · 9 天未到']],Claimable:['无人持有',['Neutral','可圈地 · 120 积分']],Unlit:['走到这里点亮',null]};
const deeds=[];
for(const size of ['Full','Row','Mini']) for(const st of STATES){
  const outline=st==='Claimable'||st==='Unlit'; const name=st==='Unlit'?'未点亮的地点':'武康大楼'; const rent=outline?'—':'+12';
  const c=figma.createComponent(); c.name=`Size=${size}, State=${st}`; c.clipsContent=true; R.created.push(c.id);
  if(outline){ c.fills=[]; strokeV(c,'sep-strong',1,[4,3]); } else fillV(c,'surface');
  if(size==='Full'){ c.layoutMode='VERTICAL'; c.primaryAxisSizingMode='FIXED'; c.counterAxisSizingMode='FIXED'; c.resize(329,420); bindR(c,'r-lg');
    const band=add(c,AL('HORIZONTAL','band',{pad:[0,16],gap:8,h:44,fill:'district/1'}),'FILL'); 
    await TX(band,'武康路街区','role/tag','on-solid',{name:'district'}); const sp=add(band,AL('HORIZONTAL','spacer'),'FILL'); await TX(band,'地契 · No. 07','role/tag','on-solid',{name:'deed no'});
    if(outline){ const ph=add(c,AL('VERTICAL','photo',{h:185,fill:'district/1-soft',justify:'CENTER'}),'FILL'); await IC(ph,st==='Unlit'?'info':'plus-c',36,'ink-3'); }
    else { const ph=cov('16:9','Place 1').createInstance(); c.appendChild(ph); ph.layoutSizingHorizontal='FILL'; ph.resize(329,185); ph.name='photo'; ph.isExposedInstance=true; R.created.push(ph.id); }
    const body=add(c,AL('VERTICAL','body',{pad:[16,16,16,16],gap:8,align:'MIN'}),'FILL','FILL');
    await TX(body,name,'t-2','ink',{name:'name'});
    const lvr=add(body,AL('HORIZONTAL','level',{gap:8}),'FILL'); await pips(lvr,outline?0:2,false); await TX(lvr,outline?'Lv 0':'Lv 2 · 插旗','t-foot','ink-2',{name:'level'});
    const rr=add(body,AL('HORIZONTAL','rent',{gap:8,align:'CENTER'}),'FILL'); await coin(rr,22); await TX(rr,rent,'role/stat',outline?'ink-3':'ink',{name:'rent'}); await TX(rr,'积分 · 每次到访','t-foot','ink-3',{name:'rent caption'});
    const sp2=add(body,AL('VERTICAL','spacer'),'FILL','FILL');
    const hr=add(body,AL('HORIZONTAL','holder',{gap:8}),'FILL'); const av=AL('HORIZONTAL','avatar',{w:28,h:28,r:14,fill:st==='Mine'||st==='Weathered'?'me':'surface-3',justify:'CENTER'}); hr.appendChild(av); await TX(av,st==='Mine'||st==='Weathered'?'我':'林','role/tag','on-solid',{name:'initial'}); if(outline) av.visible=false;
    await TX(hr,HOLD[st][0],'t-foot','ink-2',{name:'holder'}); add(hr,AL('HORIZONTAL','spacer'),'FILL'); if(HOLD[st][1]) await tag(hr,...HOLD[st][1]);
  } else if(size==='Row'){ c.layoutMode='HORIZONTAL'; c.primaryAxisSizingMode='FIXED'; c.counterAxisSizingMode='FIXED'; c.resize(361,72); bindR(c,'r-md'); c.paddingLeft=c.paddingRight=12; c.itemSpacing=12; c.counterAxisAlignItems='CENTER';
    const th=AL('VERTICAL','thumb',{w:48,h:48,r:10,clip:true,fill:outline?'district/1-soft':null,justify:'CENTER'}); c.appendChild(th); add(th,AL('HORIZONTAL','band',{h:8,fill:'district/1'}),'FILL'); if(outline){ await IC(th,st==='Unlit'?'info':'plus-c',20,'ink-3'); } else { const ph=cov('1:1','Place 1').createInstance(); th.appendChild(ph); ph.layoutSizingHorizontal='FILL'; ph.layoutSizingVertical='FILL'; ph.name='photo'; ph.isExposedInstance=true; }
    const col=add(c,AL('VERTICAL','text',{gap:2,align:'MIN'}),'FILL'); await TX(col,name,'t-head','ink',{name:'name'}); const sub=add(col,AL('HORIZONTAL','sub',{gap:6}),'FILL'); ELL(sub,8,'district/1',{name:'district dot'}); await TX(sub,'武康路','t-foot','ink-2',{name:'district'}); await TX(sub,outline?'Lv 0':'Lv 2','t-foot','ink-2',{name:'level'});
    const tr=AL('VERTICAL','trail',{gap:2,align:'MAX'}); c.appendChild(tr);
    if(HOLD[st][1]&&st!=='Claimable') await tag(tr,...HOLD[st][1]); else { const rr=add(tr,AL('HORIZONTAL','rent',{gap:4})); await coin(rr,16); await TX(rr,st==='Claimable'?'120':rent,'t-3',outline?'ink-2':'ink',{name:'rent'}); await TX(tr,st==='Claimable'?'圈地':'每次到访','t-cap','ink-3',{name:'rent caption'}); }
  } else { c.layoutMode='VERTICAL'; c.primaryAxisSizingMode='FIXED'; c.counterAxisSizingMode='FIXED'; c.resize(96,120); bindR(c,'r-sm'); c.counterAxisAlignItems='MIN';
    const band=add(c,AL('HORIZONTAL','band',{pad:[0,8],h:20,fill:'district/1'}),'FILL'); await TX(band,'武康路','role/tag','on-solid',{name:'district'});
    if(outline){ const ph=add(c,AL('VERTICAL','photo',{h:52,fill:'district/1-soft',justify:'CENTER'}),'FILL'); await IC(ph,st==='Unlit'?'info':'plus-c',20,'ink-3'); } else { const ph=cov('16:9','Place 1').createInstance(); c.appendChild(ph); ph.layoutSizingHorizontal='FILL'; ph.resize(96,52); ph.name='photo'; ph.isExposedInstance=true; }
    const body=add(c,AL('VERTICAL','body',{pad:[6,8,8,8],gap:2,align:'MIN'}),'FILL','FILL'); const nm=await TX(body,name,'role/pin-label','ink',{name:'name'}); nm.layoutSizingHorizontal='FILL'; nm.textTruncation='ENDING'; nm.maxLines=1;
    const rr=add(body,AL('HORIZONTAL','rent',{gap:4})); if(!outline) await coin(rr,12); await TX(rr,outline?(st==='Unlit'?'未点亮':'可圈地'):'+12 / 次','t-cap',outline?'ink-3':'ink-2',{name:'rent'});
  }
  deeds.push(c); }
const deedSet=await SETOF(deeds,'City/Deed Card',7,'skill-r1 SR1-22 · the signature object of City Monopoly: a Monopoly title deed crossed with a Shanghai enamel street sign. Band = district colour (district/n; override the band fill per place). Photo = the holder\'s claim photo, or the partner shop\'s storefront, or the outline when unlit (Owner default skill-r1 Q3). Full 329×420 for sheets and results, Row 361×72 for lists, Mini 96×120 for rails and pin callouts. 积分 is the only currency.',sec);
let np=0; np+=tprop(deedSet,'名称','武康大楼','name'); np+=tprop(deedSet,'街区','武康路街区','district'); np+=tprop(deedSet,'等级','Lv 2 · 插旗','level'); np+=tprop(deedSet,'租金','+12','rent');

await placeIn(sec,deedSet,'City/Deed Card · Size × State (skill-r1 SR1-22 · Q2 · Q3)');
OWN(deedSet,'Q2','District colours appear only on the deed band, map cells and the district chip.');
// ---------- Club/Default Cover (SR1-08): neutral, one glyph + initial per type (district colours are reserved by Q2) ----------
const csec=await byId(CKIT); _px=null; _py=null; _rowH=0;
const TYPES=[['校园社团','badge','校'],['旅行组织','route','旅'],['兴趣社群','heart','兴'],['商业活动组织方','store','商'],['内容创作团队','camera','创'],['其他','grid','其']];
const SURF=['surface-2','surface-3','surface-2','surface-3','surface-2','surface-3']; const ccs=[];
for(let i=0;i<TYPES.length;i++){ const [t,g,ini]=TYPES[i]; const c=figma.createComponent(); c.name=`Type=${t}`; c.resize(393,150); c.clipsContent=true; fillV(c,SURF[i]);
  const big=await TX(c,ini,'t-hero','ink',{name:'initial'}); big.fontSize=96; big.opacity=0.12; big.x=393-big.width-24; big.y=150-big.height+18;
  const gi=await IC(c,g,24,'ink-2','type glyph'); gi.x=16; gi.y=16;
  for(let k=0;k<5;k++){ const ln=RECT(c,393,1,'sep',{name:'texture',x:0,y:30+k*24}); ln.rotation=-12; ln.opacity=0.5; }
  ccs.push(c); R.created.push(c.id); }
const ccSet=await SETOF(ccs,'Club/Default Cover',3,'skill-r1 SR1-08. The default cover per club type (the six types of the create wizard): neutral surface, one glyph, the type initial large at 12%. A club that uploads a photo uses Media/Cover instead. District colours are not used here (Owner default skill-r1 Q2).',csec);
await placeIn(csec,ccSet,'Club/Default Cover · Type (skill-r1 SR1-08)');
OWN(ccSet,'Q2','No district colour on club covers; the six types differ by glyph, initial and surface step.');
await deedSet.screenshot({scale:0.5});
R.info.ids={coverSet:coverSet.id,deedSet:deedSet.id,ccSet:ccSet.id,colM:colM.id,colS:colS.id,textProps:np};
R.created=R.created.length; return R;
