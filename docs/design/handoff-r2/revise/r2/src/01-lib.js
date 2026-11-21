// 01-lib · Library 6:3 · items 4.2 (Theme Card meta), 4.3 (Club/Row Menu bar), 4.4 (Merchant/Nav Bar More + Merchant/Menu),
// 4.6 (system stand-ins), 4.7 (Editor/Switch neutral, Q3), 5.6 (Merchant/Metric Module), Q10 handbook board. Safe to re-run (idempotent by name).
const lib=await goPage('6:3');
const colorCol=V['ink']?COLS[V['ink'].variableCollectionId]:null;
function setMode(node,dark){ if(!colorCol) return; const m=colorCol.modes.find(m=>(dark?/MP-Dark/i:/MP-Light/i).test(m.name)); if(m) node.setExplicitVariableModeForCollection(colorCol,m.modeId); }
const right=Math.max(...lib.children.map(c=>c.x+c.width));
let SEC=lib.children.find(s=>s.type==='SECTION'&&s.name.startsWith('R2 · verify-r1'));
if(!SEC){ SEC=figma.createSection(); SEC.name='R2 · verify-r1 additions (menu, metric, system stand-ins)'; SEC.x=right+400; SEC.y=0; SEC.resizeWithoutConstraints(2400,1400); setMode(SEC,false); R.created.push(SEC.id); }
const inSec=nm=>SEC.children.find(c=>c.name===nm);
const desc=m=>m.children.map(c=>`${c.type}:${c.name}${c.type==='TEXT'?'='+c.characters:''}${'layoutMode' in c?'['+c.layoutMode+']':''}@x${Math.round(c.x)} w${Math.round(c.width)}${c.visible?'':' hidden'}`);

// ---------- 4.2 Player/Theme Card meta row ----------
{ const TC=await byId('287:43163'); const out=[];
  for(const v of (TC.type==='COMPONENT_SET'?TC.children:[TC])){
    const metas=v.findAll(n=>(n.type==='FRAME'||n.type==='GROUP'||n.type==='INSTANCE')&&/meta/i.test(n.name)&&!insideInstance(n,v));
    for(const m of metas){ const before=desc(m); const acts=[];
      if(m.type==='GROUP'||m.type==='INSTANCE'){ out.push({v:v.name,m:m.name,type:m.type,before,acts:['skip '+m.type]}); continue; }
      // 1) remove duplicate text layers (same characters as a sibling; keep the one bound to a property)
      const walk=[m,...m.findAll(n=>n.type==='FRAME')];
      for(const f of walk){ const ts=f.children.filter(c=>c.type==='TEXT'); const seen={};
        for(const t of ts){ const k=t.characters.trim(); if(!k) continue; const bound=t.componentPropertyReferences&&t.componentPropertyReferences.characters;
          if(seen[k]){ const keep=bound?t:seen[k]; const drop=keep===t?seen[k]:t; acts.push('rm dup '+drop.name+'='+k); R.removed.push(drop.id); drop.remove(); seen[k]=keep; } else seen[k]=t; } }
      // 2) every container in the row becomes horizontal auto-layout, hug, gap 4, children ordered by x
      for(const f of [m,...m.findAll(n=>n.type==='FRAME'&&n.children.length>0&&texts(n).length>0)]){
        if(f.layoutMode==='NONE'){ const kids=[...f.children].sort((a,b)=>a.x-b.x); kids.forEach((k,i)=>f.insertChild(i,k)); f.layoutMode='HORIZONTAL'; acts.push('AL '+f.name); }
        if(f.layoutMode==='HORIZONTAL'){ f.itemSpacing=f===m?6:4; f.primaryAxisSizingMode='AUTO'; f.counterAxisAlignItems='CENTER'; f.clipsContent=false; }
        for(const t of f.children.filter(c=>c.type==='TEXT')){ if(t.textAutoResize!=='WIDTH_AND_HEIGHT'&&t.textTruncation!=='ENDING'){ await loadFontsOf(t); t.textAutoResize='WIDTH_AND_HEIGHT'; } }
      }
      R.touched.push(m.id); out.push({v:v.name,m:m.name,before,after:desc(m),acts}); } }
  R.info['4.2']=out; }

