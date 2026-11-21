const SEC='94:4778'; const out={};
async function UNDER(f,tab){await CLUBHEAD(f,tab||'管理',{manage:true,gear:true}); SCRIM(f);}
const INPUT=(par,ph,o={})=>{const b=AL(par,'HORIZONTAL',{fill:'sheet-inset',r:12,pad:[12,14,12,14],name:'input'}); if(o.fillW!==false) b.layoutSizingHorizontal='FILL'; if(o.grow) b.layoutGrow=1; TX(b,ph,'MP/body',o.value?'ink':'mp/placeholder',{size:15}); if(o.h){b.counterAxisSizingMode='FIXED'; b.resize(b.width,o.h);} if(o.disabled) b.opacity=0.5; return b;};
const AIINPUT=(b,state)=>{const ch=AL(b,'VERTICAL',{gap:8}); for(const c of ['静安 情侣 夜间 Citywalk 90分钟','外滩 亲子 半天 城市打卡','苏州河 摄影 徒步 2小时']){const x=AL(ch,'HORIZONTAL',{fill:'sheet-inset',r:999,pad:[6,12,6,12]}); TX(x,c,'MP/body','ink-2',{size:13}); if(state==='busy') x.opacity=0.5;}
 const ta=INPUT(b,state?'静安 情侣 夜间 Citywalk 90分钟':'一句话描述想法，如“静安 情侣 夜间 Citywalk 90分钟”',{value:!!state,h:96,disabled:state==='busy'});
 const r=AL(b,'HORIZONTAL',{gap:10}); r.layoutSizingHorizontal='FILL'; INPUT(r,'俱乐部风格(选填)',{fillW:false,grow:true,disabled:state==='busy'}); const d=INPUT(r,state?'90':'时长(分钟)',{fillW:false,value:!!state,disabled:state==='busy'}); d.primaryAxisSizingMode='FIXED'; d.resize(120,d.height);
 const a=AL(b,'HORIZONTAL',{gap:10,align:'CENTER'}); a.layoutSizingHorizontal='FILL';
 if(state==='busy'){const p=PILL(a,'生成中…','disabled',{}); p.layoutGrow=1; const c=PILL(a,'取消','secondary',{}); }
 else {const p=PILL(a,state==='error'?'重试':'生成方案','primary',{}); p.layoutGrow=1;}};
