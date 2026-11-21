// 10-R4-onboard · page R4 · Q2 (owner CHANGED 2026-11-16: KEEP the identity step) — 182:7628 经营者实名 redesigned
// (真实姓名 + 身份证号, privacy line, secure entry, no autofill), new error state frame, ID masked as 110***********1234 on review 182:7693 and anywhere after;
// 4.5 (F-05 / MR-17: 183:1731 + 183:1819 status by who must act, 11月14日 19:28, copy icon in ink, 12 pt gap; every Merchant/Status Tag on R4 re-mapped);
// 4.9 (F-06: 182:8065 营销 title, grey bar removed, 管理 ›).
const PG=await goPage('182:7628');
const absX=n=>n.absoluteTransform[0][2], absY=n=>n.absoluteTransform[1][2];
const MASK='110***********1234';
const FIELD=await byId('276:638');
async function fieldInfo(F){ const out=[]; for(const i of F.findAllWithCriteria({types:['INSTANCE']})){ const mc=await topMain(i); if(mc&&mc.id==='276:638'){ const p=i.componentProperties; const g=b=>{ const k=Object.keys(p).find(k=>k.split('#')[0]===b); return k?p[k].value:undefined; }; out.push({i,label:String(g('label')||''),value:String(g('value')||''),state:g('State')}); } } return out; }
const setF=(i,o)=>{ const p={}; const D=FIELD.componentPropertyDefinitions; const k=b=>keyOf(FIELD,b); for(const [b,v] of Object.entries(o)){ const kk=k(b); if(!kk) continue; if(D[kk].type==='VARIANT'&&!D[kk].variantOptions.includes(v)){ R.warn.push('Field '+b+'='+v+' not an option'); continue; } p[kk]=v; } i.setProperties(p); };
// ---------- Q2 identity step ----------
{ const F=await byId('182:7628'); const out={name:F.name}; const fs=await fieldInfo(F); out.fieldsBefore=fs.map(f=>`${f.label}=${f.value} [${f.state}]`);
  const nameF=fs.find(f=>/姓名/.test(f.label))||fs[0], idF=fs.find(f=>/身份证|证件/.test(f.label))||fs[1];
  if(nameF) setF(nameF.i,{label:'真实姓名',showLabel:true,value:'王小城',State:'Filled',help:'与身份证上的姓名一致',showHelp:false});
  if(idF){ setF(idF.i,{label:'身份证号',showLabel:true,value:MASK,State:'Filled',help:'18 位，最后一位可能是 X',showHelp:false,suffix:'',showSuffix:false}); idF.i.name='Editor/Field · 身份证号 (secure, masked after entry)'; }
  if(!fs.length){ // raw layers: set the value texts next to the labels
    for(const [re,val] of [[/^真实姓名|^姓名/,'王小城'],[/^身份证号|^证件号/,MASK]]){ const lab=texts(F).find(t=>re.test(t.characters.trim())); if(lab){ const val0=texts(lab.parent).find(t=>t!==lab&&t.characters.trim()); if(val0) await setT(val0,val); } } out.raw=true; }
  // privacy line under the ID field (lock + one sentence); replaces an older why/privacy line if it already says the same thing
  const old=texts(F).find(t=>/加密|仅用于|隐私/.test(t.characters)); if(old){ await setT(old,'仅用于商家资质审核，加密保存'); out.privacy='rewritten '+old.id; }
  else if(idF){ const host=idF.i.parent; const row=AL('HORIZONTAL','privacy · 仅用于商家资质审核',{gap:6}); const lk=SVG(ICO.lock('#6B6B6B'),'icon/lock.fill',14); row.appendChild(lk); for(const v of lk.findAll(n=>'fills' in n&&n.fills.length)) v.fills=[PAINT('ink-2')]; for(const v of lk.findAll(n=>'strokes' in n&&n.strokes.length)) v.strokes=[PAINT('ink-2')];
    await TXT(row,'仅用于商家资质审核，加密保存',{size:13,lh:18,color:'ink-2'});
    if(host.layoutMode&&host.layoutMode!=='NONE'){ host.insertChild(host.children.indexOf(idF.i)+1,row); } else { host.appendChild(row); row.x=idF.i.x+4; row.y=idF.i.y+idF.i.height+8; } out.privacy='added'; }
  ANN(F,'**身份证号 · secure entry (Q2)**\n- `.textContentType(nil)`, `.autocorrectionDisabled()`, `.textInputAutocapitalization(.characters)`, `.keyboardType(.asciiCapable)` (X allowed), `.privacySensitive()`: no QuickType / autofill suggestions\n- Validate on 继续: 18 characters, last may be X, GB 11643 checksum; error under the field, primary stays enabled and jumps to the field (.error)\n- After entry the value shows masked `110***********1234` (first 3 + last 4) here, on 确认并提交 and on every later page; never logged\n- Request fields: realName, idCardNumber (merchant application submit)','D',/^\*\*身份证号/);
  OWNER(F,'Q2','Identity step KEPT (business registration in China needs an ID card): 真实姓名 + 身份证号, inline error, privacy line, masked after entry.');
  R.touched.push(F.id); R.info.Q2=out;
  // error state frame (validation on 继续)
  const sec=F.parent; const enm=F.name.replace(/\s*·\s*身份证号有误$/,'')+' · 身份证号有误'; const ex=sec.children.find(c=>c.name===enm); if(ex) ex.remove();
  const E=F.clone(); sec.appendChild(E); E.name=enm; const rowR=Math.max(...sec.children.filter(c=>c!==E&&Math.abs(c.y-F.y)<F.height/2).map(c=>c.x+c.width)); E.x=rowR+120; E.y=F.y; growSec(E); R.created.push(E.id);
  for(const n of E.findAll(x=>'reactions' in x&&x.reactions&&x.reactions.length)) await n.setReactionsAsync([]);
  const efs=await fieldInfo(E); const eid=efs.find(f=>/身份证/.test(f.label));
  if(eid) setF(eid.i,{value:'11010119900307123',State:'Error',help:'身份证号应为 18 位，最后一位可能是 X',showHelp:true});
  ANN(E,'**Error state (Q2)** · shown after 继续 with a wrong ID: field turns red, message under it, focus returns to the field (VoiceOver reads the message). While the field is being edited the value is visible; it is masked once it validates.','D',/^\*\*Error state/);
  OWNER(E,'Q2','Inline validation error for 身份证号 (length / last character / GB 11643 checksum).'); R.info.Q2.errorFrame=E.id; }
