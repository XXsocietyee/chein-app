const IMG={cover:'a30e807f342390bf771651974d2540b5a1e7c23f',dlogo:'c4480092d19b5b465f1baf0fbfe457feb1b9f4d8',avatar:'21f345c08aa328f8b8161ce36ef1b576c99ac33f',oldmovie:'fbe89ce2beeffdf5366299cbd2409d75cf57ee8d',teamrace:'fca70d928ebebde5d9cf0536da51d95920054a78',midlife:'7fca302a332a805179d0e490fe5a1c9daaf793ba',heat:'74278fbe58cd617f97685d9547c0c8caffe4f09e',anomaly:'9a1b8ff5a8565fcedcb11ab91a0ada3d311d8cbb',flavor:'5755e96bba3f4e83b736236c9cc806c8e2b930a3',routecity:'ea0cf24c3a6a22ead64d6dcc3d460985fe9e1bb7',routefree:'f13e4e3278cc2246d49f2a42e4d891816946b433'};
const IMGF=k=>({type:'IMAGE',imageHash:IMG[k],scaleMode:'FILL'});
const PIC=(par,k,w,h,r)=>{const n=figma.createRectangle(); par.appendChild(n); n.resize(w,h); n.cornerRadius=r??10; n.fills=[IMGF(k)]; n.name='img/'+k; return n;};
const AVIMG=(par,d)=>{const n=figma.createEllipse(); par.appendChild(n); n.resize(d,d); n.fills=[IMGF('avatar')]; n.name='avatar'; return n;};
// club home header (cloned from 070 优化), then select a tab
async function CLUBHEAD(f,tab,o={}){await BASE(f,'204:24850',432,{skip:c=>(o.visitor&&c.type==='TEXT'&&c.characters==='退出')});
 const names=['帖文','活动','概览']; let selX=null;
 for(const c of f.children){ if(c.type==='TEXT'&&names.includes(c.characters)&&c.y>380&&c.y<420){ const on=c.characters===tab; c.fills=[P(on?'ink':'ink-3')]; c.fontName={family:'SF Pro',style:on?'Semibold':'Regular'}; if(on) selX=c.x+c.width/2; } }
 if(o.manage){const t=TX(f,'管理','MP/body',tab==='管理'?'ink':'ink-3',{size:16,x:195,y:394}); if(tab==='管理'){t.fontName={family:'SF Pro',style:'Semibold'}; selX=t.x+t.width/2;}}
 if(o.gear) IC(f,'gear',22,'ink',355,60);
 const ind=f.children.find(c=>c.name==='tab-indicator'); if(ind&&selX!=null) ind.x=selX-ind.width/2; }
function POST(par,p){const c=AL(par,'VERTICAL',{gap:10,pad:16,r:16,fill:'surface',name:'post card'}); c.layoutSizingHorizontal='FILL';
 const h=AL(c,'HORIZONTAL',{gap:10,align:'CENTER'}); AVIMG(h,36); const col=AL(h,'VERTICAL',{gap:2}); const nm=AL(col,'HORIZONTAL',{gap:6,align:'CENTER'}); TX(nm,p.name,'MP/body-strong','ink'); if(p.role){const b=AL(nm,'HORIZONTAL',{fill:'surface-3',r:999,pad:[1,6,1,6]}); TX(b,p.role,'MP/tag','ink-2');}
 TX(col,p.meta,'MP/caption','ink-3');
 if(p.pinned){const pn=AL(c,'HORIZONTAL',{gap:6,align:'CENTER'}); IC(pn,'pin',14,'mp/accent-lime'); TX(pn,'置顶','MP/label','mp/accent-lime');}
 TX(c,p.text,'MP/body','ink',{fillW:true,size:15});
 if(p.imgs){const r=AL(c,'HORIZONTAL',{gap:8}); for(const k of p.imgs) PIC(r,k,p.imgs.length===1?329:104,p.imgs.length===1?180:104,10);}
 if(p.quote){const q=AL(c,'HORIZONTAL',{gap:10,pad:12,r:12,fill:'surface-2',align:'CENTER',name:'quoted record'}); q.layoutSizingHorizontal='FILL'; if(p.quote==='gone'){IC(q,'alert',18,'ink-3'); TX(q,'引用不可用','MP/body','ink-3');} else {IC(q,'route',18,'ink-2'); const qc=AL(q,'VERTICAL',{gap:2}); TX(qc,p.quote,'MP/body-strong','ink'); TX(qc,p.quoteSub,'MP/caption','ink-3');}}
 const a=AL(c,'HORIZONTAL',{gap:18,align:'CENTER',name:'counts'}); for(const [k,n] of [['heart',p.likes],['chat',p.comments],['share',null]]){const g=AL(a,'HORIZONTAL',{gap:5,align:'CENTER'}); IC(g,k,18,'ink-2'); if(n!=null) TX(g,String(n),'MP/body','ink-2');}
 if(p.actions){const r=AL(c,'HORIZONTAL',{gap:16,name:'row actions (by permission)'}); for(const t of p.actions) TX(r,t,'MP/label',t==='删除'||t==='举报'?'ink-3':'ink-2',{size:13});}
 return c;}
function CONTENT(f,y,o={}){const c=AL(f,'VERTICAL',{gap:o.gap??12,pad:[0,16,0,16],name:'content',x:0,y,w:393}); return c;}
