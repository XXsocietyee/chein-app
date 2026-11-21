const JOBS=__JOBS__;
const page=await figma.getNodeByIdAsync('235:178'); await figma.setCurrentPageAsync(page);
for(const s of ['Regular','Medium','Semibold','Bold']) await figma.loadFontAsync({family:'SF Pro',style:s});
const V={}; for(const v of await figma.variables.getLocalVariablesAsync()) if(!V[v.name]) V[v.name]=v;
const TS={}; for(const s of await figma.getLocalTextStylesAsync()) TS[s.name]=s;
const P=(n)=>figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:0,g:0,b:0}},'color',V[n]);
const SB=await figma.getNodeByIdAsync('290:16299'), CARD=await figma.getNodeByIdAsync('290:16320'), FIELD=await figma.getNodeByIdAsync('276:638'), POP=await figma.getNodeByIdAsync('276:739'), SWR=await figma.getNodeByIdAsync('278:311');
const cardCol=CARD.children.find(c=>c.name==='Collapsed=true'), cardExp=CARD.children.find(c=>c.name==='Collapsed=false');
const ck=n=>Object.keys(CARD.componentPropertyDefinitions).find(x=>x.startsWith(n+'#'));
const fk=n=>Object.keys(FIELD.componentPropertyDefinitions).find(x=>x.startsWith(n+'#')); const pk=n=>Object.keys(POP.componentPropertyDefinitions).find(x=>x.startsWith(n+'#'));
const swk=Object.keys(SWR.componentPropertyDefinitions).find(x=>x.startsWith('label#'));
const GROUP={'模板信息':'信息','玩法规则':'规则','参与方式':'规则','玩法':'玩法','玩法设置':'玩法','结果反馈':'反馈','提示':'反馈','反馈分段（本站内）':'反馈','反馈分段':'反馈','完成奖励':'奖励','互动工具':'工具'};
const BAR=['信息','规则','玩法','反馈','奖励','工具'];
const clean=s=>s.replace(/\s*\*$/,'').trim();
function summarize(c,title){ const out=[];
 const steps=c.children.filter(k=>/^step \d+/.test(k.name)).length; if(steps) out.push(`${steps} 步`);
 const cg=c.findOne(n=>n.name==='chosen gameplay'); if(cg){ const t=cg.findAll(n=>n.type==='TEXT').find(t=>t.characters.length>1&&t.characters!=='更换'); if(t) out.push(t.characters); }
 for(const sw of c.findAll(n=>n.type==='FRAME'&&n.name.startsWith('switch row/'))){ const s=sw.findOne(n=>n.type==='INSTANCE'&&n.mainComponent&&/State=On/.test(n.mainComponent.name)); if(s) out.push(sw.name.slice(11)); }
 for(const sw of c.findAll(n=>n.type==='INSTANCE'&&n.mainComponent&&n.mainComponent.id==='278:311')){ const s=sw.findOne(n=>n.type==='INSTANCE'&&/State=On/.test(n.mainComponent?n.mainComponent.name:'')); if(s) out.push(sw.componentProperties[swk].value); }
 for(const i of c.findAll(n=>n.type==='INSTANCE'&&n.mainComponent&&n.mainComponent.parent&&['Editor/Field','Editor/PopUp'].includes(n.mainComponent.parent.name)&&/State=Filled/.test(n.mainComponent.name))){ const isF=i.mainComponent.parent.name==='Editor/Field'; const v=i.componentProperties[isF?fk('value'):pk('value')].value; if(v&&v.length<=14&&!out.includes(v)) out.push(v); }
 for(const t of c.findAll(n=>n.type==='FRAME'&&n.name.startsWith('tool row/'))) out.push(t.name.slice(9));
 for(const ch of c.findAll(n=>n.type==='TEXT'&&n.parent&&/chip|tag/i.test(n.parent.name)&&n.characters.length<10&&n.characters!=='×')) if(!out.includes(ch.characters)) out.push(ch.characters);
 if(!out.length){ if(title==='提示') return '未启用'; if(c.findOne(n=>n.name.startsWith('cg-cfg-add'))) return '未添加'; return '未设置'; }
 return out.slice(0,3).join(' · '); }
