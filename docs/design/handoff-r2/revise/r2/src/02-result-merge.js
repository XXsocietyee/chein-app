// 02-result-merge · Library 6:3 · item 4.8 (F-11): one Editor/Result. Keeps set 290:20551 (State = Success/Pending/Failed/Rejected),
// adds TEXT props title/body/primary/secondary + BOOLEAN showSecondary, re-points every 290:22148 instance, restores every instance's copy, deletes 290:22148 when unused.
// DRY=true: report only.
await goPage('6:3');

// ---- 4.4 follow-up: Merchant/Nav Bar has Trailing as a BOOLEAN, so ⋯ becomes its own BOOLEAN prop "More" on every variant ----
if(!DRY){ const MN=await byId('316:4825'); let mk=keyOf(MN,'More'); const info={};
  if(!mk){ mk=MN.addComponentProperty('More','BOOLEAN',false); info.added=[];
    for(const v of MN.children){ const tr=v.findAll(n=>n.componentPropertyReferences&&n.componentPropertyReferences.visible&&n.componentPropertyReferences.visible.split('#')[0]==='Trailing')[0];
      const hit=AL('HORIZONTAL','more · hit 44',{justify:'CENTER'}); hit.resize(44,44); hit.primaryAxisSizingMode='FIXED'; hit.counterAxisSizingMode='FIXED';
      const ic=SVG(ICO.more('#111111'),'icon/more',24); hit.appendChild(ic); for(const x of ic.findAll(n=>'fills' in n&&n.type!=='FRAME')) x.fills=[PAINT('ink')];
      const row=v.layoutMode==='HORIZONTAL'?v:(tr&&tr.parent&&tr.parent.layoutMode==='HORIZONTAL'?tr.parent:v.children.find(c=>c.type==='FRAME'&&c.layoutMode==='HORIZONTAL'));
      if(row){ if(tr&&tr.parent===row) row.insertChild(row.children.indexOf(tr)+1,hit); else row.appendChild(hit); }
      else { v.appendChild(hit); hit.x=v.width-4-44; hit.y=tr?Math.round(tr.y+tr.height/2-22):Math.max(0,Math.round((Math.min(v.height,52)-44)/2)); hit.constraints={horizontal:'MAX',vertical:'MIN'}; }
      hit.componentPropertyReferences={visible:mk}; info.added.push(v.name+(row?' in '+row.name:' abs')+(tr?' after '+tr.name:'')); }
    MN.description=(MN.description||'')+'\nMore (boolean): ⋯ pull-down, 44 pt target, VoiceOver “更多操作”. Holds rare or risky page actions (暂停接待, 下线, 清除声音); destructive item last, red. Opens Merchant/Menu (verify-r1 4.4).'; }
  R.info['4.4 nav More']=info; }
const C=await byId('290:20551'), D=await byId('290:22148');
if(!C) throw new Error('290:20551 missing');
// layer names are known (DRY 2026-11-16): C variants = TEXT title, TEXT body, FRAME primary, FRAME secondary; D = TEXT 'res title', TEXT 'res body', FRAME primary, FRAME secondary
const kid=(root,re)=>root.findOne(n=>re.test(n.name)&&!insideInstance(n,root));
function roles(root){ const title=kid(root,/^(res )?title$/), body=kid(root,/^(res )?body$/), pb=kid(root,/^primary$/), sb=kid(root,/^secondary$/);
  return {title,body,pb,sb,pt:pb?texts(pb)[0]:null,st:sb?texts(sb)[0]:null}; }