// mask every ID-like value on R4 (review page and later pages)
{ const out=[]; const idFrames=[]; for(const sct of PG.children.filter(x=>x.type==='SECTION')) for(const f of sct.children) if(f.type==='FRAME'&&texts(f).some(t=>/身份证|实名|证件/.test(t.characters))) idFrames.push(f);
  for(const t of idFrames.flatMap(f=>texts(f))){ const c=t.characters; if(/(^|\D)\d{17}[\dXx](\D|$)/.test(c)||/\d{3,6}\*{4,}\d{3,4}/.test(c)&&c.trim()!==MASK){ const nv=c.replace(/\d{17}[\dXx]|\d{3,6}\*{4,}[\dXx]{3,4}/g,MASK); if(nv!==c){ await setT(t,nv); out.push(t.id); } } } R.info.masked=out;
  const RV=await byId('182:7693'); if(RV){ R.info.reviewTexts=texts(RV).filter(t=>/身份|实名|姓名|证件/.test(t.characters)).map(t=>t.characters.slice(0,30)); OWNER(RV,'Q2','经营者实名 group shows 真实姓名 and the ID masked as 110***********1234; 修改 returns to step 4.'); } }
// ---------- 4.5 status by who must act ----------
const MT=await byId('316:5196'); const MTk=Object.keys(MT.componentPropertyDefinitions).find(k=>MT.componentPropertyDefinitions[k].type==='VARIANT'); const MTopt=MT.componentPropertyDefinitions[MTk].variantOptions;
const NEEDS=/等待商家|待商家|商家意见|待你|待处理|待核验|待回复|待审批|待接受|待签约|待补充|需补充|去处理/, WAIT=/平台审核中|审核中|待审核|待复核|等待平台|等待玩家|等待顾客|等待对方|处理中|核算中|排队|已提交/;
{ const out=[]; let seen=0;
  for(const i of PG.findAllWithCriteria({types:['INSTANCE']})){ if(insideInstance(i,null)) continue; const mc=await topMain(i); if(!mc||mc.id!=='316:5196') continue; seen++;
    const lbl=texts(i).filter(t=>t.visible).map(t=>t.characters).join(' '); const cur=i.componentProperties[MTk]&&i.componentProperties[MTk].value;
    const want=NEEDS.test(lbl)?'NeedsMe':(WAIT.test(lbl)?'Waiting':null);
    if(want&&MTopt.includes(want)&&cur!==want){ i.setProperties({[MTk]:want}); out.push(`${lbl}: ${cur}→${want}`); R.touched.push(i.id); } }
  MT.description=(MT.description||'').replace(/\n?Rule \(verify-r1 4\.5\)[^]*$/,'')+'\nRule (verify-r1 4.5): colour follows who must act. NeedsMe (amber) = the merchant must act (等待商家意见, 待核验, 待回复…). Waiting (grey + clock) = someone else acts (平台审核中, 待复核, 等待玩家…). Live/Done green, Failed red, Info grey.';
  R.info['4.5 tags']={seen,changed:out}; }