// ---------- 4.3 Club/Row Menu: black bar → 0.5 pt separator ----------
{ const RM=await byId('291:61128'); const out=[];
  for(const c of (RM.type==='COMPONENT_SET'?RM.children:[RM])){
    const bars=c.findAll(n=>!insideInstance(n,c)&&n.type!=='TEXT'&&'fills' in n&&n.height>=2&&n.height<=14&&n.width>=c.width*0.5&&texts(n).length===0&&(()=>{ const s=solidOf(n); return s&&lum(s)<0.06; })());
    for(const b of bars){ const before=`${b.type} ${b.name} h${b.height} ${boundName(b.fills[0])||'raw'}`;
      if(b.parent.layoutMode&&b.parent.layoutMode!=='NONE'&&b.layoutPositioning!=='ABSOLUTE'){ b.layoutSizingVertical='FIXED'; }
      b.resize(b.width,0.5); b.fills=[PAINT('sep',{dark:true})]; b.name='separator 0.5'; R.touched.push(b.id); out.push(before+' → 0.5 sep'); }
    if(!bars.length) out.push('no bar found in '+c.name+': '+desc(c).join(' | ').slice(0,600)); }
  R.info['4.3']=out; }

// ---------- 4.4 Merchant/Nav Bar Trailing = More ----------
{ const MN=await byId('316:4825'); const defs=MN.componentPropertyDefinitions; const info={type:MN.type,defs:Object.entries(defs).map(([k,d])=>k+':'+d.type+(d.variantOptions?'['+d.variantOptions.join('/')+']':''))};
  const tk=Object.keys(defs).find(k=>k.split('#')[0]==='Trailing');
  if(MN.type==='COMPONENT_SET'&&tk&&defs[tk].type==='VARIANT'&&!defs[tk].variantOptions.includes('More')){
    const base=defs[tk].variantOptions.includes('None')?'None':defs[tk].variantOptions[0]; const srcs=MN.children.filter(v=>v.name.split(', ').includes('Trailing='+base)); info.added=[];
    let x=Math.max(...MN.children.map(v=>v.x+v.width))+24;
    for(const s of srcs){ const c=s.clone(); MN.appendChild(c); c.name=s.name.replace('Trailing='+base,'Trailing=More'); c.x=x; c.y=s.y; x+=c.width+24;
      const hit=AL('HORIZONTAL','more · hit 44',{justify:'CENTER'}); hit.resize(44,44); hit.primaryAxisSizingMode='FIXED'; hit.counterAxisSizingMode='FIXED';
      const ic=SVG(ICO.more('#111111'),'icon/more',24); hit.appendChild(ic); for(const v of ic.findAll(n=>'fills' in n&&n.type!=='FRAME')) v.fills=[PAINT('ink')];
      const title=texts(c).sort((a,b)=>b.fontSize-a.fontSize)[0];
      if(c.layoutMode==='HORIZONTAL'){ c.appendChild(hit); } else { c.appendChild(hit); hit.x=c.width-8-44; hit.y=title?Math.round(title.y+title.height/2-22):Math.round(c.height-44); hit.constraints={horizontal:'MAX',vertical:'MIN'}; }
      info.added.push(c.id); R.created.push(c.id); }
    MN.resizeWithoutConstraints(Math.max(MN.width,x),MN.height);
    MN.description=(MN.description||'')+'\nTrailing=More: ⋯ pull-down (44 pt target, VoiceOver “更多操作”). Holds page-level actions that are rare or risky (暂停接待, 下线, 清除声音); destructive item last, red (verify-r1 4.4).'; }
  R.info['4.4 nav']=info; }

