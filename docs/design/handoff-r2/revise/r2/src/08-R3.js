// 08-R3 · page R3 · 4.3 (F-03: 223:3698 stray back circle, menu bar, three avatars), 5.4 (MC-20: 236:8395 chip ✕ 28 on a 44 target;
// 219:3463 comment ⋯ menu drawn open in a new state frame), 5.8 (MC-50 motion notes → Interaction annotations + rows on every club frame).
const PG=await goPage('223:3698');
const absX=n=>n.absoluteTransform[0][2], absY=n=>n.absoluteTransform[1][2];
// ---- 4.3 ----
{ const F=await byId('223:3698'); const out={};
  const isBack=n=>/back|返回|‹|chevron\.left/i.test(n.name)&&n.type!=='TEXT'&&n.width<=52&&n.height<=52;
  const header=F.children.find(c=>/header|nav|sheet header|标题/i.test(c.name)&&absY(c)-absY(F)<140);
  const strays=F.findAll(n=>isBack(n)&&!(header&&within(n,header))&&(absY(n)-absY(F))>120);
  out.header=header?header.name:null; out.strays=strays.map(n=>`${n.name} @${Math.round(absX(n)-absX(F))},${Math.round(absY(n)-absY(F))}`);
  for(const n of strays){ R.removed.push(n.id); n.remove(); }
  // header shows ✕ (sheet) — a ‹ inside the header as well would be the second control: hide it
  if(header){ const hb=header.findAll(n=>isBack(n)); const hx=header.findAll(n=>/close|✕|xmark|关闭/i.test(n.name)&&n.type!=='TEXT'); if(hb.length&&hx.length){ for(const n of hb){ n.visible=false; R.touched.push(n.id); } out.headerBackHidden=hb.length; } out.headerClose=hx.length; }
  // menu: black bar → 0.5 separator (instance overrides or a detached copy)
  const bars=F.findAll(n=>n.type!=='TEXT'&&'fills' in n&&n.height>=2&&n.height<=14&&n.width>=150&&texts(n).length===0&&(()=>{ const s=solidOf(n); return s&&lum(s)<0.06; })()&&(()=>{ let p=n.parent; while(p&&p!==F){ if(/menu|菜单/i.test(p.name)) return true; p=p.parent; } return false; })());
  for(const b of bars){ if(insideInstance(b,F)){ b.fills=[PAINT('sep',{dark:true})]; } else { if(b.parent.layoutMode&&b.parent.layoutMode!=='NONE') b.layoutSizingVertical='FIXED'; b.resize(b.width,0.5); b.fills=[PAINT('sep',{dark:true})]; } R.touched.push(b.id); }
  out.menuBars=bars.length;
  // avatars: three rows, three different people
  const av=F.findAll(n=>(n.type==='ELLIPSE'||n.type==='RECTANGLE'||n.type==='FRAME')&&n.width>=28&&n.width<=56&&Math.abs(n.width-n.height)<1&&Array.isArray(n.fills)&&n.fills.some(f=>f.type==='IMAGE')).sort((a,b)=>absY(a)-absY(b));
  const hashes=[...new Set(av.map(n=>n.fills.find(f=>f.type==='IMAGE').imageHash))]; out.avatars=av.length; out.distinctBefore=hashes.length;
  if(av.length>=2&&hashes.length<av.length){ const pool=[]; for(const n of PG.findAll(x=>(x.type==='ELLIPSE'||x.type==='FRAME'||x.type==='RECTANGLE')&&x.width>=28&&x.width<=64&&Math.abs(x.width-x.height)<1&&Array.isArray(x.fills)&&x.fills.some(f=>f.type==='IMAGE'))){ const h=n.fills.find(f=>f.type==='IMAGE').imageHash; if(h&&!pool.includes(h)) pool.push(h); if(pool.length>=12) break; }
    const fresh=pool.filter(h=>!hashes.includes(h)); let k=0; for(let i=1;i<av.length&&k<fresh.length;i++){ const n=av[i]; n.fills=n.fills.map(f=>f.type==='IMAGE'?{...f,imageHash:fresh[k]}:f); k++; R.touched.push(n.id); } out.distinctAfter=new Set(av.map(n=>n.fills.find(f=>f.type==='IMAGE').imageHash)).size; }
  else if(!av.length){ const ini=F.findAll(n=>n.type==='TEXT'&&n.characters.trim().length===1&&n.parent&&n.parent.width<=48&&Math.abs(n.parent.width-n.parent.height)<1); const pool=['麦','周','林','安','乔']; out.initials=ini.map(t=>t.characters); const used=new Set(); for(const t of ini){ if(used.has(t.characters)){ const c=pool.find(x=>!used.has(x)); if(c){ await setT(t,c); used.add(c); } } else used.add(t.characters); } }
  FIXED(F,'4.3','One leading control (header ✕ for this sheet); no floating back circle; menu groups split by a 0.5 pt separator; three members, three avatars (F-03).');
  R.info['4.3']=out; }
