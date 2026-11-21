// 07-R1-PL33 · page R1 · item 5.6 (PL-33): the twelve 017 state frames. Status dot+text → Player/Status Tag (icon + word);
// 已核销 pill → green check row and 评价 becomes the primary; amber 结果待确认 bar → a row with a chevron; 11 pt captions → 13 pt. DRY=true reports.
const PG=await goPage('228:4790');
const FR=['228:4790','228:4894','228:5003','228:5109','228:5242','228:5361','228:5487','228:5606','228:5712','228:5849','228:5981','228:6090'];
const PST=await byId('285:20260'), PB=await byId('285:20238');
const vkey=Object.keys(PST.componentPropertyDefinitions).find(k=>PST.componentPropertyDefinitions[k].type==='VARIANT'); const vopts=vkey?PST.componentPropertyDefinitions[vkey].variantOptions:[];
const tagVariant=(text,c)=>{ let k='Neutral'; if(/已完成|已核销|已结束|已通过/.test(text)) k='Done'; else if(/进行中|签到中|直播|记录中/.test(text)) k='Live'; else if(/暂停/.test(text)) k='Paused'; else if(c&&c.g>c.r+0.15&&c.g>c.b) k='Live'; else if(c&&c.r>0.7&&c.g>0.4&&c.b<0.35) k='Warning'; else if(/待确认|异常|超时/.test(text)) k='Warning';
  const opt=vopts.find(o=>o===k)||vopts.find(o=>o.toLowerCase()===k.toLowerCase())||vopts[0]; return PST.type==='COMPONENT_SET'?variant(PST,{[vkey.split('#')[0]]:opt}):PST; };
const plan=[];
for(const fid of FR){ const F=await byId(fid); if(!F){ plan.push({fid,missing:true}); continue; } const p={fid,name:F.name,pills:[],done:[],pending:[],eval:[],cap:[]};
  for(const n of F.findAll(x=>(x.type==='FRAME'||x.type==='GROUP')&&!insideInstance(x,F)&&x.height<=32&&x.width<=160)){ const dot=n.children.find(c=>(c.type==='ELLIPSE'||(c.type==='FRAME'&&c.cornerRadius>=c.width/2))&&c.width<=12); const t=n.children.find(c=>c.type==='TEXT'); if(dot&&t&&n.children.length<=3) p.pills.push({id:n.id,text:t.characters,c:solidOf(dot)}); }
  for(const t of texts(F).filter(t=>/^已核销\s*✓?$/.test(t.characters.trim()))){ let b=t.parent; while(b&&b!==F&&b.height<40) b=b.parent; if(b&&b!==F&&b.height<=64&&b.width>=150) p.done.push({id:b.id,type:b.type,h:Math.round(b.height),w:Math.round(b.width)}); }
  for(const t of texts(F).filter(t=>/结果待确认/.test(t.characters))){ let b=t.parent; while(b&&b!==F&&b.width<300) b=b.parent; if(b&&b!==F&&b.height<=72) p.pending.push({id:b.id,text:texts(b).map(x=>x.characters).join(' / '),h:Math.round(b.height)}); }
  for(const t of texts(F).filter(t=>t.characters.trim()==='评价')){ let b=t.parent; while(b&&b!==F&&b.height<40) b=b.parent; if(b&&b!==F) p.eval.push({id:b.id,type:b.type,main:b.type==='INSTANCE'?((await topMain(b))||{}).name:null}); }
  for(const t of texts(F).filter(t=>t.fontSize===11&&t.visible&&t.characters.trim().length>1&&!insideInstance(t,F))) p.cap.push(t.id);
  plan.push(p); }
