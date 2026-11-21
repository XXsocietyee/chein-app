const SEC='94:4778';
const POST1={name:'海派城市漫游团',role:'主理人',meta:'城瘾跑团 · 2 小时前',text:'周六晚的外滩夜探路线已经放出：6 个节点，从老城钟楼出发。报名在「活动」里。',imgs:['heat','routecity','oldmovie'],likes:12,comments:3,actions:['举报']};
const POST2={name:'玩家小城',meta:'城瘾跑团 · 昨天 21:40 · 已编辑',text:'第一次跑外滩夜探，老店招牌那一关卡了好久，值得！',quote:'外滩夜探',quoteSub:'我的游玩记录 · 1 场',likes:4,comments:1,actions:['编辑','历史','删除']};
const composer=(c)=>{const cp=AL(c,'HORIZONTAL',{gap:10,pad:[12,14,12,14],r:16,fill:'surface',align:'CENTER',name:'composer row'}); cp.layoutSizingHorizontal='FILL'; AVIMG(cp,36); const col=AL(cp,'VERTICAL',{gap:2}); col.layoutGrow=1; TX(col,'玩家小城','MP/body-strong','ink'); TX(col,'有什么新鲜好玩的分享吗？','MP/body','mp/placeholder'); for(const k of ['image','pin','flag']) IC(cp,k,20,'ink-2');};
const pinned=(c)=>{const pin=AL(c,'HORIZONTAL',{gap:8,pad:[12,14,12,14],r:12,fill:'surface',align:'CENTER',name:'club-pinned-notice'}); pin.layoutSizingHorizontal='FILL'; IC(pin,'pin',16,'mp/accent-lime'); const pt=TX(pin,'欢迎加入城瘾跑团，查看置顶活动开启第一条路线！','MP/body','ink',{size:14}); pt.layoutGrow=1; pt.textAutoResize='TRUNCATE'; pt.textTruncation='ENDING'; pt.resize(280,20); IC(pin,'chev',14,'ink-3');};
const out={};
{const f=await FRAME(SEC,'069 帖文'); await CLUBHEAD(f,'帖文'); const c=CONTENT(f,446); pinned(c); composer(c); POST(c,POST1); POST(c,POST2); NOTE(f,'B-C02-1 帖文 tab (member). 新稿 N1b 47:2. Row actions show by permission: 编辑/历史/删除 on own posts, 举报 on others, 置顶 for moderators on notices.'); out.posts=f.id;}
{const f=await FRAME(SEC,'069 帖文 · 评论展开'); await CLUBHEAD(f,'帖文'); const c=CONTENT(f,446); const p=POST(c,{...POST1,imgs:null});
 const cm=AL(p,'VERTICAL',{gap:10,pad:12,r:12,fill:'surface-2',name:'comments'}); cm.layoutSizingHorizontal='FILL';
 for(const [who,txt,act] of [['沪上寻踪搭子','周六我也去，集合点见','举报'],['玩家小城','集合时间是几点？','删除'],['海派城市漫游团','19:30 外白渡桥北，提前 10 分钟到','举报']]){const r=AL(cm,'HORIZONTAL',{gap:8,align:'MIN'}); r.layoutSizingHorizontal='FILL'; r.primaryAxisAlignItems='SPACE_BETWEEN'; const t=figma.createText(); r.appendChild(t); t.textStyleId=TS['MP/body'].id; t.characters=who+'：'+txt; t.fills=[P('ink')]; t.setRangeFills(0,who.length+1,[P('ink-3')]); t.layoutGrow=1; t.textAutoResize='HEIGHT'; TX(r,act,'MP/label','ink-3',{size:13});}
 const inp=AL(cm,'HORIZONTAL',{gap:8,align:'CENTER'}); inp.layoutSizingHorizontal='FILL'; const box=AL(inp,'HORIZONTAL',{fill:'input-bg',r:999,pad:[9,14,9,14]}); box.layoutGrow=1; TX(box,'写评论…','MP/body','mp/placeholder'); const s=AL(inp,'HORIZONTAL',{fill:'cta',r:999,pad:[8,14,8,14]}); TX(s,'发送','MP/body-strong','cta-ink',{size:13});
 POST(c,POST2);
 NOTE(f,'B-C02-2 comments expanded: 「昵称：内容」, 删除 on own, 举报 on others. Empty: 还没有评论，来抢沙发. Input only for members.'); out.comments=f.id;}
{const f=await FRAME(SEC,'069 帖文 · 空'); await CLUBHEAD(f,'帖文',{visitor:true}); STATE(f,'Empty',{title:'暂无帖文',sub:'入会后可发布',showSub:true,showAction:false},500); NOTE(f,'B-C02-3 empty, visitor wording (sub only for non-members).'); out.postsEmpty=f.id;}
{const f=await FRAME(SEC,'069 帖文 · 加载失败'); await CLUBHEAD(f,'帖文'); const i=INST(f,'ie',null,{title:'帖文加载失败',sub:'网络没连上，请重试',action:'重试'},16,450); NOTE(f,'B-C02-3 error variant as K6: header and tabs keep their data.'); out.postsErr=f.id;}
// 活动 tab (host view: 发布 + 出示团码)
const EVENT=(c,e)=>{const card=AL(c,'HORIZONTAL',{gap:12,pad:12,r:16,fill:'surface',align:'MIN',name:'event card'}); card.layoutSizingHorizontal='FILL'; PIC(card,e.img,84,84,12);
 const col=AL(card,'VERTICAL',{gap:4}); col.layoutGrow=1; const tg=AL(col,'HORIZONTAL',{fill:e.tagFill,r:6,pad:[2,6,2,6]}); TX(tg,e.tag,'MP/tag',e.tagInk);
 TX(col,e.title,'MP/card-title','ink',{fillW:true}); TX(col,e.line,'MP/caption','ink-3'); const facts=AL(col,'HORIZONTAL',{gap:10}); for(const ft of e.facts) TX(facts,ft,'MP/caption','ink-2');
 const act=AL(col,'HORIZONTAL',{gap:8,align:'CENTER'}); for(const a of e.actions){const b=AL(act,'HORIZONTAL',{fill:'surface-2',r:999,pad:[5,12,5,12],align:'CENTER',gap:4}); if(a==='出示团码') IC(b,'qr',14,'ink'); TX(b,a,'MP/body-strong','ink',{size:12});} const m=AL(act,'HORIZONTAL',{fill:'surface-2',r:999,pad:[5,8,5,8]}); IC(m,'more',14,'ink-2'); return card;};
{const f=await FRAME(SEC,'069 活动'); await CLUBHEAD(f,'活动',{manage:true,gear:true}); const c=CONTENT(f,446);
 const hr=AL(c,'HORIZONTAL',{align:'CENTER'}); hr.layoutSizingHorizontal='FILL'; hr.primaryAxisAlignItems='SPACE_BETWEEN'; TX(hr,'即将举行','MP/section-title','ink'); const pb=AL(hr,'HORIZONTAL',{gap:4,align:'CENTER',fill:'surface-2',r:999,pad:[6,12,6,10]}); IC(pb,'plus',14,'ink'); TX(pb,'发布','MP/body-strong','ink',{size:13});
 EVENT(c,{img:'oldmovie',tag:'招募中',tagFill:'warn-soft',tagInk:'warn',title:'外滩钟声 · 老城寻踪三章',line:'周日 11月22日 14:00 · 城市定向',facts:['已报名 5','节点 6'],actions:['出示团码']});
 EVENT(c,{img:'heat',tag:'进行中',tagFill:'ok-soft',tagInk:'ok',title:'外滩夜探',line:'外滩 · 自由探索',facts:['节点 6'],actions:['出示团码']});
 TX(c,'已结束','MP/section-title','ink');
 EVENT(c,{img:'anomaly',tag:'已结束',tagFill:'surface-3',tagInk:'ink-3',title:'老店招牌文字迷宫',line:'南京东路 · 城市定向',facts:['已报名 4'],actions:[]});
 NOTE(f,'B-C02-4 活动 tab, host / activity-manager view: 发布 top right, 出示团码 on cards. Merchant viewer sees 邀约承接 instead; ⋯ = 举报. 新稿 N2-B 282:499.'); out.events=f.id;}
{const f=await FRAME(SEC,'069 活动 · 空'); await CLUBHEAD(f,'活动',{manage:true,gear:true}); STATE(f,'Empty',{title:'暂时俱乐部还没有活动',showSub:false,action:'发布活动',showAction:true},500); NOTE(f,'B-C02-5 empty (host sees 发布活动; members see no button). 新稿 N2-A 282:350.'); out.eventsEmpty=f.id;}
{const f=await FRAME(SEC,'069 活动 · 加载失败'); await CLUBHEAD(f,'活动'); INST(f,'ie',null,{title:'活动列表加载失败',sub:'网络没连上，请重试',action:'重试'},16,450); out.eventsErr=f.id;}
return out;
