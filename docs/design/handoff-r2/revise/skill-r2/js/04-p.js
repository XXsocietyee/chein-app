// Batch 1 · P · SR2-01 (俱乐部 root cards), SR2-02 (首页 rail + hotspots), SR2-24 (challenge sheet copies)
await goPage(P);
const before={};
const destOf=async id=>{ const n=await byId(id); if(!n) return null; for(const r of n.reactions||[]) for(const a of actsOf(r)) if(a&&a.destinationId) return a.destinationId; return null; };
// ---- SR2-01 ----
const fr=await byId('210:8452'); const list=await byId('291:7387');
const dHome=await destOf('211:5048'), dWelcome=await destOf('211:5052');
for(const c of [...list.children]) if(c.type==='INSTANCE'&&c.name==='Club/Default Cover'){ R.removed.push(c.id); c.remove(); }
for(const h of ['211:5048','211:5050','211:5052','211:5054','211:5056','211:5058']){ const n=await byId(h); if(n){ n.remove(); R.removed.push(h); } }
list.paddingLeft=16; list.paddingRight=16; list.paddingTop=16; list.paddingBottom=120; list.itemSpacing=12; list.counterAxisAlignItems='MIN';
const card=await byId(CARD);
const CL=[['夜上海滨江夜行队','1 名成员 · 旅行组织','下一场 · 11月22日 周六 19:30','382:1056','创建者'],['愚园路咖啡风味团','1 名成员 · 兴趣社群','','382:1060','创建者'],['沪上实景推理局','12 名成员 · 内容创作团队','下一场 · 11月23日 周日 14:00','382:1062','创建者'],['梧桐摄影漫步社','4 名成员 · 兴趣社群','','382:1064','创建者'],['武康路城市漫游会','28 名成员 · 旅行组织','下一场 · 11月29日 周六 10:00','381:990','成员'],['复旦城市探索社','56 名成员 · 校园社团','','381:990','成员'],['安福路剧场同好会','9 名成员 · 兴趣社群','','381:990','成员']];
const cards=[];
for(const [i,[nm,meta,next,thumb,role]] of CL.entries()){ const c=card.createInstance(); list.appendChild(c); c.layoutSizingHorizontal='FILL'; c.name='Club/List Card · '+nm; setProps(c,{Name:nm,Meta:meta,Next:next||' ','Show next':!!next}); try{ setProps(c,{Thumb:thumb}); }catch(e){ R.warn.push('thumb '+i); } const tag=c.findOne(n=>n.name==='role'&&n.type==='INSTANCE'); if(tag) setProps(tag,{Label:role}); if(i<4&&dHome) await go(c,dHome); else if(dWelcome) await go(c,dWelcome); cards.push(c.id); R.created.push(c.id); }
SR(fr,'SR2-01','Seven Club/List Card rows (thumbnail, name, members · type, next activity, role tag) in place of seven bare covers. Creator rows → clubhome, member rows → clubwelcome.');
// ---- SR2-02 · 首页 rail ----
const home=await byId('210:8239'); const rail=await byId('397:4788'); before.rail=tree(rail,0,3).join('\n');
const dAct=await destOf('211:5020'), dCreate=await destOf('211:5026');
for(const h of ['211:5020','211:5022','211:5026']){ const n=await byId(h); if(n){ n.remove(); R.removed.push(h); } }
rail.paddingLeft=0; rail.paddingRight=0; rail.paddingTop=0; rail.itemSpacing=12; rail.counterAxisAlignItems='MIN';
const head=rail.children[0]; if(head&&head.layoutMode&&head.layoutMode!=='NONE'){ head.layoutSizingHorizontal='FILL'; head.paddingLeft=0; head.paddingRight=0; const tt=texts(head)[0]; if(tt) await styleT(tt,'t-2'); }
const deeds=rail.findAll(n=>n.type==='INSTANCE'&&n.name==='City/Deed Card'); const scroller=deeds[0]&&deeds[0].parent; if(scroller&&scroller!==rail&&scroller.layoutMode){ scroller.itemSpacing=12; scroller.paddingLeft=0; scroller.layoutSizingHorizontal='FILL'; }
for(const d of deeds) await go(d,P_N11);
const all=texts(rail).find(t=>/^全部/.test(t.characters)); if(all){ const tgt=all.parent&&all.parent!==head&&all.parent.layoutMode?all.parent:all; await go(tgt,P_N01); }
const promo=await byId('290:20269'); if(promo&&dCreate) await go(promo,dCreate);
const near=await byId('290:20260'); let nc=0; if(near&&dAct) for(const c of near.findAll(n=>(n.type==='FRAME'||n.type==='INSTANCE')&&n.width>140&&n.width<200&&n.height>180)){ await go(c,dAct); nc++; }
R.info.rail={deeds:deeds.length,near:nc,dAct,dCreate,dHome,dWelcome};
SR(home,'SR2-02','我的地盘 rail on the page margin (title t-2, 全部 → N01), deed taps → N11; stale → act / → create1 hotspots removed; 附近活动 cards and the promo carry their own links.');
// ---- SR2-24 · challenge sheet copies ----
async function fixChal(fr){ const sheet=fr.findOne(n=>n.name==='sheet'&&n.type==='FRAME'); if(!sheet) return 'nosheet';
  const ob=sheet.findOne(n=>n.type==='INSTANCE'&&n.name==='City/Odds Bar'); const head=sheet.children.find(c=>c.name==='head'); const inset=sheet.children.find(c=>c.name==='inset');
  let rm=0; if(inset) for(const kv of [...inset.children]){ const s=texts(kv).map(t=>t.characters).join(' '); if(/难度|你的修正/.test(s)){ kv.remove(); rm++; } }
  if(ob&&head){ sheet.insertChild(sheet.children.indexOf(head)+1,ob); ob.layoutSizingHorizontal='FILL'; try{ ob.layoutSizingVertical='HUG'; }catch(e){ R.warn.push('obhug '+String(e).slice(0,60)); } }
  sheet.primaryAxisSizingMode='AUTO'; sheet.y=fr.height-sheet.height; R.touched.push(sheet.id); return 'ok rm'+rm+' h'+Math.round(sheet.height)+' ob'+(ob?Math.round(ob.height):'-'); }
R.info.chal=[]; for(const id of ['396:4610',P_N34]){ const f=await byId(id); if(f){ R.info.chal.push(id+':'+await fixChal(f)); SR(f,'SR2-24','Odds bar hugs and sits under the tags; 难度 / 你的修正 rows removed; sheet hugs.'); } }
R.info.before=before;
await shot(fr,0.45); await shot(home,0.45); await shot(await byId('396:4610'),0.45); await shot(await byId(COVER),0.6);
return R;