function within(n,root){ let p=n; while(p){ if(p===root) return true; p=p.parent; } return false; }
// ---- 5.4a chip ✕ ----
{ const F=await byId('236:8395'); const out=[];
  const xs=F.findAll(n=>!insideInstance(n,F)&&((n.type==='TEXT'&&/^[×✕xX]$/.test(n.characters.trim()))||((n.type==='VECTOR'||n.type==='FRAME'||n.type==='INSTANCE')&&/×|✕|close|xmark|remove|删除/i.test(n.name)&&n.width<=20)));
  for(const x of xs){ const chip=x.parent; if(!chip||chip===F) continue; const btn=AL('HORIZONTAL','remove · 28 visual / 44 hit',{justify:'CENTER',r:14,fill:'surface-3',dark:true}); btn.resize(28,28); btn.primaryAxisSizingMode='FIXED'; btn.counterAxisSizingMode='FIXED';
    const ic=SVG(ICO.xmark('#FFFFFF'),'xmark',12); btn.appendChild(ic); for(const v of ic.findAll(n=>'strokes' in n&&n.strokes.length)) v.strokes=[PAINT('ink',{dark:true})];
    const hit=figma.createFrame(); hit.name='hit 44'; hit.fills=[]; hit.resize(44,44); btn.appendChild(hit); hit.layoutPositioning='ABSOLUTE'; hit.x=-8; hit.y=-8; btn.clipsContent=false;
    const idx=chip.children.indexOf(x); chip.insertChild(idx,btn); if(!(chip.layoutMode&&chip.layoutMode!=='NONE')){ btn.x=x.x+x.width/2-14; btn.y=chip.height/2-14; }
    out.push(`${chip.name}: ${x.type} ${Math.round(x.width)} → 28/44`); R.removed.push(x.id); x.remove(); chip.clipsContent=false; }
  if(xs.length) FIXED(F,'5.4','Tag chips: ✕ is a 28 pt circle with a 44 pt target (MC-20). VoiceOver “移除标签 <名称>”.');
  R.info['5.4 chips']=out.length?out:'no ✕ found'; }
// ---- 5.4b comment menu open (new state frame next to 219:3463) ----
{ const F=await byId('219:3463'); const sec=F.parent; const out={};
  const nm=F.name+' · 评论 ⋯ 已打开'; const ex=sec.children.find(c=>c.name===nm); if(ex) ex.remove();
  const C=F.clone(); sec.appendChild(C); C.name=nm; const rowY=F.y; const rightMost=Math.max(...sec.children.filter(c=>c!==C&&Math.abs(c.y-rowY)<F.height).map(c=>c.x+c.width)); C.x=rightMost+120; C.y=F.y; growSec(C); R.created.push(C.id);
  for(const n of C.findAll(x=>'reactions' in x&&x.reactions&&x.reactions.length)) await n.setReactionsAsync([]);
  const mores=C.findAll(n=>n.type!=='TEXT'&&(/⋯|more|menu|ellipsis|更多/i.test(n.name)||(n.type==='INSTANCE'&&/Accessory=Menu/.test(n.name)))&&n.width<=48).sort((a,b)=>absY(a)-absY(b));
  const comments=C.findAll(n=>n.type==='TEXT'&&/评论|说/.test(n.characters)).length; out.mores=mores.length;
  const anchor=mores.find(m=>absY(m)-absY(C)>200)||mores[0];
  const RM=await byId('291:61128'); const m=(RM.type==='COMPONENT_SET'?RM.defaultVariant||RM.children[0]:RM).createInstance(); C.appendChild(m); if(C.layoutMode&&C.layoutMode!=='NONE') m.layoutPositioning='ABSOLUTE';
  // comments: 举报 + 删除 (destructive last); hide the member-only rows
  const rows=texts(m); out.menuTexts=rows.map(t=>t.characters);
  for(const t of rows){ const s=t.characters.trim(); if(/设为管理员|临时封禁/.test(s)){ let r=t.parent; while(r&&r.parent!==m&&r!==m) r=r.parent; if(r&&r!==m) r.visible=false; } if(s==='移除') await setT(t,'删除'); }
  m.name='Club/Row Menu · 评论（举报 / 删除）';
  if(anchor){ m.x=Math.max(16,Math.min(C.width-m.width-16,absX(anchor)-absX(C)+anchor.width-m.width)); m.y=absY(anchor)-absY(C)+anchor.height+6; if(m.y+m.height>C.height-40) m.y=absY(anchor)-absY(C)-m.height-6; }
  else { m.x=C.width-m.width-16; m.y=C.height*0.4; }
  R.created.push(m.id); out.menuAt=[Math.round(m.x),Math.round(m.y)];
  FIXED(C,'5.4','Comment ⋯ open: 举报 · 删除 (red, last); 删除 asks once with Club/Consequence Sheet. Motion: system menu spring from the ⋯ · .selection; a removed comment collapses + fades 180 ms (MC-20).');
  await NOTE(C,'MC-20 · 评论行 ⋯ 打开态（verify-r1 5.4）。自己的评论：编辑 · 删除；别人的评论：举报；主理人/管理员额外有 删除。','menu');
  R.info['5.4 menu']=out; }
await motionPass('MC-50');
return R;
