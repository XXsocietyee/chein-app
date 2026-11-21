// 15-R6 · page R6 · 4.10 (F-10: A10/A11 frames noted "已被 N01 取代" → Archive), 5.8 (PL-40 motion notes → Interaction annotations + rows).
const PG=await goPage('185:5431');
const ids=['185:5191','185:5246','185:5305','185:5318']; const nodes=[];
for(const id of ids){ const n=await byId(id); if(n&&(await pageOf(n))===PG) nodes.push(n); }
// any other frame whose note says it was superseded by N01
for(const s of PG.children.filter(s=>s.type==='SECTION')) for(const n of s.children.filter(c=>c.name.startsWith('note:'))){ if(texts(n).some(t=>/已被\s?N01\s?取代/.test(t.characters))){ const m=n.name.match(/^note:(\d+:\d+)/); if(m&&!ids.includes(m[1])){ const f=await byId(m[1]); if(f&&f.type==='FRAME') nodes.push(f); } } }
R.info.found=nodes.map(n=>n.id+' '+n.name);
await ARCHIVE(nodes,'R6 · 漫游','verify-r1 4.10 / F-10: superseded by N01 (owner confirmed Q-A, 2026-11-16).');
await motionPass('PL-40');
return R;
