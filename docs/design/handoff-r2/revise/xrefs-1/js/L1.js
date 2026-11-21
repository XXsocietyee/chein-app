// L1 · Library 6:3 · B.0 motion tokens, no-photo cover, button Done, toast states, deed hug + row meta, moment kicker, club card outline, tabular notes
await goPage('6:3');
const B=async(name,fn)=>{ try{ await fn(); R.info[name]=R.info[name]||'ok'; }catch(e){ R.warn.push(name+': '+String(e).slice(0,180)); } };
const sp=(r,z)=>[Math.round(Math.pow(2*Math.PI/r,2)*10)/10, Math.round(4*Math.PI*z/r*100)/100];
// (a) one motion token set
await B('motion',async()=>{
  const col=COLS['VariableCollectionId:381:959']; const mode=col.modes[0].modeId;
  const byName={}; for(const id of col.variableIds){ const v=VI[id]||await figma.variables.getVariableByIdAsync(id); byName[v.name]=v; }
  const ren=(a,b)=>{ if(byName[a]){ byName[a].name=b; byName[b]=byName[a]; delete byName[a]; } };
  // order matters: moment→seal before result→moment
  ren('spring/moment-response','spring/seal-response'); ren('spring/moment-damping','spring/seal-damping');
  ren('spring/result-response','spring/moment-response'); ren('spring/result-damping','spring/moment-damping');
  ren('spring/push-response','spring/hero-response'); ren('spring/push-damping','spring/hero-damping');
  ren('figma/moment-stiffness','figma/seal-stiffness'); ren('figma/moment-damping','figma/seal-damping');
  ren('figma/result-stiffness','figma/moment-stiffness'); ren('figma/result-damping','figma/moment-damping');
  ren('figma/push-stiffness','figma/hero-stiffness'); ren('figma/push-damping','figma/hero-damping');
  ren('duration/press','duration/instant'); ren('duration/sheet','duration/standard'); ren('duration/moment','duration/slow');
  ren('duration/stagger','stagger/chip-2');
  const SPR={press:[0.12,0.90,'CYMotion.press','Touch-down: scale 1 → scale/press. Every pressable control.'],
    release:[0.25,0.70,'CYMotion.release','Touch-up, pin select, chip select. CityTokens.pressSpring is now an alias of this.'],
    standard:[0.30,0.85,'CYMotion.standard','Content changes in place: insert, delete, reorder, button fill, wizard step.'],
    entrance:[0.35,0.80,'CYMotion.entrance','One entrance per container: empty state, seat arrival, toast enter.'],
    sheet:[0.38,0.86,'CYMotion.sheet','Sheets and toasts (was CityTokens.sheetSpring).'],
    moment:[0.42,0.80,'CYMotion.moment','Result beats inside a moment: deed band, text, chips (was CityTokens.deedSpring / result).'],
    seal:[0.40,0.55,'CYMotion.seal','The one playful spring: seal, medal, die landing (was CityTokens.sealSpring).'],
    hero:[0.45,0.86,'CYMotion.hero','Continuity: claim photo → deed, Mini → sheet, die across stages (was CityTokens.heroSpring / push).']};
  const ensure=(name,val,desc)=>{ let v=byName[name]; if(!v){ v=figma.variables.createVariable(name,col,'FLOAT'); v.scopes=[]; byName[name]=v; R.created.push(v.id); } v.setValueForMode(mode,val); if(desc!=null) v.description=desc; return v; };
  for(const [k,[r,z,sw,use]] of Object.entries(SPR)){ const [kk,cc]=sp(r,z);
    ensure(`spring/${k}-response`,r,`${sw} = spring(response: ${r.toFixed(2)}, dampingFraction: ${z.toFixed(2)}) · ${use} · single source (xrefs-1 B.0)`);
    ensure(`spring/${k}-damping`,z,`${sw} damping fraction (xrefs-1 B.0)`);
    ensure(`figma/${k}-stiffness`,kk,`Figma prototype spring for ${sw}: mass 1, stiffness ${kk}, damping ${cc}`);
    ensure(`figma/${k}-damping`,cc,`Figma prototype spring for ${sw}`); }
  const DUR=[['duration/instant',120,'CYMotion.Duration.instant · press-down, chip tick, toggle'],['duration/quick',200,'CYMotion.Duration.quick · fades, cross-fades, blurReplace, tab symbol swap'],['duration/standard',350,'CYMotion.Duration.standard · list insert/delete, ring fill'],['duration/slow',600,'CYMotion.Duration.slow · celebration land, count-up of rent'],['duration/push',400,'Figma prototype push only (hero spring settles ≈ 400 ms); code uses spring/hero'],
    ['duration/numeric-roll',300,'.contentTransition(.numericText(value:)) under withAnimation(.snappy(duration: 0.3)) · 积分, totals, stats; only on a real change'],['duration/hide',200,'Exits and hides: always shorter than the entrance (reveal 250 → hide 200)'],['duration/reduce-motion-fade',200,'CYMotion.reduced = easeInOut(duration: 0.2) · every row\'s Reduce Motion fallback'],['duration/success-wave',450,'CYWave single pass, amplitude 6 pt, white 12 % · rare tier only (N22, N38)'],['duration/hold',800,'Hold ring: linear(duration: 0.8); release snaps back with spring/release'],['duration/count-up',800,'Rent arrives: 0 → total in three steps']];
  for(const [n,v,d] of DUR) ensure(n,v,d+' · ms (xrefs-1 B.0)');
  const DEL=[['delay/hero-band',250,'Deed band starts 250 ms after the photo starts moving (not after it lands)'],['delay/success-wave',780,'Wave starts at the seal contact (≈ 780 ms)'],['delay/sheet-dismiss',600,'In-place Done holds 600 ms, then the sheet dismisses'],['delay/moment-deed',350,null],['delay/moment-seal',600,null],['delay/moment-text',950,null],['delay/moment-actions',1250,null],['delay/toast-action',300,'Toast trailing action (查看) enters 300 ms after the state change'],['delay/total-roll',400,'Dice total rolls 400 ms after the die lands']];
  for(const [n,v,d] of DEL) ensure(n,v,d==null?null:d+' · ms (xrefs-1)');
  const ST=[['stagger/chip-2',50,'Moment chips: delays 0 / 50 / 90 ms (non-uniform; replaces 60 × index)'],['stagger/chip-3',90,'Moment chips: third chip'],['stagger/digit',45,'Per-digit roll, from the cause side; whole number lands inside 300 ms'],['stagger/ai-2',40,'AI rewrite fields: 0 / 40 / 70 / 90 ms from the top'],['stagger/ai-3',70,null],['stagger/ai-4',90,null]];
  for(const [n,v,d] of ST) ensure(n,v,d==null?'see stagger/ai-2':d+' · ms (xrefs-1)');
  ensure('scale/press',0.97,'Press dip 0.97 (CYMotion.press). Never below 0.95.'); ensure('scale/pin-selected',1.15,'Pin select 1 → 1.15 with spring/release; nothing else moves');
  R.info.motionVars=Object.keys(byName).length;
});
// (b) no-photo cover
await B('cover',async()=>{
  const set=await byId('381:993'); const dcol=Object.values(COLS).find(c=>c.name==='District');
  let pe=Object.values(VI).find(v=>v.name==='deed/photo-empty');
  const band=Object.values(VI).find(v=>v.name==='deed/band'&&v.variableCollectionId===dcol.id);
  if(!pe){ pe=figma.variables.createVariable('deed/photo-empty',dcol,'COLOR'); pe.scopes=['FRAME_FILL','SHAPE_FILL']; R.created.push(pe.id);
    for(const m of dcol.modes){ let c=band.valuesByMode[m.modeId]; let g=0; while(c&&c.type==='VARIABLE_ALIAS'&&g++<5){ const a=VI[c.id]; c=a.valuesByMode[COLS[a.variableCollectionId].modes[0].modeId]; } pe.setValueForMode(m.modeId,{r:c.r,g:c.g,b:c.b,a:0.24}); } }
  pe.description='District colour at 24 % over surface-2 · the "no photo yet" deed cover (xrefs-1 B.0)';
  for(const old of set.children.filter(c=>/Place=No photo/.test(c.name))) old.remove();
  let key=keyOf(set,'地名'); if(!key) key=set.addComponentProperty('地名','TEXT','转角花店');
  const mk=async(srcId,ratio,big)=>{ const src=await byId(srcId); const v=src.clone(); set.appendChild(v); v.name=`Ratio=${ratio}, Place=No photo`; for(const c of [...v.children]) c.remove();
    v.layoutMode='VERTICAL'; v.primaryAxisAlignItems='CENTER'; v.counterAxisAlignItems='CENTER'; v.itemSpacing=big?6:4; v.primaryAxisSizingMode='FIXED'; v.counterAxisSizingMode='FIXED'; v.clipsContent=true;
    v.fills=[PAINT('surface-2'),figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:1,g:1,b:1}},'color',pe)];
    const disc=AL('HORIZONTAL','camera',{fill:'sep',r:999,w:big?36:28,h:big?36:28,justify:'CENTER'}); v.appendChild(disc); await IC(disc,'camera',big?18:14,'ink-2');
    const t=await TX(v,'转角花店',big?'t-2':'t-head','ink',{name:'place name'}); t.componentPropertyReferences={characters:key};
    if(big) await TX(v,'拍下第一张照片','t-cap','ink-2',{name:'invite'});
    v.x=src.x; v.y=Math.max(...set.children.filter(c=>c!==v).map(c=>c.y+c.height))+24+(big?0:0); R.created.push(v.id); return v; };
  const a=await mk('381:987','16:9',true); const b=await mk('381:990','1:1',false); b.x=a.x+a.width+24; b.y=a.y;
  set.resizeWithoutConstraints(Math.max(set.width,b.x+b.width+32),Math.max(set.height,a.y+Math.max(a.height,b.height)+32));
  set.description=(set.description||'').replace(/\n?No photo:.*$/s,'')+'\nNo photo: district colour 24 % (deed/photo-empty) over surface-2, a camera disc and the place name (地名). The real state for a place nobody has photographed yet; the glyph-on-grey Default is only for Unlit. Owner: no AI-generated or people photos (xrefs-1 B.0).';
  R.info.cover=[a.id,b.id];
});
// (c) Player/Button Done
await B('button',async()=>{
  const set=await byId('285:20238'); const check=await byId('9:39');
  for(const old of set.children.filter(c=>/State=Done/.test(c.name))) old.remove();
  const right=Math.max(...set.children.map(c=>c.x+c.width)); let made=[];
  for(const ld of set.children.filter(c=>/State=Loading/.test(c.name))){ const v=ld.clone(); set.appendChild(v); v.name=ld.name.replace('State=Loading','State=Done');
    const sp=v.findOne(n=>n.name==='spinner'); const lab=v.findOne(n=>n.type==='TEXT'); const i=check.createInstance(); i.resize(18,18); i.name='done check'; const g=i.findOne(n=>n.type==='TEXT'); if(g&&lab){ g.fontSize=14; g.fills=JSON.parse(JSON.stringify(lab.fills)); } if(!g&&lab){ for(const n of i.findAll(n=>'fills' in n&&Array.isArray(n.fills)&&n.fills.length)) n.fills=JSON.parse(JSON.stringify(lab.fills)); }
    if(sp){ v.insertChild(v.children.indexOf(sp),i); sp.remove(); } else v.insertChild(0,i);
    v.x=right+24; v.y=ld.y; made.push(v.id); }
  set.resizeWithoutConstraints(Math.max(...set.children.map(c=>c.x+c.width))+32,set.height);
  set.description=(set.description||'').replace(/\n?In place \(xrefs-1\):.*$/s,'')+'\nIn place (xrefs-1): one capsule carries the whole verb. Default → Pressed (scale/press 0.97, spring/press) → Loading (spinner + 正在… in the same capsule, label never leaves) → Done (check + 已… , success haptic) → sheet dismisses after delay/sheet-dismiss 600 ms. Width animates with spring/standard; label swaps with .contentTransition(.opacity) 200 ms; the check enters scale 0.25 → 1, opacity 0 → 1, blur 4 → 0 (300 ms, bounce 0). Interruptible: a second tap while Loading is ignored, cancel returns to Default with spring/release. Reduce Motion: label and icon cross-fade 200 ms, no width change. SwiftUI: CYMorphButton.';
  R.info.done=made;
});
// (d) toast states
await B('toast',async()=>{
  const set=await byId('285:20279'); const info=set.children.find(c=>/Type=Info/.test(c.name));
  for(const old of set.children.filter(c=>/Type=(Progress|Done)/.test(c.name))) old.remove();
  const bottom=Math.max(...set.children.map(c=>c.y+c.height));
  const p=info.clone(); set.appendChild(p); p.name='Type=Progress'; const pi=p.findOne(n=>n.name==='icon/info'); const sp=figma.createEllipse(); sp.resize(16,16); sp.name='spinner'; sp.fills=[]; sp.strokes=[PAINT('ink-2')]; sp.strokeWeight=2; sp.arcData={startingAngle:0,endingAngle:4.7,innerRadius:0.8}; sp.fills=[PAINT('ink-2')]; sp.strokes=[]; p.insertChild(p.children.indexOf(pi),sp); pi.remove(); await setT(p.findOne(n=>n.type==='TEXT'),'正在报名…'); p.x=info.x; p.y=bottom+24;
  const d=info.clone(); set.appendChild(d); d.name='Type=Done'; const di=d.findOne(n=>n.name==='icon/info'); di.swapComponent(await byId('9:41')); di.name='icon/check-c'; await setT(d.findOne(n=>n.type==='TEXT'),'报名成功'); const act=await TX(d,'查看','role/button-sm','ink',{name:'action 查看'}); d.itemSpacing=8; d.paddingRight=Math.max(d.paddingRight,6); d.x=p.x+p.width+24; d.y=p.y;
  set.resizeWithoutConstraints(Math.max(set.width,d.x+d.width+32),Math.max(set.height,d.y+d.height+32));
  set.description=(set.description||'').replace(/\n?State change \(xrefs-1.*$/s,'')+'\nState change (xrefs-1 Adopt 8): the toast never leaves to show its result. Progress → Done: the leading icon swaps in place (.contentTransition(.symbolEffect(.replace))), the title cross-fades (.contentTransition(.opacity), 200 ms), the trailing 查看 enters last after delay/toast-action 300 ms with .transition(.blurReplace). Origin: the icon. Enter and exit from the same edge with spring/sheet (0.38 / 0.86); exit 200 ms. Still: the capsule width only grows once, with spring/standard. Interruptible: a new toast retargets the same capsule. Reduce Motion: cross-fade 200 ms. Haptic: .success on Done only.';
  R.info.toast=[p.id,d.id];
});
// (h) deed: Full hugs, Row meta yields
await B('deed',async()=>{
  const set=await byId('381:1401'); let hid=0, rows=0;
  for(const v of set.children){ if(/Size=Full/.test(v.name)){ const sp=v.findOne(n=>n.name==='spacer'&&n.parent&&n.parent.name==='body'); if(sp&&sp.visible){ sp.visible=false; hid++; } }
    if(/Size=Row/.test(v.name)){ const sub=v.findOne(n=>n.name==='sub'); if(sub){ const d=sub.findOne(n=>n.type==='TEXT'&&n.name==='district'); const l=sub.findOne(n=>n.type==='TEXT'&&n.name==='level'); if(d){ await loadFontsOf(d); d.layoutGrow=1; d.textTruncation='ENDING'; d.maxLines=1; d.layoutSizingHorizontal='FILL'; } if(l){ await loadFontsOf(l); l.layoutSizingHorizontal='HUG'; l.layoutGrow=0; } rows++; } } }
  R.info.deed={fullSpacersHidden:hid,rowMeta:rows};
});
// (i) moment kicker
await B('moment',async()=>{
  const set=await byId('427:1433'); let kb=keyOf(set,'Show kicker'), kt=keyOf(set,'Kicker');
  if(!kt) kt=set.addComponentProperty('Kicker','TEXT','14 + 3'); if(!kb) kb=set.addComponentProperty('Show kicker','BOOLEAN',false);
  for(const v of set.children){ const c=v.findOne(n=>n.name==='content'); const h=c&&c.findOne(n=>n.name==='headline'); if(!c||!h||c.findOne(n=>n.name==='kicker')) continue; const k=await TX(null,'14 + 3','t-sub','ink-2',{name:'kicker'}); c.insertChild(c.children.indexOf(h),k); k.layoutSizingHorizontal='FILL'; k.textAlignHorizontal=h.textAlignHorizontal; k.componentPropertyReferences={characters:kt,visible:kb}; }
  set.description=(set.description||'').replace(/\n?Kicker \(xrefs-1.*$/s,'')+'\nKicker (xrefs-1 B.1): when the result is a number (dice total), show the maths as the kicker (14 + 3) and the total as the headline in t-hero 48 tabular; the number wins the page.';
});
// (j) club card outline + one-line name
await B('club',async()=>{
  const col=COLS['VariableCollectionId:7:2']; let io=Object.values(VI).find(v=>v.name==='image-outline');
  if(!io){ io=figma.variables.createVariable('image-outline',col,'COLOR'); io.scopes=['STROKE_COLOR']; R.created.push(io.id); }
  for(const m of col.modes){ const dark=/Dark|^Game$/.test(m.name); io.setValueForMode(m.modeId,dark?{r:1,g:1,b:1,a:0.10}:{r:0,g:0,b:0,a:0.10}); }
  io.description='1 pt inner outline on photos: white 10 % on dark, black 10 % on light (xrefs-1 B.2; make-interfaces-feel-better #11)';
  const card=await byId('421:1586'); const th=card.findOne(n=>n.name==='thumb'); th.strokes=[figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:1,g:1,b:1}},'color',io)]; th.strokeWeight=1; th.strokeAlign='INSIDE';
  try{ th.swapComponent(await byId('382:1060')); }catch(e){ R.warn.push('thumb swap '+e); }
  const nm=card.findOne(n=>n.name==='name'); await loadFontsOf(nm); nm.textTruncation='ENDING'; nm.maxLines=1;
  card.description=(card.description||'').replace(/\n?xrefs-1:.*$/s,'')+'\nxrefs-1: thumbnail carries a 1 pt image-outline so dark photos keep an edge; the name is one line with tail truncation (梧桐摄影漫步社 no longer orphans two characters). Default thumb is a people-free poster.';
});
// (l) tabular figures note on numeric styles
await B('styles',async()=>{ let n=0; for(const nm of ['t-hero','t-large','t-1','t-2','t-3','role/stat']){ const s=TS[nm]; if(!s) continue; s.description=(s.description||'').replace(/\n?Numbers: tabular.*$/s,'')+'\nNumbers: tabular figures (.monospacedDigit()); a value that changes rolls with .contentTransition(.numericText(value:)) in duration/numeric-roll 300 ms (xrefs-1 B.0).'; n++; } R.info.styles=n; });
return R;