const rec=r=>({title:r.title&&r.title.characters,body:r.body&&r.body.characters,primary:r.pt&&r.pt.characters,secondary:r.st&&r.st.characters,showSecondary:!!(r.sb&&r.sb.visible)});
const instC=[], instD=[];
for(const v of C.children) for(const i of await v.getInstancesAsync()) instC.push({i,r:rec(roles(i))});
if(D) for(const v of (D.type==='COMPONENT_SET'?D.children:[D])) for(const i of await v.getInstancesAsync()) instD.push({i,r:rec(roles(i))});
R.info.instC=instC.map(x=>x.i.id+' '+x.r.title+' / '+x.r.primary+' / '+x.r.secondary); R.info.instD=instD.map(x=>x.i.id+' '+x.r.title+' / '+x.r.primary+' / '+x.r.secondary+(x.r.showSecondary?'':' (sec hidden)'));
if(DRY) return R;
const K={}; const v0=roles(C.children[0]);
for(const [nm,t] of [['title',v0.title],['body',v0.body],['primary',v0.pt],['secondary',v0.st]]) K[nm]=keyOf(C,nm)||C.addComponentProperty(nm,'TEXT',t?t.characters:nm);
K.showSecondary=keyOf(C,'showSecondary')||C.addComponentProperty('showSecondary','BOOLEAN',true);
const bindLog=[];
for(const v of C.children){ const r=roles(v); const b=(t,k)=>{ if(!t) return 'none'; if(insideInstance(t,v)) return 'in instance'; t.componentPropertyReferences={...(t.componentPropertyReferences||{}),characters:k}; return 'ok'; };
  const l={v:v.name,title:b(r.title,K.title),body:b(r.body,K.body),primary:b(r.pt,K.primary),secondary:b(r.st,K.secondary)}; if(r.sb){ r.sb.componentPropertyReferences={...(r.sb.componentPropertyReferences||{}),visible:K.showSecondary}; l.show='ok'; } bindLog.push(l); }
R.info.bind=bindLog;
C.description='Editor/Result · the only result content for editor sheets (merged 290:20551 + 290:22148, verify-r1 4.8 / F-11). State = Success / Pending / Failed / Rejected sets the icon and tone; copy per instance through title, body, primary, secondary, showSecondary. No ✕ — a result ends with buttons (CF-52). Draft: 继续编辑 / 回到我的玩法 · Published: 查看玩法 / 完成 · Activity: 查看活动 / 完成. Motion: rises 24 pt + fade, spring(response .42, damping .8) · .success (.error on Failed).';
async function apply(i,r){ for(const t of texts(i)) await loadFontsOf(t); const p={}; if(r.title) p[K.title]=r.title; if(r.body) p[K.body]=r.body; if(r.primary) p[K.primary]=r.primary; if(r.secondary) p[K.secondary]=r.secondary; p[K.showSecondary]=!!r.showSecondary; i.setProperties(p); }
const state=r=>{ const s=[r.title,r.body].join(' '); if(/驳回|未通过|没通过/.test(s)) return 'Rejected'; if(/失败|没.{0,4}成功|未能|没发布/.test(s)) return 'Failed'; if(/待确认|处理中|确认中|排队/.test(s)) return 'Pending'; return 'Success'; };
const res={restoredC:0,swappedD:[],err:[]};
for(const x of instC){ try{ await apply(x.i,x.r); res.restoredC++; }catch(e){ res.err.push(x.i.id+' '+String(e).slice(0,100)); } }
for(const x of instD){ try{ const st=state(x.r); const tgt=variant(C,{State:st})||C.defaultVariant; const w=x.i.width, h=x.i.layoutSizingHorizontal; x.i.swapComponent(tgt); x.i.name='Editor/Result'; if(h==='FILL') x.i.layoutSizingHorizontal='FILL'; else x.i.resize(w,x.i.height); await apply(x.i,x.r); res.swappedD.push(x.i.id+' → '+st); R.touched.push(x.i.id); }catch(e){ res.err.push(x.i.id+' '+String(e).slice(0,100)); } }
R.info.after=[...instC,...instD].map(x=>{ const r=rec(roles(x.i)); return x.i.id+' '+r.title+' / '+r.primary+' / '+r.secondary+(r.showSecondary?'':' (sec hidden)'); });
if(D){ let left=0; for(const v of (D.type==='COMPONENT_SET'?D.children:[D])) left+=(await v.getInstancesAsync()).length; if(left===0){ R.removed.push(D.id); D.remove(); res.deletedD=true; } else res.leftD=left; }
R.info.result=res; R.created=R.created.length; R.touched=R.touched.length;
return R;
