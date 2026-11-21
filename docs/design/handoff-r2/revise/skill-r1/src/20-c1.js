// B4e · C1 · SR1-18 主题详情 icons, SR1-21 segmented, SR1-17, SR1-43
await goPage('237:14642');
const INFO={}; INFO.pass=await cpass();
// SR1-18: Editor/Row showIcon=false in 数值与状态 and 高级
{ const f=await byId('239:31923'); let n=0, inGroup=false; const body=f.findOne(x=>x.name==='body'); const seq=body?body.findAll(x=>(x.type==='TEXT'&&/^(基本信息|数值与状态|高级|.{2,6})$/.test(x.characters.trim())&&x.fontSize>=13&&!x.id.includes(';'))||(x.type==='INSTANCE'&&!x.id.includes(';'))):[];
  seq.sort((a,b)=>a.absoluteBoundingBox.y-b.absoluteBoundingBox.y);
  for(const x of seq){ if(x.type==='TEXT'){ if(/^数值与状态|^高级/.test(x.characters.trim())) inGroup=true; else if(/^基本信息/.test(x.characters.trim())) inGroup=false; continue; } if(!inGroup) continue; const keys=Object.keys(x.componentProperties||{}); const k=keys.find(k=>/^showIcon/i.test(k)); if(k){ x.setProperties({[k]:false}); n++; } }
  INFO.icons=n; if(n) SR(f,'SR1-18','No leading icons in 数值与状态 and 高级 (the six bar/bag glyphs said nothing); icons stay only in 基本信息.'); }
// SR1-21: one segmented control (white thumb) in the light theme
{ const seg=await byId('316:5034'); let n=0; if(seg){ const tgt=seg.type==='COMPONENT_SET'?seg.children[0]:seg; for(const i of figma.currentPage.findAllWithCriteria({types:['INSTANCE']})){ if(i.id.includes(';')||!/Segmented/.test(i.name)) continue; const mc=await i.getMainComponentAsync(); if(!mc||mc===tgt||(mc.parent&&mc.parent===seg)) continue; const labs=texts(i).map(t=>t.characters); const w=i.width; try{ i.swapComponent(tgt); i.resize(w,i.height); const ts=texts(i); for(let k=0;k<Math.min(ts.length,labs.length);k++) await setT(ts[k],labs[k]); n++; }catch(e){} } } INFO.seg=n; if(n) SR(await byId('237:31646'),'SR1-21','列表 | 地图 uses Merchant/Segmented (white thumb), the one segmented control of the light theme.'); }
R.info=INFO; await (await byId('239:31923')).screenshot({scale:0.25}); 
R.created=R.created.length; R.ann=R.ann.length; return R;
