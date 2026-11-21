// 05-R1 · page R1 · 4.2 (twins 166:2557, 166:2866 meta line), 4.9 (169:6954 + twin 169:7170 top scrim), Q8 (169:4417, 169:4536 ¥560.00),
// Q9 (166:2557 header check), 5.8 (PL-40: motion notes → native Interaction annotations + motion rows on every screen frame).
const PG=await goPage('169:6954');
await metaFix(['166:2557','166:2866']);
R.info['4.9']=[await scrim('169:6954'),await scrim('169:7170')];
{ const out=[]; for(const id of ['169:4417','169:4536']){ const F=await byId(id); if(!F) continue; for(const t of texts(F)) if(/^[¥￥]?\s?560(\.00)?$/.test(t.characters.trim())){ out.push(id+':'+t.characters); if(await setT(t,'¥560.00')) OWNER(F,'Q8','账户余额 is real money: shown as ¥560.00 (two decimals, ¥ mark), beside 积分 820.'); } } R.info.Q8=out; }
{ const F=await byId('166:2557'); const H=F&&F.findAllWithCriteria({types:['INSTANCE']}).find(i=>/Root Header/.test(i.name)); R.info.Q9=H?Object.fromEntries(Object.entries(H.componentProperties).map(([k,v])=>[k.split('#')[0],v.value])):'no Root Header'; }
// 5.5 PL-10: the old-kit twins have no button components — their buttons are raw rounded frames with one label. Swap those to Player/Button.
{ const FR=['169:3833','169:4120','169:6068','169:6155','169:9621','169:9760','169:9899','169:9973']; const PB=await byId('285:20238'); const done=[];
  for(const fid of FR){ const F=await byId(fid); if(!F) continue;
    const cands=F.findAll(n=>(n.type==='FRAME'||n.type==='INSTANCE')&&!insideInstance(n,F)&&n!==F&&n.height>=28&&n.height<=56&&n.width<=361&&n.cornerRadius>=6&&(solidOf(n)||(n.strokes&&n.strokes.length))&&texts(n).filter(t=>t.visible&&t.characters.trim()).length===1&&texts(n)[0].characters.trim().length<=8&&/报名|取消|查看|去|开始|加入|分享|收藏|关注|提交|完成|重试|确认|领取|兑换|购买|支付|下载|编辑|删除|邀请|导航|评价|签到|申请|预约|进入|打开|使用|立即|继续|返回|复制|保存|发布/.test(texts(n)[0].characters)&&!/Chip|Tag|tag|chip|badge|Nav|Logo|avatar|头像/i.test(n.name));
    for(const n of cands){ if(n.removed) continue; if(n.type==='INSTANCE'){ const mc=await topMain(n); if(mc&&/^(Player|Icon|Club|Editor|Merchant|MP\/Chip|MP\/Nav|MP\/Logo|System)/.test(mc.name)) continue; }
      const c=solidOf(n); const kind=c&&lum(c)>0.6?'Primary':(c?'Secondary':'Text'); const label=texts(n).find(t=>t.characters.trim()).characters.trim();
      const v=variant(PB,{Kind:kind,Size:n.height>=50?'52':'44',State:'Default'}); const i=v.createInstance(); i.setProperties({[keyOf(PB,'Label')]:label}); i.name='Player/Button'; const w=n.width; replaceAt(n,i,{keepW:w>=150}); R.created.push(i.id); done.push(fid+' '+label+' → '+kind); }
    FIXED(F,'5.5','Raw buttons → Player/Button (PL-10). MP/Chip filter chips stay: the player kit has no filter chip; they match its height (32) and neutral fill.'); }
  R.info['5.5']=done; }
// 5.6 follow-up (PL-33): in the bottom bar the check row comes first, 评价 (primary) fills the rest
for(const id of ['228:5109','228:5712','228:5849']){ const F=await byId(id); const row=F.findOne(n=>n.name==='已核销 · check row'); const btn=row&&row.parent.children.find(c=>c.name==='Player/Button'); if(row&&btn&&row.parent.layoutMode==='HORIZONTAL'){ const par=row.parent; par.insertChild(0,row); row.layoutSizingHorizontal='HUG'; btn.layoutSizingHorizontal='FILL'; R.touched.push(par.id); } }
await motionPass('PL-40');
R.created=R.created.length; R.touched=R.touched.length; R.ann=R.ann.length;
for(const [id,sc] of [['169:6954',0.4],['228:5109',0.4],['169:6155',0.3]]){ const n=await byId(id); if(n) await n.screenshot({scale:sc}); }
return R;
