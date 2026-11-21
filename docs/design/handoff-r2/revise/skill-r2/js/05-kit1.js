// Batch 2a · Library · SR2-42 (Deed Card properties, District modes, Size=Sheet, Mini type, band labels), SR2-33 (ink-3, band contrast), SR2-31 (map tones), SR2-32 (me → white), SR2-24 fix (odds faces + defaults), SR2-14 (Primary glyph)
await goPage(LIB);
{ const seen=new Set(); for(const t of figma.currentPage.findAllWithCriteria({types:['TEXT']})){ let fs; try{ fs=t.getRangeAllFontNames(0,t.characters.length); }catch(e){ continue; } for(const f of fs){ const k=f.family+'|'+f.style; if(!seen.has(k)){ seen.add(k); try{ await figma.loadFontAsync(f); }catch(e){} } } } R.info.fonts=seen.size; }
{ const all=await figma.listAvailableFontsAsync(); let n=0; for(const f of all){ if(/^(Noto Sans (JP|SC|TC|CJK.*)|Noto Sans|PingFang SC|Inter)$/.test(f.fontName.family)){ try{ await figma.loadFontAsync(f.fontName); n++; }catch(e){} } } R.info.fontsLoaded=n; }
const hex=h=>{ h=h.replace('#',''); return {r:parseInt(h.slice(0,2),16)/255,g:parseInt(h.slice(2,4),16)/255,b:parseInt(h.slice(4,6),16)/255,a:1}; };
const colC=COLS[V['ink'].variableCollectionId]; const dark=colC.modes.filter(m=>/Dark|^Game$/.test(m.name)); const light=colC.modes.filter(m=>!dark.includes(m));
// ---- tokens ----
for(const m of dark){ V['map-road'].setValueForMode(m.modeId,hex('3A3F46')); V['map-water'].setValueForMode(m.modeId,hex('12304A')); V['map-park'].setValueForMode(m.modeId,hex('1B3324')); V['ink-3'].setValueForMode(m.modeId,hex('8E8E93')); }
let major=V['map-road-major']; if(!major){ major=figma.variables.createVariable('map-road-major',colC,'COLOR'); major.scopes=['FRAME_FILL','SHAPE_FILL','STROKE_COLOR']; for(const m of colC.modes) major.setValueForMode(m.modeId,dark.includes(m)?hex('454B53'):V['map-road'].valuesByMode[m.modeId]); V['map-road-major']=major; R.created.push(major.id); }
for(const m of colC.modes) V['me'].setValueForMode(m.modeId,{type:'VARIABLE_ALIAS',id:V['cta'].id});
V['me'].description='Mine = white (alias of cta): the same white as the primary button means "you". Owner default (skill-r2 Q1).';
// District collection: one band variable, six modes
let dcol=Object.values(COLS).find(c=>c.name==='District');
if(!dcol){ dcol=figma.variables.createVariableCollection('District'); dcol.renameMode(dcol.modes[0].modeId,'1'); for(const k of [2,3,4,5,6]) dcol.addMode(String(k)); R.created.push(dcol.id); }
const DM={}; for(const m of dcol.modes) DM[m.name]=m.modeId;
let band=Object.values(V).find(v=>v.name==='deed/band'&&v.variableCollectionId===dcol.id), soft=Object.values(V).find(v=>v.name==='deed/soft'&&v.variableCollectionId===dcol.id);
if(!band){ band=figma.variables.createVariable('deed/band',dcol,'COLOR'); band.scopes=['FRAME_FILL','SHAPE_FILL','STROKE_COLOR']; soft=figma.variables.createVariable('deed/soft',dcol,'COLOR'); soft.scopes=['FRAME_FILL','SHAPE_FILL'];
  for(let k=1;k<=6;k++){ band.setValueForMode(DM[String(k)],{type:'VARIABLE_ALIAS',id:V['district/'+k].id}); soft.setValueForMode(DM[String(k)],{type:'VARIABLE_ALIAS',id:V['district/'+k+'-soft'].id}); }
  band.setVariableCodeSyntax('iOS','Color.district(n)'); R.created.push(band.id,soft.id); }