R.info.plan=plan.map(p=>p.missing?p:{...p,pills:p.pills.map(x=>x.text),cap:p.cap.length});
if(DRY) return R;
const out=[];
for(const p of plan){ if(p.missing) continue; const F=await byId(p.fid);
  for(const x of p.pills){ const n=await byId(x.id); if(!n) continue; const v=tagVariant(x.text,x.c); const i=v.createInstance(); const tk=Object.keys(i.componentProperties).find(k=>i.componentProperties[k].type==='TEXT'); if(tk) i.setProperties({[tk]:x.text}); else { const tt=texts(i)[0]; if(tt) await setT(tt,x.text); } i.name='Player/Status Tag'; replaceAt(n,i,{vcenter:true}); R.created.push(i.id); }
  for(const x of p.done){ const n=await byId(x.id); if(!n) continue; const row=AL('HORIZONTAL','已核销 · check row',{gap:8}); row.resize(x.w,52); row.counterAxisSizingMode='FIXED';
    const ic=SVG(ICO.check('#30D158'),'icon/checkmark.circle.fill',22); row.appendChild(ic); for(const v of ic.findAll(n=>n.type!=='FRAME'&&'fills' in n)) if(solidOf(v)&&lum(solidOf(v))<0.9) v.fills=[PAINT(PN('ok','good','success'),{dark:true})];
    await TXT(row,'已核销',{size:17,lh:22,w:'Semibold',dark:true}); replaceAt(n,row,{keepW:true}); }
  for(const x of p.eval){ const n=await byId(x.id); if(!n) continue;
    if(n.type==='INSTANCE'&&x.main==='Player/Button'){ const vk=Object.keys(n.componentProperties).find(k=>k.split('#')[0]==='Kind'); if(vk) n.setProperties({[vk]:'Primary'}); }
    else { const v=variant(PB,{Kind:'Primary',Size:'52',State:'Default'})||PB.defaultVariant; const i=v.createInstance(); const lk=Object.keys(i.componentProperties).find(k=>i.componentProperties[k].type==='TEXT'); if(lk) i.setProperties({[lk]:'评价'}); i.name='Player/Button'; replaceAt(n,i,{keepW:true}); R.created.push(i.id); } }
  for(const x of p.pending){ const n=await byId(x.id); if(!n) continue; const row=AL('HORIZONTAL','结果待确认 · row',{gap:10,pad:[0,16,0,16],r:12,fill:'surface-3',dark:true}); row.resize(n.width,52); row.counterAxisSizingMode='FIXED';
    const v=tagVariant('待确认',null); const tg=v.createInstance(); row.appendChild(tg); const tk=Object.keys(tg.componentProperties).find(k=>tg.componentProperties[k].type==='TEXT'); if(tk) tg.setProperties({[tk]:'待确认'});
    const t=await TXT(row,'确认这一站的结果',{size:15,lh:20,dark:true}); t.layoutSizingHorizontal='FILL'; t.textAutoResize='HEIGHT'; const ch=SVG(ICO.chev('#8E8E93'),'chevron',null); row.appendChild(ch); replaceAt(n,row,{keepW:true}); }
  for(const id of p.cap){ const t=await byId(id); if(t){ await loadFontsOf(t); t.fontSize=13; t.lineHeight={unit:'PIXELS',value:18}; R.touched.push(id); } }
  ANN(F,'**Motion · 动效与触感 (PL-33)**\n- 现场记录: each completed step morphs its number into a check (220 ms) and the connector line fills downward (300 ms)\n- 核销: check row appears with a spring(response .42, damping .8) · .success\n- 结果待确认 row: push to the confirm page (system slide)\n\nReduce Motion: cross-fades 200 ms; haptics stay.','I',/^\*\*Motion/);
  FIXED(F,'5.6','PL-33 details: status tags with icon + word, 已核销 as a check row with 评价 as the primary, pending result as a chevron row, 13 pt captions.'); out.push(p.fid); }
R.info.done=out; R.created=R.created.length; R.touched=R.touched.length;
for(const id of ['228:5109','228:5981']){ const n=await byId(id); if(n) await n.screenshot({scale:0.45}); }
for(const id of ['169:6155']){ const n=await byId(id); if(n) await n.screenshot({scale:0.3}); }
return R;
