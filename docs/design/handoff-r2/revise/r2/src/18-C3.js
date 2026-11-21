// 18-C3 · page C3 · 4.6 (239:625, 239:771: drawn date/time capsules → System/Date Picker Compact stand-in, same stand-in as C1),
// 5.1 (CF-52: 238:19113, 238:19278 result sheets → Editor/Result with 查看活动 / 完成), Q6 (external-game price hidden until a rule exists), 5.7 (census).
const PG=await goPage('235:13237');
const DP=await byId(DP_ID); const DPC=variant(DP,{Style:'Compact'});
const RES=await byId('290:20551');
// ---- 4.6 compact capsules ----
{ const out=[];
  for(const id of ['239:625','239:771']){ const F=await byId(id); if(!F){ out.push(id+' missing'); continue; } const o={id,rows:[]};
    // a capsule row = a horizontal group of 2 small rounded boxes holding a date and a time
    const caps=F.findAll(n=>(n.type==='FRAME'||n.type==='INSTANCE')&&!insideInstance(n,F)&&n.height>=26&&n.height<=40&&n.width<=140&&n.cornerRadius>=6&&texts(n).length===1&&/(\d{1,2}月\d{1,2}日|\d{4}年|\d{1,2}:\d{2}|周[一二三四五六日])/.test(texts(n)[0].characters));
    const byPar={}; for(const c of caps){ (byPar[c.parent.id]=byPar[c.parent.id]||{p:c.parent,c:[]}).c.push(c); }
    for(const {p,c} of Object.values(byPar)){ c.sort((a,b)=>a.x-b.x); const first=c[0]; const i=DPC.createInstance(); i.name='System/Date Picker · Compact (替身)'; const idx=p.children.indexOf(first); p.insertChild(idx,i);
      if(!(p.layoutMode&&p.layoutMode!=='NONE')){ i.x=c[c.length-1].x+c[c.length-1].width-i.width; i.y=first.y+first.height/2-i.height/2; }
      const active=c.some(x=>x.strokes&&x.strokes.length); if(active){ i.strokes=[PAINT('ink')]; i.strokeWeight=1.5; i.strokeAlign='OUTSIDE'; i.cornerRadius=8; }
      o.rows.push(c.map(x=>texts(x)[0].characters).join(' + ')+(active?' (active)':'')); for(const x of c){ R.removed.push(x.id); x.remove(); } R.created.push(i.id); }
    await NOTE(F,'开始 / 结束：系统 DatePicker(.compact)，不绘制胶囊（verify-r1 4.6 / CF-39）。结束的 in: 下限 = 开始时间。替身 = System/Date Picker · 系统控件替身（与 C1 246:6728 同一个）。','datepicker');
    FIXED(F,'4.6','Compact system date + time pickers shown as the shared stand-in; no hand-drawn capsules.'); out.push(o); }
  R.info['4.6']=out; }
// ---- 5.1 result sheets ----
{ const out=[];
  for(const [id,title,body] of [['238:19113','活动已发布','11月21日 19:30 · 2 种票。玩家现在可以在活动页报名。'],['238:19278','修改已保存','11月21日 19:30 · 2 种票。已报名的玩家会收到通知。']]){ const F=await byId(id); if(!F){ out.push(id+' missing'); continue; }
    const ex=F.findAllWithCriteria({types:['INSTANCE']}); let has=null; for(const i of ex){ const m=await topMain(i); if(m&&m.id==='290:20551'){ has=i; break; } }
    const o={id,existing:!!has};
    // the sheet body = the white/grey panel holding the result copy
    const ts=texts(F).filter(t=>t.visible); const anchor=ts.find(t=>/11月21日|发布|已保存|成功|已提交/.test(t.characters));
    let sheet=anchor?anchor.parent:null; while(sheet&&sheet!==F&&!(sheet.width>=360&&sheet.height>=180&&solidOf(sheet))) sheet=sheet.parent; if(sheet===F) sheet=null;
    o.anchor=anchor?anchor.characters.slice(0,24):null; o.sheet=sheet?sheet.name+' '+Math.round(sheet.width)+'×'+Math.round(sheet.height):null;
    const inst=has||(variant(RES,{State:'Success'})||RES.defaultVariant).createInstance();
    const k=b=>keyOf(RES,b); const P={}; if(k('title')) P[k('title')]=title; if(k('body')) P[k('body')]=body; if(k('primary')) P[k('primary')]='查看活动'; if(k('secondary')) P[k('secondary')]='完成'; if(k('showSecondary')) P[k('showSecondary')]=true;
    if(Object.keys(P).length) inst.setProperties(P); else R.warn.push('Editor/Result has no text props yet (run 02 first)');
    if(!has){ if(sheet){ // keep grabber/handle; replace the sheet's content with the result
        const keep=sheet.children.filter(c=>/grabber|handle|抓手/i.test(c.name)); for(const c of sheet.children.filter(c=>!keep.includes(c))){ c.visible=false; } sheet.appendChild(inst); if(sheet.layoutMode&&sheet.layoutMode!=='NONE'){ inst.layoutSizingHorizontal='FILL'; for(const c of sheet.children.filter(c=>!c.visible)){ R.removed.push(c.id); c.remove(); } } else { inst.resize(sheet.width,inst.height); inst.x=0; inst.y=keep.length?Math.max(...keep.map(c=>c.y+c.height))+8:16; for(const c of sheet.children.filter(c=>!c.visible)){ R.removed.push(c.id); c.remove(); } if(inst.y+inst.height>sheet.height){ const d=inst.y+inst.height+34-sheet.height; sheet.resize(sheet.width,sheet.height+d); sheet.y-=d; } }
        o.placed='in sheet'; }
      else { F.appendChild(inst); inst.x=0; inst.y=F.height-inst.height; o.placed='bottom of frame'; } }
    inst.name='Editor/Result'; R.created.push(inst.id);
    FIXED(F,'5.1','Result sheet ends with buttons: 查看活动 (primary) / 完成; no dead end (CF-52).'); out.push(o); }
  R.info['5.1']=out; }
// ---- Q6 external-game price ----
{ const out=[]; for(const s of PG.children.filter(s=>s.type==='SECTION')) for(const F of s.children){ if(F.type!=='FRAME') continue; const ext=/外部|外链|第三方|小游戏|external/i.test(F.name)||texts(F).some(t=>/外部游戏|第三方游戏|外部玩法/.test(t.characters)); if(!ext) continue;
    let hit=0; for(const t of texts(F)){ if(/^[\d,，]+\s?积分(起)?$/.test(t.characters.trim())&&t.visible){ let row=t; if(t.parent&&t.parent!==F&&t.parent.children.length<=3&&texts(t.parent).length<=2&&t.parent.width<200) row=t.parent; row.visible=false; hit++; R.touched.push(row.id); } }
    if(hit){ OWNER(F,'Q6','External-game price hidden until the 积分 conversion rule exists (no placeholder 1,260 积分).'); out.push(F.id+' '+F.name.slice(0,24)+' ×'+hit); } }
  R.info.Q6=out; }
await census('C3');
return R;