for(const [lab,st,note] of [['069 AI 策划 · 输入','', 'B-C02-24 full sheet「AI 策划活动」(host only). Idea chips from the page script fill the text area.'],['069 AI 策划 · 生成中','busy','B-C02-25 fields disabled while /api/ai/club/design runs; 取消 cancels the request.'],['069 AI 策划 · 失败','error','B-C02-27 inline error「方案没能生成」with the server sentence; the button becomes 重试.']]){
 const f=await FRAME(SEC,lab); await UNDER(f); const b=SHEET(f,'AI 策划活动',{detent:'large',gap:12}); AIINPUT(b,st);
 if(st==='error'){const e=INST(b,'ie',null,{title:'方案没能生成',sub:'AI 服务暂时繁忙，请稍后重试',showAction:false}); e.layoutSizingHorizontal='FILL';}
 NOTE(f,note); out[lab]=f.id;}
{const f=await FRAME(SEC,'069 AI 策划 · 方案',{h:1500}); await UNDER(f); const b=SHEET(f,'AI 策划活动',{h:1440,gap:12}); AIINPUT(b,'done');
 const r=AL(b,'VERTICAL',{gap:10,pad:16,r:16,fill:'sheet-inset',name:'plan result (sample AI output)'}); r.layoutSizingHorizontal='FILL';
 TX(r,'静安夜色 · 双人慢行','MP/sheet-title','ink',{size:20}); TX(r,'从愚园路到武康路的 90 分钟夜间 Citywalk','MP/body','ink-2');
 const tg=AL(r,'HORIZONTAL',{gap:6}); for(const t of ['情侣','夜间','Citywalk','约 90 分钟']){const x=AL(tg,'HORIZONTAL',{fill:'surface-3',r:6,pad:[2,8,2,8]}); TX(x,t,'MP/tag','ink-2');}
 TX(r,'两人拿到一封写给“未来的我们”的信，沿着梧桐街区寻找信里提到的五个地方，在最后一站拆开回信。','MP/body','ink',{fillW:true,size:15});
 TX(r,'为什么适合:俱乐部常办夜间路线，成员多为两人结伴参加。','MP/body','ink-3',{fillW:true});
 TX(r,'路线节点 · 5','MP/label','ink-3',{size:13});
 for(const [i,n,a] of [[1,'愚园路入口','愚园路 1088 号'],[2,'街头咖啡地图驿站','愚园路 1107 号'],[3,'武康大楼','淮海中路 1850 号'],[4,'梧桐书店','武康路 210 号'],[5,'安福路口','安福路 1 号']]){const row=AL(r,'HORIZONTAL',{gap:10,align:'CENTER'}); row.layoutSizingHorizontal='FILL'; const no=AL(row,'HORIZONTAL',{fill:'surface-3',r:999,main:'CENTER',align:'CENTER'}); no.primaryAxisSizingMode='FIXED'; no.counterAxisSizingMode='FIXED'; no.resize(24,24); TX(no,String(i),'MP/tag','ink'); const c=AL(row,'VERTICAL',{gap:1}); TX(c,n,'MP/body-strong','ink'); TX(c,a,'MP/caption','ink-3');}
 TX(r,'风险提示','MP/label','ink-3',{size:13}); for(const t of ['· 武康大楼路口夜间人多，集合点选在安福路口','· 两站之间需过马路，提醒走斑马线']) TX(r,t,'MP/body','ink-2',{fillW:true});
 TX(r,'可对接商家建议','MP/label','ink-3',{size:13}); TX(r,'· 第 2 站可找咖啡店承接线索驿站','MP/body','ink-2',{fillW:true});
 const ph=AL(r,'HORIZONTAL',{align:'CENTER'}); ph.layoutSizingHorizontal='FILL'; ph.primaryAxisAlignItems='SPACE_BETWEEN'; TX(ph,'宣传文案','MP/label','ink-3',{size:13}); const cp=AL(ph,'HORIZONTAL',{gap:4,align:'CENTER'}); IC(cp,'copy',14,'ink-2'); TX(cp,'复制','MP/body-strong','ink-2',{size:13});
 TX(r,'这个周末，带上 TA，去梧桐树下找一封写给你们的信。','MP/body','ink',{fillW:true});
 const ft=AL(b,'VERTICAL',{gap:6,align:'CENTER'}); ft.layoutSizingHorizontal='FILL'; PILL(ft,'用这个方案去发布','primary',{fillW:true}); TX(ft,'发布前需补充封面和分类','MP/caption','ink-3');
 NOTE(f,'B-C02-26 result (sample AI output). Button above the result reads 换一版; 用这个方案去发布 opens the TE editor prefilled. Drawn full height; the sheet scrolls.'); out.plan=f.id;}
// 28 选择场次 / 30 选择导演场次
const SESS=[['周日 11月22日 14:00','外滩钟声 · 老城寻踪三章 · 5 人报名'],['周六 11月28日 19:30','外滩夜探 · 0 人报名']];
for(const [lab,title,note,ex] of [['069 选择场次','选择场次','B-C02-28 medium sheet before showing a group code; note 仅限本场次.',true],['069 选择导演场次','选择导演场次','B-C02-30 medium sheet: which session the director console opens.',false]]){
 const f=await FRAME(SEC,lab); await UNDER(f,'活动'); const b=SHEET(f,title,{h:360}); if(ex){const n=AL(b,'HORIZONTAL',{gap:6,align:'CENTER'}); IC(n,'alert',14,'ink-3'); TX(n,'仅限本场次','MP/caption','ink-3');}
 const g=AL(b,'VERTICAL',{gap:0,r:14,fill:'sheet-inset',pad:[0,14,0,14]}); g.layoutSizingHorizontal='FILL'; SESS.forEach(([a,s],i)=>ROW(g,a,'',{sub:s,h:62,last:i===SESS.length-1}));
 NOTE(f,note); out[lab]=f.id;}
