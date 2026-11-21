// B4d · C2 · SR1-16 blank primary, SR1-19 preview art, SR1-17, SR1-43
await goPage('235:178');
const INFO={}; INFO.pass=await cpass();
// SR1-16: blank dark capsules in sheet footers of section 237:71932 → 下一步, disabled style
{ const sec=await byId('237:71932'); let n=0; const lum=c=>0.2126*c.r+0.7152*c.g+0.0722*c.b;
  for(const b of sec.findAll(x=>!x.id.includes(';')&&(x.type==='FRAME'||x.type==='RECTANGLE'||x.type==='INSTANCE')&&x.height>=40&&x.height<=56&&x.width>=90&&x.width<=220&&(x.cornerRadius>=18||x.cornerRadius===figma.mixed))){ const f=b.fills&&b.fills.find&&b.fills.find(p=>p.type==='SOLID'&&p.visible!==false); if(!f||lum(f.color)>0.25) continue; const ts=(b.type==='TEXT'?[b]:b.findAll?b.findAll(t=>t.type==='TEXT'&&t.visible&&t.characters.trim()):[]); if(ts.length) continue;
    const near=b.parent&&b.parent.findAll?b.parent.findAll(t=>t.type==='TEXT'&&/选一个|请选择|选择/.test(t.characters)):[]; if(!near.length) continue;
    if(b.type==='INSTANCE'){ continue; } b.fills=[PAINT('mp/disabled')]; if(b.type==='FRAME'){ const t=await TX(b,'下一步','role/button-md','ink-3',{name:'label'}); if(b.layoutMode==='NONE'){ t.x=(b.width-t.width)/2; t.y=(b.height-t.height)/2; } } else { const t=await TX(b.parent,'下一步','role/button-md','ink-3',{name:'label'}); if(b.parent.layoutMode&&b.parent.layoutMode!=='NONE'){ t.layoutPositioning='ABSOLUTE'; } t.x=b.x+(b.width-t.width)/2; t.y=b.y+(b.height-t.height)/2; } n++; let fr=b; while(fr.parent&&fr.parent!==sec) fr=fr.parent; SR(fr,'SR1-16','The unselected state shows 下一步 in the disabled style; the hint on the left gives the reason.'); }
  INFO.blank=n; }
// SR1-19: preview cover = the template's own route art
{ const src=await byId('237:43689'); const img=src&&src.findAll(n=>'fills' in n&&Array.isArray(n.fills)&&n.fills.some(p=>p.type==='IMAGE')&&n.width>=200).map(n=>n.fills.find(p=>p.type==='IMAGE'))[0]; const cv=await byId('238:25479'); if(cv&&img){ cv.fills=[{...img}]; INFO.preview='route art'; SR(await byId('238:25435'),'SR1-19','Preview shows the template\'s own route art, not a cartoon chest.'); } else INFO.preview='no source image'; }
R.info=INFO; await (await byId('237:71933')).screenshot({scale:0.35}); await (await byId('238:25435')).screenshot({scale:0.35});
R.created=R.created.length; R.ann=R.ann.length; return R;
