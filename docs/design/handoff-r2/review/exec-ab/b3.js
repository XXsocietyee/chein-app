const SEC='94:4778'; const out={};
async function UNDER(f,tab){await CLUBHEAD(f,tab||'管理',{manage:true,gear:true}); SCRIM(f);}
const GROUP=(body,title)=>{TX(body,title,'MP/label','ink-3',{size:13}); const g=AL(body,'VERTICAL',{gap:0,r:14,fill:'sheet-inset',pad:[0,14,0,14],name:'group · '+title}); g.layoutSizingHorizontal='FILL'; return g;};
const SW=(par,on)=>{const t=AL(par,'HORIZONTAL',{fill:on?'mp/switch-on':'surface-3',r:999,pad:2,align:'CENTER',main:on?'MAX':'MIN',name:'switch '+(on?'on':'off')}); t.primaryAxisSizingMode='FIXED'; t.counterAxisSizingMode='FIXED'; t.resize(51,31); const k=figma.createEllipse(); t.appendChild(k); k.resize(27,27); k.fills=[P('on-solid')]; return t;};
const SWROW=(g,label,state,o={})=>{const r=AL(g,'HORIZONTAL',{align:'CENTER',name:'switch row'}); r.layoutSizingHorizontal='FILL'; r.counterAxisSizingMode='FIXED'; r.resize(r.width,50); r.primaryAxisAlignItems='SPACE_BETWEEN'; TX(r,label,'MP/body','ink',{size:15}); if(state==='saving'){const s=AL(r,'HORIZONTAL',{gap:6,align:'CENTER'}); TX(s,'保存中…','MP/body','ink-3',{size:14});} else SW(r,state==='on'); if(!o.last){const s=figma.createRectangle(); g.appendChild(s); s.resize(10,1); s.fills=[P('sep')]; s.layoutSizingHorizontal='FILL';} return r;};
// 16 俱乐部设置 (large, full height)
{const f=await FRAME(SEC,'069 俱乐部设置 · full',{h:1330}); await UNDER(f); const b=SHEET(f,'俱乐部设置',{h:1270,gap:10});
 let g=GROUP(b,'客户与项目'); ROW(g,'查看客户','2 位'); ROW(g,'报名名册','7 个团'); ROW(g,'活动运营',''); ROW(g,'项目工具','',{last:true});
 g=GROUP(b,'成员与权限'); ROW(g,'入会申请','',{badge:'1'}); ROW(g,'成员管理','4'); ROW(g,'角色与权限','1 已委派'); ROW(g,'成员治理',''); ROW(g,'通知成员',''); ROW(g,'俱乐部勋章','',{last:true});
 g=GROUP(b,'开放设置'); SWROW(g,'俱乐部公开可见','on'); SWROW(g,'开放商家承接','saving'); SWROW(g,'允许成员发帖','off');
 const ie=INST(g,'ie',null,{title:'开关没有保存成功',sub:'允许成员发帖仍是关闭，请重试',action:'重试'}); ie.layoutSizingHorizontal='FILL';
 const w=AL(g,'HORIZONTAL',{gap:10,align:'CENTER',pad:[12,0,12,0]}); w.layoutSizingHorizontal='FILL'; const wc=AL(w,'VERTICAL',{gap:2}); wc.layoutGrow=1; TX(wc,'入会欢迎语','MP/body','ink',{size:15}); const wt=TX(wc,'欢迎加入城瘾跑团，查看置顶活动开启第一条路线！','MP/caption','ink-3',{fillW:true}); TX(w,'修改','MP/body-strong','ink-2',{size:13});
 g=GROUP(b,'经营'); ROW(g,'俱乐部分润','¥400.00',{last:true});
 g=GROUP(b,'俱乐部资料'); ROW(g,'编辑资料','',{last:true});
 NOTE(f,'B-C02-16 large sheet. Host sees 开放设置 and 经营; delegated roles see only the rows their role allows. Switches are native Toggle; a row shows 保存中… while the write is pending, and a failed write shows the inline error under the group. Sheet scrolls; drawn full height.'); out.settings=f.id;}
