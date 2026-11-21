const page=await figma.getNodeByIdAsync(PAGEID); await figma.setCurrentPageAsync(page);
for(const s of ['Regular','Medium','Semibold','Bold']) await figma.loadFontAsync({family:'SF Pro',style:s});
const NV=await figma.getNodeByIdAsync('280:585'); const tk=Object.keys(NV.componentPropertyDefinitions).find(k=>k.startsWith('title'));
const none=NV.children.find(c=>c.name==='Trailing=None');
const out={n:0,titles:{}};
for(const sid of SECS){ const sec=await figma.getNodeByIdAsync(sid);
  for(const i of sec.findAllWithCriteria({types:['INSTANCE']})){ if(i.removed) continue; let p=i.parent, nested=false; while(p&&p.type!=='SECTION'){ if(p.type==='INSTANCE'){nested=true;break;} p=p.parent;} if(nested) continue;
    const mc=await i.getMainComponentAsync(); if(!mc||!mc.parent||mc.parent.id!=='83:100') continue;
    const tt=i.findOne(n=>n.type==='TEXT'&&n.name==='title'); let title=tt&&tt.visible?tt.characters.trim():'';
    if(TITLE[title]!==undefined) title=TITLE[title];
    const par=i.parent; i.swapComponent(none); i.name='Editor/Nav Bar'; i.setProperties({[tk]:title||' '}); 
    for(const sib of par.children.filter(c=>c!==i&&/^back-circle$|^back$/.test(c.name)&&c.y<110)) sib.remove();
    out.n++; out.titles[title]=(out.titles[title]||0)+1; } }
return out;