function collapse(B,tName,keep,done){ const t=B.children.find(k=>k.name===tName); if(!t) return; const title=clean(tName.slice(2)); const cName='c/'+title.replace(/（本站内）/,''); const c=B.children.find(k=>k.name===cName)||B.children.find(k=>k.name==='c/'+title);
 if(!c) return; if(keep.has(title)) { if(!t.findOne(n=>n.name==='chevron · hit 44')){ const ch=cardExp.findOne(n=>n.name==='chevron · hit 44').clone(); t.appendChild(ch); } return; }
 const inst=cardCol.createInstance(); B.insertChild(B.children.indexOf(t),inst); inst.layoutSizingHorizontal='FILL'; inst.name='card (collapsed)/'+title;
 inst.setProperties({[ck('title')]:title,[ck('summary')]:summarize(c,title)}); t.remove(); c.remove(); done.push(title); }
function hero(B){ const H=B.children.find(k=>k.name==='hero'); if(!H) return 'nohero'; const cover=H.children.find(k=>k.name.startsWith('cover')); const ti=H.children.find(k=>k.name==='title input'); if(!cover||!ti) return 'skip';
 const texts=ti.findAll(n=>n.type==='TEXT'); const title=texts[0]?texts[0].characters:''; const placeholder=texts[0]&&texts[0].fills[0]&&texts[0].fills[0].color&&texts[0].fills[0].color.r>0.5; const errs=texts.filter(t=>t.name==='cy-inline-error'||(t.fills[0]&&t.fills[0].color&&t.fills[0].color.r>0.75&&t.fills[0].color.g<0.45));
 const oldH=cover.height; cover.resizeWithoutConstraints(361,203); cover.clipsContent=true; cover.name='cover 16:9';
 for(const k of cover.children){ if(k.name==='clear ✕'||k.name==='diagonal stripes'||k.name.startsWith('img')) continue; k.y=Math.round(k.y-(oldH-203)/2-18); }
 const g=figma.createRectangle(); g.name='title gradient'; cover.appendChild(g); g.resize(361,120); g.x=0; g.y=83; g.fills=[{type:'GRADIENT_LINEAR',gradientTransform:[[0,1,0],[-1,0,1]],gradientStops:[{position:0,color:{r:0,g:0,b:0,a:0}},{position:1,color:{r:0,g:0,b:0,a:0.62}}]}]; g.constraints={horizontal:'STRETCH',vertical:'MAX'};
 const x=cover.children.find(k=>k.name==='clear ✕'); if(x) cover.appendChild(x);
 const row=figma.createAutoLayout('HORIZONTAL'); row.name='title overlay'; row.fills=[]; row.itemSpacing=6; row.counterAxisAlignItems='CENTER'; cover.appendChild(row);
 const t=figma.createText(); row.appendChild(t); t.fontName={family:'SF Pro',style:'Bold'}; t.fontSize=22; t.lineHeight={unit:'PIXELS',value:28}; t.characters=title||'给这个玩法起个名字'; t.name='title'; t.fills=placeholder?[{type:'SOLID',color:{r:1,g:1,b:1},opacity:0.72}]:[P('on-media')];
 const pen=figma.createNodeFromSvg('<svg width="16" height="16" viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg"><path d="M10.6 2.6l2.8 2.8-7.9 7.9H2.7v-2.8z" fill="none" stroke="#FFFFFF" stroke-width="1.5" stroke-linejoin="round"/></svg>'); pen.name='edit'; row.appendChild(pen);
 row.x=16; row.y=203-16-28; row.constraints={horizontal:'MIN',vertical:'MAX'};
 if(errs.length){ const e=figma.createAutoLayout('HORIZONTAL'); e.name='title error'; e.fills=[]; e.paddingLeft=e.paddingRight=14; e.paddingTop=8; e.paddingBottom=10; H.appendChild(e); e.layoutSizingHorizontal='FILL'; const et=figma.createText(); e.appendChild(et); et.fontName={family:'SF Pro',style:'Regular'}; et.fontSize=12; et.lineHeight={unit:'PIXELS',value:16}; et.characters=errs.map(x=>x.characters).join(' '); et.fills=[P('bad')]; }
 ti.remove(); return 'ok'; }
