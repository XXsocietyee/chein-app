const PAGEID='235:13237'; const PROBE=[]; const DEEP=[];
const PG=await figma.getNodeByIdAsync(PAGEID); await figma.setCurrentPageAsync(PG);
const out={secs:[],cats:[],probe:{},text:{},react:0,annos:0};
out.cats=(await figma.annotations.getAnnotationCategoriesAsync()).map(c=>c.label+'='+c.id+':'+c.color);
for(const s of PG.children) out.secs.push(`${s.id}|${s.type}|${s.name}|${Math.round(s.x)},${Math.round(s.y)},${Math.round(s.width)}x${Math.round(s.height)}|${s.children?s.children.filter(c=>c.type==='FRAME'&&!c.name.startsWith('note')).length:0}`);
for(const id of PROBE){const n=await figma.getNodeByIdAsync(id); if(!n){out.probe[id]='MISSING';continue;} let s=`${n.type}|${n.name}|${Math.round(n.x)},${Math.round(n.y)},${Math.round(n.width)}x${Math.round(n.height)}|par=${n.parent&&n.parent.id}|pg=${(()=>{let a=n;while(a&&a.type!=="PAGE")a=a.parent;return a&&a.name})()}`; if(DEEP.includes(id)&&'children' in n){s+='\n  '+n.children.map(c=>`${c.id} ${c.type} ${c.name} ${Math.round(c.x)},${Math.round(c.y)},${Math.round(c.width)}x${Math.round(c.height)}`+(c.type==='TEXT'?' "'+c.characters.slice(0,40)+'"':'')).join('\n  ');} out.probe[id]=s;}
const PATS={ell:/(?<!…)…$|\.\.\.$/, ok:/^确定$/, del:/确认删除/, login:/去登录/, done:/任务完成[!！]/, num:/第\d+章/, tk:/票单名称\d/, fail:/加载失败|重新加载|未加载|暂时不可用/, pre:/发布前提示/, colon:/已添加: /, ellmid:/…|\.\.\./};
const texts=PG.findAllWithCriteria({types:['TEXT']});
for(const k in PATS) out.text[k]={n:0,s:[]};
for(const t of texts){ if(t.name.startsWith('note')) continue; let anc=t.parent, isNote=false; while(anc&&anc.type!=='SECTION'&&anc.type!=='PAGE'){ if(anc.name.startsWith('note:')||anc.name.startsWith('label')){isNote=true;break;} anc=anc.parent;} if(isNote) continue; const c=t.characters; for(const k in PATS) if(PATS[k].test(c)){ const o=out.text[k]; o.n++; if(o.s.length<(k==='ell'||k==='ellmid'?25:12)) o.s.push(t.id+' '+c.slice(0,36).replace(/\n/g,'⏎'));}}
for(const n of PG.findAll(n=>'reactions' in n && n.reactions.length>0)) out.react++;
for(const n of PG.findAll(n=>'annotations' in n && n.annotations.length>0)) out.annos++;
out.nTexts=texts.length;
return out;
