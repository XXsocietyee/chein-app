// Batch 1+2a · Library 6:3 · SR2-14 (Quick Action glyph + Icon swap), SR2-24/45 (odds bar hug, modifier props, Win faces), SR2-01/45 (Club/List Card)
await goPage(LIB);
// ---- SR2-14 · Merchant/Quick Action: glyph = Icon instance (swap property), Primary glyph cta-ink on cta ----
const qa=await byId('384:1486'); const qaOut=[];
for(const v of qa.children){ const prim=/Primary/.test(v.name); const circ=v.findOne(n=>n.name==='circle'); const old=circ.findOne(n=>/^icon\//.test(n.name));
  const ic=await IC(null,'scan',24,prim?'cta-ink':'ink','icon'); const idx=old?circ.children.indexOf(old):0; circ.insertChild(Math.max(0,idx),ic); if(old) old.remove(); fillV(circ,prim?'cta':'surface'); qaOut.push(v.name+':'+ic.id); }
let qaKey=null; try{ qaKey=qa.addComponentProperty('Icon','INSTANCE_SWAP','9:29'); for(const v of qa.children){ const ic=v.findOne(n=>n.name==='icon'&&n.type==='INSTANCE'); if(ic) ic.componentPropertyReferences={mainComponent:qaKey}; } }catch(e){ R.warn.push('qa swap '+String(e).slice(0,100)); }
qa.description='Merchant quick action: a 52 pt disc with a 24 pt glyph and a 12 pt label, 72 wide. Properties: Emphasis (Default = surface disc, ink glyph; Primary = cta disc, cta-ink glyph, one per screen), Label, Icon (swap any Icon/*).\nSwiftUI: Button { } label: { VStack(spacing: 8) { Image(systemName:).font(.title3).frame(width: 52, height: 52).background(Circle().fill(primary ? Color.cta : Color.surface)); Text(label).font(.caption) } }; .buttonStyle(.plain) with the press scale 0.97. Primary glyph colour = cta-ink (≥ 3:1 on cta in both merchant modes).';
// contrast cta-ink on cta per mode
const lumC=c=>{ const L=x=>x<=0.03928?x/12.92:Math.pow((x+0.055)/1.055,2.4); return 0.2126*L(c.r)+0.7152*L(c.g)+0.0722*L(c.b); };
function valIn(v,modeName){ const c=COLS[v.variableCollectionId]; const m=c.modes.find(m=>m.name===modeName)||c.modes[0]; let val=v.valuesByMode[m.modeId], g=0; while(val&&val.type==='VARIABLE_ALIAS'&&g++<6){ const a=VI[val.id]; const ac=COLS[a.variableCollectionId]; const am=ac.modes.find(x=>x.name===modeName)||ac.modes[0]; val=a.valuesByMode[am.modeId]; } return val; }
const ctaC=COLS[V['cta'].variableCollectionId]; R.info.ctaContrast=ctaC.modes.map(m=>{ const a=valIn(V['cta'],m.name), b=valIn(V['cta-ink'],m.name); if(!a||!b||!('r' in a)||!('r' in b)) return m.name+':?'; const l1=lumC(a), l2=lumC(b); return m.name+':'+((Math.max(l1,l2)+0.05)/(Math.min(l1,l2)+0.05)).toFixed(2); }).join(' ');
// ---- SR2-24 / SR2-45 · City/Odds Bar ----
const ob=await byId('382:1120'); const obPar=ob.parent;
const tr=ob.findOne(n=>n.name==='target row'); const sp=tr.findOne(n=>n.name==='spacer');
sp.layoutSizingVertical='FIXED'; sp.resize(sp.width,1); sp.layoutGrow=1; tr.counterAxisSizingMode='AUTO'; tr.counterAxisAlignItems='CENTER';
ob.primaryAxisSizingMode='AUTO'; ob.layoutSizingVertical='HUG';
const keysOb=Object.keys(ob.componentPropertyDefinitions).map(k=>k.split('#')[0]);
if(!keysOb.includes('Modifier 1')){ tprop(ob,'Modifier 1','任务 +2','modifier label'); tprop(ob,'Modifier 2','洞察 +1','modifier label'); }
if(!keysOb.includes('Show modifiers')) bprop(ob,'Show modifiers',true,'modifiers');
R.info.oddsH=ob.height;
// Win faces variants 6 / 9 / 12 (existing) / 15
let obSet=ob.parent.type==='COMPONENT_SET'?ob.parent:null;
if(!obSet){ ob.name='Win faces=12'; const vs=[ob];
  for(const k of [6,9,15]){ const c=ob.clone(); obPar.appendChild(c); c.name='Win faces='+k; const faces=c.findOne(n=>n.name==='bar · 20 faces').children; faces.forEach((f,i)=>{ const win=i>=20-k; f.name=win?'face win':'face lose'; f.fills=[PAINT(win?'ink':'fill')]; }); vs.push(c); }
  obSet=figma.combineAsVariants(vs,obPar); obSet.name='City/Odds Bar'; fillV(obSet,'bg'); obSet.cornerRadius=16; gridSet(obSet,4); obSet.x=ob.x; R.created.push(obSet.id);
  // default texts per variant (instances override through Target / Caption)
  for(const v of obSet.children){ const k=+v.name.split('=')[1]; const tgt=v.findOne(n=>n.name==='target'), cap=v.findOne(n=>n.name==='caption'); if(tgt) await setT(tgt,'需要掷出 ≥ '+(21-k)); if(cap) await setT(cap,`20 面骰 · ${k} 个面能赢 (${k*5}%)`); } }
obSet.description='Win odds of a d20 challenge: target line, 20 faces (win faces in ink from the right), caption, two modifier chips. Properties: Win faces 6 / 9 / 12 / 15, Target, Caption, Modifier 1, Modifier 2, Show modifiers. Hugs its height (≈ 136).\nSwiftUI: HStack(spacing: 3) { ForEach(0..<20) { Capsule().fill(i >= 20 - winFaces ? Color.ink : Color.fill) } }.frame(height: 12) — one element: .accessibilityElement(children: .ignore).accessibilityLabel("胜率").accessibilityValue("20 面里 12 面能赢，百分之六十"). Not a Gauge.';
R.info.obSet=obSet.id; R.info.obVariants=obSet.children.map(v=>v.name+':'+v.id+':'+Math.round(v.height));
// ---- SR2-01 · Club/List Card ----
const csec=await byId(CKIT); let card=csec.findOne(n=>n.type==='COMPONENT'&&n.name==='Club/List Card');
if(!card){ card=figma.createComponent(); card.name='Club/List Card'; card.layoutMode='HORIZONTAL'; card.primaryAxisSizingMode='FIXED'; card.counterAxisSizingMode='AUTO'; card.resize(361,96); card.itemSpacing=12; card.counterAxisAlignItems='CENTER';
  for(const k of ['paddingTop','paddingRight','paddingBottom','paddingLeft']) card[k]=12; fillV(card,'surface'); if(V['r-md']) bindR(card,'r-md'); else card.cornerRadius=16; R.created.push(card.id);
  const cov=await byId('381:993'); const place=(cov.type==='COMPONENT_SET'?cov.children:[cov]); const pv=place.find(v=>/Place 2|武康/.test(v.name))||place[0];
  const th=pv.createInstance(); card.appendChild(th); th.name='thumb'; th.resize(72,72); th.cornerRadius=12; th.clipsContent=true;
  const col=AL('VERTICAL','text',{gap:2,align:'MIN'}); add(card,col,'FILL','HUG');
  await TX(col,'梧桐摄影漫步社','t-head','ink',{name:'name',fill:true});
  await TX(col,'4 名成员 · 兴趣社群','t-foot','ink-2',{name:'meta',fill:true});
  await TX(col,'下一场 · 11月22日 周六 14:00','t-foot','ink-3',{name:'next',fill:true});
  const tagSet=await byId(STAT_TAG); const tv=variant(tagSet,{State:'Neutral'})||tagSet.children[0]; const tag=tv.createInstance(); card.appendChild(tag); tag.name='role'; setProps(tag,{Label:'创建者'});
  tprop(card,'Name','梧桐摄影漫步社','name'); tprop(card,'Meta','4 名成员 · 兴趣社群','meta'); tprop(card,'Next','下一场 · 11月22日 周六 14:00','next'); bprop(card,'Show next',true,'next');
  try{ const k=card.addComponentProperty('Thumb','INSTANCE_SWAP',pv.id); th.componentPropertyReferences={mainComponent:k}; }catch(e){ R.warn.push('thumb swap '+String(e).slice(0,80)); }
  tag.isExposedInstance=true;
  newRow(); await placeIn(csec,card,'Club/List Card (skill-r2 SR2-01)'); }
card.description='One club in a list: 72 pt cover thumbnail (r12), name t-head 17, meta t-foot 13 ink-2, optional next-activity line, trailing role tag (创建者 / 成员 / 管理员). Fill surface, r-md 16, padding 12, gap 12, hugs its height. Properties: Name, Meta, Next, Show next, Thumb (Media/Cover or Club/Default Cover), role tag exposed.\nSwiftUI: NavigationLink(value: club) { HStack(spacing: 12) { AsyncImage(url:) { $0.resizable().scaledToFill() } placeholder: { ClubDefaultCover(type:) }.frame(width: 72, height: 72).clipShape(.rect(cornerRadius: 12, style: .continuous)); VStack(alignment: .leading, spacing: 2) { Text(name).font(.headline); Text(meta).font(.footnote).foregroundStyle(.secondary) }; Spacer(); StatusTag(role) } .padding(12).background(.surface, in: .rect(cornerRadius: 16, style: .continuous)) } — in a LazyVStack(spacing: 12), page margin 16. Thumbnail .accessibilityHidden(true).';
R.info.card=card.id; R.info.coverVariants=(await byId('381:993')).children.map(v=>v.name+':'+v.id).join(' | ');
await shot(card,1); await shot(obSet,0.75); await shot(qa,1.5);
return R;
