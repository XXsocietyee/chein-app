const PH={'武康大楼':['382:1055','382:1056'],'梧桐书店':['382:1063','382:1064'],'老麦咖啡馆':['435:4517','435:4518']};
const NOPH=['453:1395','453:1404'];
async function fixDeeds(root){ let fixed=0, nophoto=[], kept=0;
  const all=root.findAllWithCriteria({types:['INSTANCE']}).filter(d=>{ try{ const m=d.mainComponent; return m&&m.parent&&m.parent.id==='381:1401'; }catch(e){ return false; } });
  for(const d of all){ if(d.removed) continue; const mc=d.mainComponent; if(!mc||!mc.parent||mc.parent.id!=='381:1401') continue;
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
