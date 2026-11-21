// P · sync the roam hold state 397:4607 with the new root; home rail deeds on the cast
await goPage(P);
{ const all=await figma.listAvailableFontsAsync(); for(const f of all){ if(/^(Noto Sans (JP|SC)|PingFang SC|Inter)$/.test(f.fontName.family)){ try{ await figma.loadFontAsync(f.fontName); }catch(e){} } } }
const B=async(name,fn)=>{ try{ await fn(); R.info[name]=R.info[name]||'ok'; }catch(e){ R.warn.push(name+': '+String(e).slice(0,160)); } };
await B('hold',async()=>{ const old=await byId('397:4607'), src=await byId('210:8322'); if(!old||!src) return; const nc=src.clone(); old.parent.appendChild(nc); nc.x=old.x; nc.y=old.y; nc.name=old.name;
  for(const n of nc.findAll(x=>'reactions' in x&&x.reactions&&x.reactions.length)) await n.setReactionsAsync([]); if(old.reactions&&old.reactions.length) await nc.setReactionsAsync(old.reactions.map(r=>({trigger:r.trigger,actions:actsOf(r)})));
  const hs=nc.findAll(n=>n.type==='INSTANCE'&&/Hold Button/.test(n.name)||(n.type==='INSTANCE'&&n.width>=360&&n.height===60)); for(const h of hs){ try{ setProps(h,{State:'Holding',Label:'松手取消'}); }catch(e){} }
  for(const h of old.children.filter(k=>/^⌖/.test(k.name))) nc.appendChild(h);
  const map={}; map[old.id]=nc.id; R.info.relinked=await relink(map); old.remove(); R.info.hold=nc.id; R.info.holdBtns=hs.length;
  ANN(nc,'**skill-r2 SR2-03 / SR2-10** · Hold state of the 漫游 root: same layout, Player/Hold Button State=Holding (ring trims 0 → 1 over 0.8 s, label 松手取消).','I'); });
await B('rail',async()=>{ const rail=await byId('397:4788'); const ds=rail.findAll(n=>n.type==='INSTANCE'&&n.name==='City/Deed Card'); const C=[{名称:'武康大楼',街区:'武康路街区',等级:'据点 Lv2',d:'1',ph:'382:1055'},{名称:'安福路 12 号',街区:'安福路街区',等级:'前哨 Lv1',d:'2'},{名称:'老麦咖啡馆',街区:'武康路街区',等级:'插旗 Lv0',d:'1',ph:'435:4517'}]; const dcol=(await figma.variables.getLocalVariableCollectionsAsync()).find(c=>c.name==='District');
  ds.slice(0,3).forEach((d,i)=>{ const c=C[i]; try{ setProps(d,{名称:c.名称,街区:c.街区,等级:c.等级}); if(c.ph) setProps(d,{Photo:c.ph}); const m=dcol.modes.find(m=>m.name===c.d); d.setExplicitVariableModeForCollection(dcol,m.modeId); }catch(e){ R.warn.push('rail '+String(e).slice(0,60)); } }); R.info.rail=ds.length; });
await shot(await byId(R.info.hold||'210:8322'),0.4); await shot(await byId('210:8239'),0.4);
return R;
