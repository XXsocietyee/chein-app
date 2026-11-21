// Batch 1 · N1 · SR2-23 (N46/N50 names + bases), SR2-24 (N34 odds bar), SR2-37 (N66), SR2-36 (N28/N33), SR2-38 (N50 link, stray labels)
await goPage(N1);
const before={};
// ---- SR2-23 · 我的地盘: one cast (skill-r2 SR2-25) ----
const CAST=[{名称:'武康大楼',等级:'据点 Lv2'},{名称:'老麦咖啡馆',等级:'插旗 Lv0'},{名称:'安福路 12 号',等级:'前哨 Lv1'}];
for(const fid of ['205:8376','205:8786']){ const f=await byId(fid); const deeds=f.findAll(n=>n.type==='INSTANCE'&&n.name==='City/Deed Card'); deeds.slice(0,3).forEach((d,i)=>{ try{ setProps(d,CAST[i]); R.touched.push(d.id); }catch(e){ R.warn.push('deed '+d.id+': '+String(e).slice(0,80)); } }); }
const n46=await byId('205:8376'); SR(n46,'SR2-23','Place names restored (武康大楼 · 据点 Lv2, 老麦咖啡馆 · 插旗 Lv0, 安福路 12 号 · 前哨 Lv1, weathered) — one cast with SR2-25. N47, N48, N49, N51 now open over this list.');
// re-clone N46 content as the base of N47, N48, N49, N51 (and N50)
const src=n46.findOne(n=>n.name==='content'&&n.parent===n46); const nav46=n46.findOne(n=>n.name==='nav'&&n.parent===n46);
R.info.base=[];
for(const fid of ['205:8475','205:8580','205:8686','205:8786','205:8866']){ const f=await byId(fid); if(!f) continue; for(const [nm,s] of [['content',src],['nav',nav46]]){ const old=f.children.find(c=>c.name===nm); if(!old||!s){ R.info.base.push(fid+':no '+nm); continue; } const c=s.clone(); const idx=f.children.indexOf(old); f.insertChild(idx,c); c.x=old.x; c.y=old.y; old.remove(); R.info.base.push(fid+':'+nm+'→'+c.id); } }
// N50 text link
{ const f=await byId('205:8786'); const links=f.findAll(n=>n.type==='INSTANCE'&&n.name==='Player/Button'); for(const b of links){ const p=b.componentProperties; const kind=Object.entries(p).find(([k])=>k.startsWith('Kind')); if(kind&&kind[1].value==='Text') setProps(b,{Label:'改天再升'}); } SR(f,'SR2-38','Text link → 改天再升 (the primary keeps 带我过去).'); }
// ---- SR2-24 · N34: odds bar between the tag row and the table; 难度 / 你的修正 rows removed; sheet hugs ----
async function fixChal(fr){ const sheet=fr.findOne(n=>n.name==='sheet'&&n.type==='FRAME'); if(!sheet) return 'nosheet';
  const ob=sheet.findOne(n=>n.type==='INSTANCE'&&n.name==='City/Odds Bar'); const head=sheet.children.find(c=>c.name==='head'); const inset=sheet.children.find(c=>c.name==='inset');
  let rm=0; if(inset) for(const kv of [...inset.children]){ const s=texts(kv).map(t=>t.characters).join(' '); if(/难度|你的修正/.test(s)){ kv.remove(); rm++; } }
  if(ob&&head){ sheet.insertChild(sheet.children.indexOf(head)+1,ob); ob.layoutSizingHorizontal='FILL'; try{ ob.layoutSizingVertical='HUG'; }catch(e){ R.warn.push('obhug '+String(e).slice(0,60)); } }
  sheet.primaryAxisSizingMode='AUTO'; sheet.y=fr.height-sheet.height; R.touched.push(sheet.id); return 'ok rm'+rm+' h'+Math.round(sheet.height)+' ob'+(ob?Math.round(ob.height):'-'); }
const n34=await byId('204:34263'); R.info.n34=await fixChal(n34); SR(n34,'SR2-24','City/Odds Bar now hugs (136 pt) and sits under the tags; 难度 and 你的修正 rows removed (the bar carries them); sheet hugs its content.');
// ---- SR2-37 · N66: collapsed title columns ----
const n66=await byId('207:2181'); let fixed66=0; before.n66=[];
for(const t of n66.findAll(n=>n.type==='TEXT'&&n.characters.trim()==='佩戴')){ let row=t.parent; while(row&&row!==n66&&!(row.layoutMode==='HORIZONTAL'&&row.width>240)) row=row.parent; if(!row||row===n66) continue;
  if(before.n66.length<3) before.n66.push(tree(row,0,3).join('\n'));
  for(const c of row.children){ const hasPei=texts(c).some(x=>x.characters.trim()==='佩戴');
    if(hasPei){ if('layoutSizingHorizontal' in c){ c.layoutSizingHorizontal=(c.type==='TEXT'||c.layoutMode&&c.layoutMode!=='NONE')?'HUG':'FIXED'; c.layoutGrow=0; } continue; }
    if(c.type==='TEXT'){ if(c.width<40){ await loadFontsOf(c); c.layoutSizingHorizontal='FILL'; c.textAutoResize='HEIGHT'; fixed66++; } continue; }
    if(c.layoutMode&&c.layoutMode!=='NONE'&&c.width<120&&texts(c).length){ c.layoutSizingHorizontal='FILL'; c.layoutGrow=1; for(const x of texts(c)){ await loadFontsOf(x); if(x.parent.layoutMode&&x.parent.layoutMode!=='NONE'){ x.layoutSizingHorizontal='FILL'; x.textAutoResize='HEIGHT'; } } fixed66++; } } }
R.info.n66=fixed66; SR(n66,'SR2-37','Row titles and conditions restored (text column fills, 佩戴 hugs at the trailing edge).');
// ---- SR2-36 · N28 / N33 rent rows: one leading image, one meta line ----
R.info.rent=[];
for(const fid of ['204:33843','204:34178']){ const f=await byId(fid); const rows=f.findAll(n=>n.type==='FRAME'&&n.name==='rent row'); if(!before[fid]&&rows[0]) before[fid]=tree(rows[0],0,2).join('\n'); let lead=0, meta=0;
  for(const row of rows){ const kids=row.children.filter(c=>c.visible!==false); const ci=kids.findIndex(c=>c.layoutMode==='VERTICAL'&&texts(c).length>0); if(ci>1){ for(const c of kids.slice(1,ci)){ c.remove(); lead++; } }
    for(const t of texts(row)){ if(/×/.test(t.characters)&&/·/.test(t.characters)){ const parts=t.characters.split(' · '); const s=parts.filter(p=>!/×/.test(p)).slice(0,2).join(' · ').replace(/^访客\s*/,''); await setT(t,s); meta++; } } }
  R.info.rent.push(fid+': rows '+rows.length+', leading removed '+lead+', meta '+meta); SR(f,'SR2-36','One leading image per row; meta = visitor · time; multipliers live in the detail sheet N29.'); }
// ---- SR2-38 · stray labels of archived frames ----
for(const sid of ['204:27379','207:2684']){ const s=await byId(sid); if(!s) continue; for(const c of [...s.children]) if(c.type==='TEXT'&&/^N(22|37|68)·[ab]/.test(c.characters)){ R.removed.push(c.id+':'+c.characters.slice(0,8)); c.remove(); } }
R.info.before=before;
await shot(n46,0.5); await shot(await byId('205:8475'),0.5); await shot(n34,0.5); await shot(n66,0.5); await shot(await byId('204:33843'),0.5);
return R;
