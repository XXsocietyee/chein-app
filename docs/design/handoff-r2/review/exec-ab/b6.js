const out={}; const SEC='96:3534';
// re-fix selected tab lozenge on this page
{let n=0; for(const i of PAGE.findAllWithCriteria({types:['INSTANCE']})){ if(!i.mainComponent||i.mainComponent.id!=='174:3515') continue; const cap=i.children.find(c=>c.name==='capsule'); if(!cap) continue; for(const t of cap.children){ if(t.type!=='FRAME') continue; const f=t.fills; if(Array.isArray(f)&&f.length&&f[0].type==='SOLID'&&(f[0].opacity??1)>0.5){ t.fills=[P('ink',0.16)]; n++; } } } out.tabfix=n;}
async function HEAD(f,tab){await BASE(f,'169:3927',144); const tabs=f.findOne(n=>n.name==='tabs 帖文/俱乐部'); let selX=null;
 if(tabs) for(const t of tabs.findAll(n=>n.type==='TEXT')){const on=t.characters===tab; t.fills=[P(on?'ink':'ink-3')]; t.fontName={family:'SF Pro',style:on?'Semibold':'Regular'}; if(on){const b=t.absoluteBoundingBox, fb=f.absoluteBoundingBox; selX=b.x-fb.x+b.width/2;}}
 const ind=f.findOne(n=>n.name==='tab indicator'); if(ind&&selX!=null) ind.x=selX-ind.width/2; }
async function LIST(f,y,o={}){const src=await figma.getNodeByIdAsync('204:27591'); const k=src.clone(); f.appendChild(k); k.x=0; k.y=y; return k;}
async function TABBAR(f){const src=await figma.getNodeByIdAsync('177:3663'); const k=src.clone(); f.appendChild(k); k.x=0; k.y=756;}
{const f=await FRAME(SEC,'005 帖文'); await HEAD(f,'帖文'); const c=CONTENT(f,156,{gap:12});
 const pc=AL(c,'VERTICAL',{gap:10,pad:16,r:16,fill:'surface',name:'pass card (通票)'}); pc.layoutSizingHorizontal='FILL'; const h=AL(pc,'HORIZONTAL',{align:'CENTER'}); h.layoutSizingHorizontal='FILL'; h.primaryAxisAlignItems='SPACE_BETWEEN'; TX(h,'城市通票 · 外滩线','MP/card-title','ink'); TX(h,'¥39.00','MP/card-title','ink');
 TX(pc,'3 条路线 · 城瘾跑团 · 30 天内有效','MP/caption','ink-3'); const th=AL(pc,'HORIZONTAL',{gap:8}); for(const k of ['heat','anomaly','flavor']) PIC(th,k,102,64,10); const b=AL(pc,'HORIZONTAL',{main:'MAX'}); b.layoutSizingHorizontal='FILL'; const bb=AL(b,'HORIZONTAL',{fill:'cta',r:999,pad:[7,16,7,16]}); TX(bb,'获取通票','MP/body-strong','cta-ink',{size:13});
 POST(c,{name:'海派城市漫游团',role:'主理人',meta:'城瘾跑团 › · 2 小时前',text:'周六晚的外滩夜探路线已经放出：6 个节点，从老城钟楼出发。',imgs:['heat','routecity','oldmovie'],likes:12,comments:3});
 POST(c,{name:'沪上寻踪搭子',meta:'城瘾跑团 › · 昨天',text:'老店招牌文字迷宫第三站的招牌终于找到了。',imgs:['anomaly'],likes:8,comments:2});
 await TABBAR(f); NOTE(f,'B-C01-1 帖文 tab: optional pass card (title, meta, up to 3 covers, price, 获取通票), then the feed (cy-post-card redrawn dark; light version R4 100:2885). Bell badge caps at 99+.'); out.posts=f.id;}
{const f=await FRAME(SEC,'005 帖文 · 空'); await HEAD(f,'帖文'); STATE(f,'Empty',{title:'还没有帖文',showSub:false,showAction:false},300); await TABBAR(f); out.empty=f.id;}
{const f=await FRAME(SEC,'005 成员管理 sheet'); await HEAD(f,'俱乐部'); await LIST(f,194); await TABBAR(f); SCRIM(f); const b=SHEET(f,'城瘾跑团',{detent:'large',gap:10}); TX(b,'成员管理','MP/section-title','ink');
 const g=AL(b,'VERTICAL',{gap:0,r:14,fill:'sheet-inset',pad:[0,14,0,14]}); g.layoutSizingHorizontal='FILL';
 for(const [nm,sub,rm] of [['海派城市漫游团','主理人',false],['平台运营','加入时间 2026-11-01',true],['沪上寻踪搭子','加入时间 2026-11-03',true],['玩家小城','加入时间 2026-11-05',true]]){const r=AL(g,'HORIZONTAL',{gap:12,pad:[10,0,10,0],align:'CENTER'}); r.layoutSizingHorizontal='FILL'; AVIMG(r,36); const col=AL(r,'VERTICAL',{gap:2}); col.layoutGrow=1; TX(col,nm,'MP/body-strong','ink'); TX(col,sub,'MP/caption','ink-3'); if(rm) TX(r,'移除','MP/body-strong','bad',{size:13});}
 const st=AL(b,'VERTICAL',{gap:6}); TX(st,'Sheet states: K1 list · error「成员加载失败」· strip「正在更新成员」· empty「暂无成员」','MP/caption','ink-3',{fillW:true});
 NOTE(f,'B-C01-3 full sheet from a club card (host). 移除 is not shown on the host row.'); out.members=f.id;}
{const f=await FRAME(SEC,'005 俱乐部 · 商家视角'); await HEAD(f,'俱乐部'); INST(f,'strip',null,{text:'正在确认同城范围'},0,148); await LIST(f,184); await TABBAR(f);
 const tagRow=AL(f,'HORIZONTAL',{gap:6,x:32,y:440,name:'capability tags (card file 101:2)'}); for(const t of ['能设计路线','能出 NPC','能对接商家']){const b=AL(tagRow,'HORIZONTAL',{fill:'surface-3',r:6,pad:[2,6,2,6]}); TX(b,t,'MP/tag','ink');}
 NOTE(f,'B-C01-4 merchant viewer: no「创建你自己的俱乐部」row, only same-city clubs; strip while the city is confirmed; empty copy「本城还没有俱乐部」. Capability tags on each card per card file 101:2.'); out.merchant=f.id;}
{const f=await FRAME(SEC,'005 加载中'); await HEAD(f,'俱乐部'); SKEL(f,'card',160); await TABBAR(f); out.loading=f.id;}
{const f=await FRAME(SEC,'005 更新中'); await HEAD(f,'俱乐部'); INST(f,'strip',null,{text:'正在更新俱乐部'},0,148); const l=await LIST(f,184); await TABBAR(f); NOTE(f,'B-C01-6 refreshing: strip under the tabs; old list stays.'); out.refresh=f.id;}
return out;
