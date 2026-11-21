const page=await figma.getNodeByIdAsync(PAGEID); await figma.setCurrentPageAsync(page);
const isNew=n=>+n.id.split(':')[0]>=217;
const KITS={'217:4511':'AB/State','217:4574':'AB/Skel','217:8259':'AB/IE','217:8268':'AB/Strip','217:8272':'AB/Banner','217:8315':'AB/Alert','217:8316':'AB/SheetHdr','217:8336':'AB/Result','217:8351':'AB/Opt','217:8352':'AB/QR','219:5570':'DEF/State','219:5645':'DEF/Skel','219:5668':'DEF/Alert','86:80':'MP/State','86:22':'MP/Sheet','86:39':'MP/Modal'};
const BAD=/E2E|smoke|烟测|undefined|\bnull\b|NaN|#\d{4,}|1390000000\d|^Title$|^Label$|^Button$|Lorem|RW TEST|\{\{/;
const res={page:page.name,newFrames:0,small:[],bad:[],overlap:[],nolabel:[],notW393:[],kits:{},frameKits:{}};
for(const s of page.children.filter(n=>n.type==='SECTION')){
 const fr=s.children.filter(c=>c.type==='FRAME');
 for(let i=0;i<fr.length;i++) for(let j=i+1;j<fr.length;j++){const a=fr[i],b=fr[j]; if(a.x<b.x+b.width&&b.x<a.x+a.width&&a.y<b.y+b.height&&b.y<a.y+a.height) res.overlap.push(a.name+' × '+b.name+' @'+s.name.slice(0,12));}
 const labels=s.children.filter(c=>c.type==='TEXT');
 for(const f of fr){ if(!isNew(f)) continue; res.newFrames++;
  if(Math.round(f.width)!==393) res.notW393.push(f.id+' '+f.name+' '+Math.round(f.width));
  if(!labels.some(l=>Math.abs(l.x-f.x)<2&&l.y<f.y&&l.y>f.y-40)) res.nolabel.push(f.id+' '+f.name);
  for(const t of f.findAllWithCriteria({types:['TEXT']})){ if(!t.visible) continue; let fs=t.fontSize; if(fs===figma.mixed){ fs=Math.min(...t.getStyledTextSegments(['fontSize']).map(x=>x.fontSize)); } if(fs<11) res.small.push(`${f.id} ${f.name} | ${t.characters.slice(0,16)} ${fs}`); if(BAD.test(t.characters)) res.bad.push(`${f.id} ${f.name} | ${t.characters.slice(0,30)}`); }
  const used=new Set(); for(const i of f.findAllWithCriteria({types:['INSTANCE']})){ const mc=i.mainComponent; if(!mc) continue; const key=(mc.parent&&mc.parent.type==='COMPONENT_SET')?mc.parent.id:mc.id; if(KITS[key]){used.add(KITS[key]); res.kits[KITS[key]]=(res.kits[KITS[key]]||0)+1;} }
  if(used.size) res.frameKits[[...used].sort().join('+')]=(res.frameKits[[...used].sort().join('+')]||0)+1;
 }}
res.small=res.small.slice(0,40); res.bad=res.bad.slice(0,40); res.smallN=res.small.length; 
return res;
