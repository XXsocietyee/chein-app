await goPage('204:7911');
const pg=figma.currentPage;
async function ANN(node,text){ let f=node; while(f.parent&&f.parent.type!=='PAGE'&&f.parent.type!=='SECTION') f=f.parent; await NOTE(f,'Motion (xrefs-1) · '+text,'xr'); }
// 0 · Patterns table fixes (cross-page)
await B('tablefix',async()=>{ const p6=await byId('6:4'); await p6.loadAsync(); let n=0; for(const id of ['454:653','454:767']){ const t=await byId(id); for(const f of t.findAll(x=>x.type==='FRAME'&&x.name==='pad')){ f.resize(f.width,1); n++; } } const tk=await byId('454:653'); tk.paddingLeft=tk.paddingRight=tk.paddingTop=tk.paddingBottom=0; const tt=tk.findOne(x=>x.name==='title'); if(tt) tt.visible=false; await setT(await byId('402:650'),'Motion tokens · 动效令牌 (one set · xrefs-1)'); R.info.pads=n; });
// 1 · deed photos (census)
const PH={'武康大楼':['382:1055','382:1056'],'梧桐书店':['382:1063','382:1064'],'老麦咖啡馆':['435:4517','435:4518']};
const NOPH=['453:1395','453:1404'];
async function fixDeeds(root){ let fixed=0, nophoto=[], kept=0;
  for(const d of root.findAllWithCriteria({types:['INSTANCE']})){ const mc=d.mainComponent; if(!mc||!mc.parent||mc.parent.id!=='381:1401') continue;
    const p=d.componentProperties; const pk=Object.keys(p).find(k=>k.startsWith('Photo#')); const nk=Object.keys(p).find(k=>k.startsWith('名称#')); if(!pk||!nk) continue;
    if(/State=Unlit/.test(mc.name)){ kept++; continue; }
    const cur=await byId(p[pk].value); const curName=cur?cur.name:''; const name=p[nk].value; const oneByOne=/Ratio=1:1/.test(curName)||/Size=(Mini|Row)/.test(mc.name);
    const people=/not for deeds/.test(curName); const isDefault=/Place=Default/.test(curName); const named=/Place=(武康大楼|梧桐书店|老麦咖啡馆)/.exec(curName);
    let want=null;
    if(PH[name]) want=PH[name][/Ratio=1:1/.test(curName)?1:0];
    else want=NOPH[oneByOne?1:0];
    if(named&&named[1]===name) continue;
    if(!isDefault&&!people&&!named&&!PH[name]&&/No photo/.test(curName)) continue;
    if(!isDefault&&!people&&named&&named[1]!==name&&PH[name]==null){ /* photo of another place on this deed */ }
    d.setProperties({[pk]:want}); fixed++;
    if(!PH[name]){ const cov=d.findOne(n=>n.type==='INSTANCE'&&n.mainComponent&&n.mainComponent.parent&&n.mainComponent.parent.id==='381:993'); if(cov){ try{ setProps(cov,{'地名':name}); }catch(e){ R.warn.push('地名 '+e); } } nophoto.push(name); } }
  return {fixed,nophoto:[...new Set(nophoto)],unlitKept:kept}; }
