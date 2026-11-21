// B2a · N1 · SR1-23 (CITY home on the board), SR1-22 use (deed rows), + structure dump for the next calls
await goPage(N1);
const deedSet=await byId('381:1401'), mapSet=await byId('387:2721'), pinSet=await byId(PIN), tile=await byId(STAT_TILE), tagSet=await byId(STAT_TAG), pbtn=await byId(PBTN);
const DEED=(s,st)=>variant(deedSet,{Size:s,State:st}); const MAPV=l=>variant(mapSet,{Layer:l}); const PINV=(o,b='None',l='1')=>variant(pinSet,{Owner:o,Badge:b,Level:l});
async function deedRow(st,name,district,d,lv){ const i=DEED('Row',st).createInstance(); setProps(i,{'名称':name}); for(const t of i.findAll(n=>n.type==='TEXT'&&n.name==='district')) await setT(t,district); for(const t of i.findAll(n=>n.type==='TEXT'&&n.name==='level')) await setT(t,lv); for(const b of i.findAll(n=>n.name==='band'||n.name==='district dot')) b.fills=[PAINT(`district/${d}`)]; return i; }
async function mapModule(layer,pins,expandTo){ const m=AL('VERTICAL','map module · 领地',{w:361,h:220,r:20,clip:true}); m.layoutMode='NONE'; const mp=MAPV(layer).createInstance(); m.appendChild(mp); mp.x=-16; mp.y=-150;
  for(const [o,b,x,y] of pins){ const p=PINV(o,b).createInstance(); m.appendChild(p); p.x=x; p.y=y; }
  const pill=AL('HORIZONTAL','stat pill',{gap:8,pad:[6,12],r:999,fill:'glass'}); m.appendChild(pill); try{ pill.effects=[{type:'GLASS',visible:true,lightIntensity:0.5,lightAngle:-45,refraction:0.35,depth:10,dispersion:0.1,radius:6}]; }catch(e){} await IC(pill,'flag',14,'ink'); await TX(pill,'持有 3 / 9','t-foot','ink',{name:'stat 1'}); await TX(pill,'·','t-foot','ink-3'); await TX(pill,'今天 +186 积分','t-foot','ink',{name:'stat 2'}); pill.x=12; pill.y=12;
  const ex=AL('HORIZONTAL','expand · hit 44',{w:44,h:44,r:999,fill:'glass',justify:'CENTER'}); m.appendChild(ex); try{ ex.effects=[{type:'GLASS',visible:true,lightIntensity:0.5,lightAngle:-45,refraction:0.35,depth:10,dispersion:0.1,radius:6}]; }catch(e){} await IC(ex,'map',20,'ink'); ex.x=361-12-44; ex.y=220-12-44;
  if(expandTo) await m.setReactionsAsync([{trigger:{type:'ON_CLICK'},actions:[{type:'NODE',destinationId:expandTo,navigation:'NAVIGATE',transition:{type:'SMART_ANIMATE',easing:SP('push'),duration:DUR.push},resetScrollPosition:true}]}]);
  return m; }