function moveChips(B){ const ps=B.children.find(k=>k.name==='c/玩法设置'); if(!ps) return; for(const nm of ['需要的资源','可触发的结果']){ const b=B.children.find(k=>k.name===nm); if(!b) continue; b.fills=[]; b.strokes=[]; b.paddingLeft=b.paddingRight=0; b.paddingBottom=0; b.paddingTop=12; b.strokes=[P('sep')]; b.strokeTopWeight=0.5; b.strokeBottomWeight=0; b.strokeLeftWeight=0; b.strokeRightWeight=0; b.strokeAlign='INSIDE'; b.cornerRadius=0; ps.appendChild(b); b.layoutSizingHorizontal='FILL'; b.name=nm+' (read-only chips)';
  for(const r of b.findAll(n=>n.type==='FRAME'&&n.name==='row'&&n.parent.name==='row')){} } const tb=B.children.find(k=>k.name==='试玩 text button'); if(tb) tb.remove(); }
async function run(F,cfg){ const B=F.children.find(c=>c.name==='scroll body'); if(!B) return F.id+' nobody';
 const oldBodyBottomGap=F.height-(B.y+B.height); const isFull=/full/.test(F.name);
 let anchorNode=null, anchorY=null; if(cfg.anchor){ anchorNode=B.children.find(k=>k.name===cfg.anchor); anchorY=cfg.y+44; }
 const hr=hero(B); moveChips(B);
 const place=()=>{ if(anchorNode) B.y=anchorY-anchorNode.y; else B.y=144; };
 place();
 const keep=new Set(['玩法设置',...(cfg.keep||[])]);
 if(!isFull&&anchorNode){ for(const k of B.children){ if(!/^[tc]\//.test(k.name)) continue; const y=B.y+k.y; if(y<852-85&&y+k.height>144){ keep.add(clean(k.name.slice(2))); if(k.name==='c/反馈分段') keep.add('反馈分段（本站内）'); } } }
 const done=[]; if(!cfg.noCollapse){ for(const k of [...B.children]) if(!k.removed&&k.name.startsWith('t/')) collapse(B,k.name,keep,done); }
 else { for(const k of [...B.children]) if(!k.removed&&k.name.startsWith('t/')) collapse(B,k.name,new Set(B.children.filter(x=>x.name.startsWith('t/')).map(x=>clean(x.name.slice(2)))),done); }
 place();
 // section bar
 const nav=F.children.find(c=>c.name==='Editor/Nav Bar'); const bar=SB.createInstance(); F.insertChild(nav?F.children.indexOf(nav):F.children.length,bar); bar.x=0; bar.y=100; bar.name='section bar (sticky)';
 const cur=cfg.current||(()=>{ if(!anchorNode) return '信息'; let i=B.children.indexOf(anchorNode); for(;i>=0;i--){ const k=B.children[i]; if(/^[tc]\//.test(k.name)) return GROUP[clean(k.name.slice(2))]||'玩法'; if(k.name.startsWith('card (collapsed)/')) return GROUP[k.name.split('/')[1]]||'玩法'; } return '信息'; })();
 const collapsedGroups=new Set(done.map(t=>GROUP[t])); const expandedGroups=new Set([...keep].map(t=>GROUP[t]));
 bar.children.forEach((it,i)=>{ const g=BAR[i]; let st='Default'; if((cfg.err||[]).includes(g)) st='Error'; else if(g===cur) st='Current'; else if(collapsedGroups.has(g)&&!expandedGroups.has(g)) st='Done'; it.setProperties({State:st}); });
 // overlays
 for(const o of F.children.filter(c=>c.name.startsWith('cy-dropdown'))) o.y+=44;
 // bottom bar label
 const pb=F.findOne(n=>n.type==='FRAME'&&n.name==='button/查看预览'); if(pb){ const tt=pb.findOne(n=>n.type==='TEXT'); for(const s of tt.getStyledTextSegments(['fontName'])) await figma.loadFontAsync(s.fontName); tt.characters='预览'; pb.name='button/预览'; }
 return `${F.id} hero:${hr} collapsed:[${done.join(',')}] cur:${cur} h:${Math.round(F.height)}`; }
const out=[]; for(const [id,cfg] of Object.entries(JOBS)){ const F=await figma.getNodeByIdAsync(id); out.push(await run(F,cfg)); }
return out;
