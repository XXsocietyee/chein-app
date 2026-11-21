// B2c · N1 · SR1-25 (moments on Player/Moment), SR1-33 (Moment/Art everywhere), Q6, + fixes from #15
await goPage(N1);
const pm=await byId('382:1364'), stageSet=await byId('382:1362');
const MOM={
 '204:26968':{stage:'Claim',h:'圈下了',l:'老麦咖啡馆现在是你的。每个到访的人都会给你留下 12 积分。',c:['−120 积分','保护到 明天 14:20','探索 +30'],p:'去看看我的地盘',s:'分享地契'},
 '204:34340':{stage:'Ready',h:'准备掷骰',l:'甩一下手机掷骰，或点下面的按钮。',c:['任务 +2','洞察 +1'],p:'掷骰',s:'再想想',q:['Q6','Throw with a flick (ON_DRAG on the die); the 掷骰 button stays as the second way.']},
 '204:34369':{stage:'Rolling',h:'掷骰中',l:null,c:['需要 ≥ 9'],p:'掷骰中',pState:'Loading',s:null},
 '204:34407':{stage:'Won',h:'17',hStyle:'t-hero',l:'14 + 3 · 转角花店归你了',lStyle:'t-3',c:['前哨 Lv1 → 插旗 Lv0','保护 24 小时','探索 +40'],p:'去看看我的地盘',s:'分享地契'},
 '204:34440':{stage:'Lost roll',h:'这次没拿下',l:'掷出 5 + 3 = 8，差 1 点。',c:['今天还可挑战 2 次','24 小时后可再来'],p:'回到地图',s:'看看规则'},
 '204:34476':{stage:'Place lost',h:'老麦咖啡馆被拿走了',l:'林小舟 在 14:20 掷出 17。补偿已经到账。',c:['+40 积分 补偿','24 小时后可夺回'],p:'知道了',s:'看看别的地盘'},
 '204:34510':{stage:'Defended',h:'守住了',l:'林小舟 掷出 6，没能拿走老麦咖啡馆。',c:['保护 +24 小时','+20 积分'],p:'好的',s:'查看挑战记录'},
 '207:2460':{stage:'Level',h:'城识 升到 Lv 4',l:'你在 7 天里点亮了 12 个新地点。',c:['Lv 3 → Lv 4','称号 · 街巷通'],p:'查看六维',s:'分享'},
};
const done={};
for(const [fid,m] of Object.entries(MOM)){ const f=await byId(fid); if(!f){ R.warn.push('missing '+fid); continue; }
  const keep=f.children.filter(c=>c.type==='INSTANCE'&&/Status Bar/.test(c.name)); let nav=null;
  for(const n of f.findAll(x=>'reactions' in x&&x.reactions&&x.reactions.length)) for(const r of n.reactions) for(const a of actsOf(r)) if(!nav&&a&&a.type==='NODE'&&a.destinationId) nav={trigger:r.trigger,actions:[a]};
  const frameReactions=(f.reactions||[]).map(r=>({trigger:r.trigger,actions:actsOf(r)}));
  for(const c of [...f.children]) if(!keep.includes(c)){ R.removed.push(c.id); c.remove(); }
  f.layoutMode='NONE'; f.resize(393,852); f.fills=[PAINT('bg')];
  const i=pm.createInstance(); f.insertChild(0,i); i.x=0; i.y=0; R.created.push(i.id);
  const props={Headline:m.h,'Chip 1':m.c[0]||'','Show chip 2':m.c.length>1,'Show chip 3':m.c.length>2}; if(m.l) props.Line=m.l; if(m.c[1]) props['Chip 2']=m.c[1]; if(m.c[2]) props['Chip 3']=m.c[2]; setProps(i,props);
  const st=i.findOne(n=>n.name==='Stage'&&n.type==='INSTANCE'); if(st) setProps(st,{Kind:m.stage});
  const pr=i.findOne(n=>n.name==='Primary'&&n.type==='INSTANCE'); if(pr){ setProps(pr,{Label:m.p}); if(m.pState) setProps(pr,{State:m.pState}); if(nav) try{ await pr.setReactionsAsync([nav]); }catch(e){ R.warn.push('react '+fid); } }
  const se=i.findOne(n=>n.name==='Secondary'&&n.type==='INSTANCE'); if(se){ if(m.s) setProps(se,{Label:m.s}); else se.visible=false; }
  const hl=i.findOne(n=>n.type==='TEXT'&&n.name==='headline'); if(hl&&m.hStyle) await hl.setTextStyleIdAsync(TS[m.hStyle].id);
  const ln=i.findOne(n=>n.type==='TEXT'&&n.name==='line'); if(ln){ if(!m.l) ln.visible=false; else if(m.lStyle){ await ln.setTextStyleIdAsync(TS[m.lStyle].id); ln.fills=[PAINT('ink')]; } }
  if(frameReactions.length) await f.setReactionsAsync(frameReactions);
  for(const k of keep) f.appendChild(k);
  SR(f,'SR1-25','On Player/Moment: Stage '+m.stage+' (top 56%), headline, one line, ≤ 3 delta chips, one primary, one text link. Moment spring 247 / 17.3 for the stage object; tap anywhere skips to the settled frame.');
  if(/Won|Lost roll|Place lost|Defended|Level|Claim/.test(m.stage)) OWN(f,'Q8','Moment object drawn in the Badge/Art language (Moment/Art).');
  if(m.q) OWN(f,m.q[0],m.q[1]);
  done[fid]=m.stage; }
R.info.moments=done;
// ---- fixes from #15 ----
{ const f=await byId('204:27271'); const sh=f.children.find(c=>c.name==='sheet'); if(sh){ const ins=sh.findAll(n=>n.type==='INSTANCE'&&!n.id.includes(';')); for(const b of ins){ const mc=await b.getMainComponentAsync(); if(mc&&mc.parent&&mc.parent.id===PBTN&&/Kind=Text/.test(mc.name)) setProps(b,{Label:'换一块地'}); } } }
for(const fid of ['204:34263','204:23691','204:23400','204:23542','204:23832','204:23956']){ const f=await byId(fid); const sh=f.children.find(c=>c.name==='sheet'&&c.type==='FRAME'); if(!sh) continue; sh.primaryAxisSizingMode='AUTO';
  if(sh.height>f.height-60){ for(const t of sh.children.filter(c=>c.type==='TEXT'&&c.fontSize<=12)){ R.removed.push(t.id); t.remove(); } }
  sh.y=Math.max(54,f.height-sh.height); if(sh.y===54&&sh.height>f.height-54){ sh.clipsContent=true; sh.layoutMode==='VERTICAL'; } R.info['sheet '+fid]=Math.round(sh.height); }
for(const id of ['204:26968','204:34407','204:34440','204:34340','204:34263']){ const n=await byId(id); await n.screenshot({scale:0.35}); }
R.created=R.created.length; R.removed=R.removed.length; return R;
