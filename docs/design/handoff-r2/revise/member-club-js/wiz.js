async function relabel(fr,text){ const par=fr.parent; const l=par.children.find(c=>c.type==='TEXT'&&Math.abs(c.x-fr.x)<4&&c.y<fr.y&&c.y>fr.y-40); if(l){ await setTxt(l,text); } }
function card(par){ const c=AL('VERTICAL','card',{fill:'surface',r:12,gap:0}); add(par,c,'FILL'); c.clipsContent=true; return c; }
async function item(body,it){
 if(it.t==='opt'){ const o=inst('opt',{Kind:it.kind,State:it.sel?'Selected':'Default'},{title:it.title,sub:it.sub||'',showSub:!!it.sub,icon:ICON[it.icon||'flag'].id}); body.appendChild(o); o.layoutSizingHorizontal='FILL'; if(it.dim) o.opacity=0.4; return o; }
 if(it.t==='grid'){ for(let i=0;i<it.cells.length;i+=2){ const r=AL('HORIZONTAL','grid row',{gap:10}); add(body,r,'FILL'); for(const [title,sel,dim] of it.cells.slice(i,i+2)){ const o=inst('opt',{Kind:'Multi',State:sel?'Selected':'Default'},{title,showSub:false}); r.appendChild(o); o.layoutSizingHorizontal='FILL'; const tile=o.findOne(n=>n.name==='icon tile'); if(tile) tile.visible=false; if(dim) o.opacity=0.4; } } return; }
 if(it.t==='field'){ const f=inst('field',{Kind:it.kind||'Line',State:it.state||'Filled',Surface:'OnCard'},{label:it.label,value:it.value,help:it.help||'',showHelp:!!it.help,required:!!it.req,suffix:it.suffix||'',showSuffix:!!it.suffix,showCounter:false}); body.appendChild(f); f.layoutSizingHorizontal='FILL'; return f; }
 if(it.t==='pair'){ const r=AL('HORIZONTAL','field pair',{gap:10,align:'MIN'}); add(body,r,'FILL'); for(const sub of it.fields){ const f=await item(r,{t:'field',...sub}); f.layoutSizingHorizontal='FILL'; } return; }
 if(it.t==='row'){ const c=card(body); const r=inst('erow',{Accessory:it.acc||'Chevron'},{label:it.label,value:it.value,showValue:true,showIcon:!!it.icon,showDivider:false,showDot:!!it.dot,...(it.icon?{icon:ICON[it.icon].id}:{})}); c.appendChild(r); r.layoutSizingHorizontal='FILL'; return c; }
 if(it.t==='sw'){ const c=card(body); const r=inst('swRow',{},{label:it.label,sub:it.sub||'',showSub:!!it.sub}); c.appendChild(r); r.layoutSizingHorizontal='FILL'; for(const n of r.findAll(x=>x.type==='INSTANCE')){ const m=await n.getMainComponentAsync(); if(m&&m.parent&&m.parent.id==='276:302') n.setProperties({State:it.on?'On':'Off'}); } return c; }
 if(it.t==='uploads'){ const r=AL('HORIZONTAL','uploads',{gap:10,align:'MIN'}); add(body,r,'FILL'); for(const l of it.labels){ const u=AL('VERTICAL','upload',{gap:6,justify:'CENTER',fill:'surface',r:12}); r.appendChild(u); u.resize(110,110); u.primaryAxisSizingMode='FIXED'; u.counterAxisSizingMode='FIXED'; u.strokes=[P('sep-strong')]; u.strokeWeight=1; u.dashPattern=[5,4]; I(u,'plus',22,'ink-2','icon'); await T(u,l,'t-foot','ink-2',{name:'label'}); } return; }
 if(it.t==='text'){ const r=AL('HORIZONTAL','line',{gap:6}); add(body,r,'FILL'); if(it.icon) I(r,it.icon,14,it.color||'ink-3','icon'); const t=await T(r,it.s,'t-foot',it.color||'ink-3',{name:'text'}); t.layoutGrow=1; t.textAutoResize='HEIGHT'; return r; }
 if(it.t==='banner'){ const b=AL('HORIZONTAL','inline error',{fill:'bad-soft',r:12,pad:[12,14,12,14],gap:10,align:'MIN'}); add(body,b,'FILL'); I(b,'alert',18,'bad','icon'); const col=AL('VERTICAL','text',{gap:2,align:'MIN'}); add(b,col,'FILL'); await T(col,it.title,null,'ink',{size:15,w:'Semibold',fill:true,name:'title'}); await T(col,it.line,'t-foot','ink-2',{fill:true,name:'line'}); return b; }
}
async function citySheet(fr){ const scr=figma.createRectangle(); fr.appendChild(scr); scr.name='scrim'; scr.resize(393,852); scr.x=0; scr.y=0; F(scr,'scrim');
 const sh=AL('VERTICAL','sheet · 选择城市 (fit → .large)',{fill:'sheet',pad:[8,16,34,16],gap:12,align:'MIN'}); fr.appendChild(sh); sh.resize(393,10); sh.counterAxisSizingMode='FIXED'; sh.primaryAxisSizingMode='AUTO'; sh.topLeftRadius=sh.topRightRadius=20;
 const gr=AL('HORIZONTAL','grabber row',{justify:'CENTER'}); add(sh,gr,'FILL'); const g=figma.createRectangle(); gr.appendChild(g); g.resize(36,5); g.cornerRadius=3; F(g,'mp/sheet-handle'); g.name='grabber';
 const hd=AL('HORIZONTAL','header',{gap:8}); add(sh,hd,'FILL'); const tt=await T(hd,'选择城市','t-3','ink',{name:'title'}); tt.layoutGrow=1; const x=box(hd,32,32,'close',{fill:'mp/sheet-close-bg',r:16}); I(x,'x',14,'ink-2','icon');
 const sf=AL('HORIZONTAL','search',{fill:'input-bg',r:10,pad:[0,10,0,10],gap:6}); add(sh,sf,'FILL'); sf.resize(361,36); sf.counterAxisSizingMode='FIXED'; sf.layoutSizingHorizontal='FILL'; I(sf,'search',16,'ink-3','icon'); await T(sf,'搜索城市','t-sub','ink-3',{name:'placeholder'});
 await T(sh,'当前定位','t-foot','ink-3',{name:'group'}); const g1=AL('VERTICAL','group',{r:12,gap:0}); add(sh,g1,'FILL'); g1.clipsContent=true; const r0=inst('row',{Accessory:'Check'},{title:'上海',sub:'当前定位',showAvatar:false,showDivider:false}); g1.appendChild(r0); r0.layoutSizingHorizontal='FILL';
 await T(sh,'热门城市','t-foot','ink-3',{name:'group'}); const g2=AL('VERTICAL','group',{r:12,gap:0}); add(sh,g2,'FILL'); g2.clipsContent=true; const cs=['北京','杭州','南京','成都']; cs.forEach((c,i)=>{ const r=inst('row',{Accessory:'None'},{title:c,showSub:false,showAvatar:false,showDivider:i<cs.length-1}); g2.appendChild(r); r.layoutSizingHorizontal='FILL'; });
 sh.x=0; sh.y=852-sh.height; return sh; }
