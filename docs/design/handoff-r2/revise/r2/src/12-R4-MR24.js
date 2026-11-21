// 12-R4-MR24 · page R4 · item 5.6 (MR-24 AI 店铺参谋): chart modules → Merchant/Metric Module (one number, comparison, labelled neutral bars);
// contradicting numbers fixed; greeting wraps instead of truncating; recommended theme gets a real cover. DRY=true reports.
const PG=await goPage('182:8263');
const FR=['182:8263','182:8356','225:8155','225:8321'];
const MET=await byId(MET_ID);
const absY=n=>n.absoluteTransform[1][2];
const lav=c=>!!c&&c.b>0.75&&c.r>0.45&&c.r<0.9&&c.g<0.8&&(c.b-c.g)>0.12;
const card=(n,F)=>{ let p=n; while(p.parent&&p.parent!==F&&!(solidOf(p)&&p.cornerRadius>=8&&p.width>=300)) p=p.parent; return (solidOf(p)&&p.cornerRadius>=8&&p.width>=300)?p:null; };
const SPEC=[{title:'本周到店',value:'12 人',delta:'比上周 +3'},{title:'本周核销',value:'9 张',delta:'比上周 +2'},{title:'本周报名',value:'15 人',delta:'比上周 −1'}];
const plan=[];
for(const fid of FR){ const F=await byId(fid); if(!F){ plan.push({fid,missing:true}); continue; } const p={fid,name:F.name,charts:[],contra:[],trunc:[],grad:[]};
  const groups=F.findAll(n=>(n.type==='FRAME'||n.type==='GROUP')&&!insideInstance(n,F)&&(n.children.filter(c=>(c.type==='RECTANGLE'||c.type==='FRAME')&&lav(solidOf(c))).length>=4||n.children.filter(c=>c.type==='ELLIPSE').length>=12));
  const seen=new Set(); for(const g of groups){ const c=card(g,F); if(c&&!seen.has(c.id)){ seen.add(c.id); p.charts.push({card:c.id,name:c.name,h:Math.round(c.height),texts:texts(c).slice(0,4).map(t=>t.characters)}); } }
  for(const t of texts(F)) if(/0\s?位玩家到店/.test(t.characters)) p.contra.push(t.id);
  for(const t of texts(F)) if(t.textTruncation==='ENDING'&&absY(t)-absY(F)<220) p.trunc.push(t.id);
  for(const n of F.findAll(n=>'fills' in n&&Array.isArray(n.fills)&&n.fills.some(f=>f.type&&f.type.startsWith('GRADIENT'))&&n.width>=80&&n.height>=60&&!insideInstance(n,F))){ const c=card(n,F); if(c&&texts(c).some(t=>/推荐|主题/.test(t.characters))) p.grad.push(n.id); }
  plan.push(p); }
R.info.plan=plan;
if(DRY) return R;
const pool=[...new Set(PG.findAll(n=>'fills' in n&&Array.isArray(n.fills)&&n.width>=120&&Math.abs(n.width-n.height)>20&&n.fills.some(f=>f.type==='IMAGE')&&/cover|封面|图|photo/i.test(n.name)).map(n=>n.fills.find(f=>f.type==='IMAGE').imageHash))];
for(const p of plan){ if(p.missing) continue; const F=await byId(p.fid); let k=0;
  for(const c of p.charts){ const n=await byId(c.card); if(!n) continue; const i=MET.createInstance(); const s=SPEC[Math.min(k,SPEC.length-1)]; i.setProperties({[keyOf(MET,'title')]:s.title,[keyOf(MET,'value')]:s.value,[keyOf(MET,'delta')]:s.delta}); i.name='Merchant/Metric Module · '+s.title; replaceAt(n,i,{keepW:true}); R.created.push(i.id); k++; }
  for(const id of p.contra){ const t=await byId(id); await setT(t,t.characters.replace(/0\s?位玩家到店/,'今天 2 位玩家到店')); }
  for(const id of p.trunc){ const t=await byId(id); await loadFontsOf(t); t.textTruncation='DISABLED'; t.maxLines=null; if(t.textAutoResize==='NONE') t.textAutoResize='HEIGHT'; R.touched.push(id); }
  for(const id of p.grad){ const n=await byId(id); if(pool.length){ n.fills=[{type:'IMAGE',imageHash:pool[0],scaleMode:'FILL'}]; R.touched.push(id); } }
  ANN(F,'**Motion · 动效与触感 (MR-24)**\n- Bars grow from the axis 400 ms ease-out, once, on first appear\n- Value and delta roll (numericText) when the period changes · .selection\n\nReduce Motion: bars fade in 200 ms.','I',/^\*\*Motion/);
  FIXED(F,'5.6','AI 参谋: each module states one number, its comparison and a labelled neutral chart (Merchant/Metric Module); numbers agree; greeting wraps (MR-24).'); }
R.info.coverPool=pool.length;
return R;
