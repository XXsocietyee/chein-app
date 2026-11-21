const page=await figma.getNodeByIdAsync(PAGEID); await figma.setCurrentPageAsync(page);
for(const s of ['Regular','Medium','Semibold','Bold']) await figma.loadFontAsync({family:'SF Pro',style:s});
const SH=await figma.getNodeByIdAsync('280:410'); const key=b=>Object.keys(SH.componentPropertyDefinitions).find(k=>k.split('#')[0]===b);
const V=(l,t)=>SH.children.find(c=>c.name===`Leading=${l}, Trailing=${t}`);
const inInst=n=>{let p=n.parent; while(p&&p.type!=='PAGE'){ if(p.type==='INSTANCE'||p.type==='COMPONENT') return true; p=p.parent;} return false;};
const res={done:[],skip:[],kswap:0};
// K sheet header instances
for(const i of page.findAllWithCriteria({types:['INSTANCE']})){ if(i.removed||inInst(i)) continue; const mc=await i.getMainComponentAsync(); if(!mc||mc.id!=='217:8316') continue; const p=i.componentProperties; const g=b=>{const k=Object.keys(p).find(k=>k.split('#')[0]===b); return k?p[k].value:undefined;};
  const t=String(g('title')||''); const lead=g('showClose')===false?'None':'Close'; const w=i.layoutSizingHorizontal; i.swapComponent(V(lead,'None')); i.name='Editor/Sheet Header'; i.setProperties({[key('title')]:t,[key('showEyebrow')]:false,[key('showGrabber')]:g('showGrabber')!==false}); if(w==='FILL') i.layoutSizingHorizontal='FILL'; res.kswap++; }
const sheets=page.findAll(n=>n.type==='FRAME'&&/sheet/i.test(n.name)&&!/body|content|list|row|card/i.test(n.name)&&n.layoutMode==='VERTICAL'&&!inInst(n)&&!n.children.some(c=>c.name==='Editor/Sheet Header'));
for(const s of sheets){ const kids=s.children; let i0=0, grab=null; if(kids[0]&&kids[0].type==='RECTANGLE'&&kids[0].height<=6){ grab=kids[0]; i0=1; }
  const hdr=kids[i0]; if(!hdr||hdr.type!=='FRAME'||hdr.height>64||hdr.y>40){ res.skip.push(s.id+' nohdr'); continue; }
  const texts=hdr.findAll(n=>n.type==='TEXT'&&n.visible); const big=texts.filter(t=>t.fontSize>=16).sort((a,b)=>b.fontSize-a.fontSize)[0]; if(!big){ res.skip.push(s.id+' notitle'); continue; }
  const small=texts.find(t=>t!==big&&t.fontSize<16);
  const hasClose=hdr.findAll(n=>n.type!=='TEXT'&&n!==hdr&&n.width>=12&&n.width<=44&&n.height<=44&&(n.type==='FRAME'||n.type==='INSTANCE')&&n.findAll?n.findAll(x=>x.type==='VECTOR'||x.type==='TEXT'||x.type==='INSTANCE').length>0:false).length>0;
  let trail='None'; const last=kids[kids.length-1]; let lastBtn=null;
  if(last&&last!==hdr){ const bt=last.type==='TEXT'?null:last.findAll(n=>n.type==='TEXT').find(t=>/^(确定|完成|保存)/.test(t.characters)); if(bt){ trail='Done'; lastBtn=last; } }
  const idx=kids.indexOf(hdr); const inst=V(hasClose?'Close':'None',trail).createInstance(); s.insertChild(idx,inst); inst.name='Editor/Sheet Header'; inst.layoutSizingHorizontal='FILL';
  const props={[key('title')]:big.characters,[key('showEyebrow')]:!!small,[key('showGrabber')]:!!grab}; if(small) props[key('eyebrow')]=small.characters; inst.setProperties(props);
  hdr.remove(); if(grab) grab.remove(); if(lastBtn) lastBtn.remove();
  const top=(()=>{let p=s; while(p.parent&&p.parent.type!=='SECTION') p=p.parent; return p.id;})(); res.done.push(top+(trail==='Done'?'*':'')); }
return {kswap:res.kswap, n:res.done.length, done:res.done.join(' '), skip:res.skip.slice(0,30)};
