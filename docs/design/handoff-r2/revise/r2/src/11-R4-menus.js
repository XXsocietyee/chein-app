// 11-R4-menus · page R4 · 4.4 (F-04: "moved to ⋯" now has a ⋯ — Merchant/Nav Bar Trailing=More + one open-menu frame each:
// 233:9703 暂停接待, 182:8448 下线, 233:11700 移除 (row ⋯), MR-26 / MR-27 清除声音), 5.6 (MR-27 voice: waveform ring + timer while holding, auto progress while generating).
const PG=await goPage('233:9703');
const absX=n=>n.absoluteTransform[0][2], absY=n=>n.absoluteTransform[1][2];
const MN=await byId('316:4825'); const tk=keyOf(MN,'Trailing'); const MENU=await byId(MENU_ID);
async function navOf(F){ for(const i of F.findAllWithCriteria({types:['INSTANCE']})){ const mc=await topMain(i); if(mc&&mc.id==='316:4825') return i; } return null; }
async function setMore(F){ const nav=await navOf(F); if(!nav) return 'no Merchant/Nav Bar'; const mk=keyOf(MN,'More'); if(mk){ nav.setProperties({[mk]:true}); return 'More=true'; } if(!tk) return 'no Trailing prop'; const d=MN.componentPropertyDefinitions[tk]; if(d.type==='VARIANT'&&d.variantOptions.includes('More')){ nav.setProperties({[tk]:'More'}); return 'More'; } if(d.type==='TEXT'){ nav.setProperties({[tk]:'⋯'}); return 'text ⋯'; } return 'Trailing '+d.type; }
async function openClone(F,items,anchorFn,label){ const sec=F.parent; const nm=F.name+' · ⋯ 已打开'; for(const o of sec.children.filter(c=>c.name===nm)) o.remove();
  const C=F.clone(); sec.appendChild(C); C.name=nm; const rr=Math.max(...sec.children.filter(c=>c!==C&&Math.abs(c.y-F.y)<F.height/2).map(c=>c.x+c.width)); C.x=rr+120; C.y=F.y; growSec(C); R.created.push(C.id);
  for(const n of C.findAll(x=>'reactions' in x&&x.reactions&&x.reactions.length)) await n.setReactionsAsync([]);
  const m=MENU.createInstance(); C.appendChild(m); if(C.layoutMode&&C.layoutMode!=='NONE') m.layoutPositioning='ABSOLUTE';
  const P={}; const k=b=>keyOf(MENU,b); P[k('item1')]=items[0]; P[k('show2')]=!!items[1]; if(items[1]) P[k('item2')]=items[1]; P[k('show3')]=!!items[2]; if(items[2]) P[k('item3')]=items[2]; P[k('show4')]=!!items[3]; if(items[3]) P[k('item4')]=items[3]; m.setProperties(P); m.name='Merchant/Menu · '+items.filter(Boolean).join(' / ');
  const a=await anchorFn(C); if(a){ m.x=Math.max(16,Math.min(C.width-m.width-16,absX(a)-absX(C)+a.width-m.width)); m.y=absY(a)-absY(C)+a.height+4; if(m.y+m.height>C.height-90) m.y=absY(a)-absY(C)-m.height-4; } else { m.x=C.width-m.width-16; m.y=100; }
  R.created.push(m.id); FIXED(C,'4.4',label+' Motion: system menu spring from the ⋯ · .selection; the red item asks once (confirmationDialog) · .warning.'); return C.id; }
const navMore=async C=>{ const nav=await navOf(C); return nav?(nav.findOne(n=>/more|⋯/i.test(n.name))||nav):null; };
// 4.5 follow-up: the refund pages' pills are not Merchant/Status Tag instances — swap them by who must act
{ const MT=await byId('316:5196'); const lk=keyOf(MT,'Label'); const o=[];
  for(const id of ['183:1731','183:1819']){ const F=await byId(id); if(!F) continue;
    for(const [re,st] of [[/^平台审核中$/,'Waiting'],[/^等待商家意见$/,'NeedsMe'],[/^待商家处理$/,'NeedsMe'],[/^退款成功$|^已退款$/,'Done']]){ for(const t of texts(F).filter(t=>re.test(t.characters.trim())&&!insideInstance(t,F))){ let pill=t.parent; while(pill&&pill!==F&&!(pill.height<=32&&(solidOf(pill)||pill.cornerRadius>=6))) pill=pill.parent; if(!pill||pill===F) continue;
      const i=variant(MT,{State:st}).createInstance(); i.setProperties({[lk]:t.characters.trim()}); i.name='Merchant/Status Tag'; replaceAt(pill,i,{vcenter:true}); o.push(id+' '+t.characters+' → '+st); } } }
  R.info['4.5 pills']=o; }