async function wizard(sp){
 const fr=await figma.getNodeByIdAsync(sp.id); if(sp.name){ fr.name=sp.name; await relabel(fr,sp.name); }
 const nav=fr.children.find(c=>c.type==='INSTANCE'&&c.y<10); const ctr=fr.children.find(c=>c.type==='TEXT'&&/^\d \/ 4$/.test(c.characters));
 for(const c of [...fr.children]) if(c!==nav&&c!==ctr) c.remove();
 if(ctr) await setTxt(ctr,`${sp.step} / 4`);
 const h=inst('step',{Step:sp.step},{eyebrow:sp.eyebrow,title:sp.title,sub:sp.sub||'',showSub:!!sp.sub}); fr.appendChild(h); h.x=0; h.y=100;
 const body=AL('VERTICAL','content',{gap:8,align:'MIN'}); fr.appendChild(body); body.resize(361,10); body.counterAxisSizingMode='FIXED'; body.primaryAxisSizingMode='AUTO'; body.clipsContent=false; body.x=16; body.y=100+h.height;
 for(const it of sp.items) await item(body,it);
 const bb=bottomBar(fr); if(sp.foot) await T(bb,sp.foot,'t-foot','ink-3',{fill:true,align:'CENTER',name:'footnote'});
 const b=btn(bb,'Primary',sp.primary); b.layoutSizingHorizontal='FILL'; pinBottom(fr,bb);
 if(sp.sheet) await citySheet(fr);
 if(sp.note) await NOTE(fr,sp.note,'mc');
 return {id:fr.id, bodyBottom:Math.round(body.y+body.height), barTop:Math.round(bb.y)};
}