// 17 项目工具 panel
{const f=await FRAME(SEC,'069 俱乐部设置 · 项目工具'); await UNDER(f); const b=SHEET(f,'俱乐部设置',{detent:'large',gap:10});
 let g=GROUP(b,'客户与项目'); ROW(g,'查看客户','2 位'); ROW(g,'报名名册','7 个团'); ROW(g,'活动运营','');
 const r=AL(g,'HORIZONTAL',{align:'CENTER'}); r.layoutSizingHorizontal='FILL'; r.counterAxisSizingMode='FIXED'; r.resize(r.width,50); r.primaryAxisAlignItems='SPACE_BETWEEN'; TX(r,'项目工具','MP/body','ink',{size:15}); IC(r,'down',16,'ink-3');
 const tiles=AL(g,'HORIZONTAL',{gap:10,pad:[0,0,14,0]}); tiles.layoutSizingHorizontal='FILL'; for(const [k,l] of [['plus','发布主题'],['cal','开一场'],['spark','AI 策划']]){const t=AL(tiles,'VERTICAL',{gap:8,pad:[14,8,14,8],r:12,fill:'surface-3',align:'CENTER'}); t.layoutGrow=1; IC(t,k,22,'ink'); TX(t,l,'MP/body-strong','ink',{size:13});}
 g=GROUP(b,'成员与权限'); ROW(g,'入会申请','',{badge:'1'}); ROW(g,'成员管理','4',{last:true});
 NOTE(f,'B-C02-17 row 项目工具 opened in place: three tiles 发布主题 / 开一场 / AI 策划.'); out.tools=f.id;}
// 18 成员管理 panel
{const f=await FRAME(SEC,'069 俱乐部设置 · 成员管理'); await UNDER(f); const b=SHEET(f,'俱乐部设置',{detent:'large',gap:10});
 let g=GROUP(b,'成员与权限'); ROW(g,'入会申请','',{badge:'1'});
 const r=AL(g,'HORIZONTAL',{align:'CENTER'}); r.layoutSizingHorizontal='FILL'; r.counterAxisSizingMode='FIXED'; r.resize(r.width,50); r.primaryAxisAlignItems='SPACE_BETWEEN'; TX(r,'成员管理','MP/body','ink',{size:15}); const rr=AL(r,'HORIZONTAL',{gap:6,align:'CENTER'}); TX(rr,'4','MP/body','ink-3'); IC(rr,'down',16,'ink-3');
 ROW(g,'邀请成员','',{icon:'plus'});
 for(const [nm,meta] of [['平台运营','管理员 · 加入 2026-11-01'],['沪上寻踪搭子','加入 2026-11-03'],['玩家小城','加入 2026-11-05']]){const m=AL(g,'HORIZONTAL',{gap:10,align:'CENTER',pad:[10,0,10,0]}); m.layoutSizingHorizontal='FILL'; AVIMG(m,32); const col=AL(m,'VERTICAL',{gap:2}); col.layoutGrow=1; TX(col,nm,'MP/body-strong','ink'); TX(col,meta,'MP/caption','ink-3'); for(const a of ['权限','临时封禁','移除']) TX(m,a,'MP/label',a==='移除'?'bad':'ink-2',{size:13});}
 g=GROUP(b,'开放设置'); SWROW(g,'俱乐部公开可见','on',{last:true});
 NOTE(f,'B-C02-18 row 成员管理 opened: 邀请成员 ›, then members with text buttons 权限 / 临时封禁 / 移除 (none on the host row).'); out.memberPanel=f.id;}