// ---------- Merchant/Menu (pull-down shown open) ----------
let MENU=inSec('Merchant/Menu');
if(!MENU){ MENU=figma.createComponent(); SEC.appendChild(MENU); MENU.name='Merchant/Menu'; MENU.x=80; MENU.y=120; MENU.layoutMode='VERTICAL'; MENU.primaryAxisSizingMode='AUTO'; MENU.counterAxisSizingMode='FIXED'; MENU.resize(250,100); MENU.itemSpacing=0; MENU.cornerRadius=13; MENU.clipsContent=true;
  MENU.fills=[PAINT('surface')]; MENU.effects=[{type:'DROP_SHADOW',color:{r:0,g:0,b:0,a:0.16},offset:{x:0,y:8},radius:24,spread:0,visible:true,blendMode:'NORMAL'}];
  const defaults=['暂停接待','本站设置','编辑信息','下线'];
  for(let i=1;i<=4;i++){ const row=AL('HORIZONTAL','item '+i,{pad:[0,16,0,16]}); MENU.appendChild(row); row.layoutSizingHorizontal='FILL'; row.counterAxisSizingMode='FIXED'; row.resize(250,44); row.layoutSizingHorizontal='FILL';
    if(i<4){ row.strokes=[PAINT('sep')]; row.strokeAlign='INSIDE'; row.strokeTopWeight=0; row.strokeLeftWeight=0; row.strokeRightWeight=0; row.strokeBottomWeight=0.5; }
    const t=await TXT(row,defaults[i-1],{size:17,lh:22,color:i===4?'bad':'ink',name:'label'}); t.layoutSizingHorizontal='FILL'; t.textAutoResize='HEIGHT';
    const k=MENU.addComponentProperty('item'+i,'TEXT',defaults[i-1]); t.componentPropertyReferences={characters:k};
    if(i>1){ const sk=MENU.addComponentProperty('show'+i,'BOOLEAN',true); row.componentPropertyReferences={visible:sk}; } }
  MENU.description='Pull-down menu, shown open (iOS Menu). 44 pt rows, 17 pt labels, 0.5 pt separators. item4 is the destructive slot (red, always last); hide unused rows with show2–show4. Opens from a ⋯ (Merchant/Nav Bar Trailing=More or a row ⋯). Motion: system menu spring from the anchor, .selection haptic on open. VoiceOver: each item is a button; destructive item says “删除类操作”.';
  R.created.push(MENU.id); }
R.info.menu=MENU.id;

// ---------- 5.6 Merchant/Metric Module (MR-24) ----------
let MET=inSec('Merchant/Metric Module');
if(!MET){ MET=figma.createComponent(); SEC.appendChild(MET); MET.name='Merchant/Metric Module'; MET.x=420; MET.y=120; MET.layoutMode='VERTICAL'; MET.primaryAxisSizingMode='AUTO'; MET.counterAxisSizingMode='FIXED'; MET.resize(361,100); MET.itemSpacing=10; MET.paddingTop=MET.paddingBottom=16; MET.paddingLeft=MET.paddingRight=16; MET.cornerRadius=12; MET.fills=[PAINT('surface')];
  const head=AL('HORIZONTAL','head',{gap:8}); add(MET,head,'FILL'); const tt=await TXT(head,'本周到店',{size:15,lh:20,w:'Semibold',name:'title'}); tt.layoutSizingHorizontal='FILL'; tt.textAutoResize='HEIGHT'; await TXT(head,'近 7 天',{size:13,lh:18,color:'ink-2',name:'period'});
  const val=AL('HORIZONTAL','value row',{gap:8,align:'BASELINE'}); add(MET,val,'FILL'); const vt=await TXT(val,'12 人',{size:28,lh:34,w:'Bold',name:'value'}); const dt=await TXT(val,'比上周 +3',{size:13,lh:18,color:'ink-2',name:'delta'});
  const chart=figma.createFrame(); chart.name='chart · BarMark (axis + values)'; chart.fills=[]; add(MET,chart,'FILL'); chart.layoutSizingVertical='FIXED'; chart.resize(329,132); chart.layoutSizingHorizontal='FILL';
  const vals=[1,2,1,3,2,3,0], days=['一','二','三','四','五','六','日'], cur=5, maxV=3, top=18, base=104, bw=24, step=(329-28)/7;
  const grid=figma.createRectangle(); chart.appendChild(grid); grid.name='axis'; grid.resize(329-28,0.5); grid.x=28; grid.y=base; grid.fills=[PAINT('sep')];
  for(const [lbl,y] of [['3',top],['0',base]]){ const g=await TXT(chart,lbl,{size:11,lh:13,color:'ink-2',name:'y '+lbl}); g.x=4; g.y=y-7; }
  const gl=figma.createRectangle(); chart.appendChild(gl); gl.name='gridline 3'; gl.resize(329-28,0.5); gl.x=28; gl.y=top; gl.fills=[PAINT('sep')];
  for(let i=0;i<7;i++){ const h=Math.max(2,Math.round((base-top)*vals[i]/maxV)); const x=28+i*step+(step-bw)/2; const b=figma.createRectangle(); chart.appendChild(b); b.name='bar 周'+days[i]; b.resize(bw,h); b.x=x; b.y=base-h; b.topLeftRadius=b.topRightRadius=4; b.fills=[PAINT(i===cur?'ink':PN('ink-3','sep-strong','ink-2'))];
    const v=await TXT(chart,String(vals[i]),{size:11,lh:13,color:i===cur?'ink':'ink-2',w:i===cur?'Semibold':'Regular',name:'value 周'+days[i]}); v.x=x+bw/2-v.width/2; v.y=base-h-15;
    const d=await TXT(chart,days[i],{size:11,lh:13,color:i===cur?'ink':'ink-2',w:i===cur?'Semibold':'Regular',name:'day '+days[i]}); d.x=x+bw/2-d.width/2; d.y=base+6; }
  for(const [nm,t] of [['title',tt],['value',vt],['delta',dt]]){ const k=MET.addComponentProperty(nm,'TEXT',t.characters); t.componentPropertyReferences={characters:k}; }
  MET.description='MR-24 · One number, its comparison, a labelled chart. Neutral ink bars, the current period in ink (others ink-3), values on top, day labels and a 0/max axis. SwiftUI: Chart { BarMark } with .chartYAxis(AxisMarks(values:[0,max])) and an AXChartDescriptor (“本周到店 12 人，比上周多 3 人”). Motion: bars grow from the axis 400 ms ease-out on first appear only; Reduce Motion: fade. No data: value “—” with the reason underneath (keep the reason line).';
  R.created.push(MET.id); }
