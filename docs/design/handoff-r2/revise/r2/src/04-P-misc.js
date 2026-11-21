// 04-P-misc · page P · 4.2 (home card meta, instance side), 4.6 (204:21385 keyboard label → System/Keyboard stand-in, label as note outside the frame),
// 4.9 / F-13 (204:15032 lobby back circle inside the frame, 12 pt above the primary), Q8 (210:8603 ¥560.00), Q9 (210:8239 header check).
const P=await goPage('210:8239');
await metaFix(['210:8239']);
R.info['4.9 P detail']=await scrim('210:9137');
const absX=n=>n.absoluteTransform[0][2], absY=n=>n.absoluteTransform[1][2];
const moveAbs=(n,ax,ay)=>{ if(ax!=null) n.x+=ax-absX(n); if(ay!=null) n.y+=ay-absY(n); };
// ---- 4.6 keyboard stand-in on 204:21385 ----
{ const F=await byId('204:21385'); const t=findText(F,/系统数字键盘/); const out={};
  if(t){ let area=t.parent; if(!(area!==F&&area.width>=300&&area.height>=150)){ area=F.children.filter(c=>c!==t&&c.width>=300&&c.height>=150&&c.y>F.height*0.45).sort((a,b)=>b.y-a.y)[0]||null; }
    const KB=await byId(KB_ID); const kb=KB.createInstance(); F.appendChild(kb); kb.name='System/Keyboard · 替身'; if(F.layoutMode&&F.layoutMode!=='NONE') kb.layoutPositioning='ABSOLUTE'; kb.x=0; kb.y=F.height-kb.height; kb.constraints={horizontal:'STRETCH',vertical:'MAX'}; R.created.push(kb.id);
    out.area=area?`${area.type} ${area.name} ${Math.round(area.width)}×${Math.round(area.height)}`:'none';
    if(area&&area!==F&&!texts(area).some(x=>x!==t)){ R.removed.push(area.id); area.remove(); } else { R.removed.push(t.id); t.remove(); }
    // keep home indicator / anything that must sit above the keyboard on top
    for(const c of F.children.filter(c=>/home ?indicator|indicator/i.test(c.name))) F.appendChild(c);
    await NOTE(F,'键盘区：系统数字键盘（.keyboardType(.numberPad)，验证码页用 .oneTimeCode），不绘制。System/Keyboard · 替身 只占位（verify-r1 4.6 / F-07）。','kb'); FIXED(F,'4.6','Keyboard area is the System/Keyboard stand-in; no label inside the phone frame.');
  } else out.missing='no 系统数字键盘 text';
  R.info['4.6 P']=out; }
// ---- 4.9 lobby 204:15032 ----
{ const F=await byId('204:15032'); const out={};
  const back=F.findAll(n=>n.type!=='TEXT'&&/back|返回|‹|chevron\.left/i.test(n.name)&&n.width<=52&&n.height<=52&&(absY(n)-absY(F))<160).sort((a,b)=>absY(a)-absY(b))[0];
  if(back){ out.backBefore=[Math.round(absX(back)-absX(F)),Math.round(absY(back)-absY(F)),back.width]; moveAbs(back,absX(F)+16,absY(F)+54+4); back.constraints={horizontal:'MIN',vertical:'MIN'};
    // anything (eyebrow/title) it still overlaps moves below it
    const bb={x:absX(back),y:absY(back),r:absX(back)+back.width,b:absY(back)+back.height};
    const hits=texts(F).filter(t=>t.visible&&!within(t,back)&&absX(t)<bb.r&&absX(t)+t.width>bb.x&&absY(t)<bb.b&&absY(t)+t.height>bb.y);
    out.overlapTexts=hits.map(t=>t.characters.slice(0,16));
    for(const t of hits){ const block=t.parent!==F&&t.parent.type!=='INSTANCE'&&t.parent.layoutMode&&t.parent.layoutMode!=='NONE'?t.parent:t; moveAbs(block,null,bb.b+8); R.touched.push(block.id); }
    R.touched.push(back.id); out.backAfter=[Math.round(absX(back)-absX(F)),Math.round(absY(back)-absY(F))]; } else out.back='not found';
  const prim=F.findAll(n=>(n.type==='INSTANCE'||n.type==='FRAME')&&n.height>=44&&texts(n).some(t=>/按住开始|开始/.test(t.characters))).sort((a,b)=>absY(b)-absY(a))[0];
  if(prim){ const above=F.findAll(n=>n!==prim&&!within(n,prim)&&!within(prim,n)&&(n.type==='FRAME'||n.type==='INSTANCE')&&n.width>=300&&n.height>=40&&n.height<=80&&absY(n)+n.height<=absY(prim)+2).sort((a,b)=>(absY(b)+b.height)-(absY(a)+a.height))[0];
    if(above){ const gap=absY(prim)-(absY(above)+above.height); out.gapBefore=Math.round(gap); out.above=above.name;
      if(gap<12){ const par=above.parent; if(par.layoutMode&&par.layoutMode!=='NONE'&&above.layoutPositioning!=='ABSOLUTE'&&par===prim.parent){ par.itemSpacing=Math.max(par.itemSpacing,12); } else moveAbs(above,null,absY(prim)-12-above.height); R.touched.push(above.id); out.gapAfter=12; } } }
  FIXED(F,'4.9','Back circle sits inside the frame under the status bar; 12 pt between the role row and 按住开始 (F-13).'); R.info['4.9 lobby']=out; }
function within(n,root){ let p=n; while(p){ if(p===root) return true; p=p.parent; } return false; }
// ---- Q8 balance ----
{ const F=await byId('210:8603'); const out=[]; for(const t of texts(F)){ if(/^[¥￥]?\s?560(\.00)?$/.test(t.characters.trim())){ out.push(t.characters); if(await setT(t,'¥560.00')) OWNER(F,'Q8','账户余额 is real money: shown as ¥560.00 (two decimals, ¥ mark), beside 积分 820.'); } } R.info.Q8=out; }
// ---- Q9 home header ----
{ const F=await byId('210:8239'); const H=F.findAllWithCriteria({types:['INSTANCE']}).find(i=>/Root Header/.test(i.name)); const out={};
  if(H){ out.props=Object.fromEntries(Object.entries(H.componentProperties).map(([k,v])=>[k.split('#')[0],v.value])); out.visibleActions=H.findAll(n=>/action|bell|消息|search|搜索/i.test(n.name)&&n.visible).map(n=>n.name); }
  R.info.Q9=out; }
// 4.1 follow-up: the sheet's button label is a component property
{ const nc5=await byId('345:3309'); if(nc5) for(const i of nc5.findAllWithCriteria({types:['INSTANCE']})){ const k=Object.keys(i.componentProperties).find(k=>i.componentProperties[k].type==='TEXT'&&i.componentProperties[k].value==='完成'); if(k){ i.setProperties({[k]:'去看看'}); R.info['4.1 btn']=i.id; } } }
await motionPass('PL-40');
R.created=R.created.length; R.touched=R.touched.length; R.ann=R.ann.length;
for(const id of ['210:8239','204:15032','204:21385']){ const n=await byId(id); if(n) await n.screenshot({scale:0.5}); }
return R;