// 29 团核销码
{const f=await FRAME(SEC,'069 团核销码'); await UNDER(f,'活动'); const b=SHEET(f,'',{h:520}); const q=INST(b,'qr',null,{name:'外滩钟声 · 老城寻踪三章 · 团核销码',desc:'合作商家扫码登记'}); q.layoutSizingHorizontal='FILL'; const sv=AL(b,'HORIZONTAL',{main:'CENTER'}); sv.layoutSizingHorizontal='FILL'; PILL(sv,'保存到相册','secondary',{});
 NOTE(f,'B-C02-29 K12 medium sheet. Screen brightness rises while the code is shown.'); out.code=f.id;}
// 31 发布什么？
{const f=await FRAME(SEC,'069 发布什么？'); await UNDER(f,'活动'); const b=SHEET(f,'发布什么？',{h:420,gap:10});
 for(const [k,t,d] of [['route','城市定向','需设置具体的集合时间与地点，适合强组织的团体活动。'],['pin','自由探索','只需设置有效期，用户在规定时间内自由前往体验。'],['cal','活动','一次性的线下聚会:定时间、地点与票种，不含路线与节点。']]){const r=AL(b,'HORIZONTAL',{gap:12,pad:14,r:14,fill:'sheet-inset',align:'CENTER'}); r.layoutSizingHorizontal='FILL'; const ic=AL(r,'HORIZONTAL',{fill:'surface-3',r:12,main:'CENTER',align:'CENTER'}); ic.primaryAxisSizingMode='FIXED'; ic.counterAxisSizingMode='FIXED'; ic.resize(40,40); IC(ic,k,20,'ink'); const c=AL(r,'VERTICAL',{gap:2}); c.layoutGrow=1; TX(c,t,'MP/card-title','ink'); TX(c,d,'MP/caption','ink-3',{fillW:true}); IC(r,'chev',16,'ink-3');}
 NOTE(f,'B-C02-31 medium sheet, three options (新稿 G1 151:115).'); out.what=f.id;}
// 32 确认 alerts
{const f=await FRAME(SEC,'069 确认'); await CLUBHEAD(f,'帖文'); SCRIM(f);
 const specs=[['删除这条帖文？','删除后不能恢复，评论也会一起删除。','取消','删除'],['删除这条评论？','删除后不能恢复。','取消','删除'],['退出俱乐部？','退出后不再收到俱乐部通知，已报名的活动不受影响。','再想想','退出']];
 let y=130; for(const [t,m,c,k] of specs){const a=INST(f,'alert','Tone=Destructive',{title:t,message:m,cancel:c,confirm:k}); a.x=(393-a.width)/2; a.y=y; y+=a.height+40;}
 NOTE(f,'B-C02-32 three K10 alerts on one frame (one shows at a time). Body copy is the page script’s confirm text where present; wording here is a sample.'); out.confirms=f.id;}
// generic
{const f=await FRAME(SEC,'069 加载中'); NAV(f,''); SKEL(f,'detail',110); NOTE(f,'K1 detail skeleton under the nav bar; shows after 200 ms.'); out.loading=f.id;}
{const f=await FRAME(SEC,'069 未登录'); NAV(f,''); STATE(f,'Lock',{title:'登录后查看俱乐部',showSub:false,action:'去登录',showAction:true}); out.login=f.id;}
{const f=await FRAME(SEC,'069 链接已失效'); NAV(f,''); STATE(f,'Info',{title:'链接已失效',sub:'这个俱乐部链接可能已过期，可以回到俱乐部列表找找',showSub:true,action:'返回',showAction:true}); out.missing=f.id;}
{const f=await FRAME(SEC,'069 已解散'); NAV(f,''); STATE(f,'Info',{title:'这个俱乐部已解散',sub:'俱乐部的帖文和活动已不再公开',showSub:true,action:'返回',showAction:true}); NOTE(f,'K5 gone state: title is the server sentence.'); out.gone=f.id;}
return out;