for(const id of ['183:1731','183:1819']){ const F=await byId(id); if(!F) continue; const out={};
  out.dates=[]; for(const t of texts(F)){ const nv=t.characters.replace(/(\d{4})-(\d{1,2})-(\d{1,2})\s+(\d{1,2}):(\d{2})(:\d{2})?/g,(m,y,mo,d,h,mi)=>`${+mo}月${+d}日 ${h.padStart(2,'0')}:${mi}`); if(nv!==t.characters){ await setT(t,nv); out.dates.push(nv); } }
  out.blue=0; for(const n of F.findAll(n=>n.type!=='TEXT'&&n.width<=32&&n.height<=32&&!insideInstance(n,F))){ for(const prop of ['fills','strokes']){ if(!(prop in n)||!Array.isArray(n[prop])) continue; if(n[prop].some(p=>p.type==='SOLID'&&isBlue(p.color))){ n[prop]=n[prop].map(p=>p.type==='SOLID'&&isBlue(p.color)?PAINT('ink'):p); out.blue++; R.touched.push(n.id); } } }
  for(const t of texts(F).filter(t=>!insideInstance(t,F)&&solidOf(t)&&isBlue(solidOf(t)))){ t.fills=[PAINT('ink')]; out.blue++; }
  const cardOf=re=>{ const t=texts(F).find(t=>re.test(t.characters)); if(!t) return null; let p=t.parent; while(p&&p!==F&&!(solidOf(p)&&p.cornerRadius>=8&&p.width>=300)) p=p.parent; return p===F?null:p; };
  const a=cardOf(/^申请原因/), b=cardOf(/^补充凭证/);
  if(a&&b&&a!==b){ const gap=Math.round(absY(b)-(absY(a)+a.height)); out.gapBefore=gap;
    if(gap<12){ const par=b.parent; if(par===a.parent&&par.layoutMode==='VERTICAL'){ if(par.itemSpacing<12){ const sp=figma.createFrame(); sp.name='gap 12'; sp.fills=[]; par.insertChild(par.children.indexOf(b),sp); sp.resize(1,Math.max(0.01,12-par.itemSpacing)); sp.layoutSizingHorizontal='FILL'; } }
      else { const d=12-gap; for(const s of par.children) if(s!==a&&absY(s)>=absY(b)-1&&s.layoutPositioning!=='ABSOLUTE') s.y+=d; } out.gapAfter=12; } }
  FIXED(F,'4.5','Status by who must act: 等待商家意见 = NeedsMe (amber), 平台审核中 = Waiting (grey, clock); dates 11月14日 19:28; copy icon in ink; 12 pt between 申请原因 and 补充凭证 (F-05, MR-17).');
  R.info['4.5 '+id]=out; }