await B('deeds',async()=>{ R.info.deedsN1=await fixDeeds(pg); });
// 2 · moments: number wins (N38, N39), notes on N22
await B('moments',async()=>{
  const fix=async(id,kick,head,line)=>{ const m=await byId(id); const before=JSON.stringify(Object.fromEntries(Object.entries(m.componentProperties).filter(([k])=>/Headline|Line/.test(k)).map(([k,v])=>[k.split('#')[0],v.value]))); setProps(m,{'Show kicker':true,'Kicker':kick,'Headline':head,'Line':line}); const h=m.findOne(n=>n.type==='TEXT'&&n.name==='headline'); if(h){ await loadFontsOf(h); await h.setTextStyleIdAsync(TS['t-hero'].id); } return before; };
  R.info.N38before=await fix('391:4137','14 + 3','17','拿下 转角花店。你的修正把 14 推到了 17。');
  R.info.N39before=await fix('391:4251','5 + 3','8','差 1 点，这次没拿下。');
  await ANN(await byId('204:34407'),'flow 8 + 4 · die lands at the deed corner (spring/hero → seal), kicker 14 + 3 shows as it lands, total rolls 14 → 17 at +400 ms over 300 ms (numericText, tabular); one white success wave 450 ms from the button at ≈ 780 ms; Reduce Motion: total appears, no roll, no wave.');
  await ANN(await byId('204:34440'),'flow 8 · lost: grey die, total 8 shows without a wave; one soft impact; nothing else moves.');
  await ANN(await byId('204:26968'),'flow 1 + 4 · photo arrives from the N21 thumbnail (spring/hero 0.45/0.86), deed band +250, seal +600 (contact ≈ 780, heavy), headline +950, chips 0 / 50 / 90 ms, actions +1250. One success wave (white 12 %, 450 ms) at the seal contact. See section 照片 → 地契. Reduce Motion: 200 ms cross-fade.');
});
// 3 · balances become one number + a fading delta chip
await B('balances',async()=>{ let n=0; const re=/^([\d,]+) → ([\d,]+)$/;
  for(const t of pg.findAllWithCriteria({types:['TEXT']})){ if(!re.test(t.characters)) continue; let p=t.parent; if(!p||p.type!=='FRAME'||p.layoutMode==='NONE') continue; let inInst=false; for(let a=t.parent;a&&a.type!=='PAGE';a=a.parent) if(a.type==='INSTANCE'){ inInst=true; break; } if(inInst) continue;
    const [,a,b]=re.exec(t.characters); const diff=parseInt(b.replace(/,/g,''))-parseInt(a.replace(/,/g,'')); await setT(t,b);
    const g=AL('HORIZONTAL','value · rolls',{gap:6}); p.insertChild(p.children.indexOf(t),g); g.appendChild(t);
    const chip=AL('HORIZONTAL','delta chip (fades after the roll)',{fill:'surface-3',r:999,pad:[2,8]}); g.appendChild(chip); await TX(chip,(diff<0?'−':'+')+Math.abs(diff).toLocaleString('en-US'),'t-cap2','ink-2',{name:'delta'}); n++; }
  R.info.balances=n;
  await ANN(await byId('204:26708'),'flow 2 + 3 · tap 打开相机拍照: capsule dips 0.97 (spring/press) and turns Loading in place; the result arrives as Done in the same capsule (section 原地结果). 积分余额 is one number (tabular) with a −120 chip; on confirm the number rolls 1,286 → 1,166 in 300 ms and the chip fades 200 ms after. Check rows swap spinner → tick in place (symbol replace). Reduce Motion: cross-fades 200 ms.');
});
// 4 · N34 flatter, N45 reason above the disabled button
await B('challenge',async()=>{ const ob=await byId('390:3777'); R.info.oddsFills=ob.fills.length; ob.fills=[]; ob.strokes=[]; ob.effects=[];
  const n45=await byId('204:34759'); const btn=n45.findAll(n=>n.type==='INSTANCE'&&n.mainComponent&&n.mainComponent.parent&&n.mainComponent.parent.id==='285:20238').find(b=>/Kind=Primary/.test(b.mainComponent.name));
  if(btn&&!n45.findOne(n=>n.name==='blocking reason')){ const par=btn.parent; const cap=await TX(null,'再走近 235 m 就能开始挑战','t-foot','ink-2',{name:'blocking reason',align:'CENTER'}); par.insertChild(par.children.indexOf(btn),cap); try{ cap.layoutSizingHorizontal='FILL'; }catch(e){} R.info.n45btn=btn.mainComponent.name; }
  await ANN(await byId('204:34263'),'flow 2 + 16 · odds bar sits on the sheet (no card); one card for fee + attempts. When the distance check passes the check symbol replaces in place, then 开始挑战 fills surface-3 → cta (spring/standard) with one selection haptic. Confirm stays in place (Loading → Done).');
  await ANN(n45,'flow 16 · the blocking reason sits directly above the disabled button; it fades 200 ms when the player is close enough and the button fills (spring/standard).');
});
// 5 · N36 die alone up top, text + odds down by the button
await B('n36',async()=>{ const m=await byId('391:3938'); const c=m.findOne(n=>n.name==='content'&&n.type==='FRAME'); c.primaryAxisAlignItems='MAX'; R.info.n36=c.primaryAxisAlignItems;
  await ANN(await byId('204:34340'),'flow 8 + 15 · the die is alone in the top half; headline, chips and the button sit in the thumb zone. Idle: ±3° and 2 pt float, 3 s period, stops on touch (off under Reduce Motion / Low Power). Drag tracks 1:1; release velocity seeds the spin; light haptic every 120 ms in flight.'); });
