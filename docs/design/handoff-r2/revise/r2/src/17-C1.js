// 17-C1 · page C1 · 4.6 (246:6728, 246:6908: graphical DatePicker placeholder text → System/Date Picker stand-in, label outside the frame),
// 4.9 (F-09: 249:16773 links to ink + every blue text on C1 → ink; 238:20393 删除节点 row confirmed or added), 5.7 (CF-15 census + fixes on C1).
const PG=await goPage('237:14642');
const absY=n=>n.absoluteTransform[1][2];
const DP=await byId(DP_ID); const DPG=variant(DP,{Style:'Graphical'}), DPC=variant(DP,{Style:'Compact'});
// ---- 4.6 ----
{ const out=[];
  for(const id of ['246:6728','246:6908']){ const F=await byId(id); if(!F){ out.push(id+' missing'); continue; }
    const lab=texts(F).filter(t=>/DatePicker|系统日历|可选范围|\(\.graphical\)|\.compact/.test(t.characters)); const o={id,labels:lab.map(t=>t.characters)};
    let box=null; if(lab.length){ let p=lab[0].parent; while(p&&p!==F&&!(p.width>=280&&p.height>=200)) p=p.parent; box=p&&p!==F?p:null; }
    if(box){ const i=DPG.createInstance(); i.name='System/Date Picker · Graphical (替身)'; replaceAt(box,i,{keepW:true}); if(i.parent.layoutMode&&i.parent.layoutMode!=='NONE'&&i.layoutSizingHorizontal!=='FILL') i.layoutSizingHorizontal='FILL'; R.created.push(i.id); o.box='replaced '+Math.round(i.width)+'×'+Math.round(i.height); }
    else { for(const t of lab){ R.removed.push(t.id); t.remove(); } o.box='no box; labels removed'; }
    for(const t of texts(F).filter(t=>/^可选范围/.test(t.characters))){ if(!t.removed){ R.removed.push(t.id); t.remove(); } }
    await NOTE(F,'日期区：系统 DatePicker(.graphical)，不绘制日历（verify-r1 4.6 / CF-39）。可选范围：今天之后；结束时间的最小值 = 开始时间（in:）。替身 = System/Date Picker · 系统控件替身，与 C3 239:625 / 239:771 同一个。','datepicker');
    FIXED(F,'4.6','Date area is the System/Date Picker stand-in (one stand-in for C1 and C3); placeholder text moved out of the phone frame.'); out.push(o); }
  R.info['4.6']=out; }
// ---- 4.9 blue links → ink (249:16773 first, then the whole page; C1 was not swept) ----
{ const SKIP=/组件|component|素材|asset/i; let n=0; const ex=[];
  for(const s of PG.children.filter(s=>s.type==='SECTION'&&!SKIP.test(s.name))) for(const t of s.findAllWithCriteria({types:['TEXT']})){ if(insideInstance(t,s)) continue; const segs=t.getStyledTextSegments(['fills']); if(!segs.some(g=>g.fills.some(f=>f.type==='SOLID'&&isBlue(f.color)))) continue;
    if(/^(http|www)/.test(t.characters)) continue; await loadFontsOf(t);
    for(const g of segs) if(g.fills.some(f=>f.type==='SOLID'&&isBlue(f.color))) t.setRangeFills(g.start,g.end,[PAINT('ink')]);
    n++; if(ex.length<12) ex.push(t.characters.slice(0,16)); R.touched.push(t.id); }
  const F=await byId('249:16773'); FIXED(F,'4.9','Text links in ink (阅读剧情 ›, 修改 ›), not blue (F-09).'); R.info['4.9 links']={n,ex}; }
// ---- 4.9 238:20393 删除节点 ----
{ const F=await byId('238:20393'); const t=texts(F).find(t=>/删除节点/.test(t.characters)); const o={};
  if(t){ let vis=true, p=t; while(p&&p!==F){ if(p.visible===false) vis=false; p=p.parent; } o.found=t.characters; o.visible=vis; o.y=Math.round(absY(t)-absY(F)); o.frameH=Math.round(F.height);
    // inside a clipped scroll area below the fold? note where it is so nobody hunts for it
    if(o.y>F.height-40) o.belowFold=true; }
  else { const sheet=F.findAll(n=>n.type==='FRAME'&&/scroll|content|body|sheet/i.test(n.name)&&n.layoutMode==='VERTICAL').sort((a,b)=>b.height-a.height)[0]; o.found=false;
    if(sheet){ const row=AL('HORIZONTAL','删除节点 · quiet destructive row',{pad:[0,16,0,16],justify:'CENTER'}); sheet.appendChild(row); row.layoutSizingHorizontal='FILL'; row.counterAxisSizingMode='FIXED'; row.resize(row.width,52); row.layoutSizingHorizontal='FILL'; await TXT(row,'删除节点',{size:17,lh:22,color:'bad'}); o.added=row.id; } }
  FIXED(F,'4.9','删除节点 is the last row of the node sheet: quiet red text row, asks once (Editor/Confirm Dialog) (F-13).'); R.info['4.9 删除节点']=o; }
await census('C1');
return R;
