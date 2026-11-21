await goPage('6:3');
// clean the two half-made multi-mode variables from L1
await B('cleanvars',async()=>{ for(const id of ['VariableID:452:1398','VariableID:452:1517']){ const v=await figma.variables.getVariableByIdAsync(id); if(v&&/deed\/photo-empty|image-outline/.test(v.name)){ R.removed.push(v.name); v.remove(); } } });
// (b) no-photo cover, retry: tint is a child at 24 % node opacity (no new multi-mode variable)
await B('cover',async()=>{
  const set=await byId('381:993');
  for(const old of set.children.filter(c=>/Place=No photo/.test(c.name))) old.remove();
  let key=keyOf(set,'地名'); if(!key) key=set.addComponentProperty('地名','TEXT','转角花店');
  const bottom=Math.max(...set.children.map(c=>c.y+c.height));
  const mk=async(srcId,ratio,big)=>{ const src=await byId(srcId); const v=src.clone(); set.appendChild(v); v.name=`Ratio=${ratio}, Place=No photo`; for(const c of [...v.children]) c.remove();
    v.layoutMode='VERTICAL'; v.primaryAxisAlignItems='CENTER'; v.counterAxisAlignItems='CENTER'; v.itemSpacing=big?6:4; v.primaryAxisSizingMode='FIXED'; v.counterAxisSizingMode='FIXED'; v.clipsContent=true; v.fills=[PAINT('surface-2')];
    const tint=figma.createRectangle(); v.appendChild(tint); tint.layoutPositioning='ABSOLUTE'; tint.x=0; tint.y=0; tint.resize(v.width,v.height); tint.constraints={horizontal:'STRETCH',vertical:'STRETCH'}; tint.name='district tint 24%'; tint.fills=[PAINT('deed/band')]; tint.opacity=0.24; R.created.push(tint.id);
    const disc=AL('HORIZONTAL','camera',{fill:'sep',r:999,w:big?36:28,h:big?36:28,justify:'CENTER'}); v.appendChild(disc); await IC(disc,'camera',big?18:14,'ink-2');
    const t=await TX(v,'转角花店',big?'t-2':'t-head','ink',{name:'place name'}); t.componentPropertyReferences={characters:key};
    if(big) await TX(v,'拍下第一张照片','t-cap','ink-2',{name:'invite'});
    v.x=src.x; v.y=bottom+24; R.created.push(v.id); return v; };
  const a=await mk('381:987','16:9',true); const b=await mk('381:990','1:1',false); b.x=a.x+a.width+24;
  set.resizeWithoutConstraints(Math.max(set.width,b.x+b.width+32),Math.max(set.height,a.y+Math.max(a.height,b.height)+32));
  set.description=(set.description||'').replace(/\n?No photo:.*$/s,'')+'\nNo photo: surface-2 with the district colour (deed/band) at 24 %, a camera disc and the place name (地名) — the real state for a place nobody has photographed yet, inviting the first claim photo. The glyph-on-grey Default is only for Unlit. No AI-generated or people photos (owner, xrefs-1 B.0).';
  R.info.cover=[a.id,b.id];
});
// (j) club card outline with an alpha token
await B('club',async()=>{ const card=await byId('421:1586'); const th=card.findOne(n=>n.name==='thumb'); th.strokes=[PAINT('sep-strong')]; th.strokeWeight=1; th.strokeAlign='INSIDE'; R.info.thumbMain=th.mainComponent&&th.mainComponent.name; });
// shared placement under the Stat Tile set
const stat=await byId('427:1552'); const host=stat.parent;
let py=Math.max(...host.children.map(c=>c.y+c.height))+120; const px=stat.x;
const place=n=>{ host.appendChild(n); n.x=px; n.y=py; py+=n.height+80; if(host.type==='SECTION') host.resizeWithoutConstraints(Math.max(host.width,n.x+n.width+80),Math.max(host.height,n.y+n.height+80)); };
// (e) Stat Tile Plain
await B('statPlain',async()=>{ for(const o of stat.children.filter(c=>/Emphasis=Plain/.test(c.name))) o.remove(); const d=stat.children.find(c=>/Emphasis=Default/.test(c.name)); const v=d.clone(); stat.appendChild(v); v.name='Emphasis=Plain'; const val=v.findOne(n=>n.name==='value'); const cap=v.findOne(n=>n.name==='caption'); await loadFontsOf(val); await val.setTextStyleIdAsync(TS['role/stat'].id); await loadFontsOf(cap); await cap.setTextStyleIdAsync(TS['t-cap2'].id); cap.fills=[PAINT('ink-3')]; v.fills=[]; v.strokes=[]; v.x=Math.max(...stat.children.filter(c=>c!==v).map(c=>c.x+c.width))+24; v.y=d.y; stat.resizeWithoutConstraints(v.x+v.width+32,stat.height);
  stat.description=(stat.description||'').replace(/\n?Plain \(xrefs-1.*$/s,'')+'\nPlain (xrefs-1 Adopt 4): no tile — three Plain stats in an HStack with two 1 pt sep dividers 28 high; number role/stat 22 bold tabular, caption t-cap2 ink-3. Rolls with numericText only when the value really changes, never on every visit.'; R.info.plain=v.id; });
// (f) Streak Day + Streak Row
await B('streak',async()=>{
  for(const o of host.children.filter(c=>/^Player\/Streak (Day|Row)$/.test(c.name))) o.remove();
  const mkDay=async(state)=>{ const c=figma.createComponent(); c.layoutMode='VERTICAL'; c.itemSpacing=4; c.counterAxisAlignItems='CENTER'; c.primaryAxisSizingMode='AUTO'; c.counterAxisSizingMode='FIXED'; c.resize(32,40); c.fills=[]; c.name='State='+state;
    const lit=/Lit/.test(state), today=/Today/.test(state);
    const dot=AL('HORIZONTAL','dot',{r:999,w:24,h:24,justify:'CENTER',fill:lit?'ink':null}); c.appendChild(dot); if(!lit){ dot.strokes=[PAINT(today?'ink':'ink-3')]; dot.strokeWeight=1.5; dot.strokeAlign='INSIDE'; } else await IC(dot,'check',14,'ink-inv');
    const t=await TX(c,'四',today?'role/tag':'t-cap2',today?'ink':'ink-3',{name:'day'}); R.created.push(c.id); return c; };
  const days=[]; for(const s of ['Unlit','Lit','Today','Today lit']) days.push(await mkDay(s));
  const set=figma.combineAsVariants(days,host); set.name='Player/Streak Day'; set.layoutMode='HORIZONTAL'; set.itemSpacing=24; set.paddingTop=set.paddingBottom=set.paddingLeft=set.paddingRight=24; set.primaryAxisSizingMode='AUTO'; set.counterAxisSizingMode='AUTO'; set.fills=[PAINT('bg')]; set.cornerRadius=16;
  const key=set.addComponentProperty('Day','TEXT','四'); for(const v of set.children){ const t=v.findOne(n=>n.name==='day'); t.componentPropertyReferences={characters:key}; }
  set.description='Streak day (xrefs-1 Adopt 6). Lit = ink disc + check; Unlit = ink-3 ring; Today = ink ring and a bold day letter. Neutral colours only (no orange, no purple). When today lights: the disc fills with spring/seal and .symbolEffect(.bounce, value: litToday) once, .sensoryFeedback(.impact(weight: .light)). Never animates on a plain visit. Reduce Motion: fill cross-fades 200 ms, haptic stays.';
  place(set);
  const row=figma.createComponent(); row.name='Player/Streak Row'; row.layoutMode='HORIZONTAL'; row.primaryAxisAlignItems='SPACE_BETWEEN'; row.counterAxisAlignItems='CENTER'; row.primaryAxisSizingMode='FIXED'; row.counterAxisSizingMode='AUTO'; row.resize(361,40); row.fills=[];
  const spec=[['一','Unlit'],['二','Lit'],['三','Lit'],['四','Today lit'],['五','Unlit'],['六','Unlit'],['日','Unlit']];
  for(const [d,s] of spec){ const v=set.children.find(c=>c.name==='State='+s); const i=v.createInstance(); row.appendChild(i); setProps(i,{Day:d}); }
  row.description='连续探索 row for 我的 (and the 漫游 header): seven days, Monday first, three lit ending today. Row never staggers; only today\'s disc animates when it lights (xrefs-1 Adopt 6).';
  place(row); R.info.streak=[set.id,row.id];
});
// (g) Balance Tile Masked / Revealed
await B('balance',async()=>{
  for(const o of host.children.filter(c=>c.name==='Player/Balance Tile')) o.remove();
  const eye='<svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M2 12C4.5 7.5 8 5 12 5C16 5 19.5 7.5 22 12C19.5 16.5 16 19 12 19C8 19 4.5 16.5 2 12Z" stroke="#FFFFFF" stroke-width="1.8" stroke-linejoin="round"/><circle cx="12" cy="12" r="3.2" stroke="#FFFFFF" stroke-width="1.8"/></svg>';
  const slash='<svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M2 12C4.5 7.5 8 5 12 5C16 5 19.5 7.5 22 12C19.5 16.5 16 19 12 19C8 19 4.5 16.5 2 12Z" stroke="#FFFFFF" stroke-width="1.8" stroke-linejoin="round"/><circle cx="12" cy="12" r="3.2" stroke="#FFFFFF" stroke-width="1.8"/><path d="M4 4L20 20" stroke="#FFFFFF" stroke-width="1.8" stroke-linecap="round"/></svg>';
  const mk=async(state)=>{ const c=figma.createComponent(); c.name='State='+state; c.layoutMode='HORIZONTAL'; c.counterAxisAlignItems='CENTER'; c.itemSpacing=12; c.paddingTop=c.paddingBottom=16; c.paddingLeft=20; c.paddingRight=12; c.primaryAxisSizingMode='FIXED'; c.counterAxisSizingMode='AUTO'; c.resize(361,80); c.cornerRadius=24;
    c.fills=state==='Revealed'?[PAINT('surface-2'),{type:'GRADIENT_RADIAL',gradientTransform:[[0.9,0,-0.36],[0,2.2,-0.25]],gradientStops:[{position:0,color:{r:1,g:1,b:1,a:0.10}},{position:1,color:{r:1,g:1,b:1,a:0}}]}]:[PAINT('surface-2')];
    const col=AL('VERTICAL','text',{gap:2,align:'MIN'}); c.appendChild(col); col.layoutGrow=1; await TX(col,'积分余额','t-foot','ink-2',{name:'caption'}); await TX(col,state==='Revealed'?'1,286':'••••••','t-large','ink',{name:'value'});
    const btn=AL('HORIZONTAL','eye button · 44',{fill:'sep',r:999,w:44,h:44,justify:'CENTER'}); c.appendChild(btn); const ic=figma.createNodeFromSvg(state==='Revealed'?slash:eye); ic.name=state==='Revealed'?'eye.slash':'eye'; btn.appendChild(ic); for(const n of ic.findAll(n=>'strokes' in n&&n.strokes.length)) n.strokes=[PAINT('ink-2')];
    R.created.push(c.id); return c; };
  const set=figma.combineAsVariants([await mk('Masked'),await mk('Revealed')],host); set.name='Player/Balance Tile'; set.layoutMode='VERTICAL'; set.itemSpacing=24; set.paddingTop=set.paddingBottom=set.paddingLeft=set.paddingRight=24; set.primaryAxisSizingMode='AUTO'; set.counterAxisSizingMode='AUTO'; set.fills=[PAINT('bg')]; set.cornerRadius=16;
  set.description='Hidden balance (xrefs-1 Adopt 5; only if the owner wants a hide toggle on 我的). Origin: the eye button. Reveal: the eye cross-blurs to eye.slash (.contentTransition(.symbolEffect(.replace)), 200 ms); a white 8–10 % radial light grows from the button anchor with spring(response: 0.4, dampingFraction: 0.85); digits roll in with numericText, stagger/digit 45 ms from the button side, landing inside 250 ms. Hide: 200 ms (shorter than the reveal), digits drop to dots, light drains to the button. Still: caption, card shape (no warp), page. No purple, no colour flood. Interruptible: a second tap reverses from the current state, no queue. Haptic: .selection on the tap only. Reduce Motion: value and icon cross-fade 200 ms, no light.';
  place(set); R.info.balance=set.id;
});
// (k) Player/Sheet partial detent = material
await B('sheet',async()=>{ const set=await byId('287:462'); for(const o of set.children.filter(c=>/Detent=Partial/.test(c.name))) o.remove(); const m=set.children.find(c=>/Detent=Medium/.test(c.name)); const v=m.clone(); set.appendChild(v); v.name='Detent=Partial'; v.fills=[RAW('1C1C1E',0.72)]; v.effects=[{type:'BACKGROUND_BLUR',radius:24,visible:true}]; v.x=Math.max(...set.children.filter(c=>c!==v).map(c=>c.x+c.width))+24; v.y=m.y; set.resizeWithoutConstraints(Math.max(set.width,v.x+v.width+32),set.height);
  set.description=(set.description||'').replace(/\n?Partial \(xrefs-1.*$/s,'')+'\nPartial (xrefs-1 Adopt 11 / B.1): over a live map at a partial detent (property sheet 420 pt, 附近 sheet) the sheet is the system material — iOS 26 default Liquid Glass, earlier .presentationBackground(.regularMaterial) — and turns opaque at .large. Fills inside are plain (no second material, no outline on the deed). The 72 % fill + 24 blur here only stands in for the system material. Reduce Transparency: the system makes it opaque.'; R.info.sheet=v.id; });
return R;
