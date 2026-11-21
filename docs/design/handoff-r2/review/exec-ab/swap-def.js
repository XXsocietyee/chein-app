const page=await figma.getNodeByIdAsync(PAGEID); await figma.setCurrentPageAsync(page);
for(const s of ['Regular','Medium','Semibold','Bold']) await figma.loadFontAsync({family:'SF Pro',style:s});
const AS=await figma.getNodeByIdAsync('217:4511'), AK=await figma.getNodeByIdAsync('217:4574'), AA=await figma.getNodeByIdAsync('217:8315');
const val=(i,base)=>{const k=Object.keys(i.componentProperties).find(k=>k.split('#')[0]===base); return k?i.componentProperties[k].value:undefined;};
const setP=(i,props)=>{const map={}; for(const key of Object.keys(i.componentProperties)) map[key.split('#')[0]]=key; const o={}; for(const [k,v] of Object.entries(props)) if(map[k]!=null&&v!=null) o[map[k]]=v; i.setProperties(o);};
let n={state:0,skel:0,alert:0};
for(const i of page.findAllWithCriteria({types:['INSTANCE']})){ const mc=i.mainComponent; if(!mc||!mc.parent) continue; const sid=mc.parent.id; if(!['219:5570','219:5645','219:5668'].includes(sid)) continue;
 const x=i.x,y=i.y,lh=i.layoutSizingHorizontal;
 if(sid==='219:5570'){ let kind=val(i,'Kind'); kind={Missing:'Info'}[kind]||kind; const p={title:val(i,'Title'),sub:val(i,'Sub'),action:val(i,'Button'),showSub:val(i,'Show Sub'),showAction:val(i,'Show Button')}; i.swapComponent(AS.children.find(c=>c.name==='Kind='+kind)||AS.defaultVariant); setP(i,p); n.state++; }
 else if(sid==='219:5645'){ const t=val(i,'Type'); i.swapComponent(AK.children.find(c=>c.name==='Type='+t)||AK.defaultVariant); n.skel++; }
 else { const tone=val(i,'Tone'); const p={title:val(i,'Title'),message:val(i,'Body'),cancel:val(i,'Left'),confirm:val(i,'Right'),showMessage:val(i,'Show Body')}; i.swapComponent(AA.children.find(c=>c.name==='Tone='+tone)||AA.defaultVariant); setP(i,p); n.alert++; }
 if(i.parent&&(!i.parent.layoutMode||i.parent.layoutMode==='NONE')){i.x=x;i.y=y;} else if(lh==='FILL') i.layoutSizingHorizontal='FILL';
}
return n;