// ---- N01 ----
const N01=await byId('204:21814'); const content=await byId('204:21813');
const stat=await byId('204:21715'), pillBtn=await byId('204:21716'), rowsCard=await byId('204:21749'), progTitle=await byId('204:21750'), progCard=await byId('204:21777'), mineTitle=await byId('204:21778'), mineCard=await byId('204:21812');
const mm=await mapModule('Territory',[['Mine','None',60,118],['Other','Shield',150,30],['Mine','Hourglass',260,118],['None','None',150,150]],'204:23260'); content.insertChild(0,mm);
const strip=AL('HORIZONTAL','today strip',{pad:[14,16],r:16,fill:'surface',justify:'SPACE_BETWEEN'}); content.insertChild(1,strip); strip.layoutSizingHorizontal='FILL';
for(const [v,c] of [['1,286','积分 · +186 待入账'],['3 / 9','持有'],['12 天','赛季剩余']]){ const t=tile.createInstance(); strip.appendChild(t); setProps(t,{Value:v,Caption:c}); }
const needT=await TX(null,'需要你处理','t-3','ink',{name:'需要你处理'}); content.insertChild(2,needT);
const need=AL('VERTICAL','card · 需要你处理',{r:16,fill:'surface'}); content.insertChild(3,need); need.layoutSizingHorizontal='FILL';
for(const [n,st,lab] of [['武康大楼','Warning','风化 · 9 天未到'],['安福路 12 号','Warning','保护 11:42 后结束']]){ const r=AL('HORIZONTAL','row · '+n,{pad:[0,16],gap:8,h:52}); need.appendChild(r); r.layoutSizingHorizontal='FILL'; await TX(r,n,'t-head','ink',{name:'title'}); add(r,AL('HORIZONTAL','spacer'),'FILL'); const tg=variant(tagSet,{State:st}).createInstance(); r.appendChild(tg); setProps(tg,{Label:lab}); await IC(r,'chev',16,'ink-3'); }
// 我的地盘 as deed rows, then 街区, then the four secondary rows grouped at the end
const deeds=AL('VERTICAL','我的地盘 · deeds',{gap:8}); content.insertChild(content.children.indexOf(mineTitle)+1,deeds); deeds.layoutSizingHorizontal='FILL';
deeds.appendChild(await deedRow('Mine','武康大楼','武康路',1,'Lv 2')); deeds.appendChild(await deedRow('Weathered','安福路 12 号','安福路',2,'Lv 1')); deeds.appendChild(await deedRow('Mine','愚园路 1088 弄','愚园路',3,'Lv 1'));
if(mineCard) mineCard.remove(); if(stat) stat.remove(); if(pillBtn) pillBtn.remove();
// order: map, strip, need, mine title, deeds, 街区 title, 街区 card, 更多 title, rows card
const moreT=await TX(null,'更多','t-3','ink',{name:'更多'});
const order=[mm,strip,needT,need,mineTitle,deeds,progTitle,progCard,moreT,rowsCard].filter(Boolean); order.forEach((n,i)=>content.insertChild(i,n));
for(const t of [needT,moreT]) t.layoutSizingHorizontal='FILL';
N01.resize(393,content.y+content.height+40);
SR(N01,'SR1-23','The board leads: live map module (Territory, my flags, stat pill, expand → N07), today strip, 需要你处理, 我的地盘 as deed rows, 街区, then the four secondary rows. The white 打开领地图 pill is gone.');
OWN(N01,'Q1','City Monopoly enters from the 漫游 root (迷雾 / 领地 chips) and a 我的地盘 rail on 首页; no sixth tab.');
// ---- N03 (empty) ----
const N03=await byId('204:21889'); const c3=N03.findOne(n=>n.name==='content'&&n.type==='FRAME');
if(c3){ const m3=await mapModule('Fog',[['None','None',70,90],['None','None',170,120],['None','None',260,70],['Unlit','None',120,30]],'204:23260'); c3.insertChild(0,m3); for(const t of m3.findAll(n=>n.name==='stat 1')) await setT(t,'附近 3 块可圈'); for(const t of m3.findAll(n=>n.name==='stat 2')) await setT(t,'圈地 120 积分'); const b=variant(pbtn,{Kind:'Primary',Size:'52',State:'Default'}).createInstance(); c3.insertChild(1,b); b.layoutSizingHorizontal='FILL'; setProps(b,{Label:'去圈第一块地'}); N03.resize(393,Math.max(852,c3.y+c3.height+40)); SR(N03,'SR1-23','Empty board shows the same map with claimable outlines and one primary 去圈第一块地.'); }
else R.warn.push('N03 has no content frame');
await N01.screenshot({scale:0.45});
// ---- structure dump for B2b/B2c ----
function tree(n,d,max){ let s='  '.repeat(d)+n.type[0]+' '+n.id+' '+n.name.slice(0,22)+(n.type==='TEXT'?' «'+n.characters.slice(0,26).replace(/\n/g,'⏎')+'» '+n.fontSize:'')+' '+Math.round(n.x)+','+Math.round(n.y)+' '+Math.round(n.width)+'x'+Math.round(n.height)+(n.layoutMode&&n.layoutMode!=='NONE'?' AL'+n.layoutMode[0]:''); if(d<max&&n.children&&n.type!=='INSTANCE') for(const c of n.children.slice(0,14)) s+='\n'+tree(c,d+1,max); return s; }
const dump={}; for(const id of ['205:8376','204:33843','204:23542','204:27271','205:8786','204:27073','204:34263','204:34340','208:2281','208:2311','204:34304','207:2311','207:2026']){ const n=await byId(id); dump[id]=n?tree(n,0,3).slice(0,1700):'missing'; }
R.info.dump=dump; R.info.ids={mm:mm.id,strip:strip.id,need:need.id,deeds:deeds.id};
R.created=R.created.length; R.touched=R.touched.length; return R;
