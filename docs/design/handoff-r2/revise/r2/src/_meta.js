// shared: 4.2 Theme Card meta line on instances (component fixed in 01-lib; here: overrides that still double the words)
async function metaFix(frameIds){ const out=[];
  for(const fid of frameIds){ const F=await byId(fid); if(!F){ out.push(fid+' missing'); continue; }
    for(const i of F.findAllWithCriteria({types:['INSTANCE']})){ const mc=await topMain(i); if(!mc||mc.id!=='287:43163') continue;
      for(const m of i.findAll(n=>/meta/i.test(n.name)&&n.type!=='TEXT')){ const ts=texts(m).filter(t=>t.visible); const before=ts.map(t=>t.characters).join('|'); const seen={}; let fixed=0;
        for(const t of ts){ if(/glyph|icon/i.test(t.name)&&t.id.includes(';')){ const mn=await byId(t.id.split(';').pop()); if(mn&&mn.type==='TEXT'&&mn.characters!==t.characters){ let pp=t.parent, lab=null; while(pp&&pp!==m&&!lab){ lab=pp.children&&pp.children.find(c=>c.type==='TEXT'&&c!==t&&c.name==='label'); pp=pp.parent; } if(lab) await setT(lab,t.characters); await setT(t,mn.characters); fixed++; continue; } } if(t.name==='label') continue; const k=t.characters.trim(); const par=t.parent.id; const key=par+'|'+k; if(seen[key]){ t.visible=false; fixed++; R.touched.push(t.id); } else seen[key]=1;
          const dbl=k.match(/^(.{2,6})\1$/); if(dbl){ await setT(t,dbl[1]); fixed++; } }
        out.push({frame:fid,inst:i.id,meta:m.name,before,after:texts(m).filter(t=>t.visible).map(t=>t.characters).join('|'),fixed}); } } }
  R.info['4.2 instances']=out; }
