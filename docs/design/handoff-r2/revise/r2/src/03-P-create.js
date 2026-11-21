// 03-P-create · page P · item 4.1 (F-01, MC-01 relink): flow 5 创建俱乐部 walks the real create flow (copies of R3 204:24591…24716),
// ends on a 俱乐部已创建 sheet with 去看看. The 申请主理人 form stays only where a 主理人/申请 entry points to it; otherwise it is archived.
// DRY=true: report frames, entry points, flows.
const P=await goPage('209:16053');
// entry kinds confirmed by the DRY run: home banner 成为俱乐部主理人 and 设置 › 成为俱乐部主理人 = apply; 俱乐部 tab 创建俱乐部 = create
const KIND={'211:5026':'apply','211:5072':'apply','211:5046':'create'};
const OLD=['209:16053','209:16076','209:16104','209:16127'], SRC=['204:24591','204:24631','204:24676','204:24716'];
const old=await Promise.all(OLD.map(byId)); const sec=old[0].parent;
const c5=sec.children.find(c=>c.type==='FRAME'&&/create5|申请已提交/.test(c.name));
const within=(n,roots)=>{ let p=n; while(p){ if(roots.includes(p)) return true; p=p.parent; } return false; };
const topFrame=n=>{ let p=n; while(p.parent&&p.parent.type!=='SECTION'&&p.parent.type!=='PAGE') p=p.parent; return p; };
const ownFrames=[...old,c5].filter(Boolean);
const ext=[]; for(const s of sourcesTo(ownFrames.map(f=>f.id))){ const n=await byId(s.src); if(within(n,ownFrames)) continue; const tf=topFrame(n);
  const ctx=[n.name,...texts(n).map(t=>t.characters),...(n.parent?texts(n.parent).slice(0,6).map(t=>t.characters):[])].join(' ');
  ext.push({...s,frame:tf.name,frameId:tf.id,ctx:ctx.slice(0,120),kind:KIND[s.src]||(/主理人|申请/.test(ctx)?'apply':'create')}); }
R.info.old=ownFrames.map(o=>`${o.id} ${o.name} @${Math.round(o.x)},${Math.round(o.y)} ${Math.round(o.width)}×${Math.round(o.height)}`);
R.info.entries=ext; R.info.flows=P.flowStartingPoints.filter(f=>OLD.includes(f.nodeId)||/俱乐部|创建|主理人/.test(f.name));
R.info.section={id:sec.id,name:sec.name,w:sec.width,h:sec.height};
if(DRY){ R.info.c5roles=c5?texts(c5).filter(t=>t.visible).map(t=>`${t.id} ${t.name}=${t.characters.slice(0,30)}`):null; return R; }
// --- 1) copies of the R3 create flow, in place of the apply frames ---
const r3=await pageOf(SRC[0]); await r3.loadAsync();
function modesChain(n){ const m={}; let p=n; while(p&&p.type!=='DOCUMENT'){ if(p.explicitVariableModes) for(const [cid,mid] of Object.entries(p.explicitVariableModes)) if(!(cid in m)) m[cid]=mid; p=p.parent; } return m; }
const news=[];
for(let k=0;k<4;k++){ const s=await byId(SRC[k]); const c=s.clone(); sec.appendChild(c); c.x=old[k].x; c.y=old[k].y; c.name=`create${k+1} · ${s.name.replace(/^.*?·\s*/,'')}`;
  for(const [cid,mid] of Object.entries(modesChain(s))){ const col=COLS[cid]||await figma.variables.getVariableCollectionByIdAsync(cid); if(col) c.setExplicitVariableModeForCollection(col,mid); }
  // drop links that pointed at R3 frames
  for(const n of [c,...c.findAll(x=>'reactions' in x&&x.reactions&&x.reactions.length>0)]){ if(!n.reactions||!n.reactions.length) continue; const keep=[]; for(const r of n.reactions){ const acts=[]; for(const a of actsOf(r)){ if(a&&a.type==='NODE'&&a.destinationId){ const d=await byId(a.destinationId); if(!d||(await pageOf(d))!==P) continue; } acts.push(a); } if(acts.length) keep.push({trigger:r.trigger,actions:acts}); } await n.setReactionsAsync(keep); }
  news.push(c); R.created.push(c.id); FIXED(c,'4.1',`Real create flow (copy of R3 ${SRC[k]}); the 申请主理人 form is a different flow (F-01).`); }