const out={};
// 233:9703 本站运行 · 182:8448 城市节点
for(const [id,items,lbl] of [['233:9703',['暂停接待','本站设置',null,null],'暂停接待 lives in ⋯ (reversible, no red).'],['182:8448',['编辑节点信息',null,null,'下线'],'下线 lives in ⋯, red, last; confirms once.']]){ const F=await byId(id); if(!F){ out[id]='missing'; continue; } const s=await setMore(F); out[id]={nav:s,open:await openClone(F,items,navMore,lbl)}; FIXED(F,'4.4','Nav ⋯ added (F-04): '+items.filter(Boolean).join(' / ')+'.'); }
// MR-26 / MR-27 frames that still say 清除声音 lives in ⋯
{ const cand=['227:18542','227:19212','227:19289','227:19366','227:19432','227:19495']; const hits=[];
  for(const id of cand){ const F=await byId(id); if(!F||(await pageOf(F))!==PG) continue; const s=await setMore(F); hits.push(id+':'+s); }
  out.voiceNav=hits;
  const base=await byId('227:19212'); if(base) out['227:19212 open']=await openClone(base,['重新录制',null,null,'清除声音'],navMore,'清除声音 lives in ⋯, red, last (MR-27).');
  const role=await byId('227:18542'); if(role&&texts(role).some(t=>/声音/.test(t.characters))) out['227:18542 open']=await openClone(role,['更换形象',null,null,'清除声音'],navMore,'清除声音 lives in ⋯, red, last (MR-26).'); }
// 233:11700 员工: red 移除 word on the row → row ⋯ + open menu
{ const F=await byId('233:11700'); const words=texts(F).filter(t=>t.characters.trim()==='移除'&&!insideInstance(t,F)); const o={words:words.length};
  for(const t of words){ const hit=AL('HORIZONTAL','row ⋯ · hit 44',{justify:'CENTER'}); hit.resize(44,44); hit.primaryAxisSizingMode='FIXED'; hit.counterAxisSizingMode='FIXED'; const ic=SVG(ICO.more('#111111'),'icon/more',22); hit.appendChild(ic); for(const v of ic.findAll(n=>'fills' in n&&n.type!=='FRAME')) v.fills=[PAINT('ink-2')];
    const par=t.parent; par.insertChild(par.children.indexOf(t),hit); if(!(par.layoutMode&&par.layoutMode!=='NONE')){ hit.x=t.x+t.width-44+6; hit.y=t.y+t.height/2-22; } R.removed.push(t.id); t.remove(); }
  if(words.length){ o.open=await openClone(F,['设为店长','设为店员',null,'移除'],async C=>C.findAll(n=>n.name==='row ⋯ · hit 44').sort((a,b)=>absY(a)-absY(b))[0],'Member row ⋯: role changes + 移除 (red, last) (MR-29).'); FIXED(F,'4.4','Member rows: ⋯ instead of the red 移除 word (F-04, MR-29).'); }
  out['233:11700']=o; }
