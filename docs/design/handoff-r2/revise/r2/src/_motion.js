// shared: verify-r1 5.8 (PL-40, MC-50) · motion in ONE place and ONE format: native annotations, category Interaction.
// 1) motion sentences in yellow/green canvas notes move into the frame's annotation (the note keeps only non-motion text, or goes);
// 2) every screen frame without a Motion annotation gets rows chosen from its own components. Detent notes (blue, :detent) stay.
const ROWP={
 press:'Press (buttons, cards, rows): scale .97, 80 ms ease-out; release 120 ms · no haptic',
 push:'Push: system slide ≈350 ms · edge swipe-back follows the finger',
 tab:'Tab switch: content cross-fade 140 ms, no slide · .selection',
 sheet:'Sheet: system spring ≈350 ms in, 280 ms out; detent change spring(response .38, damping .86) · .selection when a drag settles',
 menu:'⋯ menu: system menu spring from its anchor; a destructive item asks once · .warning',
 select:'Select (option card, chip, check): fill cross-fade 140 ms, check badge scales .6 → 1 in 220 ms · .selection',
 step:'Wizard step: slide 350 ms, progress segment fills 220 ms · .selection',
 remove:'Remove / leave: row collapses + fades 180 ms · .warning on the confirmation, .success after',
 toast:'Toast: rises 12 pt + fade 220 ms, stays 2 s, leaves 180 ms · VoiceOver announcement',
 load:'Loading: skeleton shimmer 1.2 s loop; content fades in 180 ms',
 hold:'Hold to start: ring fills over 1 s with a haptic ramp (.impact(.light) → .medium); early release rewinds 200 ms; VoiceOver action “开始”',
 map:'Map: camera moves with the system spring; newly lit cells fade in 600 ms ease-out · .impact(.light) per new cell',
 result:'Result: rises 24 pt + fade, spring(response .42, damping .8) · .success (.error on failure)',
 count:'Numbers that change (积分, 计时, 进度) roll with numericText 220 ms; progress bars fill 300 ms ease-out',
};
const RMX='Interruptible: a tap or scroll jumps to the end state. Reduce Motion: springs and slides → 200 ms cross-fades; fog, shimmer and glow loops stop; haptics stay.';
function kindsP(f){ const names=f.findAllWithCriteria({types:['INSTANCE']}).map(i=>i.name); const has=re=>names.some(n=>re.test(n)); const fn=f.name; const k=[];
 if(has(/Button|button/)||texts(f).length) k.push('press');
 if(has(/Nav Bar|Back|back/)||/详情|detail|设置|管理/.test(fn)) k.push('push');
 if(has(/Tab Bar|Root Header/)) k.push('tab');
 if(has(/Sheet|Consequence/)||/sheet|弹层|选择|确认|提示/i.test(fn)) k.push('sheet');
 if(has(/Row Menu|Menu/)||/菜单|⋯/.test(fn)) k.push('menu');
 if(has(/Option Card|Wizard|Check|Chip|Segment/)) k.push('select');
 if(has(/Wizard\/Step|Step Header|Step Bar/)) k.push('step');
 if(has(/Consequence/)||/删除|移除|退出|解散|封禁/.test(fn)) k.push('remove');
 if(has(/Toast/)) k.push('toast');
 if(has(/State|Skeleton/)||/加载|loading|skeleton/i.test(fn)) k.push('load');
 if(/大厅|lobby|走起|按住|hold/i.test(fn)) k.push('hold');
 if(/地图|map|漫游|roam|迷雾|fog/i.test(fn)) k.push('map');
 if(/成功|已提交|已创建|已完成|结果|result/i.test(fn)) k.push('result');
 if(has(/Stat Tile|Top Pill|Progress/)) k.push('count');
 return [...new Set(k)]; }
async function motionPass(tag,opt={}){ const pg=figma.currentPage; const SKIP=opt.skip||/组件|component|kit|素材|asset|规格|spec board|Spec/i;
 const lines={}; let notesMoved=0, notesDeleted=0;
 for(const s of pg.children.filter(s=>s.type==='SECTION')) for(const n of s.children.filter(c=>c.name.startsWith('note:'))){
   const m=n.name.match(/^note:(\d+:\d+)(?::(.+))?$/); if(!m||m[2]==='detent') continue; const t=texts(n); if(!t.length) continue;
   const full=t.map(x=>x.characters).join('\n'); const parts=full.replace(/([。；;])\s*/g,'$1\n').split(/\n+/).map(x=>x.trim()).filter(Boolean);
   const mot=m[2]==='motion'?parts:parts.filter(p=>MOTION_RE.test(p)); if(!mot.length) continue;
   (lines[m[1]]=lines[m[1]]||[]).push(...mot); notesMoved++;
   const restP=m[2]==='motion'?[]:parts.filter(p=>!mot.includes(p));
   if(!restP.join('').replace(/[\s·:：]/g,'').length||restP.every(p=>/^(Motion|动效|PL-4\d|MC-50)[^]{0,12}$/.test(p))){ R.removed.push(n.id); n.remove(); notesDeleted++; }
   else { await setT(t[0],restP.join('\n')); for(const x of t.slice(1)){ x.remove(); } } }
 let annotated=0, fromNotes=0;
 for(const s of pg.children.filter(s=>s.type==='SECTION'&&!SKIP.test(s.name))) for(const f of s.children){
   if(f.type!=='FRAME'||/^(note|label)/.test(f.name)||f.width<360||f.height<480) continue;
   const has=(f.annotations||[]).some(a=>/^\*\*Motion/.test(a.labelMarkdown||a.label||''));
   const nl=lines[f.id]||[]; if(has&&!nl.length) continue;
   const rows=[...nl,...kindsP(f).map(k=>ROWP[k])]; if(!rows.length) continue;
   ANN(f,`**Motion · 动效与触感 (${tag})**\n`+rows.map(l=>'- '+l).join('\n')+'\n\n'+RMX,'I',/^\*\*Motion/); annotated++; if(nl.length) fromNotes++; delete lines[f.id]; }
 // notes whose frame is not a section child (nested or elsewhere)
 for(const [id,nl] of Object.entries(lines)){ const f=await byId(id); if(f&&'annotations' in f){ ANN(f,`**Motion · 动效与触感 (${tag})**\n`+nl.map(l=>'- '+l).join('\n')+'\n\n'+RMX,'I',/^\*\*Motion/); annotated++; fromNotes++; } else R.warn.push('motion note for missing '+id); }
 R.info['5.8']={tag,annotated,fromNotes,notesMoved,notesDeleted};
 R.ann=R.ann.slice(-20); }
