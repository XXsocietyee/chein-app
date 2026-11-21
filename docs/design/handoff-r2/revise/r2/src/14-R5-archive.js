// 14-R5-archive · page R5 · 4.10 (F-10): the 12 publish twins marked "· 已被 C1–C3 取代" (45 % opacity) move to the Archive page; links to them are removed.
const PG=await goPage('186:5944');
const twins=[]; for(const s of PG.children.filter(s=>s.type==='SECTION')) for(const f of s.children) if(f.type==='FRAME'&&(/已被\s?C1/.test(f.name)||(f.opacity>0.4&&f.opacity<0.5&&/发布|publish/i.test(f.name)))) twins.push(f);
R.info.found=twins.map(f=>f.id+' '+f.name);
await ARCHIVE(twins,'R5 · 创作者发布','verify-r1 4.10 / F-10: superseded by the C1–C3 editor pages (MR-34).');
return R;