// 6 · stats without a box (N01, N46, N28)
await B('stats',async()=>{ const out=[]; const plain=(await byId('427:1552')).children.find(c=>/Emphasis=Plain/.test(c.name));
  for(const fid of ['204:21814','205:8376','204:33843']){ const f=await byId(fid); const tiles=f.findAll(n=>n.type==='INSTANCE'&&n.mainComponent&&n.mainComponent.parent&&n.mainComponent.parent.id==='427:1552'); const parents=[...new Set(tiles.map(t=>t.parent))];
    for(const p of parents){ let inInst=false; for(let a=p;a&&a.type!=='PAGE';a=a.parent) if(a.type==='INSTANCE'){ inInst=true; break; } if(inInst||p.layoutMode!=='HORIZONTAL') continue; const ts=p.children.filter(c=>tiles.includes(c));
      p.fills=[]; p.strokes=[]; p.effects=[]; p.primaryAxisAlignItems='SPACE_BETWEEN'; p.counterAxisAlignItems='CENTER'; p.paddingLeft=p.paddingRight=0;
      for(const old of p.children.filter(c=>c.name==='divider')) old.remove();
      for(const t of ts){ t.swapComponent(plain); }
      for(let i=1;i<ts.length;i++){ const r=figma.createRectangle(); r.name='divider'; r.resize(1,28); r.fills=[PAINT('sep')]; p.insertChild(p.children.indexOf(ts[i]),r); }
      out.push(fid+':'+p.id+'×'+ts.length); } }
  R.info.stats=out;
  await ANN(await byId('204:21814'),'flow 3 · stats: three numbers, two hairlines, no box (Adopt 4). Values roll with numericText (300 ms) only when they change — never on opening the board.'); });
// 7 · property sheets: material at the partial detent, deed without outline
await B('sheets',async()=>{ const out=[]; for(const fid of ['204:23400','204:23542','204:23691','204:23832','204:23956']){ const f=await byId(fid); const s=f.findOne(n=>n.type==='FRAME'&&n.name==='sheet'); if(s){ s.fills=[RAW('1C1C1E',0.72)]; s.effects=[{type:'BACKGROUND_BLUR',radius:24,visible:true}]; }
    let cleared=0; for(const d of f.findAll(n=>n.type==='INSTANCE'&&n.mainComponent&&n.mainComponent.parent&&n.mainComponent.parent.id==='381:1401')){ if(d.strokes&&d.strokes.length&&d.dashPattern&&d.dashPattern.length){ d.strokes=[]; cleared++; } for(const x of d.findAll(n=>'dashPattern' in n&&n.dashPattern&&n.dashPattern.length&&n.strokes&&n.strokes.length)){ x.strokes=[]; cleared++; } }
    out.push(fid+(s?' sheet '+s.id:' nosheet')+' dash×'+cleared); }
  R.info.sheets=out;
  await ANN(await byId('204:23400'),'flow 7 + 9 · tapped pin scales 1 → 1.15 (spring/release, selection haptic); sheet is the system material at the 420 pt detent (opaque at .large), map stays live above it; deed inside is a plain fill (no outline). Content is already in the sheet — no stagger.'); });
// 8 · N47 / N48 hug + notes
await B('n47',async()=>{ const out=[]; for(const [fid,sid] of [['205:8475','205:8477'],['205:8580','205:8582']]){ const f=await byId(fid); const s=await byId(sid); const h0=s.height; if(s.layoutMode!=='NONE'){ s.primaryAxisSizingMode='AUTO'; } s.y=f.height-s.height; out.push(fid+' '+Math.round(h0)+'→'+Math.round(s.height)); }
  R.info.n47=out;
  await ANN(await byId('205:8475'),'flow 2 + 3 · one detent = content height. 开护盾 stays in place: Loading → Done (护盾已开), the 积分 row rolls, then the sheet closes after 600 ms and the deed row behind already shows 保护到 明天 02:20.');
  await ANN(await byId('205:8580'),'flow 2 + 3 · same in-place pattern as 开护盾: Loading → Done (升级完成), balance rolls, sheet closes after 600 ms, the level pips on the row behind are already updated.'); });
// 9 · strip beat 1 shows the thumbnail as the source
await B('strip',async()=>{ const s=await byId('399:4431'); const th=s.findOne(n=>n.name==='img/现场照片'); if(th){ th.strokes=[RAW('FFFFFF')]; th.strokeWeight=2; th.strokeAlign='OUTSIDE'; R.info.stripThumb=th.id; const fr=th; } await ANN(s,'beat 1 · source = this thumbnail (white ring). It becomes the deed photo in beat 3 (spring/hero); see section 照片 → 地契.'); });
await B('n21',async()=>{ await ANN(await byId('204:26924'),'flow 1 · this 64 pt photo is the hero: when the checks pass it flies into the deed photo slot of N22 (matchedTransitionSource / zoom transition, spring/hero). The four checks swap spinner → tick in place.'); });
return R;
