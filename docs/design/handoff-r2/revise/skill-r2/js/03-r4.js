// Batch 1 · R4 · SR2-14 (扫码 primary visible), SR2-15 (营销 icons + overflow)
await goPage('182:7328');
const qaSet=await byId(QA); const prim=variant(qaSet,{Emphasis:'Primary'}), def=variant(qaSet,{Emphasis:'Default'});
function qaInst(p,label,icon){ const i=(p?prim:def).createInstance(); setProps(i,{Label:label}); try{ setProps(i,{Icon:ICON_IDS[icon]}); }catch(e){ R.warn.push('icon '+label); } const g=i.findOne(n=>n.name==='icon'); if(g) R.info['glyph '+label]=bindFillDeep(g,p?'cta-ink':'ink'); R.created.push(i.id); return i; }
// workbench: local columns → kit instances
const wb=await byId('182:7328'); const row=await byId('203:37988'); R.info.rowBefore=tree(row,0,1).join(' / ');
for(const [id,label,icon,p] of [['203:37989','扫码','scan',true],['203:37998','客户','people'],['203:38006','财务','wallet'],['203:38013','更多','grid']]){ const old=await byId(id); if(!old) continue; const i=qaInst(p,label,icon); row.insertChild(row.children.indexOf(old),i); old.remove(); R.removed.push(id); }
SR(wb,'SR2-14','Quick actions are Merchant/Quick Action instances; 扫码 = Emphasis Primary (cta disc, cta-ink glyph, 18:1). Checked in Merchant-Light and Merchant-Dark by the variable values.');
// 营销: four distinct glyphs
const mk=await byId('182:8065');
for(const [id,icon] of [['404:9696','chart'],['404:9705','store'],['404:9714','route'],['404:9723','cal']]){ const i=await byId(id); if(!i) continue; try{ setProps(i,{Icon:ICON_IDS[icon]}); const g=i.findOne(n=>n.name==='icon'); if(g) bindFillDeep(g,'ink'); R.touched.push(id); }catch(e){ R.warn.push('mk '+id+': '+String(e).slice(0,60)); } }
// overflow: the frame grows to its content, tab bar + scroll edge stay fixed, 96 pt bottom inset
const coupon=await byId('203:39711'), cstack=await byId('203:39709');
if(coupon){ coupon.primaryAxisSizingMode='AUTO'; if(cstack) cstack.resize(cstack.width,coupon.y+coupon.height); R.info.couponTree=tree(coupon,0,2).join('\n'); }
const tab=await byId('203:39732'), edge=await byId('404:9766');
for(const n of [tab,edge]) if(n){ n.layoutPositioning='ABSOLUTE'; try{ n.scrollBehavior='FIXED'; }catch(e){ R.warn.push('fixed '+n.id); } }
mk.primaryAxisSizingMode='AUTO'; mk.paddingBottom=96; mk.clipsContent=true; tab.y=755; edge.y=732; tab.x=0; edge.x=0;
// keep fixed layers on top
mk.appendChild(edge); mk.appendChild(tab);
R.info.mkH=Math.round(mk.height);
SR(mk,'SR2-15','Icons 店铺参谋 chart · 店铺装修 store · 发主题 route · 发活动 cal. Frame grows to its content (scrolls in the prototype); tab bar and scroll edge are fixed; 96 pt bottom inset.');
// same fixed treatment on the workbench
{ const t2=await byId('203:38088'), e2=await byId('404:9765'); for(const n of [t2,e2]) if(n){ n.layoutPositioning='ABSOLUTE'; try{ n.scrollBehavior='FIXED'; }catch(e){} } }
await shot(wb,0.6); await shot(mk,0.45);
return R;
