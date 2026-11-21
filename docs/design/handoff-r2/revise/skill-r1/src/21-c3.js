// B4f · C3 · SR1-17, SR1-43, SR1-39 check (tab bars)
await goPage('235:13237');
const INFO={}; INFO.pass=await cpass();
let other=0; const tbP=await byId('12:129'); for(const i of figma.currentPage.findAllWithCriteria({types:['INSTANCE']})){ if(i.id.includes(';')||!/Tab Bar/i.test(i.name)) continue; const mc=await i.getMainComponentAsync(); if(mc&&mc.parent!==tbP&&mc.parent&&!/Merchant/.test(mc.parent.name)){ try{ i.swapComponent(variant(tbP,{Selected:'发布'})); other++; }catch(e){} } }
INFO.tabSwaps=other; SR(await byId('243:1964'),'SR1-39','Tab Bar / Player (floating glass capsule); no yellow ⊕.');
R.info=INFO; await (await byId('243:1964')).screenshot({scale:0.35});
R.created=R.created.length; R.ann=R.ann.length; return R;