// 19 选择要管理的俱乐部
{const f=await FRAME(SEC,'069 选择要管理的俱乐部'); await UNDER(f); const b=SHEET(f,'选择要管理的俱乐部',{h:300}); for(const [l,s,sub] of [['城瘾跑团',true,'城市探索 · 4 名成员'],['外滩夜行俱乐部',false,'城市探索 · 42 名成员']]){const i=INST(b,'opt','Selected='+s,{label:l,sub,showSub:true,showSep:s}); i.layoutSizingHorizontal='FILL';} NOTE(f,'B-C02-19 medium sheet: the host’s clubs, one per row (max 2 per host).'); out.pick=f.id;}
// 20 发帖 composer
{const f=await FRAME(SEC,'069 发帖'); await UNDER(f,'帖文'); const b=SHEET(f,'发帖',{detent:'large',gap:14});
 const ta=AL(b,'VERTICAL',{gap:8,pad:14,r:14,fill:'sheet-inset',name:'text area'}); ta.layoutSizingHorizontal='FILL'; ta.counterAxisSizingMode='FIXED'; TX(ta,'有什么新鲜好玩的分享吗？','MP/body','mp/placeholder',{size:16}); GAP(ta,120); TX(ta,'0/500','MP/caption','ink-3');
 const im=AL(b,'HORIZONTAL',{gap:8}); PIC(im,'heat',96,96,12); PIC(im,'routecity',96,96,12); const add=AL(im,'VERTICAL',{gap:4,r:12,fill:'sheet-inset',main:'CENTER',align:'CENTER'}); add.primaryAxisSizingMode='FIXED'; add.counterAxisSizingMode='FIXED'; add.resize(96,96); IC(add,'plus',22,'ink-2'); TX(add,'2/9','MP/caption','ink-3');
 const g=AL(b,'VERTICAL',{gap:0,r:14,fill:'sheet-inset',pad:[0,14,0,14]}); g.layoutSizingHorizontal='FILL'; ROW(g,'带上一次游玩记录','外滩夜探',{icon:'route',last:true});
 const sp=GAP(b,150); PILL(b,'发布','primary',{fillW:true});
 NOTE(f,'B-C02-20 large sheet, cy-post-compose (新稿 N1b 47:2). Swipe down with text entered asks K9 放弃本轮修改.'); out.compose=f.id;}
// 21 带上一次游玩记录
{const f=await FRAME(SEC,'069 带上一次游玩记录'); await UNDER(f,'帖文'); const b=SHEET(f,'带上一次游玩记录',{h:380}); const g=AL(b,'VERTICAL',{gap:0,r:14,fill:'sheet-inset',pad:[0,14,0,14]}); g.layoutSizingHorizontal='FILL'; ROW(g,'外滩夜探','我的游玩记录 · 1 场 · 0.0 km',{icon:'route'}); ROW(g,'老店招牌文字迷宫','城市定向 · 未完成',{icon:'route',last:true});
 NOTE(f,'B-C02-21 medium sheet. States: K1 list, error「游玩记录加载失败」, empty「还没有可以带的记录」.'); out.record=f.id;}
// 22 编辑动态 + discard
for(const [lab,alert] of [['069 编辑动态',false],['069 编辑动态 · 放弃修改',true]]){const f=await FRAME(SEC,lab); await UNDER(f,'帖文'); const b=SHEET(f,'编辑动态',{detent:'large',gap:14});
 const ta=AL(b,'VERTICAL',{gap:8,pad:14,r:14,fill:'sheet-inset'}); ta.layoutSizingHorizontal='FILL'; TX(ta,'第一次跑外滩夜探，老店招牌那一关卡了好久，值得！下次带朋友一起。','MP/body','ink',{fillW:true,size:16}); GAP(ta,90);
 const n=AL(b,'HORIZONTAL',{gap:6,align:'CENTER'}); IC(n,'alert',14,'ink-3'); TX(n,'编辑记录将公开','MP/caption','ink-3'); GAP(b,280); PILL(b,'保存修改','primary',{fillW:true});
 if(alert) ALERT(f,'Destructive',{title:'放弃本轮修改？',message:'离开后，本次修改不会保留。',cancel:'继续编辑',confirm:'确认放弃'});
 NOTE(f,alert?'K9 over the edit sheet: 继续编辑 is the default; 确认放弃 destructive.':'B-C02-22 large sheet; placeholder「输入动态内容」when empty.'); out[lab]=f.id;}
// 23 编辑历史
{const f=await FRAME(SEC,'069 编辑历史'); await UNDER(f,'帖文'); const b=SHEET(f,'编辑历史',{detent:'large',gap:10});
 for(const [v,t] of [['v2 · 11月14日 19:26','第一次跑外滩夜探，老店招牌那一关卡了好久，值得！下次带朋友一起。'],['v1 · 11月14日 18:02','第一次跑外滩夜探，老店招牌那一关卡了好久，值得！'],['v0 · 11月14日 17:40','（仅图片动态）']]){const c=AL(b,'VERTICAL',{gap:6,pad:14,r:14,fill:'sheet-inset'}); c.layoutSizingHorizontal='FILL'; TX(c,v,'MP/label','ink-3',{size:13}); TX(c,t,'MP/body',t.startsWith('（')?'ink-3':'ink',{fillW:true,size:15});}
 NOTE(f,'B-C02-23 large sheet; empty「暂无编辑记录」.'); out.history=f.id;}
return out;