// --- 2) result sheet: the new step 4 under the c5 sheet, which now reads 俱乐部已创建 · 去看看 ---
let nc5=null;
if(c5){ nc5=news[3].clone(); sec.appendChild(nc5); nc5.x=c5.x; nc5.y=c5.y; nc5.name='create5 · 俱乐部已创建 sheet'; R.created.push(nc5.id); nc5.annotations=[];
  for(const n of [nc5,...nc5.findAll(x=>'reactions' in x&&x.reactions&&x.reactions.length)]) if(n.reactions&&n.reactions.length) await n.setReactionsAsync([]);
  const titleT=texts(c5).find(t=>/申请已提交/.test(t.characters)); let sheet=titleT; while(sheet&&sheet.parent!==c5) sheet=sheet.parent;
  const si=c5.children.indexOf(sheet); const scrim=c5.children.slice(0,si).reverse().find(c=>c.width>=c5.width-1&&c.height>=c5.height*0.9&&solidOf(c)&&lum(solidOf(c))<0.1);
  const add2=n=>{ const k=n.clone(); nc5.appendChild(k); if(nc5.layoutMode&&nc5.layoutMode!=='NONE') k.layoutPositioning='ABSOLUTE'; k.x=n.x; k.y=n.y; return k; };
  if(scrim) add2(scrim); const sh=add2(sheet); for(const h of c5.children.filter(c=>c.name.startsWith('⌖'))) add2(h);
  const ts=texts(sh).filter(t=>t.visible&&t.characters.trim()); const title=ts.find(t=>/申请已提交/.test(t.characters)); await setT(title,'俱乐部已创建');
  const btnT=ts.filter(t=>/^(完成|好的|知道了)$/.test(t.characters.trim())); for(const t of btnT) await setT(t,'去看看');
  const rest=ts.filter(t=>t!==title&&!btnT.includes(t)&&t.characters.length>4).sort((a,b)=>b.characters.length-a.characters.length);
  if(rest[0]) await setT(rest[0],'现在可以邀请成员，或者发布第一场活动。'); for(const t of rest.slice(1)) if(/审核|工作日|通知|申请/.test(t.characters)){ t.visible=false; R.touched.push(t.id); }
  R.info.c5={scrim:!!scrim,sheet:sheet&&sheet.name,hotspots:nc5.children.filter(c=>c.name.startsWith('⌖')).map(c=>c.name)};
  FIXED(nc5,'4.1','Result of 创建俱乐部 over the new step 4: 俱乐部已创建 · 去看看 → club home. Motion: sheet rises with the system spring, check draws 220 ms · .success.'); }
// --- 3) wire the new flow ---
const btnIn=f=>{ const cands=f.findAll(n=>(n.type==='INSTANCE'||n.type==='FRAME')&&n.height>=44&&n.height<=56&&texts(n).some(t=>/下一步|继续|创建|完成|提交/.test(t.characters))); return cands.sort((a,b)=>b.absoluteTransform[1][2]-a.absoluteTransform[1][2])[0]; };
const leadIn=f=>f.findAll(n=>n.type!=='TEXT'&&n.width<=56&&n.height<=56&&(n.absoluteTransform[1][2]-f.absoluteTransform[1][2])<130&&(n.absoluteTransform[0][2]-f.absoluteTransform[0][2])<70&&/back|close|‹|✕|leading|返回|关闭|xmark|chevron/i.test(n.name))[0];
const wired=[];
for(let k=0;k<4;k++){ const b=btnIn(news[k]); const dest=k<3?news[k+1]:nc5; if(b&&dest){ await link(b,dest.id,k<3?PUSH('LEFT'):SHEET_IN); wired.push(`${news[k].name}: ${b.name} → ${dest.name}`); } else R.warn.push('no primary in '+news[k].id);
  const l=leadIn(news[k]); if(l){ await link(l,'BACK'); wired.push(`${news[k].name}: ${l.name} → back`); } else R.warn.push('no leading control in '+news[k].id); }
R.info.wired=wired;
// --- 4) entries: create → new flow; apply entries keep the old (申请主理人) frames ---
const createSrc=ext.filter(e=>e.kind==='create'), applySrc=ext.filter(e=>e.kind==='apply');
for(const e of createSrc){ const n=await byId(e.src); const rs=n.reactions.map(r=>({trigger:r.trigger,actions:actsOf(r).map(a=>a&&a.destinationId===OLD[0]?{...a,destinationId:news[0].id}:a)})); await n.setReactionsAsync(rs); }
P.flowStartingPoints=P.flowStartingPoints.map(f=>OLD.includes(f.nodeId)?{nodeId:news[0].id,name:/主理人|申请/.test(f.name)?f.name:'创建俱乐部'}:f);
if(applySrc.length){ // keep the apply form below, renamed
  let y=Math.max(...sec.children.map(c=>c.y+c.height))+240; let x=old[0].x;
  for(const [k,o] of old.entries()){ o.name=`apply${k+1} · 申请主理人 ${k+1}/4`; o.y=y; o.x=x+(o.x-old[0].x); R.touched.push(o.id); for(const t of texts(o).filter(t=>t.characters==='建一个俱乐部')) await setT(t,'申请成为主理人'); FIXED(o,'4.1','申请主理人 form (entry: 首页 banner and 设置 › 成为俱乐部主理人). Not the create flow (F-01).'); }
  if(c5){ c5.name='apply5 · 申请已提交 sheet'; c5.y=y; for(const t of texts(c5).filter(t=>t.characters==='建一个俱乐部')) await setT(t,'申请成为主理人'); }
  growSec(old[3]); if(c5) growSec(c5); R.info.applyKept=true;
} else { await ARCHIVE([...old,c5],'P · 原型','verify-r1 4.1 / F-01: 申请主理人 form was drawn as 创建俱乐部; no 申请主理人 entry on P points here.'); }
R.info.createEntries=createSrc.length; R.info.applyEntries=applySrc.length;
return R;