R.info['4.4']=out;
// ---------- MR-27 voice: ring + timer while holding; automatic progress while generating ----------
{ const ids=['227:19212','227:19289','227:19366','227:19432','227:19495']; const o={frames:[]};
  const circleIn=F=>F.findAll(n=>(n.type==='ELLIPSE'||n.type==='FRAME'||n.type==='INSTANCE')&&n.width>=64&&n.width<=160&&Math.abs(n.width-n.height)<2&&(n.type==='ELLIPSE'||n.cornerRadius>=n.width/2-1)&&solidOf(n)&&lum(solidOf(n))<0.08)[0];
  let rec=null, base=null;
  for(const id of ids){ const F=await byId(id); if(!F) continue; o.frames.push(id+' '+F.name); if(!base&&circleIn(F)) base=F; if(/录制中|录音中|按住|正在录/.test(F.name)) rec=F; }
  if(!rec&&base){ const sec=base.parent; const nm=base.name.replace(/\s*·.*$/,'')+' · 按住录音中'; for(const x of sec.children.filter(c=>c.name===nm)) x.remove(); rec=base.clone(); sec.appendChild(rec); rec.name=nm; rec.x=Math.max(...sec.children.filter(c=>c!==rec&&Math.abs(c.y-base.y)<base.height/2).map(c=>c.x+c.width))+120; rec.y=base.y; growSec(rec); R.created.push(rec.id); o.newRec=rec.id; }
  if(rec){ const c=circleIn(rec); if(c){ for(const x of c.parent.children.filter(x=>x.name==='level ring'||x.name==='timer')) x.remove();
      const r0=c.width/2+8, D=Math.ceil((r0+18)*2); let lines=''; for(let i=0;i<48;i++){ const a=i*7.5*Math.PI/180; const L=4+14*Math.abs(Math.sin(i*0.7))*(0.55+0.45*Math.cos(i*0.31)); const x1=D/2+r0*Math.cos(a), y1=D/2+r0*Math.sin(a), x2=D/2+(r0+L)*Math.cos(a), y2=D/2+(r0+L)*Math.sin(a); lines+=`<line x1="${x1.toFixed(1)}" y1="${y1.toFixed(1)}" x2="${x2.toFixed(1)}" y2="${y2.toFixed(1)}" stroke="#111111" stroke-width="3" stroke-linecap="round"/>`; }
      const ring=figma.createNodeFromSvg(`<svg width="${D}" height="${D}" viewBox="0 0 ${D} ${D}" xmlns="http://www.w3.org/2000/svg">${lines}</svg>`); ring.name='level ring'; const par=c.parent; par.insertChild(par.children.indexOf(c),ring); if(par.layoutMode&&par.layoutMode!=='NONE') ring.layoutPositioning='ABSOLUTE'; ring.x=c.x+c.width/2-D/2; ring.y=c.y+c.height/2-D/2; for(const v of ring.findAll(n=>'strokes' in n&&n.strokes.length)) v.strokes=[PAINT('ink')]; R.created.push(ring.id);
      const tm=await TXT(par,'0:08 / 0:15',{size:17,lh:22,w:'Semibold',name:'timer'}); tm.fontName={family:'SF Pro',style:'Semibold'}; if(par.layoutMode&&par.layoutMode!=='NONE') tm.layoutPositioning='ABSOLUTE'; tm.x=c.x+c.width/2-tm.width/2; tm.y=ring.y-30;
      ANN(rec,'**Motion · 动效与触感 (MR-27)**\n- Press and hold: .impact(.medium); the ring follows the input level every frame (AVAudioRecorder metering → Canvas)\n- Timer counts up with the target, 0:08 / 0:15 (numericText)\n- Release: the ring collapses into a playable waveform (300 ms) · .success for a valid take, .error when shorter than 5 s\n\nReduce Motion: the ring shows a static level bar; haptics stay.','I',/^\*\*Motion/); FIXED(rec,'5.6','Hold-to-record: live level ring + count-up timer (MR-27).'); o.ring='drawn in '+rec.id; } else o.ring='no black circle found'; }
  for(const id of ids){ const F=await byId(id); if(!F) continue; const btn=texts(F).find(t=>/刷新状态/.test(t.characters)); if(!btn) continue; let b=btn.parent; while(b&&b!==F&&b.height<40) b=b.parent; if(!b||b===F) b=btn;
    const blk=AL('VERTICAL','generating · auto progress',{gap:8,align:'MIN'}); const t1=await TXT(blk,'正在学习你的声音，大约 1 分钟',{size:15,lh:20}); const track=figma.createFrame(); track.name='progress 60%'; track.resize(Math.max(200,b.width),4); track.cornerRadius=2; track.fills=[PAINT('surface-3')]; blk.appendChild(track); const fill=figma.createRectangle(); fill.name='fill'; track.appendChild(fill); fill.resize(track.width*0.6,4); fill.cornerRadius=2; fill.fills=[PAINT('ink')];
    await TXT(blk,'完成后会自动更新，不用刷新',{size:13,lh:18,color:'ink-2'}); replaceAt(b,blk,{keepW:true}); if(blk.parent.layoutMode&&blk.parent.layoutMode!=='NONE') blk.layoutSizingHorizontal='FILL'; track.layoutSizingHorizontal='FILL';
    FIXED(F,'5.6','生成中: progress with what is happening, polled automatically; no 刷新状态 button (MR-27).'); o.progress=(o.progress||[]).concat(id); }
  R.info['MR-27']=o; }
R.created=R.created.length; R.touched=R.touched.length; R.ann=R.ann.length; R.removed=R.removed.length;
for(const id of ['183:1731',R.info['4.4']['233:9703']&&R.info['4.4']['233:9703'].open,R.info['4.4']['233:11700']&&R.info['4.4']['233:11700'].open,R.info['MR-27'].newRec||'227:19212','227:19366']){ if(!id) continue; const n=await byId(id); if(n) await n.screenshot({scale:0.35}); }
return R;
