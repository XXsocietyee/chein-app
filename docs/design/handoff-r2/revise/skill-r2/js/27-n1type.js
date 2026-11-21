// SR2-41 · N1 captions that carry an actionable number → t-sub 15; bind the remaining loose text
await goPage(N1);
{ const all=await figma.listAvailableFontsAsync(); for(const f of all){ if(/^(Noto Sans (JP|SC)|PingFang SC|Inter)$/.test(f.fontName.family)){ try{ await figma.loadFontAsync(f.fontName); }catch(e){} } } }
const pg=figma.currentPage; const byIdS={}; for(const s of Object.values(TS)) byIdS[s.id]=s.name;
const size=s=>s>=34?'t-large':s>=28?'t-1':s>=22?'t-2':s>=20?'t-3':s>=17?'t-head':s>=16?'t-callout':s>=15?'t-sub':s>=13?'t-foot':s>=12?'t-cap':'t-cap2';
const ACT=/(\d|＋|\+).*(积分|每次|到访|保护|距离|m\b|km|分钟|小时|天|次|级|Lv|%|面)|(积分|每次|到访|保护|距离|分钟|小时|天|次|级|Lv|%|面).*\d/;
let loose=0, up=0, e=0;
for(const t of pg.findAllWithCriteria({types:['TEXT']})){ if(t.id.includes(';')||typeof t.fontSize!=='number') continue; let s=t.parent, inst=false, sec=null; while(s&&s.type!=='PAGE'){ if(s.type==='INSTANCE') inst=true; if(s.type==='SECTION'&&!sec) sec=s; s=s.parent; } if(inst) continue; if(t.parent&&t.parent.type==='SECTION') continue; if(sec&&(sec.id==='204:7912'||sec.id==='208:2662')) continue;
  const cur=t.textStyleId&&typeof t.textStyleId==='string'?byIdS[t.textStyleId]:null; let to=null;
  if(!t.textStyleId) { to=size(t.fontSize); loose++; }
  else if(cur==='t-foot'&&ACT.test(t.characters)&&t.characters.length<=40) { to='t-sub'; up++; }
  if(!to) continue; try{ const fl=t.fills; await styleT(t,to); if(fl!==figma.mixed) t.fills=fl; }catch(err){ e++; } }
R.info.type=`loose ${loose} · actionable captions 13 → 15: ${up} · skipped ${e}`;
let tot=0, small=0; for(const t of pg.findAllWithCriteria({types:['TEXT']})){ if(t.id.includes(';')||typeof t.fontSize!=='number') continue; if(t.parent&&t.parent.type==='SECTION') continue; let s=t.parent; while(s&&s.type!=='SECTION'&&s.type!=='PAGE') s=s.parent; if(s&&(s.id==='204:7912')) continue; tot++; if(t.fontSize<=14) small++; } R.info.after=`≤14 pt ${small}/${tot} (${Math.round(small*100/tot)}%)`;
await shot(await byId('204:23542'),0.4); await shot(await byId('205:8376'),0.4);
return R;