R.info.metric=MET.id;

// ---------- 4.6 system stand-ins (Apple iOS UI kit library is not available in this file) ----------
let DP=inSec('System/Date Picker · 系统控件替身');
if(!DP){ const mk=async(style,w,h)=>{ const c=figma.createComponent(); c.name='Style='+style; c.fills=[]; if(w>0) c.resize(w,h);
    if(style==='Graphical'){ const b=figma.createRectangle(); c.appendChild(b); b.name='system area (not drawn)'; b.resize(w,h); b.cornerRadius=13; b.fills=[PAINT('mp/input-filled')]; b.constraints={horizontal:'STRETCH',vertical:'STRETCH'}; }
    else { c.layoutMode='HORIZONTAL'; c.itemSpacing=8; c.primaryAxisSizingMode='AUTO'; c.counterAxisSizingMode='AUTO'; c.counterAxisAlignItems='CENTER'; for(const [nm,ww] of [['date',112],['time',72]]){ const b=figma.createRectangle(); c.appendChild(b); b.name=nm+' capsule (system)'; b.resize(ww,34); b.cornerRadius=8; b.fills=[PAINT('mp/input-filled')]; } }
    return c; };
  const g=await mk('Graphical',329,316), cp=await mk('Compact',0,0);
  DP=figma.combineAsVariants([g,cp],SEC); DP.name='System/Date Picker · 系统控件替身'; DP.x=880; DP.y=120; g.x=24; g.y=24; cp.x=24; cp.y=g.y+g.height+24; DP.resizeWithoutConstraints(24+329+24,cp.y+cp.height+24); DP.fills=[PAINT('bg')];
  DP.description='Stand-in for the SYSTEM DatePicker — do not draw a calendar or wheels. Graphical = DatePicker(…).datePickerStyle(.graphical) inside the sheet card; Compact = .compact (date + time capsules). The neutral block keeps layout honest; the label lives outside the phone frame as a note. Replace with the Apple iOS UI kit “Date Picker” instance if that library is ever added (verify-r1 4.6, CF-39).';
  R.created.push(DP.id); }
let KB=inSec('System/Keyboard · 系统控件替身');
if(!KB){ KB=figma.createComponent(); SEC.appendChild(KB); KB.name='System/Keyboard · 系统控件替身'; KB.x=1300; KB.y=120; KB.resize(393,291); KB.fills=[RAW('D1D3D9')];
  KB.description='Stand-in for the SYSTEM keyboard (number pad / .oneTimeCode). Neutral block only; never draw keys. Height 291 = iPhone 393-wide number pad incl. home-indicator area (verify-r1 4.6).'; R.created.push(KB.id); }
R.info.standins={datePicker:DP.id,keyboard:KB.id};

