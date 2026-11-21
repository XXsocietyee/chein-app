// B5a · Library 02 Patterns 6:4 · SR1-47b Motion & Haptics board; read tab bars / alert / icons for B5b
await goPage(PAT);
const pg=figma.currentPage;
const right=Math.max(0,...pg.children.map(c=>c.x+c.width));
const board=AL('VERTICAL','Motion & Haptics · 动效与触感 (skill-r1 SR1-47)',{gap:24,pad:[40,40],r:24,fill:'bg',w:1200,align:'MIN'}); pg.appendChild(board); board.x=right+200; board.y=0;
await TX(board,'Motion & Haptics · 动效与触感','t-large','ink',{name:'title'});
await TX(board,'One table for every transition and one haptic per game verb (PowerWash Simulator rule). Tokens live in the Motion collection (duration/*, spring/* for SwiftUI, figma/* for the prototype). Frame notes name the token and the verb, nothing more.','t-body','ink-2',{name:'lede',fill:true});
async function table(title,head,rows,widths){ await TX(board,title,'t-2','ink',{name:title}); const t=AL('VERTICAL','table · '+title,{r:16,fill:'surface',align:'MIN'}); board.appendChild(t); t.layoutSizingHorizontal='FILL';
  const line=async(cells,isHead)=>{ const r=AL('HORIZONTAL','row',{pad:[12,20],gap:16,align:'CENTER'}); t.appendChild(r); r.layoutSizingHorizontal='FILL'; if(!isHead){ r.strokes=[PAINT('sep')]; r.strokeTopWeight=1; r.strokeBottomWeight=0; r.strokeLeftWeight=0; r.strokeRightWeight=0; } for(let i=0;i<cells.length;i++){ const c=await TX(r,cells[i],isHead?'role/tag':'t-sub',isHead?'ink-2':'ink',{name:'cell'}); c.resize(widths[i],c.height); c.textAutoResize='HEIGHT'; } };
  await line(head,true); for(const r of rows) await line(r,false); }
await table('Springs · 弹簧',['Use','SwiftUI','Figma spring (mass 1)','Duration shown','Token'],[
 ['Sheet in, detent change','response .38, damping .86','stiffness 273, damping 28.4','≈ 350 ms','spring/sheet-*'],
 ['Push, pop','response .45, damping .86','stiffness 195, damping 24.0','≈ 400 ms','spring/push-*'],
 ['Press, chip, segment','response .30, damping .80','stiffness 439, damping 33.5','≈ 250 ms','spring/press-*'],
 ['Result card rise','response .42, damping .80','stiffness 224, damping 23.9','≈ 400 ms','spring/result-*'],
 ['Moment (flag plant, die land)','response .40, damping .55','stiffness 247, damping 17.3','≈ 600 ms','spring/moment-*']],[260,220,260,140,200]);
await table('Haptics · 触感',['Verb','Haptic','Sound pairing'],[
 ['Fog cell lights','impact light, at most one per 2 s','none'],['Claim check passes (each row)','selection','soft tick'],['Claim check fails','notification error','none'],['Flag plants','impact heavy at contact','low thud'],['Claim confirmed','notification success, 150 ms after the plant','none'],['Die rolling','impact light every 120 ms, intensity rising','rattle'],['Die lands','impact rigid','click'],['Roll won','custom: two rising taps','short rise'],['Roll lost','impact soft, single','none'],['Rent arrives','impact soft','coin'],['Place taken from me','notification warning','none'],['Sheet settles on a detent','selection','none']],[360,520,200]);
await TX(board,'Rules','t-2','ink');
for(const s of ['Interruptible: a tap jumps to the settled frame; velocity hands off into the spring.','Reduce Motion: springs and slides become 200 ms cross-fades; fog, shimmer and glow loops stop; haptics stay.','VoiceOver speaks every result (headline + line) — haptics are in addition to audio cues, never instead.','No double-firing: one haptic per verb; .success is used only for Claim confirmed.']){ await TX(board,'• '+s,'t-body','ink',{fill:true}); }
SR(board,'SR1-47','Spring table + haptic map; the prototype uses the figma/* values, the build uses spring/* and duration/*.');
await board.screenshot({scale:0.35});
// ---- read for B5b ----
function desc(n){ if(!n) return 'missing'; let pgn=n; while(pgn&&pgn.type!=='PAGE') pgn=pgn.parent; return n.type+' '+n.name+' '+Math.round(n.width)+'x'+Math.round(n.height)+' page='+(pgn&&pgn.name.slice(0,12))+(n.type==='COMPONENT_SET'?' variants='+n.children.map(c=>c.name).join('|').slice(0,300):''); }
const info={}; for(const id of ['174:3515','12:129','12:256','319:8299','290:20572','287:521']){ info[id]=desc(await byId(id)); }
const tp=await byId('287:521'); info.topPill=tp.findAll(()=>true).slice(0,12).map(n=>n.type[0]+' '+n.name+' '+Math.round(n.width)+'x'+Math.round(n.height)+(n.effects&&n.effects.length?' fx:'+n.effects.map(e=>e.type).join(','):'')).join(' | ');
const opt=await byId('174:3515'); if(opt){ const v=opt.type==='COMPONENT_SET'?opt.children[0]:opt; info.optTree=v.findAll(()=>true).slice(0,20).map(n=>n.type[0]+' '+n.name.slice(0,20)+' '+Math.round(n.width)+'x'+Math.round(n.height)).join(' | '); }
const tb=await byId('12:129'); if(tb){ const v=tb.type==='COMPONENT_SET'?tb.children[0]:tb; info.tbTree=v.children.map(n=>n.type[0]+' '+n.name.slice(0,20)+' '+Math.round(n.width)+'x'+Math.round(n.height)).join(' | '); }
R.info=info; R.created=R.created.length; return R;
