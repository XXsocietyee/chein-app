// ---- CF-75 popup previews
const POP=['238:11777','238:11850','238:11923','238:11999','238:12075','238:12156'];
const STY=['星尘','纸本','末世','夜城'];
const W=(o)=>({type:'SOLID',color:{r:1,g:1,b:1},opacity:o});
out.pop=[];
for(let i=0;i<POP.length;i++){ const F=await byId(POP[i]); const ctrl=F.children.find(c=>c.name==='preview controls');
 const title=F.children.find(c=>c.type==='TEXT'&&/ · /.test(c.characters)); const selStyle=title?title.characters.split(' · ')[0]:'纸本';
 let cols=[]; let selCol=0;
 if(ctrl){ const ells=ctrl.findAll(n=>n.type==='ELLIPSE'); cols=ells.map(e=>({fill:JSON.parse(JSON.stringify(e.fills)),name:(e.parent.children.find(c=>c.type==='TEXT')||{characters:''}).characters, sel:(e.strokes&&e.strokes.length>0)||(e.parent.strokes&&e.parent.strokes.length>0)})); const k=cols.findIndex(c=>c.sel); selCol=k>=0?k:0; ctrl.remove(); }
 const oldStrip=F.children.find(c=>/^preview strip/.test(c.name)); if(!cols.length&&oldStrip){ cols=oldStrip.children.filter(h=>/^color · /.test(h.name)).map(h=>{const e=h.children[0]; return {fill:JSON.parse(JSON.stringify(e.fills)),name:h.name.replace(/^color · /,'').replace(' (选中)',''),sel:/选中/.test(h.name)};}); const k=cols.findIndex(c=>c.sel); selCol=k>=0?k:0; }
 for(const c of F.children.filter(c=>/^preview (strip|dots)/.test(c.name))) c.remove();
 const card=F.children.find(c=>/^pop-up card/.test(c.name))||F.children.filter(c=>c.type==='FRAME'&&!/close|status/.test(c.name)).sort((a,b)=>b.width*b.height-a.width*a.height)[0];
 if(card) card.y=Math.round(410-card.height/2);
 const strip=figma.createAutoLayout('HORIZONTAL',{name:'preview strip · 风格 + 配色 (CF-75)',itemSpacing:4}); F.appendChild(strip);
 strip.fills=[W(0.12)]; strip.cornerRadius=26; strip.paddingLeft=strip.paddingRight=10; strip.paddingTop=strip.paddingBottom=4; strip.counterAxisAlignItems='CENTER'; strip.clipsContent=true;
 for(const s of STY){ const on=s===selStyle; const p=figma.createAutoLayout('HORIZONTAL',{name:'style · '+s+(on?' (选中)':'')}); strip.appendChild(p); p.fills=[W(on?1:0.14)]; p.cornerRadius=18; p.paddingLeft=p.paddingRight=10; p.primaryAxisAlignItems='CENTER'; p.counterAxisAlignItems='CENTER'; 
  const t=figma.createText(); p.appendChild(t); t.fontName={family:'SF Pro',style:'Medium'}; t.fontSize=13; t.characters=s; t.fills=[{type:'SOLID',color:on?{r:0,g:0,b:0}:{r:1,g:1,b:1}}]; p.counterAxisSizingMode='FIXED'; p.resize(p.width,36); p.primaryAxisSizingMode='AUTO'; p.minWidth=44; }
 const dv=figma.createRectangle(); strip.appendChild(dv); dv.resize(1,24); dv.fills=[W(0.3)]; dv.name='divider';
 cols.forEach((c,j)=>{ const h=figma.createFrame(); strip.appendChild(h); h.name='color · '+c.name+(j===selCol?' (选中)':''); h.resize(40,44); h.fills=[]; const e=figma.createEllipse(); h.appendChild(e); e.resize(26,26); e.x=7; e.y=9; e.fills=c.fill; if(j===selCol){ e.strokes=[{type:'SOLID',color:{r:1,g:1,b:1}}]; e.strokeWeight=2; e.strokeAlign='OUTSIDE'; } else { e.strokes=[W(0.35)]; e.strokeWeight=1; e.strokeAlign='INSIDE'; } });
 strip.primaryAxisSizingMode='FIXED'; strip.resize(361,52); strip.x=16; strip.y=852-34-52-6;
 const dots=figma.createAutoLayout('HORIZONTAL',{name:'preview dots · 阶段 '+(i+1)+'/6',itemSpacing:8}); F.appendChild(dots); dots.fills=[];
 for(let j=0;j<6;j++){ const d=figma.createEllipse(); dots.appendChild(d); d.resize(6,6); d.fills=[W(j===i?1:0.35)]; d.name='dot '+(j+1); }
 dots.x=Math.round((393-dots.width)/2); dots.y=strip.y-20;
 out.pop.push(F.id+' style='+selStyle+' cols='+cols.length+' sel='+selCol+' card='+(card&&card.id));
}
for(let i=0;i<POP.length;i++){ const F=await byId(POP[i]); await link(F,{type:'ON_DRAG'},POP[(i+1)%POP.length],PUSH()); }
// 章节闸 copy
const cg=await byId('249:35830'); if(cg&&cg.type==='TEXT') await setT(cg,'第一章 · 共三章');
// ---- CF-66: 系统键盘 labels → ink-2
const ink2=await figma.variables.getVariableByIdAsync('VariableID:7:13'); let kb=0;
for(const f of FRAMES) for(const t of f.findAllWithCriteria({types:['TEXT']})) if(t.characters==='系统键盘'){ t.fills=[figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:.25,g:.25,b:.25}},'color',ink2)]; kb++; }
out.kb=kb;
// ---- copy pass
out.copy=await copyPass();
// ---- motion annotations
const POPMD=['Popup preview (CF-75): 阶段 is a swipe pager (TabView(.page)); page slide 350 ms ease-out (.22,.61,.36,1); the popup replays its entrance on each page (scale .92 → 1 + fade, spring(.38, .86)) · no haptic','Bottom strip (风格 | 配色): selection cross-fade 140 ms · .selection; the strip scrolls sideways; every target 44 pt'];
const SPECIAL={}; for(const id of POP) SPECIAL[id]=POPMD;
SPECIAL['249:35825']=['Chapter gate (player): card fades up 24 pt, spring(response .42, damping .8); the three progress segments fill 220 ms in turn; tap anywhere continues (轻点继续) · no haptic; Reduce Motion: fade only'];
out.motion=motionPass(SPECIAL);
// ---- CF-68 / CF-74 targeted annotations
const a11y=[]; const B2=await byId('237:31646'); const seg=inst(B2,/Segment/); if(seg){ annotate(seg,'**VoiceOver (CF-68)** · segmented 「显示方式」, values 列表 / 地图; the chosen one has trait .isSelected',CAT_A,/^\*\*VoiceOver/); a11y.push(seg.id); }
for(const id of ['237:51859','237:65700','237:51424']){ const f=await byId(id); const sm=inst(f,/Seam/); if(sm){ annotate(sm,'**VoiceOver (CF-68)** · seam ＋ = 「在这里插入」; expanded tiles read their block type (文字, 图片, 节点 …)',CAT_A,/^\*\*VoiceOver/); a11y.push(sm.id); } }
for(const id of ['237:31986','237:67490']){ const f=await byId(id); const h=inst(f,/Handle|Chapter Card|List Item/); if(h){ annotate(h,'**VoiceOver (CF-68)** · handle = 「调整顺序」 with actions 「上移」 「下移」; ⋯ = 「更多操作」; while dragging the row announces 「移到第 N 位」',CAT_A,/^\*\*VoiceOver/); a11y.push(h.id);} }
for(const id of ['239:33463','239:33587']){ const f=await byId(id); if(f){ annotate(f,'**Keyboard (CF-74)** · the sheet sits on the keyboard and grows with the text (.height(200) → .large); the 完成 pill stays visible above the keyboard; Return inserts a line in 剧情 / 描述, and commits in 名称',CAT_D,/^\*\*Keyboard/); a11y.push(f.id);} }
out.a11y=a11y;
// page components (C1-local)
const pc={'290:23460':'VoiceOver (CF-68): seam ＋ = 「在这里插入」; tiles read the block type. Motion: expand height + fade 220 ms ease-out · .selection.','290:23403':'VoiceOver (CF-68): card = chapter name + summary; ⋯ = 「更多操作」; handle = 「调整顺序」 (actions 上移 / 下移). Motion: see Editor/List Item (CF-60).','290:23581':'VoiceOver (CF-68): the sentence is read as one element; unset tokens read 「未设置」; ⋯ = 「更多操作」; handle = 「调整顺序」.','290:23583':'VoiceOver (CF-68): 「搜索地点」 search field.','290:23587':'VoiceOver (CF-68): 「定位到我」. Haptic .impact(.light) when the map recentres.','290:23504':'VoiceOver (CF-68): label = gameplay name, value = 已设置 / 未设置 / 有错误.','290:23405':'VoiceOver (CF-68): label = block type.'};
out.pc=[]; for(const [id,t] of Object.entries(pc)){ const n=await byId(id); if(n&&(n.type==='COMPONENT'||n.type==='COMPONENT_SET')){ let d=n.description||''; const i=d.indexOf('\n\n— F/G'); if(i>=0) d=d.slice(0,i); n.description=d+'\n\n— F/G —\n'+t; out.pc.push(id);} }
// ---- prototypes (CF-64 most-seen)
const L=[];
L.push(await link(await byId('249:40292'),{type:'ON_DRAG'},'239:24873',SA(0.38,SPR(290,27))));
L.push(await link(await byId('239:24873'),{type:'ON_DRAG'},'249:40292',SA(0.38,SPR(290,27))));
const B7=await byId('239:31923'); const t7=B7.findAllWithCriteria({types:['TEXT']}).find(t=>t.characters==='画面风格'); let row=t7; while(row&&row.parent!==B7&&!(row.type==='INSTANCE'&&/Row/.test(row.name))) row=row.parent;
L.push(await link(row&&row!==B7?row:null,{type:'ON_CLICK'},'241:1680',PUSH()));
const B72=await byId('241:1680'); const hd=inst(B72,/Sheet Header/); if(hd){ await hd.setReactionsAsync([{trigger:{type:'ON_CLICK'},actions:[{type:'BACK'}]}]); L.push(hd.id+'>BACK'); }
L.push(await link(inst(await byId('238:10642'),/Add Row/),{type:'ON_CLICK'},'238:10960',SA(0.22)));
L.push(await link(inst(await byId('237:31646'),/Chapter Card/,1),{type:'MOUSE_DOWN',delay:0.18},'237:31986',SA(0.14)));
L.push(await link(inst(await byId('237:65700'),/Seam/),{type:'ON_CLICK'},'237:51859',SA(0.22)));
out.links=L;
out.flows=flows([{nodeId:'249:40292',name:'F · 抽屉高度 · 章节设置 (§3)'},{nodeId:'239:31923',name:'F · 推入子页 · 主题详情 → 画面风格'},{nodeId:'238:10642',name:'F · 添加一行 · 分支'},{nodeId:'237:31646',name:'F · 拖动排序 · 章节 (CF-60)'},{nodeId:'237:65700',name:'F · 展开插入缝 · 故事流'},{nodeId:'238:11777',name:'F · 弹窗预览 (CF-75)'}]);
return out;