// ---------- 4.7 Editor/Switch tint → neutral (Q3) ----------
{ const SW=await byId('276:302'); const out=[];
  for(const v of SW.children){ for(const n of [v,...v.findAll(()=>true)]){ if(!('fills' in n)||!Array.isArray(n.fills)) continue; let ch=false;
      const nf=n.fills.map(p=>{ if(boundName(p)==='mp/switch-on'){ ch=true; return PAINT('ink'); } return p; }); if(ch){ n.fills=nf; out.push(v.name+' / '+n.name); R.touched.push(n.id); } } }
  if(!/neutral ink/.test(SW.description||'')) SW.description=(SW.description||'')+'\nOn tint: neutral ink track (was green mp/switch-on). Owner confirmed 2026-11-16 (verify-r1 Q3) — same as player and club.';
  OWNER(SW,'Q3','On track is neutral ink, not green; one tint across editor, player and club.');
  R.info['4.7']=out.length?out:'no mp/switch-on paint found: '+SW.children.map(v=>v.name+':'+v.findAll(n=>'fills' in n).map(n=>boundName(n.fills&&n.fills[0])||'raw').join(',')).join(' | '); }

// ---------- Q10 handbook board: three sheet headers by theme ----------
{ let H=lib.children.find(s=>s.type==='SECTION'&&s.name.startsWith('Handbook · 弹层标题栏'));
  if(!H){ H=figma.createSection(); H.name='Handbook · 弹层标题栏 · Sheet headers by theme (verify-r1 Q10)'; H.x=SEC.x; H.y=SEC.y+SEC.height+300; H.resizeWithoutConstraints(1480,980); R.created.push(H.id);
    const board=AL('VERTICAL','handbook · sheet headers',{gap:24,pad:[40],fill:'surface',align:'MIN'}); H.appendChild(board); board.x=40; board.y=40; board.counterAxisSizingMode='FIXED'; board.resize(1400,100); setMode(board,false);
    await TXT(board,'弹层标题栏：按主题三种，写定不再变',{size:28,lh:34,w:'Bold'});
    const intro=await TXT(board,'Owner confirmed 2026-11-16 (verify-r1 Q10)：保留三种，按主题区分。共同规则：同一时间只有一张 sheet；可调高度时显示抓手；下滑可关闭；有未保存修改时下滑或 ✕ 弹出「放弃修改 / 继续编辑」；高度切换弹簧 response .38 · damping .86；✕ 视觉 32、点按区域 44。HIG Sheets：有「完成」时必须有取消/关闭。',{size:15,lh:22,color:'ink-2'}); intro.layoutSizingHorizontal='FILL'; intro.textAutoResize='HEIGHT';
    const row=AL('HORIZONTAL','three styles',{gap:24,align:'MIN'}); add(board,row,'FILL');
    const cols=[
      {name:'编辑器 · Editor/Sheet Header（浅色）',id:'280:410',props:{Leading:'Close',Trailing:'Done'},dark:false,rule:'✕ 在左 · 标题居中（可带 eyebrow）· 完成 在右（编辑类）。\n选一项即提交的 sheet 不放 完成；结果 sheet 不放 ✕，以按钮收尾。\n推入子页时左侧变 ‹ 返回。'},
      {name:'玩家 · Player/Sheet（深色）',id:'287:462',props:{Detent:'Fit'},dark:true,rule:'抓手 · 标题左对齐 20 Bold · ✕ 在右（圆形）。\n主操作在底部整宽主按钮；没有「完成」。\n用于报名、提示、选择票种等一次性任务。'},
      {name:'商家 · Merchant/Sheet Header（浅色）',id:'316:4927',props:{Progress:'None'},dark:false,rule:'抓手 · 标题居中 18 Bold · ✕ 在右（圆形）。\n多步时 Progress=Step 显示步数。\n提交放在底部 Merchant/Bottom Bar，不放在标题栏。'}];
    for(const c of cols){ const col=AL('VERTICAL',c.name,{gap:12,pad:[20],r:16,fill:c.dark?'bg':'bg',dark:c.dark,align:'MIN'}); add(row,col,'FILL'); setMode(col,c.dark);
      await TXT(col,c.name,{size:17,lh:22,w:'Semibold',dark:c.dark});
      const comp=await byId(c.id); if(comp){ const tgt=comp.type==='COMPONENT_SET'?(variant(comp,c.props)||comp.defaultVariant||comp.children[0]):comp; const inst=tgt.createInstance(); col.appendChild(inst); if(inst.width>380){ inst.rescale(380/inst.width); } R.created.push(inst.id); } else R.warn.push('missing '+c.id);
      const t=await TXT(col,c.rule,{size:14,lh:21,color:'ink-2',dark:c.dark}); t.layoutSizingHorizontal='FILL'; t.textAutoResize='HEIGHT'; }
    OWNER(board,'Q10','Keep three sheet headers, one per theme; this board is the handbook entry.'); } }
return R;