dcol.hiddenFromPublishing=false;
const bandPaint=()=>figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:0.31,g:0.53,b:0.92}},'color',band);
// ---- City/Level Pips ----
const deedSet=await byId(DEED); const dsec=deedSet.parent;
let pipSet=dsec.findOne(n=>n.type==='COMPONENT_SET'&&n.name==='City/Level Pips');
if(!pipSet){ const ps=[]; for(const lv of [0,1,2]){ const c=figma.createComponent(); c.name='Level='+lv; c.layoutMode='HORIZONTAL'; c.primaryAxisSizingMode='AUTO'; c.counterAxisSizingMode='AUTO'; c.itemSpacing=4; c.counterAxisAlignItems='CENTER'; c.fills=[];
    for(let i=0;i<2;i++){ const e=figma.createEllipse(); e.resize(8,8); e.name=i<lv?'pip on':'pip off'; e.fills=[PAINT(i<lv?'ink':'sep-strong')]; c.appendChild(e); } ps.push(c); R.created.push(c.id); }
  pipSet=figma.combineAsVariants(ps,dsec); pipSet.name='City/Level Pips'; fillV(pipSet,'bg'); pipSet.cornerRadius=8; gridSet(pipSet,3,16,12); pipSet.x=deedSet.x; pipSet.y=deedSet.y-pipSet.height-40;
  pipSet.description='Deed level as two pips: Lv 0 = ○○ (插旗), Lv 1 = ●○ (前哨), Lv 2 = ●● (据点). The level name sits beside it.\nSwiftUI: HStack(spacing: 4) { ForEach(0..<2) { Circle().fill(i < level ? Color.ink : Color.sepStrong).frame(width: 8, height: 8) } }.accessibilityHidden(true) (the level name carries it).'; R.created.push(pipSet.id); }
const pip2=variant(pipSet,{Level:'2'});
// ---- Deed Card ----
const defs=deedSet.componentPropertyDefinitions; const has=n=>Object.keys(defs).some(k=>k.split('#')[0]===n);
const st=v=>v.name.match(/State=([^,]+)/)[1], sz=v=>v.name.match(/Size=([^,]+)/)[1];
// normalise caption + holder texts so one property can drive them
for(const v of deedSet.children){ for(const t of v.findAll(n=>n.type==='TEXT')){ if(t.name==='rent caption') await setT(t,'每次到访'); if(t.name==='holder') await setT(t,'你持有 · 第 3 天'); if(t.name==='deed no') await setT(t,'地契 · No. 12'); if(t.name==='district'&&sz(v)!=='Full') await setT(t,'武康路街区'); if(t.name==='level'&&sz(v)==='Row') await setT(t,'Lv 2 · 插旗'); } }
const keyOfD=n=>Object.keys(deedSet.componentPropertyDefinitions).find(k=>k.split('#')[0]===n);
function bindTxt(name,nodeNames,filter){ let key=keyOfD(name); if(!key){ const first=deedSet.children.flatMap(v=>v.findAll(n=>n.type==='TEXT'&&nodeNames.includes(n.name)))[0]; key=deedSet.addComponentProperty(name,'TEXT',first?first.characters:name); }
  let c=0; for(const v of deedSet.children){ if(filter&&!filter(v)) continue; for(const t of v.findAll(n=>n.type==='TEXT'&&nodeNames.includes(n.name))){ t.componentPropertyReferences={...(t.componentPropertyReferences||{}),characters:key}; c++; } } return c; }
