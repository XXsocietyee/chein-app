// args: PAGEID, OLD (array of old set/component ids), SCOPE (optional section id), LIMIT
const page=await figma.getNodeByIdAsync(PAGEID); await figma.setCurrentPageAsync(page);
const N=id=>figma.getNodeByIdAsync(id);
const K={field:await N('276:638'),popup:await N('276:739'),sw:await N('276:302'),handle:await N('276:307'),swrow:await N('278:311'),li:await N('278:458'),add:await N('278:467'),sh:await N('280:410'),toast:await N('280:479'),bb:await N('280:593')};
const keyOf=(owner,base)=>Object.keys(owner.componentPropertyDefinitions).find(k=>k.split('#')[0]===base);
const variant=(set,props)=>set.children.find(v=>Object.entries(props).every(([k,val])=>v.name.split(', ').includes(`${k}=${val}`)));
const old=(i,base)=>{ const p=i.componentProperties; const k=Object.keys(p).find(k=>k.split('#')[0]===base); return k?p[k].value:undefined; };
function surface(n){ let p=n.parent; while(p&&p.type!=='PAGE'&&p.type!=='SECTION'){ if('fills' in p && Array.isArray(p.fills)){ const f=p.fills.find(f=>f.visible!==false&&f.type==='SOLID'&&(f.opacity??1)>0.5); if(f){ const c=f.color; return (c.r>0.985&&c.g>0.985&&c.b>0.985)?'OnCard':'OnGrey'; } } p=p.parent; } return 'OnGrey'; }
const fontsLoaded=new Set(); async function loadFonts(n){ for(const t of n.findAll(x=>x.type==='TEXT')){ for(const s of t.getStyledTextSegments(['fontName'])){ const k=s.fontName.family+'|'+s.fontName.style; if(!fontsLoaded.has(k)){ await figma.loadFontAsync(s.fontName); fontsLoaded.add(k);} } } }
async function doSwap(i,target,props,opts={}){
  const par=i.parent; const al=par.layoutMode&&par.layoutMode!=='NONE'&&i.layoutPositioning!=='ABSOLUTE';
  const sz={h:i.layoutSizingHorizontal,v:i.layoutSizingVertical,w:i.width,x:i.x,y:i.y,ht:i.height};
  i.swapComponent(target); await loadFonts(i);
  if(props&&Object.keys(props).length) i.setProperties(props);
  i.name=target.parent&&target.parent.type==='COMPONENT_SET'?target.parent.name:target.name;
  if(opts.keepW!==false){ if(al){ if(sz.h==='FILL') i.layoutSizingHorizontal='FILL'; else if(opts.fixedW!==false){ i.resize(sz.w,i.height); i.layoutSizingHorizontal='FIXED'; } }
    else { if(opts.fixedW!==false) i.resize(sz.w,i.height); } }
  if(!al && opts.anchorRight){ i.x=sz.x+sz.w-i.width; i.y=sz.y+(sz.ht-i.height)/2; }
  else if(!al && opts.center){ i.x=sz.x+(sz.w-i.width)/2; i.y=sz.y+(sz.ht-i.height)/2; }
}
const FD=K.field, PD=K.popup;
const P=(set,base)=>keyOf(set,base);
const map={
 '236:15775': async i=>{ const st=old(i,'State'), kind=old(i,'Kind'); const t=variant(FD,{Kind:kind==='Area'?'Area':'Line',State:st==='Placeholder'?'Empty':st,Surface:surface(i)}); await doSwap(i,t,{[P(FD,'showLabel')]:false,[P(FD,'value')]:String(old(i,'text'))}); },
 '236:15792': async i=>{ const st=old(i,'State'); const t=variant(PD,{State:st==='Placeholder'?'Empty':st,Surface:surface(i)}); await doSwap(i,t,{[P(PD,'showLabel')]:false,[P(PD,'value')]:String(old(i,'text'))}); },
 '236:14530': async i=>{ const st=old(i,'State'), kind=old(i,'Kind'); const s2=st==='Placeholder'?'Empty':st; const err=st==='Error'&&old(i,'showError')!==false;
   if(kind==='Dropdown'){ const t=variant(PD,{State:s2,Surface:surface(i)}); await doSwap(i,t,{[P(PD,'label')]:String(old(i,'label')),[P(PD,'showLabel')]:old(i,'showLabel')!==false,[P(PD,'value')]:String(old(i,'value')),[P(PD,'help')]:String(old(i,'error')),[P(PD,'showHelp')]:err}); }
   else { const t=variant(FD,{Kind:'Line',State:s2,Surface:surface(i)}); const suf=String(old(i,'suffix')||''); await doSwap(i,t,{[P(FD,'label')]:String(old(i,'label')),[P(FD,'showLabel')]:old(i,'showLabel')!==false,[P(FD,'value')]:String(old(i,'value')),[P(FD,'suffix')]:suf||'分',[P(FD,'showSuffix')]:!!old(i,'showSuffix')&&suf.length>0,[P(FD,'help')]:String(old(i,'error')),[P(FD,'showHelp')]:err}); } },
 '236:14552': async i=>{ const st=old(i,'State'); const s2=st==='Placeholder'?'Empty':st; const t=variant(FD,{Kind:'Area',State:s2,Surface:surface(i)}); await doSwap(i,t,{[P(FD,'label')]:String(old(i,'label')),[P(FD,'showLabel')]:old(i,'showHead')!==false,[P(FD,'counter')]:String(old(i,'counter')),[P(FD,'showCounter')]:!!old(i,'showCounter'),[P(FD,'value')]:String(old(i,'value')),[P(FD,'help')]:String(old(i,'error')),[P(FD,'showHelp')]:st==='Error'}); },
 '236:14487': async i=>{ const on=String(old(i,'On'))==='true'; await doSwap(i,variant(K.sw,{State:on?'On':'Off'}),{}, {fixedW:false,anchorRight:true}); },
 '236:15797': async i=>{ const on=old(i,'State')==='On'; await doSwap(i,variant(K.sw,{State:on?'On':'Off'}),{}, {fixedW:false,anchorRight:true}); },
 '236:15798': async i=>{ await doSwap(i,K.handle,{}, {fixedW:false,center:true}); },
 '236:14553': async i=>{ const nested=i.findOne(n=>n.type==='INSTANCE'&&n.name==='switch'); let on=false; if(nested){ const mc=await nested.getMainComponentAsync(); on=!!mc&&/On=true|State=On/.test(mc.name); }
   const SR=K.swrow; await doSwap(i,SR,{[P(SR,'label')]:String(old(i,'label')),[P(SR,'sub')]:String(old(i,'sub')),[P(SR,'showSub')]:!!old(i,'showSub')});
   const sw=i.findOne(n=>n.type==='INSTANCE'&&n.name==='switch'); if(sw) sw.setProperties({State:on?'On':'Off'}); },
 '236:14559': async i=>{ const SH=K.sh; const t=variant(SH,{Leading:old(i,'showClose')===false?'None':'Close',Trailing:old(i,'showDone')===false?'None':'Done'}); const cap=String(old(i,'caption')||''); await doSwap(i,t,{[P(SH,'title')]:String(old(i,'title')),[P(SH,'eyebrow')]:cap||' ',[P(SH,'showEyebrow')]:!!old(i,'showCaption')&&cap.length>0,[P(SH,'done')]:String(old(i,'done')||'完成')}); },
 '236:15806': async i=>{ const SH=K.sh; const t=variant(SH,{Leading:'Close',Trailing:old(i,'showDone')===false?'None':'Done'}); await doSwap(i,t,{[P(SH,'title')]:String(old(i,'title')),[P(SH,'showEyebrow')]:false,[P(SH,'done')]:String(old(i,'done')||'完成')}); },
 '236:14568': async i=>{ const LI=K.li; await doSwap(i,variant(LI,{State:'Default'}),{[P(LI,'title')]:String(old(i,'name')),[P(LI,'showHandle')]:old(i,'showHandle')!==false,[P(LI,'showMore')]:true,[P(LI,'showMeta')]:false}); },
 '236:14580': async i=>{ const A=K.add; await doSwap(i,variant(A,{State:'Default'}),{[P(A,'label')]:String(old(i,'label'))}); },
 '236:14582': async i=>{ const TO=K.toast; await doSwap(i,variant(TO,{Icon:'none'}),{[P(TO,'text')]:String(old(i,'text'))},{fixedW:false,center:true}); },
 '236:14584': async i=>{ const B=K.bb; await doSwap(i,B,{[P(B,'left')]:String(old(i,'left')),[P(B,'showLeft')]:old(i,'showLeft')!==false,[P(B,'middle')]:String(old(i,'middle')),[P(B,'primary')]:String(old(i,'primary'))}); },
};
const scope=SCOPE?await N(SCOPE):page;
const all=scope.findAllWithCriteria({types:['INSTANCE']});
const KITSEC=['236:14482','236:15762','255:14133'];
const inInst=n=>{ let p=n.parent; while(p&&p.type!=='PAGE'){ if(p.type==='INSTANCE'||p.type==='COMPONENT'||p.type==='COMPONENT_SET'||KITSEC.includes(p.id)) return true; p=p.parent; } return false; };
const res={done:0,nested:0,err:[]}; let count=0;
for(const i of all){ if(count>=LIMIT) break; if(i.removed) continue; const mc=await i.getMainComponentAsync(); if(!mc) continue; const top=mc.parent&&mc.parent.type==='COMPONENT_SET'?mc.parent:mc; if(!OLD.includes(top.id)) continue;
  if(inInst(i)){ res.nested++; continue; }
  try{ await map[top.id](i); res.done++; count++; }catch(e){ res.err.push(i.id+': '+String(e).slice(0,120)); if(res.err.length>8) break; } }
if(POST){ let fx=0; for(const i of scope.findAllWithCriteria({types:['INSTANCE']})){ if(!/^Editor\/(Field|PopUp)$/.test(i.name)) continue; const want=surface(i); const cur=i.componentProperties.Surface&&i.componentProperties.Surface.value; if(cur&&cur!==want){ i.setProperties({Surface:want}); fx++; } } res.surfaceFix=fx; }
const left=[]; for(const i of all){ if(i.removed) continue; const mc=await i.getMainComponentAsync(); if(!mc) continue; const top=mc.parent&&mc.parent.type==='COMPONENT_SET'?mc.parent:mc; if(OLD.includes(top.id)&&!inInst(i)) left.push(i.id); } res.left=left.length;
return res;