// ---------- 4.9 / F-06 营销 root ----------
{ const F=await byId('182:8065'); const out={};
  const first=texts(F).find(t=>/近\s?30\s?天报名/.test(t.characters)); const proto=PG.findOne(n=>n.name==='large title'&&!within(n,F));
  if(!F.findOne(n=>n.name==='large title')&&first){ let anchor=first; while(anchor.parent!==F&&!(anchor.parent.layoutMode==='VERTICAL'&&anchor.parent.height>F.height*0.5)) anchor=anchor.parent;
    const lt=proto?proto.clone():null; let node=lt;
    if(lt){ const tt=texts(lt).sort((a,b)=>b.fontSize-a.fontSize)[0]; if(tt) await setT(tt,'营销'); for(const t of texts(lt).filter(x=>x!==tt)) t.visible=false; }
    else { node=AL('HORIZONTAL','large title',{pad:[4,16,8,16]}); await TXT(node,'营销',{size:34,lh:41,w:'Bold'}); }
    const par=anchor.parent; par.insertChild(par.children.indexOf(anchor),node);
    if(par.layoutMode&&par.layoutMode!=='NONE'){ node.layoutSizingHorizontal='FILL'; } else { node.x=0; node.y=anchor.y; const h=node.height; for(const s of par.children) if(s!==node&&s.y>=anchor.y-1&&s.layoutPositioning!=='ABSOLUTE'&&!/status|tab bar|Tab Bar|home/i.test(s.name)) s.y+=h; }
    out.title=proto?'cloned large title':'built large title'; R.created.push(node.id); }
  const coupon=(()=>{ const t=texts(F).find(t=>/优惠券|券/.test(t.characters)); if(!t) return null; let p=t.parent; while(p&&p!==F&&!(solidOf(p)&&p.cornerRadius>=8&&p.width>=280)) p=p.parent; return p===F?null:p; })();
  if(coupon){ const cb={x:absX(coupon),y:absY(coupon),r:absX(coupon)+coupon.width,b:absY(coupon)+coupon.height};
    const bars=coupon.parent.children.filter(s=>s!==coupon&&texts(s).length===0&&solidOf(s)&&lum(solidOf(s))>0.55&&lum(solidOf(s))<0.93&&s.cornerRadius>0&&absX(s)<cb.r&&absX(s)+s.width>cb.x&&absY(s)<cb.b&&absY(s)+s.height>cb.y);
    out.greyBars=bars.map(s=>`${s.type} ${s.name} ${Math.round(s.width)}×${Math.round(s.height)}`); for(const s of bars){ R.removed.push(s.id); s.remove(); } }
  for(const t of texts(F).filter(t=>/→/.test(t.characters))){ await setT(t,t.characters.replace(/\s*→/,' ›')); out.arrow=t.characters; }
  FIXED(F,'4.9','营销 root: large title 营销, no grey bar behind the coupon card, 管理 › (F-06).'); R.info['4.9 营销']=out; }
function within(n,root){ let p=n; while(p){ if(p===root) return true; p=p.parent; } return false; }
R.created=R.created.length; R.touched=R.touched.length; R.ann=R.ann.length;
for(const id of ['182:7628',R.info.Q2&&R.info.Q2.errorFrame,'182:7693','183:1731','182:8065']){ if(!id) continue; const n=await byId(id); if(n) await n.screenshot({scale:0.4}); }
return R;
