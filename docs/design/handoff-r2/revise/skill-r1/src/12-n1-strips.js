// B3d · N1 · SR1-46 five-frame moment strips (+ die flick), SR1-49 Reduce Motion + XXL proof per strip, Q6
await goPage(N1);
const pg=figma.currentPage; const pm=await byId('382:1364'); const ERR={}; async function SETR(n,rs,tag){ try{ await n.setReactionsAsync(rs); return true; }catch(e){ const k=tag+': '+String(e).slice(0,60); ERR[k]=(ERR[k]||0)+1; return false; } }
const colT=Object.values(COLS).find(c=>c.name==='Type'); const xxl=colT&&colT.modes.find(m=>/xxxLarge/.test(m.name));
let sec=pg.children.find(s=>s.type==='SECTION'&&/^Moments · 分镜/.test(s.name)); if(!sec){ sec=figma.createSection(); sec.name='Moments · 分镜 (skill-r1 SR1-46 / SR1-49)'; const bottom=Math.max(...pg.children.filter(c=>c!==sec).map(c=>c.y+c.height)); sec.x=0; sec.y=bottom+200; R.created.push(sec.id); }
const STRIPS=[
 {key:'claim',title:'圈下了',stage:'Claim',h:'圈下了',l:'武康大楼现在是你的。每个到访的人都会给你留下 12 积分。',c:['−120 积分','保护到 明天 14:20','探索 +30'],p:'去看看我的地盘',s:'分享地契',hap:['','impact heavy (flag contact) · low thud','notification success +150 ms','','']},
 {key:'roll-win',title:'掷骰 · 拿下',stage:'Won',pre:'Rolling',h:'17',hs:'t-hero',l:'14 + 3 · 武康大楼归你了',ls:'t-3',c:['前哨 Lv1 → 插旗 Lv0','保护 24 小时','探索 +40'],p:'去看看我的地盘',s:'分享地契',hap:['impact light every 120 ms, rising · rattle','impact rigid (die lands) · click','custom: two rising taps','','']},
 {key:'roll-lose',title:'掷骰 · 没拿下',stage:'Lost roll',pre:'Rolling',h:'这次没拿下',l:'掷出 5 + 3 = 8，差 1 点。',c:['今天还可挑战 2 次','24 小时后可再来'],p:'回到地图',s:'看看规则',hap:['impact light every 120 ms, rising · rattle','impact rigid (die lands) · click','impact soft, single','','']},
 {key:'taken',title:'被抢',stage:'Place lost',h:'武康大楼被拿走了',l:'林小舟 在 14:20 掷出 17。补偿已经到账。',c:['+40 积分 补偿','24 小时后可夺回'],p:'知道了',s:'看看别的地盘',hap:['','notification warning','','','']},
 {key:'rent',title:'收租入账',stage:'Rent',h:'+186 积分',hs:'t-hero',l:'今天 14 位玩家到访你的 3 块地盘。',c:['武康大楼 +96','安福路 12 号 +54','愚园路 1088 弄 +36'],p:'看看明细',s:'好的',hap:['','impact soft · coin','','','']},
 {key:'level',title:'升级',stage:'Level',h:'城识 升到 Lv 4',l:'你在 7 天里点亮了 12 个新地点。',c:['Lv 3 → Lv 4','称号 · 街巷通'],p:'查看六维',s:'分享',hap:['','impact medium','notification success','','']},
];
const BEATS=['anticipation','action','impact','settle','result'];
function inst(m,beat){ const i=pm.createInstance(); const props={Headline:m.h,'Chip 1':m.c[0],'Show chip 2':m.c.length>1,'Show chip 3':m.c.length>2,Line:m.l}; if(m.c[1]) props['Chip 2']=m.c[1]; if(m.c[2]) props['Chip 3']=m.c[2]; setProps(i,props);
  const st=i.findOne(n=>n.name==='Stage'&&n.type==='INSTANCE'); const kind=(beat<=1&&m.pre)?m.pre:m.stage; setProps(st,{Kind:kind});
  const pr=i.findOne(n=>n.name==='Primary'&&n.type==='INSTANCE'); setProps(pr,{Label:m.p}); const se=i.findOne(n=>n.name==='Secondary'&&n.type==='INSTANCE'); setProps(se,{Label:m.s});
  const hl=i.findOne(n=>n.type==='TEXT'&&n.name==='headline'), ln=i.findOne(n=>n.type==='TEXT'&&n.name==='line'), ch=i.findOne(n=>n.name==='chips');
  const stObj=st.children.filter(c=>c.type==='INSTANCE');
  if(beat===0){ st.opacity=0.0; hl.opacity=0; ln.opacity=0; ch.opacity=0; pr.opacity=0; se.opacity=0; }
  if(beat===1){ hl.opacity=0; ln.opacity=0; ch.opacity=0; pr.opacity=0; se.opacity=0; for(const o of stObj) o.opacity=o===stObj[stObj.length-1]&&stObj.length>1?0:1; }
  if(beat===2){ ln.opacity=0; ch.opacity=0; pr.opacity=0; se.opacity=0; hl.opacity=0.0; }
  if(beat===3){ ch.opacity=0; pr.opacity=0; se.opacity=0; }
  return {i,hl,ln}; }
