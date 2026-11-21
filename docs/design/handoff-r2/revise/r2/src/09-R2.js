// 09-R2 · page R2 · 5.3 (MC-04: 204:34773 附近 — the yellow diagonal and the cropped cover live in rasters: swap the map image and the card cover),
// 5.8 (MC-50 motion notes → Interaction annotations + rows on every member frame).
const PG=await goPage('204:34773');
const absY=n=>n.absoluteTransform[1][2];
const img=n=>Array.isArray(n.fills)&&n.fills.find(f=>f.type==='IMAGE'&&f.visible!==false);
{ const F=await byId('204:34773'); const out={};
  const imgs=F.findAll(n=>'fills' in n&&img(n)).map(n=>({n,h:img(n).imageHash,area:n.width*n.height}));
  out.images=imgs.map(x=>`${x.n.type} ${x.n.name} ${Math.round(x.n.width)}×${Math.round(x.n.height)} @y${Math.round(absY(x.n)-absY(F))}`);
  const map=imgs.filter(x=>x.n.width>=300).sort((a,b)=>b.area-a.area)[0];
  const cover=imgs.filter(x=>x.n!==(map&&map.n)&&x.n.width>=56&&x.n.width<=200&&absY(x.n)-absY(F)>F.height*0.55).sort((a,b)=>absY(b.n)-absY(a.n))[0];
  // candidates elsewhere on R2: other map-like rasters, and photo covers (not square avatars)
  const pool=PG.findAll(n=>'fills' in n&&img(n)&&n.width>=80&&!within(n,F));
  const maps=pool.filter(n=>n.width>=300&&/map|地图|附近|漫游|route|路线/i.test(n.name+' '+(n.parent?n.parent.name:''))).map(n=>img(n).imageHash).filter(h=>!map||h!==map.h);
  const covers=pool.filter(n=>/cover|封面|photo|图/i.test(n.name)&&Math.abs(n.width-n.height)>8).map(n=>img(n).imageHash).filter(h=>!cover||h!==cover.h);
  out.mapCandidates=[...new Set(maps)].length; out.coverCandidates=[...new Set(covers)].length;
  if(map&&maps.length){ map.n.fills=map.n.fills.map(f=>f.type==='IMAGE'?{...f,imageHash:maps[0],scaleMode:'FILL'}:f); out.map='swapped '+map.n.name; R.touched.push(map.n.id); } else out.map='no candidate (left)';
  if(cover&&covers.length){ cover.n.fills=cover.n.fills.map(f=>f.type==='IMAGE'?{...f,imageHash:covers[0],scaleMode:'FILL'}:f); out.cover='swapped '+cover.n.name; R.touched.push(cover.n.id); } else out.cover='no candidate (left)';
  if(R.touched.length) FIXED(F,'5.3','附近: map raster without the yellow line, and a real cover on the bottom card (MC-04).');
  R.info['5.3']=out; }
function within(n,root){ let p=n; while(p){ if(p===root) return true; p=p.parent; } return false; }
await motionPass('MC-50');
return R;