R.info.bind={街区:bindTxt('街区',['district']),等级:bindTxt('等级',['level'],v=>sz(v)!=='Mini'),编号:bindTxt('编号',['deed no']),租金说明:bindTxt('租金说明',['rent caption']),持有:bindTxt('持有',['holder'])};
try{ deedSet.editComponentProperty(keyOfD('等级'),{defaultValue:'据点 Lv2'}); deedSet.editComponentProperty(keyOfD('租金'),{defaultValue:'+12'}); }catch(e){ R.warn.push('defaults '+String(e).slice(0,80)); }
// Photo swap
let photoKey=keyOfD('Photo'); if(!photoKey){ try{ photoKey=deedSet.addComponentProperty('Photo','INSTANCE_SWAP','382:1055'); }catch(e){ R.warn.push('photo prop '+String(e).slice(0,80)); } }
let showHolderKey=keyOfD('Show holder'); if(!showHolderKey) showHolderKey=deedSet.addComponentProperty('Show holder','BOOLEAN',true);
let showCoinKey=keyOfD('Show coin'); if(!showCoinKey) showCoinKey=deedSet.addComponentProperty('Show coin','BOOLEAN',true);
for(const v of deedSet.children){ const S=st(v), Z=sz(v);
  const ph=v.findOne(n=>n.name==='photo'&&n.type==='INSTANCE'); if(ph&&photoKey) ph.componentPropertyReferences={mainComponent:photoKey};
  const bands=v.findAll(n=>n.name==='band'); for(const b of bands){ b.fills=S==='Unlit'?[PAINT('surface-3')]:[bandPaint()]; for(const t of texts(b)) t.fills=[PAINT(S==='Unlit'?'ink-2':'ink-inv')]; }
  for(const d of v.findAll(n=>n.name==='district dot')) d.fills=S==='Unlit'?[PAINT('ink-3')]:[bandPaint()];
  const no=v.findOne(n=>n.name==='deed no'); if(no&&S==='Unlit') no.visible=false;
  for(const sp of v.findAll(n=>n.name==='spacer'&&n.type==='FRAME')){ if(sp.parent.layoutMode==='HORIZONTAL'){ sp.layoutSizingVertical='FIXED'; sp.resize(sp.width,1); sp.layoutGrow=1; } }
  const holder=v.findOne(n=>n.name==='holder'&&n.type==='FRAME'); if(holder){ holder.counterAxisSizingMode='AUTO'; holder.componentPropertyReferences={visible:showHolderKey}; const av=holder.findOne(n=>n.name==='avatar'); if(av){ av.fills=[PAINT('me')]; for(const t of texts(av)) t.fills=[PAINT('ink-inv')]; } }
  for(const coin of v.findAll(n=>n.name==='coin'&&n.type==='FRAME')) coin.componentPropertyReferences={visible:showCoinKey};
  const pips=v.findOne(n=>n.name==='pips'&&n.type==='FRAME'); if(pips){ const pi=pip2.createInstance(); pips.parent.insertChild(pips.parent.children.indexOf(pips),pi); pi.name='pips'; pips.remove(); pi.isExposedInstance=true; }
  if(Z==='Full'){ const body=v.findOne(n=>n.name==='body'); if(body){ body.primaryAxisSizingMode='AUTO'; body.paddingBottom=Math.max(body.paddingBottom,16); } v.primaryAxisSizingMode='AUTO'; try{ v.minHeight=380; }catch(e){} }
  if(Z==='Mini'){ const bt=texts(v.findOne(n=>n.name==='band'))[0]; if(bt){ await styleT(bt,'t-cap2'); bt.fontName={family:'SF Pro',style:'Semibold'}; } const nm=v.findOne(n=>n.name==='name'); if(nm){ await styleT(nm,'t-foot'); nm.fontName={family:'SF Pro',style:'Semibold'}; } const rt=v.findOne(n=>n.name==='rent'&&n.type==='TEXT'); if(rt) await styleT(rt,'t-cap'); const coin=v.findOne(n=>n.name==='coin'); if(coin){ coin.resize(14,14); const g=texts(coin)[0]; if(g){ g.fontSize=9; } } v.primaryAxisSizingMode='AUTO'; const body=v.findOne(n=>n.name==='body'); if(body) body.primaryAxisSizingMode='AUTO'; }
  for(const t of v.findAll(n=>n.type==='TEXT'&&!n.textStyleId&&n.name!=='coin glyph')){ const s=t.fontSize===22?'t-2':t.fontSize===17?'t-head':t.fontSize===13?'t-foot':t.fontSize===12?'t-cap':null; if(s){ const fl=t.fills; await styleT(t,s); t.fills=fl; } }
}
// Size=Sheet (329 × hug ≈ 176): band 32, photo 88, name t-2 + pips, rent row
const sheets=deedSet.children.filter(v=>sz(v)==='Sheet');
if(!sheets.length){ for(const v of deedSet.children.filter(v=>sz(v)==='Full')){ const c=v.clone(); deedSet.appendChild(c); c.name=v.name.replace('Size=Full','Size=Sheet'); try{ c.minHeight=null; }catch(e){}
    const b=c.findOne(n=>n.name==='band'); if(b) b.resize(b.width,32); const ph=c.findOne(n=>n.name==='photo'); if(ph) ph.resize(329,88);
    const h=c.findOne(n=>n.name==='holder'&&n.type==='FRAME'); if(h) h.visible=false; for(const sp of c.findAll(n=>n.name==='spacer'&&n.parent&&n.parent.name==='body')) sp.visible=false;
    const nm=c.findOne(n=>n.name==='name'); const lvl=c.findOne(n=>n.name==='level'&&n.type==='FRAME');
    if(nm&&lvl){ const row=figma.createAutoLayout('HORIZONTAL'); row.name='title row'; row.fills=[]; row.itemSpacing=8; row.counterAxisAlignItems='CENTER'; nm.parent.insertChild(nm.parent.children.indexOf(nm),row); row.layoutSizingHorizontal='FILL'; row.appendChild(nm); row.appendChild(lvl); nm.layoutGrow=1; lvl.layoutSizingHorizontal='HUG'; }
    const body=c.findOne(n=>n.name==='body'); if(body){ body.paddingTop=12; body.paddingBottom=12; body.itemSpacing=6; }
    R.created.push(c.id); } }