let row=0; const made={}; let reacts=0;
for(const m of STRIPS){ const y=120+row*1100; const fr=[];
  const lab=await TX(null,`${m.title} · 5 beats (anticipation → action → impact → settle → result) · tap anywhere = result`,'t-3','ink'); sec.appendChild(lab); lab.x=80; lab.y=y-60; lab.fills=[RAW('8E8E93')];
  for(let b=0;b<5;b++){ const f=figma.createFrame(); sec.appendChild(f); f.name=`${m.key}-${b+1} · ${m.title} · ${BEATS[b]}`; f.resize(393,852); f.fills=[PAINT('bg')]; f.x=80+b*473; f.y=y; f.clipsContent=true; const {i,hl,ln}=inst(m,b); f.appendChild(i); if(m.hs) await hl.setTextStyleIdAsync(TS[m.hs].id); if(m.ls){ await ln.setTextStyleIdAsync(TS[m.ls].id); ln.fills=[PAINT('ink')]; } R.created.push(f.id); fr.push(f);
    ANN(f,`**Motion · ${m.title} · ${BEATS[b]} (skill-r1 SR1-46)**\n- Transition into this frame: Smart Animate · moment spring (Figma 247 / 17.3)\n- Haptic: ${m.hap[b]||'none'}\n- Tap anywhere → result`,'I',/^\*\*Motion · /); }
  // Reduce Motion + XXL proofs
  const rm=figma.createFrame(); sec.appendChild(rm); rm.name=`${m.key} · Reduce Motion`; rm.resize(393,852); rm.fills=[PAINT('bg')]; rm.x=80+5*473+80; rm.y=y; const r1=inst(m,4); rm.appendChild(r1.i); if(m.hs) await r1.hl.setTextStyleIdAsync(TS[m.hs].id); R.created.push(rm.id);
  ANN(rm,`**skill-r1 SR1-49 · Reduce Motion** · No stage motion: the result cross-fades in over 200 ms. Haptics stay (${m.hap.filter(Boolean).join(' · ')||'none'}). VoiceOver announces the headline and line.`,'A',/^\*\*skill-r1 SR1-49/);
  const xx=figma.createFrame(); sec.appendChild(xx); xx.name=`${m.key} · XXL`; xx.resize(393,1000); xx.fills=[PAINT('bg')]; xx.x=rm.x+473; xx.y=y; const r2=inst(m,4); xx.appendChild(r2.i); r2.i.resize(393,1000); if(colT&&xxl) xx.setExplicitVariableModeForCollection(colT,xxl.modeId); R.created.push(xx.id);
  ANN(xx,'**skill-r1 SR1-49 · XXL** · Type collection at xxxLarge: headline wraps to two lines, chips wrap and stack, primary stays reachable; the frame grows (scroll).','A',/^\*\*skill-r1 SR1-49/);
  for(let b=0;b<4;b++){ if(await SETR(fr[b],[{trigger:{type:'AFTER_TIMEOUT',timeout:b===0?0.15:(b===1?0.45:0.35)},actions:[{type:'NODE',destinationId:fr[b+1].id,navigation:'NAVIGATE',transition:{type:'SMART_ANIMATE',easing:SP('moment'),duration:DUR.moment},resetScrollPosition:false}]},{trigger:{type:'ON_CLICK'},actions:[{type:'NODE',destinationId:fr[4].id,navigation:'NAVIGATE',transition:{type:'DISSOLVE',easing:SP('press'),duration:0.2},resetScrollPosition:false}]}],'strip')) reacts++; }
  made[m.key]=fr.map(f=>f.id).concat([rm.id,xx.id]); row++; }
const W=80+7*473+80+80; sec.resizeWithoutConstraints(Math.max(sec.width,W),120+row*1100+40);
pg.flowStartingPoints=[...pg.flowStartingPoints.filter(f=>!/^分镜/.test(f.name)),...STRIPS.map(m=>({nodeId:made[m.key][0],name:'分镜 · '+m.title}))];
// ---- die flick (Q6) on N36 → N37 ----
for(const [a,b] of [['204:34340','204:34369']]){ const f=await byId(a); if(!f) continue; const h=figma.createRectangle(); f.appendChild(h); h.name='⌖ flick the die (drag)'; h.resize(393,440); h.x=0; h.y=54; h.fills=[]; await SETR(h,[{trigger:{type:'ON_DRAG'},actions:[{type:'NODE',destinationId:b,navigation:'NAVIGATE',transition:{type:'SMART_ANIMATE',easing:SP('moment'),duration:DUR.moment},resetScrollPosition:false}]}],'flick'); }
R.info={made,reacts,ERR,section:sec.id};
await sec.screenshot({scale:0.06});
R.created=R.created.length; R.ann=R.ann.length; return R;