gridSet(deedSet,7,24,32);
deedSet.description=`The deed (地契): the game's one signature object. Variants Size = Full (329 × hug, min 380) / Sheet (329 × ≈176, the property sheet at its 420 pt detent) / Row (361 × 72) / Mini (96 × hug) × State = Mine / Other / Protected / Challengeable / Claimable / Weathered / Unlit (neutral band, no number).
Properties: 名称, 街区, 等级 (插旗 Lv0 / 前哨 Lv1 / 据点 Lv2), 编号 (地契 · No. 12, real serial per district — Owner default skill-r2 Q10), 租金, 租金说明 (Row trailing: Rent "每次到访" · Today "今天 · 每次 +12" · Price "圈地价"), 持有, Show holder, Show coin, Photo (Media/Cover). Nested exposed: pips (City/Level Pips Level 0/1/2). District colour = variable mode: set the "District" collection mode (1…6) on the instance; band, dot and outline read deed/band. Band labels ink-inv (5.6–8.6:1 on the six bands).
SwiftUI: struct DeedCard: View { let deed: Deed; var size: Size /* .full .sheet .row .mini */ } — RoundedRectangle(cornerRadius: 20, style: .continuous); band = Color.district(deed.district) (asset-catalog colour per district) with .foregroundStyle(.black) labels; photo AsyncImage(url:) { $0.resizable().aspectRatio(16/9, contentMode: .fill) }.clipped(); outline states StrokeStyle(lineWidth: 1, dash: [4, 4]). One accessibility element: .accessibilityElement(children: .combine) reading "老麦咖啡馆，武康路街区，插旗 0 级，每次到访 12 积分，你持有". @ScaledMetric for the band height. Hero: .matchedTransitionSource(id:in:) on the card, .navigationTransition(.zoom(sourceID:in:)) on the detail. Text grows with Dynamic Type: rows hug, the card grows.`;
// ---- Odds bar: faces + defaults ----
const ob=await byId(ODDS); const v12=variant(ob,{'Win faces':'12'}); const fl=v12.findOne(n=>n.name==='face lose').fills, fw=v12.findOne(n=>n.name==='face win').fills;
for(const v of ob.children){ const k=+v.name.split('=')[1]; const faces=v.findOne(n=>n.name==='bar · 20 faces').children; faces.forEach((f,i)=>{ const win=i>=20-k; f.name=win?'face win':'face lose'; f.fills=win?fw:fl; }); }
const oKey=n=>Object.keys(ob.componentPropertyDefinitions).find(k=>k.split('#')[0]===n);
try{ ob.editComponentProperty(oKey('Target'),{defaultValue:'需要掷出 ≥ 9'}); ob.editComponentProperty(oKey('Caption'),{defaultValue:'20 面骰 · 12 个面能赢 (60%)'}); }catch(e){ R.warn.push('ob defaults '+String(e).slice(0,80)); }
// ---- Quick Action Primary glyph ----
const qa=await byId(QA); const qp=variant(qa,{Emphasis:'Primary'}); const circ=qp.findOne(n=>n.name==='circle'); R.info.qaTree=tree(circ,0,4).join('\n');
R.info.qaGlyph=bindFillDeep(circ,'cta-ink'); fillV(circ,'cta');
// contrast check: ink-inv on the six bands (Player-Dark)
const lumC=c=>{ const L=x=>x<=0.03928?x/12.92:Math.pow((x+0.055)/1.055,2.4); return 0.2126*L(c.r)+0.7152*L(c.g)+0.0722*L(c.b); };
const pd=colC.modes[0].modeId; const inv=V['ink-inv'].valuesByMode[pd]; R.info.bandContrast=[1,2,3,4,5,6].map(k=>{ let c=V['district/'+k].valuesByMode[pd]; if(c.type==='VARIABLE_ALIAS') c=VI[c.id].valuesByMode[pd]; const a=lumC(c), b=lumC(inv); return k+':'+((Math.max(a,b)+0.05)/(Math.min(a,b)+0.05)).toFixed(2); }).join(' ');
R.info.deedVariants=deedSet.children.length; R.info.deedProps=Object.keys(deedSet.componentPropertyDefinitions).map(k=>k.split('#')[0]).join(',');
await shot(deedSet,0.5); await shot(ob,0.6); await shot(qa,1);
return R;
